import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Bespoke, multi-toned RPG Arcane Rewind / Reset Emblem rendered via
/// [CustomPainter] on a transparent background.
///
/// Harmonizes visually with [RpgBackpackIcon], [RpgTeleportPortalIcon], and
/// [MetalWizardLairIcon]:
/// - Forged warm gold/bronze (`#FFE082` / `#FFB300` / `#C47A38` / `#8D5524`)
///   counter-clockwise rewind band with beveled light/shadow faces and crisp
///   dark slate outlines (`#1A2226`).
/// - Inlaid luminous crimson-ruby energy channel (`#FF8A80` / `#FF5252` /
///   `#D32F2F` / `#B71C1C`) with specular edge highlights and forged rivets.
/// - Bold split-shaded arrowhead pointing counter-clockwise to evoke a
///   magical time-rewind relic.
/// - Compact faceted crimson-gold ember crystal core and subtle golden
///   sparkles accenting the outer rim.
class RpgResetIcon extends StatelessWidget {
  final double size;
  final bool showGlow;

  const RpgResetIcon({
    super.key,
    this.size = 38.0,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final glowDiameter = size * 0.72;
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
                    color: const Color(0xFFFF5252).withValues(alpha: 0.34),
                    blurRadius: size * 0.28,
                    spreadRadius: size * 0.02,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.24),
                    blurRadius: size * 0.36,
                    spreadRadius: size * 0.03,
                  ),
                ],
              ),
            ),
          RepaintBoundary(
            child: CustomPaint(
              size: Size(size, size),
              painter: const _RpgResetPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RpgResetPainter extends CustomPainter {
  const _RpgResetPainter();

  static const Color _cGoldHighlight = Color(0xFFFFE082);
  static const Color _cGoldMid = Color(0xFFFFB300);
  static const Color _cBronzeMid = Color(0xFFC47A38);
  static const Color _cBronzeDark = Color(0xFF8D5524);
  static const Color _cRubyHighlight = Color(0xFFFF8A80);
  static const Color _cRubyBright = Color(0xFFFF5252);
  static const Color _cRubyMid = Color(0xFFD32F2F);
  static const Color _cRubyDark = Color(0xFFB71C1C);
  static const Color _cRubyDeep = Color(0xFF7F0000);
  static const Color _cEmberCore = Color(0xFFFFF59D);
  static const Color _cEmberAmber = Color(0xFFFFAB40);
  static const Color _cSparkleGold = Color(0xFFFFD54F);
  static const Color _cOutline = Color(0xFF1A2226);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final offsetX = (size.width - s) * 0.5;
    final offsetY = (size.height - s) * 0.5;
    final scale = s / 38.0;
    final center = Offset(s * 0.51, s * 0.51);

    canvas.save();
    canvas.translate(offsetX, offsetY);

    final outlinePaint = Paint()
      ..color = _cOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 1.35 * scale)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final detailOutlinePaint = Paint()
      ..color = _cOutline.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.65, 0.85 * scale)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Arc angles (Flutter canvas: 0 = right, +pi/2 = bottom, -pi/2 = top)
    // Counter-clockwise rewind sweep from lower-left tail (154 deg) through
    // bottom, right, and top to upper-left arrowhead base (-130 deg).
    const double tailAngle = 154.0 * math.pi / 180.0;
    const double headBaseAngle = -130.0 * math.pi / 180.0;
    const double sweepAngle = headBaseAngle - tailAngle; // -284 deg

    final rOuter = s * 0.425;
    final rInner = s * 0.265;
    final rMid = (rOuter + rInner) * 0.5;

    final bandPath = _buildArcBandPath(
      center: center,
      rOuter: rOuter,
      rInner: rInner,
      startAngle: tailAngle,
      sweepAngle: sweepAngle,
    );

    final arrowGeom = _computeArrowGeometry(
      center: center,
      rOuter: rOuter,
      rInner: rInner,
      rMid: rMid,
      headBaseAngle: headBaseAngle,
      s: s,
    );

    // 1. Subtle drop shadow beneath emblem for depth on both light & dark HUDs
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.34)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.8 * scale);
    canvas.drawPath(bandPath.shift(Offset(0, s * 0.032)), shadowPaint);
    canvas.drawPath(
      arrowGeom.fullPath.shift(Offset(0, s * 0.032)),
      shadowPaint,
    );

    // 2. Forged Warm Gold/Bronze Outer Rewind Band
    final bandBounds = Rect.fromCircle(center: center, radius: rOuter);
    canvas.drawPath(
      bandPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cGoldHighlight, _cGoldMid, _cBronzeMid, _cBronzeDark],
          stops: [0.0, 0.34, 0.72, 1.0],
        ).createShader(bandBounds),
    );
    canvas.drawPath(bandPath, outlinePaint);

    // 3. Recessed Luminous Crimson-Ruby Channel inlaid inside the bronze band
    const double rubyTailAngle = 148.0 * math.pi / 180.0;
    const double rubyHeadAngle = -128.0 * math.pi / 180.0;
    const double rubySweep = rubyHeadAngle - rubyTailAngle;
    final rRubyOuter = s * 0.392;
    final rRubyInner = s * 0.298;

    final rubyOuterHalf = _buildArcBandPath(
      center: center,
      rOuter: rRubyOuter,
      rInner: rMid,
      startAngle: rubyTailAngle,
      sweepAngle: rubySweep,
    );
    final rubyInnerHalf = _buildArcBandPath(
      center: center,
      rOuter: rMid,
      rInner: rRubyInner,
      startAngle: rubyTailAngle,
      sweepAngle: rubySweep,
    );
    final rubyFull = _buildArcBandPath(
      center: center,
      rOuter: rRubyOuter,
      rInner: rRubyInner,
      startAngle: rubyTailAngle,
      sweepAngle: rubySweep,
    );

    canvas.drawPath(
      rubyOuterHalf,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cRubyHighlight, _cRubyBright, _cRubyMid],
          stops: [0.0, 0.45, 1.0],
        ).createShader(bandBounds),
    );
    canvas.drawPath(
      rubyInnerHalf,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cRubyMid, _cRubyDark, _cRubyDeep],
          stops: [0.0, 0.55, 1.0],
        ).createShader(bandBounds),
    );
    canvas.drawPath(rubyFull, detailOutlinePaint);

    // Specular highlight curving along top-lit ruby ridge
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: (rRubyOuter + rMid) * 0.52),
      -122.0 * math.pi / 180.0,
      98.0 * math.pi / 180.0,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.85, 1.15 * scale)
        ..strokeCap = StrokeCap.round,
    );

    // 4. Forged Gold Clasps / Rivets riveted across cardinal points of the arc
    for (final claspDeg in [-90.0, 0.0, 90.0]) {
      final a = claspDeg * math.pi / 180.0;
      final pClasp = center + Offset(math.cos(a), math.sin(a)) * rMid;
      canvas.save();
      canvas.translate(pClasp.dx, pClasp.dy);
      canvas.rotate(a);
      final claspRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: (rOuter - rInner) * 1.08,
          height: s * 0.064,
        ),
        Radius.circular(s * 0.018),
      );
      canvas.drawRRect(
        claspRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_cGoldHighlight, _cGoldMid, _cBronzeDark],
          ).createShader(claspRect.outerRect),
      );
      canvas.drawRRect(claspRect, detailOutlinePaint);
      canvas.drawCircle(
        Offset.zero,
        s * 0.014,
        Paint()..color = _cOutline,
      );
      canvas.restore();
    }

    // 5. Bold Sculpted Arrowhead (Upper-Left, pointing counter-clockwise)
    _paintSculptedArrowhead(
      canvas: canvas,
      geom: arrowGeom,
      scale: scale,
      outlinePaint: outlinePaint,
      detailOutlinePaint: detailOutlinePaint,
    );

    // 6. Central Glowing Arcane Ember / Time-Crystal Core
    _paintEmberCrystal(
      canvas: canvas,
      center: center,
      s: s,
      scale: scale,
      outlinePaint: detailOutlinePaint,
    );

    // 7. Subtle Golden-Amber Star Sparkles near rim
    _paintSparkles(canvas, center, s, scale);

    canvas.restore();
  }

  Path _buildArcBandPath({
    required Offset center,
    required double rOuter,
    required double rInner,
    required double startAngle,
    required double sweepAngle,
  }) {
    final outerRect = Rect.fromCircle(center: center, radius: rOuter);
    final innerRect = Rect.fromCircle(center: center, radius: rInner);
    final endAngle = startAngle + sweepAngle;

    final startOuter =
        center + Offset(math.cos(startAngle), math.sin(startAngle)) * rOuter;
    final endInner =
        center + Offset(math.cos(endAngle), math.sin(endAngle)) * rInner;

    return Path()
      ..moveTo(startOuter.dx, startOuter.dy)
      ..arcTo(outerRect, startAngle, sweepAngle, false)
      ..lineTo(endInner.dx, endInner.dy)
      ..arcTo(innerRect, endAngle, -sweepAngle, false)
      ..close();
  }

  _ArrowGeometry _computeArrowGeometry({
    required Offset center,
    required double rOuter,
    required double rInner,
    required double rMid,
    required double headBaseAngle,
    required double s,
  }) {
    const double tipAngle = -175.0 * math.pi / 180.0;
    final double wingAngle = headBaseAngle + 6.0 * math.pi / 180.0;
    final double notchAngle = headBaseAngle - 4.0 * math.pi / 180.0;

    final tip = center +
        Offset(math.cos(tipAngle), math.sin(tipAngle)) * (rMid + s * 0.014);
    final outerWing = center +
        Offset(math.cos(wingAngle), math.sin(wingAngle)) *
            (rOuter + s * 0.088);
    final innerWing = center +
        Offset(math.cos(wingAngle + 0.08), math.sin(wingAngle + 0.08)) *
            (rInner - s * 0.082);
    final baseMid = center +
        Offset(math.cos(notchAngle), math.sin(notchAngle)) * rMid;

    final fullPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(outerWing.dx, outerWing.dy)
      ..lineTo(baseMid.dx, baseMid.dy)
      ..lineTo(innerWing.dx, innerWing.dy)
      ..close();

    final upperFacet = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(outerWing.dx, outerWing.dy)
      ..lineTo(baseMid.dx, baseMid.dy)
      ..close();

    final lowerFacet = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(baseMid.dx, baseMid.dy)
      ..lineTo(innerWing.dx, innerWing.dy)
      ..close();

    // Inset ruby facets inside gold bevel border
    Offset lerpPoint(Offset a, Offset b, double t) => Offset.lerp(a, b, t)!;
    final rubyTip = lerpPoint(tip, baseMid, 0.20);
    final rubyOuter = lerpPoint(outerWing, baseMid, 0.28);
    final rubyInner = lerpPoint(innerWing, baseMid, 0.28);
    final rubyBase = lerpPoint(baseMid, tip, 0.14);

    final rubyUpperFacet = Path()
      ..moveTo(rubyTip.dx, rubyTip.dy)
      ..lineTo(rubyOuter.dx, rubyOuter.dy)
      ..lineTo(rubyBase.dx, rubyBase.dy)
      ..close();

    final rubyLowerFacet = Path()
      ..moveTo(rubyTip.dx, rubyTip.dy)
      ..lineTo(rubyBase.dx, rubyBase.dy)
      ..lineTo(rubyInner.dx, rubyInner.dy)
      ..close();

    return _ArrowGeometry(
      tip: tip,
      baseMid: baseMid,
      fullPath: fullPath,
      upperFacet: upperFacet,
      lowerFacet: lowerFacet,
      rubyUpperFacet: rubyUpperFacet,
      rubyLowerFacet: rubyLowerFacet,
      bounds: fullPath.getBounds(),
    );
  }

  void _paintSculptedArrowhead({
    required Canvas canvas,
    required _ArrowGeometry geom,
    required double scale,
    required Paint outlinePaint,
    required Paint detailOutlinePaint,
  }) {
    // Split gold/bronze metallic arrowhead bevels
    canvas.drawPath(
      geom.upperFacet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cGoldHighlight, _cGoldMid],
        ).createShader(geom.bounds),
    );
    canvas.drawPath(
      geom.lowerFacet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cBronzeMid, _cBronzeDark],
        ).createShader(geom.bounds),
    );

    // Split crimson-ruby inlaid facets
    canvas.drawPath(
      geom.rubyUpperFacet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cRubyHighlight, _cRubyBright],
        ).createShader(geom.bounds),
    );
    canvas.drawPath(
      geom.rubyLowerFacet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cRubyMid, _cRubyDeep],
        ).createShader(geom.bounds),
    );

    // Crisp outer silhouette & central ridge spine
    canvas.drawPath(geom.fullPath, outlinePaint);
    canvas.drawLine(
      geom.tip,
      geom.baseMid,
      Paint()
        ..color = _cGoldHighlight.withValues(alpha: 0.78)
        ..strokeWidth = math.max(0.75, 0.95 * scale)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(geom.rubyUpperFacet, detailOutlinePaint);
    canvas.drawPath(geom.rubyLowerFacet, detailOutlinePaint);
  }

  void _paintEmberCrystal({
    required Canvas canvas,
    required Offset center,
    required double s,
    required double scale,
    required Paint outlinePaint,
  }) {
    final rx = s * 0.125;
    final ry = s * 0.155;

    // Soft ember glow inside the rewind ring
    canvas.drawCircle(
      center,
      s * 0.185,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _cEmberAmber.withValues(alpha: 0.55),
            _cRubyBright.withValues(alpha: 0.25),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: s * 0.185)),
    );

    final top = center + Offset(0, -ry);
    final right = center + Offset(rx, 0);
    final bottom = center + Offset(0, ry);
    final left = center + Offset(-rx, 0);
    final diamondBounds = Rect.fromCenter(
      center: center,
      width: rx * 2,
      height: ry * 2,
    );

    // 4 faceted ember-ruby crystal faces with directional light/shadow split
    final topLeftFacet = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(top.dx, top.dy)
      ..close();
    final topRightFacet = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    final bottomLeftFacet = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    final bottomRightFacet = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..close();

    canvas.drawPath(
      topLeftFacet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cEmberCore, _cGoldMid],
        ).createShader(diamondBounds),
    );
    canvas.drawPath(
      topRightFacet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [_cEmberAmber, _cRubyBright],
        ).createShader(diamondBounds),
    );
    canvas.drawPath(
      bottomLeftFacet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          colors: [_cRubyBright, _cRubyMid],
        ).createShader(diamondBounds),
    );
    canvas.drawPath(
      bottomRightFacet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cRubyDark, _cRubyDeep],
        ).createShader(diamondBounds),
    );

    final fullDiamond = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    canvas.drawPath(fullDiamond, outlinePaint);

    // Subtle specular glint on the top-left crystal facet
    canvas.drawCircle(
      center + Offset(-rx * 0.28, -ry * 0.30),
      math.max(0.9, 1.25 * scale),
      Paint()..color = Colors.white.withValues(alpha: 0.90),
    );
  }

  void _paintSparkles(Canvas canvas, Offset center, double s, double scale) {
    final specs = [
      (pos: Offset(s * 0.87, s * 0.16), r: 2.3 * scale),
      (pos: Offset(s * 0.12, s * 0.80), r: 1.8 * scale),
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
  bool shouldRepaint(_RpgResetPainter oldDelegate) => false;
}

class _ArrowGeometry {
  final Offset tip;
  final Offset baseMid;
  final Path fullPath;
  final Path upperFacet;
  final Path lowerFacet;
  final Path rubyUpperFacet;
  final Path rubyLowerFacet;
  final Rect bounds;

  const _ArrowGeometry({
    required this.tip,
    required this.baseMid,
    required this.fullPath,
    required this.upperFacet,
    required this.lowerFacet,
    required this.rubyUpperFacet,
    required this.rubyLowerFacet,
    required this.bounds,
  });
}
