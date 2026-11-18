import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/move.dart';

/// A rich, polished RPG adventurer's brown leather backpack icon.
///
/// Features warm leather browns (#8D5524 / #6D3F18), a top flap, front pouch,
/// dark leather straps, and golden-amber buckles (#FFB300).
/// Supports an optional elemental glow pulse when orbs are absorbed, as well as
/// an illustrated wide-open state ([isOpen]) showing lifted flap, side strap,
/// glowing elemental orbs for [ownedOrbs], radial glow pulse, and rising sparkles.
class RpgBackpackIcon extends StatelessWidget {
  final double size;
  final Color? pulseColor;
  final double glowStrength;
  final bool isOpen;
  final double openProgress;
  final double ambientGlowPhase;
  final Set<HandMove> ownedOrbs;

  const RpgBackpackIcon({
    super.key,
    this.size = 28.0,
    this.pulseColor,
    this.glowStrength = 0.0,
    this.isOpen = false,
    this.openProgress = 1.0,
    this.ambientGlowPhase = 0.0,
    this.ownedOrbs = const {},
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(size, size),
        painter: _RpgBackpackPainter(
          pulseColor: pulseColor,
          glowStrength: glowStrength,
          isOpen: isOpen,
          openProgress: openProgress,
          ambientGlowPhase: ambientGlowPhase,
          ownedOrbs: ownedOrbs,
        ),
      ),
    );
  }
}

class _RpgBackpackPainter extends CustomPainter {
  final Color? pulseColor;
  final double glowStrength;
  final bool isOpen;
  final double openProgress;
  final double ambientGlowPhase;
  final Set<HandMove> ownedOrbs;

  _RpgBackpackPainter({
    this.pulseColor,
    required this.glowStrength,
    required this.isOpen,
    required this.openProgress,
    required this.ambientGlowPhase,
    required this.ownedOrbs,
  });

  static const _cHandle = Color(0xFF5C3110);
  static const _cLeatherBodyTop = Color(0xFF9E5C27);
  static const _cLeatherBodyMid = Color(0xFF8D5524);
  static const _cLeatherBodyDark = Color(0xFF6D3F18);
  static const _cLeatherOutline = Color(0xFF422209);
  static const _cLeatherFlapTop = Color(0xFFA6662E);
  static const _cLeatherFlapBot = Color(0xFF844D1E);
  static const _cLeatherPouchMid = Color(0xFF7D4719);
  static const _cLeatherInterior = Color(0xFF231005);
  static const _cLeatherLining = Color(0xFF6A3A14);
  static const _cLeatherLiningDark = Color(0xFF4B260A);
  static const _cStrap = Color(0xFF522A0C);
  static const _cBuckleGold = Color(0xFFFFB300);
  static const _cBuckleShine = Color(0xFFFFE082);
  static const _cBuckleShadow = Color(0xFFB27B00);

  @override
  void paint(Canvas canvas, Size size) {
    if (isOpen) {
      _paintOpenBackpack(canvas, size);
    } else {
      _paintClosedBackpack(canvas, size);
    }
  }

  void _drawBuckle(
    Canvas canvas,
    double w,
    double bx,
    double by,
    double bw,
    double bh,
  ) {
    final bRect = Rect.fromLTWH(bx, by, bw, bh);
    final bRRect = RRect.fromRectAndRadius(bRect, Radius.circular(bw * 0.25));

    final bPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_cBuckleShine, _cBuckleGold, _cBuckleShadow],
        stops: [0.0, 0.5, 1.0],
      ).createShader(bRect);

    final bOutline = Paint()
      ..color = _cLeatherOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, 0.7 * (w / 28.0));

    canvas.drawRRect(
      bRRect.shift(Offset(0, bh * 0.2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
    );
    canvas.drawRRect(bRRect, bPaint);
    canvas.drawRRect(bRRect, bOutline);

    final pinPaint = Paint()
      ..color = _cLeatherOutline
      ..strokeWidth = math.max(0.6, 0.8 * (w / 28.0));
    canvas.drawLine(
      Offset(bx + bw * 0.5, by + bh * 0.2),
      Offset(bx + bw * 0.5, by + bh * 0.8),
      pinPaint,
    );
  }

  void _paintClosedBackpack(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Elemental Glow Pulse (only when pulsing)
    if (glowStrength > 0.0 && pulseColor != null) {
      final glowPaint = Paint()
        ..color =
            pulseColor!.withValues(alpha: (0.75 * glowStrength).clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 * glowStrength);
      canvas.drawCircle(Offset(w * 0.5, h * 0.52), w * 0.46, glowPaint);
    }

    // 2. Top Leather Handle Loop
    final handlePaint = Paint()
      ..color = _cHandle
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, 2.0 * (w / 28.0))
      ..strokeCap = StrokeCap.round;
    final handleOutlinePaint = Paint()
      ..color = _cLeatherOutline
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
    final bodyRRect =
        RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.16));

    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_cLeatherBodyTop, _cLeatherBodyMid, _cLeatherBodyDark],
        stops: [0.0, 0.45, 1.0],
      ).createShader(bodyRect);

    final outlinePaint = Paint()
      ..color = _cLeatherOutline
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
    final strapPaint = Paint()..color = _cStrap;
    final strapOutline = Paint()
      ..color = _cLeatherOutline
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
    final pouchRRect =
        RRect.fromRectAndRadius(pouchRect, Radius.circular(w * 0.10));

    final pouchPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_cLeatherBodyMid, _cLeatherPouchMid, _cLeatherBodyDark],
      ).createShader(pouchRect);

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
        colors: [_cLeatherFlapTop, _cLeatherFlapBot],
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
        colors: [_cLeatherFlapTop, _cLeatherBodyMid, _cLeatherFlapBot],
        stops: [0.0, 0.6, 1.0],
      ).createShader(flapRect);

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
    _drawBuckle(canvas, w, w * 0.24, h * 0.44, w * 0.14, h * 0.10);
    _drawBuckle(canvas, w, w * 0.62, h * 0.44, w * 0.14, h * 0.10);
    _drawBuckle(canvas, w, w * 0.44, h * 0.60, w * 0.12, h * 0.08);
  }

  void _paintOpenBackpack(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final scaleFactor = w / 86.0;
    final openT = openProgress.clamp(0.0, 1.0);
    final pulse = 0.5 - 0.5 * math.cos(ambientGlowPhase * 2 * math.pi);

    final activeOrbs = [
      for (final move in HandMove.values)
        if (ownedOrbs.contains(move)) move,
    ];
    final hasOrbs = activeOrbs.isNotEmpty;

    final outlinePaint = Paint()
      ..color = _cLeatherOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, 1.8 * scaleFactor)
      ..strokeJoin = StrokeJoin.round;

    // 1. Ambient Looping Radial Glow radiating from inside the open bag
    final mouthCenter = Offset(w * 0.49, h * 0.39);
    if (hasOrbs) {
      final auraStrength = (0.55 + 0.45 * pulse) * openT;
      final outerAuraRect =
          Rect.fromCircle(center: mouthCenter, radius: w * 0.48);
      final auraPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE082).withValues(alpha: 0.48 * auraStrength),
            const Color(0xFFFFB300).withValues(alpha: 0.26 * auraStrength),
            Colors.transparent,
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(outerAuraRect);
      canvas.drawCircle(mouthCenter, w * 0.48, auraPaint);

      // Subtle elemental tint halos corresponding to owned orbs
      for (int i = 0; i < activeOrbs.length; i++) {
        final angle = -math.pi * 0.8 + (i / math.max(1, activeOrbs.length - 1)) * math.pi * 0.6;
        final offset = mouthCenter + Offset(math.cos(angle) * w * 0.12, -w * 0.04);
        canvas.drawCircle(
          offset,
          w * 0.24,
          Paint()
            ..color = activeOrbs[i]
                .elementalPrimaryColor
                .withValues(alpha: 0.22 * auraStrength)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9.0 * scaleFactor),
        );
      }
    } else {
      // Faint warm rim glow even when empty
      canvas.drawCircle(
        mouthCenter,
        w * 0.36,
        Paint()
          ..color = const Color(0xFFFFB300).withValues(alpha: 0.10 * openT)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 * scaleFactor),
      );
    }

    // 2. Top Leather Handle Loop (behind the lifted flap)
    final handleTopY = uiLerp(h * 0.24, h * 0.03, openT);
    final handleBaseY = uiLerp(h * 0.34, h * 0.14, openT);
    final handlePath = Path()
      ..moveTo(w * 0.39, handleBaseY)
      ..cubicTo(
        w * 0.39,
        handleTopY,
        w * 0.59,
        handleTopY,
        w * 0.59,
        handleBaseY,
      );
    canvas.drawPath(
      handlePath,
      Paint()
        ..color = _cLeatherOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3.0, 4.8 * scaleFactor)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      handlePath,
      Paint()
        ..color = _cHandle
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, 3.0 * scaleFactor)
        ..strokeCap = StrokeCap.round,
    );

    // 3. Lifted-Back Top Flap (showing inner leather lining & upturned strap buckles)
    final flapPeakY = uiLerp(h * 0.33, h * 0.09, openT);
    final flapHingeY = h * 0.35;
    final liftedFlapPath = Path()
      ..moveTo(w * 0.19, flapHingeY)
      ..quadraticBezierTo(w * 0.16, flapPeakY + h * 0.05, w * 0.26, flapPeakY)
      ..quadraticBezierTo(w * 0.49, flapPeakY - h * 0.03, w * 0.72, flapPeakY)
      ..quadraticBezierTo(w * 0.82, flapPeakY + h * 0.05, w * 0.79, flapHingeY)
      ..close();

    // Drop shadow behind lifted flap
    canvas.drawPath(
      liftedFlapPath.shift(Offset(0, h * 0.025)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0 * scaleFactor),
    );

    // Inner suede lining of lifted flap
    final flapRect = Rect.fromLTRB(w * 0.17, flapPeakY - h * 0.03, w * 0.81, flapHingeY);
    canvas.drawPath(
      liftedFlapPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cLeatherFlapTop, _cLeatherLining, _cLeatherLiningDark],
          stops: const [0.0, 0.38, 1.0],
        ).createShader(flapRect),
    );

    // Warm golden/elemental bounce light on the inside of the lifted flap
    if (hasOrbs) {
      canvas.save();
      canvas.clipPath(liftedFlapPath);
      canvas.drawCircle(
        Offset(w * 0.49, flapHingeY - h * 0.02),
        w * 0.32,
        Paint()
          ..color = const Color(0xFFFFD54F)
              .withValues(alpha: (0.20 + 0.16 * pulse) * openT)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10.0 * scaleFactor),
      );
      canvas.restore();
    }

    canvas.drawPath(liftedFlapPath, outlinePaint);

    // Folded top ridge highlight on lifted flap
    final ridgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 1.4 * scaleFactor)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.26, flapPeakY + h * 0.025)
        ..quadraticBezierTo(
          w * 0.49,
          flapPeakY - h * 0.005,
          w * 0.72,
          flapPeakY + h * 0.025,
        ),
      ridgePaint,
    );

    // Two upturned flap strap tabs with golden buckles visible on the open flap
    void drawFlapStrapTab(double cx) {
      final tabRect = Rect.fromCenter(
        center: Offset(cx, flapPeakY + h * 0.045),
        width: w * 0.085,
        height: h * 0.095,
      );
      final tabRRect =
          RRect.fromRectAndRadius(tabRect, Radius.circular(w * 0.025));
      canvas.drawRRect(tabRRect, Paint()..color = _cStrap);
      canvas.drawRRect(
        tabRRect,
        Paint()
          ..color = _cLeatherOutline
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.8, 1.1 * scaleFactor),
      );
      _drawBuckle(
        canvas,
        w * 0.72,
        cx - w * 0.048,
        flapPeakY + h * 0.015,
        w * 0.096,
        h * 0.055,
      );
    }

    if (openT > 0.25) {
      drawFlapStrapTab(w * 0.29);
      drawFlapStrapTab(w * 0.69);
    }

    // 4. Side Gussets & Side Compression Strap (right side detail)
    // Left subtle gusset
    final leftGusset = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.11, h * 0.47, w * 0.12, h * 0.36),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(leftGusset, Paint()..color = _cLeatherBodyDark);
    canvas.drawRRect(leftGusset, outlinePaint);

    // Right side gusset (protruding slightly for 3/4 RPG silhouette)
    final rightGussetRect = Rect.fromLTWH(w * 0.74, h * 0.45, w * 0.15, h * 0.40);
    final rightGusset = RRect.fromRectAndRadius(
      rightGussetRect,
      Radius.circular(w * 0.065),
    );
    canvas.drawRRect(
      rightGusset.shift(Offset(0, h * 0.025)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 * scaleFactor),
    );
    canvas.drawRRect(
      rightGusset,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_cLeatherBodyMid, _cLeatherBodyDark],
        ).createShader(rightGussetRect),
    );
    canvas.drawRRect(rightGusset, outlinePaint);

    // Side Strap wrapping across right gusset + Golden Side Buckle
    final sideStrapPath = Path()
      ..moveTo(w * 0.77, h * 0.59)
      ..lineTo(w * 0.90, h * 0.61)
      ..lineTo(w * 0.90, h * 0.68)
      ..lineTo(w * 0.77, h * 0.66)
      ..close();
    canvas.drawPath(sideStrapPath, Paint()..color = _cStrap);
    canvas.drawPath(
      sideStrapPath,
      Paint()
        ..color = _cLeatherOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.9, 1.2 * scaleFactor),
    );
    _drawBuckle(canvas, w * 0.74, w * 0.80, h * 0.585, w * 0.085, h * 0.095);

    // 5. Open Bag Mouth / Interior Cavity
    final mouthPath = Path()
      ..moveTo(w * 0.18, h * 0.38)
      ..quadraticBezierTo(w * 0.49, h * 0.30, w * 0.80, h * 0.38)
      ..quadraticBezierTo(w * 0.82, h * 0.49, w * 0.49, h * 0.51)
      ..quadraticBezierTo(w * 0.16, h * 0.49, w * 0.18, h * 0.38)
      ..close();

    canvas.drawPath(
      mouthPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.2),
          radius: 0.9,
          colors: [
            hasOrbs ? const Color(0xFF3A1D0A) : const Color(0xFF281306),
            _cLeatherInterior,
          ],
        ).createShader(Rect.fromLTWH(w * 0.17, h * 0.30, w * 0.64, h * 0.22)),
    );
    canvas.drawPath(mouthPath, outlinePaint);

    // 6. Glowing Elemental Orbs inside the open mouth (clipped above lower lip)
    if (hasOrbs && openT > 0.15) {
      final orbCenters = _orbPositionsForCount(activeOrbs.length, w, h);
      final orbRadius = _orbRadiusForCount(activeOrbs.length, w);

      for (int i = 0; i < activeOrbs.length; i++) {
        final move = activeOrbs[i];
        final center = orbCenters[i] + Offset(0, (1.0 - openT) * h * 0.06);
        final r = orbRadius * (0.75 + 0.25 * openT);
        final primary = move.elementalPrimaryColor;
        final secondary = move.elementalSecondaryColor;

        // Soft glowing aura around each orb
        canvas.drawCircle(
          center,
          r * (1.45 + 0.22 * pulse),
          Paint()
            ..color = primary.withValues(alpha: (0.45 + 0.25 * pulse) * openT)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.5 * scaleFactor),
        );

        // Glassy elemental sphere body
        final orbRect = Rect.fromCircle(center: center, radius: r);
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.28, -0.28),
              radius: 0.92,
              colors: [
                Color.lerp(primary, Colors.white, 0.55)!,
                primary,
                secondary,
                const Color(0xFF0A0C12),
              ],
              stops: const [0.0, 0.38, 0.78, 1.0],
            ).createShader(orbRect),
        );

        // Luminous rim
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..color = Color.lerp(primary, Colors.white, 0.35)!
                .withValues(alpha: 0.92 * openT)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.8, 1.1 * scaleFactor),
        );

        // Glossy top-left specular highlight
        canvas.drawCircle(
          center + Offset(-r * 0.32, -r * 0.32),
          r * 0.24,
          Paint()..color = Colors.white.withValues(alpha: 0.85 * openT),
        );
      }
    }

    // 7. Main Front Leather Body (occludes lower edge of front orbs for true 3D depth)
    final bodyPath = Path()
      ..moveTo(w * 0.16, h * 0.42)
      ..quadraticBezierTo(w * 0.49, h * 0.495, w * 0.82, h * 0.42)
      ..lineTo(w * 0.82, h * 0.78)
      ..quadraticBezierTo(w * 0.82, h * 0.92, w * 0.67, h * 0.92)
      ..lineTo(w * 0.31, h * 0.92)
      ..quadraticBezierTo(w * 0.16, h * 0.92, w * 0.16, h * 0.78)
      ..close();

    // Ground drop shadow under bag
    canvas.drawPath(
      bodyPath.shift(Offset(0, h * 0.035)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0 * scaleFactor),
    );

    final bodyBounds = Rect.fromLTWH(w * 0.16, h * 0.42, w * 0.66, h * 0.50);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cLeatherBodyTop, _cLeatherBodyMid, _cLeatherBodyDark],
          stops: [0.0, 0.42, 1.0],
        ).createShader(bodyBounds),
    );
    canvas.drawPath(bodyPath, outlinePaint);

    // Warm lip collar highlight curving along the open front mouth edge
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.18, h * 0.435)
        ..quadraticBezierTo(w * 0.49, h * 0.51, w * 0.80, h * 0.435),
      Paint()
        ..color = const Color(0xFFD68D4A).withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, 1.8 * scaleFactor)
        ..strokeCap = StrokeCap.round,
    );

    // Vertical dark leather straps on front body
    final strapOutline = Paint()
      ..color = _cLeatherOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, 1.0 * scaleFactor);
    final leftFrontStrap =
        Rect.fromLTWH(w * 0.255, h * 0.46, w * 0.085, h * 0.45);
    final rightFrontStrap =
        Rect.fromLTWH(w * 0.64, h * 0.46, w * 0.085, h * 0.45);
    canvas.drawRect(leftFrontStrap, Paint()..color = _cStrap);
    canvas.drawRect(leftFrontStrap, strapOutline);
    canvas.drawRect(rightFrontStrap, Paint()..color = _cStrap);
    canvas.drawRect(rightFrontStrap, strapOutline);

    // Front main golden buckles (unlatched at front rim)
    _drawBuckle(canvas, w * 0.72, w * 0.235, h * 0.495, w * 0.125, h * 0.082);
    _drawBuckle(canvas, w * 0.72, w * 0.62, h * 0.495, w * 0.125, h * 0.082);

    // 8. Front Utility Pouch & Golden Center Buckle
    final pouchRect = Rect.fromLTWH(w * 0.28, h * 0.63, w * 0.42, h * 0.25);
    final pouchRRect =
        RRect.fromRectAndRadius(pouchRect, Radius.circular(w * 0.08));
    canvas.drawRRect(
      pouchRRect.shift(Offset(0, h * 0.02)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.8 * scaleFactor),
    );
    canvas.drawRRect(
      pouchRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cLeatherBodyMid, _cLeatherPouchMid, _cLeatherBodyDark],
        ).createShader(pouchRect),
    );
    canvas.drawRRect(pouchRRect, outlinePaint);

    // Front pouch flap
    final pouchFlapRect = Rect.fromLTWH(w * 0.265, h * 0.61, w * 0.45, h * 0.105);
    final pouchFlapRRect = RRect.fromRectAndCorners(
      pouchFlapRect,
      topLeft: Radius.circular(w * 0.05),
      topRight: Radius.circular(w * 0.05),
      bottomLeft: Radius.circular(w * 0.07),
      bottomRight: Radius.circular(w * 0.07),
    );
    canvas.drawRRect(
      pouchFlapRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cLeatherFlapTop, _cLeatherFlapBot],
        ).createShader(pouchFlapRect),
    );
    canvas.drawRRect(pouchFlapRRect, outlinePaint);

    // Pouch center golden buckle
    _drawBuckle(canvas, w * 0.72, w * 0.435, h * 0.675, w * 0.11, h * 0.072);

    // 9. Subtle Rising Golden / Elemental Sparkles
    if (openT > 0.35) {
      _paintRisingSparkles(
        canvas,
        w,
        h,
        scaleFactor,
        openT,
        activeOrbs,
      );
    }
  }

  List<Offset> _orbPositionsForCount(int count, double w, double h) {
    switch (count) {
      case 1:
        return [Offset(w * 0.49, h * 0.40)];
      case 2:
        return [Offset(w * 0.39, h * 0.40), Offset(w * 0.59, h * 0.40)];
      case 3:
        return [
          Offset(w * 0.34, h * 0.415),
          Offset(w * 0.49, h * 0.365),
          Offset(w * 0.64, h * 0.415),
        ];
      case 4:
        return [
          Offset(w * 0.40, h * 0.36),
          Offset(w * 0.58, h * 0.36),
          Offset(w * 0.34, h * 0.43),
          Offset(w * 0.64, h * 0.43),
        ];
      default:
        return [
          Offset(w * 0.40, h * 0.355),
          Offset(w * 0.58, h * 0.355),
          Offset(w * 0.32, h * 0.425),
          Offset(w * 0.49, h * 0.435),
          Offset(w * 0.66, h * 0.425),
        ];
    }
  }

  double _orbRadiusForCount(int count, double w) {
    switch (count) {
      case 1:
        return w * 0.11;
      case 2:
        return w * 0.102;
      case 3:
        return w * 0.095;
      case 4:
        return w * 0.088;
      default:
        return w * 0.084;
    }
  }

  void _paintRisingSparkles(
    Canvas canvas,
    double w,
    double h,
    double scaleFactor,
    double openT,
    List<HandMove> activeOrbs,
  ) {
    const sparkleAnchors = [
      0.27,
      0.38,
      0.49,
      0.61,
      0.71,
      0.43,
      0.55,
    ];
    for (int i = 0; i < sparkleAnchors.length; i++) {
      final phase = (ambientGlowPhase + i / sparkleAnchors.length) % 1.0;
      final fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      if (fade <= 0.02) continue;

      final baseAlpha = activeOrbs.isNotEmpty ? 0.92 : 0.42;
      final alpha = (fade * baseAlpha * openT).clamp(0.0, 1.0);

      final sway = math.sin(phase * 2 * math.pi + i) * w * 0.025;
      final sx = w * sparkleAnchors[i] + sway;
      final sy = h * (0.37 - phase * 0.29);

      final Color sparkleColor;
      if (activeOrbs.isEmpty || i % 2 == 0) {
        sparkleColor = i % 3 == 0
            ? const Color(0xFFFFE082)
            : const Color(0xFFFFB300);
      } else {
        sparkleColor =
            activeOrbs[i % activeOrbs.length].elementalPrimaryColor;
      }

      final r = (i.isEven ? 3.2 : 2.1) * scaleFactor * (0.65 + 0.35 * fade);

      // Soft dot glow
      canvas.drawCircle(
        Offset(sx, sy),
        r * 1.35,
        Paint()
          ..color = sparkleColor.withValues(alpha: alpha * 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 * scaleFactor),
      );

      // Crisp 4-point star for primary sparkles, bright mote for secondary
      if (i.isEven) {
        final starPath = Path()
          ..moveTo(sx, sy - r)
          ..quadraticBezierTo(sx, sy, sx + r, sy)
          ..quadraticBezierTo(sx, sy, sx, sy + r)
          ..quadraticBezierTo(sx, sy, sx - r, sy)
          ..quadraticBezierTo(sx, sy, sx, sy - r)
          ..close();
        canvas.drawPath(
          starPath,
          Paint()
            ..color = Color.lerp(sparkleColor, Colors.white, 0.55)!
                .withValues(alpha: alpha),
        );
      } else {
        canvas.drawCircle(
          Offset(sx, sy),
          r * 0.65,
          Paint()
            ..color = Color.lerp(sparkleColor, Colors.white, 0.45)!
                .withValues(alpha: alpha),
        );
      }
    }
  }

  static double uiLerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(_RpgBackpackPainter oldDelegate) {
    return oldDelegate.pulseColor != pulseColor ||
        oldDelegate.glowStrength != glowStrength ||
        oldDelegate.isOpen != isOpen ||
        oldDelegate.openProgress != openProgress ||
        oldDelegate.ambientGlowPhase != ambientGlowPhase ||
        !setEquals(oldDelegate.ownedOrbs, ownedOrbs);
  }
}

