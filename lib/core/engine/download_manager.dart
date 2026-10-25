import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../utils/constants.dart';
import '../../utils/file_types.dart';
import '../models/app_settings.dart';
import '../models/download_task.dart';
import '../platform/native_bridge.dart';
import '../platform/notifications.dart';
import 'download_worker.dart';
import 'task_store.dart';
import 'torrent_engine.dart';

/// Owns the task list, queue, persistence and platform integrations.
class DownloadManager extends ChangeNotifier {
  DownloadManager({
    required this.store,
    required this.notifications,
    required this.native,
    required this.settingsGetter,
    required this.defaultDirectoryGetter,
  });

  final TaskStore store;
  final NotificationService notifications;
  final NativeBridge native;
  final AppSettings Function() settingsGetter;
  final String Function() defaultDirectoryGetter;

  final List<DownloadTask> tasks = [];
  final Map<String, DownloadWorker> _workers = {};

  late final TorrentEngine torrents;
  late final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool _onWifi = true;
  bool _serviceRunning = false;
  Timer? _ticker;
  Timer? _saveTimer;
  bool _dirty = false;
  bool _ready = false;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastNotificationUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  bool get ready => _ready;
  bool get onWifi => _onWifi;

  int get activeCount => tasks.where((t) => t.status.occupiesSlot).length;
  int get queuedCount =>
      tasks.where((t) => t.status == TaskStatus.queued).length;
  int get completedCount => tasks.where((t) => t.isFinished).length;
  int get errorCount => tasks.where((t) => t.status == TaskStatus.error).length;

  double get totalSpeed => tasks
      .where((t) => t.status.isActive)
      .fold(0.0, (sum, t) => sum + t.speed);

  Future<void> init() async {
    final loaded = await store.load();
    for (final task in loaded) {
      if (task.status.occupiesSlot || task.status == TaskStatus.connecting) {
        task.status = TaskStatus.paused;
        task.message = '已暂停（应用重启）';
      }
      task.speed = 0;
      task.uploadSpeed = 0;
      if (task.segments.isNotEmpty) {
        for (final segment in task.segments) {
          if (segment.status == SegmentStatus.running) {
            segment.status = SegmentStatus.waiting;
          }
        }
      }
      tasks.add(task);
    }
    torrents = TorrentEngine(
      settings: () => settingsGetter(),
      onChanged: () {
        _markDirty();
        _notify();
      },
      onPersist: saveNow,
      cacheDirectory: () => p.join(store.directory.path, 'torrents'),
    );
    _connectivity = Connectivity();
    try {
      _onWifi = _isWifi(await _connectivity.checkConnectivity());
      _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
        final wasWifi = _onWifi;
        _onWifi = _isWifi(results);
        if (!wasWifi && _onWifi) _notify();
      });
    } catch (_) {
      _onWifi = true;
    }
    _ready = true;
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
    _notify(force: true);
    if (settingsGetter().autoStart) {
      startAll();
    }
  }

  bool _isWifi(List<ConnectivityResult> results) =>
      results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet) ||
      results.contains(ConnectivityResult.vpn);

  // ---------------------------------------------------------------------------
  // Task creation
  // ---------------------------------------------------------------------------

  String get defaultDirectory => defaultDirectoryGetter();

  DownloadTask _newTask({
    required String url,
    required String name,
    required String directory,
    required TaskKind kind,
  }) {
    final id =
        '${DateTime.now().microsecondsSinceEpoch}'
        '${(tasks.length % 97).toString().padLeft(2, '0')}';
    return DownloadTask(
      id: id,
      url: url,
      name: sanitizeFileName(name),
      directory: directory,
      filePath: '',
      kind: kind,
      status: TaskStatus.queued,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<DownloadTask> addHttp({
    required String url,
    String name = '',
    String directory = '',
    int threads = 0,
    int speedLimit = 0,
    int algorithm = -1,
    String userAgent = '',
    String referer = '',
    String cookie = '',
    String authorization = '',
    String headers = '',
    String proxy = '',
    String checksum = '',
    String checksumType = 'md5',
    bool startNow = true,
  }) async {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('请输入有效的 http(s) 链接');
    }
    final directoryValue = directory.isNotEmpty
        ? directory
        : defaultDirectoryGetter();
    final task =
        _newTask(
            url: trimmed,
            name: name.isNotEmpty ? name : fileNameFromUrl(uri),
            directory: directoryValue,
            kind: TaskKind.http,
          )
          ..threads = threads
          ..speedLimit = speedLimit
          ..algorithm = algorithm
          ..userAgent = userAgent
          ..referer = referer.isNotEmpty ? referer : trimmed
          ..cookie = cookie
          ..authorization = authorization
          ..headers = headers
          ..proxy = proxy
          ..checksum = checksum
          ..checksumType = checksumType;
    tasks.add(task);
    _markDirty();
    _notify(force: true);
    if (startNow) start(task);
    return task;
  }

  Future<DownloadTask> addTorrentFile({
    required String path,
    String directory = '',
    bool startNow = true,
  }) async {
    final directoryValue = directory.isNotEmpty
        ? directory
        : defaultDirectoryGetter();
    final task =
        _newTask(
            url: path,
            name: p.basename(path),
            directory: directoryValue,
            kind: TaskKind.torrent,
          )
          ..torrentFile = path
          ..name = p.basenameWithoutExtension(path);
    tasks.add(task);
    _markDirty();
    _notify(force: true);
    if (startNow) start(task);
    return task;
  }

  Future<DownloadTask> addTorrentUrl({
    required String url,
    String directory = '',
    bool startNow = true,
  }) async {
    final directoryValue = directory.isNotEmpty
        ? directory
        : defaultDirectoryGetter();
    final uri = Uri.parse(url);
    final task = _newTask(
      url: url,
      name: fileNameFromUrl(uri, fallback: 'torrent'),
      directory: directoryValue,
      kind: TaskKind.torrent,
    );
    tasks.add(task);
    _markDirty();
    _notify(force: true);
    if (startNow) start(task);
    return task;
  }

  Future<DownloadTask> addMagnet({
    required String url,
    String directory = '',
    bool startNow = true,
  }) async {
    final trimmed = url.trim();
    if (!trimmed.startsWith('magnet:')) {
      throw const FormatException('无效的磁力链接');
    }
    final uri = Uri.parse(trimmed);
    final hash = uri.queryParametersAll['xt']?.firstWhere(
      (value) => value.toLowerCase().startsWith('urn:btih:'),
      orElse: () => '',
    );
    final directoryValue = directory.isNotEmpty
        ? directory
        : defaultDirectoryGetter();
    final name =
        uri.queryParameters['dn'] ??
        (hash != null && hash.length > 9 ? hash.substring(9, 17) : 'magnet');
    final task = _newTask(
      url: trimmed,
      name: name,
      directory: directoryValue,
      kind: TaskKind.magnet,
    );
    tasks.add(task);
    _markDirty();
    _notify(force: true);
    if (startNow) start(task);
    return task;
  }

  // ---------------------------------------------------------------------------
  // Queue control
  // ---------------------------------------------------------------------------

  void start(DownloadTask task) {
    if (!tasks.contains(task)) return;
    if (task.status.isActive) return;
    if (task.status == TaskStatus.completed) return;
    if (task.isTorrent) {
      _startTorrent(task);
      return;
    }
    if (_workers.containsKey(task.id)) return;
    if (activeCount >= settingsGetter().maxConcurrent) {
      task.status = TaskStatus.queued;
      task.message = '等待队列';
      _notify(force: true);
      return;
    }
    if (settingsGetter().maxConcurrentPerHost > 0 &&
        _hostActive(task) >= settingsGetter().maxConcurrentPerHost) {
      task.status = TaskStatus.queued;
      task.message = '等待队列（该站点并发已满）';
      _notify(force: true);
      return;
    }
    _launchWorker(task);
  }

  void _startTorrent(DownloadTask task) {
    if (settingsGetter().maxConcurrent > 0 &&
        activeCount >= settingsGetter().maxConcurrent) {
      task.status = TaskStatus.queued;
      task.message = '等待队列';
      _notify(force: true);
      return;
    }
    task.status = TaskStatus.connecting;
    task.message = '正在准备种子…';
    task.speed = 0;
    _notify(force: true);
    _ensureService();
    unawaited(torrents.start(task));
    _markDirty();
  }

  void _launchWorker(DownloadTask task) {
    task.status = TaskStatus.connecting;
    task.message = '正在连接…';
    task.speed = 0;
    _notify(force: true);
    _ensureService();
    final worker = DownloadWorker(
      task: task,
      settings: () => settingsGetter(),
      defaultDirectory: () => defaultDirectoryGetter(),
      notify: () {
        _markDirty();
        _notify();
      },
      onPersist: saveNow,
      onFinished: () => _onWorkerFinished(task),
      isWifi: () => _onWifi,
    );
    _workers[task.id] = worker;
    unawaited(worker.start());
    _markDirty();
  }

  void _onWorkerFinished(DownloadTask task) {
    _workers.remove(task.id);
    if (task.status == TaskStatus.completed) {
      unawaited(notifications.showCompleted(task));
      task.segments.clear();
    } else if (task.status == TaskStatus.error) {
      unawaited(notifications.showError(task));
    }
    saveNow();
    _schedule();
    _updateService();
    _notify(force: true);
  }

  Future<void> pause(DownloadTask task) async {
    if (task.isTorrent) {
      await torrents.pause(task);
      saveNow();
      _updateService();
      _notify(force: true);
      return;
    }
    final worker = _workers.remove(task.id);
    if (worker != null) {
      await worker.pause();
    }
    if (task.status != TaskStatus.completed) {
      task.status = TaskStatus.paused;
      task.message = '已暂停';
      task.speed = 0;
    }
    saveNow();
    _updateService();
    _notify(force: true);
  }

  Future<void> retry(DownloadTask task) async {
    if (task.status == TaskStatus.completed) return;
    task.message = '';
    if (task.isTorrent) {
      await torrents.remove(task, deleteFiles: false);
      task.status = TaskStatus.queued;
      start(task);
      return;
    }
    if (task.segments.isNotEmpty &&
        task.segments.every((s) => s.status == SegmentStatus.error)) {
      for (final segment in task.segments) {
        segment.status = SegmentStatus.idle;
      }
    }
    task.status = TaskStatus.queued;
    start(task);
    _notify(force: true);
  }

  Future<void> remove(DownloadTask task, {bool deleteFile = true}) async {
    final worker = _workers.remove(task.id);
    if (worker != null) {
      await worker.pause();
    }
    await torrents.remove(task, deleteFiles: deleteFile);
    tasks.remove(task);
    await notifications.cancel(task);
    if (deleteFile) {
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
    saveNow();
    _schedule();
    _updateService();
    _notify(force: true);
  }

  void startAll() {
    for (final task in tasks) {
      if (task.status == TaskStatus.completed) continue;
      if (task.status.isActive) continue;
      task.status = TaskStatus.queued;
      task.message = '等待队列';
    }
    _schedule(force: true);
    _notify(force: true);
  }

  Future<void> pauseAll() async {
    for (final task in tasks.toList()) {
      if (task.status.isActive || task.status == TaskStatus.queued) {
        await pause(task);
      }
    }
  }

  Future<void> clearCompleted() async {
    for (final task in tasks.where((t) => t.isFinished).toList()) {
      await remove(task, deleteFile: false);
    }
  }

  void _schedule({bool force = false}) {
    final max = settingsGetter().maxConcurrent;
    if (max <= 0) return;
    while (activeCount < max) {
      final candidate = tasks.firstWhere(
        (t) => t.status == TaskStatus.queued,
        orElse: () => _missingTask,
      );
      if (identical(candidate, _missingTask)) break;
      if (!force &&
          settingsGetter().maxConcurrentPerHost > 0 &&
          _hostActive(candidate) >= settingsGetter().maxConcurrentPerHost) {
        break;
      }
      if (candidate.isTorrent) {
        _startTorrent(candidate);
      } else {
        _launchWorker(candidate);
      }
      if (candidate.status == TaskStatus.queued) break;
    }
  }

  static final DownloadTask _missingTask = DownloadTask(
    id: '__missing__',
    url: '',
    name: '',
    directory: '',
    filePath: '',
  );

  int _hostActive(DownloadTask task) {
    final host = Uri.tryParse(task.url)?.host ?? '';
    return tasks.where((t) {
      if (!t.status.occupiesSlot) return false;
      return (Uri.tryParse(t.url)?.host ?? '') == host;
    }).length;
  }

  // ---------------------------------------------------------------------------
  // Settings / lifecycle
  // ---------------------------------------------------------------------------

  void onSettingsChanged() {
    if (!_ready) return;
    _schedule();
    _notify(force: true);
  }

  void _markDirty() {
    _dirty = true;
  }

  void saveNow() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _dirty = false;
    unawaited(store.save(tasks));
  }

  Future<void> persistNow() async {
    await store.save(tasks);
    _dirty = false;
  }

  // ---------------------------------------------------------------------------
  // Periodic housekeeping
  // ---------------------------------------------------------------------------

  void _tick() {
    if (!_ready) return;
    final now = DateTime.now();
    if (_dirty && now.difference(_lastNotify).inMilliseconds > 900) {
      _lastNotify = now;
      _notify();
    }
    if (_dirty &&
        now.difference(_lastNotificationUpdate).inMilliseconds >= 2000) {
      _lastNotificationUpdate = now;
      if (settingsGetter().notifications) {
        var count = 0;
        for (final task in tasks) {
          if (task.status.isActive && count < 3) {
            unawaited(notifications.updateTask(task));
            count++;
          }
        }
      }
    }
    if (_dirty) {
      _saveTimer ??= Timer(const Duration(seconds: 5), () {
        if (_dirty) saveNow();
      });
    }
    _schedule();
    _updateService();
  }

  void _ensureService() {
    if (_serviceRunning) return;
    _serviceRunning = true;
    unawaited(native.startForegroundService());
  }

  void _updateService() {
    if (activeCount > 0 || _workers.isNotEmpty) {
      _ensureService();
    } else if (_serviceRunning) {
      _serviceRunning = false;
      unawaited(native.stopForegroundService());
    }
  }

  void _notify({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastNotify).inMilliseconds < 300) return;
    _lastNotify = now;
    notifyListeners();
  }

  Future<void> disposeManager() async {
    _ticker?.cancel();
    _saveTimer?.cancel();
    await _connectivitySub?.cancel();
    for (final worker in _workers.values) {
      await worker.pause();
    }
    _workers.clear();
    await torrents.dispose();
    await persistNow();
    await native.stopForegroundService();
    _serviceRunning = false;
  }

  /// Default directory helper used by [AppState] during startup.
  static Future<String> platformDefaultDirectory() async {
    String base;
    try {
      if (Platform.isAndroid) {
        final dir = await getExternalStorageDirectory();
        base = dir?.path ?? (await getApplicationDocumentsDirectory()).path;
      } else {
        final dir = await getDownloadsDirectory();
        base = dir?.path ?? (await getApplicationDocumentsDirectory()).path;
      }
    } catch (_) {
      base = (await getApplicationDocumentsDirectory()).path;
    }
    final target = p.join(base, 'Aero');
    await Directory(target).create(recursive: true);
    return target;
  }

  String get appVersion => kAppVersion;
}
