import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A bespoke, multi-toned RPG Metallic Automaton Head icon for the Metal
/// Wizard's Lair, rendered via [CustomPainter] on a transparent background.
///
/// Architectural & character silhouette features:
/// - Double mechanical cog segments peeking out from behind the left and right
///   sides of the head.
/// - Faceted, heavily armored steel & iron automaton head with split 3D
///   shading (`#ECEFF1` / `#CFD8DC` light steel on left faces; `#78909C` /
///   `#455A64` shadow iron-slate on right faces).
/// - Intense blazing flame eyes (`#FF3D00` / `#FF9100`) burning outward from
///   deep dark eye sockets.
/// - Prominent vertical riveted bronze/brass forehead & nose strip
///   (`#C47A38` / `#8D5524`), mechanical side ear housings, and a heavy
///   riveted jaw guard with vertical vent slits.
/// - Crisp dark charcoal-slate outlines (`#1A2226`) for sharp legibility at
///   `24px–28px` map pin sizes.
///
/// Set [isOnGoldBackground] to `true` when rendering on a solid gold surface
/// to switch to the high-contrast deep charcoal-slate palette.
class MetalWizardLairIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const MetalWizardLairIcon({
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
          painter: _MetalWizardLairPainter(
            isOnGoldBackground: isOnGoldBackground,
          ),
        ),
      ),
    );
  }
}

class _AutomatonPalette {
  final Color steelHighlight;
  final Color steelLight;
  final Color ironMid;
  final Color ironDark;
  final Color bronzeLight;
  final Color bronzeMid;
  final Color bronzeDark;
  final Color fireRed;
  final Color fireOrange;
  final Color fireCore;
  final Color socketDark;
  final Color outline;

  const _AutomatonPalette({
    required this.steelHighlight,
    required this.steelLight,
    required this.ironMid,
    required this.ironDark,
    required this.bronzeLight,
    required this.bronzeMid,
    required this.bronzeDark,
    required this.fireRed,
    required this.fireOrange,
    required this.fireCore,
    required this.socketDark,
    required this.outline,
  });

  static const standard = _AutomatonPalette(
    steelHighlight: Color(0xFFECEFF1),
    steelLight: Color(0xFFCFD8DC),
    ironMid: Color(0xFF78909C),
    ironDark: Color(0xFF455A64),
    bronzeLight: Color(0xFFD68D4B),
    bronzeMid: Color(0xFFC47A38),
    bronzeDark: Color(0xFF8D5524),
    fireRed: Color(0xFFFF3D00),
    fireOrange: Color(0xFFFF9100),
    fireCore: Color(0xFFFFEA00),
    socketDark: Color(0xFF141A1D),
    outline: Color(0xFF1A2226),
  );

  static const onGold = _AutomatonPalette(
    steelHighlight: Color(0xFF455A64),
    steelLight: Color(0xFF37474F),
    ironMid: Color(0xFF263238),
    ironDark: Color(0xFF1A2226),
    bronzeLight: Color(0xFF5D4037),
    bronzeMid: Color(0xFF4E342E),
    bronzeDark: Color(0xFF3E2723),
    fireRed: Color(0xFFD84315),
    fireOrange: Color(0xFFFF6D00),
    fireCore: Color(0xFFFFCA28),
    socketDark: Color(0xFF0F1417),
    outline: Color(0xFF12171A),
  );
}

class _MetalWizardLairPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _MetalWizardLairPainter({
    required this.isOnGoldBackground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final offsetX = (size.width - side) * 0.5;
    final offsetY = (size.height - side) * 0.5;
    final scale = side / 24.0;
    final p = isOnGoldBackground
        ? _AutomatonPalette.onGold
        : _AutomatonPalette.standard;

    canvas.save();
    canvas.translate(offsetX, offsetY);

    final outlinePaint = Paint()
      ..color = p.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, 1.15 * scale)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final detailStrokePaint = Paint()
      ..color = p.outline.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.45, 0.68 * scale)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // 1. Subtle ground shadow beneath jaw guard
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(side * 0.50, side * 0.925),
        width: side * 0.68,
        height: side * 0.068,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: isOnGoldBackground ? 0.16 : 0.30),
    );

    // 2. Double metallic cogs peeking from behind left & right temples/cheeks
    _paintBackgroundCogs(canvas, side, p, outlinePaint);

    // 3. Mechanical side ear housings
    _paintSideEars(canvas, side, p, outlinePaint, detailStrokePaint);

    // 4. Faceted steel & iron automaton main head with split 3D shading
    _paintMainHead(canvas, side, p, outlinePaint, detailStrokePaint);

    // 5. Recessed sockets & blazing flame eyes
    _paintFlameEyes(canvas, side, scale, p, outlinePaint);

    // 6. Vertical bronze/brass forehead & nose strip with rivets
    _paintBronzeCrest(canvas, side, scale, p, outlinePaint);

    // 7. Heavy riveted metallic jaw guard & vent grille
    _paintJawGuard(canvas, side, scale, p, outlinePaint, detailStrokePaint);

    canvas.restore();
  }

  void _paintBackgroundCogs(
    Canvas canvas,
    double s,
    _AutomatonPalette p,
    Paint outlinePaint,
  ) {
    void drawGear({
      required Offset center,
      required double outerR,
      required double innerR,
      required int teeth,
      required double angleOffset,
      required Color fill,
    }) {
      final path = Path();
      final step = (2 * math.pi) / teeth;
      for (int i = 0; i < teeth; i++) {
        final a0 = angleOffset + i * step;
        final a1 = a0 + step * 0.22;
        final a2 = a0 + step * 0.48;
        final a3 = a0 + step * 0.72;
        final p0 = center + Offset(math.cos(a0), math.sin(a0)) * innerR;
        final p1 = center + Offset(math.cos(a1), math.sin(a1)) * outerR;
        final p2 = center + Offset(math.cos(a2), math.sin(a2)) * outerR;
        final p3 = center + Offset(math.cos(a3), math.sin(a3)) * innerR;
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
      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(path, outlinePaint);
    }

    // Left pair of peeking gears (lighter steel)
    drawGear(
      center: Offset(s * 0.185, s * 0.305),
      outerR: s * 0.120,
      innerR: s * 0.082,
      teeth: 8,
      angleOffset: 0.2,
      fill: p.steelLight,
    );
    drawGear(
      center: Offset(s * 0.165, s * 0.565),
      outerR: s * 0.095,
      innerR: s * 0.064,
      teeth: 7,
      angleOffset: 0.55,
      fill: p.ironMid,
    );

    // Right pair of peeking gears (shaded iron-slate)
    drawGear(
      center: Offset(s * 0.815, s * 0.305),
      outerR: s * 0.120,
      innerR: s * 0.082,
      teeth: 8,
      angleOffset: 0.4,
      fill: p.ironMid,
    );
    drawGear(
      center: Offset(s * 0.835, s * 0.565),
      outerR: s * 0.095,
      innerR: s * 0.064,
      teeth: 7,
      angleOffset: 0.1,
      fill: p.ironDark,
    );
  }

  void _paintSideEars(
    Canvas canvas,
    double s,
    _AutomatonPalette p,
    Paint outlinePaint,
    Paint detailStrokePaint,
  ) {
    final leftEar = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.145, s * 0.395, s * 0.24, s * 0.565),
      Radius.circular(s * 0.028),
    );
    canvas.drawRRect(
      leftEar,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bronzeLight, p.bronzeMid, p.bronzeDark],
        ).createShader(leftEar.outerRect),
    );
    canvas.drawRRect(leftEar, outlinePaint);
    canvas.drawCircle(
      Offset(s * 0.185, s * 0.48),
      s * 0.022,
      Paint()..color = p.outline,
    );

    final rightEar = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.76, s * 0.395, s * 0.855, s * 0.565),
      Radius.circular(s * 0.028),
    );
    canvas.drawRRect(
      rightEar,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bronzeMid, p.bronzeDark, p.ironDark],
        ).createShader(rightEar.outerRect),
    );
    canvas.drawRRect(rightEar, outlinePaint);
    canvas.drawCircle(
      Offset(s * 0.815, s * 0.48),
      s * 0.022,
      Paint()..color = p.outline,
    );
  }

  void _paintMainHead(
    Canvas canvas,
    double s,
    _AutomatonPalette p,
    Paint outlinePaint,
    Paint detailStrokePaint,
  ) {
    // Left half face (light steel #ECEFF1 -> #CFD8DC)
    final leftFace = Path()
      ..moveTo(s * 0.50, s * 0.115)
      ..lineTo(s * 0.315, s * 0.135)
      ..lineTo(s * 0.22, s * 0.255)
      ..lineTo(s * 0.21, s * 0.535)
      ..lineTo(s * 0.265, s * 0.69)
      ..lineTo(s * 0.50, s * 0.69)
      ..close();
    canvas.drawPath(
      leftFace,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.steelHighlight, p.steelLight],
        ).createShader(Rect.fromLTRB(s * 0.21, s * 0.115, s * 0.50, s * 0.69)),
    );

    // Right half face (shadow iron-slate #78909C -> #455A64)
    final rightFace = Path()
      ..moveTo(s * 0.50, s * 0.115)
      ..lineTo(s * 0.685, s * 0.135)
      ..lineTo(s * 0.78, s * 0.255)
      ..lineTo(s * 0.79, s * 0.535)
      ..lineTo(s * 0.735, s * 0.69)
      ..lineTo(s * 0.50, s * 0.69)
      ..close();
    canvas.drawPath(
      rightFace,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.ironMid, p.ironDark],
        ).createShader(Rect.fromLTRB(s * 0.50, s * 0.115, s * 0.79, s * 0.69)),
    );

    // Full armored head outline
    final headOutline = Path()
      ..moveTo(s * 0.50, s * 0.115)
      ..lineTo(s * 0.685, s * 0.135)
      ..lineTo(s * 0.78, s * 0.255)
      ..lineTo(s * 0.79, s * 0.535)
      ..lineTo(s * 0.735, s * 0.69)
      ..lineTo(s * 0.265, s * 0.69)
      ..lineTo(s * 0.21, s * 0.535)
      ..lineTo(s * 0.22, s * 0.255)
      ..lineTo(s * 0.315, s * 0.135)
      ..close();
    canvas.drawPath(headOutline, outlinePaint);

    // Faceted brow & cheekbone armor seam lines
    canvas.drawLine(
      Offset(s * 0.225, s * 0.32),
      Offset(s * 0.445, s * 0.375),
      detailStrokePaint,
    );
    canvas.drawLine(
      Offset(s * 0.775, s * 0.32),
      Offset(s * 0.555, s * 0.375),
      detailStrokePaint,
    );
    canvas.drawLine(
      Offset(s * 0.215, s * 0.53),
      Offset(s * 0.34, s * 0.585),
      detailStrokePaint,
    );
    canvas.drawLine(
      Offset(s * 0.785, s * 0.53),
      Offset(s * 0.66, s * 0.585),
      detailStrokePaint,
    );

    // Brow plate rivets
    for (final pt in [
      Offset(s * 0.31, s * 0.215),
      Offset(s * 0.69, s * 0.215),
    ]) {
      canvas.drawCircle(pt, s * 0.022, Paint()..color = p.outline);
    }
  }

  void _paintFlameEyes(
    Canvas canvas,
    double s,
    double scale,
    _AutomatonPalette p,
    Paint outlinePaint,
  ) {
    // Recessed dark angular eye sockets
    final leftSocket = Path()
      ..moveTo(s * 0.265, s * 0.355)
      ..lineTo(s * 0.44, s * 0.41)
      ..lineTo(s * 0.425, s * 0.515)
      ..lineTo(s * 0.28, s * 0.50)
      ..close();
    final rightSocket = Path()
      ..moveTo(s * 0.735, s * 0.355)
      ..lineTo(s * 0.56, s * 0.41)
      ..lineTo(s * 0.575, s * 0.515)
      ..lineTo(s * 0.72, s * 0.50)
      ..close();

    for (final socket in [leftSocket, rightSocket]) {
      canvas.drawPath(socket, Paint()..color = p.socketDark);
      canvas.drawPath(socket, outlinePaint);
    }

    // Blazing flame eyes erupting outward in #FF3D00 / #FF9100
    void drawFlameEye({required bool isLeft}) {
      final sign = isLeft ? -1.0 : 1.0;
      double px(double offsetFromCenter) => s * (0.50 + sign * offsetFromCenter);

      final outerFlame = Path()
        ..moveTo(px(0.145), s * 0.495)
        ..cubicTo(px(0.225), s * 0.485, px(0.25), s * 0.395, px(0.23), s * 0.325)
        ..cubicTo(px(0.195), s * 0.365, px(0.185), s * 0.385, px(0.155), s * 0.355)
        ..cubicTo(px(0.15), s * 0.405, px(0.08), s * 0.41, px(0.08), s * 0.465)
        ..cubicTo(px(0.08), s * 0.495, px(0.115), s * 0.50, px(0.145), s * 0.495)
        ..close();

      canvas.drawPath(
        outerFlame,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [p.fireRed, p.fireOrange],
          ).createShader(
            Rect.fromLTRB(
              math.min(px(0.07), px(0.26)),
              s * 0.32,
              math.max(px(0.07), px(0.26)),
              s * 0.51,
            ),
          ),
      );
      canvas.drawPath(
        outerFlame,
        Paint()
          ..color = p.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.45, 0.65 * scale)
          ..strokeJoin = StrokeJoin.round,
      );

      // Hot inner flame core
      final innerFlame = Path()
        ..moveTo(px(0.14), s * 0.48)
        ..cubicTo(px(0.185), s * 0.475, px(0.20), s * 0.425, px(0.185), s * 0.39)
        ..cubicTo(px(0.155), s * 0.415, px(0.115), s * 0.43, px(0.115), s * 0.465)
        ..close();
      canvas.drawPath(innerFlame, Paint()..color = p.fireCore);
    }

    drawFlameEye(isLeft: true);
    drawFlameEye(isLeft: false);
  }

  void _paintBronzeCrest(
    Canvas canvas,
    double s,
    double scale,
    _AutomatonPalette p,
    Paint outlinePaint,
  ) {
    // Prominent vertical bronze/brass forehead & nose strip with split shading
    final leftCrest = Path()
      ..moveTo(s * 0.50, s * 0.068)
      ..lineTo(s * 0.435, s * 0.115)
      ..lineTo(s * 0.452, s * 0.585)
      ..lineTo(s * 0.50, s * 0.61)
      ..close();
    canvas.drawPath(
      leftCrest,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bronzeLight, p.bronzeMid],
        ).createShader(Rect.fromLTRB(s * 0.435, s * 0.068, s * 0.50, s * 0.61)),
    );

    final rightCrest = Path()
      ..moveTo(s * 0.50, s * 0.068)
      ..lineTo(s * 0.565, s * 0.115)
      ..lineTo(s * 0.548, s * 0.585)
      ..lineTo(s * 0.50, s * 0.61)
      ..close();
    canvas.drawPath(
      rightCrest,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bronzeMid, p.bronzeDark],
        ).createShader(Rect.fromLTRB(s * 0.50, s * 0.068, s * 0.565, s * 0.61)),
    );

    final fullCrest = Path()
      ..moveTo(s * 0.50, s * 0.068)
      ..lineTo(s * 0.565, s * 0.115)
      ..lineTo(s * 0.548, s * 0.585)
      ..lineTo(s * 0.50, s * 0.61)
      ..lineTo(s * 0.452, s * 0.585)
      ..lineTo(s * 0.435, s * 0.115)
      ..close();
    canvas.drawPath(fullCrest, outlinePaint);

    // Center metallic ridge & circular dark rivets along the crest
    canvas.drawLine(
      Offset(s * 0.50, s * 0.10),
      Offset(s * 0.50, s * 0.58),
      Paint()
        ..color = p.outline.withValues(alpha: 0.45)
        ..strokeWidth = math.max(0.45, 0.60 * scale),
    );
    for (final ry in [s * 0.175, s * 0.285]) {
      canvas.drawCircle(
        Offset(s * 0.50, ry),
        s * 0.022,
        Paint()..color = p.outline,
      );
    }
  }

  void _paintJawGuard(
    Canvas canvas,
    double s,
    double scale,
    _AutomatonPalette p,
    Paint outlinePaint,
    Paint detailStrokePaint,
  ) {
    // Split-shaded armored lower jaw guard
    final leftJaw = Path()
      ..moveTo(s * 0.245, s * 0.615)
      ..lineTo(s * 0.50, s * 0.615)
      ..lineTo(s * 0.50, s * 0.905)
      ..lineTo(s * 0.305, s * 0.855)
      ..close();
    canvas.drawPath(
      leftJaw,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.steelHighlight, p.steelLight],
        ).createShader(Rect.fromLTRB(s * 0.245, s * 0.615, s * 0.50, s * 0.905)),
    );

    final rightJaw = Path()
      ..moveTo(s * 0.50, s * 0.615)
      ..lineTo(s * 0.755, s * 0.615)
      ..lineTo(s * 0.695, s * 0.855)
      ..lineTo(s * 0.50, s * 0.905)
      ..close();
    canvas.drawPath(
      rightJaw,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.ironMid, p.ironDark],
        ).createShader(Rect.fromLTRB(s * 0.50, s * 0.615, s * 0.755, s * 0.905)),
    );

    final jawOutline = Path()
      ..moveTo(s * 0.245, s * 0.615)
      ..lineTo(s * 0.755, s * 0.615)
      ..lineTo(s * 0.695, s * 0.855)
      ..lineTo(s * 0.50, s * 0.905)
      ..lineTo(s * 0.305, s * 0.855)
      ..close();
    canvas.drawPath(jawOutline, outlinePaint);

    // Bronze upper jaw rim accent
    final jawTrim = Rect.fromLTRB(s * 0.285, s * 0.615, s * 0.715, s * 0.655);
    canvas.drawRect(
      jawTrim,
      Paint()
        ..shader = LinearGradient(
          colors: [p.bronzeLight, p.bronzeMid, p.bronzeDark],
        ).createShader(jawTrim),
    );
    canvas.drawRect(jawTrim, detailStrokePaint);

    // Recessed central mouth vent plate with 3 vertical grille bars
    final grilleRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.395, s * 0.685, s * 0.605, s * 0.825),
      Radius.circular(s * 0.025),
    );
    canvas.drawRRect(grilleRect, Paint()..color = p.socketDark);
    canvas.drawRRect(grilleRect, detailStrokePaint);

    final grilleBarPaint = Paint()
      ..color = p.steelLight.withValues(alpha: isOnGoldBackground ? 0.55 : 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.55, 0.80 * scale)
      ..strokeCap = StrokeCap.round;
    for (final gx in [s * 0.45, s * 0.50, s * 0.55]) {
      canvas.drawLine(
        Offset(gx, s * 0.705),
        Offset(gx, s * 0.805),
        grilleBarPaint,
      );
    }

    // Heavy circular corner rivets on jaw guard
    for (final pt in [
      Offset(s * 0.32, s * 0.705),
      Offset(s * 0.345, s * 0.81),
      Offset(s * 0.68, s * 0.705),
      Offset(s * 0.655, s * 0.81),
    ]) {
      canvas.drawCircle(pt, s * 0.021, Paint()..color = p.outline);
    }
  }

  @override
  bool shouldRepaint(_MetalWizardLairPainter oldDelegate) {
    return oldDelegate.isOnGoldBackground != isOnGoldBackground;
  }
}
