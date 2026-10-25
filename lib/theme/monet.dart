import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

/// Builds a Material 3 [ColorScheme] from the platform's dynamic colour
/// (Android Monet, Windows accent, desktop accent on GTK) with a graceful
/// fallback to the selected seed colour.
class MonetService {
  const MonetService._();

  static ColorScheme? _lightCache;
  static ColorScheme? _darkCache;
  static bool _attempted = false;

  static bool get hasResult => _attempted;

  static Future<void> ensureLoaded() async {
    if (_attempted) return;
    _attempted = true;
    try {
      final palette = await DynamicColorPlugin.getCorePalette();
      if (palette != null) {
        final seed = Color(palette.primary.get(40));
        _lightCache = ColorScheme.fromSeed(seedColor: seed);
        _darkCache = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        );
        return;
      }
      final accent = await DynamicColorPlugin.getAccentColor();
      if (accent != null) {
        _lightCache = ColorScheme.fromSeed(seedColor: accent);
        _darkCache = ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        );
      }
    } catch (_) {
      // Dynamic colour is optional.
    }
  }

  static ColorScheme? scheme(Brightness brightness) =>
      brightness == Brightness.dark ? _darkCache : _lightCache;
}
