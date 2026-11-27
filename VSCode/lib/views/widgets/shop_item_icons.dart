import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'rpg_gift_icon.dart';
import 'temple_wing_icons.dart';

/// Shared helper wrapper matching [RoyalCastleIcon] and [temple_wing_icons.dart]
/// so every Shop / Altar of Offerings custom RPG vector icon renders cleanly at
/// a fixed square dimension inside a [RepaintBoundary].
class _ShopItemVectorIcon extends StatelessWidget {
  final double size;
  final CustomPainter painter;

  const _ShopItemVectorIcon({
    required this.size,
    required this.painter,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: painter,
        ),
      ),
    );
  }
}

Color _shopOutlineColor(bool isOnGoldBackground) =>
    isOnGoldBackground ? const Color(0xFF12181B) : const Color(0xFF263238);

Paint _shopOutlinePaint(
  double scale, {
  bool isOnGoldBackground = false,
  double baseWidth = 1.18,
}) {
  return Paint()
    ..color = _shopOutlineColor(isOnGoldBackground)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.80, baseWidth * scale)
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
}

Paint _shopDetailPaint(
  double scale, {
  bool isOnGoldBackground = false,
  double alpha = 0.78,
  double baseWidth = 0.78,
}) {
  return Paint()
    ..color = _shopOutlineColor(isOnGoldBackground).withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.55, baseWidth * scale)
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
}

void _drawFourPointSparkle(
  Canvas canvas,
  Offset center,
  double radius,
  Color fillColor,
  Paint? outline,
) {
  final star = Path()
    ..moveTo(center.dx, center.dy - radius)
    ..quadraticBezierTo(
      center.dx + radius * 0.16,
      center.dy - radius * 0.16,
      center.dx + radius,
      center.dy,
    )
    ..quadraticBezierTo(
      center.dx + radius * 0.16,
      center.dy + radius * 0.16,
      center.dx,
      center.dy + radius,
    )
    ..quadraticBezierTo(
      center.dx - radius * 0.16,
      center.dy + radius * 0.16,
      center.dx - radius,
      center.dy,
    )
    ..quadraticBezierTo(
      center.dx - radius * 0.16,
      center.dy - radius * 0.16,
      center.dx,
      center.dy - radius,
    )
    ..close();
  canvas.drawPath(star, Paint()..color = fillColor);
  if (outline != null) {
    canvas.drawPath(star, outline);
  }
}

// =============================================================================
// 1. PREDICTABILITY SCORE — Gauge + Scoreboard
// =============================================================================

/// Multi-toned RPG **Gauge + Scoreboard** icon for the Predictability Score
/// upgrade: forged gold-and-slate scoreboard plaque crowned by a 3-zone
/// semicircular Predictability Gauge with a golden-crimson indicator needle.
class PredictabilityScoreIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const PredictabilityScoreIcon({
    super.key,
    this.size = 32.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _ShopItemVectorIcon(
      size: size,
      painter: _PredictabilityScorePainter(
        isOnGoldBackground: isOnGoldBackground,
      ),
    );
  }
}

class _PredictabilityScorePainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _PredictabilityScorePainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _shopOutlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.15,
    );
    final detail = _shopDetailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.78,
    );

    final frameHighlight =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFF3B0);
    final frameLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFFFD54F);
    final frameMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFB300);
    final frameDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFF9A6500);

    const dialBg = Color(0xFF1D2730);
    const boardBg = Color(0xFF22303C);

    canvas.save();
    canvas.translate(ox, oy);

    final gaugeCenter = Offset(s * 0.50, s * 0.50);
    final outerR = s * 0.37;
    final innerR = s * 0.27;

    // 1. Sculpted semicircular brass/gold Predictability Gauge housing (top)
    final archOuter = Path()
      ..moveTo(gaugeCenter.dx - outerR, gaugeCenter.dy)
      ..arcTo(
        Rect.fromCircle(center: gaugeCenter, radius: outerR),
        math.pi,
        math.pi,
        false,
      )
      ..close();
    canvas.drawPath(
      archOuter,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [frameHighlight, frameLight, frameMid, frameDark],
          stops: const [0.0, 0.28, 0.65, 1.0],
        ).createShader(Rect.fromCircle(center: gaugeCenter, radius: outerR)),
    );
    canvas.drawPath(archOuter, outline);

    // Recessed dark gauge dial interior
    final dialPath = Path()
      ..moveTo(gaugeCenter.dx - innerR, gaugeCenter.dy)
      ..arcTo(
        Rect.fromCircle(center: gaugeCenter, radius: innerR),
        math.pi,
        math.pi,
        false,
      )
      ..close();
    canvas.drawPath(dialPath, Paint()..color = dialBg);

    // 3-zone arc bands (emerald -> amber -> crimson)
    final arcRect = Rect.fromCircle(center: gaugeCenter, radius: s * 0.215);
    final arcWidth = math.max(2.0, 2.5 * scale);
    final segments = [
      (start: math.pi * 1.06, sweep: math.pi * 0.26, color: const Color(0xFF4CAF50)),
      (start: math.pi * 1.36, sweep: math.pi * 0.28, color: const Color(0xFFFFCA28)),
      (start: math.pi * 1.68, sweep: math.pi * 0.26, color: const Color(0xFFEF5350)),
    ];
    for (final seg in segments) {
      canvas.drawArc(
        arcRect,
        seg.start,
        seg.sweep,
        false,
        Paint()
          ..color = seg.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = arcWidth
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawPath(dialPath, detail);

    // Crisp gauge needle pointing toward high predictability (~-42 deg)
    const needleAngle = -math.pi * 0.26;
    final needleTip = gaugeCenter +
        Offset(math.cos(needleAngle), math.sin(needleAngle)) * (s * 0.23);
    final needlePerp = Offset(-math.sin(needleAngle), math.cos(needleAngle)) *
        (s * 0.028);
    final needlePath = Path()
      ..moveTo(needleTip.dx, needleTip.dy)
      ..lineTo(gaugeCenter.dx + needlePerp.dx, gaugeCenter.dy + needlePerp.dy)
      ..lineTo(gaugeCenter.dx - needlePerp.dx, gaugeCenter.dy - needlePerp.dy)
      ..close();
    canvas.drawPath(needlePath, Paint()..color = const Color(0xFFFF5252));
    canvas.drawPath(needlePath, detail);

    // 2. Lower Match Scoreboard Plaque (y: 0.49..0.88)
    final boardOuter = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.11, s * 0.49, s * 0.89, s * 0.88),
      Radius.circular(s * 0.075),
    );
    canvas.drawRRect(
      boardOuter,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [frameHighlight, frameLight, frameMid, frameDark],
          stops: const [0.0, 0.25, 0.65, 1.0],
        ).createShader(boardOuter.outerRect),
    );
    canvas.drawRRect(boardOuter, outline);

    final boardInner = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.175, s * 0.555, s * 0.825, s * 0.815),
      Radius.circular(s * 0.045),
    );
    canvas.drawRRect(boardInner, Paint()..color = boardBg);
    canvas.drawRRect(boardInner, detail);

    // Center golden scoreboard divider
    canvas.drawLine(
      Offset(s * 0.50, s * 0.57),
      Offset(s * 0.50, s * 0.80),
      Paint()
        ..color = frameLight
        ..strokeWidth = math.max(0.85, 1.0 * scale)
        ..strokeCap = StrokeCap.round,
    );

    // Left (Player — cyan) & Right (AI — coral ruby) luminous score bars
    final leftScoreBar = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.22, s * 0.615, s * 0.445, s * 0.675),
      Radius.circular(s * 0.025),
    );
    final leftScoreSub = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.22, s * 0.71, s * 0.39, s * 0.76),
      Radius.circular(s * 0.02),
    );
    canvas.drawRRect(leftScoreBar, Paint()..color = const Color(0xFF4DD0E1));
    canvas.drawRRect(leftScoreSub, Paint()..color = const Color(0xFF80DEEA));

    final rightScoreBar = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.555, s * 0.615, s * 0.78, s * 0.675),
      Radius.circular(s * 0.025),
    );
    final rightScoreSub = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.61, s * 0.71, s * 0.78, s * 0.76),
      Radius.circular(s * 0.02),
    );
    canvas.drawRRect(rightScoreBar, Paint()..color = const Color(0xFFFF7043));
    canvas.drawRRect(rightScoreSub, Paint()..color = const Color(0xFFFFAB91));

    // Central pivot gem rivet on gauge axis
    canvas.drawCircle(
      gaugeCenter,
      s * 0.055,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [frameHighlight, frameMid, frameDark],
        ).createShader(Rect.fromCircle(center: gaugeCenter, radius: s * 0.055)),
    );
    canvas.drawCircle(gaugeCenter, s * 0.055, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PredictabilityScorePainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

// =============================================================================
// 2. RESET BUTTON — Ornate Golden Hourglass Reversal
// =============================================================================

/// Multi-toned RPG **Ornate Golden Hourglass Reversal** icon with sculpted gold
/// caps, luminous hourglass sand bulbs, and orbiting curved reset arrows.
class ResetButtonIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const ResetButtonIcon({
    super.key,
    this.size = 32.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _ShopItemVectorIcon(
      size: size,
      painter: _ResetButtonPainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _ResetButtonPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _ResetButtonPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _shopOutlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.15,
    );
    final detail = _shopDetailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.78,
    );

    final goldHi =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFF3B0);
    final goldLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFFFD54F);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFB300);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFF9A6500);

    const arrowLight = Color(0xFF80F3FF);
    const arrowMid = Color(0xFF00BCD4);
    const arrowDark = Color(0xFF006064);

    canvas.save();
    canvas.translate(ox, oy);

    final c = Offset(s * 0.50, s * 0.50);

    // 1. Two orbiting curved counter-clockwise reversal arrows flanking hourglass
    void drawOrbitArrow(double startAngle, double sweepAngle) {
      final rOut = s * 0.445;
      final rIn = s * 0.355;
      final rMid = (rOut + rIn) * 0.5;
      final endAngle = startAngle + sweepAngle;

      Offset polar(double a, double r) =>
          c + Offset(math.cos(a), math.sin(a)) * r;

      final path = Path();
      const steps = 14;
      final tail = polar(startAngle, rMid);
      path.moveTo(tail.dx, tail.dy);
      for (int i = 1; i <= steps; i++) {
        final t = i / steps;
        final a = startAngle + sweepAngle * t;
        final r = rMid + (rOut - rMid) * (0.30 + 0.70 * math.sin(t * math.pi * 0.72));
        final p = polar(a, r);
        path.lineTo(p.dx, p.dy);
      }
      final headOut = polar(endAngle + 0.04, s * 0.48);
      final headTip = polar(endAngle - 0.24, rMid);
      final headIn = polar(endAngle + 0.04, s * 0.305);
      path.lineTo(headOut.dx, headOut.dy);
      path.lineTo(headTip.dx, headTip.dy);
      path.lineTo(headIn.dx, headIn.dy);

      for (int i = steps; i >= 1; i--) {
        final t = i / steps;
        final a = startAngle + sweepAngle * t;
        final r = rMid - (rMid - rIn) * (0.30 + 0.70 * math.sin(t * math.pi * 0.72));
        final p = polar(a, r);
        path.lineTo(p.dx, p.dy);
      }
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [arrowLight, arrowMid, arrowDark],
          ).createShader(Rect.fromCircle(center: c, radius: s * 0.48)),
      );
      canvas.drawPath(path, outline);
    }

    // Top-left & bottom-right orbiting counter-clockwise arrows
    drawOrbitArrow(-math.pi * 0.14, -math.pi * 0.58);
    drawOrbitArrow(math.pi * 0.86, -math.pi * 0.58);

    // 2. Twin slender golden hourglass support pillars
    for (final px in [s * 0.335, s * 0.665]) {
      canvas.drawLine(
        Offset(px, s * 0.22),
        Offset(px, s * 0.78),
        Paint()
          ..color = goldDark
          ..strokeWidth = math.max(1.2, 1.5 * scale)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(px, s * 0.22),
        Offset(px, s * 0.78),
        detail,
      );
    }

    // 3. Double-bulbed hourglass crystal glass body
    final glassPath = Path()
      ..moveTo(s * 0.355, s * 0.235)
      ..lineTo(s * 0.645, s * 0.235)
      ..cubicTo(s * 0.645, s * 0.39, s * 0.54, s * 0.46, s * 0.52, s * 0.50)
      ..cubicTo(s * 0.54, s * 0.54, s * 0.645, s * 0.61, s * 0.645, s * 0.765)
      ..lineTo(s * 0.355, s * 0.765)
      ..cubicTo(s * 0.355, s * 0.61, s * 0.46, s * 0.54, s * 0.48, s * 0.50)
      ..cubicTo(s * 0.46, s * 0.46, s * 0.355, s * 0.39, s * 0.355, s * 0.235)
      ..close();

    canvas.drawPath(
      glassPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2), Color(0xFF80DEEA)],
        ).createShader(Rect.fromLTRB(s * 0.35, s * 0.23, s * 0.65, s * 0.77)),
    );

    // Upper amber time-sand wedge
    final upperSand = Path()
      ..moveTo(s * 0.385, s * 0.335)
      ..lineTo(s * 0.615, s * 0.335)
      ..cubicTo(s * 0.59, s * 0.42, s * 0.525, s * 0.465, s * 0.50, s * 0.49)
      ..cubicTo(s * 0.475, s * 0.465, s * 0.41, s * 0.42, s * 0.385, s * 0.335)
      ..close();
    canvas.drawPath(
      upperSand,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFE65100)],
        ).createShader(Rect.fromLTRB(s * 0.38, s * 0.33, s * 0.62, s * 0.49)),
    );

    // Lower amber time-sand mound + trickling sand stream
    final lowerSand = Path()
      ..moveTo(s * 0.50, s * 0.635)
      ..quadraticBezierTo(s * 0.585, s * 0.68, s * 0.625, s * 0.755)
      ..lineTo(s * 0.375, s * 0.755)
      ..quadraticBezierTo(s * 0.415, s * 0.68, s * 0.50, s * 0.635)
      ..close();
    canvas.drawPath(
      lowerSand,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
        ).createShader(Rect.fromLTRB(s * 0.37, s * 0.63, s * 0.63, s * 0.76)),
    );
    canvas.drawLine(
      Offset(s * 0.50, s * 0.50),
      Offset(s * 0.50, s * 0.64),
      Paint()
        ..color = const Color(0xFFFFC107)
        ..strokeWidth = math.max(0.85, 1.0 * scale)
        ..strokeCap = StrokeCap.round,
    );

    // Crisp specular highlight on left glass bulb
    canvas.drawLine(
      Offset(s * 0.395, s * 0.275),
      Offset(s * 0.42, s * 0.37),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.78)
        ..strokeWidth = math.max(0.8, 1.0 * scale)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(glassPath, outline);

    // 4. Sculpted beveled golden top & bottom hourglass end-caps
    for (final capY in [s * 0.165, s * 0.755]) {
      final capRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(s * 0.295, capY, s * 0.705, capY + s * 0.08),
        Radius.circular(s * 0.03),
      );
      canvas.drawRRect(
        capRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [goldHi, goldLight, goldMid, goldDark],
            stops: const [0.0, 0.28, 0.68, 1.0],
          ).createShader(capRect.outerRect),
      );
      canvas.drawRRect(capRect, outline);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ResetButtonPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

// =============================================================================
// 3. LEARN EARTH & METAL — Earth & Metal Elemental Shield Badge
// =============================================================================

/// Multi-toned RPG **Earth & Metal Elemental Shield** badge: heraldic kite
/// shield split into sculpted warm **Bronze/Earth** on the left and brushed
/// **Steel/Metal** on the right, framed in a riveted golden bevel rim.
class NewHandsIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const NewHandsIcon({
    super.key,
    this.size = 32.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _ShopItemVectorIcon(
      size: size,
      painter: _NewHandsPainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _NewHandsPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _NewHandsPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _shopOutlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.22,
    );
    final detail = _shopDetailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.78,
    );

    final rimHi =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFF3B0);
    final rimMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFB300);
    final rimDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFF8D5524);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Outer Heraldic Shield Contour
    final outerShield = Path()
      ..moveTo(s * 0.50, s * 0.09)
      ..quadraticBezierTo(s * 0.68, s * 0.16, s * 0.85, s * 0.19)
      ..cubicTo(s * 0.85, s * 0.54, s * 0.73, s * 0.78, s * 0.50, s * 0.915)
      ..cubicTo(s * 0.27, s * 0.78, s * 0.15, s * 0.54, s * 0.15, s * 0.19)
      ..quadraticBezierTo(s * 0.32, s * 0.16, s * 0.50, s * 0.09)
      ..close();

    canvas.drawPath(
      outerShield,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [rimHi, rimMid, rimDark],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.15, s * 0.09, s * 0.85, s * 0.915)),
    );

    // 2. Inner Split Field: Left Bronze/Earth, Right Steel/Metal
    final leftHalf = Path()
      ..moveTo(s * 0.50, s * 0.165)
      ..lineTo(s * 0.50, s * 0.835)
      ..cubicTo(s * 0.32, s * 0.72, s * 0.225, s * 0.52, s * 0.225, s * 0.25)
      ..quadraticBezierTo(s * 0.36, s * 0.225, s * 0.50, s * 0.165)
      ..close();

    final rightHalf = Path()
      ..moveTo(s * 0.50, s * 0.165)
      ..quadraticBezierTo(s * 0.64, s * 0.225, s * 0.775, s * 0.25)
      ..cubicTo(s * 0.775, s * 0.52, s * 0.68, s * 0.72, s * 0.50, s * 0.835)
      ..close();

    // Left: Warm Bronze / Terracotta Earth
    canvas.drawPath(
      leftHalf,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE6A15C), Color(0xFFB86B32), Color(0xFF6D3B18)],
          stops: [0.0, 0.50, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.22, s * 0.16, s * 0.50, s * 0.84)),
    );

    // Right: Brushed Forged Steel Metal
    canvas.drawPath(
      rightHalf,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFECEFF1), Color(0xFFB0BEC5), Color(0xFF546E7A)],
          stops: [0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.50, s * 0.16, s * 0.78, s * 0.84)),
    );

    // Earth faceted mountain / crystal boulder motif on left half
    final earthPeak = Path()
      ..moveTo(s * 0.275, s * 0.58)
      ..lineTo(s * 0.37, s * 0.38)
      ..lineTo(s * 0.46, s * 0.58)
      ..close();
    canvas.drawPath(
      earthPeak,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD580), Color(0xFFD4883B)],
        ).createShader(Rect.fromLTRB(s * 0.27, s * 0.38, s * 0.46, s * 0.58)),
    );
    canvas.drawPath(earthPeak, detail);

    // Metal forged steel diagonal sheen + steel gear/ingot chevron on right half
    final steelSheen = Path()
      ..moveTo(s * 0.54, s * 0.36)
      ..lineTo(s * 0.72, s * 0.29)
      ..lineTo(s * 0.70, s * 0.38)
      ..lineTo(s * 0.54, s * 0.45)
      ..close();
    canvas.drawPath(
      steelSheen,
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );

    final metalChevron = Path()
      ..moveTo(s * 0.555, s * 0.46)
      ..lineTo(s * 0.64, s * 0.385)
      ..lineTo(s * 0.715, s * 0.46)
      ..lineTo(s * 0.64, s * 0.585)
      ..close();
    canvas.drawPath(
      metalChevron,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFF90A4AE), Color(0xFF455A64)],
        ).createShader(Rect.fromLTRB(s * 0.55, s * 0.38, s * 0.72, s * 0.59)),
    );
    canvas.drawPath(metalChevron, detail);

    // Crisp inner shield border & central spine
    canvas.drawPath(leftHalf, detail);
    canvas.drawPath(rightHalf, detail);
    canvas.drawPath(outerShield, outline);

    // Central raised diamond boss emblem
    final boss = Path()
      ..moveTo(s * 0.50, s * 0.425)
      ..lineTo(s * 0.575, s * 0.50)
      ..lineTo(s * 0.50, s * 0.575)
      ..lineTo(s * 0.425, s * 0.50)
      ..close();
    canvas.drawPath(
      boss,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [rimHi, rimMid, rimDark],
        ).createShader(Rect.fromCircle(center: Offset(s * 0.50, s * 0.50), radius: s * 0.08)),
    );
    canvas.drawPath(boss, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_NewHandsPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

// =============================================================================
// 4. RANDOM BUTTON — Multi-faceted Golden RPG Dice Set (d6 & d4)
// =============================================================================

/// Multi-toned RPG **Golden Dice Set (`d6` & `d4`)** icon with isometric
/// split-shaded facets, crisp dark pips, and glowing star sparkles.
class RandomButtonIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const RandomButtonIcon({
    super.key,
    this.size = 32.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _ShopItemVectorIcon(
      size: size,
      painter: _RandomButtonPainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _RandomButtonPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _RandomButtonPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _shopOutlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.15,
    );
    final detail = _shopDetailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.78,
    );

    final goldHi =
        isOnGoldBackground ? const Color(0xFF607D8B) : const Color(0xFFFFF5B8);
    final goldLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFFFD54F);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFB300);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFF9A6500);
    final pipColor =
        isOnGoldBackground ? const Color(0xFFFFF3B0) : const Color(0xFF1F2A30);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Back-right faceted d4 pyramid die (crimson-gold / bronze RPG accents)
    final d4Apex = Offset(s * 0.72, s * 0.14);
    final d4Left = Offset(s * 0.52, s * 0.50);
    final d4Mid = Offset(s * 0.73, s * 0.565);
    final d4Right = Offset(s * 0.90, s * 0.45);

    final d4LeftFace = Path()
      ..moveTo(d4Apex.dx, d4Apex.dy)
      ..lineTo(d4Mid.dx, d4Mid.dy)
      ..lineTo(d4Left.dx, d4Left.dy)
      ..close();
    final d4RightFace = Path()
      ..moveTo(d4Apex.dx, d4Apex.dy)
      ..lineTo(d4Right.dx, d4Right.dy)
      ..lineTo(d4Mid.dx, d4Mid.dy)
      ..close();

    canvas.drawPath(
      d4LeftFace,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF8A65), Color(0xFFE53935)],
        ).createShader(Rect.fromLTRB(s * 0.52, s * 0.14, s * 0.74, s * 0.57)),
    );
    canvas.drawPath(
      d4RightFace,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD32F2F), Color(0xFF7F0000)],
        ).createShader(Rect.fromLTRB(s * 0.72, s * 0.14, s * 0.90, s * 0.57)),
    );
    canvas.drawPath(d4LeftFace, outline);
    canvas.drawPath(d4RightFace, outline);
    // Tiny golden pip dot on d4 left face
    canvas.drawCircle(
      Offset(s * 0.655, s * 0.415),
      s * 0.025,
      Paint()..color = const Color(0xFFFFF3B0),
    );

    // 2. Foreground Isometric Golden d6 Cube Die
    final topPt = Offset(s * 0.40, s * 0.29);
    final leftTop = Offset(s * 0.14, s * 0.43);
    final centerPt = Offset(s * 0.40, s * 0.575);
    final rightTop = Offset(s * 0.66, s * 0.43);
    final leftBot = Offset(s * 0.14, s * 0.735);
    final botPt = Offset(s * 0.40, s * 0.88);
    final rightBot = Offset(s * 0.66, s * 0.735);

    final topFace = Path()
      ..moveTo(topPt.dx, topPt.dy)
      ..lineTo(rightTop.dx, rightTop.dy)
      ..lineTo(centerPt.dx, centerPt.dy)
      ..lineTo(leftTop.dx, leftTop.dy)
      ..close();

    final leftFace = Path()
      ..moveTo(leftTop.dx, leftTop.dy)
      ..lineTo(centerPt.dx, centerPt.dy)
      ..lineTo(botPt.dx, botPt.dy)
      ..lineTo(leftBot.dx, leftBot.dy)
      ..close();

    final rightFace = Path()
      ..moveTo(centerPt.dx, centerPt.dy)
      ..lineTo(rightTop.dx, rightTop.dy)
      ..lineTo(rightBot.dx, rightBot.dy)
      ..lineTo(botPt.dx, botPt.dy)
      ..close();

    canvas.drawPath(
      topFace,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [goldHi, goldLight],
        ).createShader(Rect.fromLTRB(s * 0.14, s * 0.29, s * 0.66, s * 0.58)),
    );
    canvas.drawPath(
      leftFace,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [goldLight, goldMid],
        ).createShader(Rect.fromLTRB(s * 0.14, s * 0.43, s * 0.40, s * 0.88)),
    );
    canvas.drawPath(
      rightFace,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [goldMid, goldDark],
        ).createShader(Rect.fromLTRB(s * 0.40, s * 0.43, s * 0.66, s * 0.88)),
    );

    canvas.drawPath(topFace, outline);
    canvas.drawPath(leftFace, outline);
    canvas.drawPath(rightFace, outline);

    // Pips on d6: 1 on top, 2 on left, 3 on right
    final pipPaint = Paint()..color = pipColor;
    final pipR = s * 0.036;
    canvas.drawCircle(Offset(s * 0.40, s * 0.43), pipR * 1.12, pipPaint);

    // Left face: 2 pips
    canvas.drawCircle(Offset(s * 0.22, s * 0.57), pipR * 0.92, pipPaint);
    canvas.drawCircle(Offset(s * 0.32, s * 0.72), pipR * 0.92, pipPaint);

    // Right face: 3 diagonal pips
    canvas.drawCircle(Offset(s * 0.58, s * 0.555), pipR * 0.85, pipPaint);
    canvas.drawCircle(Offset(s * 0.53, s * 0.655), pipR * 0.85, pipPaint);
    canvas.drawCircle(Offset(s * 0.48, s * 0.755), pipR * 0.85, pipPaint);

    // 3. Radiant golden sparkles accenting the dice set
    _drawFourPointSparkle(
      canvas,
      Offset(s * 0.20, s * 0.20),
      s * 0.085,
      isOnGoldBackground ? const Color(0xFFFFF8E1) : const Color(0xFFFFE082),
      detail,
    );
    _drawFourPointSparkle(
      canvas,
      Offset(s * 0.84, s * 0.72),
      s * 0.068,
      isOnGoldBackground ? const Color(0xFFFFF8E1) : const Color(0xFF80F3FF),
      detail,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RandomButtonPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

// =============================================================================
// 5. SHOW ALGORITHM — Runic Markov Orb Nodes + Data-Streams + Small Eye
// =============================================================================

/// Multi-toned RPG **Markov Transition Matrix** icon: grid of 4 glowing Runic
/// Markov Orb nodes linked by golden-cyan data-stream edges around a central
/// inspecting Seer Eye.
class MarkovMatrixIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const MarkovMatrixIcon({
    super.key,
    this.size = 32.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _ShopItemVectorIcon(
      size: size,
      painter: _MarkovMatrixPainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _MarkovMatrixPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _MarkovMatrixPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _shopOutlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.10,
    );

    final streamColor =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFF4DD0E1);
    final goldRim =
        isOnGoldBackground ? const Color(0xFF37474F) : const Color(0xFFFFD54F);

    canvas.save();
    canvas.translate(ox, oy);

    // 4 Runic Markov Orb node coordinates
    final tl = Offset(s * 0.22, s * 0.22);
    final tr = Offset(s * 0.78, s * 0.22);
    final bl = Offset(s * 0.22, s * 0.78);
    final br = Offset(s * 0.78, s * 0.78);
    final center = Offset(s * 0.50, s * 0.50);

    // 1. Glowing data-stream transition grid lines (outer square + diagonals)
    final streamCasing = Paint()
      ..color = _shopOutlineColor(isOnGoldBackground).withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, 2.3 * scale)
      ..strokeCap = StrokeCap.round;
    final streamPaint = Paint()
      ..color = streamColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.95, 1.25 * scale)
      ..strokeCap = StrokeCap.round;
    final diagPaint = Paint()
      ..color = goldRim
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.85, 1.05 * scale)
      ..strokeCap = StrokeCap.round;

    final edges = [
      (tl, tr),
      (tr, br),
      (br, bl),
      (bl, tl),
    ];
    for (final (a, b) in edges) {
      canvas.drawLine(a, b, streamCasing);
      canvas.drawLine(a, b, streamPaint);
    }
    canvas.drawLine(tl, br, streamCasing);
    canvas.drawLine(tr, bl, streamCasing);
    canvas.drawLine(tl, br, diagPaint);
    canvas.drawLine(tr, bl, diagPaint);

    // 2. Four Glossy Runic Markov Orbs at the matrix corners
    final nodes = [
      (pos: tl, hi: const Color(0xFFFFAB91), mid: const Color(0xFFFF5722), dark: const Color(0xFFBF360C)),
      (pos: tr, hi: const Color(0xFF80F3FF), mid: const Color(0xFF00BCD4), dark: const Color(0xFF006064)),
      (pos: bl, hi: const Color(0xFFA5D6A7), mid: const Color(0xFF43A047), dark: const Color(0xFF1B5E20)),
      (pos: br, hi: const Color(0xFFFFF3B0), mid: const Color(0xFFFFB300), dark: const Color(0xFF8D5524)),
    ];
    final nodeR = s * 0.125;
    for (final node in nodes) {
      final rect = Rect.fromCircle(center: node.pos, radius: nodeR);
      canvas.drawCircle(
        node.pos,
        nodeR,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            radius: 0.9,
            colors: [node.hi, node.mid, node.dark],
          ).createShader(rect),
      );
      canvas.drawCircle(
        node.pos + Offset(-nodeR * 0.30, -nodeR * 0.30),
        nodeR * 0.25,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
      canvas.drawCircle(node.pos, nodeR, outline);
    }

    // 3. Central Small Inspecting Seer Eye
    final eyePath = Path()
      ..moveTo(s * 0.28, center.dy)
      ..quadraticBezierTo(center.dx, s * 0.33, s * 0.72, center.dy)
      ..quadraticBezierTo(center.dx, s * 0.67, s * 0.28, center.dy)
      ..close();

    // Subtle golden eye housing rim
    canvas.drawPath(
      eyePath,
      Paint()
        ..color = goldRim
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, 2.4 * scale)
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(eyePath, Paint()..color = const Color(0xFFFAF8F2));
    canvas.drawPath(eyePath, outline);

    // Radiant indigo-cyan iris & pupil
    final irisR = s * 0.088;
    canvas.drawCircle(
      center,
      irisR,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF80F3FF), Color(0xFF5E35B1), Color(0xFF1A237E)],
        ).createShader(Rect.fromCircle(center: center, radius: irisR)),
    );
    canvas.drawCircle(center, s * 0.040, Paint()..color = const Color(0xFF12181B));
    canvas.drawCircle(
      center + Offset(-s * 0.030, -s * 0.028),
      s * 0.020,
      Paint()..color = Colors.white,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkovMatrixPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

// =============================================================================
// 6. YOUR PREDICTION — Cleric's Hand with Divine Foresight Marking a Scroll
// =============================================================================

/// Multi-toned RPG **Cleric's Hand with Divine Foresight** icon: warm parchment
/// scroll with sculpted gold rollers while a cleric's hand inscribes a glowing
/// foresight rune upon it.
class YourPredictionIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const YourPredictionIcon({
    super.key,
    this.size = 32.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _ShopItemVectorIcon(
      size: size,
      painter: _YourPredictionPainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _YourPredictionPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _YourPredictionPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _shopOutlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.15,
    );
    final detail = _shopDetailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.72,
    );

    final goldHi =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFF3B0);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFB300);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFF9A6500);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Unrolled Warm Parchment Scroll Sheet (left-center)
    final scrollBody = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.14, s * 0.24, s * 0.67, s * 0.84),
      Radius.circular(s * 0.04),
    );
    canvas.drawRRect(
      scrollBody,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF9EA), Color(0xFFF0DFC0), Color(0xFFCBB187)],
        ).createShader(scrollBody.outerRect),
    );
    canvas.drawRRect(scrollBody, outline);

    // Top & bottom golden scroll rollers
    for (final ry in [s * 0.18, s * 0.80]) {
      final roller = RRect.fromRectAndRadius(
        Rect.fromLTRB(s * 0.10, ry, s * 0.71, ry + s * 0.085),
        Radius.circular(s * 0.042),
      );
      canvas.drawRRect(
        roller,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [goldHi, goldMid, goldDark],
          ).createShader(roller.outerRect),
      );
      canvas.drawRRect(roller, outline);
    }

    // Subtle scripture lines on parchment
    for (final ly in [s * 0.36, s * 0.72]) {
      canvas.drawLine(
        Offset(s * 0.22, ly),
        Offset(s * 0.56, ly),
        Paint()
          ..color = const Color(0xFF8D6E63).withValues(alpha: 0.55)
          ..strokeWidth = math.max(0.85, 1.0 * scale)
          ..strokeCap = StrokeCap.round,
      );
    }

    // 2. Glowing Divine Foresight Rune marked onto the parchment
    final runeCenter = Offset(s * 0.39, s * 0.54);
    canvas.drawCircle(
      runeCenter,
      s * 0.135,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF00E5FF).withValues(alpha: 0.55),
            const Color(0xFFFFD54F).withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: runeCenter, radius: s * 0.135)),
    );
    _drawFourPointSparkle(
      canvas,
      runeCenter,
      s * 0.105,
      const Color(0xFF00E5FF),
      detail,
    );

    // 3. Cleric's Hand with Sky-Blue Robe Sleeve pointing/inscribing the rune
    final sleeve = Path()
      ..moveTo(s * 0.73, s * 0.31)
      ..lineTo(s * 0.90, s * 0.18)
      ..lineTo(s * 0.92, s * 0.44)
      ..lineTo(s * 0.77, s * 0.50)
      ..close();
    canvas.drawPath(
      sleeve,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF81D4FA), Color(0xFF29B6F6), Color(0xFF0277BD)],
        ).createShader(Rect.fromLTRB(s * 0.72, s * 0.18, s * 0.92, s * 0.50)),
    );
    canvas.drawPath(sleeve, outline);

    // Cleric's sculpted hand & pointing forefinger touching the foresight mark
    final hand = Path()
      ..moveTo(s * 0.75, s * 0.34)
      ..lineTo(s * 0.48, s * 0.48)
      ..cubicTo(s * 0.445, s * 0.498, s * 0.46, s * 0.545, s * 0.505, s * 0.535)
      ..lineTo(s * 0.64, s * 0.49)
      ..cubicTo(s * 0.68, s * 0.53, s * 0.74, s * 0.525, s * 0.78, s * 0.47)
      ..close();
    canvas.drawPath(
      hand,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4C9B0), Color(0xFFE0A98B), Color(0xFFB8785B)],
        ).createShader(Rect.fromLTRB(s * 0.45, s * 0.34, s * 0.78, s * 0.55)),
    );
    canvas.drawPath(hand, outline);

    // Radiant foresight halo sparkle above fingertip
    _drawFourPointSparkle(
      canvas,
      Offset(s * 0.56, s * 0.24),
      s * 0.068,
      const Color(0xFFFFE082),
      detail,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_YourPredictionPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

// =============================================================================
// 7. PC NEXT MOVE — Deep Seer Eye Observing Opponent's Mechanical Hand
// =============================================================================

/// Multi-toned RPG **Deep Seer Eye** observing the opponent's **Mechanical
/// Robot Hand** with glowing arcane scanning rays.
class EnemyNextMoveIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const EnemyNextMoveIcon({
    super.key,
    this.size = 32.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _ShopItemVectorIcon(
      size: size,
      painter: _EnemyNextMovePainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _EnemyNextMovePainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _EnemyNextMovePainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _shopOutlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.15,
    );
    final detail = _shopDetailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.78,
    );

    final goldHi =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFF3B0);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFB300);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Translucent Cyan-Violet Foresight Scan Cone from Eye -> Mechanical Hand
    final scanCone = Path()
      ..moveTo(s * 0.44, s * 0.36)
      ..lineTo(s * 0.56, s * 0.36)
      ..lineTo(s * 0.76, s * 0.62)
      ..lineTo(s * 0.24, s * 0.62)
      ..close();
    canvas.drawPath(
      scanCone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF00E5FF).withValues(alpha: 0.42),
            const Color(0xFF7C4DFF).withValues(alpha: 0.08),
          ],
        ).createShader(Rect.fromLTRB(s * 0.24, s * 0.36, s * 0.76, s * 0.62)),
    );

    // 2. Commanding Deep Seer Eye (upper portion: y 0.11..0.41)
    final eyeCenter = Offset(s * 0.50, s * 0.26);
    final eyePath = Path()
      ..moveTo(s * 0.14, eyeCenter.dy)
      ..quadraticBezierTo(s * 0.50, s * 0.06, s * 0.86, eyeCenter.dy)
      ..quadraticBezierTo(s * 0.50, s * 0.46, s * 0.14, eyeCenter.dy)
      ..close();

    canvas.drawPath(
      eyePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [goldHi, goldMid],
        ).createShader(Rect.fromLTRB(s * 0.14, s * 0.11, s * 0.86, s * 0.41))
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.1, 2.6 * scale)
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(eyePath, Paint()..color = const Color(0xFFF3F8FF));
    canvas.drawPath(eyePath, outline);

    final irisR = s * 0.11;
    canvas.drawCircle(
      eyeCenter,
      irisR,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF80F3FF), Color(0xFF7E57C2), Color(0xFF311B92)],
        ).createShader(Rect.fromCircle(center: eyeCenter, radius: irisR)),
    );
    canvas.drawCircle(eyeCenter, s * 0.048, Paint()..color = const Color(0xFF12181B));
    canvas.drawCircle(
      eyeCenter + Offset(-s * 0.036, -s * 0.034),
      s * 0.024,
      Paint()..color = Colors.white,
    );

    // 3. Opponent's Articulated Mechanical Steel Hand (lower portion: y 0.50..0.90)
    // Articulated robot fingers rising from palm
    final fingerSpecs = [
      Rect.fromLTRB(s * 0.26, s * 0.54, s * 0.35, s * 0.72),
      Rect.fromLTRB(s * 0.38, s * 0.48, s * 0.475, s * 0.71),
      Rect.fromLTRB(s * 0.505, s * 0.49, s * 0.60, s * 0.71),
      Rect.fromLTRB(s * 0.63, s * 0.55, s * 0.72, s * 0.72),
    ];
    for (final rect in fingerSpecs) {
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.032));
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFECEFF1), Color(0xFF90A4AE), Color(0xFF455A64)],
          ).createShader(rect),
      );
      canvas.drawRRect(rr, outline);
      // Knuckle joint seam
      final midY = (rect.top + rect.bottom) * 0.52;
      canvas.drawLine(
        Offset(rect.left + s * 0.015, midY),
        Offset(rect.right - s * 0.015, midY),
        detail,
      );
    }

    // Mechanical gauntlet palm & wrist cuff
    final palm = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.25, s * 0.66, s * 0.73, s * 0.89),
      Radius.circular(s * 0.06),
    );
    canvas.drawRRect(
      palm,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCFD8DC), Color(0xFF78909C), Color(0xFF37474F)],
        ).createShader(palm.outerRect),
    );
    canvas.drawRRect(palm, outline);

    // Glowing crimson mechanical palm core rivet
    final corePos = Offset(s * 0.49, s * 0.775);
    canvas.drawCircle(
      corePos,
      s * 0.055,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFF8A80), Color(0xFFE53935), Color(0xFF8E0000)],
        ).createShader(Rect.fromCircle(center: corePos, radius: s * 0.055)),
    );
    canvas.drawCircle(corePos, s * 0.055, detail);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_EnemyNextMovePainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

// =============================================================================
// 8. GIFT BOX — Preserves Existing Bespoke RPG Gift Box Painter
// =============================================================================

/// Shop item wrapper for the **Gift Box** upgrade, reusing the existing
/// multi-toned crimson-and-gold [RpgGiftIcon] `CustomPainter`.
class GiftBoxIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const GiftBoxIcon({
    super.key,
    this.size = 32.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return RpgGiftIcon(
      size: size,
      showGlow: !isOnGoldBackground,
    );
  }
}

// =============================================================================
// 9. SUGGESTION — Golden Lightbulb of Strategy + Warhammer
// =============================================================================

/// Multi-toned RPG **Golden Lightbulb of Strategy** paired with a forged
/// steel-and-bronze **Warhammer** for the Optimal Suggestion upgrade.
class StrategySuggestionIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const StrategySuggestionIcon({
    super.key,
    this.size = 32.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _ShopItemVectorIcon(
      size: size,
      painter: _StrategySuggestionPainter(
        isOnGoldBackground: isOnGoldBackground,
      ),
    );
  }
}

class _StrategySuggestionPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _StrategySuggestionPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _shopOutlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.15,
    );
    final detail = _shopDetailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.78,
    );

    final bulbHi =
        isOnGoldBackground ? const Color(0xFFFFF8E1) : const Color(0xFFFFFDE7);
    final bulbMid =
        isOnGoldBackground ? const Color(0xFFFFD54F) : const Color(0xFFFFCA28);
    final bulbDeep =
        isOnGoldBackground ? const Color(0xFFE65100) : const Color(0xFFFF8F00);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Diagonal Forged Medieval Warhammer behind/crossing the lightbulb
    canvas.save();
    canvas.translate(s * 0.56, s * 0.52);
    canvas.rotate(math.pi * 0.22);

    // Wooden-bronze warhammer shaft
    final shaft = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, s * 0.08), width: s * 0.085, height: s * 0.68),
      Radius.circular(s * 0.028),
    );
    canvas.drawRRect(
      shaft,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFC47A38), Color(0xFF8D5524), Color(0xFF5D3414)],
        ).createShader(shaft.outerRect),
    );
    canvas.drawRRect(shaft, outline);

    // Forged steel warhammer head with beveled striking face & rear spike
    final headPath = Path()
      ..moveTo(-s * 0.22, -s * 0.30)
      ..lineTo(s * 0.14, -s * 0.30)
      ..lineTo(s * 0.26, -s * 0.21) // tactical back spike
      ..lineTo(s * 0.14, -s * 0.12)
      ..lineTo(-s * 0.22, -s * 0.12)
      ..close();
    canvas.drawPath(
      headPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFECEFF1), Color(0xFF90A4AE), Color(0xFF455A64)],
        ).createShader(Rect.fromLTRB(-s * 0.22, -s * 0.30, s * 0.26, -s * 0.12)),
    );
    canvas.drawPath(headPath, outline);

    // Golden reinforcement band on hammerhead
    final band = Rect.fromLTRB(-s * 0.055, -s * 0.305, s * 0.055, -s * 0.115);
    canvas.drawRect(band, Paint()..color = const Color(0xFFFFB300));
    canvas.drawRect(band, detail);
    canvas.restore();

    // 2. Radiant Strategy Inspiration Rays around the lightbulb
    final rayPaint = Paint()
      ..color = isOnGoldBackground
          ? const Color(0xFF263238)
          : const Color(0xFFFFE082)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 1.25 * scale)
      ..strokeCap = StrokeCap.round;
    final bulbCenter = Offset(s * 0.39, s * 0.42);
    for (final deg in [-145.0, -90.0, -35.0]) {
      final a = deg * math.pi / 180.0;
      canvas.drawLine(
        bulbCenter + Offset(math.cos(a), math.sin(a)) * (s * 0.25),
        bulbCenter + Offset(math.cos(a), math.sin(a)) * (s * 0.33),
        rayPaint,
      );
    }

    // 3. Golden Lightbulb Glass Globe (foreground left-center)
    final bulbPath = Path()
      ..moveTo(s * 0.295, s * 0.64)
      ..cubicTo(s * 0.295, s * 0.56, s * 0.18, s * 0.52, s * 0.18, s * 0.395)
      ..arcTo(
        Rect.fromCircle(center: bulbCenter, radius: s * 0.21),
        math.pi * 0.92,
        math.pi * 1.16,
        false,
      )
      ..cubicTo(s * 0.60, s * 0.52, s * 0.485, s * 0.56, s * 0.485, s * 0.64)
      ..close();

    canvas.drawPath(
      bulbPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.30),
          radius: 0.92,
          colors: [bulbHi, bulbMid, bulbDeep],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: bulbCenter, radius: s * 0.23)),
    );
    canvas.drawPath(bulbPath, outline);

    // Bright inner filament arc
    final filament = Path()
      ..moveTo(s * 0.34, s * 0.57)
      ..lineTo(s * 0.34, s * 0.44)
      ..quadraticBezierTo(s * 0.39, s * 0.38, s * 0.44, s * 0.44)
      ..lineTo(s * 0.44, s * 0.57);
    canvas.drawPath(
      filament,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.9, 1.1 * scale)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Threaded metallic brass lightbulb screw base
    final screwRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(s * 0.295, s * 0.635, s * 0.485, s * 0.775),
      bottomLeft: Radius.circular(s * 0.05),
      bottomRight: Radius.circular(s * 0.05),
    );
    canvas.drawRRect(
      screwRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFCFD8DC), Color(0xFF90A4AE), Color(0xFF455A64)],
        ).createShader(screwRect.outerRect),
    );
    canvas.drawRRect(screwRect, outline);
    canvas.drawLine(Offset(s * 0.305, s * 0.69), Offset(s * 0.475, s * 0.69), detail);
    canvas.drawLine(Offset(s * 0.32, s * 0.735), Offset(s * 0.46, s * 0.735), detail);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_StrategySuggestionPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

// =============================================================================
// 10. REMOVE ADS — International "Silence" Vow Icon (Lips + Raised Finger)
// =============================================================================

/// International **"Silence" Vow** icon for Remove Ads: stylized lips with an
/// index finger raised centrally in a "Shh" gesture, delegating to the bespoke
/// [VowOfSilenceIcon] painter in `temple_wing_icons.dart` so both widget types
/// share the exact high-contrast vector artwork.
class RemoveAdsIcon extends StatelessWidget {
  final double size;
  final bool isActive;
  final bool isOnGoldBackground;

  const RemoveAdsIcon({
    super.key,
    this.size = 32.0,
    this.isActive = true,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return VowOfSilenceIcon(
      size: size,
      isActive: isActive,
      isOnGoldBackground: isOnGoldBackground,
    );
  }
}

// =============================================================================
// 11. NEW SKIN — Classic Hands Theme Crest (Retained for Shop Consistency)
// =============================================================================

/// Multi-toned RPG **Hands Theme Crest** icon for the classic New Skin upgrade:
/// sculpted golden-framed medallion featuring a stylized gauntlet/hand emblem
/// and dual-tone ribbon flourish.
class NewSkinIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const NewSkinIcon({
    super.key,
    this.size = 32.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _ShopItemVectorIcon(
      size: size,
      painter: _NewSkinPainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _NewSkinPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _NewSkinPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _shopOutlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.15,
    );
    final detail = _shopDetailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.72,
    );

    final goldHi =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFF3B0);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFB300);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFF8D5524);

    canvas.save();
    canvas.translate(ox, oy);

    final c = Offset(s * 0.50, s * 0.50);

    // 1. Ornate Gilded Medallion Frame
    final outerR = s * 0.41;
    canvas.drawCircle(
      c,
      outerR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [goldHi, goldMid, goldDark],
        ).createShader(Rect.fromCircle(center: c, radius: outerR)),
    );
    canvas.drawCircle(c, outerR, outline);

    // Inner Royal Indigo-Velvet Backing
    final innerR = s * 0.32;
    canvas.drawCircle(
      c,
      innerR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.25, -0.25),
          colors: [Color(0xFF5C6BC0), Color(0xFF283593), Color(0xFF1A237E)],
        ).createShader(Rect.fromCircle(center: c, radius: innerR)),
    );
    canvas.drawCircle(c, innerR, detail);

    // 2. Classic Open Hand / Gauntlet Silhouette inside Medallion
    final hand = Path()
      ..moveTo(s * 0.34, s * 0.56)
      ..lineTo(s * 0.34, s * 0.37)
      ..cubicTo(s * 0.34, s * 0.33, s * 0.405, s * 0.33, s * 0.405, s * 0.37)
      ..lineTo(s * 0.405, s * 0.47)
      ..lineTo(s * 0.43, s * 0.32)
      ..cubicTo(s * 0.43, s * 0.28, s * 0.50, s * 0.28, s * 0.50, s * 0.32)
      ..lineTo(s * 0.50, s * 0.47)
      ..lineTo(s * 0.525, s * 0.335)
      ..cubicTo(s * 0.525, s * 0.295, s * 0.59, s * 0.295, s * 0.59, s * 0.335)
      ..lineTo(s * 0.59, s * 0.49)
      ..lineTo(s * 0.62, s * 0.40)
      ..cubicTo(s * 0.635, s * 0.37, s * 0.685, s * 0.39, s * 0.67, s * 0.43)
      ..lineTo(s * 0.625, s * 0.62)
      ..cubicTo(s * 0.61, s * 0.70, s * 0.54, s * 0.73, s * 0.46, s * 0.73)
      ..cubicTo(s * 0.38, s * 0.73, s * 0.34, s * 0.67, s * 0.34, s * 0.56)
      ..close();

    canvas.drawPath(
      hand,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8E1), Color(0xFFFFE0B2), Color(0xFFE6A15C)],
        ).createShader(Rect.fromLTRB(s * 0.33, s * 0.28, s * 0.68, s * 0.74)),
    );
    canvas.drawPath(hand, outline);

    _drawFourPointSparkle(
      canvas,
      Offset(s * 0.84, s * 0.19),
      s * 0.068,
      const Color(0xFFFFE082),
      detail,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_NewSkinPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

// =============================================================================
// 12. CRYSTAL BALL — Shimmering Oracular Crystal Ball with Radiant Seer Eye
// =============================================================================

/// Multi-toned RPG **Oracular Crystal Ball** icon containing a radiant golden
/// & cyan Seer Eye, swirling cosmic dust, glossy specular reflection, and an
/// ornate gilded pedestal base.
class CrystalBallIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const CrystalBallIcon({
    super.key,
    this.size = 32.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _ShopItemVectorIcon(
      size: size,
      painter: _CrystalBallPainter(
        isEnhancedPlus: false,
        isOnGoldBackground: isOnGoldBackground,
      ),
    );
  }
}

// =============================================================================
// 13. CRYSTAL BALL+ — Enhanced Crystal Ball+ with Plus (+) Halo & Arcane Aura
// =============================================================================

/// Enhanced multi-toned RPG **Crystal Ball+** icon with a stronger radiant
/// cosmic aura halo, heightened golden-cyan Seer Eye, and a beveled golden
/// **`+` (Plus)** halo emblem at the upper-right crest.
class CrystalBallPlusIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const CrystalBallPlusIcon({
    super.key,
    this.size = 32.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _ShopItemVectorIcon(
      size: size,
      painter: _CrystalBallPainter(
        isEnhancedPlus: true,
        isOnGoldBackground: isOnGoldBackground,
      ),
    );
  }
}

class _CrystalBallPainter extends CustomPainter {
  final bool isEnhancedPlus;
  final bool isOnGoldBackground;

  const _CrystalBallPainter({
    required this.isEnhancedPlus,
    required this.isOnGoldBackground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _shopOutlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.15,
    );
    final detail = _shopDetailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.76,
    );

    final goldHi =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFF3B0);
    final goldLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFFFD54F);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFB300);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFF8D5524);

    canvas.save();
    canvas.translate(ox, oy);

    final orbCenter = Offset(s * 0.47, s * 0.43);
    final orbR = s * 0.325;

    // 1. Enhanced Arcane Aura Halo behind the Crystal Ball
    if (isEnhancedPlus) {
      canvas.drawCircle(
        orbCenter,
        orbR * 1.42,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF00E5FF).withValues(alpha: 0.42),
              const Color(0xFFE040FB).withValues(alpha: 0.28),
              const Color(0xFFFFD54F).withValues(alpha: 0.14),
              Colors.transparent,
            ],
            stops: const [0.0, 0.48, 0.78, 1.0],
          ).createShader(
            Rect.fromCircle(center: orbCenter, radius: orbR * 1.42),
          ),
      );
      // Radiant arcane halo ring
      canvas.drawCircle(
        orbCenter,
        orbR * 1.16,
        Paint()
          ..color = isOnGoldBackground
              ? const Color(0xFF263238).withValues(alpha: 0.55)
              : const Color(0xFFFFE082).withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.85, 1.05 * scale),
      );
    } else {
      canvas.drawCircle(
        orbCenter,
        orbR * 1.25,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF7C4DFF).withValues(alpha: 0.28),
              const Color(0xFF00E5FF).withValues(alpha: 0.12),
              Colors.transparent,
            ],
            stops: const [0.0, 0.60, 1.0],
          ).createShader(
            Rect.fromCircle(center: orbCenter, radius: orbR * 1.25),
          ),
      );
    }

    // 2. Translucent Cosmic Crystal Sphere
    final orbRect = Rect.fromCircle(center: orbCenter, radius: orbR);
    canvas.drawCircle(
      orbCenter,
      orbR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.32, -0.35),
          radius: 0.98,
          colors: isEnhancedPlus
              ? const [
                  Color(0xFFE0F7FA),
                  Color(0xFFCE93D8),
                  Color(0xFF7E57C2),
                  Color(0xFF311B92),
                  Color(0xFF1A0E3D),
                ]
              : const [
                  Color(0xFFE1F5FE),
                  Color(0xFFB39DDB),
                  Color(0xFF5E35B1),
                  Color(0xFF28176B),
                  Color(0xFF150B38),
                ],
          stops: const [0.0, 0.24, 0.56, 0.84, 1.0],
        ).createShader(orbRect),
    );

    // Swirling cosmic dust & nebula star specks inside sphere
    final dustArc = Path()
      ..addArc(
        Rect.fromCircle(center: orbCenter, radius: orbR * 0.70),
        -math.pi * 0.12,
        math.pi * 0.72,
      );
    canvas.drawPath(
      dustArc,
      Paint()
        ..color = const Color(0xFF80F3FF).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, 1.3 * scale)
        ..strokeCap = StrokeCap.round,
    );
    for (final mote in [
      Offset(orbCenter.dx - s * 0.17, orbCenter.dy + s * 0.08),
      Offset(orbCenter.dx + s * 0.16, orbCenter.dy - s * 0.12),
      Offset(orbCenter.dx + s * 0.13, orbCenter.dy + s * 0.15),
    ]) {
      canvas.drawCircle(
        mote,
        s * 0.018,
        Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.90),
      );
    }

    // 3. Radiant Seer Eye nestled inside the Crystal Ball
    final eyePath = Path()
      ..moveTo(orbCenter.dx - s * 0.18, orbCenter.dy)
      ..quadraticBezierTo(
        orbCenter.dx,
        orbCenter.dy - s * 0.13,
        orbCenter.dx + s * 0.18,
        orbCenter.dy,
      )
      ..quadraticBezierTo(
        orbCenter.dx,
        orbCenter.dy + s * 0.13,
        orbCenter.dx - s * 0.18,
        orbCenter.dy,
      )
      ..close();
    canvas.drawPath(
      eyePath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE0F7FA), Color(0xFFFFFFFF)],
        ).createShader(orbRect),
    );
    canvas.drawPath(
      eyePath,
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.85, 1.05 * scale),
    );

    final irisR = s * 0.068;
    canvas.drawCircle(
      orbCenter,
      irisR,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF80F3FF), Color(0xFF00B8D4), Color(0xFF1A237E)],
        ).createShader(Rect.fromCircle(center: orbCenter, radius: irisR)),
    );
    canvas.drawCircle(
      orbCenter,
      s * 0.032,
      Paint()..color = const Color(0xFF12181B),
    );
    canvas.drawCircle(
      orbCenter + Offset(-s * 0.022, -s * 0.022),
      s * 0.016,
      Paint()..color = Colors.white,
    );

    // Glossy glass crescent specular reflection on upper-left of crystal dome
    final specular = Path()
      ..addArc(
        Rect.fromCircle(center: orbCenter, radius: orbR * 0.78),
        -math.pi * 0.84,
        math.pi * 0.34,
      );
    canvas.drawPath(
      specular,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, 1.6 * scale)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(orbCenter, orbR, outline);

    // 4. Ornate Sculpted Golden/Bronze Pedestal Base (y: 0.67..0.90)
    final cradlePath = Path()
      ..moveTo(s * 0.24, s * 0.67)
      ..quadraticBezierTo(s * 0.47, s * 0.745, s * 0.70, s * 0.67)
      ..lineTo(s * 0.65, s * 0.79)
      ..lineTo(s * 0.29, s * 0.79)
      ..close();
    canvas.drawPath(
      cradlePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [goldHi, goldLight, goldMid, goldDark],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.24, s * 0.67, s * 0.70, s * 0.79)),
    );
    canvas.drawPath(cradlePath, outline);

    final basePlinth = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.20, s * 0.79, s * 0.74, s * 0.895),
      Radius.circular(s * 0.035),
    );
    canvas.drawRRect(
      basePlinth,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [goldHi, goldLight, goldMid, goldDark],
          stops: const [0.0, 0.28, 0.68, 1.0],
        ).createShader(basePlinth.outerRect),
    );
    canvas.drawRRect(basePlinth, outline);

    // 5. Crystal Ball+ Radiant Golden Plus (+) Halo Badge at Upper-Right
    if (isEnhancedPlus) {
      final plusCenter = Offset(s * 0.78, s * 0.22);
      final plusHaloR = s * 0.165;
      canvas.drawCircle(
        plusCenter,
        plusHaloR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF59D).withValues(alpha: 0.90),
              const Color(0xFFFFB300).withValues(alpha: 0.42),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: plusCenter, radius: plusHaloR)),
      );

      final armLen = s * 0.125;
      final armHalfW = s * 0.038;
      final plusPath = Path()
        ..moveTo(plusCenter.dx - armHalfW, plusCenter.dy - armLen)
        ..lineTo(plusCenter.dx + armHalfW, plusCenter.dy - armLen)
        ..lineTo(plusCenter.dx + armHalfW, plusCenter.dy - armHalfW)
        ..lineTo(plusCenter.dx + armLen, plusCenter.dy - armHalfW)
        ..lineTo(plusCenter.dx + armLen, plusCenter.dy + armHalfW)
        ..lineTo(plusCenter.dx + armHalfW, plusCenter.dy + armHalfW)
        ..lineTo(plusCenter.dx + armHalfW, plusCenter.dy + armLen)
        ..lineTo(plusCenter.dx - armHalfW, plusCenter.dy + armLen)
        ..lineTo(plusCenter.dx - armHalfW, plusCenter.dy + armHalfW)
        ..lineTo(plusCenter.dx - armLen, plusCenter.dy + armHalfW)
        ..lineTo(plusCenter.dx - armLen, plusCenter.dy - armHalfW)
        ..lineTo(plusCenter.dx - armHalfW, plusCenter.dy - armHalfW)
        ..close();
      canvas.drawPath(
        plusPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [goldHi, goldLight, goldMid],
          ).createShader(Rect.fromCircle(center: plusCenter, radius: armLen)),
      );
      canvas.drawPath(plusPath, outline);

      _drawFourPointSparkle(
        canvas,
        Offset(s * 0.14, s * 0.18),
        s * 0.068,
        const Color(0xFF80F3FF),
        detail,
      );
    } else {
      _drawFourPointSparkle(
        canvas,
        Offset(s * 0.80, s * 0.18),
        s * 0.065,
        const Color(0xFFFFE082),
        detail,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CrystalBallPainter oldDelegate) =>
      oldDelegate.isEnhancedPlus != isEnhancedPlus ||
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

// =============================================================================
// ADDITIONAL OFFERINGS & TAB 6 ICONS (Zero Generic Material Icons in Shop)
// =============================================================================

/// Multi-toned RPG **Overcharged Staff** icon: gilded arcane staff crowned by
/// a glowing sapphire-cyan orb crackling with twin golden lightning arcs.
class OverchargedStaffIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const OverchargedStaffIcon({
    super.key,
    this.size = 32.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _ShopItemVectorIcon(
      size: size,
      painter: _OverchargedStaffPainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _OverchargedStaffPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _OverchargedStaffPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _shopOutlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.15,
    );

    final goldHi =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFF3B0);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFB300);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFF8D5524);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Diagonal Forged Staff Shaft (bottom-left to upper-right)
    final shaft = Path()
      ..moveTo(s * 0.14, s * 0.83)
      ..lineTo(s * 0.57, s * 0.40)
      ..lineTo(s * 0.63, s * 0.46)
      ..lineTo(s * 0.20, s * 0.89)
      ..close();
    canvas.drawPath(
      shaft,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [goldHi, goldMid, goldDark],
        ).createShader(Rect.fromLTRB(s * 0.14, s * 0.40, s * 0.63, s * 0.89)),
    );
    canvas.drawPath(shaft, outline);

    // 2. Sculpted Golden Staff Prongs cradling the Lightning Core
    final headCenter = Offset(s * 0.66, s * 0.34);
    final prongs = Path()
      ..moveTo(s * 0.49, s * 0.34)
      ..quadraticBezierTo(s * 0.52, s * 0.49, s * 0.66, s * 0.51)
      ..quadraticBezierTo(s * 0.81, s * 0.49, s * 0.82, s * 0.33)
      ..lineTo(s * 0.74, s * 0.37)
      ..quadraticBezierTo(s * 0.66, s * 0.44, s * 0.58, s * 0.37)
      ..close();
    canvas.drawPath(
      prongs,
      Paint()
        ..shader = LinearGradient(
          colors: [goldHi, goldMid, goldDark],
        ).createShader(Rect.fromCircle(center: headCenter, radius: s * 0.22)),
    );
    canvas.drawPath(prongs, outline);

    // Glowing Overcharged Cyan-Gold Core Orb
    final coreR = s * 0.135;
    canvas.drawCircle(
      headCenter,
      coreR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFFFFFFFF), Color(0xFF80F3FF), Color(0xFF0288D1)],
        ).createShader(Rect.fromCircle(center: headCenter, radius: coreR)),
    );
    canvas.drawCircle(headCenter, coreR, outline);

    // 3. Jagged Golden Lightning Bolt crackling from the staff head
    final bolt = Path()
      ..moveTo(s * 0.41, s * 0.12)
      ..lineTo(s * 0.29, s * 0.31)
      ..lineTo(s * 0.38, s * 0.31)
      ..lineTo(s * 0.26, s * 0.50)
      ..lineTo(s * 0.47, s * 0.27)
      ..lineTo(s * 0.38, s * 0.27)
      ..close();
    canvas.drawPath(
      bolt,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF8D6), Color(0xFFFFD54F), Color(0xFFFF8F00)],
        ).createShader(Rect.fromLTRB(s * 0.26, s * 0.12, s * 0.47, s * 0.50)),
    );
    canvas.drawPath(bolt, outline);

    // Secondary crisp lightning spark on right
    final sparkBolt = Path()
      ..moveTo(s * 0.84, s * 0.50)
      ..lineTo(s * 0.74, s * 0.65)
      ..lineTo(s * 0.81, s * 0.65)
      ..lineTo(s * 0.72, s * 0.80)
      ..lineTo(s * 0.89, s * 0.62)
      ..lineTo(s * 0.82, s * 0.62)
      ..close();
    canvas.drawPath(sparkBolt, Paint()..color = const Color(0xFF80F3FF));
    canvas.drawPath(sparkBolt, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_OverchargedStaffPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Multi-toned RPG **Markov Recalibrator** icon: forged bronze astrolabe gear
/// dial with a glowing cyan 1-step calibration prism at its heart.
class MarkovRecalibratorIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const MarkovRecalibratorIcon({
    super.key,
    this.size = 32.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _ShopItemVectorIcon(
      size: size,
      painter: _MarkovRecalibratorPainter(
        isOnGoldBackground: isOnGoldBackground,
      ),
    );
  }
}

class _MarkovRecalibratorPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _MarkovRecalibratorPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _shopOutlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.15,
    );

    final goldHi =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFF3B0);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFB300);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFF8D5524);

    canvas.save();
    canvas.translate(ox, oy);

    final c = Offset(s * 0.50, s * 0.50);

    // 1. 8-toothed Forged Bronze Calibration Gear
    const teeth = 8;
    final gearPath = Path();
    for (int i = 0; i < teeth * 2; i++) {
      final a = i * math.pi / teeth - math.pi / 2;
      final r = i.isEven ? s * 0.42 : s * 0.32;
      final pt = c + Offset(math.cos(a), math.sin(a)) * r;
      if (i == 0) {
        gearPath.moveTo(pt.dx, pt.dy);
      } else {
        gearPath.lineTo(pt.dx, pt.dy);
      }
    }
    gearPath.close();
    canvas.drawPath(
      gearPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [goldHi, goldMid, goldDark],
        ).createShader(Rect.fromCircle(center: c, radius: s * 0.42)),
    );
    canvas.drawPath(gearPath, outline);

    // Inner recessed slate ring
    canvas.drawCircle(c, s * 0.24, Paint()..color = const Color(0xFF1D2730));
    canvas.drawCircle(c, s * 0.24, outline);

    // Glowing Cyan Calibration Prism Diamond Core
    final prism = Path()
      ..moveTo(c.dx, c.dy - s * 0.165)
      ..lineTo(c.dx + s * 0.145, c.dy)
      ..lineTo(c.dx, c.dy + s * 0.165)
      ..lineTo(c.dx - s * 0.145, c.dy)
      ..close();
    canvas.drawPath(
      prism,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0F7FA), Color(0xFF00E5FF), Color(0xFF01579B)],
        ).createShader(Rect.fromCircle(center: c, radius: s * 0.17)),
    );
    canvas.drawPath(prism, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkovRecalibratorPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Tab 6 — Offertory (`TitheVaultIcon`): Sacred Golden Offertory Tithe Chest
/// (Gazofilácio) receiving a glowing orb, delegating cleanly to the bespoke
/// [OffertoryVaultIcon] painter in `temple_wing_icons.dart` so both widget
/// types render the exact same high-contrast vector artwork.
class TitheVaultIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const TitheVaultIcon({
    super.key,
    this.size = 28.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return OffertoryVaultIcon(
      size: size,
      isOnGoldBackground: isOnGoldBackground,
    );
  }
}
