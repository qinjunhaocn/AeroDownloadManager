import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../utils/constants.dart';
import '../../utils/file_types.dart';
import '../models/app_settings.dart';
import '../models/download_task.dart';
import 'http_transport.dart';
import 'speed_limiter.dart';

/// Runs a single HTTP task: probe, segment, download, verify, finish.
///
/// This is the Flutter counterpart of ADM's `i2.t` (task thread) +
/// `i2.y` (connection thread) + `i2.x` (segment manager) trio.
class DownloadWorker {
  DownloadWorker({
    required this.task,
    required this.settings,
    required this.defaultDirectory,
    required this.notify,
    required this.onFinished,
    required this.onPersist,
    required this.isWifi,
  });

  final DownloadTask task;
  final AppSettings Function() settings;
  final String Function() defaultDirectory;
  final void Function() notify;
  final void Function() onFinished;
  final void Function() onPersist;
  final bool Function() isWifi;

  RandomAccessFile? _raf;
  String? _effectiveUrl;
  bool _cancelled = false;
  bool _restartSingle = false;
  bool _splitScheduled = false;
  bool _finished = false;
  bool _notifiedComplete = false;

  final Set<Segment> _active = {};
  final Map<Segment, HttpClient> _clients = {};
  final Map<Segment, DateTime> _segStartedAt = {};
  final Map<Segment, int> _segStartPos = {};
  SpeedLimiter _limiter = SpeedLimiter(0);

  DateTime _lastTick = DateTime.now();
  int _lastBytes = 0;
  DateTime _lastPersist = DateTime.now();

  bool get isCancelled => _cancelled;
  bool get isFinished => _finished;

  int get _threads {
    final value = task.threads > 0 ? task.threads : settings().threads;
    return value.clamp(1, 32);
  }

  int get _algorithm {
    final value = task.algorithm >= 0 ? task.algorithm : settings().algorithm;
    return value == 1 ? 1 : 0;
  }

  int get _speedLimit {
    final value = task.speedLimit > 0
        ? task.speedLimit
        : settings().speedLimitBytesPerSecond;
    return value;
  }

  String get _proxy => task.proxy.isNotEmpty ? task.proxy : settings().proxy;

  String get _url => _effectiveUrl ?? task.url;

  Future<void> start() async {
    task.startedAt ??= DateTime.now().millisecondsSinceEpoch;
    try {
      if (task.kind != TaskKind.http) {
        throw DownloadException('该任务不是 HTTP 下载任务');
      }
      await _probe();
      if (_cancelled) return;
      await _prepareFile();
      if (_cancelled) return;
      await _prepareSegments();
      if (_cancelled) return;
      task.status = TaskStatus.downloading;
      task.message = '';
      _limiter = SpeedLimiter(_speedLimit);
      _lastTick = DateTime.now();
      _lastBytes = task.downloaded;
      _startPending();
      await _monitor();
    } on _AlreadyComplete {
      if (!_cancelled) {
        task.downloaded = task.total;
        task.status = TaskStatus.completed;
        task.message = '文件已存在';
        task.finishedAt = DateTime.now().millisecondsSinceEpoch;
        task.speed = 0;
        _notifiedComplete = true;
      }
    } on DownloadException catch (error) {
      _fail(error.message);
    } catch (error) {
      _fail('下载失败：$error');
    } finally {
      _cancelConnections();
      await _closeFile();
      _finished = true;
      task.speed = 0;
      onPersist();
      onFinished();
      notify();
    }
  }

  Future<void> pause() async {
    if (_finished) return;
    _cancelled = true;
    _cancelConnections();
    task.status = TaskStatus.paused;
    task.message = '已暂停';
    task.speed = 0;
    notify();
  }

  // ---------------------------------------------------------------------------
  // Probing
  // ---------------------------------------------------------------------------

  Future<void> _probe() async {
    final uri = Uri.tryParse(task.url);
    if (uri == null || !uri.hasScheme) {
      throw DownloadException('无效的链接');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw DownloadException('不支持的协议：${uri.scheme}');
    }
    if (task.total > 0 && task.segments.isNotEmpty) {
      _effectiveUrl = task.url;
      return;
    }

    task.status = TaskStatus.connecting;
    task.message = '正在连接…';
    notify();

    final s = settings();
    final headers = _headersForProbe();
    final result = await HttpTransport.get(
      uri: uri,
      headers: headers,
      timeoutSec: s.timeoutSec,
      proxy: _proxy,
    );
    try {
      final response = result.response;
      final code = response.statusCode;
      final contentType = response.headers.contentType?.mimeType ?? '';
      final disposition = response.headers.value('content-disposition');

      if (result.cookie != null && result.cookie!.isNotEmpty) {
        task.cookie = result.cookie!;
      }

      if (code == HttpStatus.requestedRangeNotSatisfiable && !task.noRange) {
        task.noRange = true;
        task.total = 0;
        await _probe();
        return;
      }
      if (code >= 400) {
        throw DownloadException(describeHttpStatus(code, contentType));
      }
      if (code != 200 && code != 206) {
        throw DownloadException('服务器返回了意外状态：HTTP $code');
      }

      _effectiveUrl = result.finalUri.toString();
      final total = _totalFromResponse(response);
      if (code == 206) {
        task.noRange = task.noRange || total == null;
        if (total != null) task.total = total;
      } else {
        // 200 for a range probe means the server ignores ranges.
        task.noRange = true;
        if (total != null) task.total = total;
      }

      _applyRemoteName(disposition, contentType);
      if (contentType.toLowerCase().contains('text/html') &&
          (disposition == null || disposition.isEmpty) &&
          !_looksLikeHtmlFile(task.name) &&
          task.total < 8 * 1024 * 1024) {
        throw DownloadException('这是一个网页链接，请在浏览器中打开');
      }
      if (task.total == 0) {
        // Unknown length: single connection until EOF.
        task.noRange = true;
      }
    } finally {
      result.client.close(force: true);
    }
  }

  Map<String, String> _headersForProbe() {
    final headers = _baseHeaders();
    if (!task.noRange) {
      headers['Range'] = 'bytes=0-${kProbeBytes - 1}';
    }
    return headers;
  }

  Map<String, String> _baseHeaders() {
    final s = settings();
    final headers = <String, String>{
      'User-Agent': task.userAgent.isNotEmpty ? task.userAgent : s.userAgent,
      'Accept': '*/*',
      'Pragma': 'no-cache',
      'Cache-Control': 'no-cache',
      'Accept-Encoding': 'identity',
    };
    if (task.referer.isNotEmpty) headers['Referer'] = task.referer;
    if (task.authorization.isNotEmpty) {
      headers['Authorization'] = task.authorization;
    }
    if (task.cookie.isNotEmpty) headers['Cookie'] = task.cookie;
    for (final line in task.headers.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final index = trimmed.indexOf(':');
      if (index <= 0) continue;
      headers[trimmed.substring(0, index).trim()] = trimmed
          .substring(index + 1)
          .trim();
    }
    return headers;
  }

  Map<String, String> _headersFor(Segment segment) {
    final headers = _baseHeaders();
    if (!task.noRange) {
      final end = segment.end > 0 ? (segment.end - 1).toString() : '';
      headers['Range'] = 'bytes=${segment.pos}-$end';
    }
    return headers;
  }

  int? _totalFromResponse(HttpClientResponse response) {
    final range = response.headers.value('content-range');
    if (range != null) {
      final match = RegExp(r'bytes\s+\d+-\d+/(\d+|\*)').firstMatch(range);
      if (match != null && match.group(1) != '*') {
        return int.tryParse(match.group(1)!);
      }
    }
    final length = response.contentLength;
    if (length > 0) return length;
    return null;
  }

  void _applyRemoteName(String? disposition, String contentType) {
    String? remote;
    if (disposition != null && disposition.isNotEmpty) {
      remote = _fileNameFromDisposition(disposition);
    }
    if (remote != null && remote.isNotEmpty) {
      final hasExt = p.extension(task.name).length > 1;
      if (task.name.isEmpty || !hasExt) {
        task.name = sanitizeFileName(remote);
      }
    }
    if (p.extension(task.name).length <= 1) {
      final ext = _extensionForMime(contentType);
      if (ext != null) task.name = '${task.name}.$ext';
    }
    if (task.name.isEmpty) {
      task.name = fileNameFromUrl(Uri.parse(_url));
    }
    task.name = sanitizeFileName(task.name);
  }

  String? _fileNameFromDisposition(String value) {
    final star = RegExp(
      r"filename\*\s*=\s*([^;]+)",
      caseSensitive: false,
    ).firstMatch(value);
    if (star != null) {
      var raw = star.group(1)!.trim().replaceAll('"', '');
      final parts = raw.split("''");
      if (parts.length == 2) raw = parts[1];
      try {
        return Uri.decodeComponent(raw);
      } catch (_) {
        return raw;
      }
    }
    final plain = RegExp(
      r'filename\s*=\s*"?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(value);
    if (plain != null) return plain.group(1)!.trim();
    return null;
  }

  static const Map<String, String> _mimeExtensions = {
    'video/mp4': 'mp4',
    'video/x-matroska': 'mkv',
    'video/webm': 'webm',
    'audio/mpeg': 'mp3',
    'audio/mp4': 'm4a',
    'audio/flac': 'flac',
    'audio/ogg': 'ogg',
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/gif': 'gif',
    'image/webp': 'webp',
    'application/pdf': 'pdf',
    'application/zip': 'zip',
    'application/x-7z-compressed': '7z',
    'application/x-rar-compressed': 'rar',
    'application/vnd.android.package-archive': 'apk',
    'application/x-bittorrent': 'torrent',
    'text/plain': 'txt',
  };

  String? _extensionForMime(String contentType) {
    final mime = contentType.split(';').first.trim().toLowerCase();
    return _mimeExtensions[mime];
  }

  bool _looksLikeHtmlFile(String name) {
    final ext = p.extension(name).toLowerCase();
    return ext == '.html' || ext == '.htm' || ext == '.xhtml';
  }

  // ---------------------------------------------------------------------------
  // File + segments
  // ---------------------------------------------------------------------------

  Future<void> _prepareFile() async {
    final dir = task.directory.isNotEmpty ? task.directory : defaultDirectory();
    await Directory(dir).create(recursive: true);
    if (task.name.isEmpty) {
      task.name = fileNameFromUrl(Uri.parse(_url));
    }
    task.name = sanitizeFileName(task.name);

    final needsPath =
        task.filePath.isEmpty ||
        p.dirname(task.filePath) != dir ||
        p.basename(task.filePath) != task.name;
    if (needsPath) {
      final unique = uniqueFileName(dir, task.name);
      task.name = unique;
      task.filePath = p.join(dir, unique);
    }
    task.directory = dir;

    final file = File(task.filePath);
    final exists = await file.exists();
    final existing = exists ? await file.length() : 0;
    if (!exists && task.segments.isNotEmpty && task.downloaded > 0) {
      // The partially downloaded file disappeared (user cleanup / OS cache
      // eviction). Restart the task instead of writing sparse garbage.
      task.segments.clear();
      task.downloaded = 0;
      task.restartCount = 0;
      task.noRange = false;
    }
    _raf = await file.open(mode: FileMode.append);
    if (task.segments.isEmpty) {
      task.downloaded = existing;
      if (task.total > 0 && existing >= task.total) {
        throw _AlreadyComplete();
      }
    }
  }

  Future<void> _prepareSegments() async {
    if (task.segments.isEmpty) {
      task.segments.add(
        Segment(
          index: 0,
          start: 0,
          pos: task.downloaded.clamp(0, 1 << 62),
          end: -1,
        ),
      );
    }
    for (final segment in task.segments) {
      if (segment.status == SegmentStatus.running) {
        segment.status = SegmentStatus.idle;
      }
      if (segment.status == SegmentStatus.error) {
        segment.status = SegmentStatus.idle;
      }
    }
    _recalcDownloaded();

    if (_canClassicSplit()) {
      _classicSplit();
    }
    onPersist();

    if (task.total >= kPreallocateThreshold &&
        settings().preallocate &&
        _threads > 1 &&
        _algorithm == 0 &&
        task.segments.first.pos == 0 &&
        task.segments.length > 1) {
      try {
        await _raf?.truncate(task.total);
        await _raf?.flush();
      } catch (_) {
        // Preallocation is an optimisation; ignore failures.
      }
    }
  }

  bool _canClassicSplit() {
    return task.total > 0 &&
        task.segments.length == 1 &&
        task.segments.first.pos == 0 &&
        task.segments.first.end == -1 &&
        !task.noRange &&
        _algorithm == 0 &&
        _threads > 1 &&
        task.restartCount == 0;
  }

  void _classicSplit() {
    final total = task.total;
    var threads = _threads;
    var part = total ~/ threads;
    final minPart = settings().minSegmentBytes;
    if (part < minPart) part = minPart;
    if (part <= 0) return;
    if (part * threads > total) {
      threads = total ~/ part + 1;
    }
    if (threads <= 1) return;

    final first = task.segments.first;
    first.end = math.min(part, total);
    for (var i = 1; i < threads; i++) {
      final start = i * part;
      if (start >= total) break;
      final end = (i == threads - 1) ? -1 : math.min((i + 1) * part, total);
      task.segments.add(Segment(index: i, start: start, pos: start, end: end));
    }
  }

  void _startPending() {
    if (_cancelled) return;
    final threads = _threads;
    if (_active.length >= threads) return;
    final pending =
        task.segments
            .where(
              (s) =>
                  s.status == SegmentStatus.idle ||
                  s.status == SegmentStatus.waiting,
            )
            .toList()
          ..sort(
            (a, b) =>
                b.remaining(task.total).compareTo(a.remaining(task.total)),
          );
    for (final segment in pending) {
      if (_cancelled || _active.length >= threads) break;
      _startSegment(segment);
    }
  }

  void _startSegment(Segment segment) {
    if (_cancelled || segment.status == SegmentStatus.done) return;
    if (_active.contains(segment)) return;
    segment.status = SegmentStatus.running;
    _active.add(segment);
    _downloadSegment(segment).whenComplete(() {
      _active.remove(segment);
      _clients.remove(segment);
      if (!_cancelled && !_finished) {
        _startPending();
      }
    });
  }

  Future<void> _downloadSegment(Segment segment) async {
    final maxRetries = settings().maxRetries.clamp(1, 128);
    var attempts = 0;
    while (!_cancelled && segment.status != SegmentStatus.done) {
      attempts++;
      HttpClient? client;
      try {
        final result = await HttpTransport.get(
          uri: Uri.parse(_url),
          headers: _headersFor(segment),
          timeoutSec: settings().timeoutSec,
          proxy: _proxy,
        );
        client = result.client;
        _clients[segment] = client;
        if (_cancelled || segment.status != SegmentStatus.running) {
          return;
        }
        final response = result.response;
        final code = response.statusCode;
        final contentType = response.headers.contentType?.mimeType ?? '';

        if (code == HttpStatus.requestedRangeNotSatisfiable && !task.noRange) {
          task.noRange = true;
          _restartSingle = true;
          return;
        }
        if (code == 200 && segment.start > 0 && !task.noRange) {
          // The server ignored the Range header; fall back to one stream.
          task.noRange = true;
          _restartSingle = true;
          return;
        }
        if (code >= 400) {
          throw DownloadException(describeHttpStatus(code, contentType));
        }
        if (result.cookie != null && result.cookie!.isNotEmpty) {
          task.cookie = result.cookie!;
        }
        final total = _totalFromResponse(response);
        if (total != null && total > 0) {
          task.total = total;
          if (segment.end > total) segment.end = total;
        }

        _segStartedAt[segment] = DateTime.now();
        _segStartPos[segment] = segment.pos;
        if (_algorithm == 1) {
          _scheduleSplit();
        }

        await for (final chunk in response.timeout(
          const Duration(seconds: 60),
        )) {
          if (_cancelled || segment.status != SegmentStatus.running) {
            return;
          }
          if (chunk.isEmpty) continue;
          var data = chunk;
          if (segment.end > 0) {
            final remaining = segment.end - segment.pos;
            if (remaining <= 0) break;
            if (data.length > remaining) {
              data = data.sublist(0, remaining);
            }
          }
          await _limiter.consume(data.length);
          if (_cancelled || segment.status != SegmentStatus.running) return;
          final raf = _raf;
          if (raf == null) throw DownloadException('文件句柄已关闭');
          try {
            raf.setPositionSync(segment.pos);
            raf.writeFromSync(data);
          } on FileSystemException catch (error) {
            throw DownloadException(
              '无法写入文件（${error.osError?.message ?? error.message}）',
            );
          }
          segment.pos += data.length;
          _recalcDownloaded();
          if (segment.end > 0 && segment.pos >= segment.end) break;
        }

        if (_cancelled) return;
        if (segment.end > 0 && segment.pos < segment.end) {
          throw DownloadException('连接提前结束');
        }
        segment.status = SegmentStatus.done;
        _onSegmentDone(segment);
        return;
      } on DownloadException catch (error) {
        if (_cancelled || _restartSingle) return;
        if (attempts >= maxRetries) {
          segment.status = SegmentStatus.error;
          task.message = error.message;
          return;
        }
        await _retryDelay(attempts);
      } catch (error) {
        if (_cancelled || _restartSingle) return;
        if (attempts >= maxRetries) {
          segment.status = SegmentStatus.error;
          task.message = '网络错误：$error';
          return;
        }
        await _retryDelay(attempts);
      } finally {
        _clients.remove(segment);
        client?.close(force: true);
        _segStartedAt.remove(segment);
        _segStartPos.remove(segment);
      }
    }
  }

  Future<void> _retryDelay(int attempt) async {
    final ms = (500 * math.pow(1.6, attempt)).clamp(500, 10000).toInt();
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (!_cancelled && DateTime.now().isBefore(end)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _onSegmentDone(Segment segment) {
    if (_cancelled) return;
    if (_algorithm == 1) _scheduleSplit();
    _startPending();
  }

  // ---------------------------------------------------------------------------
  // Smart segmentation
  // ---------------------------------------------------------------------------

  void _scheduleSplit() {
    if (_splitScheduled || _cancelled || _algorithm != 1) return;
    if (_threads <= 1 || task.total <= 0) return;
    _splitScheduled = true;
    Future.delayed(const Duration(milliseconds: 100), () {
      _splitScheduled = false;
      _maybeSplit();
    });
  }

  void _maybeSplit() {
    if (_cancelled || _algorithm != 1 || task.total <= 0) return;
    if (_active.length >= _threads) return;
    final minBytes = settings().minSegmentBytes;
    final now = DateTime.now();
    Segment? best;
    var bestRemaining = 0;

    for (final segment in task.segments) {
      if (segment.status != SegmentStatus.running) continue;
      final remaining = segment.remaining(task.total);
      if (remaining < math.max(2 * minBytes, 1)) continue;
      final startedAt = _segStartedAt[segment];
      final startPos = _segStartPos[segment] ?? segment.pos;
      if (startedAt == null) continue;
      final elapsedMs = now.difference(startedAt).inMilliseconds;
      if (elapsedMs < 800) continue;
      final speed = (segment.pos - startPos) * 1000 / elapsedMs;
      if (speed * 12 >= remaining) continue;
      if (remaining > bestRemaining) {
        bestRemaining = remaining;
        best = segment;
      }
    }
    if (best == null) return;
    final chatAt = best.pos + bestRemaining ~/ 2;
    if (chatAt <= best.pos || chatAt >= task.total) return;

    final child = Segment(
      index: task.segments.length,
      start: chatAt,
      pos: chatAt,
      end: best.end,
    );
    best.end = chatAt;
    task.segments.add(child);
    onPersist();
    _startSegment(child);
  }

  // ---------------------------------------------------------------------------
  // Monitor loop
  // ---------------------------------------------------------------------------

  Future<void> _monitor() async {
    task.startedAt ??= DateTime.now().millisecondsSinceEpoch;
    while (!_cancelled) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_cancelled) break;

      if (_restartSingle) {
        await _rebuildSingleConnection();
        continue;
      }

      if (settings().wifiOnly && !isWifi()) {
        if (task.status != TaskStatus.waiting) {
          task.status = TaskStatus.waiting;
          task.message = '等待 Wi-Fi';
          _cancelConnections();
          notify();
        }
        continue;
      } else if (task.status == TaskStatus.waiting) {
        task.status = TaskStatus.downloading;
        task.message = '';
        _startPending();
      }

      final now = DateTime.now();
      final bytes = _recalcDownloaded();
      final dt = now.difference(_lastTick).inMilliseconds;
      if (dt > 0) {
        final instant = (bytes - _lastBytes) * 1000 / dt;
        final clamped = instant < 0 ? 0.0 : instant.toDouble();
        task.speed = task.speed <= 0
            ? clamped
            : task.speed * 0.6 + clamped * 0.4;
        _lastTick = now;
        _lastBytes = bytes;
      }
      task.downloaded = bytes;

      if (task.segments.isNotEmpty &&
          task.segments.every((s) => s.status == SegmentStatus.done) &&
          _active.isEmpty) {
        await _complete();
        return;
      }

      if (_active.isEmpty) {
        if (task.segments.any((s) => s.status == SegmentStatus.error)) {
          _fail(task.message.isNotEmpty ? task.message : '下载失败');
          return;
        }
        if (task.segments.any(
          (s) =>
              s.status == SegmentStatus.idle ||
              s.status == SegmentStatus.waiting,
        )) {
          _startPending();
        }
      }

      if (_algorithm == 1 && _active.isNotEmpty) {
        _maybeSplit();
      }

      if (now.difference(_lastPersist).inSeconds >= 5) {
        _lastPersist = now;
        onPersist();
      }
      notify();
    }
  }

  Future<void> _rebuildSingleConnection() async {
    _cancelConnections();
    await Future.delayed(const Duration(milliseconds: 150));
    task.segments.clear();
    task.downloaded = 0;
    task.restartCount = math.max(task.restartCount, 1);
    _restartSingle = false;
    try {
      await _raf?.truncate(0);
      await _raf?.flush();
    } catch (_) {
      // ignore
    }
    task.segments.add(Segment(index: 0, start: 0, pos: 0, end: -1));
    task.message = '服务器不支持多线程或续传，已切换为单连接';
    onPersist();
    notify();
    _startPending();
  }

  // ---------------------------------------------------------------------------
  // Completion / failure
  // ---------------------------------------------------------------------------

  Future<void> _complete() async {
    if (_cancelled) return;
    final bytes = _recalcDownloaded();
    task.downloaded = bytes;
    if (task.total > 0 && bytes < task.total) {
      _fail('文件不完整：已下载 $bytes / ${task.total} 字节');
      return;
    }
    if (task.checksum.isNotEmpty) {
      final ok = await _verifyChecksum();
      if (!ok) {
        _fail('校验失败（${task.checksumType.toUpperCase()} 不匹配）');
        return;
      }
    }
    task.downloaded = task.total > 0 ? task.total : bytes;
    task.status = TaskStatus.completed;
    task.message = '已完成';
    task.finishedAt = DateTime.now().millisecondsSinceEpoch;
    task.speed = 0;
    _notifiedComplete = true;
    onPersist();
    notify();
  }

  bool get notifiedComplete => _notifiedComplete;

  void _fail(String message) {
    if (_cancelled) return;
    task.status = TaskStatus.error;
    task.message = message;
    task.speed = 0;
    onPersist();
    notify();
  }

  Future<bool> _verifyChecksum() async {
    try {
      final file = File(task.filePath);
      if (!await file.exists()) return false;
      final algorithm = switch (task.checksumType) {
        'sha1' => sha1,
        'sha256' => sha256,
        _ => md5,
      };
      final sink = _DigestSink();
      final input = algorithm.startChunkedConversion(sink);
      await for (final chunk in file.openRead()) {
        input.add(chunk);
      }
      input.close();
      final digest = sink.value?.toString().toLowerCase();
      return digest != null && digest == task.checksum.trim().toLowerCase();
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int _recalcDownloaded() {
    var total = 0;
    for (final segment in task.segments) {
      total += segment.downloaded;
    }
    if (task.segments.isEmpty) {
      total = task.downloaded;
    }
    return total;
  }

  void _cancelConnections() {
    for (final entry in _clients.entries.toList()) {
      try {
        entry.value.close(force: true);
      } catch (_) {
        // ignore
      }
    }
    _clients.clear();
    for (final segment in task.segments) {
      if (segment.status == SegmentStatus.running) {
        segment.status = SegmentStatus.waiting;
      }
    }
  }

  Future<void> _closeFile() async {
    final raf = _raf;
    _raf = null;
    try {
      await raf?.flush();
    } catch (_) {
      // ignore
    }
    try {
      await raf?.close();
    } catch (_) {
      // ignore
    }
  }
}

class _AlreadyComplete implements Exception {}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
