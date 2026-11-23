import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Renders the animated Watch Tower Metal Wizard underground forge scene
/// (`assets/images/story/intro_1.jpeg`) with a gentle ambient pan/zoom motion
/// in the circular spyglass lens and a 60 FPS [CustomPainter] rendering rising
/// glowing embers, welding sparks, and warm pulsing firelight.
class WatchtowerForgeView extends StatefulWidget {
  final bool animationsEnabled;
  final bool isFullScreen;
  final bool isCoolingDown;

  const WatchtowerForgeView({
    super.key,
    this.animationsEnabled = true,
    this.isFullScreen = false,
    this.isCoolingDown = false,
  });

  @override
  State<WatchtowerForgeView> createState() => _WatchtowerForgeViewState();
}

class _WatchtowerForgeViewState extends State<WatchtowerForgeView>
    with SingleTickerProviderStateMixin {
  static const String _forgeAsset = 'assets/images/story/intro_1.jpeg';

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant WatchtowerForgeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationsEnabled != widget.animationsEnabled) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.animationsEnabled) {
      if (!_animController.isAnimating) {
        _animController.repeat();
      }
    } else {
      if (_animController.isAnimating) {
        _animController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        key: const ValueKey('watchtower_forge_view_stack'),
        fit: StackFit.expand,
        children: [
          // Artwork with gentle slow ambient pan/zoom in the circular lens
          if (widget.isFullScreen)
            Image.asset(
              _forgeAsset,
              key: const ValueKey('watchtower_forge_image'),
              fit: BoxFit.cover,
            )
          else
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                final t = widget.animationsEnabled ? _animController.value : 0.0;
                final angle = t * 2.0 * math.pi;
                final scale = widget.animationsEnabled
                    ? 1.10 + 0.04 * math.sin(angle)
                    : 1.06;
                final dx = widget.animationsEnabled
                    ? 6.0 * math.sin(angle)
                    : 0.0;
                final dy = widget.animationsEnabled
                    ? 4.0 * math.cos(angle * 0.5)
                    : 0.0;
                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                );
              },
              child: Image.asset(
                _forgeAsset,
                key: const ValueKey('watchtower_forge_image'),
                fit: BoxFit.cover,
              ),
            ),

          // 60 FPS Forge Embers, Welding Sparks, Warm Firelight & Optical Vignette
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey('watchtower_forge_vfx_paint'),
                painter: _ForgeSpyglassVfxPainter(
                  progress: _animController,
                  animationsEnabled: widget.animationsEnabled,
                  isFullScreen: widget.isFullScreen,
                  isCoolingDown: widget.isCoolingDown,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForgeSpyglassVfxPainter extends CustomPainter {
  final Animation<double> progress;
  final bool animationsEnabled;
  final bool isFullScreen;
  final bool isCoolingDown;

  _ForgeSpyglassVfxPainter({
    required this.progress,
    required this.animationsEnabled,
    required this.isFullScreen,
    required this.isCoolingDown,
  }) : super(repaint: progress);

  static const List<
    ({double x, double yStart, double speed, double phase, double radius, double sway})
  > _emberSpecs = [
    (x: 0.10, yStart: 0.88, speed: 1.0, phase: 0.04, radius: 1.9, sway: 7.0),
    (x: 0.14, yStart: 0.82, speed: 1.2, phase: 0.37, radius: 1.4, sway: 5.5),
    (x: 0.24, yStart: 0.90, speed: 0.9, phase: 0.62, radius: 1.6, sway: 6.5),
    (x: 0.42, yStart: 0.86, speed: 1.1, phase: 0.19, radius: 1.5, sway: 8.0),
    (x: 0.55, yStart: 0.84, speed: 1.3, phase: 0.78, radius: 1.7, sway: 7.5),
    (x: 0.66, yStart: 0.92, speed: 1.0, phase: 0.46, radius: 1.4, sway: 6.0),
    (x: 0.74, yStart: 0.86, speed: 1.4, phase: 0.11, radius: 2.0, sway: 9.0),
    (x: 0.80, yStart: 0.80, speed: 1.2, phase: 0.53, radius: 2.2, sway: 10.0),
    (x: 0.85, yStart: 0.78, speed: 1.5, phase: 0.28, radius: 1.8, sway: 8.5),
    (x: 0.90, yStart: 0.84, speed: 1.1, phase: 0.89, radius: 1.6, sway: 7.0),
    (x: 0.83, yStart: 0.70, speed: 1.3, phase: 0.67, radius: 1.5, sway: 8.0),
    (x: 0.12, yStart: 0.66, speed: 1.1, phase: 0.91, radius: 1.5, sway: 5.0),
    (x: 0.48, yStart: 0.74, speed: 0.95, phase: 0.33, radius: 1.3, sway: 6.5),
    (x: 0.77, yStart: 0.88, speed: 1.35, phase: 0.74, radius: 1.8, sway: 9.5),
    (x: 0.88, yStart: 0.74, speed: 1.25, phase: 0.16, radius: 1.4, sway: 7.5),
    (x: 0.62, yStart: 0.78, speed: 1.05, phase: 0.58, radius: 1.6, sway: 7.0),
  ];

  static const List<
    ({double x, double y, double dx, double dy, double phase})
  > _sparkSpecs = [
    (x: 0.82, y: 0.68, dx: -16.0, dy: -20.0, phase: 0.08),
    (x: 0.86, y: 0.65, dx: 14.0, dy: -22.0, phase: 0.29),
    (x: 0.79, y: 0.74, dx: -18.0, dy: -14.0, phase: 0.52),
    (x: 0.89, y: 0.71, dx: 12.0, dy: -18.0, phase: 0.76),
    (x: 0.58, y: 0.66, dx: -14.0, dy: -16.0, phase: 0.41),
    (x: 0.52, y: 0.62, dx: 13.0, dy: -19.0, phase: 0.84),
    (x: 0.11, y: 0.82, dx: 12.0, dy: -15.0, phase: 0.19),
    (x: 0.13, y: 0.78, dx: -10.0, dy: -17.0, phase: 0.63),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final t = animationsEnabled ? progress.value : 0.25;
    final firePulse = 0.5 + 0.5 * math.sin(t * 6.0 * math.pi);
    final intensity = isCoolingDown ? 0.42 : 1.0;

    // 1. Warm pulsing firelight overlays (furnace on right & lava fall on left)
    final furnaceCenter = Offset(size.width * 0.86, size.height * 0.72);
    final furnaceRadius = size.shortestSide * 0.42;
    canvas.drawCircle(
      furnaceCenter,
      furnaceRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF6D00).withValues(
              alpha: (0.16 + 0.10 * firePulse) * intensity,
            ),
            const Color(0xFFFFAB00).withValues(
              alpha: (0.07 + 0.04 * firePulse) * intensity,
            ),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(
          Rect.fromCircle(center: furnaceCenter, radius: furnaceRadius),
        ),
    );

    final lavaCenter = Offset(size.width * 0.11, size.height * 0.58);
    final lavaRadius = size.shortestSide * 0.34;
    canvas.drawCircle(
      lavaCenter,
      lavaRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF3D00).withValues(
              alpha: (0.12 + 0.07 * firePulse) * intensity,
            ),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: lavaCenter, radius: lavaRadius),
        ),
    );

    // 2. Rising glowing orange & gold embers
    final emberScale = isFullScreen ? 1.35 : 1.0;
    for (final spec in _emberSpecs) {
      final cycle = (t * spec.speed + spec.phase) % 1.0;
      final y = size.height * (spec.yStart - 0.62 * cycle);
      final x = size.width * spec.x +
          math.sin(cycle * 2.0 * math.pi + spec.phase * 9.0) *
              spec.sway *
              emberScale;
      final fade = math.sin(cycle * math.pi).clamp(0.0, 1.0);
      final alpha = (0.82 * fade * intensity).clamp(0.0, 1.0);
      if (alpha <= 0.02) continue;

      final pos = Offset(x, y);
      final r = spec.radius * emberScale;
      canvas.drawCircle(
        pos,
        r * 2.5,
        Paint()
          ..color = const Color(0xFFFF6D00).withValues(alpha: alpha * 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawCircle(
        pos,
        r,
        Paint()..color = const Color(0xFFFFD54F).withValues(alpha: alpha),
      );
    }

    // 3. Sharp directional welding / forge sparks
    if (!isCoolingDown) {
      for (final spark in _sparkSpecs) {
        final cycle = (t * 2.0 + spark.phase) % 1.0;
        // Brief bright burst window (0.0 .. 0.35 of cycle)
        if (cycle > 0.35) continue;
        final u = cycle / 0.35;
        final fade = (1.0 - u).clamp(0.0, 1.0);
        final start = Offset(
          size.width * spark.x + spark.dx * u * emberScale,
          size.height * spark.y + spark.dy * u * emberScale + (u * u * 10.0),
        );
        final tail = Offset(
          start.dx - spark.dx * 0.22 * emberScale,
          start.dy - spark.dy * 0.22 * emberScale,
        );
        canvas.drawLine(
          tail,
          start,
          Paint()
            ..color = const Color(0xFFFFF59D).withValues(alpha: fade * 0.90)
            ..strokeWidth = 1.6 * emberScale
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // 4. Spyglass optical vignette overlay
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = (isFullScreen
                ? RadialGradient(
                    radius: 1.15,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.36),
                    ],
                    stops: const [0.0, 0.62, 1.0],
                  )
                : RadialGradient(
                    radius: 0.92,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      const Color(0xFF04141C).withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.62, 0.86, 1.0],
                  ))
            .createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _ForgeSpyglassVfxPainter oldDelegate) {
    return oldDelegate.animationsEnabled != animationsEnabled ||
        oldDelegate.isFullScreen != isFullScreen ||
        oldDelegate.isCoolingDown != isCoolingDown;
  }
}
