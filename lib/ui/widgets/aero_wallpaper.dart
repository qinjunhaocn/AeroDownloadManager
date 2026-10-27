import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Soft, slowly drifting colour blobs behind the whole app. The blobs are
/// blurred with a real gaussian filter when blur is enabled, which gives every
/// translucent surface (app bars, navigation bar, drawer, sheets) something
/// visible to frost.
class AeroWallpaper extends StatefulWidget {
  const AeroWallpaper({
    super.key,
    required this.animations,
    required this.blur,
    required this.sigma,
  });

  final bool animations;
  final bool blur;
  final double sigma;

  @override
  State<AeroWallpaper> createState() => _AeroWallpaperState();
}

class _AeroWallpaperState extends State<AeroWallpaper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    );
    _syncController();
  }

  @override
  void didUpdateWidget(covariant AeroWallpaper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController();
  }

  void _syncController() {
    if (widget.animations && widget.blur) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!widget.blur) {
      return ColoredBox(color: scheme.surface);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * math.pi * 2;
        final blobs = Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: scheme.surface),
            _Blob(
              color: scheme.primary,
              size: 340,
              alignment: Alignment.topLeft,
              offset: Offset(
                math.sin(angle) * 26 - 80,
                math.cos(angle) * 30 - 60,
              ),
            ),
            _Blob(
              color: scheme.tertiary,
              size: 300,
              alignment: Alignment.bottomRight,
              offset: Offset(
                math.cos(angle + 1.1) * 28 + 90,
                math.sin(angle + 0.7) * 34 + 80,
              ),
            ),
            _Blob(
              color: scheme.secondary,
              size: 240,
              alignment: Alignment.centerRight,
              offset: Offset(
                math.sin(angle + 2.2) * 24 + 40,
                math.cos(angle + 1.8) * 20,
              ),
            ),
          ],
        );
        return ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: widget.sigma.clamp(2, 40),
            sigmaY: widget.sigma.clamp(2, 40),
          ),
          child: blobs,
        );
      },
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.color,
    required this.size,
    required this.alignment,
    required this.offset,
  });

  final Color color;
  final double size;
  final Alignment alignment;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.30),
          ),
        ),
      ),
    );
  }
}
