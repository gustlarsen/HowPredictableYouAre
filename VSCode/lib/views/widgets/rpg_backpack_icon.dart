import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A rich, polished RPG adventurer's brown leather backpack icon.
///
/// Features warm leather browns (#8D5524 / #6D3F18), a top flap, front pouch,
/// dark leather straps, and golden-amber buckles (#FFB300).
/// Supports an optional elemental glow pulse when orbs are absorbed.
class RpgBackpackIcon extends StatelessWidget {
  final double size;
  final Color? pulseColor;
  final double glowStrength;

  const RpgBackpackIcon({
    super.key,
    this.size = 28.0,
    this.pulseColor,
    this.glowStrength = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(size, size),
        painter: _RpgBackpackPainter(
          pulseColor: pulseColor,
          glowStrength: glowStrength,
        ),
      ),
    );
  }
}

class _RpgBackpackPainter extends CustomPainter {
  final Color? pulseColor;
  final double glowStrength;

  _RpgBackpackPainter({
    this.pulseColor,
    required this.glowStrength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Elemental Glow Pulse (only when pulsing)
    if (glowStrength > 0.0 && pulseColor != null) {
      final glowPaint = Paint()
        ..color = pulseColor!.withValues(alpha: (0.75 * glowStrength).clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 * glowStrength);
      canvas.drawCircle(Offset(w * 0.5, h * 0.52), w * 0.46, glowPaint);
    }

    // Palette:
    const cHandle = Color(0xFF5C3110);
    const cLeatherBodyTop = Color(0xFF9E5C27);
    const cLeatherBodyMid = Color(0xFF8D5524);
    const cLeatherBodyDark = Color(0xFF6D3F18);
    const cLeatherOutline = Color(0xFF422209);
    const cLeatherFlapTop = Color(0xFFA6662E);
    const cLeatherFlapBot = Color(0xFF844D1E);
    const cLeatherPouchMid = Color(0xFF7D4719);
    const cStrap = Color(0xFF522A0C);
    const cBuckleGold = Color(0xFFFFB300);
    const cBuckleShine = Color(0xFFFFE082);
    const cBuckleShadow = Color(0xFFB27B00);

    // 2. Top Leather Handle Loop
    final handlePaint = Paint()
      ..color = cHandle
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, 2.0 * (w / 28.0))
      ..strokeCap = StrokeCap.round;
    final handleOutlinePaint = Paint()
      ..color = cLeatherOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.2, 3.0 * (w / 28.0))
      ..strokeCap = StrokeCap.round;

    final handlePath = Path()
      ..moveTo(w * 0.38, h * 0.20)
      ..cubicTo(w * 0.38, h * 0.06, w * 0.62, h * 0.06, w * 0.62, h * 0.20);

    canvas.drawPath(handlePath, handleOutlinePaint);
    canvas.drawPath(handlePath, handlePaint);

    // 3. Main Backpack Body
    final bodyRect = Rect.fromLTWH(w * 0.14, h * 0.18, w * 0.72, h * 0.74);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.16));

    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [cLeatherBodyTop, cLeatherBodyMid, cLeatherBodyDark],
        stops: [0.0, 0.45, 1.0],
      ).createShader(bodyRect);

    final outlinePaint = Paint()
      ..color = cLeatherOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 1.2 * (w / 28.0));

    // Subtle drop shadow under main body
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawRRect(bodyRRect.shift(Offset(0, h * 0.04)), shadowPaint);

    canvas.drawRRect(bodyRRect, bodyPaint);
    canvas.drawRRect(bodyRRect, outlinePaint);

    // 4. Vertical Straps (behind flap & pouch)
    final strapPaint = Paint()..color = cStrap;
    final strapOutline = Paint()
      ..color = cLeatherOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, 0.8 * (w / 28.0));

    final leftStrap = Rect.fromLTWH(w * 0.26, h * 0.18, w * 0.10, h * 0.74);
    final rightStrap = Rect.fromLTWH(w * 0.64, h * 0.18, w * 0.10, h * 0.74);

    canvas.drawRect(leftStrap, strapPaint);
    canvas.drawRect(leftStrap, strapOutline);
    canvas.drawRect(rightStrap, strapPaint);
    canvas.drawRect(rightStrap, strapOutline);

    // 5. Front Pouch
    final pouchRect = Rect.fromLTWH(w * 0.24, h * 0.54, w * 0.52, h * 0.34);
    final pouchRRect = RRect.fromRectAndRadius(pouchRect, Radius.circular(w * 0.10));

    final pouchPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [cLeatherBodyMid, cLeatherPouchMid, cLeatherBodyDark],
      ).createShader(pouchRect);

    // Subtle shadow behind pouch
    canvas.drawRRect(
      pouchRRect.shift(Offset(0, h * 0.02)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0),
    );
    canvas.drawRRect(pouchRRect, pouchPaint);
    canvas.drawRRect(pouchRRect, outlinePaint);

    // Front Pouch Flap
    final pouchFlapRect = Rect.fromLTWH(w * 0.22, h * 0.52, w * 0.56, h * 0.13);
    final pouchFlapRRect = RRect.fromRectAndCorners(
      pouchFlapRect,
      topLeft: Radius.circular(w * 0.06),
      topRight: Radius.circular(w * 0.06),
      bottomLeft: Radius.circular(w * 0.08),
      bottomRight: Radius.circular(w * 0.08),
    );
    final pouchFlapPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [cLeatherFlapTop, cLeatherFlapBot],
      ).createShader(pouchFlapRect);
    canvas.drawRRect(pouchFlapRRect, pouchFlapPaint);
    canvas.drawRRect(pouchFlapRRect, outlinePaint);

    // 6. Top Main Flap
    final flapRect = Rect.fromLTWH(w * 0.12, h * 0.16, w * 0.76, h * 0.34);
    final flapRRect = RRect.fromRectAndCorners(
      flapRect,
      topLeft: Radius.circular(w * 0.16),
      topRight: Radius.circular(w * 0.16),
      bottomLeft: Radius.circular(w * 0.12),
      bottomRight: Radius.circular(w * 0.12),
    );

    final flapPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [cLeatherFlapTop, cLeatherBodyMid, cLeatherFlapBot],
        stops: [0.0, 0.6, 1.0],
      ).createShader(flapRect);

    // Shadow under top flap
    canvas.drawRRect(
      flapRRect.shift(Offset(0, h * 0.03)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
    canvas.drawRRect(flapRRect, flapPaint);
    canvas.drawRRect(flapRRect, outlinePaint);

    // Top leather highlight crease line
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, 0.8 * (w / 28.0));
    canvas.drawLine(
      Offset(w * 0.22, h * 0.21),
      Offset(w * 0.78, h * 0.21),
      highlightPaint,
    );

    // 7. Golden-Amber Buckles (#FFB300)
    void drawBuckle(double bx, double by, double bw, double bh) {
      final bRect = Rect.fromLTWH(bx, by, bw, bh);
      final bRRect = RRect.fromRectAndRadius(bRect, Radius.circular(bw * 0.25));

      final bPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cBuckleShine, cBuckleGold, cBuckleShadow],
          stops: [0.0, 0.5, 1.0],
        ).createShader(bRect);

      final bOutline = Paint()
        ..color = cLeatherOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.5, 0.7 * (w / 28.0));

      // Buckle shadow
      canvas.drawRRect(
        bRRect.shift(Offset(0, bh * 0.2)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
      );
      canvas.drawRRect(bRRect, bPaint);
      canvas.drawRRect(bRRect, bOutline);

      // Inner buckle bar/pin
      final pinPaint = Paint()
        ..color = cLeatherOutline
        ..strokeWidth = math.max(0.6, 0.8 * (w / 28.0));
      canvas.drawLine(
        Offset(bx + bw * 0.5, by + bh * 0.2),
        Offset(bx + bw * 0.5, by + bh * 0.8),
        pinPaint,
      );
    }

    // Left main buckle (at flap line)
    drawBuckle(w * 0.24, h * 0.44, w * 0.14, h * 0.10);
    // Right main buckle (at flap line)
    drawBuckle(w * 0.62, h * 0.44, w * 0.14, h * 0.10);
    // Front pouch center mini buckle
    drawBuckle(w * 0.44, h * 0.60, w * 0.12, h * 0.08);
  }

  @override
  bool shouldRepaint(_RpgBackpackPainter oldDelegate) {
    return oldDelegate.pulseColor != pulseColor ||
        oldDelegate.glowStrength != glowStrength;
  }
}
