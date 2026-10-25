import 'dart:io';

import 'package:flutter/services.dart';

/// Android-only bridge for the foreground service and share/open-with intents.
///
/// All methods are no-ops on Linux/Windows, which keeps the shared app code
/// platform agnostic.
class NativeBridge {
  NativeBridge._();

  static final NativeBridge instance = NativeBridge._();

  static const MethodChannel _channel = MethodChannel('com.voxyn.aero/native');

  bool _initialized = false;
  void Function(List<String> payload)? onShared;

  bool get isSupported => Platform.isAndroid;

  Future<void> init({void Function(List<String> payload)? onShared}) async {
    this.onShared = onShared;
    if (!isSupported || _initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') {
        final args = call.arguments;
        if (args is List) {
          final payload = args.whereType<String>().toList();
          if (payload.isNotEmpty) {
            this.onShared?.call(payload);
          }
        }
      }
      return null;
    });
  }

  Future<List<String>> initialShared() async {
    if (!isSupported) return const [];
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getInitialShared',
      );
      return result?.whereType<String>().toList() ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> startForegroundService() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('startService');
    } catch (_) {
      // Ignore: downloads still run while the app is in the foreground.
    }
  }

  Future<void> stopForegroundService() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('stopService');
    } catch (_) {
      // ignore
    }
  }
}
