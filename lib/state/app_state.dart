import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/engine/download_manager.dart';
import '../core/engine/task_store.dart';
import '../core/models/app_settings.dart';
import '../core/models/download_task.dart';
import '../core/platform/native_bridge.dart';
import '../core/platform/notifications.dart';
import '../utils/file_types.dart';

enum TaskFilter { all, active, queued, completed, error, torrents }

enum TaskSort { newest, oldest, name, size, progress }

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  late AppSettings settings;
  late DownloadManager manager;
  late NotificationService notifications;
  Directory? _supportDirectory;

  bool _initialized = false;
  bool get initialized => _initialized;

  TaskFilter filter = TaskFilter.all;
  DownloadCategory? categoryFilter;
  TaskSort sort = TaskSort.newest;
  String searchQuery = '';

  final Set<String> selectedIds = {};

  String? clipboardUrl;
  String? lastClipboardText;

  final List<String> pendingIncomingUrls = [];

  bool get selectionMode => selectedIds.isNotEmpty;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    settings = await AppSettings.load();
    _supportDirectory = await getApplicationSupportDirectory();
    final stateDir = Directory(p.join(_supportDirectory!.path, 'state'));
    final store = TaskStore(stateDir);
    notifications = NotificationService();
    await notifications.init();
    if (Platform.isAndroid) {
      unawaited(notifications.requestPermission());
    }
    final native = NativeBridge.instance;
    await native.init(onShared: _onSharedPayload);

    await prepareDefaultDirectory();
    manager = DownloadManager(
      store: store,
      notifications: notifications,
      native: native,
      settingsGetter: () => settings,
      defaultDirectoryGetter: _defaultDirectory,
    );
    manager.addListener(notifyListeners);
    await manager.init();

    _initialized = true;
    final initial = await native.initialShared();
    if (initial.isNotEmpty) _onSharedPayload(initial);
    notifyListeners();
  }

  String _defaultDirectory() {
    if (settings.downloadDir.isNotEmpty) return settings.downloadDir;
    // Resolved once at startup by main(); DownloadManager falls back to its
    // own resolver when this returns an empty string.
    return _fallbackDirectory ?? '';
  }

  String? _fallbackDirectory;

  Future<void> prepareDefaultDirectory() async {
    _fallbackDirectory = await DownloadManager.platformDefaultDirectory();
    if (settings.downloadDir.isEmpty) {
      settings.downloadDir = _fallbackDirectory!;
      await settings.save();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Incoming links (share / open-with / clipboard)
  // ---------------------------------------------------------------------------

  void _onSharedPayload(List<String> payload) {
    if (!_initialized) {
      pendingIncomingUrls.addAll(payload);
      return;
    }
    for (final item in payload) {
      final value = item.trim();
      if (value.isEmpty) continue;
      final lower = value.toLowerCase();
      if (lower.startsWith('magnet:')) {
        unawaited(manager.addMagnet(url: value));
      } else if (lower.startsWith('http://') || lower.startsWith('https://')) {
        if (lower.contains('.torrent')) {
          unawaited(manager.addTorrentUrl(url: value));
        } else {
          pendingIncomingUrls.add(value);
          notifyListeners();
        }
      } else if (File(value).existsSync() && lower.endsWith('.torrent')) {
        unawaited(manager.addTorrentFile(path: value));
      }
    }
  }

  String? takeIncomingUrl() {
    if (pendingIncomingUrls.isEmpty) return null;
    return pendingIncomingUrls.removeAt(0);
  }

  Future<void> checkClipboard() async {
    if (!settings.clipboardWatch) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty || text == lastClipboardText) return;
      lastClipboardText = text;
      final lower = text.toLowerCase();
      if (lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('magnet:')) {
        clipboardUrl = text;
        notifyListeners();
      }
    } catch (_) {
      // ignore
    }
  }

  void dismissClipboard() {
    clipboardUrl = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Filtering / selection
  // ---------------------------------------------------------------------------

  List<DownloadTask> get visibleTasks {
    final list = manager.tasks.where((task) {
      switch (filter) {
        case TaskFilter.active:
          if (!(task.status.occupiesSlot)) return false;
          break;
        case TaskFilter.queued:
          if (task.status != TaskStatus.queued) return false;
          break;
        case TaskFilter.completed:
          if (!task.isFinished) return false;
          break;
        case TaskFilter.error:
          if (task.status != TaskStatus.error) return false;
          break;
        case TaskFilter.torrents:
          if (!task.isTorrent) return false;
          break;
        case TaskFilter.all:
          break;
      }
      if (categoryFilter != null && task.category != categoryFilter) {
        return false;
      }
      if (searchQuery.trim().isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!task.name.toLowerCase().contains(query) &&
            !task.url.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (sort) {
      case TaskSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case TaskSort.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case TaskSort.name:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case TaskSort.size:
        list.sort((a, b) => b.total.compareTo(a.total));
        break;
      case TaskSort.progress:
        list.sort((a, b) => b.progress.compareTo(a.progress));
        break;
    }
    return list;
  }

  int countFor(TaskFilter value) {
    switch (value) {
      case TaskFilter.all:
        return manager.tasks.length;
      case TaskFilter.active:
        return manager.activeCount;
      case TaskFilter.queued:
        return manager.queuedCount;
      case TaskFilter.completed:
        return manager.completedCount;
      case TaskFilter.error:
        return manager.errorCount;
      case TaskFilter.torrents:
        return manager.tasks.where((t) => t.isTorrent).length;
    }
  }

  void setFilter(TaskFilter value) {
    filter = value;
    categoryFilter = null;
    notifyListeners();
  }

  void setCategory(DownloadCategory? value) {
    categoryFilter = value;
    filter = TaskFilter.all;
    notifyListeners();
  }

  void setSort(TaskSort value) {
    sort = value;
    notifyListeners();
  }

  void setSearch(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (!selectedIds.add(id)) {
      selectedIds.remove(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    selectedIds.clear();
    notifyListeners();
  }

  void selectAll() {
    selectedIds
      ..clear()
      ..addAll(visibleTasks.map((t) => t.id));
    notifyListeners();
  }

  List<DownloadTask> get selectedTasks =>
      manager.tasks.where((t) => selectedIds.contains(t.id)).toList();

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    await settings.save();
    manager.onSettingsChanged();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await updateSettings(settings.copyWith(themeMode: mode));
  }

  Future<void> setMonet(bool enabled) async {
    await updateSettings(settings.copyWith(monet: enabled));
  }

  Future<void> setSeedColor(int color) async {
    await updateSettings(settings.copyWith(seedColor: color));
  }

  bool get isDark {
    if (settings.themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return settings.themeMode == ThemeMode.dark;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(checkClipboard());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(manager.persistNow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    manager.removeListener(notifyListeners);
    unawaited(manager.disposeManager());
    super.dispose();
  }
}
