import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/download_task.dart';
import '../../utils/formatters.dart';

/// Android progress notifications. Desktop platforms skip notifications to keep
/// the dependency surface small; the in-app UI is always authoritative.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (!Platform.isAndroid) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: android),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      final impl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await impl?.requestNotificationsPermission();
    } catch (_) {
      // ignore
    }
  }

  int _id(DownloadTask task) => task.id.hashCode & 0x7fffffff;

  Future<void> updateTask(DownloadTask task) async {
    if (!_ready) return;
    final progress = (task.progress * 1000).round().clamp(0, 1000);
    final details = AndroidNotificationDetails(
      'aero_downloads',
      '下载任务',
      channelDescription: '显示正在进行的下载与完成提醒',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 1000,
      progress: progress,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
    );
    final bodyParts = <String>[
      formatPercent(task.progress),
      if (task.total > 0)
        '${formatBytes(task.downloaded)} / ${formatBytes(task.total)}',
      formatSpeed(task.speed),
      if (task.eta != null) '剩余 ${formatDuration(task.eta!.inMilliseconds)}',
    ];
    try {
      await _plugin.show(
        id: _id(task),
        title: task.displayName,
        body: bodyParts.join(' · '),
        notificationDetails: NotificationDetails(android: details),
      );
    } catch (_) {
      // ignore
    }
  }

  Future<void> showCompleted(DownloadTask task) async {
    if (!_ready) return;
    const details = AndroidNotificationDetails(
      'aero_completed',
      '下载完成',
      channelDescription: '下载完成提醒',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      autoCancel: true,
      icon: '@mipmap/ic_launcher',
    );
    try {
      await _plugin.show(
        id: _id(task),
        title: '下载完成',
        body: task.displayName,
        notificationDetails: const NotificationDetails(android: details),
      );
    } catch (_) {
      // ignore
    }
  }

  Future<void> showError(DownloadTask task) async {
    if (!_ready) return;
    const details = AndroidNotificationDetails(
      'aero_errors',
      '下载错误',
      channelDescription: '任务失败提醒',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      autoCancel: true,
      icon: '@mipmap/ic_launcher',
    );
    try {
      await _plugin.show(
        id: _id(task),
        title: '下载失败',
        body: '${task.displayName}\n${task.message}',
        notificationDetails: const NotificationDetails(android: details),
      );
    } catch (_) {
      // ignore
    }
  }

  Future<void> cancel(DownloadTask task) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _id(task));
    } catch (_) {
      // ignore
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // ignore
    }
  }
}
