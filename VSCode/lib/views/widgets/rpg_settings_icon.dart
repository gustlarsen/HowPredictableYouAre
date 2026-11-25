import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Bespoke, multi-toned RPG Forged Arcane Gear icon rendered via
/// [CustomPainter] on a transparent background.
///
/// Echoes the steampunk/arcane automaton craftsmanship of [MetalWizardLairIcon]
/// and harmonizes with [RpgBackpackIcon] and [RpgTeleportPortalIcon]:
/// - 8 sculpted beveled gear teeth in polished steel and shaded iron-slate
///   (`#ECEFF1` / `#CFD8DC` / `#78909C` / `#455A64`) with crisp dark slate
///   outlines (`#1A2226`).
/// - Dimensional warm brass/gold riveted collar ring (`#FFE082` / `#FFB300` /
///   `#C47A38` / `#8D5524`) with 4 recessed metallic rivets.
/// - Deep dark-slate inner mechanical chamber with 4 machined steel prongs.
/// - Luminous faceted cyan/sapphire arcane crystal core (`#00E5FF` /
///   `#0091EA` / `#0D47A1`) glowing from the center hub.
class RpgSettingsIcon extends StatelessWidget {
  final double size;
  final bool showGlow;

  const RpgSettingsIcon({
    super.key,
    this.size = 38.0,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final glowDiameter = size * 0.68;
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
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.30),
                    blurRadius: size * 0.28,
                    spreadRadius: size * 0.02,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.18),
                    blurRadius: size * 0.34,
                    spreadRadius: size * 0.02,
                  ),
                ],
              ),
            ),
          RepaintBoundary(
            child: CustomPaint(
              size: Size(size, size),
              painter: const _RpgSettingsPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RpgSettingsPainter extends CustomPainter {
  const _RpgSettingsPainter();

  static const Color _cSteelHighlight = Color(0xFFECEFF1);
  static const Color _cSteelLight = Color(0xFFCFD8DC);
  static const Color _cIronMid = Color(0xFF78909C);
  static const Color _cIronDark = Color(0xFF455A64);
  static const Color _cSlateDeep = Color(0xFF263238);
  static const Color _cSocketDark = Color(0xFF141A1D);
  static const Color _cBrassHighlight = Color(0xFFFFE082);
  static const Color _cBrassGold = Color(0xFFFFB300);
  static const Color _cBronzeMid = Color(0xFFC47A38);
  static const Color _cBronzeDark = Color(0xFF8D5524);
  static const Color _cCyanIce = Color(0xFFE0F7FA);
  static const Color _cCyanBright = Color(0xFF00E5FF);
  static const Color _cSapphireMid = Color(0xFF0091EA);
  static const Color _cSapphireDeep = Color(0xFF0D47A1);
  static const Color _cOutline = Color(0xFF1A2226);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final offsetX = (size.width - s) * 0.5;
    final offsetY = (size.height - s) * 0.5;
    final scale = s / 38.0;
    final center = Offset(s * 0.5, s * 0.5);

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

    const int teethCount = 8;
    const double startAngle = -math.pi / 2;
    final double outerR = s * 0.462;
    final double rootR = s * 0.348;

    final gearPath = _buildGearPath(
      center: center,
      outerR: outerR,
      rootR: rootR,
      teethCount: teethCount,
      startAngle: startAngle,
    );

    // 1. Soft drop shadow beneath gear silhouette
    canvas.drawPath(
      gearPath.shift(Offset(0, s * 0.032)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.34)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.8 * scale),
    );

    // 2. Sculpted Steel & Iron-Slate Gear Body with Split Directional Shading
    final gearRect = Rect.fromCircle(center: center, radius: outerR);
    canvas.drawPath(
      gearPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cSteelHighlight, _cSteelLight, _cIronMid, _cIronDark],
          stops: [0.0, 0.35, 0.68, 1.0],
        ).createShader(gearRect),
    );

    // Per-tooth chamfered light & shadow bevel accents
    _paintToothBevels(
      canvas: canvas,
      center: center,
      outerR: outerR,
      rootR: rootR,
      teethCount: teethCount,
      startAngle: startAngle,
      scale: scale,
    );

    // Crisp outer steel gear contour
    canvas.drawPath(gearPath, outlinePaint);

    // 3. Dimensional Warm Brass / Gold Collar Ring
    final brassOuterR = s * 0.332;
    final brassInnerR = s * 0.228;
    final brassMidR = (brassOuterR + brassInnerR) * 0.5;
    final brassRect = Rect.fromCircle(center: center, radius: brassOuterR);

    canvas.drawCircle(
      center,
      brassMidR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cBrassHighlight, _cBrassGold, _cBronzeMid, _cBronzeDark],
          stops: [0.0, 0.34, 0.70, 1.0],
        ).createShader(brassRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = brassOuterR - brassInnerR,
    );

    // Top-left specular arc on the brass collar
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: brassOuterR - s * 0.018),
      -155.0 * math.pi / 180.0,
      105.0 * math.pi / 180.0,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, 1.05 * scale)
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(center, brassOuterR, detailOutlinePaint);

    // 4 machined diagonal rivets around the brass collar
    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) + math.pi / 4;
      final rivetCenter =
          center + Offset(math.cos(angle), math.sin(angle)) * brassMidR;
      final rivetR = s * 0.025;
      canvas.drawCircle(
        rivetCenter,
        rivetR,
        Paint()..color = _cOutline,
      );
      canvas.drawCircle(
        rivetCenter,
        rivetR * 0.68,
        Paint()..color = _cSteelLight,
      );
      canvas.drawCircle(
        rivetCenter + Offset(-rivetR * 0.22, -rivetR * 0.22),
        rivetR * 0.28,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    // 4. Recessed Dark-Slate Inner Metallic Cavity
    final cavityRect = Rect.fromCircle(center: center, radius: brassInnerR);
    canvas.drawCircle(
      center,
      brassInnerR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cSocketDark, _cSlateDeep, _cIronDark],
          stops: [0.0, 0.55, 1.0],
        ).createShader(cavityRect),
    );
    canvas.drawCircle(center, brassInnerR, outlinePaint);

    // 4 cardinal machined steel/brass clamp prongs holding the arcane core
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final prongRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(s * 0.135, -s * 0.028, brassInnerR - s * 0.008, s * 0.028),
        Radius.circular(s * 0.012),
      );
      canvas.drawRRect(
        prongRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_cSteelHighlight, _cIronMid, _cIronDark],
          ).createShader(prongRect.outerRect),
      );
      canvas.drawRRect(prongRect, detailOutlinePaint);
      canvas.restore();
    }

    // 5. Glowing Cyan / Sapphire Arcane Core in Center Hub
    final coreR = s * 0.142;
    final coreRect = Rect.fromCircle(center: center, radius: coreR);

    // Radial arcane bloom inside recessed cavity
    canvas.drawCircle(
      center,
      brassInnerR * 0.90,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _cCyanBright.withValues(alpha: 0.55),
            _cSapphireMid.withValues(alpha: 0.22),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(cavityRect),
    );

    // Core crystal fill
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.28, -0.30),
          radius: 0.92,
          colors: [_cCyanIce, _cCyanBright, _cSapphireMid, _cSapphireDeep],
          stops: [0.0, 0.32, 0.72, 1.0],
        ).createShader(coreRect),
    );

    // Cut diamond facet lines inside the sapphire core
    final innerFacetR = coreR * 0.62;
    final innerDiamond = Path()
      ..moveTo(center.dx, center.dy - innerFacetR)
      ..lineTo(center.dx + innerFacetR, center.dy)
      ..lineTo(center.dx, center.dy + innerFacetR)
      ..lineTo(center.dx - innerFacetR, center.dy)
      ..close();
    canvas.drawPath(
      innerDiamond,
      Paint()
        ..color = _cCyanIce.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.55, 0.75 * scale),
    );

    // Crisp metallic core bezel & specular crystal highlight
    canvas.drawCircle(center, coreR, outlinePaint);
    canvas.drawCircle(
      center,
      coreR - 0.75 * scale,
      Paint()
        ..color = _cCyanBright.withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.55, 0.75 * scale),
    );
    canvas.drawCircle(
      center + Offset(-coreR * 0.34, -coreR * 0.34),
      math.max(1.0, 1.45 * scale),
      Paint()..color = Colors.white.withValues(alpha: 0.94),
    );

    canvas.restore();
  }

  Path _buildGearPath({
    required Offset center,
    required double outerR,
    required double rootR,
    required int teethCount,
    required double startAngle,
  }) {
    final path = Path();
    final step = (2 * math.pi) / teethCount;

    for (int i = 0; i < teethCount; i++) {
      final base = startAngle + i * step;
      // Symmetric beveled trapezoidal tooth centered on `base`
      final aRootLeft = base - step * 0.31;
      final aTipLeft = base - step * 0.175;
      final aTipRight = base + step * 0.175;
      final aRootRight = base + step * 0.31;

      final p0 = center + Offset(math.cos(aRootLeft), math.sin(aRootLeft)) * rootR;
      final p1 = center + Offset(math.cos(aTipLeft), math.sin(aTipLeft)) * outerR;
      final p2 = center + Offset(math.cos(aTipRight), math.sin(aTipRight)) * outerR;
      final p3 = center + Offset(math.cos(aRootRight), math.sin(aRootRight)) * rootR;

      if (i == 0) {
        path.moveTo(p0.dx, p0.dy);
      } else {
        path.lineTo(p0.dx, p0.dy);
      }
      path
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy);
    }
    path.close();
    return path;
  }

  void _paintToothBevels({
    required Canvas canvas,
    required Offset center,
    required double outerR,
    required double rootR,
    required int teethCount,
    required double startAngle,
    required double scale,
  }) {
    final step = (2 * math.pi) / teethCount;
    final bevelInnerR = rootR + (outerR - rootR) * 0.22;
    final bevelOuterR = outerR - (outerR - rootR) * 0.14;

    for (int i = 0; i < teethCount; i++) {
      final base = startAngle + i * step;
      // Directional light factor from top-left (-135 deg)
      final lightDot = math.cos(base - (-3 * math.pi / 4));

      final aLeft = base - step * 0.16;
      final aRight = base + step * 0.16;
      final pTipL = center + Offset(math.cos(aLeft), math.sin(aLeft)) * bevelOuterR;
      final pTipR = center + Offset(math.cos(aRight), math.sin(aRight)) * bevelOuterR;
      final pInL = center + Offset(math.cos(aLeft), math.sin(aLeft)) * bevelInnerR;
      final pInR = center + Offset(math.cos(aRight), math.sin(aRight)) * bevelInnerR;

      final bevelColor = lightDot >= 0
          ? _cSteelHighlight.withValues(alpha: 0.38 + 0.30 * lightDot)
          : _cSlateDeep.withValues(alpha: 0.22 + 0.26 * (-lightDot));

      final facet = Path()
        ..moveTo(pInL.dx, pInL.dy)
        ..lineTo(pTipL.dx, pTipL.dy)
        ..lineTo(pTipR.dx, pTipR.dy)
        ..lineTo(pInR.dx, pInR.dy)
        ..close();

      canvas.drawPath(facet, Paint()..color = bevelColor);

      // Crisp metallic tooth tip edge highlight on top-left teeth
      if (lightDot > 0.05) {
        canvas.drawLine(
          pTipL,
          pTipR,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55 * lightDot)
            ..strokeWidth = math.max(0.7, 0.95 * scale)
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RpgSettingsPainter oldDelegate) => false;
}
