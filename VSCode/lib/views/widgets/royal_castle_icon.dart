import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A refined, multi-toned stone-gray medieval RPG castle icon rendered via
/// [CustomPainter] on a transparent background.
///
/// Architectural silhouette features:
/// - Taller central keep with battlements, a pointed dark-slate roof, and a
///   tiny fluttering pennant at the peak.
/// - Two flanking watchtowers with battered plinth bases, crenellations,
///   pointed dark-slate roofs, and narrow vertical arrow-slit windows.
/// - Front crenellated curtain wall with a dark arched gate at the base and
///   clean multi-toned 3D stone shading.
///
/// Set [isOnGoldBackground] to `true` when rendering on a bright solid-gold
/// surface (such as the active `Throne` tab pill) to switch to the
/// high-contrast deep charcoal-slate palette.
class RoyalCastleIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const RoyalCastleIcon({
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
          painter: _RoyalCastlePainter(
            isOnGoldBackground: isOnGoldBackground,
          ),
        ),
      ),
    );
  }
}

class _CastlePalette {
  final Color stoneHighlight;
  final Color stoneLight;
  final Color stoneMid;
  final Color stoneShadow;
  final Color roofLight;
  final Color roofDark;
  final Color outline;
  final Color gateDark;
  final Color pennantFill;
  final Color pennantShadow;

  const _CastlePalette({
    required this.stoneHighlight,
    required this.stoneLight,
    required this.stoneMid,
    required this.stoneShadow,
    required this.roofLight,
    required this.roofDark,
    required this.outline,
    required this.gateDark,
    required this.pennantFill,
    required this.pennantShadow,
  });

  static const standard = _CastlePalette(
    stoneHighlight: Color(0xFFECEFF1),
    stoneLight: Color(0xFFCFD8DC),
    stoneMid: Color(0xFF90A4AE),
    stoneShadow: Color(0xFF607D8B),
    roofLight: Color(0xFF546E7A),
    roofDark: Color(0xFF455A64),
    outline: Color(0xFF263238),
    gateDark: Color(0xFF1A2226),
    pennantFill: Color(0xFFC62828),
    pennantShadow: Color(0xFF8E0000),
  );

  static const onGold = _CastlePalette(
    stoneHighlight: Color(0xFF37474F),
    stoneLight: Color(0xFF313F47),
    stoneMid: Color(0xFF263238),
    stoneShadow: Color(0xFF1E282D),
    roofLight: Color(0xFF37474F),
    roofDark: Color(0xFF263238),
    outline: Color(0xFF1A2226),
    gateDark: Color(0xFF1A2226),
    pennantFill: Color(0xFF7F1D1D),
    pennantShadow: Color(0xFF1A2226),
  );
}

class _RoyalCastlePainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _RoyalCastlePainter({
    required this.isOnGoldBackground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final offsetX = (size.width - side) * 0.5;
    final offsetY = (size.height - side) * 0.5;
    final scale = side / 24.0;
    final p = isOnGoldBackground
        ? _CastlePalette.onGold
        : _CastlePalette.standard;

    canvas.save();
    canvas.translate(offsetX, offsetY);

    final outlinePaint = Paint()
      ..color = p.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.65, 1.0 * scale)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final detailStrokePaint = Paint()
      ..color = p.outline.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.45, 0.65 * scale)
      ..strokeCap = StrokeCap.round;

    // 1. Subtle ground shadow beneath fortress base
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(side * 0.50, side * 0.925),
        width: side * 0.80,
        height: side * 0.08,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: isOnGoldBackground ? 0.16 : 0.30),
    );

    // 2. Central Keep (behind curtain wall & flanking watchtowers)
    _paintCentralKeep(canvas, side, scale, p, outlinePaint, detailStrokePaint);

    // 3. Front Crenellated Curtain Wall & Dark Arched Gate
    _paintCurtainWallAndGate(
      canvas,
      side,
      scale,
      p,
      outlinePaint,
      detailStrokePaint,
    );

    // 4. Left & Right Flanking Watchtowers
    _paintWatchtower(
      canvas,
      side,
      scale,
      centerX: 0.215,
      p: p,
      outlinePaint: outlinePaint,
      detailStrokePaint: detailStrokePaint,
    );
    _paintWatchtower(
      canvas,
      side,
      scale,
      centerX: 0.785,
      p: p,
      outlinePaint: outlinePaint,
      detailStrokePaint: detailStrokePaint,
    );

    canvas.restore();
  }

  void _paintCentralKeep(
    Canvas canvas,
    double s,
    double scale,
    _CastlePalette p,
    Paint outlinePaint,
    Paint detailStrokePaint,
  ) {
    // Keep shaft
    final keepRect = Rect.fromLTRB(s * 0.365, s * 0.325, s * 0.635, s * 0.66);
    canvas.drawRect(
      keepRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            p.stoneHighlight,
            p.stoneLight,
            p.stoneMid,
            p.stoneShadow,
          ],
          stops: const [0.0, 0.30, 0.68, 1.0],
        ).createShader(keepRect),
    );

    // Corbelled shadow band under parapet
    canvas.drawRect(
      Rect.fromLTRB(s * 0.365, s * 0.325, s * 0.635, s * 0.365),
      Paint()..color = p.outline.withValues(alpha: 0.25),
    );
    canvas.drawRect(keepRect, outlinePaint);

    // Horizontal stone masonry seam on keep
    canvas.drawLine(
      Offset(s * 0.37, s * 0.49),
      Offset(s * 0.63, s * 0.49),
      detailStrokePaint,
    );

    // Keep narrow vertical arrow-slit windows
    _drawArrowSlit(
      canvas,
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.425),
        width: s * 0.042,
        height: s * 0.095,
      ),
      p,
    );

    // Keep upper battlement parapet (corbelled gallery + 3 merlons)
    final parapetPath = Path()
      ..moveTo(s * 0.34, s * 0.33)
      ..lineTo(s * 0.34, s * 0.265)
      ..lineTo(s * 0.41, s * 0.265)
      ..lineTo(s * 0.41, s * 0.295)
      ..lineTo(s * 0.465, s * 0.295)
      ..lineTo(s * 0.465, s * 0.265)
      ..lineTo(s * 0.535, s * 0.265)
      ..lineTo(s * 0.535, s * 0.295)
      ..lineTo(s * 0.59, s * 0.295)
      ..lineTo(s * 0.59, s * 0.265)
      ..lineTo(s * 0.66, s * 0.265)
      ..lineTo(s * 0.66, s * 0.33)
      ..close();

    // Pointed dark-slate roof emerging behind the battlements
    final roofBaseY = s * 0.285;
    final roofPeak = Offset(s * 0.50, s * 0.115);
    final roofLeft = Offset(s * 0.335, roofBaseY);
    final roofRight = Offset(s * 0.665, roofBaseY);

    // Flagpole & fluttering pennant at peak
    final poleBottom = roofPeak;
    final poleTop = Offset(s * 0.50, s * 0.045);
    canvas.drawLine(
      poleBottom,
      poleTop,
      Paint()
        ..color = p.outline
        ..strokeWidth = math.max(0.7, 1.05 * scale)
        ..strokeCap = StrokeCap.round,
    );

    final pennantPath = Path()
      ..moveTo(s * 0.50, s * 0.05)
      ..quadraticBezierTo(s * 0.555, s * 0.036, s * 0.625, s * 0.055)
      ..lineTo(s * 0.595, s * 0.075)
      ..lineTo(s * 0.625, s * 0.095)
      ..quadraticBezierTo(s * 0.555, s * 0.078, s * 0.50, s * 0.092)
      ..close();
    canvas.drawPath(pennantPath, Paint()..color = p.pennantFill);
    canvas.drawPath(
      pennantPath,
      Paint()
        ..color = p.pennantShadow
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.45, 0.65 * scale)
        ..strokeJoin = StrokeJoin.round,
    );

    // Roof left facet (lighter slate)
    final roofLeftPath = Path()
      ..moveTo(roofPeak.dx, roofPeak.dy)
      ..lineTo(roofLeft.dx, roofLeft.dy)
      ..lineTo(s * 0.50, roofBaseY)
      ..close();
    canvas.drawPath(roofLeftPath, Paint()..color = p.roofLight);

    // Roof right facet (darker slate)
    final roofRightPath = Path()
      ..moveTo(roofPeak.dx, roofPeak.dy)
      ..lineTo(s * 0.50, roofBaseY)
      ..lineTo(roofRight.dx, roofRight.dy)
      ..close();
    canvas.drawPath(roofRightPath, Paint()..color = p.roofDark);

    // Full roof outline & subtle ridge highlight
    final fullRoofPath = Path()
      ..moveTo(roofPeak.dx, roofPeak.dy)
      ..lineTo(roofLeft.dx, roofLeft.dy)
      ..lineTo(roofRight.dx, roofRight.dy)
      ..close();
    canvas.drawPath(fullRoofPath, outlinePaint);

    // Draw keep battlements over the roof base
    final parapetBounds = Rect.fromLTRB(s * 0.34, s * 0.265, s * 0.66, s * 0.33);
    canvas.drawPath(
      parapetPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [p.stoneHighlight, p.stoneLight, p.stoneMid, p.stoneShadow],
          stops: const [0.0, 0.32, 0.70, 1.0],
        ).createShader(parapetBounds),
    );
    canvas.drawPath(parapetPath, outlinePaint);
  }

  void _paintCurtainWallAndGate(
    Canvas canvas,
    double s,
    double scale,
    _CastlePalette p,
    Paint outlinePaint,
    Paint detailStrokePaint,
  ) {
    // Curtain wall silhouette with crenellated battlements along top
    final wallPath = Path()
      ..moveTo(s * 0.25, s * 0.90)
      ..lineTo(s * 0.25, s * 0.555)
      ..lineTo(s * 0.36, s * 0.555)
      ..lineTo(s * 0.36, s * 0.515)
      ..lineTo(s * 0.425, s * 0.515)
      ..lineTo(s * 0.425, s * 0.555)
      ..lineTo(s * 0.468, s * 0.555)
      ..lineTo(s * 0.468, s * 0.515)
      ..lineTo(s * 0.532, s * 0.515)
      ..lineTo(s * 0.532, s * 0.555)
      ..lineTo(s * 0.575, s * 0.555)
      ..lineTo(s * 0.575, s * 0.515)
      ..lineTo(s * 0.64, s * 0.515)
      ..lineTo(s * 0.64, s * 0.555)
      ..lineTo(s * 0.75, s * 0.555)
      ..lineTo(s * 0.75, s * 0.90)
      ..close();

    final wallBounds = Rect.fromLTRB(s * 0.25, s * 0.515, s * 0.75, s * 0.90);
    canvas.drawPath(
      wallPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.stoneLight, p.stoneMid, p.stoneShadow],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(wallBounds),
    );

    // Subtle shadow strip beneath parapet walkway
    canvas.drawRect(
      Rect.fromLTRB(s * 0.25, s * 0.575, s * 0.75, s * 0.605),
      Paint()..color = p.outline.withValues(alpha: 0.20),
    );

    canvas.drawPath(wallPath, outlinePaint);

    // Stone masonry course lines flanking the gate
    canvas.drawLine(
      Offset(s * 0.29, s * 0.69),
      Offset(s * 0.38, s * 0.69),
      detailStrokePaint,
    );
    canvas.drawLine(
      Offset(s * 0.62, s * 0.69),
      Offset(s * 0.71, s * 0.69),
      detailStrokePaint,
    );

    // Outer stone arch surround around gate
    final archOuterLeft = s * 0.395;
    final archOuterRight = s * 0.605;
    final archOuterTop = s * 0.655;
    final gateBaseY = s * 0.90;
    final archOuterPath = Path()
      ..moveTo(archOuterLeft, gateBaseY)
      ..lineTo(archOuterLeft, s * 0.755)
      ..arcToPoint(
        Offset(archOuterRight, s * 0.755),
        radius: Radius.circular((archOuterRight - archOuterLeft) * 0.5),
        clockwise: true,
      )
      ..lineTo(archOuterRight, gateBaseY)
      ..close();

    canvas.drawPath(
      archOuterPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [p.stoneHighlight, p.stoneMid],
        ).createShader(
          Rect.fromLTRB(archOuterLeft, archOuterTop, archOuterRight, gateBaseY),
        ),
    );
    canvas.drawPath(archOuterPath, outlinePaint);

    // Inner dark arched gate recess
    final gateLeft = s * 0.425;
    final gateRight = s * 0.575;
    final gateArchPath = Path()
      ..moveTo(gateLeft, gateBaseY)
      ..lineTo(gateLeft, s * 0.765)
      ..arcToPoint(
        Offset(gateRight, s * 0.765),
        radius: Radius.circular((gateRight - gateLeft) * 0.5),
        clockwise: true,
      )
      ..lineTo(gateRight, gateBaseY)
      ..close();

    canvas.drawPath(gateArchPath, Paint()..color = p.gateDark);
    canvas.drawPath(gateArchPath, detailStrokePaint);

    // Subtle double-door seam & iron bar inside gate
    final doorLinePaint = Paint()
      ..color = p.stoneMid.withValues(alpha: isOnGoldBackground ? 0.35 : 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.45, 0.65 * scale);
    canvas.drawLine(
      Offset(s * 0.50, s * 0.705),
      Offset(s * 0.50, gateBaseY),
      doorLinePaint,
    );
    canvas.drawLine(
      Offset(gateLeft + s * 0.015, s * 0.81),
      Offset(gateRight - s * 0.015, s * 0.81),
      doorLinePaint,
    );

    // Threshold stone step
    final stepRect = Rect.fromLTRB(s * 0.38, s * 0.895, s * 0.62, s * 0.925);
    canvas.drawRect(stepRect, Paint()..color = p.stoneMid);
    canvas.drawRect(stepRect, outlinePaint);
  }

  void _paintWatchtower(
    Canvas canvas,
    double s,
    double scale, {
    required double centerX,
    required _CastlePalette p,
    required Paint outlinePaint,
    required Paint detailStrokePaint,
  }) {
    final cx = s * centerX;
    final halfShaftW = s * 0.105;
    final halfBaseW = s * 0.122;
    final shaftTopY = s * 0.43;
    final batterTopY = s * 0.77;
    final baseBottomY = s * 0.915;

    // Tower body + flared stone plinth base
    final towerPath = Path()
      ..moveTo(cx - halfShaftW, shaftTopY)
      ..lineTo(cx + halfShaftW, shaftTopY)
      ..lineTo(cx + halfShaftW, batterTopY)
      ..lineTo(cx + halfBaseW, s * 0.82)
      ..lineTo(cx + halfBaseW, baseBottomY)
      ..lineTo(cx - halfBaseW, baseBottomY)
      ..lineTo(cx - halfBaseW, s * 0.82)
      ..lineTo(cx - halfShaftW, batterTopY)
      ..close();

    final towerBounds = Rect.fromLTRB(
      cx - halfBaseW,
      shaftTopY,
      cx + halfBaseW,
      baseBottomY,
    );

    canvas.drawPath(
      towerPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            p.stoneHighlight,
            p.stoneLight,
            p.stoneMid,
            p.stoneShadow,
          ],
          stops: const [0.0, 0.32, 0.68, 1.0],
        ).createShader(towerBounds),
    );

    // Corbel shadow beneath battlements + subtle plinth bevel shadow
    canvas.drawRect(
      Rect.fromLTRB(
        cx - halfShaftW,
        shaftTopY,
        cx + halfShaftW,
        shaftTopY + s * 0.032,
      ),
      Paint()..color = p.outline.withValues(alpha: 0.24),
    );
    canvas.drawPath(towerPath, outlinePaint);

    // Horizontal plinth ridge & masonry line
    canvas.drawLine(
      Offset(cx - halfBaseW + s * 0.006, s * 0.82),
      Offset(cx + halfBaseW - s * 0.006, s * 0.82),
      detailStrokePaint,
    );
    canvas.drawLine(
      Offset(cx - halfShaftW + s * 0.006, s * 0.615),
      Offset(cx + halfShaftW - s * 0.006, s * 0.615),
      detailStrokePaint,
    );

    // Two narrow vertical arrow-slit windows (upper & lower)
    _drawArrowSlit(
      canvas,
      Rect.fromCenter(
        center: Offset(cx, s * 0.535),
        width: s * 0.040,
        height: s * 0.088,
      ),
      p,
    );
    _drawArrowSlit(
      canvas,
      Rect.fromCenter(
        center: Offset(cx, s * 0.695),
        width: s * 0.034,
        height: s * 0.075,
      ),
      p,
    );

    // Pointed dark-slate watchtower roof behind crenellations
    final roofBaseY = s * 0.375;
    final roofPeak = Offset(cx, s * 0.205);
    final roofHalfW = s * 0.115;

    // Small roof peak finial
    canvas.drawLine(
      roofPeak,
      Offset(cx, s * 0.175),
      Paint()
        ..color = p.outline
        ..strokeWidth = math.max(0.65, 0.95 * scale)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(cx, s * 0.175),
      math.max(0.6, 0.85 * scale),
      Paint()..color = p.stoneMid,
    );

    final roofLeftPath = Path()
      ..moveTo(roofPeak.dx, roofPeak.dy)
      ..lineTo(cx - roofHalfW, roofBaseY)
      ..lineTo(cx, roofBaseY)
      ..close();
    canvas.drawPath(roofLeftPath, Paint()..color = p.roofLight);

    final roofRightPath = Path()
      ..moveTo(roofPeak.dx, roofPeak.dy)
      ..lineTo(cx, roofBaseY)
      ..lineTo(cx + roofHalfW, roofBaseY)
      ..close();
    canvas.drawPath(roofRightPath, Paint()..color = p.roofDark);

    final fullRoofPath = Path()
      ..moveTo(roofPeak.dx, roofPeak.dy)
      ..lineTo(cx - roofHalfW, roofBaseY)
      ..lineTo(cx + roofHalfW, roofBaseY)
      ..close();
    canvas.drawPath(fullRoofPath, outlinePaint);

    // Crenellated tower crown (parapet + 3 merlons) over roof base
    final crownHalfW = s * 0.125;
    final crownBotY = s * 0.435;
    final crownMidY = s * 0.392;
    final merlonTopY = s * 0.352;
    final mOuter = s * 0.062;
    final mInner = s * 0.028;

    final crownPath = Path()
      ..moveTo(cx - crownHalfW, crownBotY)
      ..lineTo(cx - crownHalfW, merlonTopY)
      ..lineTo(cx - mOuter, merlonTopY)
      ..lineTo(cx - mOuter, crownMidY)
      ..lineTo(cx - mInner, crownMidY)
      ..lineTo(cx - mInner, merlonTopY)
      ..lineTo(cx + mInner, merlonTopY)
      ..lineTo(cx + mInner, crownMidY)
      ..lineTo(cx + mOuter, crownMidY)
      ..lineTo(cx + mOuter, merlonTopY)
      ..lineTo(cx + crownHalfW, merlonTopY)
      ..lineTo(cx + crownHalfW, crownBotY)
      ..close();

    final crownBounds = Rect.fromLTRB(
      cx - crownHalfW,
      merlonTopY,
      cx + crownHalfW,
      crownBotY,
    );
    canvas.drawPath(
      crownPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [p.stoneHighlight, p.stoneLight, p.stoneMid, p.stoneShadow],
          stops: const [0.0, 0.32, 0.70, 1.0],
        ).createShader(crownBounds),
    );
    canvas.drawPath(crownPath, outlinePaint);
  }

  void _drawArrowSlit(Canvas canvas, Rect rect, _CastlePalette p) {
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.width * 0.45),
    );
    canvas.drawRRect(rrect, Paint()..color = p.gateDark);
  }

  @override
  bool shouldRepaint(_RoyalCastlePainter oldDelegate) {
    return oldDelegate.isOnGoldBackground != isOnGoldBackground;
  }
}
