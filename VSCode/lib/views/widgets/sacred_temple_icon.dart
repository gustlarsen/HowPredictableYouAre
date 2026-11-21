import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A bespoke, multi-toned classical marble-and-gold Temple Sanctuary icon
/// rendered via [CustomPainter] on a transparent background.
///
/// Architectural silhouette features:
/// - Golden-amber triangular pediment roof (`#FFD54F` left highlight, `#FFB300`
///   right shadow) with a recessed tympanum and a glowing cyan crystal gem
///   (`#00E5FF`) centered inside.
/// - Four bold fluted ivory marble columns (`#FAF6EE` light face, `#D7CCC8`
///   shaded face) set over a deep slate sanctuary recess (`#263238` / `#37474F`).
/// - Two-tiered horizontal marble-and-gold stepped sanctuary foundation base.
/// - Crisp dark charcoal-slate outlines (`#263238`) for sharp legibility at
///   `22px–28px` map pin sizes.
///
/// Set [isOnGoldBackground] to `true` when rendering on a solid gold surface
/// to switch to the high-contrast deep charcoal-slate palette.
class SacredTempleIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const SacredTempleIcon({
    super.key,
    this.size = 24.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: _SacredTemplePainter(
            isOnGoldBackground: isOnGoldBackground,
          ),
        ),
      ),
    );
  }
}

class _TemplePalette {
  final Color goldHighlight;
  final Color goldLight;
  final Color goldMid;
  final Color goldShadow;
  final Color tympanum;
  final Color marbleHighlight;
  final Color marbleLight;
  final Color marbleMid;
  final Color marbleShadow;
  final Color recessDark;
  final Color recessLight;
  final Color gemHighlight;
  final Color gemBright;
  final Color gemShadow;
  final Color outline;

  const _TemplePalette({
    required this.goldHighlight,
    required this.goldLight,
    required this.goldMid,
    required this.goldShadow,
    required this.tympanum,
    required this.marbleHighlight,
    required this.marbleLight,
    required this.marbleMid,
    required this.marbleShadow,
    required this.recessDark,
    required this.recessLight,
    required this.gemHighlight,
    required this.gemBright,
    required this.gemShadow,
    required this.outline,
  });

  static const standard = _TemplePalette(
    goldHighlight: Color(0xFFFFE57F),
    goldLight: Color(0xFFFFD54F),
    goldMid: Color(0xFFFFB300),
    goldShadow: Color(0xFFD98A00),
    tympanum: Color(0xFF37474F),
    marbleHighlight: Color(0xFFFFFDF7),
    marbleLight: Color(0xFFFAF6EE),
    marbleMid: Color(0xFFEBE3D5),
    marbleShadow: Color(0xFFD7CCC8),
    recessDark: Color(0xFF263238),
    recessLight: Color(0xFF37474F),
    gemHighlight: Color(0xFFE0FFFF),
    gemBright: Color(0xFF00E5FF),
    gemShadow: Color(0xFF00838F),
    outline: Color(0xFF263238),
  );

  static const onGold = _TemplePalette(
    goldHighlight: Color(0xFF455A64),
    goldLight: Color(0xFF37474F),
    goldMid: Color(0xFF263238),
    goldShadow: Color(0xFF1A2226),
    tympanum: Color(0xFF1A2226),
    marbleHighlight: Color(0xFF455A64),
    marbleLight: Color(0xFF37474F),
    marbleMid: Color(0xFF2C383E),
    marbleShadow: Color(0xFF263238),
    recessDark: Color(0xFF151C20),
    recessLight: Color(0xFF1E272C),
    gemHighlight: Color(0xFF84FFFF),
    gemBright: Color(0xFF00E5FF),
    gemShadow: Color(0xFF006064),
    outline: Color(0xFF141B1E),
  );
}

class _SacredTemplePainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _SacredTemplePainter({
    required this.isOnGoldBackground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final offsetX = (size.width - side) * 0.5;
    final offsetY = (size.height - side) * 0.5;
    final scale = side / 24.0;
    final p = isOnGoldBackground
        ? _TemplePalette.onGold
        : _TemplePalette.standard;

    canvas.save();
    canvas.translate(offsetX, offsetY);

    final outlinePaint = Paint()
      ..color = p.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, 1.15 * scale)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final detailStrokePaint = Paint()
      ..color = p.outline.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.45, 0.68 * scale)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // 1. Subtle ground shadow beneath the sanctuary steps
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(side * 0.50, side * 0.925),
        width: side * 0.86,
        height: side * 0.075,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: isOnGoldBackground ? 0.16 : 0.28),
    );

    // 2. Deep slate interior recess behind columns
    _paintSanctuaryRecess(canvas, side, p);

    // 3. Four fluted ivory marble columns
    _paintMarbleColumns(canvas, side, p, outlinePaint, detailStrokePaint);

    // 4. Two-tiered stepped marble-and-gold sanctuary base
    _paintSteppedBase(canvas, side, p, outlinePaint, detailStrokePaint);

    // 5. Golden architrave & triangular pediment roof with cyan crystal gem
    _paintPedimentAndArchitrave(
      canvas,
      side,
      scale,
      p,
      outlinePaint,
      detailStrokePaint,
    );

    canvas.restore();
  }

  void _paintSanctuaryRecess(Canvas canvas, double s, _TemplePalette p) {
    final recessRect = Rect.fromLTRB(s * 0.16, s * 0.365, s * 0.84, s * 0.778);
    canvas.drawRect(
      recessRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.recessDark, p.recessLight, p.recessDark],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(recessRect),
    );

    // Subtle deeper inner sanctum doorway between central columns
    final doorwayRect = Rect.fromLTRB(s * 0.445, s * 0.50, s * 0.555, s * 0.778);
    canvas.drawRect(
      doorwayRect,
      Paint()..color = p.recessDark.withValues(alpha: 0.75),
    );
  }

  void _paintMarbleColumns(
    Canvas canvas,
    double s,
    _TemplePalette p,
    Paint outlinePaint,
    Paint detailStrokePaint,
  ) {
    const columnCenters = [0.225, 0.408, 0.592, 0.775];
    final shaftWidth = s * 0.106;
    final capWidth = s * 0.136;

    for (final normX in columnCenters) {
      final cx = s * normX;
      final shaftRect = Rect.fromLTRB(
        cx - shaftWidth * 0.5,
        s * 0.418,
        cx + shaftWidth * 0.5,
        s * 0.742,
      );

      canvas.drawRect(
        shaftRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              p.marbleHighlight,
              p.marbleLight,
              p.marbleMid,
              p.marbleShadow,
            ],
            stops: const [0.0, 0.25, 0.65, 1.0],
          ).createShader(shaftRect),
      );
      canvas.drawRect(shaftRect, outlinePaint);

      // Central vertical flute groove
      canvas.drawLine(
        Offset(cx, s * 0.442),
        Offset(cx, s * 0.718),
        detailStrokePaint,
      );

      // Column capital (top) & plinth block (bottom)
      final capitalRect = Rect.fromLTRB(
        cx - capWidth * 0.5,
        s * 0.382,
        cx + capWidth * 0.5,
        s * 0.418,
      );
      final baseBlockRect = Rect.fromLTRB(
        cx - capWidth * 0.5,
        s * 0.742,
        cx + capWidth * 0.5,
        s * 0.778,
      );

      for (final block in [capitalRect, baseBlockRect]) {
        canvas.drawRect(
          block,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [p.marbleLight, p.marbleShadow],
            ).createShader(block),
        );
        canvas.drawRect(block, detailStrokePaint);
      }
    }
  }

  void _paintSteppedBase(
    Canvas canvas,
    double s,
    _TemplePalette p,
    Paint outlinePaint,
    Paint detailStrokePaint,
  ) {
    // Upper marble step
    final upperStep = Rect.fromLTRB(s * 0.12, s * 0.776, s * 0.88, s * 0.842);
    canvas.drawRect(
      upperStep,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [p.marbleHighlight, p.marbleLight, p.marbleMid, p.marbleShadow],
          stops: const [0.0, 0.25, 0.68, 1.0],
        ).createShader(upperStep),
    );
    canvas.drawRect(upperStep, outlinePaint);

    // Lower golden foundation step
    final lowerStep = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.075, s * 0.842, s * 0.925, s * 0.910),
      Radius.circular(s * 0.024),
    );
    canvas.drawRRect(
      lowerStep,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [p.goldHighlight, p.goldLight, p.goldMid, p.goldShadow],
          stops: const [0.0, 0.30, 0.70, 1.0],
        ).createShader(lowerStep.outerRect),
    );
    canvas.drawRRect(lowerStep, outlinePaint);

    // Subtle central sanctuary threshold accent on upper marble step
    canvas.drawLine(
      Offset(s * 0.36, s * 0.809),
      Offset(s * 0.64, s * 0.809),
      detailStrokePaint,
    );
  }

  void _paintPedimentAndArchitrave(
    Canvas canvas,
    double s,
    double scale,
    _TemplePalette p,
    Paint outlinePaint,
    Paint detailStrokePaint,
  ) {
    // Golden horizontal architrave beam above columns
    final architrave = Rect.fromLTRB(s * 0.115, s * 0.335, s * 0.885, s * 0.384);
    canvas.drawRect(
      architrave,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [p.goldLight, p.goldMid, p.goldShadow],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(architrave),
    );
    canvas.drawRect(architrave, outlinePaint);

    // Outer triangular pediment roof with split light/shadow shading
    final peak = Offset(s * 0.50, s * 0.092);
    final leftEave = Offset(s * 0.065, s * 0.340);
    final rightEave = Offset(s * 0.935, s * 0.340);
    final bottomCenter = Offset(s * 0.50, s * 0.340);

    final leftRoofPath = Path()
      ..moveTo(peak.dx, peak.dy)
      ..lineTo(leftEave.dx, leftEave.dy)
      ..lineTo(bottomCenter.dx, bottomCenter.dy)
      ..close();
    canvas.drawPath(leftRoofPath, Paint()..color = p.goldLight);

    final rightRoofPath = Path()
      ..moveTo(peak.dx, peak.dy)
      ..lineTo(bottomCenter.dx, bottomCenter.dy)
      ..lineTo(rightEave.dx, rightEave.dy)
      ..close();
    canvas.drawPath(rightRoofPath, Paint()..color = p.goldMid);

    final fullRoofPath = Path()
      ..moveTo(peak.dx, peak.dy)
      ..lineTo(leftEave.dx, leftEave.dy)
      ..lineTo(rightEave.dx, rightEave.dy)
      ..close();
    canvas.drawPath(fullRoofPath, outlinePaint);

    // Inner recessed tympanum
    final tympanumPath = Path()
      ..moveTo(s * 0.50, s * 0.152)
      ..lineTo(s * 0.215, s * 0.312)
      ..lineTo(s * 0.785, s * 0.312)
      ..close();
    canvas.drawPath(tympanumPath, Paint()..color = p.tympanum);
    canvas.drawPath(tympanumPath, detailStrokePaint);

    // Glowing cyan crystal gem centered in the pediment
    final gemCenter = Offset(s * 0.50, s * 0.252);
    canvas.drawCircle(
      gemCenter,
      s * 0.075,
      Paint()
        ..color = p.gemBright.withValues(
          alpha: isOnGoldBackground ? 0.24 : 0.38,
        ),
    );

    final gemTop = Offset(gemCenter.dx, s * 0.194);
    final gemRight = Offset(s * 0.550, gemCenter.dy);
    final gemBottom = Offset(gemCenter.dx, s * 0.302);
    final gemLeft = Offset(s * 0.450, gemCenter.dy);

    final gemUpperLeft = Path()
      ..moveTo(gemTop.dx, gemTop.dy)
      ..lineTo(gemCenter.dx, gemCenter.dy)
      ..lineTo(gemLeft.dx, gemLeft.dy)
      ..close();
    final gemUpperRight = Path()
      ..moveTo(gemTop.dx, gemTop.dy)
      ..lineTo(gemRight.dx, gemRight.dy)
      ..lineTo(gemCenter.dx, gemCenter.dy)
      ..close();
    final gemLowerLeft = Path()
      ..moveTo(gemLeft.dx, gemLeft.dy)
      ..lineTo(gemCenter.dx, gemCenter.dy)
      ..lineTo(gemBottom.dx, gemBottom.dy)
      ..close();
    final gemLowerRight = Path()
      ..moveTo(gemCenter.dx, gemCenter.dy)
      ..lineTo(gemRight.dx, gemRight.dy)
      ..lineTo(gemBottom.dx, gemBottom.dy)
      ..close();

    canvas.drawPath(gemUpperLeft, Paint()..color = p.gemHighlight);
    canvas.drawPath(gemUpperRight, Paint()..color = p.gemBright);
    canvas.drawPath(gemLowerLeft, Paint()..color = p.gemBright);
    canvas.drawPath(gemLowerRight, Paint()..color = p.gemShadow);

    final gemOutline = Path()
      ..moveTo(gemTop.dx, gemTop.dy)
      ..lineTo(gemRight.dx, gemRight.dy)
      ..lineTo(gemBottom.dx, gemBottom.dy)
      ..lineTo(gemLeft.dx, gemLeft.dy)
      ..close();
    canvas.drawPath(
      gemOutline,
      Paint()
        ..color = p.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.45, 0.65 * scale)
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SacredTemplePainter oldDelegate) {
    return oldDelegate.isOnGoldBackground != isOnGoldBackground;
  }
}
