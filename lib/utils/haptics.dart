import 'dart:io';

import 'package:flutter/services.dart';

/// Centralised haptic feedback so it can respect the user's preference and is
/// a no-op on desktop platforms.
class Haptics {
  const Haptics._();

  static bool enabled = true;

  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  static void select() {
    if (!enabled || !_supported) return;
    HapticFeedback.selectionClick();
  }

  static void tap() {
    if (!enabled || !_supported) return;
    HapticFeedback.lightImpact();
  }

  static void medium() {
    if (!enabled || !_supported) return;
    HapticFeedback.mediumImpact();
  }

  static void success() {
    if (!enabled || !_supported) return;
    HapticFeedback.heavyImpact();
  }
}
