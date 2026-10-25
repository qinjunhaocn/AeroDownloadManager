import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dtorrent_common/dtorrent_common.dart';
import 'package:dtorrent_parser/dtorrent_parser.dart';
import 'package:dtorrent_task/dtorrent_task.dart';
import 'package:dtorrent_tracker/dtorrent_tracker.dart';
import 'package:events_emitter2/events_emitter2.dart';
import 'package:path/path.dart' as p;

import '../../utils/file_types.dart';
import '../models/app_settings.dart';
import '../models/download_task.dart';
import 'http_transport.dart';

/// BitTorrent support powered by the pure-Dart `dtorrent_task` stack.
///
/// Supports `.torrent` files, remote `.torrent` URLs and magnet links (metadata
/// fetched via BEP 9 with tracker + DHT peer discovery).
class TorrentEngine {
  TorrentEngine({
    required this.settings,
    required this.onChanged,
    required this.onPersist,
    required this.cacheDirectory,
  });

  final AppSettings Function() settings;
  final void Function() onChanged;
  final void Function() onPersist;
  final String Function() cacheDirectory;

  final Map<String, _TorrentRuntime> _runtimes = {};

  bool isRunning(String id) => _runtimes.containsKey(id);

  Future<void> start(DownloadTask task) async {
    final existing = _runtimes[task.id];
    if (existing?.task != null && existing!.task!.state == TaskState.paused) {
      existing.task!.resume();
      task.status = TaskStatus.downloading;
      task.message = '';
      existing.startTimer(onTick: () => _tick(task));
      onChanged();
      return;
    }
    if (existing?.task != null) {
      if (existing!.task!.state == TaskState.running) {
        return;
      }
      await remove(task, deleteFiles: false);
    }
    if (existing?.metadata != null) {
      // A paused magnet task: throw away the stopped metadata session and
      // start a fresh one below.
      await existing!.publicTrackerSub?.cancel();
      try {
        await existing.tracker?.stop(true);
      } catch (_) {
        // ignore
      }
      try {
        await existing.metadata?.stop();
      } catch (_) {
        // ignore
      }
      _runtimes.remove(task.id);
    }
    final runtime = _TorrentRuntime();
    _runtimes[task.id] = runtime;
    try {
      task.status = TaskStatus.connecting;
      task.message = '正在准备种子…';
      onChanged();

      final path = await _resolveTorrentFile(task);
      if (path == null) {
        await _startMetadata(task, runtime);
        return;
      }
      final model = await Torrent.parseFromFile(path);
      await _startTorrentModel(task, runtime, model, path);
    } catch (error) {
      _fail(task, '种子任务失败：$error');
    }
  }

  Future<void> pause(DownloadTask task) async {
    final runtime = _runtimes[task.id];
    if (runtime == null) {
      task.status = TaskStatus.paused;
      task.speed = 0;
      task.message = '已暂停';
      onChanged();
      return;
    }
    runtime.cancelTimer();
    runtime.cancelMetadataTimeout();
    try {
      runtime.task?.pause();
    } catch (_) {
      // ignore
    }
    try {
      await runtime.metadata?.stop();
    } catch (_) {
      // ignore
    }
    try {
      await runtime.tracker?.stop(true);
    } catch (_) {
      // ignore
    }
    await runtime.publicTrackerSub?.cancel();
    task.status = TaskStatus.paused;
    task.message = '已暂停';
    task.speed = 0;
    task.uploadSpeed = 0;
    onChanged();
    onPersist();
  }

  Future<void> remove(DownloadTask task, {bool deleteFiles = false}) async {
    final runtime = _runtimes.remove(task.id);
    if (runtime != null) {
      runtime.cancelTimer();
      runtime.cancelMetadataTimeout();
      await runtime.publicTrackerSub?.cancel();
      try {
        await runtime.metadata?.stop();
      } catch (_) {
        // ignore
      }
      try {
        await runtime.tracker?.stop(true);
      } catch (_) {
        // ignore
      }
      try {
        await runtime.task?.stop();
      } catch (_) {
        // ignore
      }
      try {
        await runtime.task?.dispose();
      } catch (_) {
        // ignore
      }
    }
    if (deleteFiles) {
      try {
        final target = File(task.filePath);
        if (target.existsSync()) {
          target.deleteSync();
        } else {
          final dir = Directory(task.filePath);
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        }
      } catch (_) {
        // ignore
      }
    }
  }

  // ---------------------------------------------------------------------------

  Future<String?> _resolveTorrentFile(DownloadTask task) async {
    if (task.torrentFile.isNotEmpty && File(task.torrentFile).existsSync()) {
      return task.torrentFile;
    }
    final source = task.url;
    if (source.startsWith('magnet:')) return null;
    if (source.startsWith('file://')) {
      final path = Uri.parse(source).toFilePath();
      if (File(path).existsSync()) {
        task.torrentFile = path;
        return path;
      }
      return null;
    }
    if (File(source).existsSync()) {
      task.torrentFile = source;
      return source;
    }
    if (source.startsWith('http://') || source.startsWith('https://')) {
      final s = settings();
      final result = await HttpTransport.get(
        uri: Uri.parse(source),
        headers: {'User-Agent': s.userAgent, 'Accept': '*/*'},
        timeoutSec: s.timeoutSec,
        proxy: s.proxy,
      );
      try {
        if (result.response.statusCode >= 400) {
          throw DownloadException(
            '下载种子文件失败：HTTP ${result.response.statusCode}',
          );
        }
        final bytes = await result.response
            .timeout(Duration(seconds: s.timeoutSec))
            .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
        final dir = Directory(cacheDirectory());
        await dir.create(recursive: true);
        final name = sanitizeFileName(
          fileNameFromUrl(Uri.parse(source), fallback: 'remote.torrent'),
        );
        final path = p.join(
          dir.path,
          name.endsWith('.torrent') ? name : '$name.torrent',
        );
        await File(path).writeAsBytes(bytes, flush: true);
        task.torrentFile = path;
        return path;
      } finally {
        result.client.close(force: true);
      }
    }
    return null;
  }

  Future<void> _startTorrentModel(
    DownloadTask task,
    _TorrentRuntime runtime,
    Torrent model,
    String torrentPath,
  ) async {
    task.torrentFile = torrentPath;
    task.kind = TaskKind.torrent;
    task.infoHash = model.infoHash;
    task.name = model.name;
    task.total = model.length;
    task.directory = task.directory.isNotEmpty
        ? task.directory
        : Directory(torrentPath).parent.path;
    if (task.filePath.isEmpty) {
      task.filePath = p.join(task.directory, model.name);
    }
    task.status = TaskStatus.downloading;
    task.message = '';
    task.noRange = true;
    onChanged();
    onPersist();

    final torrentTask = TorrentTask.newTask(model, task.directory);
    runtime.task = torrentTask;
    final listener = torrentTask.createListener();
    runtime.listener = listener;
    listener
      ..on<TaskCompleted>((_) => _markComplete(task, runtime))
      ..on<TaskStopped>((_) {
        if (!runtime.disposed &&
            task.status == TaskStatus.downloading &&
            (torrentTask.state == TaskState.stopped)) {
          _fail(task, '种子任务已停止');
        }
      });

    await torrentTask.start();
    for (final announce in model.announces) {
      try {
        torrentTask.startAnnounceUrl(announce, model.infoHashBuffer);
      } catch (_) {
        // ignore individual trackers
      }
    }
    for (final node in model.nodes) {
      try {
        torrentTask.addDHTNode(node);
      } catch (_) {
        // ignore
      }
    }
    await runtime.publicTrackerSub?.cancel();
    runtime.publicTrackerSub = findPublicTrackers().listen((urls) {
      for (final url in urls) {
        try {
          torrentTask.startAnnounceUrl(url, model.infoHashBuffer);
        } catch (_) {
          // ignore
        }
      }
    });
    runtime.startTimer(onTick: () => _tick(task));
  }

  void _tick(DownloadTask task) {
    final runtime = _runtimes[task.id];
    final torrentTask = runtime?.task;
    if (runtime == null || runtime.disposed || torrentTask == null) return;
    if (task.status != TaskStatus.downloading) return;
    final downloaded = torrentTask.downloaded ?? task.downloaded;
    task.downloaded = downloaded;
    if (task.total <= 0) task.total = torrentTask.metaInfo.length;
    task.speed = torrentTask.currentDownloadSpeed * 1000;
    task.uploadSpeed = torrentTask.uploadSpeed * 1000;
    task.peers = torrentTask.connectedPeersNumber;
    task.seeders = torrentTask.seederNumber;
    if (torrentTask.progress >= 1.0 ||
        (task.total > 0 && downloaded >= task.total)) {
      _markComplete(task, runtime);
    }
    onChanged();
  }

  void _markComplete(DownloadTask task, _TorrentRuntime runtime) {
    if (task.status == TaskStatus.completed) return;
    task.status = TaskStatus.completed;
    task.message = '已完成';
    task.downloaded = task.total > 0 ? task.total : task.downloaded;
    task.speed = 0;
    task.finishedAt = DateTime.now().millisecondsSinceEpoch;
    runtime.cancelTimer();
    onChanged();
    onPersist();
  }

  // ---------------------------------------------------------------------------
  // Magnet metadata (BEP 9)
  // ---------------------------------------------------------------------------

  Future<void> _startMetadata(
    DownloadTask task,
    _TorrentRuntime runtime,
  ) async {
    final uri = Uri.parse(task.url);
    final hashHex = _infoHashFromMagnet(uri);
    if (hashHex == null) {
      throw DownloadException('磁力链接缺少有效的 info-hash');
    }
    task.status = TaskStatus.connecting;
    task.message = '正在获取种子元数据…';
    task.infoHash = hashHex;
    if (task.name.isEmpty) task.name = uri.queryParameters['dn'] ?? hashHex;
    onChanged();

    final metadata = MetadataDownloader(hashHex);
    runtime.metadata = metadata;
    final listener = metadata.createListener();
    runtime.metadataListener = listener;
    listener
      ..on<MetaDataDownloadProgress>((event) {
        if (runtime.disposed) return;
        task.message = '获取元数据 ${event.progress.toStringAsFixed(0)}%';
        onChanged();
      })
      ..on<MetaDataDownloadComplete>((event) async {
        if (runtime.disposed) return;
        await _onMetadataComplete(task, runtime, event.data);
      })
      ..on<MetaDataDownloadFailed>((event) {
        if (runtime.disposed) return;
        _fail(task, '获取元数据失败：${event.error}');
      });

    final tracker = TorrentAnnounceTracker(metadata);
    runtime.tracker = tracker;
    runtime.trackerListener = tracker.createListener();
    runtime.trackerListener!.on<AnnouncePeerEventEvent>((event) async {
      final peerEvent = event.event;
      if (peerEvent == null) return;
      for (final address in peerEvent.peers) {
        metadata.addNewPeerAddress(address, PeerSource.tracker);
      }
    });

    await metadata.startDownload();
    final hashBytes = _hexToBytes(hashHex);
    final announceUrls = <String>[...?uri.queryParametersAll['tr']];
    for (final announce in announceUrls) {
      try {
        tracker.runTracker(Uri.parse(announce), hashBytes);
      } catch (_) {
        // ignore malformed tracker URLs
      }
    }
    runtime.publicTrackerSub = findPublicTrackers().listen((urls) {
      for (final url in urls) {
        try {
          tracker.runTracker(url, hashBytes);
        } catch (_) {
          // ignore
        }
      }
    });
    runtime.startMetadataTimeout(const Duration(minutes: 6), () {
      if (runtime.disposed || runtime.metadata == null) return;
      _fail(task, '获取种子元数据超时，请检查网络/DHT 或改用 .torrent 文件');
    });
  }

  Future<void> _onMetadataComplete(
    DownloadTask task,
    _TorrentRuntime runtime,
    List<int> data,
  ) async {
    try {
      final dir = Directory(cacheDirectory());
      await dir.create(recursive: true);
      final path = p.join(
        dir.path,
        '${task.infoHash.isNotEmpty ? task.infoHash : task.id}.torrent',
      );
      await File(path).writeAsBytes(data, flush: true);
      final model = await Torrent.parseFromBytes(Uint8List.fromList(data));
      runtime.cancelMetadataTimeout();
      runtime.cancelTimer();
      await runtime.publicTrackerSub?.cancel();
      try {
        await runtime.tracker?.stop(true);
      } catch (_) {
        // ignore
      }
      try {
        await runtime.metadata?.stop();
      } catch (_) {
        // ignore
      }
      runtime.metadata = null;
      runtime.tracker = null;
      await _startTorrentModel(task, runtime, model, path);
    } catch (error) {
      _fail(task, '解析种子元数据失败：$error');
    }
  }

  String? _infoHashFromMagnet(Uri uri) {
    final values = uri.queryParametersAll['xt'];
    if (values == null) return null;
    for (final value in values) {
      final lower = value.toLowerCase();
      if (!lower.startsWith('urn:btih:')) continue;
      final raw = value.substring(9);
      if (raw.length == 40 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(raw)) {
        return raw.toLowerCase();
      }
      if (raw.length == 32) {
        try {
          return _base32ToHex(raw);
        } catch (_) {
          // ignore
        }
      }
    }
    return null;
  }

  static String _base32ToHex(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    var bits = 0;
    var value = 0;
    final bytes = <int>[];
    for (final code in input.toUpperCase().codeUnits) {
      final index = alphabet.indexOf(String.fromCharCode(code));
      if (index < 0) continue;
      value = (value << 5) | index;
      bits += 5;
      if (bits >= 8) {
        bytes.add((value >> (bits - 8)) & 0xff);
        bits -= 8;
      }
    }
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  void _fail(DownloadTask task, String message) {
    if (task.status == TaskStatus.completed) return;
    task.status = TaskStatus.error;
    task.message = message;
    task.speed = 0;
    onChanged();
    onPersist();
  }

  Future<void> dispose() async {
    for (final runtime in _runtimes.values.toList()) {
      runtime.disposed = true;
      runtime.cancelTimer();
      await runtime.publicTrackerSub?.cancel();
      try {
        await runtime.metadata?.stop();
      } catch (_) {
        // ignore
      }
      try {
        await runtime.tracker?.stop(true);
      } catch (_) {
        // ignore
      }
      try {
        await runtime.task?.stop();
      } catch (_) {
        // ignore
      }
    }
    _runtimes.clear();
  }
}

class _TorrentRuntime {
  TorrentTask? task;
  MetadataDownloader? metadata;
  TorrentAnnounceTracker? tracker;
  EventsListener<TaskEvent>? listener;
  EventsListener<MetadataDownloaderEvent>? metadataListener;
  EventsListener<TorrentAnnounceEvent>? trackerListener;
  StreamSubscription<List<Uri>>? publicTrackerSub;
  Timer? timer;
  Timer? metadataTimer;
  bool disposed = false;

  void startMetadataTimeout(Duration duration, void Function() onTimeout) {
    metadataTimer?.cancel();
    metadataTimer = Timer(duration, onTimeout);
  }

  void cancelMetadataTimeout() {
    metadataTimer?.cancel();
    metadataTimer = null;
  }

  void startTimer({required void Function() onTick}) {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => onTick());
  }

  void cancelTimer() {
    timer?.cancel();
    timer = null;
  }
}
