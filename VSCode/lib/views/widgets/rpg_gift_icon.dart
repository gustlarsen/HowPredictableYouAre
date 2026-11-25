import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Bespoke, multi-toned RPG Treasure Gift Box icon rendered via
/// [CustomPainter] on a transparent background.
///
/// Harmonizes visually with [RpgBackpackIcon], [RpgResetIcon],
/// [RpgTeleportPortalIcon], and [RpgSettingsIcon]:
/// - Rich crimson-ruby gift box body and slightly overhanging lid (`#FF6E6E` /
///   `#FF5252` / `#D32F2F` / `#B71C1C`) with directional light/shadow shading
///   and crisp dark slate outlines (`#1A2226`).
/// - Forged warm gold/amber vertical & horizontal ribbon bands (`#FFE082` /
///   `#FFB300` / `#C47A38` / `#8D5524`) with metallic specular highlights.
/// - Sculpted twin-loop golden ribbon bow perched atop the lid with a glowing
///   arcane emerald/cyan clasp gem (`#69F0AE` / `#00E5FF`) and subtle golden
///   star sparkles.
class RpgGiftIcon extends StatelessWidget {
  final double size;
  final bool showGlow;

  const RpgGiftIcon({
    super.key,
    this.size = 38.0,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final glowDiameter = size * 0.74;
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
                    color: const Color(0xFFFFB300).withValues(alpha: 0.34),
                    blurRadius: size * 0.30,
                    spreadRadius: size * 0.03,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.24),
                    blurRadius: size * 0.36,
                    spreadRadius: size * 0.02,
                  ),
                ],
              ),
            ),
          RepaintBoundary(
            child: CustomPaint(
              size: Size(size, size),
              painter: const _RpgGiftPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RpgGiftPainter extends CustomPainter {
  const _RpgGiftPainter();

  static const Color _cRubyHighlight = Color(0xFFFF8A80);
  static const Color _cRubyBright = Color(0xFFFF5252);
  static const Color _cRubyMid = Color(0xFFD32F2F);
  static const Color _cRubyDark = Color(0xFFB71C1C);
  static const Color _cRubyDeep = Color(0xFF7F0000);
  static const Color _cGoldHighlight = Color(0xFFFFF3B0);
  static const Color _cGoldBright = Color(0xFFFFE082);
  static const Color _cGoldMid = Color(0xFFFFB300);
  static const Color _cBronzeMid = Color(0xFFC47A38);
  static const Color _cBronzeDark = Color(0xFF8D5524);
  static const Color _cGemHighlight = Color(0xFFE0F7FA);
  static const Color _cGemCyan = Color(0xFF00E5FF);
  static const Color _cGemDeep = Color(0xFF00838F);
  static const Color _cSparkleGold = Color(0xFFFFD54F);
  static const Color _cOutline = Color(0xFF1A2226);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final offsetX = (size.width - s) * 0.5;
    final offsetY = (size.height - s) * 0.5;
    final scale = s / 38.0;

    canvas.save();
    canvas.translate(offsetX, offsetY);

    final outlinePaint = Paint()
      ..color = _cOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 1.35 * scale)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final detailOutlinePaint = Paint()
      ..color = _cOutline.withValues(alpha: 0.84)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.65, 0.85 * scale)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // 1. Subtle ground drop shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.90),
        width: s * 0.68,
        height: s * 0.08,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.34)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.6 * scale),
    );

    // 2. Main Gift Box Lower Body
    final bodyRect = Rect.fromLTRB(s * 0.17, s * 0.43, s * 0.83, s * 0.89);
    final bodyRRect = RRect.fromRectAndCorners(
      bodyRect,
      topLeft: Radius.circular(s * 0.03),
      topRight: Radius.circular(s * 0.03),
      bottomLeft: Radius.circular(s * 0.09),
      bottomRight: Radius.circular(s * 0.09),
    );

    canvas.drawRRect(
      bodyRRect.shift(Offset(0, s * 0.025)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.6 * scale),
    );

    // Split-shaded ruby body (bright top-left -> deep crimson bottom-right)
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cRubyBright, _cRubyMid, _cRubyDark, _cRubyDeep],
          stops: [0.0, 0.38, 0.76, 1.0],
        ).createShader(bodyRect),
    );

    // Subtle right-side shadow panel for 3/4 dimensional depth
    final bodyRightShadow = RRect.fromRectAndCorners(
      Rect.fromLTRB(s * 0.56, s * 0.43, s * 0.83, s * 0.89),
      topRight: Radius.circular(s * 0.03),
      bottomRight: Radius.circular(s * 0.09),
    );
    canvas.drawRRect(
      bodyRightShadow,
      Paint()..color = _cRubyDeep.withValues(alpha: 0.28),
    );

    // Vertical Golden Ribbon Strap on Lower Body
    final bodyRibbonRect = Rect.fromLTRB(s * 0.425, s * 0.43, s * 0.575, s * 0.89);
    canvas.drawRect(
      bodyRibbonRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_cGoldBright, _cGoldMid, _cBronzeMid, _cBronzeDark],
          stops: [0.0, 0.36, 0.72, 1.0],
        ).createShader(bodyRibbonRect),
    );
    canvas.drawLine(
      Offset(bodyRibbonRect.left, bodyRibbonRect.top),
      Offset(bodyRibbonRect.left, bodyRibbonRect.bottom),
      detailOutlinePaint,
    );
    canvas.drawLine(
      Offset(bodyRibbonRect.right, bodyRibbonRect.top),
      Offset(bodyRibbonRect.right, bodyRibbonRect.bottom),
      detailOutlinePaint,
    );

    // Outer box contour
    canvas.drawRRect(bodyRRect, outlinePaint);

    // Shadow cast beneath overhanging lid
    canvas.drawRect(
      Rect.fromLTRB(s * 0.175, s * 0.455, s * 0.825, s * 0.505),
      Paint()..color = Colors.black.withValues(alpha: 0.30),
    );

    // 3. Overhanging Beveled Gift Box Lid
    final lidRect = Rect.fromLTRB(s * 0.125, s * 0.295, s * 0.875, s * 0.465);
    final lidRRect = RRect.fromRectAndRadius(
      lidRect,
      Radius.circular(s * 0.055),
    );

    canvas.drawRRect(
      lidRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cRubyHighlight, _cRubyBright, _cRubyMid, _cRubyDark],
          stops: [0.0, 0.32, 0.70, 1.0],
        ).createShader(lidRect),
    );

    // Top specular lip highlight on lid
    canvas.drawLine(
      Offset(s * 0.175, s * 0.322),
      Offset(s * 0.825, s * 0.322),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.42)
        ..strokeWidth = math.max(0.75, 1.0 * scale)
        ..strokeCap = StrokeCap.round,
    );

    // Vertical Golden Ribbon Strap crossing the Lid
    final lidRibbonRect = Rect.fromLTRB(s * 0.415, s * 0.295, s * 0.585, s * 0.465);
    canvas.drawRect(
      lidRibbonRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cGoldHighlight, _cGoldMid, _cBronzeMid],
          stops: [0.0, 0.55, 1.0],
        ).createShader(lidRibbonRect),
    );
    canvas.drawLine(
      Offset(lidRibbonRect.left, lidRibbonRect.top),
      Offset(lidRibbonRect.left, lidRibbonRect.bottom),
      detailOutlinePaint,
    );
    canvas.drawLine(
      Offset(lidRibbonRect.right, lidRibbonRect.top),
      Offset(lidRibbonRect.right, lidRibbonRect.bottom),
      detailOutlinePaint,
    );

    // Golden metallic corner clasps on lid edge for RPG chest flair
    for (final cx in [s * 0.148, s * 0.852]) {
      final cornerRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, s * 0.38),
          width: s * 0.048,
          height: s * 0.13,
        ),
        Radius.circular(s * 0.015),
      );
      canvas.drawRRect(
        cornerRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_cGoldBright, _cGoldMid, _cBronzeDark],
          ).createShader(cornerRect.outerRect),
      );
      canvas.drawRRect(cornerRect, detailOutlinePaint);
    }

    canvas.drawRRect(lidRRect, outlinePaint);

    // 4. Sculpted Golden Twin-Loop Ribbon Bow perched atop Lid
    _paintRibbonBow(
      canvas: canvas,
      s: s,
      scale: scale,
      outlinePaint: outlinePaint,
      detailOutlinePaint: detailOutlinePaint,
    );

    // 5. Subtle Golden Star Sparkles
    _paintSparkles(canvas, s, scale);

    canvas.restore();
  }

  void _paintRibbonBow({
    required Canvas canvas,
    required double s,
    required double scale,
    required Paint outlinePaint,
    required Paint detailOutlinePaint,
  }) {
    final bowCenter = Offset(s * 0.50, s * 0.255);

    // Left outer golden bow loop
    final leftLoop = Path()
      ..moveTo(bowCenter.dx - s * 0.03, bowCenter.dy + s * 0.01)
      ..cubicTo(
        s * 0.26,
        s * 0.29,
        s * 0.20,
        s * 0.15,
        s * 0.31,
        s * 0.11,
      )
      ..cubicTo(
        s * 0.39,
        s * 0.085,
        s * 0.455,
        s * 0.17,
        bowCenter.dx - s * 0.02,
        bowCenter.dy - s * 0.01,
      )
      ..close();

    // Right outer golden bow loop
    final rightLoop = Path()
      ..moveTo(bowCenter.dx + s * 0.03, bowCenter.dy + s * 0.01)
      ..cubicTo(
        s * 0.74,
        s * 0.29,
        s * 0.80,
        s * 0.15,
        s * 0.69,
        s * 0.11,
      )
      ..cubicTo(
        s * 0.61,
        s * 0.085,
        s * 0.545,
        s * 0.17,
        bowCenter.dx + s * 0.02,
        bowCenter.dy - s * 0.01,
      )
      ..close();

    final bowBounds = Rect.fromLTRB(s * 0.20, s * 0.09, s * 0.80, s * 0.31);
    canvas.drawPath(
      leftLoop,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cGoldHighlight, _cGoldBright, _cGoldMid],
        ).createShader(bowBounds),
    );
    canvas.drawPath(
      rightLoop,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cGoldMid, _cBronzeMid, _cBronzeDark],
        ).createShader(bowBounds),
    );

    // Inner ribbon fold shadows for sculptural depth
    final leftFold = Path()
      ..moveTo(bowCenter.dx - s * 0.04, bowCenter.dy)
      ..quadraticBezierTo(s * 0.34, s * 0.22, s * 0.30, s * 0.17)
      ..quadraticBezierTo(s * 0.37, s * 0.17, bowCenter.dx - s * 0.03, bowCenter.dy - s * 0.01)
      ..close();
    final rightFold = Path()
      ..moveTo(bowCenter.dx + s * 0.04, bowCenter.dy)
      ..quadraticBezierTo(s * 0.66, s * 0.22, s * 0.70, s * 0.17)
      ..quadraticBezierTo(s * 0.63, s * 0.17, bowCenter.dx + s * 0.03, bowCenter.dy - s * 0.01)
      ..close();

    canvas.drawPath(leftFold, Paint()..color = _cBronzeMid.withValues(alpha: 0.78));
    canvas.drawPath(rightFold, Paint()..color = _cBronzeDark.withValues(alpha: 0.82));

    canvas.drawPath(leftLoop, outlinePaint);
    canvas.drawPath(rightLoop, outlinePaint);
    canvas.drawPath(leftFold, detailOutlinePaint);
    canvas.drawPath(rightFold, detailOutlinePaint);

    // Center Bow Knot & Glowing Arcane Cyan Clasp Gem
    final knotRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: bowCenter, width: s * 0.155, height: s * 0.13),
      Radius.circular(s * 0.045),
    );
    canvas.drawRRect(
      knotRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cGoldHighlight, _cGoldMid, _cBronzeDark],
        ).createShader(knotRect.outerRect),
    );
    canvas.drawRRect(knotRect, outlinePaint);

    // Tiny faceted arcane gem nestled in the bow knot
    final gemR = s * 0.045;
    final gemRect = Rect.fromCircle(center: bowCenter, radius: gemR);
    canvas.drawCircle(
      bowCenter,
      gemR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          radius: 0.9,
          colors: [_cGemHighlight, _cGemCyan, _cGemDeep],
        ).createShader(gemRect),
    );
    canvas.drawCircle(bowCenter, gemR, detailOutlinePaint);
    canvas.drawCircle(
      bowCenter + Offset(-gemR * 0.30, -gemR * 0.30),
      math.max(0.7, 0.95 * scale),
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
  }

  void _paintSparkles(Canvas canvas, double s, double scale) {
    final specs = [
      (pos: Offset(s * 0.14, s * 0.16), r: 2.3 * scale),
      (pos: Offset(s * 0.86, s * 0.15), r: 2.0 * scale),
    ];
    for (final spec in specs) {
      final p = spec.pos;
      final r = spec.r;
      final star = Path()
        ..moveTo(p.dx, p.dy - r)
        ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
        ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r)
        ..close();
      canvas.drawPath(
        star,
        Paint()..color = _cSparkleGold.withValues(alpha: 0.95),
      );
    }
  }

  @override
  bool shouldRepaint(_RpgGiftPainter oldDelegate) => false;
}
