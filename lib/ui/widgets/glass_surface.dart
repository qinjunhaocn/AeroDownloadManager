import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

/// Frosted-glass surface. Falls back to an opaque material when the user turns
/// blur off, so callers can always wrap content in it.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.tint,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.select<AppState, bool>((s) => s.settings.blur);
    final sigma = context.select<AppState, double>((s) => s.settings.blurSigma);
    final base = tint ?? scheme.surface;
    final content = Material(
      color: base.withValues(alpha: settings ? 0.72 : 0.98),
      elevation: 0,
      child: child,
    );
    final clipped = ClipRRect(borderRadius: borderRadius, child: content);
    if (!settings) return clipped;
    final value = sigma.clamp(2.0, 40.0);
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: value, sigmaY: value),
        child: content,
      ),
    );
  }
}
