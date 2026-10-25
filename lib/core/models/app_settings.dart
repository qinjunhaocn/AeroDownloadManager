import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/constants.dart';

class AppSettings {
  AppSettings({
    this.themeMode = ThemeMode.system,
    this.monet = true,
    this.seedColor = 0xFF006A6A,
    this.maxConcurrent = 2,
    this.maxConcurrentPerHost = 0,
    this.threads = 6,
    this.minSegmentKB = 512,
    this.maxRetries = 10,
    this.timeoutSec = 16,
    this.algorithm = 0,
    this.speedLimitKBps = 0,
    this.wifiOnly = false,
    this.autoStart = false,
    this.autoRetry = true,
    this.preallocate = true,
    this.notifications = true,
    this.haptics = true,
    this.predictiveBack = false,
    this.clipboardWatch = false,
    this.confirmDelete = true,
    this.downloadDir = '',
    this.browserHome = 'https://www.google.com',
    this.proxy = '',
    this.userAgent = kDefaultUserAgent,
  });

  ThemeMode themeMode;
  bool monet;
  int seedColor;

  int maxConcurrent;
  int maxConcurrentPerHost;
  int threads;
  int minSegmentKB;
  int maxRetries;
  int timeoutSec;

  /// 0 = classic (split once), 1 = smart (split while running).
  int algorithm;

  /// 0 = unlimited.
  int speedLimitKBps;

  bool wifiOnly;
  bool autoStart;
  bool autoRetry;
  bool preallocate;
  bool notifications;
  bool haptics;
  bool predictiveBack;
  bool clipboardWatch;
  bool confirmDelete;

  String downloadDir;
  String browserHome;
  String proxy;
  String userAgent;

  int get minSegmentBytes => minSegmentKB * 1024;
  int get speedLimitBytesPerSecond => speedLimitKBps * 1024;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? monet,
    int? seedColor,
    int? maxConcurrent,
    int? maxConcurrentPerHost,
    int? threads,
    int? minSegmentKB,
    int? maxRetries,
    int? timeoutSec,
    int? algorithm,
    int? speedLimitKBps,
    bool? wifiOnly,
    bool? autoStart,
    bool? autoRetry,
    bool? preallocate,
    bool? notifications,
    bool? haptics,
    bool? predictiveBack,
    bool? clipboardWatch,
    bool? confirmDelete,
    String? downloadDir,
    String? browserHome,
    String? proxy,
    String? userAgent,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      monet: monet ?? this.monet,
      seedColor: seedColor ?? this.seedColor,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      maxConcurrentPerHost: maxConcurrentPerHost ?? this.maxConcurrentPerHost,
      threads: threads ?? this.threads,
      minSegmentKB: minSegmentKB ?? this.minSegmentKB,
      maxRetries: maxRetries ?? this.maxRetries,
      timeoutSec: timeoutSec ?? this.timeoutSec,
      algorithm: algorithm ?? this.algorithm,
      speedLimitKBps: speedLimitKBps ?? this.speedLimitKBps,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      autoStart: autoStart ?? this.autoStart,
      autoRetry: autoRetry ?? this.autoRetry,
      preallocate: preallocate ?? this.preallocate,
      notifications: notifications ?? this.notifications,
      haptics: haptics ?? this.haptics,
      predictiveBack: predictiveBack ?? this.predictiveBack,
      clipboardWatch: clipboardWatch ?? this.clipboardWatch,
      confirmDelete: confirmDelete ?? this.confirmDelete,
      downloadDir: downloadDir ?? this.downloadDir,
      browserHome: browserHome ?? this.browserHome,
      proxy: proxy ?? this.proxy,
      userAgent: userAgent ?? this.userAgent,
    );
  }

  Map<String, dynamic> toJson() => {
    'theme': themeMode.index,
    'monet': monet,
    'seed': seedColor,
    'maxConcurrent': maxConcurrent,
    'maxPerHost': maxConcurrentPerHost,
    'threads': threads,
    'minSegmentKB': minSegmentKB,
    'maxRetries': maxRetries,
    'timeout': timeoutSec,
    'algorithm': algorithm,
    'speedLimitKBps': speedLimitKBps,
    'wifiOnly': wifiOnly,
    'autoStart': autoStart,
    'autoRetry': autoRetry,
    'preallocate': preallocate,
    'notifications': notifications,
    'clipboardWatch': clipboardWatch,
    'confirmDelete': confirmDelete,
    'downloadDir': downloadDir,
    'browserHome': browserHome,
    'proxy': proxy,
    'userAgent': userAgent,
  };

  static AppSettings fromJson(Map<String, dynamic> json) {
    final settings = AppSettings();
    final theme = (json['theme'] as num?)?.toInt();
    if (theme != null && theme >= 0 && theme < ThemeMode.values.length) {
      settings.themeMode = ThemeMode.values[theme];
    }
    settings.monet = json['monet'] as bool? ?? settings.monet;
    settings.seedColor = (json['seed'] as num?)?.toInt() ?? settings.seedColor;
    settings.maxConcurrent =
        (json['maxConcurrent'] as num?)?.toInt() ?? settings.maxConcurrent;
    settings.maxConcurrentPerHost =
        (json['maxPerHost'] as num?)?.toInt() ?? settings.maxConcurrentPerHost;
    settings.threads = (json['threads'] as num?)?.toInt() ?? settings.threads;
    settings.minSegmentKB =
        (json['minSegmentKB'] as num?)?.toInt() ?? settings.minSegmentKB;
    settings.maxRetries =
        (json['maxRetries'] as num?)?.toInt() ?? settings.maxRetries;
    settings.timeoutSec =
        (json['timeout'] as num?)?.toInt() ?? settings.timeoutSec;
    settings.algorithm =
        (json['algorithm'] as num?)?.toInt() ?? settings.algorithm;
    settings.speedLimitKBps =
        (json['speedLimitKBps'] as num?)?.toInt() ?? settings.speedLimitKBps;
    settings.wifiOnly = json['wifiOnly'] as bool? ?? settings.wifiOnly;
    settings.autoStart = json['autoStart'] as bool? ?? settings.autoStart;
    settings.autoRetry = json['autoRetry'] as bool? ?? settings.autoRetry;
    settings.preallocate = json['preallocate'] as bool? ?? settings.preallocate;
    settings.notifications =
        json['notifications'] as bool? ?? settings.notifications;
    settings.haptics = json['haptics'] as bool? ?? settings.haptics;
    settings.predictiveBack =
        json['predictiveBack'] as bool? ?? settings.predictiveBack;
    settings.clipboardWatch =
        json['clipboardWatch'] as bool? ?? settings.clipboardWatch;
    settings.confirmDelete =
        json['confirmDelete'] as bool? ?? settings.confirmDelete;
    settings.downloadDir =
        json['downloadDir'] as String? ?? settings.downloadDir;
    settings.browserHome =
        json['browserHome'] as String? ?? settings.browserHome;
    settings.proxy = json['proxy'] as String? ?? settings.proxy;
    settings.userAgent = json['userAgent'] as String? ?? settings.userAgent;
    return settings;
  }

  static const String storageKey = 'aero.settings.v1';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return AppSettings();
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(toJson()));
  }
}
