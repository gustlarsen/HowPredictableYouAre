import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Classic RPG swirling arcane teleport portal icon rendered via [CustomPainter]
/// on a transparent background.
///
/// Features:
/// 1. An ornate circular outer stone/dark-bronze metallic frame with subtle
///    golden-amber trim (`#FFB300`), cardinal diamond clasps, and tiny geometric
///    rune accents around the border.
/// 2. An inner swirling spiral vortex blending luminous cyan-blue (`#00E5FF` /
///    `#00B0FF`) and arcane violet/purple (`#9C27B0` / `#7C4DFF`) energy arcs
///    spiraling into a deep indigo center.
/// 3. Subtle golden-amber star sparkles (`#FFD54F`) around the outer rim and
///    a soft cyan/purple radial glow (`BoxShadow`).
class RpgTeleportPortalIcon extends StatelessWidget {
  final double size;
  final bool showGlow;

  const RpgTeleportPortalIcon({
    super.key,
    this.size = 28.0,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final glowDiameter = size * 0.78;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (showGlow)
            Container(
              width: glowDiameter,
              height: glowDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
                    blurRadius: size * 0.32,
                    spreadRadius: size * 0.04,
                  ),
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.38),
                    blurRadius: size * 0.42,
                    spreadRadius: size * 0.06,
                  ),
                ],
              ),
            ),
          RepaintBoundary(
            child: CustomPaint(
              size: Size(size, size),
              painter: const _RpgTeleportPortalPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RpgTeleportPortalPainter extends CustomPainter {
  const _RpgTeleportPortalPainter();

  static const Color _cStoneDark = Color(0xFF2B303A);
  static const Color _cStoneMid = Color(0xFF424957);
  static const Color _cBronzeDark = Color(0xFF4A3519);
  static const Color _cGoldTrim = Color(0xFFFFB300);
  static const Color _cGoldLight = Color(0xFFFFE082);
  static const Color _cSparkleGold = Color(0xFFFFD54F);
  static const Color _cCyanBright = Color(0xFF00E5FF);
  static const Color _cCyanDeep = Color(0xFF00B0FF);
  static const Color _cViolet = Color(0xFF9C27B0);
  static const Color _cPurple = Color(0xFF7C4DFF);
  static const Color _cIndigoCore = Color(0xFF0B0724);
  static const Color _cIndigoMid = Color(0xFF1B1045);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);
    final scale = math.min(w, h) / 28.0;

    final outerFrameRadius = math.min(w, h) * 0.41;
    final innerPortalRadius = outerFrameRadius * 0.74;
    final ringMidRadius = (outerFrameRadius + innerPortalRadius) * 0.5;
    final ringWidth = outerFrameRadius - innerPortalRadius;

    // 1. Subtle outer golden-amber star sparkles & dust motes around the rim
    _paintOuterSparkles(canvas, center, outerFrameRadius, scale);

    // 2. Inner Swirling Arcane Vortex (clipped inside innerPortalRadius)
    final innerCircleRect = Rect.fromCircle(
      center: center,
      radius: innerPortalRadius,
    );
    final innerClip = Path()..addOval(innerCircleRect);

    canvas.save();
    canvas.clipPath(innerClip);

    // Deep indigo to electric blue/violet radial base
    canvas.drawCircle(
      center,
      innerPortalRadius,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            _cIndigoCore,
            _cIndigoMid,
            Color(0xFF192B6B),
            Color(0xFF0088CC),
          ],
          stops: const [0.0, 0.34, 0.72, 1.0],
        ).createShader(innerCircleRect),
    );

    // Soft violet & cyan nebula glows inside the portal
    canvas.drawCircle(
      center + Offset(-innerPortalRadius * 0.25, -innerPortalRadius * 0.18),
      innerPortalRadius * 0.55,
      Paint()
        ..color = _cCyanDeep.withValues(alpha: 0.42)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * scale),
    );
    canvas.drawCircle(
      center + Offset(innerPortalRadius * 0.24, innerPortalRadius * 0.22),
      innerPortalRadius * 0.52,
      Paint()
        ..color = _cViolet.withValues(alpha: 0.48)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * scale),
    );

    // Swirling spiral energy arcs (alternating cyan-blue & arcane violet/purple)
    const armCount = 6;
    for (int i = 0; i < armCount; i++) {
      final baseAngle = (i / armCount) * 2 * math.pi - math.pi / 4;
      final isCyan = i.isEven;
      final primaryArcColor = isCyan ? _cCyanBright : _cPurple;
      final secondaryArcColor = isCyan ? _cCyanDeep : _cViolet;

      final spiralPath = _buildSpiralArmPath(
        center: center,
        startAngle: baseAngle,
        innerR: innerPortalRadius * 0.10,
        outerR: innerPortalRadius * 0.98,
        twistRadians: math.pi * 1.18,
      );

      // Soft colored energy halo along the spiral arm
      canvas.drawPath(
        spiralPath,
        Paint()
          ..color = secondaryArcColor.withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * scale
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.1 * scale),
      );

      // Crisp luminous core filament
      canvas.drawPath(
        spiralPath,
        Paint()
          ..color = Color.lerp(primaryArcColor, Colors.white, isCyan ? 0.32 : 0.18)!
              .withValues(alpha: 0.94)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (isCyan ? 1.25 : 1.05) * scale
          ..strokeCap = StrokeCap.round,
      );
    }

    // Inner bright cyan rim glow inside the stone bezel
    canvas.drawCircle(
      center,
      innerPortalRadius * 0.95,
      Paint()
        ..color = _cCyanBright.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * scale
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.9 * scale),
    );

    // Deep indigo spiral center singularity
    canvas.drawCircle(
      center,
      innerPortalRadius * 0.24,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _cIndigoCore,
            _cIndigoMid.withValues(alpha: 0.85),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: innerPortalRadius * 0.24),
        ),
    );

    // Tiny swirling golden-amber sparks inside the vortex (matching reference)
    final vortexSparks = [
      Offset(-0.42, -0.30),
      Offset(0.36, -0.34),
      Offset(0.28, 0.44),
      Offset(-0.34, 0.38),
    ];
    for (final rel in vortexSparks) {
      canvas.drawCircle(
        center +
            Offset(rel.dx * innerPortalRadius, rel.dy * innerPortalRadius),
        0.7 * scale,
        Paint()..color = _cSparkleGold.withValues(alpha: 0.92),
      );
    }

    canvas.restore();

    // 3. Ornate Circular Outer Stone / Dark-Bronze Metallic Frame
    final outerRect = Rect.fromCircle(center: center, radius: outerFrameRadius);
    canvas.drawCircle(
      center,
      ringMidRadius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cStoneMid, _cStoneDark, _cBronzeDark, _cStoneDark],
          stops: [0.0, 0.38, 0.75, 1.0],
        ).createShader(outerRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth,
    );

    // Subtle dark outer stone outline
    canvas.drawCircle(
      center,
      outerFrameRadius,
      Paint()
        ..color = const Color(0xFF171A21)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, 0.9 * scale),
    );

    // Golden-amber outer & inner metallic trim rings (#FFB300)
    canvas.drawCircle(
      center,
      outerFrameRadius - 0.65 * scale,
      Paint()
        ..color = _cGoldTrim.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, 0.75 * scale),
    );
    canvas.drawCircle(
      center,
      innerPortalRadius + 0.35 * scale,
      Paint()
        ..color = _cGoldLight.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, 0.9 * scale),
    );

    // Tiny geometric rune accents etched around the 4 segments of the frame
    _paintBorderRunes(canvas, center, ringMidRadius, scale);

    // 4 cardinal diamond clasps (North, East, South, West) in golden-amber
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      _paintCardinalDiamond(
        canvas,
        center + Offset(math.cos(angle), math.sin(angle)) * ringMidRadius,
        angle,
        ringWidth * 0.72,
        scale,
      );
    }
  }

  Path _buildSpiralArmPath({
    required Offset center,
    required double startAngle,
    required double innerR,
    required double outerR,
    required double twistRadians,
  }) {
    const steps = 14;
    final path = Path();
    for (int step = 0; step <= steps; step++) {
      final t = step / steps;
      // Ease radius outward while twisting around the center
      final r = innerR + (outerR - innerR) * math.pow(t, 0.88);
      final angle = startAngle + twistRadians * t;
      final point = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      if (step == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  void _paintBorderRunes(
    Canvas canvas,
    Offset center,
    double ringMidRadius,
    double scale,
  ) {
    final runePaint = Paint()
      ..color = _cSparkleGold.withValues(alpha: 0.86)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.55, 0.65 * scale)
      ..strokeCap = StrokeCap.round;

    // 3 tiny geometric rune ticks in each of the 4 quadrants between cardinal clasps
    const offsetsInQuadrant = [0.24, 0.50, 0.76];
    for (int q = 0; q < 4; q++) {
      final quadStart = q * (math.pi / 2);
      for (int r = 0; r < offsetsInQuadrant.length; r++) {
        final angle = quadStart + offsetsInQuadrant[r] * (math.pi / 2);
        final pos = center + Offset(math.cos(angle), math.sin(angle)) * ringMidRadius;
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(angle + math.pi / 2);
        final h = 1.15 * scale;
        final w = 0.7 * scale;
        if ((q + r) % 3 == 0) {
          // Chevron rune
          canvas.drawLine(Offset(-w, h * 0.5), Offset(0, -h * 0.6), runePaint);
          canvas.drawLine(Offset(0, -h * 0.6), Offset(w, h * 0.5), runePaint);
        } else if ((q + r) % 3 == 1) {
          // Crossed staff rune
          canvas.drawLine(Offset(0, -h * 0.65), Offset(0, h * 0.65), runePaint);
          canvas.drawLine(Offset(-w * 0.8, -h * 0.1), Offset(w * 0.8, h * 0.25), runePaint);
        } else {
          // Diamond-dot / Z-glyph rune
          canvas.drawLine(Offset(-w * 0.7, -h * 0.5), Offset(w * 0.7, 0), runePaint);
          canvas.drawLine(Offset(w * 0.7, 0), Offset(-w * 0.7, h * 0.5), runePaint);
        }
        canvas.restore();
      }
    }
  }

  void _paintCardinalDiamond(
    Canvas canvas,
    Offset pos,
    double radialAngle,
    double halfSize,
    double scale,
  ) {
    final s = math.max(halfSize, 1.8 * scale);
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(radialAngle);

    final diamond = Path()
      ..moveTo(s * 1.15, 0)
      ..lineTo(0, s * 0.85)
      ..lineTo(-s * 1.15, 0)
      ..lineTo(0, -s * 0.85)
      ..close();

    canvas.drawPath(
      diamond,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cGoldLight, _cGoldTrim, _cBronzeDark],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: s)),
    );
    canvas.drawPath(
      diamond,
      Paint()
        ..color = _cBronzeDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.55, 0.7 * scale),
    );
    canvas.drawCircle(
      Offset.zero,
      s * 0.28,
      Paint()..color = _cCyanBright.withValues(alpha: 0.90),
    );
    canvas.restore();
  }

  void _paintOuterSparkles(
    Canvas canvas,
    Offset center,
    double outerFrameRadius,
    double scale,
  ) {
    // Crisp 4-point golden-amber star sparkles positioned just outside the ring
    final starAngles = [
      -math.pi * 0.84,
      -math.pi * 0.16,
      math.pi * 0.20,
      math.pi * 0.82,
    ];
    final starRadii = [
      outerFrameRadius + 1.9 * scale,
      outerFrameRadius + 2.1 * scale,
      outerFrameRadius + 1.8 * scale,
      outerFrameRadius + 2.0 * scale,
    ];
    final starSizes = [1.85 * scale, 1.45 * scale, 1.75 * scale, 1.4 * scale];

    for (int i = 0; i < starAngles.length; i++) {
      final pos =
          center +
          Offset(math.cos(starAngles[i]), math.sin(starAngles[i])) *
              starRadii[i];
      final r = starSizes[i];
      final starPath = Path()
        ..moveTo(pos.dx, pos.dy - r)
        ..quadraticBezierTo(pos.dx, pos.dy, pos.dx + r, pos.dy)
        ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy + r)
        ..quadraticBezierTo(pos.dx, pos.dy, pos.dx - r, pos.dy)
        ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy - r)
        ..close();

      canvas.drawPath(
        starPath,
        Paint()..color = _cSparkleGold.withValues(alpha: 0.95),
      );
    }

    // Tiny golden dust motes near the rim
    final moteAngles = [-2.15, -0.95, 0.92, 2.18];
    for (final angle in moteAngles) {
      final pos =
          center +
          Offset(math.cos(angle), math.sin(angle)) *
              (outerFrameRadius + 1.5 * scale);
      canvas.drawCircle(
        pos,
        0.55 * scale,
        Paint()..color = _cGoldLight.withValues(alpha: 0.82),
      );
    }
  }

  @override
  bool shouldRepaint(_RpgTeleportPortalPainter oldDelegate) => false;
}
