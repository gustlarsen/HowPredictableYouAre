import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/sacred_blessing.dart';
import 'sacred_temple_icon.dart';

/// Shared helper wrapper matching [RoyalCastleIcon] and [castle_wing_icons.dart]
/// so every Sacred Temple custom vector icon renders cleanly at a fixed square
/// dimension inside a [RepaintBoundary].
class _TempleVectorIcon extends StatelessWidget {
  final double size;
  final CustomPainter painter;

  const _TempleVectorIcon({
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

Color _outlineColor(bool isOnGoldBackground) =>
    isOnGoldBackground ? const Color(0xFF12181B) : const Color(0xFF1A2226);

Paint _outlinePaint(
  double scale, {
  bool isOnGoldBackground = false,
  double baseWidth = 1.30,
}) {
  return Paint()
    ..color = _outlineColor(isOnGoldBackground)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.85, baseWidth * scale)
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
}

Paint _detailPaint(
  double scale, {
  bool isOnGoldBackground = false,
  double alpha = 0.78,
  double baseWidth = 0.85,
}) {
  return Paint()
    ..color = _outlineColor(isOnGoldBackground).withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.55, baseWidth * scale)
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
}

// =============================================================================
// 5 NAVIGATION TAB ICONS (Accepting `size` & `bool isOnGoldBackground`)
// =============================================================================

/// Tab 1 — Consagration: Bold, wide-rimmed Sacred Chalice / Goblet with
/// sculpted stem, central ornamental collar node, and tiered triangular base.
class ConsagrationChaliceIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const ConsagrationChaliceIcon({
    super.key,
    this.size = 28.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: _ConsagrationChalicePainter(
        isOnGoldBackground: isOnGoldBackground,
      ),
    );
  }
}

class _ConsagrationChalicePainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _ConsagrationChalicePainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.32,
    );
    final detail = _detailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.75,
    );

    final bodyHighlight =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFF3B0);
    final bodyLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFFFD54F);
    final bodyMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFB300);
    final bodyDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFFB27800);
    final cupInterior =
        isOnGoldBackground ? const Color(0xFF101518) : const Color(0xFF6B4200);
    final glintColor = isOnGoldBackground
        ? const Color(0xFF90A4AE).withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.78);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Sturdy tiered triangular base (y: 0.74..0.90)
    final footSlope = Path()
      ..moveTo(s * 0.43, s * 0.74)
      ..lineTo(s * 0.57, s * 0.74)
      ..lineTo(s * 0.73, s * 0.855)
      ..lineTo(s * 0.27, s * 0.855)
      ..close();
    canvas.drawPath(
      footSlope,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [bodyLight, bodyMid, bodyDark],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.27, s * 0.74, s * 0.73, s * 0.855)),
    );
    canvas.drawPath(footSlope, outline);

    final footPlinth = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.23, s * 0.84, s * 0.77, s * 0.905),
      Radius.circular(s * 0.03),
    );
    canvas.drawRRect(
      footPlinth,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [bodyLight, bodyMid, bodyDark],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(footPlinth.outerRect),
    );
    canvas.drawRRect(footPlinth, outline);

    // 2. Thick sculpted stem & central ornamental collar node (y: 0.51..0.76)
    final stemRect = Rect.fromLTRB(s * 0.435, s * 0.51, s * 0.565, s * 0.76);
    canvas.drawRect(
      stemRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [bodyLight, bodyMid, bodyDark],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(stemRect),
    );
    canvas.drawRect(stemRect, outline);

    final collarNode = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.64),
        width: s * 0.28,
        height: s * 0.095,
      ),
      Radius.circular(s * 0.048),
    );
    canvas.drawRRect(
      collarNode,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bodyHighlight, bodyLight, bodyMid, bodyDark],
          stops: const [0.0, 0.28, 0.68, 1.0],
        ).createShader(collarNode.outerRect),
    );
    canvas.drawRRect(collarNode, outline);

    // Subtle upper ring collar beneath cup
    final neckRing = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.545),
        width: s * 0.20,
        height: s * 0.055,
      ),
      Radius.circular(s * 0.028),
    );
    canvas.drawRRect(
      neckRing,
      Paint()
        ..shader = LinearGradient(
          colors: [bodyLight, bodyMid, bodyDark],
        ).createShader(neckRing.outerRect),
    );
    canvas.drawRRect(neckRing, outline);

    // 3. Wide flared chalice cup (y: 0.18..0.53)
    final cupPath = Path()
      ..moveTo(s * 0.21, s * 0.20)
      ..lineTo(s * 0.79, s * 0.20)
      ..cubicTo(s * 0.79, s * 0.42, s * 0.65, s * 0.525, s * 0.50, s * 0.525)
      ..cubicTo(s * 0.35, s * 0.525, s * 0.21, s * 0.42, s * 0.21, s * 0.20)
      ..close();
    canvas.drawPath(
      cupPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bodyHighlight, bodyLight, bodyMid, bodyDark],
          stops: const [0.0, 0.26, 0.62, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.21, s * 0.20, s * 0.79, s * 0.525)),
    );

    // Left-side curved specular facet glint on cup
    final cupHighlight = Path()
      ..moveTo(s * 0.27, s * 0.265)
      ..cubicTo(s * 0.27, s * 0.37, s * 0.34, s * 0.445, s * 0.415, s * 0.47)
      ..cubicTo(s * 0.365, s * 0.42, s * 0.325, s * 0.35, s * 0.32, s * 0.265)
      ..close();
    canvas.drawPath(cupHighlight, Paint()..color = glintColor);
    canvas.drawPath(cupPath, outline);

    // Sculpted decorative mid-cup rib line
    final cupRib = Path()
      ..moveTo(s * 0.245, s * 0.335)
      ..quadraticBezierTo(s * 0.50, s * 0.39, s * 0.755, s * 0.335);
    canvas.drawPath(cupRib, detail);

    // 4. Wide elliptical sculpted rim & recessed dark inner bowl (y: 0.13..0.255)
    final outerRimRect = Rect.fromLTRB(s * 0.19, s * 0.135, s * 0.81, s * 0.255);
    canvas.drawOval(
      outerRimRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bodyHighlight, bodyLight, bodyMid, bodyDark],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ).createShader(outerRimRect),
    );
    canvas.drawOval(outerRimRect, outline);

    final innerBowlRect = Rect.fromLTRB(s * 0.255, s * 0.155, s * 0.745, s * 0.232);
    canvas.drawOval(innerBowlRect, Paint()..color = cupInterior);
    canvas.drawOval(innerBowlRect, detail);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ConsagrationChalicePainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Tab 2 — Offerings: Wide architectural White Marble Altar Pedestal with
/// stepped top slab, golden trim accents, and recessed carved pillars, topped
/// by a large, multi-tongued roaring Sacred Flame.
class OfferingsAltarIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const OfferingsAltarIcon({
    super.key,
    this.size = 28.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: _OfferingsAltarPainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _OfferingsAltarPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _OfferingsAltarPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.25,
    );
    final detail = _detailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.72,
    );

    final marbleLight =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFFFFF);
    final marbleMid =
        isOnGoldBackground ? const Color(0xFF37474F) : const Color(0xFFE4E9ED);
    final marbleDark =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFF9EAAB3);
    final recessBg =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFF697680);

    final trimLight =
        isOnGoldBackground ? const Color(0xFF37474F) : const Color(0xFFFFE082);
    final trimDark =
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFFC68400);

    const flameOuterTop = Color(0xFFFFC107);
    const flameOuterMid = Color(0xFFFF8F00);
    const flameOuterBot = Color(0xFFE65100);
    const flameCoreTop = Color(0xFFFFFFFF);
    const flameCoreBot = Color(0xFFFFF59D);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Large multi-tongued roaring Sacred Flame (y: 0.09..0.46)
    final sideFlames = Path()
      // Left roaring tongue
      ..moveTo(s * 0.30, s * 0.45)
      ..cubicTo(s * 0.21, s * 0.37, s * 0.23, s * 0.27, s * 0.29, s * 0.21)
      ..cubicTo(s * 0.31, s * 0.28, s * 0.36, s * 0.31, s * 0.40, s * 0.45)
      ..close()
      // Right roaring tongue
      ..moveTo(s * 0.60, s * 0.45)
      ..cubicTo(s * 0.64, s * 0.31, s * 0.69, s * 0.28, s * 0.71, s * 0.21)
      ..cubicTo(s * 0.77, s * 0.27, s * 0.79, s * 0.37, s * 0.70, s * 0.45)
      ..close();
    canvas.drawPath(
      sideFlames,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [flameOuterTop, flameOuterBot],
        ).createShader(Rect.fromLTRB(s * 0.22, s * 0.21, s * 0.78, s * 0.45)),
    );
    canvas.drawPath(sideFlames, outline);

    final mainFlame = Path()
      ..moveTo(s * 0.50, s * 0.09)
      ..cubicTo(s * 0.58, s * 0.17, s * 0.56, s * 0.24, s * 0.62, s * 0.28)
      ..cubicTo(s * 0.66, s * 0.34, s * 0.65, s * 0.41, s * 0.58, s * 0.455)
      ..lineTo(s * 0.42, s * 0.455)
      ..cubicTo(s * 0.35, s * 0.41, s * 0.34, s * 0.34, s * 0.38, s * 0.28)
      ..cubicTo(s * 0.44, s * 0.24, s * 0.42, s * 0.17, s * 0.50, s * 0.09)
      ..close();
    canvas.drawPath(
      mainFlame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [flameOuterTop, flameOuterMid, flameOuterBot],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.35, s * 0.09, s * 0.65, s * 0.455)),
    );
    canvas.drawPath(mainFlame, outline);

    final innerCore = Path()
      ..moveTo(s * 0.50, s * 0.21)
      ..cubicTo(s * 0.56, s * 0.29, s * 0.56, s * 0.39, s * 0.525, s * 0.445)
      ..lineTo(s * 0.475, s * 0.445)
      ..cubicTo(s * 0.44, s * 0.39, s * 0.44, s * 0.29, s * 0.50, s * 0.21)
      ..close();
    canvas.drawPath(
      innerCore,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [flameCoreTop, flameCoreBot],
        ).createShader(Rect.fromLTRB(s * 0.44, s * 0.21, s * 0.56, s * 0.445)),
    );

    // 2. Central marble pedestal body with recessed carved pillars (y: 0.55..0.79)
    final bodyRect = Rect.fromLTRB(s * 0.21, s * 0.55, s * 0.79, s * 0.79);
    canvas.drawRect(
      bodyRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [marbleLight, marbleMid, marbleDark],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bodyRect),
    );
    canvas.drawRect(bodyRect, outline);

    // Recessed carved center niche
    final nicheRect = Rect.fromLTRB(s * 0.32, s * 0.575, s * 0.68, s * 0.77);
    canvas.drawRect(nicheRect, Paint()..color = recessBg);
    canvas.drawRect(nicheRect, detail);

    // Two distinct carved inner pillars inside the recess
    for (final px in [s * 0.375, s * 0.545]) {
      final pillarRect = Rect.fromLTRB(px, s * 0.58, px + s * 0.08, s * 0.765);
      canvas.drawRect(
        pillarRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [marbleLight, marbleMid, marbleDark],
          ).createShader(pillarRect),
      );
      canvas.drawRect(pillarRect, detail);
    }

    // 3. Stepped top marble slab & golden trim molding (y: 0.435..0.555)
    final topSlab = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.11, s * 0.435, s * 0.89, s * 0.505),
      Radius.circular(s * 0.025),
    );
    canvas.drawRRect(
      topSlab,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [marbleLight, marbleMid, marbleDark],
        ).createShader(topSlab.outerRect),
    );
    canvas.drawRRect(topSlab, outline);

    final goldenMolding = Rect.fromLTRB(s * 0.16, s * 0.505, s * 0.84, s * 0.555);
    canvas.drawRect(
      goldenMolding,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [trimLight, trimDark],
        ).createShader(goldenMolding),
    );
    canvas.drawRect(goldenMolding, outline);

    // 4. Stepped marble & gold base plinth (y: 0.785..0.90)
    final upperBase = Rect.fromLTRB(s * 0.16, s * 0.785, s * 0.84, s * 0.842);
    canvas.drawRect(
      upperBase,
      Paint()
        ..shader = LinearGradient(
          colors: [trimLight, trimDark],
        ).createShader(upperBase),
    );
    canvas.drawRect(upperBase, outline);

    final lowerBase = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.11, s * 0.842, s * 0.89, s * 0.905),
      Radius.circular(s * 0.025),
    );
    canvas.drawRRect(
      lowerBase,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [marbleLight, marbleMid, marbleDark],
        ).createShader(lowerBase.outerRect),
    );
    canvas.drawRRect(lowerBase, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_OfferingsAltarPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Tab 3 — Transformation: Radiant 4-pointed divine miracle star/cross framed
/// by two graceful curved golden transformation arcs symbolizing divine grace
/// converting one substance into another.
class HolyTransformationIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const HolyTransformationIcon({
    super.key,
    this.size = 28.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: _HolyTransformationPainter(
        isOnGoldBackground: isOnGoldBackground,
      ),
    );
  }
}

class _HolyTransformationPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _HolyTransformationPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.25,
    );
    final detail = _detailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.72,
      baseWidth: 0.80,
    );

    // On active gold pill (#F5C22B), switch cleanly to deep charcoal-slate
    // tones for crisp contrast; when inactive, use rich gold & radiant ivory/cyan.
    final arcLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFFFF3B0);
    final arcMid =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFFFFCA28);
    final arcDark =
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFFB27800);

    final starCenter =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFFFFF);
    final starMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFE0F7FA);
    final starEdge =
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFF4DD0E1);

    final sparkleColor = isOnGoldBackground
        ? const Color(0xFF263238)
        : const Color(0xFFFFF8E1);
    final glintColor = isOnGoldBackground
        ? const Color(0xFF90A4AE).withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.80);

    canvas.save();
    canvas.translate(ox, oy);

    final c = Offset(s * 0.50, s * 0.50);

    // 1. Two graceful curved transformation arcs orbiting the miracle star
    Path buildTransformationArc(double rotationOffset) {
      final path = Path();
      const steps = 16;
      const startAngle = math.pi * 1.08;
      const endAngle = math.pi * 1.84; // sweeps across top to upper-right
      final rIn = s * 0.315;
      final rOut = s * 0.43;
      final rMid = (rIn + rOut) * 0.5;

      Offset polar(double angle, double radius) =>
          c + Offset(math.cos(angle + rotationOffset), math.sin(angle + rotationOffset)) * radius;

      // Start at tapered tail
      final tail = polar(startAngle, rMid);
      path.moveTo(tail.dx, tail.dy);

      // Outer sweeping curve swelling toward the arrow head
      for (int i = 1; i <= steps; i++) {
        final t = i / steps;
        final a = startAngle + (endAngle - startAngle) * t;
        final thickness = math.sin(t * math.pi * 0.68);
        final r = rMid + (rOut - rMid) * (0.25 + 0.75 * thickness);
        final pt = polar(a, r);
        path.lineTo(pt.dx, pt.dy);
      }

      // Flared light-beam arrowhead pointing clockwise
      final headOuter = polar(endAngle - 0.03, s * 0.465);
      final headTip = polar(endAngle + 0.14, rMid);
      final headInner = polar(endAngle - 0.03, s * 0.27);
      path.lineTo(headOuter.dx, headOuter.dy);
      path.lineTo(headTip.dx, headTip.dy);
      path.lineTo(headInner.dx, headInner.dy);

      // Inner sweeping curve returning to tapered tail
      for (int i = steps; i >= 1; i--) {
        final t = i / steps;
        final a = startAngle + (endAngle - startAngle) * t;
        final thickness = math.sin(t * math.pi * 0.68);
        final r = rMid - (rMid - rIn) * (0.25 + 0.75 * thickness);
        final pt = polar(a, r);
        path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      return path;
    }

    for (final rot in [0.0, math.pi]) {
      final arcPath = buildTransformationArc(rot);
      canvas.drawPath(
        arcPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [arcLight, arcMid, arcDark],
            stops: const [0.0, 0.50, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: s * 0.46)),
      );
      canvas.drawPath(arcPath, outline);
    }

    // Subtle specular glint along upper arc crest
    final upperGlint = Path()
      ..addArc(
        Rect.fromCircle(center: c, radius: s * 0.39),
        -math.pi * 0.72,
        math.pi * 0.34,
      );
    canvas.drawPath(
      upperGlint,
      Paint()
        ..color = glintColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.75, 0.9 * scale)
        ..strokeCap = StrokeCap.round,
    );

    // 2. Radiant 4-pointed divine miracle star/cross in the center
    final rTip = s * 0.275;
    final starPath = Path()
      ..moveTo(c.dx, c.dy - rTip)
      ..cubicTo(
        c.dx + s * 0.014,
        c.dy - s * 0.068,
        c.dx + s * 0.068,
        c.dy - s * 0.014,
        c.dx + rTip,
        c.dy,
      )
      ..cubicTo(
        c.dx + s * 0.068,
        c.dy + s * 0.014,
        c.dx + s * 0.014,
        c.dy + s * 0.068,
        c.dx,
        c.dy + rTip,
      )
      ..cubicTo(
        c.dx - s * 0.014,
        c.dy + s * 0.068,
        c.dx - s * 0.068,
        c.dy + s * 0.014,
        c.dx - rTip,
        c.dy,
      )
      ..cubicTo(
        c.dx - s * 0.068,
        c.dy - s * 0.014,
        c.dx - s * 0.014,
        c.dy - s * 0.068,
        c.dx,
        c.dy - rTip,
      )
      ..close();

    canvas.drawPath(
      starPath,
      Paint()
        ..shader = RadialGradient(
          colors: [starCenter, starMid, starEdge],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: rTip)),
    );
    canvas.drawPath(starPath, outline);

    // Fine internal cross-flare ribs inside the 4-pointed miracle star
    canvas.drawLine(
      Offset(c.dx, c.dy - s * 0.14),
      Offset(c.dx, c.dy + s * 0.14),
      detail,
    );
    canvas.drawLine(
      Offset(c.dx - s * 0.14, c.dy),
      Offset(c.dx + s * 0.14, c.dy),
      detail,
    );

    // 3. Delicate diagonal miracle sparkle accents in the open quadrants
    for (final pt in [
      Offset(s * 0.25, s * 0.25),
      Offset(s * 0.75, s * 0.75),
    ]) {
      canvas.drawCircle(pt, s * 0.026, Paint()..color = sparkleColor);
      canvas.drawCircle(pt, s * 0.026, detail);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HolyTransformationPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Tab 4 — Adoration: Ornate classical S-Curved Golden Lyre / Harp with wide
/// sculpted tiered pedestal base, scrolled top volutes, curved golden crossbar,
/// and 5 crisp vertical ivory-white harp strings.
class AdorationHarpIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const AdorationHarpIcon({
    super.key,
    this.size = 28.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: _AdorationHarpPainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _AdorationHarpPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _AdorationHarpPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.25,
    );
    final detail = _detailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.72,
    );

    final goldHighlight =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFF3B0);
    final goldLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFFFD54F);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFB300);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFFB27800);
    const stringIvory = Color(0xFFFFFDF7);
    final stringCasing = _outlineColor(isOnGoldBackground);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. 5 crisp vertical ivory-white harp strings with subtle dark casing
    final casingPaint = Paint()
      ..color = stringCasing.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.3, 1.65 * scale)
      ..strokeCap = StrokeCap.round;
    final stringPaint = Paint()
      ..color = stringIvory
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, 0.90 * scale)
      ..strokeCap = StrokeCap.round;

    for (final sx in [s * 0.37, s * 0.435, s * 0.50, s * 0.565, s * 0.63]) {
      canvas.drawLine(Offset(sx, s * 0.21), Offset(sx, s * 0.72), casingPaint);
      canvas.drawLine(Offset(sx, s * 0.21), Offset(sx, s * 0.72), stringPaint);
    }

    // 2. Curved golden top crossbar / yoke (y: 0.16..0.24)
    final yokePath = Path()
      ..moveTo(s * 0.24, s * 0.20)
      ..quadraticBezierTo(s * 0.50, s * 0.15, s * 0.76, s * 0.20)
      ..lineTo(s * 0.74, s * 0.255)
      ..quadraticBezierTo(s * 0.50, s * 0.21, s * 0.26, s * 0.255)
      ..close();
    canvas.drawPath(
      yokePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [goldHighlight, goldLight, goldMid, goldDark],
          stops: const [0.0, 0.28, 0.70, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.24, s * 0.15, s * 0.76, s * 0.26)),
    );
    canvas.drawPath(yokePath, outline);

    // 3. Two graceful, thick S-curved outer arms with scrolled top volutes
    for (final isLeft in [true, false]) {
      final sign = isLeft ? -1.0 : 1.0;
      double px(double offsetFromCenter) => s * (0.50 + sign * offsetFromCenter);

      final armPath = Path()
        // Outer S-curve from soundbox up to curled top volute
        ..moveTo(px(0.20), s * 0.73)
        ..cubicTo(
          px(0.39),
          s * 0.63,
          px(0.38),
          s * 0.42,
          px(0.27),
          s * 0.30,
        )
        ..cubicTo(
          px(0.22),
          s * 0.24,
          px(0.24),
          s * 0.13,
          px(0.33),
          s * 0.13,
        )
        ..cubicTo(
          px(0.385),
          s * 0.13,
          px(0.405),
          s * 0.195,
          px(0.35),
          s * 0.225,
        )
        // Smooth inner return curve down to soundbox
        ..cubicTo(
          px(0.30),
          s * 0.245,
          px(0.23),
          s * 0.24,
          px(0.215),
          s * 0.31,
        )
        ..cubicTo(
          px(0.285),
          s * 0.43,
          px(0.29),
          s * 0.60,
          px(0.13),
          s * 0.72,
        )
        ..close();

      canvas.drawPath(
        armPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isLeft
                ? [goldHighlight, goldLight, goldMid]
                : [goldHighlight, goldMid, goldDark],
          ).createShader(Rect.fromLTRB(s * 0.10, s * 0.13, s * 0.90, s * 0.74)),
      );
      canvas.drawPath(armPath, outline);

      // Scrolled volute accent bead inside top curl
      canvas.drawCircle(
        Offset(px(0.335), s * 0.178),
        s * 0.024,
        Paint()..color = isLeft ? goldHighlight : goldLight,
      );
      canvas.drawCircle(Offset(px(0.335), s * 0.178), s * 0.024, detail);
    }

    // 4. Sculpted soundbox & wide tiered golden pedestal base (y: 0.68..0.90)
    final soundbox = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.26, s * 0.685, s * 0.74, s * 0.80),
      Radius.circular(s * 0.05),
    );
    canvas.drawRRect(
      soundbox,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [goldHighlight, goldLight, goldMid, goldDark],
        ).createShader(soundbox.outerRect),
    );
    canvas.drawRRect(soundbox, outline);

    // Recessed ornamental panel on soundbox
    final soundRecess = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.745),
        width: s * 0.26,
        height: s * 0.055,
      ),
      Radius.circular(s * 0.025),
    );
    canvas.drawRRect(soundRecess, Paint()..color = goldDark);
    canvas.drawRRect(soundRecess, detail);

    final pedestalStep = Path()
      ..moveTo(s * 0.28, s * 0.795)
      ..lineTo(s * 0.72, s * 0.795)
      ..lineTo(s * 0.78, s * 0.855)
      ..lineTo(s * 0.22, s * 0.855)
      ..close();
    canvas.drawPath(
      pedestalStep,
      Paint()
        ..shader = LinearGradient(
          colors: [goldLight, goldMid, goldDark],
        ).createShader(Rect.fromLTRB(s * 0.22, s * 0.795, s * 0.78, s * 0.855)),
    );
    canvas.drawPath(pedestalStep, outline);

    final pedestalPlinth = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.18, s * 0.845, s * 0.82, s * 0.905),
      Radius.circular(s * 0.028),
    );
    canvas.drawRRect(
      pedestalPlinth,
      Paint()
        ..shader = LinearGradient(
          colors: [goldHighlight, goldMid, goldDark],
        ).createShader(pedestalPlinth.outerRect),
    );
    canvas.drawRRect(pedestalPlinth, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_AdorationHarpPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Tab 5 — Prayer: Expressive, anatomically clear Praying Hands with curved
/// finger contours, warm shaded skin tones, sky-blue/ivory flared robe cuffs,
/// and a tilted 3D golden oval Halo floating above the fingertips.
class PrayerHandsIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const PrayerHandsIcon({
    super.key,
    this.size = 28.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: _PrayerHandsPainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _PrayerHandsPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _PrayerHandsPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.25,
    );
    final detail = _detailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.75,
    );

    const skinHighlight = Color(0xFFF2C5AB);
    const skinLight = Color(0xFFE0A98B);
    const skinMid = Color(0xFFC48466);
    const skinDark = Color(0xFF9C5F43);

    const robeLight = Color(0xFF81D4FA);
    const robeMid = Color(0xFF29B6F6);
    const robeDark = Color(0xFF0277BD);
    const cuffIvory = Color(0xFFFAF8F2);
    const cuffShadow = Color(0xFFCFD8DC);

    final haloLight =
        isOnGoldBackground ? const Color(0xFFFFF59D) : const Color(0xFFFFF8E1);
    final haloMid =
        isOnGoldBackground ? const Color(0xFFFFB300) : const Color(0xFFFFD54F);
    final haloDark =
        isOnGoldBackground ? const Color(0xFF9A5800) : const Color(0xFFB27800);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Tilted 3D golden oval halo floating above fingertips (y: 0.08..0.22)
    final outerHalo = Rect.fromCenter(
      center: Offset(s * 0.50, s * 0.15),
      width: s * 0.50,
      height: s * 0.145,
    );
    final innerHalo = Rect.fromCenter(
      center: Offset(s * 0.50, s * 0.15),
      width: s * 0.28,
      height: s * 0.048,
    );
    final haloPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(outerHalo)
      ..addOval(innerHalo);
    canvas.drawPath(
      haloPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [haloLight, haloMid, haloDark],
        ).createShader(outerHalo),
    );
    final haloOutline = _outlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 0.90,
    );
    canvas.drawOval(outerHalo, haloOutline);
    canvas.drawOval(innerHalo, haloOutline);

    // 2. Far-side hand silhouette (left/back hand peeking out for 3D depth)
    final backHand = Path()
      ..moveTo(s * 0.47, s * 0.255)
      ..cubicTo(s * 0.41, s * 0.28, s * 0.36, s * 0.41, s * 0.33, s * 0.53)
      ..cubicTo(s * 0.30, s * 0.62, s * 0.29, s * 0.69, s * 0.31, s * 0.75)
      ..lineTo(s * 0.51, s * 0.75)
      ..lineTo(s * 0.51, s * 0.27)
      ..close();
    canvas.drawPath(
      backHand,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [skinLight, skinMid, skinDark],
        ).createShader(Rect.fromLTRB(s * 0.29, s * 0.255, s * 0.51, s * 0.75)),
    );
    canvas.drawPath(backHand, outline);

    // 3. Near-side expressive praying hand with curved finger & thumb contours
    final frontHand = Path()
      ..moveTo(s * 0.51, s * 0.26)
      ..cubicTo(s * 0.57, s * 0.275, s * 0.62, s * 0.39, s * 0.65, s * 0.52)
      ..cubicTo(s * 0.68, s * 0.62, s * 0.70, s * 0.69, s * 0.68, s * 0.75)
      ..lineTo(s * 0.48, s * 0.75)
      ..cubicTo(s * 0.44, s * 0.71, s * 0.43, s * 0.64, s * 0.45, s * 0.56)
      ..cubicTo(s * 0.42, s * 0.53, s * 0.41, s * 0.47, s * 0.46, s * 0.42)
      ..cubicTo(s * 0.475, s * 0.33, s * 0.49, s * 0.275, s * 0.51, s * 0.26)
      ..close();
    canvas.drawPath(
      frontHand,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [skinHighlight, skinLight, skinMid],
          stops: [0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.42, s * 0.26, s * 0.70, s * 0.75)),
    );
    canvas.drawPath(frontHand, outline);

    // Curved finger separation & knuckle contour lines
    final finger1 = Path()
      ..moveTo(s * 0.505, s * 0.34)
      ..quadraticBezierTo(s * 0.555, s * 0.39, s * 0.575, s * 0.49);
    final finger2 = Path()
      ..moveTo(s * 0.485, s * 0.41)
      ..quadraticBezierTo(s * 0.535, s * 0.46, s * 0.555, s * 0.56);
    final leftFinger = Path()
      ..moveTo(s * 0.44, s * 0.35)
      ..quadraticBezierTo(s * 0.405, s * 0.42, s * 0.39, s * 0.50);
    canvas.drawPath(finger1, detail);
    canvas.drawPath(finger2, detail);
    canvas.drawPath(leftFinger, detail);

    // 4. Ivory cuff bands & flared sky-blue robe sleeves (y: 0.72..0.90)
    final leftCuff = Path()
      ..moveTo(s * 0.28, s * 0.72)
      ..lineTo(s * 0.49, s * 0.72)
      ..lineTo(s * 0.48, s * 0.785)
      ..lineTo(s * 0.23, s * 0.785)
      ..close();
    final rightCuff = Path()
      ..moveTo(s * 0.51, s * 0.72)
      ..lineTo(s * 0.72, s * 0.72)
      ..lineTo(s * 0.77, s * 0.785)
      ..lineTo(s * 0.52, s * 0.785)
      ..close();
    for (final cuff in [leftCuff, rightCuff]) {
      canvas.drawPath(
        cuff,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [cuffIvory, cuffShadow],
          ).createShader(Rect.fromLTRB(s * 0.22, s * 0.72, s * 0.78, s * 0.79)),
      );
      canvas.drawPath(cuff, outline);
    }

    final leftSleeve = Path()
      ..moveTo(s * 0.23, s * 0.78)
      ..lineTo(s * 0.48, s * 0.78)
      ..lineTo(s * 0.46, s * 0.905)
      ..lineTo(s * 0.14, s * 0.905)
      ..close();
    final rightSleeve = Path()
      ..moveTo(s * 0.52, s * 0.78)
      ..lineTo(s * 0.77, s * 0.78)
      ..lineTo(s * 0.86, s * 0.905)
      ..lineTo(s * 0.54, s * 0.905)
      ..close();
    for (final sleeve in [leftSleeve, rightSleeve]) {
      canvas.drawPath(
        sleeve,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [robeLight, robeMid, robeDark],
          ).createShader(Rect.fromLTRB(s * 0.14, s * 0.78, s * 0.86, s * 0.905)),
      );
      canvas.drawPath(sleeve, outline);
    }

    // Subtle sleeve drape folds
    canvas.drawLine(Offset(s * 0.33, s * 0.81), Offset(s * 0.28, s * 0.885), detail);
    canvas.drawLine(Offset(s * 0.67, s * 0.81), Offset(s * 0.72, s * 0.885), detail);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PrayerHandsPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

// =============================================================================
// MODAL HEADER & INTERNAL WING FOCAL / SECTION ICONS
// =============================================================================

/// Modal Header Emblem: Delegates to [SacredTempleIcon] so the Sacred Temple
/// map pin and the modal header badge share the exact same bespoke vector icon.
class SacredTempleEmblemIcon extends StatelessWidget {
  final double size;

  const SacredTempleEmblemIcon({super.key, this.size = 32.0});

  @override
  Widget build(BuildContext context) {
    return SacredTempleIcon(size: size);
  }
}

/// Wing 1 — `+1 Max HP`: Large faceted crimson-ruby crystal heart framed
/// inside a thick beveled golden heart bezel with a floating 3D golden oval halo.
class VitalityHeartIcon extends StatelessWidget {
  final double size;

  const VitalityHeartIcon({super.key, this.size = 46.0});

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(size: size, painter: const _VitalityHeartPainter());
  }
}

class _VitalityHeartPainter extends CustomPainter {
  const _VitalityHeartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, baseWidth: 1.25);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Floating 3D golden oval halo hovering right above heart's cleft
    final haloOuter = Rect.fromCenter(
      center: Offset(s * 0.50, s * 0.12),
      width: s * 0.52,
      height: s * 0.145,
    );
    final haloInner = Rect.fromCenter(
      center: Offset(s * 0.50, s * 0.12),
      width: s * 0.30,
      height: s * 0.050,
    );
    final haloPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(haloOuter)
      ..addOval(haloInner);
    canvas.drawPath(
      haloPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8E1), Color(0xFFFFD54F), Color(0xFFB27800)],
        ).createShader(haloOuter),
    );
    final crispThinOutline = _outlinePaint(scale, baseWidth: 0.85);
    canvas.drawOval(haloOuter, crispThinOutline);
    canvas.drawOval(haloInner, crispThinOutline);

    // 2. Thick beveled golden heart bezel (y: 0.21..0.92)
    final outerHeart = Path()
      ..moveTo(s * 0.50, s * 0.315)
      ..cubicTo(s * 0.40, s * 0.175, s * 0.115, s * 0.20, s * 0.115, s * 0.455)
      ..cubicTo(s * 0.115, s * 0.68, s * 0.37, s * 0.82, s * 0.50, s * 0.92)
      ..cubicTo(s * 0.63, s * 0.82, s * 0.885, s * 0.68, s * 0.885, s * 0.455)
      ..cubicTo(s * 0.885, s * 0.20, s * 0.60, s * 0.175, s * 0.50, s * 0.315)
      ..close();

    canvas.drawPath(
      outerHeart,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8E1),
            Color(0xFFFFE082),
            Color(0xFFFFB300),
            Color(0xFFB27800),
          ],
          stops: [0.0, 0.32, 0.68, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.115, s * 0.20, s * 0.885, s * 0.92)),
    );
    canvas.drawPath(outerHeart, outline);

    // 3. Faceted crimson-ruby crystal heart inset inside the golden bezel
    final innerHeart = Path()
      ..moveTo(s * 0.50, s * 0.388)
      ..cubicTo(s * 0.415, s * 0.26, s * 0.195, s * 0.28, s * 0.195, s * 0.47)
      ..cubicTo(s * 0.195, s * 0.65, s * 0.40, s * 0.76, s * 0.50, s * 0.845)
      ..cubicTo(s * 0.60, s * 0.76, s * 0.805, s * 0.65, s * 0.805, s * 0.47)
      ..cubicTo(s * 0.805, s * 0.28, s * 0.585, s * 0.26, s * 0.50, s * 0.388)
      ..close();

    canvas.save();
    canvas.clipPath(innerHeart);

    // Base rich ruby gradient
    canvas.drawRect(
      Rect.fromLTRB(s * 0.18, s * 0.24, s * 0.82, s * 0.86),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF1744), Color(0xFFD50000), Color(0xFF8E0000)],
        ).createShader(Rect.fromLTRB(s * 0.18, s * 0.24, s * 0.82, s * 0.86)),
    );

    // Geometric ruby crystal facets converging around central table facet
    final cleft = Offset(s * 0.50, s * 0.375);
    final tip = Offset(s * 0.50, s * 0.855);
    final leftTop = Offset(s * 0.29, s * 0.26);
    final leftSide = Offset(s * 0.18, s * 0.49);
    final leftBot = Offset(s * 0.32, s * 0.73);
    final rightTop = Offset(s * 0.71, s * 0.26);
    final rightSide = Offset(s * 0.82, s * 0.49);
    final rightBot = Offset(s * 0.68, s * 0.73);

    final tableTop = Offset(s * 0.50, s * 0.47);
    final tableTL = Offset(s * 0.35, s * 0.40);
    final tableTR = Offset(s * 0.65, s * 0.40);
    final tableLeft = Offset(s * 0.32, s * 0.56);
    final tableRight = Offset(s * 0.68, s * 0.56);
    final tableBot = Offset(s * 0.50, s * 0.71);

    void drawFacet(List<Offset> pts, Color color) {
      final p = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) {
        p.lineTo(pts[i].dx, pts[i].dy);
      }
      p.close();
      canvas.drawPath(p, Paint()..color = color);
    }

    // Outer bevel facets (top-left brightest -> bottom-right deepest shadow)
    drawFacet([leftTop, cleft, tableTL, leftSide], const Color(0xFFFF5252));
    drawFacet([leftTop, tableTL, leftSide], const Color(0xFFFF8A80));
    drawFacet([cleft, tableTR, tableTop, tableTL], const Color(0xFFFF1744));
    drawFacet([cleft, rightTop, tableTR], const Color(0xFFE53935));
    drawFacet([rightTop, rightSide, tableRight, tableTR], const Color(0xFFC62828));
    drawFacet([leftSide, tableLeft, tableBot, leftBot], const Color(0xFFD50000));
    drawFacet([leftBot, tableBot, tip], const Color(0xFF9E0000));
    drawFacet([rightSide, rightBot, tableBot, tableRight], const Color(0xFF8E0000));
    drawFacet([rightBot, tip, tableBot], const Color(0xFF5E0000));

    // Inner central heart/kite table facet
    final tableFacet = Path()
      ..moveTo(tableTop.dx, tableTop.dy)
      ..lineTo(tableTR.dx, tableTR.dy)
      ..lineTo(tableRight.dx, tableRight.dy)
      ..lineTo(tableBot.dx, tableBot.dy)
      ..lineTo(tableLeft.dx, tableLeft.dy)
      ..lineTo(tableTL.dx, tableTL.dy)
      ..close();
    canvas.drawPath(
      tableFacet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF4081), Color(0xFFFF1744), Color(0xFFB71C1C)],
        ).createShader(Rect.fromLTRB(s * 0.32, s * 0.40, s * 0.68, s * 0.71)),
    );

    // Crisp translucent rose-white facet ridge lines
    final ridgePaint = Paint()
      ..color = const Color(0xFFFFCDD2).withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.65, 0.72 * scale)
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(tableFacet, ridgePaint);
    canvas.drawLine(cleft, tableTop, ridgePaint);
    canvas.drawLine(leftTop, tableTL, ridgePaint);
    canvas.drawLine(leftSide, tableLeft, ridgePaint);
    canvas.drawLine(rightTop, tableTR, ridgePaint);
    canvas.drawLine(rightSide, tableRight, ridgePaint);
    canvas.drawLine(tableBot, tip, ridgePaint);

    // Specular pink-white gleam on upper-left lobe
    canvas.save();
    canvas.translate(s * 0.305, s * 0.365);
    canvas.rotate(-0.45);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: s * 0.11, height: s * 0.048),
      Paint()..color = Colors.white.withValues(alpha: 0.90),
    );
    canvas.restore();
    canvas.drawCircle(
      Offset(s * 0.245, s * 0.435),
      s * 0.022,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    canvas.restore();
    canvas.drawPath(innerHeart, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_VitalityHeartPainter oldDelegate) => false;
}

/// Wing 1 — `+1 Max Mana Pool`: Large faceted sapphire-cyan teardrop crystal
/// framed inside a thick beveled golden teardrop bezel.
class ManaDropIcon extends StatelessWidget {
  final double size;

  const ManaDropIcon({super.key, this.size = 46.0});

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(size: size, painter: const _ManaDropPainter());
  }
}

class _ManaDropPainter extends CustomPainter {
  const _ManaDropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, baseWidth: 1.25);

    canvas.save();
    canvas.translate(ox, oy);

    Path buildDrop(double pad) {
      final t = pad;
      return Path()
        ..moveTo(s * 0.50, s * (0.085 + t * 1.15))
        ..cubicTo(
          s * (0.68 - t * 0.4),
          s * 0.34,
          s * (0.85 - t),
          s * 0.51,
          s * (0.85 - t),
          s * 0.625,
        )
        ..arcToPoint(
          Offset(s * (0.15 + t), s * 0.625),
          radius: Radius.circular(s * (0.35 - t)),
          clockwise: true,
        )
        ..cubicTo(
          s * (0.15 + t),
          s * 0.51,
          s * (0.32 + t * 0.4),
          s * 0.34,
          s * 0.50,
          s * (0.085 + t * 1.15),
        )
        ..close();
    }

    // 1. Thick beveled golden teardrop bezel (y: 0.085..0.925)
    final outerDrop = buildDrop(0.0);
    canvas.drawPath(
      outerDrop,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8E1),
            Color(0xFFFFE082),
            Color(0xFFFFB300),
            Color(0xFFB27800),
          ],
          stops: [0.0, 0.32, 0.68, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.15, s * 0.085, s * 0.85, s * 0.925)),
    );
    canvas.drawPath(outerDrop, outline);

    // 2. Multi-faceted sapphire-cyan teardrop crystal inside
    final innerDrop = buildDrop(0.08);
    canvas.save();
    canvas.clipPath(innerDrop);

    canvas.drawRect(
      Rect.fromLTRB(s * 0.20, s * 0.15, s * 0.80, s * 0.90),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF80F3FF), Color(0xFF00B0FF), Color(0xFF01579B)],
        ).createShader(Rect.fromLTRB(s * 0.20, s * 0.15, s * 0.80, s * 0.90)),
    );

    final topTip = Offset(s * 0.50, s * 0.16);
    final midLeft = Offset(s * 0.21, s * 0.56);
    final midRight = Offset(s * 0.79, s * 0.56);
    final botLeft = Offset(s * 0.29, s * 0.80);
    final botRight = Offset(s * 0.71, s * 0.80);
    final botTip = Offset(s * 0.50, s * 0.87);

    final tableTop = Offset(s * 0.50, s * 0.35);
    final tableLeft = Offset(s * 0.34, s * 0.56);
    final tableRight = Offset(s * 0.66, s * 0.56);
    final tableBot = Offset(s * 0.50, s * 0.74);

    void drawFacet(List<Offset> pts, Color color) {
      final p = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) {
        p.lineTo(pts[i].dx, pts[i].dy);
      }
      p.close();
      canvas.drawPath(p, Paint()..color = color);
    }

    drawFacet([topTip, tableTop, tableLeft, midLeft], const Color(0xFFB2F5FF));
    drawFacet([topTip, midRight, tableRight, tableTop], const Color(0xFF40C4FF));
    drawFacet([midLeft, tableLeft, tableBot, botLeft], const Color(0xFF00B0FF));
    drawFacet([midRight, botRight, tableBot, tableRight], const Color(0xFF0277BD));
    drawFacet([botLeft, tableBot, botTip], const Color(0xFF026AA7));
    drawFacet([botRight, botTip, tableBot], const Color(0xFF014377));

    final tableFacet = Path()
      ..moveTo(tableTop.dx, tableTop.dy)
      ..lineTo(tableRight.dx, tableRight.dy)
      ..lineTo(tableBot.dx, tableBot.dy)
      ..lineTo(tableLeft.dx, tableLeft.dy)
      ..close();
    canvas.drawPath(
      tableFacet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF80F3FF), Color(0xFF00E5FF), Color(0xFF0288D1)],
        ).createShader(Rect.fromLTRB(s * 0.34, s * 0.35, s * 0.66, s * 0.74)),
    );

    final ridgePaint = Paint()
      ..color = const Color(0xFFE0F7FA).withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.65, 0.72 * scale)
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(tableFacet, ridgePaint);
    canvas.drawLine(topTip, tableTop, ridgePaint);
    canvas.drawLine(midLeft, tableLeft, ridgePaint);
    canvas.drawLine(midRight, tableRight, ridgePaint);
    canvas.drawLine(tableBot, botTip, ridgePaint);

    // Bright white crystal specular highlight on upper-left shoulder
    canvas.save();
    canvas.translate(s * 0.365, s * 0.44);
    canvas.rotate(-0.68);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: s * 0.125, height: s * 0.042),
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas.restore();
    canvas.drawCircle(
      Offset(s * 0.30, s * 0.565),
      s * 0.023,
      Paint()..color = Colors.white.withValues(alpha: 0.88),
    );

    canvas.restore();
    canvas.drawPath(innerDrop, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ManaDropPainter oldDelegate) => false;
}

/// Wing 2 — `Altar of Offerings`: Bold beveled golden-and-cyan star relic icon.
class SacredRelicIcon extends StatelessWidget {
  final double size;

  const SacredRelicIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(size: size, painter: const _SacredRelicPainter());
  }
}

class _SacredRelicPainter extends CustomPainter {
  const _SacredRelicPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, baseWidth: 1.25);

    canvas.save();
    canvas.translate(ox, oy);

    final c = Offset(s * 0.50, s * 0.50);

    // 1. Beveled golden halo ring behind star
    final outerRing = Rect.fromCircle(center: c, radius: s * 0.36);
    final innerRing = Rect.fromCircle(center: c, radius: s * 0.25);
    final ringPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(outerRing)
      ..addOval(innerRing);
    canvas.drawPath(
      ringPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3B0), Color(0xFFFFB300), Color(0xFF9A6500)],
        ).createShader(outerRing),
    );
    canvas.drawOval(outerRing, outline);
    canvas.drawOval(innerRing, outline);

    // 2. Sculpted 4-point golden star burst with faceted split shading
    final star = Path();
    final outerPts = <Offset>[];
    final innerPts = <Offset>[];
    for (int i = 0; i < 8; i++) {
      final r = i.isEven ? s * 0.45 : s * 0.16;
      final a = -math.pi / 2 + i * (math.pi / 4);
      final pt = c + Offset(math.cos(a), math.sin(a)) * r;
      if (i.isEven) {
        outerPts.add(pt);
      } else {
        innerPts.add(pt);
      }
      if (i == 0) {
        star.moveTo(pt.dx, pt.dy);
      } else {
        star.lineTo(pt.dx, pt.dy);
      }
    }
    star.close();
    canvas.drawPath(
      star,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3B0), Color(0xFFFFD54F), Color(0xFFB27800)],
        ).createShader(Rect.fromCircle(center: c, radius: s * 0.45)),
    );

    // Shadow facets on the right/bottom half of each star arm
    for (int i = 0; i < 4; i++) {
      final tip = outerPts[i];
      final nextIn = innerPts[i];
      final facet = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(nextIn.dx, nextIn.dy)
        ..close();
      canvas.drawPath(
        facet,
        Paint()..color = const Color(0xFF9A6500).withValues(alpha: 0.45),
      );
    }
    canvas.drawPath(star, outline);

    // 3. Multi-faceted cyan crystal core diamond
    final coreR = s * 0.16;
    final core = Path()
      ..moveTo(c.dx, c.dy - coreR)
      ..lineTo(c.dx + coreR, c.dy)
      ..lineTo(c.dx, c.dy + coreR)
      ..lineTo(c.dx - coreR, c.dy)
      ..close();
    canvas.drawPath(
      core,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB2F5FF), Color(0xFF00E5FF), Color(0xFF01579B)],
        ).createShader(Rect.fromCircle(center: c, radius: coreR)),
    );
    canvas.drawCircle(
      c + Offset(-coreR * 0.28, -coreR * 0.28),
      coreR * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawPath(core, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SacredRelicPainter oldDelegate) => false;
}

/// Wing 3 — `Holy Transformation (3 → 1)`: Compact divine miracle emblem
/// featuring a radiant golden halo/orb with a 4-pointed star sparkle and
/// a graceful curved golden conversion arc.
class TransformationMiracleIcon extends StatelessWidget {
  final double size;

  const TransformationMiracleIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: const _TransformationMiraclePainter(),
    );
  }
}

class _TransformationMiraclePainter extends CustomPainter {
  const _TransformationMiraclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, baseWidth: 1.2);
    final thinOutline = _outlinePaint(scale, baseWidth: 0.9);

    canvas.save();
    canvas.translate(ox, oy);

    final c = Offset(s * 0.50, s * 0.50);
    final outerR = s * 0.44;
    final innerR = s * 0.34;

    // 1. Deep celestial sanctuary orb core for crisp contrast
    canvas.drawCircle(
      c,
      innerR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.25, -0.25),
          colors: [Color(0xFF2C5282), Color(0xFF1A365D), Color(0xFF0F172A)],
        ).createShader(Rect.fromCircle(center: c, radius: innerR)),
    );

    // 2. Radiant beveled golden halo rim
    final haloPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: c, radius: outerR))
      ..addOval(Rect.fromCircle(center: c, radius: innerR));
    canvas.drawPath(
      haloPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8E1), Color(0xFFFFD54F), Color(0xFFB27800)],
        ).createShader(Rect.fromCircle(center: c, radius: outerR)),
    );
    canvas.drawCircle(c, outerR, outline);
    canvas.drawCircle(c, innerR, outline);

    // 3. Curved golden conversion arc sweeping along the lower-right rim
    final arcPath = Path();
    const steps = 14;
    const startAngle = math.pi * 0.78;
    const endAngle = -math.pi * 0.14; // sweeps counter-clockwise up to right
    final arcRIn = s * 0.205;
    final arcROut = s * 0.295;
    final arcRMid = (arcRIn + arcROut) * 0.5;

    Offset polar(double a, double r) =>
        c + Offset(math.cos(a), math.sin(a)) * r;

    final tail = polar(startAngle, arcRMid);
    arcPath.moveTo(tail.dx, tail.dy);
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final a = startAngle + (endAngle - startAngle) * t;
      final swell = math.sin(t * math.pi * 0.72);
      final r = arcRMid + (arcROut - arcRMid) * (0.25 + 0.75 * swell);
      final pt = polar(a, r);
      arcPath.lineTo(pt.dx, pt.dy);
    }
    final headOuter = polar(endAngle + 0.04, s * 0.315);
    final headTip = polar(endAngle - 0.16, arcRMid);
    final headInner = polar(endAngle + 0.04, s * 0.175);
    arcPath.lineTo(headOuter.dx, headOuter.dy);
    arcPath.lineTo(headTip.dx, headTip.dy);
    arcPath.lineTo(headInner.dx, headInner.dy);
    for (int i = steps; i >= 1; i--) {
      final t = i / steps;
      final a = startAngle + (endAngle - startAngle) * t;
      final swell = math.sin(t * math.pi * 0.72);
      final r = arcRMid - (arcRMid - arcRIn) * (0.25 + 0.75 * swell);
      final pt = polar(a, r);
      arcPath.lineTo(pt.dx, pt.dy);
    }
    arcPath.close();

    canvas.drawPath(
      arcPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFFFFCA28), Color(0xFFFFF8E1)],
        ).createShader(Rect.fromCircle(center: c, radius: arcROut)),
    );
    canvas.drawPath(arcPath, thinOutline);

    // 4. Radiant 4-pointed divine miracle star sparkle inside the orb
    final sc = Offset(s * 0.435, s * 0.42);
    final rStar = s * 0.21;
    final star = Path()
      ..moveTo(sc.dx, sc.dy - rStar)
      ..cubicTo(
        sc.dx + s * 0.011,
        sc.dy - s * 0.052,
        sc.dx + s * 0.052,
        sc.dy - s * 0.011,
        sc.dx + rStar,
        sc.dy,
      )
      ..cubicTo(
        sc.dx + s * 0.052,
        sc.dy + s * 0.011,
        sc.dx + s * 0.011,
        sc.dy + s * 0.052,
        sc.dx,
        sc.dy + rStar,
      )
      ..cubicTo(
        sc.dx - s * 0.011,
        sc.dy + s * 0.052,
        sc.dx - s * 0.052,
        sc.dy + s * 0.011,
        sc.dx - rStar,
        sc.dy,
      )
      ..cubicTo(
        sc.dx - s * 0.052,
        sc.dy - s * 0.011,
        sc.dx - s * 0.011,
        sc.dy - s * 0.052,
        sc.dx,
        sc.dy - rStar,
      )
      ..close();

    canvas.drawPath(
      star,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF8E1), Color(0xFF80F3FF)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: sc, radius: rStar)),
    );
    canvas.drawPath(star, thinOutline);

    // Tiny companion miracle gleam
    canvas.drawCircle(
      Offset(s * 0.65, s * 0.28),
      s * 0.028,
      Paint()..color = const Color(0xFFFFF8E1),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TransformationMiraclePainter oldDelegate) => false;
}

/// Wing 4 — `All-Element Orb Bundles`: Bold golden-trimmed sacred reliquary
/// chest overflowing with richly shaded elemental orbs.
class ReliquaryBundleIcon extends StatelessWidget {
  final double size;

  const ReliquaryBundleIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: const _ReliquaryBundlePainter(),
    );
  }
}

class _ReliquaryBundlePainter extends CustomPainter {
  const _ReliquaryBundlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, baseWidth: 1.25);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Overflowing richly shaded elemental orbs peeking from top
    final orbs = [
      (
        Offset(s * 0.30, s * 0.29),
        const [Color(0xFFFFCCBC), Color(0xFFFF5722), Color(0xFFBF360C)],
      ),
      (
        Offset(s * 0.70, s * 0.29),
        const [Color(0xFFC8E6C9), Color(0xFF4CAF50), Color(0xFF1B5E20)],
      ),
      (
        Offset(s * 0.50, s * 0.22),
        const [Color(0xFFB2F5FF), Color(0xFF00E5FF), Color(0xFF01579B)],
      ),
    ];
    for (final orb in orbs) {
      final r = s * 0.135;
      canvas.drawCircle(
        orb.$1,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            colors: orb.$2,
          ).createShader(Rect.fromCircle(center: orb.$1, radius: r)),
      );
      canvas.drawCircle(
        orb.$1 + Offset(-r * 0.3, -r * 0.3),
        r * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
      canvas.drawCircle(orb.$1, r, outline);
    }

    // 2. Sculpted wooden & leather reliquary body (y: 0.39..0.89)
    final vesselPath = Path()
      ..moveTo(s * 0.14, s * 0.40)
      ..lineTo(s * 0.86, s * 0.40)
      ..lineTo(s * 0.80, s * 0.885)
      ..lineTo(s * 0.20, s * 0.885)
      ..close();
    canvas.drawPath(
      vesselPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB87333), Color(0xFF8D5524), Color(0xFF4E2A0E)],
        ).createShader(Rect.fromLTRB(s * 0.14, s * 0.40, s * 0.86, s * 0.885)),
    );
    canvas.drawPath(vesselPath, outline);

    // 3. Vertical beveled golden straps
    for (final sx in [s * 0.29, s * 0.71]) {
      final strap = Rect.fromCenter(
        center: Offset(sx, s * 0.66),
        width: s * 0.085,
        height: s * 0.44,
      );
      canvas.drawRect(
        strap,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFF3B0), Color(0xFFFFB300), Color(0xFF9A6500)],
          ).createShader(strap),
      );
      canvas.drawRect(strap, outline);
    }

    // 4. Beveled golden top rim & center lock clasp
    final rim = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.11, s * 0.34, s * 0.89, s * 0.455),
      Radius.circular(s * 0.035),
    );
    canvas.drawRRect(
      rim,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3B0), Color(0xFFFFD54F), Color(0xFF9A6500)],
        ).createShader(rim.outerRect),
    );
    canvas.drawRRect(rim, outline);

    final clasp = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.56),
        width: s * 0.16,
        height: s * 0.18,
      ),
      Radius.circular(s * 0.035),
    );
    canvas.drawRRect(
      clasp,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3B0), Color(0xFFFFB300), Color(0xFF9A6500)],
        ).createShader(clasp.outerRect),
    );
    canvas.drawRRect(clasp, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ReliquaryBundlePainter oldDelegate) => false;
}

/// Wing 4 — `Single-Element Bulk Packs`: Bold multi-faceted elemental crystal
/// spire seated in a beveled golden collar.
class ElementalCrystalIcon extends StatelessWidget {
  final double size;

  const ElementalCrystalIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: const _ElementalCrystalPainter(),
    );
  }
}

class _ElementalCrystalPainter extends CustomPainter {
  const _ElementalCrystalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, baseWidth: 1.25);

    canvas.save();
    canvas.translate(ox, oy);

    final top = Offset(s * 0.50, s * 0.08);
    final ul = Offset(s * 0.22, s * 0.36);
    final ur = Offset(s * 0.78, s * 0.36);
    final bl = Offset(s * 0.27, s * 0.77);
    final br = Offset(s * 0.73, s * 0.77);
    final midTop = Offset(s * 0.50, s * 0.43);
    final midBot = Offset(s * 0.50, s * 0.77);

    final full = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(ur.dx, ur.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..lineTo(ul.dx, ul.dy)
      ..close();

    void drawFacet(List<Offset> pts, Color color) {
      final p = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) {
        p.lineTo(pts[i].dx, pts[i].dy);
      }
      p.close();
      canvas.drawPath(p, Paint()..color = color);
    }

    drawFacet([top, midTop, ul], const Color(0xFFB2F5FF));
    drawFacet([top, ur, midTop], const Color(0xFF40C4FF));
    drawFacet([ul, midTop, midBot, bl], const Color(0xFF00B0FF));
    drawFacet([midTop, ur, br, midBot], const Color(0xFF0277BD));

    // Central faceted prism table
    drawFacet(
      [
        Offset(s * 0.50, s * 0.25),
        Offset(s * 0.60, s * 0.43),
        Offset(s * 0.56, s * 0.70),
        Offset(s * 0.44, s * 0.70),
        Offset(s * 0.40, s * 0.43),
      ],
      const Color(0xFF80F3FF).withValues(alpha: 0.48),
    );

    final ridgePaint = Paint()
      ..color = const Color(0xFFE0F7FA).withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.65, 0.78 * scale);
    canvas.drawLine(ul, midTop, ridgePaint);
    canvas.drawLine(ur, midTop, ridgePaint);
    canvas.drawLine(top, midBot, ridgePaint);
    canvas.drawPath(full, outline);

    // Specular gleam
    canvas.drawCircle(
      Offset(s * 0.42, s * 0.30),
      s * 0.032,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    // Beveled golden base collar
    final collar = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.21, s * 0.74, s * 0.79, s * 0.905),
      Radius.circular(s * 0.04),
    );
    canvas.drawRRect(
      collar,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3B0), Color(0xFFFFD54F), Color(0xFF9A6500)],
        ).createShader(collar.outerRect),
    );
    canvas.drawRRect(collar, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ElementalCrystalPainter oldDelegate) => false;
}

/// Wing 5 — `Meditation for Free Orbs`: Sculpted golden radiant sun-halo
/// medallion with beveled sunbeams and faceted cyan core gem.
class MeditationHaloIcon extends StatelessWidget {
  final double size;

  const MeditationHaloIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: const _MeditationHaloPainter(),
    );
  }
}

class _MeditationHaloPainter extends CustomPainter {
  const _MeditationHaloPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, baseWidth: 1.2);

    canvas.save();
    canvas.translate(ox, oy);

    final c = Offset(s * 0.50, s * 0.50);

    // 1. 8 sculpted golden sunbeam spikes (filled & outlined)
    final rayOutline = _outlinePaint(scale, baseWidth: 0.85);
    for (int i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * (math.pi / 4);
      final outerR = i.isEven ? s * 0.46 : s * 0.40;
      final baseR = s * 0.23;
      final halfSpan = i.isEven ? 0.25 : 0.20;
      final ray = Path()
        ..moveTo(c.dx + math.cos(a) * outerR, c.dy + math.sin(a) * outerR)
        ..lineTo(
          c.dx + math.cos(a + halfSpan) * baseR,
          c.dy + math.sin(a + halfSpan) * baseR,
        )
        ..lineTo(
          c.dx + math.cos(a - halfSpan) * baseR,
          c.dy + math.sin(a - halfSpan) * baseR,
        )
        ..close();
      canvas.drawPath(
        ray,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8E1), Color(0xFFFFD54F), Color(0xFFB27800)],
          ).createShader(Rect.fromCircle(center: c, radius: outerR)),
      );
      canvas.drawPath(ray, rayOutline);
    }

    // 2. Sculpted golden sun disc
    canvas.drawCircle(
      c,
      s * 0.25,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.30, -0.30),
          colors: [Color(0xFFFFF8E1), Color(0xFFFFD54F), Color(0xFFB27800)],
        ).createShader(Rect.fromCircle(center: c, radius: s * 0.25)),
    );
    canvas.drawCircle(c, s * 0.25, outline);

    // 3. Faceted cyan meditation core
    final coreR = s * 0.115;
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.35),
          colors: [Color(0xFFB2F5FF), Color(0xFF00E5FF), Color(0xFF0277BD)],
        ).createShader(Rect.fromCircle(center: c, radius: coreR)),
    );
    canvas.drawCircle(
      c + Offset(-coreR * 0.3, -coreR * 0.3),
      coreR * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(c, coreR, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MeditationHaloPainter oldDelegate) => false;
}

/// Wing 5 — `Pre-Battle Sacred Blessings`: Bold winged golden-and-ivory
/// heater shield with layered sculpted feathers and raised sacred cross.
class SacredBlessingIcon extends StatelessWidget {
  final double size;

  const SacredBlessingIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: const _SacredBlessingPainter(),
    );
  }
}

class _SacredBlessingPainter extends CustomPainter {
  const _SacredBlessingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, baseWidth: 1.25);
    final detail = _detailPaint(scale, alpha: 0.72);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Symmetrical layered ivory-gold angel wings flanking the shield
    for (final isLeft in [true, false]) {
      final sign = isLeft ? -1.0 : 1.0;
      double px(double d) => s * (0.50 + sign * d);

      final wing = Path()
        ..moveTo(px(0.18), s * 0.34)
        ..cubicTo(px(0.45), s * 0.17, px(0.47), s * 0.34, px(0.39), s * 0.43)
        ..cubicTo(px(0.45), s * 0.45, px(0.41), s * 0.55, px(0.32), s * 0.57)
        ..cubicTo(px(0.36), s * 0.61, px(0.28), s * 0.67, px(0.19), s * 0.65)
        ..close();

      canvas.drawPath(
        wing,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isLeft
                ? const [Color(0xFFFFFFFF), Color(0xFFECEFF1), Color(0xFFB0BEC5)]
                : const [Color(0xFFECEFF1), Color(0xFFCFD8DC), Color(0xFF90A4AE)],
          ).createShader(Rect.fromLTRB(s * 0.04, s * 0.17, s * 0.96, s * 0.68)),
      );
      canvas.drawPath(wing, outline);
      canvas.drawLine(Offset(px(0.22), s * 0.43), Offset(px(0.38), s * 0.43), detail);
      canvas.drawLine(Offset(px(0.21), s * 0.55), Offset(px(0.32), s * 0.57), detail);
    }

    // 2. Beveled golden outer heater shield
    final outerShield = Path()
      ..moveTo(s * 0.50, s * 0.14)
      ..lineTo(s * 0.77, s * 0.24)
      ..cubicTo(s * 0.77, s * 0.58, s * 0.65, s * 0.80, s * 0.50, s * 0.90)
      ..cubicTo(s * 0.35, s * 0.80, s * 0.23, s * 0.58, s * 0.23, s * 0.24)
      ..close();
    canvas.drawPath(
      outerShield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3B0), Color(0xFFFFD54F), Color(0xFF9A6500)],
        ).createShader(Rect.fromLTRB(s * 0.23, s * 0.14, s * 0.77, s * 0.90)),
    );
    canvas.drawPath(outerShield, outline);

    // 3. Rich crimson-gold inner shield field
    final innerShield = Path()
      ..moveTo(s * 0.50, s * 0.21)
      ..lineTo(s * 0.705, s * 0.285)
      ..cubicTo(s * 0.705, s * 0.555, s * 0.61, s * 0.735, s * 0.50, s * 0.82)
      ..cubicTo(s * 0.39, s * 0.735, s * 0.295, s * 0.555, s * 0.295, s * 0.285)
      ..close();
    canvas.drawPath(
      innerShield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEF5350), Color(0xFFC62828), Color(0xFF7F0000)],
        ).createShader(Rect.fromLTRB(s * 0.295, s * 0.21, s * 0.705, s * 0.82)),
    );
    canvas.drawPath(innerShield, outline);

    // 4. Sculpted golden-ivory sacred cross inside shield
    final crossPath = Path()
      ..moveTo(s * 0.46, s * 0.31)
      ..lineTo(s * 0.54, s * 0.31)
      ..lineTo(s * 0.54, s * 0.44)
      ..lineTo(s * 0.64, s * 0.44)
      ..lineTo(s * 0.64, s * 0.52)
      ..lineTo(s * 0.54, s * 0.52)
      ..lineTo(s * 0.54, s * 0.70)
      ..lineTo(s * 0.46, s * 0.70)
      ..lineTo(s * 0.46, s * 0.52)
      ..lineTo(s * 0.36, s * 0.52)
      ..lineTo(s * 0.36, s * 0.44)
      ..lineTo(s * 0.46, s * 0.44)
      ..close();
    canvas.drawPath(
      crossPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFDF7), Color(0xFFFFE082)],
        ).createShader(Rect.fromLTRB(s * 0.36, s * 0.31, s * 0.64, s * 0.70)),
    );
    canvas.drawPath(crossPath, detail);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SacredBlessingPainter oldDelegate) => false;
}

/// Wing 5 — `Vow of Silence — Remove Ads`: Minimalist "Shh" silence gesture
/// featuring stylized warm rose-terracotta lips behind a centrally raised
/// vertical index finger, outlined in `#263238` with golden silence sparkles
/// and muted-wave accents when active.
class VowOfSilenceIcon extends StatelessWidget {
  final double size;
  final bool isActive;
  final bool isOnGoldBackground;

  const VowOfSilenceIcon({
    super.key,
    this.size = 28.0,
    this.isActive = true,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: _VowOfSilencePainter(
        isActive: isActive,
        isOnGoldBackground: isOnGoldBackground,
      ),
    );
  }
}

class _VowOfSilencePainter extends CustomPainter {
  final bool isActive;
  final bool isOnGoldBackground;

  const _VowOfSilencePainter({
    required this.isActive,
    required this.isOnGoldBackground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;

    const charcoalOutline = Color(0xFF263238);
    final outline = Paint()
      ..color = charcoalOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.85, 1.15 * scale)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final detail = Paint()
      ..color = charcoalOutline.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.60, 0.78 * scale)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Warm rose-terracotta / muted bronze lips palette
    final lipLight = isActive
        ? const Color(0xFFD98872)
        : const Color(0xFFB38B7D);
    final lipMid = isActive
        ? const Color(0xFFB8654F)
        : const Color(0xFF8F6A5E);
    final lipDark = isActive
        ? const Color(0xFF8C4636)
        : const Color(0xFF6B4C42);

    // Finger warm ivory-gold when active, muted slate-ivory when inactive
    final fingerHighlight = isActive
        ? (isOnGoldBackground ? const Color(0xFFFFF8E1) : const Color(0xFFFFF0D4))
        : const Color(0xFFECEFF1);
    final fingerMid = isActive
        ? (isOnGoldBackground ? const Color(0xFFFFE0B2) : const Color(0xFFFFE0B2))
        : const Color(0xFFCFD8DC);
    final fingerShadow = isActive
        ? (isOnGoldBackground ? const Color(0xFFD7A05B) : const Color(0xFFFFD54F))
        : const Color(0xFF90A4AE);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Stylized gently curved lips / mouth behind the finger (x: 0.22..0.78, y: 0.53..0.74)
    final upperLip = Path()
      ..moveTo(s * 0.22, s * 0.625)
      ..cubicTo(s * 0.30, s * 0.555, s * 0.41, s * 0.535, s * 0.50, s * 0.570)
      ..cubicTo(s * 0.59, s * 0.535, s * 0.70, s * 0.555, s * 0.78, s * 0.625)
      ..quadraticBezierTo(s * 0.50, s * 0.648, s * 0.22, s * 0.625)
      ..close();
    canvas.drawPath(
      upperLip,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lipLight, lipMid],
        ).createShader(Rect.fromLTRB(s * 0.22, s * 0.53, s * 0.78, s * 0.65)),
    );
    canvas.drawPath(upperLip, outline);

    final lowerLip = Path()
      ..moveTo(s * 0.24, s * 0.628)
      ..quadraticBezierTo(s * 0.50, s * 0.646, s * 0.76, s * 0.628)
      ..cubicTo(s * 0.70, s * 0.730, s * 0.59, s * 0.750, s * 0.50, s * 0.750)
      ..cubicTo(s * 0.41, s * 0.750, s * 0.30, s * 0.730, s * 0.24, s * 0.628)
      ..close();
    canvas.drawPath(
      lowerLip,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lipMid, lipDark],
        ).createShader(Rect.fromLTRB(s * 0.24, s * 0.62, s * 0.76, s * 0.75)),
    );
    canvas.drawPath(lowerLip, outline);

    // Subtle lip parting seam
    final lipLine = Path()
      ..moveTo(s * 0.25, s * 0.626)
      ..quadraticBezierTo(s * 0.50, s * 0.645, s * 0.75, s * 0.626);
    canvas.drawPath(lipLine, detail);

    // 2. Subtle golden silence sparkles & muted-wave accents flanking the finger
    if (isActive) {
      final wavePaint = Paint()
        ..color = isOnGoldBackground
            ? charcoalOutline.withValues(alpha: 0.70)
            : const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.9, 1.15 * scale)
        ..strokeCap = StrokeCap.round;
      final waveOutline = Paint()
        ..color = charcoalOutline.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, 1.9 * scale)
        ..strokeCap = StrokeCap.round;

      // Left muted-wave arc
      final leftWave = Path()
        ..addArc(
          Rect.fromCenter(
            center: Offset(s * 0.35, s * 0.36),
            width: s * 0.30,
            height: s * 0.28,
          ),
          math.pi * 0.74,
          math.pi * 0.46,
        );
      // Right muted-wave arc
      final rightWave = Path()
        ..addArc(
          Rect.fromCenter(
            center: Offset(s * 0.65, s * 0.36),
            width: s * 0.30,
            height: s * 0.28,
          ),
          -math.pi * 0.20,
          math.pi * 0.46,
        );
      for (final wave in [leftWave, rightWave]) {
        if (!isOnGoldBackground) {
          canvas.drawPath(wave, waveOutline);
        }
        canvas.drawPath(wave, wavePaint);
      }

      // Flanking 4-point golden silence sparkles
      void drawSparkle(Offset center, double r) {
        final star = Path()
          ..moveTo(center.dx, center.dy - r)
          ..quadraticBezierTo(
            center.dx + r * 0.15,
            center.dy - r * 0.15,
            center.dx + r,
            center.dy,
          )
          ..quadraticBezierTo(
            center.dx + r * 0.15,
            center.dy + r * 0.15,
            center.dx,
            center.dy + r,
          )
          ..quadraticBezierTo(
            center.dx - r * 0.15,
            center.dy + r * 0.15,
            center.dx - r,
            center.dy,
          )
          ..quadraticBezierTo(
            center.dx - r * 0.15,
            center.dy - r * 0.15,
            center.dx,
            center.dy - r,
          )
          ..close();
        canvas.drawPath(
          star,
          Paint()
            ..color = isOnGoldBackground
                ? const Color(0xFFFFF8E1)
                : const Color(0xFFFFD54F),
        );
        canvas.drawPath(
          star,
          Paint()
            ..color = charcoalOutline
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.55, 0.70 * scale)
            ..strokeJoin = StrokeJoin.round,
        );
      }

      drawSparkle(Offset(s * 0.20, s * 0.24), s * 0.085);
      drawSparkle(Offset(s * 0.80, s * 0.28), s * 0.075);
    }

    // 3. Vertical index finger raised centrally over the lips (x: 0.415..0.585, y: 0.14..0.89)
    final fingerRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(s * 0.415, s * 0.14, s * 0.585, s * 0.89),
      topLeft: Radius.circular(s * 0.085),
      topRight: Radius.circular(s * 0.085),
      bottomLeft: Radius.circular(s * 0.070),
      bottomRight: Radius.circular(s * 0.070),
    );
    canvas.drawRRect(
      fingerRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [fingerHighlight, fingerMid, fingerShadow],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(fingerRect.outerRect),
    );
    canvas.drawRRect(fingerRect, outline);

    // Subtle fingernail oval at the fingertip
    final nailRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(s * 0.445, s * 0.175, s * 0.555, s * 0.275),
      topLeft: Radius.circular(s * 0.055),
      topRight: Radius.circular(s * 0.055),
      bottomLeft: Radius.circular(s * 0.025),
      bottomRight: Radius.circular(s * 0.025),
    );
    canvas.drawRRect(
      nailRect,
      Paint()..color = Colors.white.withValues(alpha: isActive ? 0.55 : 0.35),
    );
    canvas.drawRRect(nailRect, detail);

    // Subtle knuckle contour lines below the lips
    canvas.drawLine(
      Offset(s * 0.45, s * 0.77),
      Offset(s * 0.55, s * 0.77),
      detail,
    );
    canvas.drawLine(
      Offset(s * 0.455, s * 0.825),
      Offset(s * 0.545, s * 0.825),
      detail,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_VowOfSilencePainter oldDelegate) =>
      oldDelegate.isActive != isActive ||
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Tab 6 — Offertory (Gazofilácio): Sacred Temple Offertory Chest / Tithe Urn
/// rendered in rich gold, warm ivory/marble, and dark graphite outlines
/// (`#263238`), featuring an arched sanctuary front motif and a glowing
/// cyan-gold orb hovering into the top offering slot.
class OffertoryVaultIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const OffertoryVaultIcon({
    super.key,
    this.size = 28.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: _OffertoryVaultPainter(
        isOnGoldBackground: isOnGoldBackground,
      ),
    );
  }
}

class _OffertoryVaultPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _OffertoryVaultPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;

    const graphiteOutline = Color(0xFF263238);
    final outline = Paint()
      ..color = isOnGoldBackground ? const Color(0xFF12181B) : graphiteOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.9, 1.28 * scale)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final detail = Paint()
      ..color = (isOnGoldBackground ? const Color(0xFF12181B) : graphiteOutline)
          .withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.55, 0.85 * scale)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final goldHighlight =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFF3B0);
    final goldLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFFFD54F);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFB300);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFFB27800);

    final marbleLight =
        isOnGoldBackground ? const Color(0xFF607D8B) : const Color(0xFFFFFDF7);
    final marbleMid =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFF3ECE0);
    final marbleDark =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFFC9BBA4);

    final archInterior =
        isOnGoldBackground ? const Color(0xFF141B1F) : const Color(0xFF5D4010);
    final slotDark =
        isOnGoldBackground ? const Color(0xFF0E1417) : const Color(0xFF1F2A30);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Soft radiant halo behind hovering cyan-gold orb (top)
    final orbCenter = Offset(s * 0.50, s * 0.205);
    final orbRadius = s * 0.12;
    canvas.drawCircle(
      orbCenter,
      orbRadius * 1.65,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF4DD0E1).withValues(alpha: 0.45),
            const Color(0xFFFFD54F).withValues(alpha: 0.25),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: orbCenter, radius: orbRadius * 1.65)),
    );

    // 2. Stepped warm ivory/marble temple pedestal base (y: 0.81..0.915)
    final lowerPlinth = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.12, s * 0.845, s * 0.88, s * 0.915),
      Radius.circular(s * 0.025),
    );
    canvas.drawRRect(
      lowerPlinth,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [marbleLight, marbleMid, marbleDark],
        ).createShader(lowerPlinth.outerRect),
    );
    canvas.drawRRect(lowerPlinth, outline);

    final upperBaseTrim = Rect.fromLTRB(s * 0.16, s * 0.795, s * 0.84, s * 0.848);
    canvas.drawRect(
      upperBaseTrim,
      Paint()
        ..shader = LinearGradient(
          colors: [goldLight, goldMid, goldDark],
        ).createShader(upperBaseTrim),
    );
    canvas.drawRect(upperBaseTrim, outline);

    // 3. Sculpted Offertory Vault Chest Body (marble body + gold corner pilasters)
    final chestRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.175, s * 0.44, s * 0.825, s * 0.80),
      Radius.circular(s * 0.03),
    );
    canvas.drawRRect(
      chestRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [marbleLight, marbleMid, marbleDark],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(chestRect.outerRect),
    );
    canvas.drawRRect(chestRect, outline);

    // Left & right burnished gold corner pilasters
    for (final px in [s * 0.175, s * 0.735]) {
      final pilaster = Rect.fromLTRB(px, s * 0.445, px + s * 0.09, s * 0.795);
      canvas.drawRect(
        pilaster,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [goldHighlight, goldMid, goldDark],
          ).createShader(pilaster),
      );
      canvas.drawRect(pilaster, outline);
    }

    // 4. Arched Sanctuary Front Motif centered on chest facade
    final archOuter = Path()
      ..moveTo(s * 0.34, s * 0.795)
      ..lineTo(s * 0.34, s * 0.62)
      ..arcToPoint(
        Offset(s * 0.66, s * 0.62),
        radius: Radius.circular(s * 0.16),
        clockwise: true,
      )
      ..lineTo(s * 0.66, s * 0.795)
      ..close();
    canvas.drawPath(
      archOuter,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [goldHighlight, goldLight, goldDark],
        ).createShader(Rect.fromLTRB(s * 0.34, s * 0.46, s * 0.66, s * 0.795)),
    );
    canvas.drawPath(archOuter, outline);

    final archInner = Path()
      ..moveTo(s * 0.39, s * 0.79)
      ..lineTo(s * 0.39, s * 0.635)
      ..arcToPoint(
        Offset(s * 0.61, s * 0.635),
        radius: Radius.circular(s * 0.11),
        clockwise: true,
      )
      ..lineTo(s * 0.61, s * 0.79)
      ..close();
    canvas.drawPath(archInner, Paint()..color = archInterior);
    canvas.drawPath(archInner, detail);

    // Subtle golden sacred star/emblem inside the recessed sanctuary arch
    final emblemPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, 1.05 * scale)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(s * 0.50, s * 0.58),
      Offset(s * 0.50, s * 0.73),
      emblemPaint,
    );
    canvas.drawLine(
      Offset(s * 0.445, s * 0.635),
      Offset(s * 0.555, s * 0.635),
      emblemPaint,
    );

    // 5. Domed / Beveled Golden Offertory Lid with Top Offering Slot (y: 0.32..0.46)
    final lidPath = Path()
      ..moveTo(s * 0.13, s * 0.455)
      ..lineTo(s * 0.19, s * 0.335)
      ..quadraticBezierTo(s * 0.50, s * 0.295, s * 0.81, s * 0.335)
      ..lineTo(s * 0.87, s * 0.455)
      ..close();
    canvas.drawPath(
      lidPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [goldHighlight, goldLight, goldMid, goldDark],
          stops: const [0.0, 0.30, 0.70, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.13, s * 0.30, s * 0.87, s * 0.455)),
    );
    canvas.drawPath(lidPath, outline);

    // Recessed dark offering slot on top of the lid
    final slotRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.375),
        width: s * 0.28,
        height: s * 0.055,
      ),
      Radius.circular(s * 0.028),
    );
    canvas.drawRRect(slotRect, Paint()..color = slotDark);
    canvas.drawRRect(slotRect, detail);

    // 6. Glowing Cyan-Gold Elemental Orb hovering into the top offering slot
    final orbRect = Rect.fromCircle(center: orbCenter, radius: orbRadius);
    canvas.drawCircle(
      orbCenter,
      orbRadius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.32, -0.35),
          radius: 0.92,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFF80DEEA),
            Color(0xFF26C6DA),
            Color(0xFFFFCA28),
          ],
          stops: [0.0, 0.34, 0.68, 1.0],
        ).createShader(orbRect),
    );
    canvas.drawCircle(orbCenter, orbRadius, outline);

    // Crisp specular highlight crescent on orb
    canvas.drawCircle(
      Offset(orbCenter.dx - orbRadius * 0.32, orbCenter.dy - orbRadius * 0.32),
      orbRadius * 0.26,
      Paint()..color = Colors.white.withValues(alpha: 0.88),
    );

    // Twin golden sparkle accents flanking the hovering orb
    void drawMiniStar(Offset c, double r) {
      final star = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx + r * 0.18, c.dy - r * 0.18, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx + r * 0.18, c.dy + r * 0.18, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - r * 0.18, c.dy + r * 0.18, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - r * 0.18, c.dy - r * 0.18, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(star, Paint()..color = const Color(0xFFFFE082));
      canvas.drawPath(star, detail);
    }

    drawMiniStar(Offset(s * 0.25, s * 0.20), s * 0.065);
    drawMiniStar(Offset(s * 0.76, s * 0.18), s * 0.055);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_OffertoryVaultPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Compact Sacred Temple vector icon for the 10% Tithe Blessing (`2x` Speed)
/// card header: golden sanctuary offering bowl radiating ascending golden
/// acceleration chevrons and a radiant blessing star.
class TitheBlessingIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const TitheBlessingIcon({
    super.key,
    this.size = 28.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: _TitheBlessingPainter(
        isOnGoldBackground: isOnGoldBackground,
      ),
    );
  }
}

class _TitheBlessingPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _TitheBlessingPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;

    const graphiteOutline = Color(0xFF263238);
    final outline = Paint()
      ..color = isOnGoldBackground ? const Color(0xFF12181B) : graphiteOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.85, 1.22 * scale)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final goldHighlight =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFF8D6);
    final goldLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFFFD54F);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFA000);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFFB26A00);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Radiant warm aura behind upper blessing chevrons
    final auraCenter = Offset(s * 0.50, s * 0.38);
    canvas.drawCircle(
      auraCenter,
      s * 0.34,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD54F).withValues(alpha: 0.42),
            const Color(0xFFFF8F00).withValues(alpha: 0.14),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: auraCenter, radius: s * 0.34)),
    );

    // 2. Twin upward blessing acceleration chevrons (symbolizing 2x production speed)
    void drawChevron(double topY, double halfW, double thick) {
      final path = Path()
        ..moveTo(s * 0.50, topY)
        ..lineTo(s * 0.50 + halfW, topY + halfW * 0.68)
        ..lineTo(s * 0.50 + halfW, topY + halfW * 0.68 + thick)
        ..lineTo(s * 0.50, topY + thick)
        ..lineTo(s * 0.50 - halfW, topY + halfW * 0.68 + thick)
        ..lineTo(s * 0.50 - halfW, topY + halfW * 0.68)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [goldHighlight, goldLight, goldMid],
          ).createShader(Rect.fromLTRB(
            s * 0.50 - halfW,
            topY,
            s * 0.50 + halfW,
            topY + halfW + thick,
          )),
      );
      canvas.drawPath(path, outline);
    }

    drawChevron(s * 0.11, s * 0.24, s * 0.095);
    drawChevron(s * 0.29, s * 0.29, s * 0.105);

    // 3. Sacred Golden Offering Bowl / Tithe Vessel at bottom (y: 0.58..0.88)
    final bowlPath = Path()
      ..moveTo(s * 0.18, s * 0.60)
      ..lineTo(s * 0.82, s * 0.60)
      ..cubicTo(s * 0.80, s * 0.77, s * 0.66, s * 0.83, s * 0.50, s * 0.83)
      ..cubicTo(s * 0.34, s * 0.83, s * 0.20, s * 0.77, s * 0.18, s * 0.60)
      ..close();
    canvas.drawPath(
      bowlPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [goldHighlight, goldLight, goldMid, goldDark],
          stops: const [0.0, 0.28, 0.68, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.18, s * 0.60, s * 0.82, s * 0.83)),
    );
    canvas.drawPath(bowlPath, outline);

    // Marble & gold foot plinth
    final footRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.30, s * 0.825, s * 0.70, s * 0.90),
      Radius.circular(s * 0.03),
    );
    canvas.drawRRect(
      footRect,
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFFFFFDF7), const Color(0xFFD7CBB7)],
        ).createShader(footRect.outerRect),
    );
    canvas.drawRRect(footRect, outline);

    // Radiant cyan-white blessing sparkle gem centered on bowl rim
    final gemCenter = Offset(s * 0.50, s * 0.695);
    final gemR = s * 0.068;
    final gem = Path()
      ..moveTo(gemCenter.dx, gemCenter.dy - gemR)
      ..lineTo(gemCenter.dx + gemR * 0.82, gemCenter.dy)
      ..lineTo(gemCenter.dx, gemCenter.dy + gemR)
      ..lineTo(gemCenter.dx - gemR * 0.82, gemCenter.dy)
      ..close();
    canvas.drawPath(
      gem,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFF4DD0E1)],
        ).createShader(Rect.fromCircle(center: gemCenter, radius: gemR)),
    );
    canvas.drawPath(gem, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TitheBlessingPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Sacred Offertory Card 2 — Consecration Rate: Ornate Golden Sacred Thurible /
/// Incense Censer suspended by fine bronze chains, featuring a hammered-gold
/// body (`#FFD54F` / `#FFB300`), glowing amber-ruby embers (`#FF6D00`) peeking
/// through gothic dome vents, curling golden-cyan sacred incense wisps, and
/// crisp dark graphite outlines (`#1A2226`).
class ConsecrationCenserIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const ConsecrationCenserIcon({
    super.key,
    this.size = 28.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: _ConsecrationCenserPainter(
        isOnGoldBackground: isOnGoldBackground,
      ),
    );
  }
}

class _ConsecrationCenserPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _ConsecrationCenserPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;

    final outline = _outlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.08,
    );
    final fineOutline = _outlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 0.88,
    );
    final detail = _detailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.72,
      baseWidth: 0.72,
    );
    final ink = _outlineColor(isOnGoldBackground);

    final goldHighlight =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFF3B0);
    final goldLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFFFD54F);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFB300);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFFB87400);
    final bronzeLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFFFD54F);
    final bronzeDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFF8C5600);

    const emberCore = Color(0xFFFFF59D);
    const emberBright = Color(0xFFFF6D00);
    const emberRuby = Color(0xFFD50000);

    const wispGold = Color(0xFFFFE082);
    const wispCyan = Color(0xFF00E5FF);
    const wispTip = Color(0xFFB2EBF2);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Soft sacred amber-cyan ambient glow behind the censer & rising wisps
    final auraCenter = Offset(s * 0.50, s * 0.48);
    canvas.drawCircle(
      auraCenter,
      s * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF6D00).withValues(alpha: 0.24),
            const Color(0xFF00E5FF).withValues(alpha: 0.14),
            Colors.transparent,
          ],
          stops: const [0.0, 0.56, 1.0],
        ).createShader(Rect.fromCircle(center: auraCenter, radius: s * 0.42)),
    );

    // 2. Curling golden-cyan wisps of sacred incense rising from the upper vents
    final leftWisp = Path()
      ..moveTo(s * 0.35, s * 0.43)
      ..cubicTo(s * 0.21, s * 0.37, s * 0.13, s * 0.25, s * 0.22, s * 0.135)
      ..cubicTo(s * 0.255, s * 0.10, s * 0.305, s * 0.092, s * 0.325, s * 0.112)
      ..cubicTo(s * 0.265, s * 0.145, s * 0.235, s * 0.21, s * 0.27, s * 0.275)
      ..cubicTo(s * 0.30, s * 0.33, s * 0.36, s * 0.36, s * 0.39, s * 0.41)
      ..close();

    final rightWisp = Path()
      ..moveTo(s * 0.65, s * 0.43)
      ..cubicTo(s * 0.79, s * 0.37, s * 0.87, s * 0.25, s * 0.78, s * 0.135)
      ..cubicTo(s * 0.745, s * 0.10, s * 0.695, s * 0.092, s * 0.675, s * 0.112)
      ..cubicTo(s * 0.735, s * 0.145, s * 0.765, s * 0.21, s * 0.73, s * 0.275)
      ..cubicTo(s * 0.70, s * 0.33, s * 0.64, s * 0.36, s * 0.61, s * 0.41)
      ..close();

    final wispOutline = Paint()
      ..color = ink.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.60, 0.75 * scale)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    for (final wisp in [leftWisp, rightWisp]) {
      canvas.drawPath(
        wisp,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [wispGold, wispCyan, wispTip],
            stops: [0.0, 0.56, 1.0],
          ).createShader(Rect.fromLTRB(s * 0.13, s * 0.09, s * 0.87, s * 0.43)),
      );
      canvas.drawPath(wisp, wispOutline);
    }

    // 3. Fine bronze-gold suspension chains & top ring (y: 0.055..0.51)
    final chainCasing = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.45, 1.75 * scale)
      ..strokeCap = StrokeCap.round;
    final chainCore = Paint()
      ..color = bronzeLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.80, 1.0 * scale)
      ..strokeCap = StrokeCap.round;

    void drawArticulatedChain(Offset a, Offset b, int beads) {
      canvas.drawLine(a, b, chainCasing);
      canvas.drawLine(a, b, chainCore);
      for (int i = 1; i <= beads; i++) {
        final t = i / (beads + 1);
        final pt = Offset.lerp(a, b, t)!;
        canvas.drawCircle(pt, s * 0.019, Paint()..color = goldHighlight);
        canvas.drawCircle(
          pt,
          s * 0.019,
          Paint()
            ..color = ink.withValues(alpha: 0.78)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.45, 0.55 * scale),
        );
      }
    }

    // Side & center suspension chains
    drawArticulatedChain(Offset(s * 0.46, s * 0.17), Offset(s * 0.22, s * 0.505), 3);
    drawArticulatedChain(Offset(s * 0.54, s * 0.17), Offset(s * 0.78, s * 0.505), 3);
    drawArticulatedChain(Offset(s * 0.50, s * 0.18), Offset(s * 0.50, s * 0.285), 1);

    // Top golden-bronze suspension ring (thick luminous gold band)
    final ringCenter = Offset(s * 0.50, s * 0.12);
    final ringOuterR = s * 0.068;
    final ringInnerR = s * 0.026;
    final ringPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: ringCenter, radius: ringOuterR))
      ..addOval(Rect.fromCircle(center: ringCenter, radius: ringInnerR));
    canvas.drawPath(
      ringPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [goldHighlight, goldLight, goldMid, bronzeDark],
        ).createShader(Rect.fromCircle(center: ringCenter, radius: ringOuterR)),
    );
    canvas.drawCircle(ringCenter, ringOuterR, fineOutline);
    canvas.drawCircle(ringCenter, ringInnerR, detail);

    // 4. Sculpted tiered pedestal foot & hanging drop finial (y: 0.78..0.94)
    final dropTip = Path()
      ..moveTo(s * 0.45, s * 0.875)
      ..lineTo(s * 0.55, s * 0.875)
      ..quadraticBezierTo(s * 0.53, s * 0.918, s * 0.50, s * 0.942)
      ..quadraticBezierTo(s * 0.47, s * 0.918, s * 0.45, s * 0.875)
      ..close();
    canvas.drawPath(
      dropTip,
      Paint()
        ..shader = LinearGradient(
          colors: [goldHighlight, goldMid, goldDark],
        ).createShader(Rect.fromLTRB(s * 0.45, s * 0.87, s * 0.55, s * 0.942)),
    );
    canvas.drawPath(dropTip, fineOutline);

    final footPlinth = Path()
      ..moveTo(s * 0.40, s * 0.795)
      ..lineTo(s * 0.60, s * 0.795)
      ..lineTo(s * 0.665, s * 0.88)
      ..lineTo(s * 0.335, s * 0.88)
      ..close();
    canvas.drawPath(
      footPlinth,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [goldHighlight, goldLight, goldMid, goldDark],
          stops: const [0.0, 0.30, 0.70, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.335, s * 0.795, s * 0.665, s * 0.88)),
    );
    canvas.drawPath(footPlinth, outline);

    // 5. Hammered-gold lower fire-bowl / brazier belly (y: 0.545..0.805)
    final bowlPath = Path()
      ..moveTo(s * 0.22, s * 0.55)
      ..lineTo(s * 0.78, s * 0.55)
      ..cubicTo(s * 0.77, s * 0.72, s * 0.66, s * 0.805, s * 0.50, s * 0.805)
      ..cubicTo(s * 0.34, s * 0.805, s * 0.23, s * 0.72, s * 0.22, s * 0.55)
      ..close();
    canvas.drawPath(
      bowlPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [goldHighlight, goldLight, goldMid, goldDark],
          stops: const [0.0, 0.28, 0.66, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.22, s * 0.55, s * 0.78, s * 0.805)),
    );

    // Left-side curved specular glint on lower bowl
    final bowlGlint = Path()
      ..moveTo(s * 0.275, s * 0.585)
      ..cubicTo(s * 0.285, s * 0.675, s * 0.34, s * 0.735, s * 0.40, s * 0.76)
      ..cubicTo(s * 0.365, s * 0.715, s * 0.325, s * 0.66, s * 0.32, s * 0.585)
      ..close();
    canvas.drawPath(
      bowlGlint,
      Paint()..color = Colors.white.withValues(alpha: isOnGoldBackground ? 0.25 : 0.64),
    );

    // Hammered gadroon fluted ribs on the bowl
    for (final rx in [0.36, 0.64]) {
      final rib = Path()
        ..moveTo(s * rx, s * 0.565)
        ..quadraticBezierTo(
          s * (rx < 0.5 ? 0.38 : 0.62),
          s * 0.685,
          s * (rx < 0.5 ? 0.435 : 0.565),
          s * 0.785,
        );
      canvas.drawPath(rib, detail);
    }
    canvas.drawPath(bowlPath, outline);

    // Central glowing amber-ruby medallion inset on the fire-bowl
    final medalCenter = Offset(s * 0.50, s * 0.675);
    final medalR = s * 0.070;
    final medal = Path()
      ..moveTo(medalCenter.dx, medalCenter.dy - medalR)
      ..lineTo(medalCenter.dx + medalR * 0.82, medalCenter.dy)
      ..lineTo(medalCenter.dx, medalCenter.dy + medalR)
      ..lineTo(medalCenter.dx - medalR * 0.82, medalCenter.dy)
      ..close();
    canvas.drawPath(
      medal,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.25, -0.25),
          colors: [emberCore, emberBright, emberRuby],
          stops: [0.0, 0.48, 1.0],
        ).createShader(Rect.fromCircle(center: medalCenter, radius: medalR)),
    );
    canvas.drawPath(medal, detail);

    // 6. Ornate Perforated Golden Dome Lid (y: 0.275..0.51)
    final domePath = Path()
      ..moveTo(s * 0.215, s * 0.505)
      ..cubicTo(s * 0.23, s * 0.36, s * 0.37, s * 0.295, s * 0.50, s * 0.285)
      ..cubicTo(s * 0.63, s * 0.295, s * 0.77, s * 0.36, s * 0.785, s * 0.505)
      ..close();
    canvas.drawPath(
      domePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [goldHighlight, goldLight, goldMid, goldDark],
          stops: const [0.0, 0.28, 0.66, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.215, s * 0.285, s * 0.785, s * 0.505)),
    );
    canvas.drawPath(domePath, outline);

    // Spire finial bead crowning the dome
    final spireRect = Rect.fromCenter(
      center: Offset(s * 0.50, s * 0.272),
      width: s * 0.10,
      height: s * 0.072,
    );
    canvas.drawOval(
      spireRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [goldHighlight, goldLight, goldDark],
        ).createShader(spireRect),
    );
    canvas.drawOval(spireRect, fineOutline);

    // 3 Arched Gothic Ember Vents pierced in the dome revealing glowing embers
    void drawEmberVent(double cx, double cy, double halfW, double h) {
      final vent = Path()
        ..moveTo(cx - halfW, cy + h * 0.5)
        ..lineTo(cx - halfW, cy - h * 0.05)
        ..quadraticBezierTo(cx, cy - h * 0.72, cx + halfW, cy - h * 0.05)
        ..lineTo(cx + halfW, cy + h * 0.5)
        ..close();
      canvas.drawPath(
        vent,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0.0, 0.25),
            radius: 0.95,
            colors: [emberCore, emberBright, emberRuby],
            stops: [0.0, 0.48, 1.0],
          ).createShader(
            Rect.fromCenter(center: Offset(cx, cy), width: halfW * 2.2, height: h * 1.4),
          ),
      );
      canvas.drawPath(vent, detail);
    }

    drawEmberVent(s * 0.50, s * 0.415, s * 0.066, s * 0.132);
    drawEmberVent(s * 0.34, s * 0.435, s * 0.050, s * 0.106);
    drawEmberVent(s * 0.66, s * 0.435, s * 0.050, s * 0.106);

    // 7. Sculpted Mid-Waist Flanged Rim, glowing ember seam & side chain lugs
    for (final lx in [s * 0.20, s * 0.80]) {
      final lugCenter = Offset(lx, s * 0.52);
      canvas.drawCircle(
        lugCenter,
        s * 0.044,
        Paint()
          ..shader = LinearGradient(
            colors: [goldHighlight, goldLight, bronzeDark],
          ).createShader(Rect.fromCircle(center: lugCenter, radius: s * 0.044)),
      );
      canvas.drawCircle(lugCenter, s * 0.044, fineOutline);
    }

    final seamRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.18, s * 0.492, s * 0.82, s * 0.568),
      Radius.circular(s * 0.036),
    );
    canvas.drawRRect(
      seamRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [goldHighlight, goldLight, goldMid, goldDark],
          stops: const [0.0, 0.28, 0.68, 1.0],
        ).createShader(seamRect.outerRect),
    );
    canvas.drawRRect(seamRect, outline);

    // Incandescent ember light strip gleaming along the censer waist seam
    final glowStrip = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.255, s * 0.517, s * 0.745, s * 0.545),
      Radius.circular(s * 0.014),
    );
    canvas.drawRRect(
      glowStrip,
      Paint()
        ..shader = const LinearGradient(
          colors: [emberRuby, emberBright, emberCore, emberBright, emberRuby],
          stops: [0.0, 0.22, 0.50, 0.78, 1.0],
        ).createShader(glowStrip.outerRect),
    );

    // Twin subtle golden-cyan incense sparkle motes
    void drawSparkMote(Offset c, double r, Color color) {
      final star = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx + r * 0.18, c.dy - r * 0.18, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx + r * 0.18, c.dy + r * 0.18, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - r * 0.18, c.dy + r * 0.18, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - r * 0.18, c.dy - r * 0.18, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(star, Paint()..color = color);
      canvas.drawPath(star, detail);
    }

    drawSparkMote(Offset(s * 0.155, s * 0.155), s * 0.048, wispGold);
    drawSparkMote(Offset(s * 0.845, s * 0.145), s * 0.045, wispCyan);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ConsecrationCenserPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Sacred Offertory Card 3 — Offline Cap: Ornate Royal Arcane Hourglass with
/// sculpted golden-bronze top and bottom caps (`#FFD54F` / `#C88A00`), slender
/// side pillars, translucent glass bulbs with curved specular highlights,
/// glowing golden-cyan cosmic sand (`#FFE082` / `#00E5FF`) flowing from the
/// upper chamber into a lower mound, and crisp `#1A2226` outlines.
class SanctuaryHourglassIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const SanctuaryHourglassIcon({
    super.key,
    this.size = 28.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: _SanctuaryHourglassPainter(
        isOnGoldBackground: isOnGoldBackground,
      ),
    );
  }
}

class _SanctuaryHourglassPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _SanctuaryHourglassPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;

    final outline = _outlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 1.08,
    );
    final pillarOutline = _outlinePaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      baseWidth: 0.90,
    );
    final detail = _detailPaint(
      scale,
      isOnGoldBackground: isOnGoldBackground,
      alpha: 0.72,
      baseWidth: 0.70,
    );

    final goldHighlight =
        isOnGoldBackground ? const Color(0xFF546E7A) : const Color(0xFFFFF5C0);
    final goldLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFFFD54F);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF2E3B42) : const Color(0xFFFFB300);
    final bronzeMid =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFFC88A00);
    final bronzeDark =
        isOnGoldBackground ? const Color(0xFF1B2429) : const Color(0xFF915C00);

    const glassDark = Color(0xFF1A313D);
    const glassMid = Color(0xFF2B5263);
    const glassRim = Color(0xFF80DEEA);

    const sandCream = Color(0xFFFFF8D6);
    const sandGold = Color(0xFFFFE082);
    const sandDeepGold = Color(0xFFE09900);
    const sandCyan = Color(0xFF00E5FF);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Subtle arcane golden-cyan aura behind the hourglass waist
    final center = Offset(s * 0.50, s * 0.50);
    canvas.drawCircle(
      center,
      s * 0.39,
      Paint()
        ..shader = RadialGradient(
          colors: [
            sandCyan.withValues(alpha: 0.22),
            sandGold.withValues(alpha: 0.18),
            Colors.transparent,
          ],
          stops: const [0.0, 0.56, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: s * 0.39)),
    );

    // 2. Slender gleaming golden-bronze side pillars (x: 0.215 & 0.785)
    for (final px in [s * 0.215, s * 0.785]) {
      final pillarRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(px - s * 0.042, s * 0.21, px + s * 0.042, s * 0.79),
        Radius.circular(s * 0.015),
      );
      canvas.drawRRect(
        pillarRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [goldHighlight, goldLight, goldMid, bronzeMid],
            stops: const [0.0, 0.32, 0.70, 1.0],
          ).createShader(pillarRect.outerRect),
      );
      canvas.drawRRect(pillarRect, pillarOutline);

      // Decorative sculpted golden ring collar at mid-pillar
      final ring = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(px, s * 0.50),
          width: s * 0.115,
          height: s * 0.068,
        ),
        Radius.circular(s * 0.032),
      );
      canvas.drawRRect(
        ring,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [goldHighlight, goldLight, bronzeMid],
          ).createShader(ring.outerRect),
      );
      canvas.drawRRect(ring, pillarOutline);
    }

    // 3. Translucent Arcane Glass Bulbs (y: 0.22..0.78)
    final glassPath = Path()
      ..moveTo(s * 0.305, s * 0.22)
      ..lineTo(s * 0.695, s * 0.22)
      // Right upper bulb curve into pinched waist
      ..cubicTo(s * 0.71, s * 0.37, s * 0.585, s * 0.455, s * 0.534, s * 0.50)
      // Right lower bulb curve flaring to base
      ..cubicTo(s * 0.585, s * 0.545, s * 0.71, s * 0.63, s * 0.695, s * 0.78)
      ..lineTo(s * 0.305, s * 0.78)
      // Left lower bulb curve into pinched waist
      ..cubicTo(s * 0.29, s * 0.63, s * 0.415, s * 0.545, s * 0.466, s * 0.50)
      // Left upper bulb curve back to top
      ..cubicTo(s * 0.415, s * 0.455, s * 0.29, s * 0.37, s * 0.305, s * 0.22)
      ..close();

    // Tinted translucent arcane glass backdrop (high contrast in Dark & Light modes)
    canvas.drawPath(
      glassPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            glassRim.withValues(alpha: 0.48),
            glassMid.withValues(alpha: 0.84),
            glassDark.withValues(alpha: 0.92),
          ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.29, s * 0.22, s * 0.71, s * 0.78)),
    );

    // 4. Glowing Golden-Cyan Cosmic Sand clipped cleanly inside the glass bulbs
    canvas.save();
    canvas.clipPath(glassPath);

    // 4a. Upper chamber funneling cosmic sand (y: 0.31..0.498)
    final upperSand = Path()
      ..moveTo(s * 0.295, s * 0.315)
      ..quadraticBezierTo(s * 0.50, s * 0.362, s * 0.705, s * 0.315)
      ..cubicTo(s * 0.66, s * 0.415, s * 0.555, s * 0.47, s * 0.514, s * 0.498)
      ..lineTo(s * 0.486, s * 0.498)
      ..cubicTo(s * 0.445, s * 0.47, s * 0.34, s * 0.415, s * 0.295, s * 0.315)
      ..close();
    canvas.drawPath(
      upperSand,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sandCream, sandGold, sandCyan],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.295, s * 0.31, s * 0.705, s * 0.50)),
    );

    // Bright crest glint along top edge of upper sand
    final upperCrest = Path()
      ..moveTo(s * 0.33, s * 0.326)
      ..quadraticBezierTo(s * 0.50, s * 0.366, s * 0.67, s * 0.326);
    canvas.drawPath(
      upperCrest,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.75, 0.95 * scale)
        ..strokeCap = StrokeCap.round,
    );

    // 4b. Glowing vertical cosmic sand stream pouring through the central waist
    final streamGlow = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [sandCyan, sandGold, sandCyan],
      ).createShader(Rect.fromLTRB(s * 0.46, s * 0.49, s * 0.54, s * 0.65))
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, 2.25 * scale)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s * 0.50, s * 0.49), Offset(s * 0.50, s * 0.64), streamGlow);

    final streamCore = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, 0.95 * scale)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s * 0.50, s * 0.495), Offset(s * 0.50, s * 0.63), streamCore);

    // Sparkling falling cosmic grains flanking the stream
    canvas.drawCircle(
      Offset(s * 0.468, s * 0.562),
      s * 0.014,
      Paint()..color = sandGold,
    );
    canvas.drawCircle(
      Offset(s * 0.534, s * 0.584),
      s * 0.013,
      Paint()..color = sandCyan,
    );

    // 4c. Lower chamber radiant conical cosmic sand mound (y: 0.605..0.78)
    final lowerMound = Path()
      ..moveTo(s * 0.29, s * 0.782)
      ..cubicTo(s * 0.34, s * 0.688, s * 0.435, s * 0.614, s * 0.50, s * 0.604)
      ..cubicTo(s * 0.565, s * 0.614, s * 0.66, s * 0.688, s * 0.71, s * 0.782)
      ..close();
    canvas.drawPath(
      lowerMound,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.0, -0.52),
          radius: 1.05,
          colors: [sandCream, sandCyan, sandGold, sandDeepGold],
          stops: [0.0, 0.32, 0.68, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.29, s * 0.60, s * 0.71, s * 0.782)),
    );

    // Luminous cyan-white impact shimmer at apex of lower sand mound
    canvas.drawCircle(
      Offset(s * 0.50, s * 0.625),
      s * 0.050,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.88),
            sandCyan.withValues(alpha: 0.45),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(s * 0.50, s * 0.625), radius: s * 0.050),
        ),
    );

    // Curved white glass specular reflection highlights inside upper & lower bulbs
    final glassGlintPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 1.35 * scale)
      ..strokeCap = StrokeCap.round;

    final upperGlint = Path()
      ..moveTo(s * 0.345, s * 0.265)
      ..cubicTo(s * 0.345, s * 0.335, s * 0.375, s * 0.385, s * 0.415, s * 0.425);
    canvas.drawPath(upperGlint, glassGlintPaint);

    final lowerGlint = Path()
      ..moveTo(s * 0.415, s * 0.575)
      ..cubicTo(s * 0.375, s * 0.615, s * 0.345, s * 0.665, s * 0.345, s * 0.735);
    canvas.drawPath(lowerGlint, glassGlintPaint);

    // Subtle right-edge aqua glass rim bounce light
    final rightRimGlint = Path()
      ..moveTo(s * 0.655, s * 0.275)
      ..cubicTo(s * 0.655, s * 0.335, s * 0.63, s * 0.375, s * 0.60, s * 0.41);
    canvas.drawPath(
      rightRimGlint,
      Paint()
        ..color = glassRim.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.75, 0.95 * scale)
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore(); // end glass clip

    // Crisp outer glass bulb silhouette outline
    canvas.drawPath(glassPath, outline);

    // Ornate miniature golden waist collar clasping the central glass pinch
    final waistRing = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.50),
        width: s * 0.145,
        height: s * 0.062,
      ),
      Radius.circular(s * 0.030),
    );
    canvas.drawRRect(
      waistRing,
      Paint()
        ..shader = LinearGradient(
          colors: [goldHighlight, goldLight, goldMid, bronzeMid],
        ).createShader(waistRing.outerRect),
    );
    canvas.drawRRect(waistRing, pillarOutline);

    // 5. Sculpted Golden-Bronze Top Royal Cap & Crown Crest (y: 0.065..0.228)
    // Crown crest arch rising from the top cap
    final crownCrest = Path()
      ..moveTo(s * 0.33, s * 0.125)
      ..quadraticBezierTo(s * 0.50, s * 0.045, s * 0.67, s * 0.125)
      ..close();
    canvas.drawPath(
      crownCrest,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [goldHighlight, goldLight, bronzeMid],
        ).createShader(Rect.fromLTRB(s * 0.33, s * 0.05, s * 0.67, s * 0.125)),
    );
    canvas.drawPath(crownCrest, outline);

    // Sculpted single stepped beveled royal top cornice (generous gold surface)
    final topCapPath = Path()
      ..moveTo(s * 0.13, s * 0.12)
      ..lineTo(s * 0.87, s * 0.12)
      ..lineTo(s * 0.87, s * 0.18)
      ..lineTo(s * 0.82, s * 0.228)
      ..lineTo(s * 0.18, s * 0.228)
      ..lineTo(s * 0.13, s * 0.18)
      ..close();
    canvas.drawPath(
      topCapPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [goldHighlight, goldLight, goldMid, bronzeMid, bronzeDark],
          stops: const [0.0, 0.28, 0.56, 0.82, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.13, s * 0.12, s * 0.87, s * 0.228)),
    );
    // Top specular bevel highlight along upper edge
    canvas.drawLine(
      Offset(s * 0.175, s * 0.145),
      Offset(s * 0.55, s * 0.145),
      Paint()
        ..color = Colors.white.withValues(alpha: isOnGoldBackground ? 0.25 : 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.85, 1.05 * scale)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(topCapPath, outline);

    // Glowing cyan arcane finial jewel inset on the top cap center
    final finialGem = Offset(s * 0.50, s * 0.168);
    canvas.drawCircle(
      finialGem,
      s * 0.028,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, sandCyan],
        ).createShader(Rect.fromCircle(center: finialGem, radius: s * 0.028)),
    );
    canvas.drawCircle(finialGem, s * 0.028, detail);

    // 6. Sculpted Golden-Bronze Bottom Royal Cap & Base Plinth (y: 0.772..0.925)
    final bottomCapPath = Path()
      ..moveTo(s * 0.18, s * 0.772)
      ..lineTo(s * 0.82, s * 0.772)
      ..lineTo(s * 0.87, s * 0.822)
      ..lineTo(s * 0.87, s * 0.892)
      ..lineTo(s * 0.13, s * 0.892)
      ..lineTo(s * 0.13, s * 0.822)
      ..close();
    canvas.drawPath(
      bottomCapPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [goldHighlight, goldLight, goldMid, bronzeMid, bronzeDark],
          stops: const [0.0, 0.28, 0.56, 0.82, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.13, s * 0.772, s * 0.87, s * 0.892)),
    );
    // Subtle golden highlight glint along lower plinth shoulder
    canvas.drawLine(
      Offset(s * 0.18, s * 0.825),
      Offset(s * 0.54, s * 0.825),
      Paint()
        ..color = Colors.white.withValues(alpha: isOnGoldBackground ? 0.25 : 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.85, 1.05 * scale)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(bottomCapPath, outline);

    // Subtle carved royal plinth line across bottom base
    canvas.drawLine(
      Offset(s * 0.22, s * 0.892),
      Offset(s * 0.78, s * 0.892),
      outline,
    );

    // 7. Delicate arcane sparkle accents flanking the hourglass waist
    void drawSparkle(Offset c, double r, Color color) {
      final star = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx + r * 0.18, c.dy - r * 0.18, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx + r * 0.18, c.dy + r * 0.18, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - r * 0.18, c.dy + r * 0.18, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - r * 0.18, c.dy - r * 0.18, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(star, Paint()..color = color);
      canvas.drawPath(star, detail);
    }

    drawSparkle(Offset(s * 0.105, s * 0.36), s * 0.045, sandCyan);
    drawSparkle(Offset(s * 0.895, s * 0.64), s * 0.048, sandGold);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SanctuaryHourglassPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Dispatcher rendering the bespoke custom RPG [CustomPainter] icon for each
/// [SacredBlessing] in the Sacred Temple Prayer tab and Battle HUD pills.
class SacredBlessingBadgeIcon extends StatelessWidget {
  final SacredBlessing blessing;
  final double size;

  const SacredBlessingBadgeIcon({
    super.key,
    required this.blessing,
    this.size = 22.0,
  });

  @override
  Widget build(BuildContext context) {
    switch (blessing) {
      case SacredBlessing.vitality:
        return BlessingOfVitalityIcon(size: size);
      case SacredBlessing.clairvoyance:
        return BlessingOfClairvoyanceIcon(size: size);
      case SacredBlessing.harvest:
        return BlessingOfHarvestIcon(size: size);
      case SacredBlessing.mana:
        return BlessingOfManaIcon(size: size);
    }
  }
}

/// Prayer Room — `Blessing of Vitality`: Beveled golden heart bezel enclosing
/// a faceted crimson-ruby crystal heart topped with a floating golden halo.
class BlessingOfVitalityIcon extends StatelessWidget {
  final double size;

  const BlessingOfVitalityIcon({super.key, this.size = 22.0});

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: const _BlessingOfVitalityPainter(),
    );
  }
}

class _BlessingOfVitalityPainter extends CustomPainter {
  const _BlessingOfVitalityPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, baseWidth: 1.2);
    final thinOutline = _outlinePaint(scale, baseWidth: 0.85);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Floating golden oval halo above the heart
    final haloOuter = Rect.fromCenter(
      center: Offset(s * 0.50, s * 0.14),
      width: s * 0.50,
      height: s * 0.14,
    );
    final haloInner = Rect.fromCenter(
      center: Offset(s * 0.50, s * 0.14),
      width: s * 0.28,
      height: s * 0.05,
    );
    final haloPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(haloOuter)
      ..addOval(haloInner);
    canvas.drawPath(
      haloPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8E1), Color(0xFFFFD54F), Color(0xFFB27800)],
        ).createShader(haloOuter),
    );
    canvas.drawOval(haloOuter, thinOutline);

    // 2. Beveled golden outer heart bezel
    final outerHeart = Path()
      ..moveTo(s * 0.50, s * 0.34)
      ..cubicTo(s * 0.40, s * 0.21, s * 0.12, s * 0.23, s * 0.12, s * 0.47)
      ..cubicTo(s * 0.12, s * 0.69, s * 0.37, s * 0.82, s * 0.50, s * 0.92)
      ..cubicTo(s * 0.63, s * 0.82, s * 0.88, s * 0.69, s * 0.88, s * 0.47)
      ..cubicTo(s * 0.88, s * 0.23, s * 0.60, s * 0.21, s * 0.50, s * 0.34)
      ..close();
    canvas.drawPath(
      outerHeart,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8E1), Color(0xFFFFD54F), Color(0xFFB27800)],
        ).createShader(Rect.fromLTRB(s * 0.12, s * 0.22, s * 0.88, s * 0.92)),
    );
    canvas.drawPath(outerHeart, outline);

    // 3. Radiant ruby crystal inner heart
    final innerHeart = Path()
      ..moveTo(s * 0.50, s * 0.41)
      ..cubicTo(s * 0.42, s * 0.30, s * 0.21, s * 0.32, s * 0.21, s * 0.49)
      ..cubicTo(s * 0.21, s * 0.65, s * 0.40, s * 0.76, s * 0.50, s * 0.84)
      ..cubicTo(s * 0.60, s * 0.76, s * 0.79, s * 0.65, s * 0.79, s * 0.49)
      ..cubicTo(s * 0.79, s * 0.32, s * 0.58, s * 0.30, s * 0.50, s * 0.41)
      ..close();
    canvas.drawPath(
      innerHeart,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF5252), Color(0xFFE53935), Color(0xFF8E0000)],
        ).createShader(Rect.fromLTRB(s * 0.21, s * 0.30, s * 0.79, s * 0.84)),
    );
    canvas.drawPath(innerHeart, thinOutline);

    // 4. Specular highlight & subtle ivory cross glint
    final glintPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = math.max(0.9, 1.35 * scale)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(s * 0.50, s * 0.47),
      Offset(s * 0.50, s * 0.67),
      glintPaint,
    );
    canvas.drawLine(
      Offset(s * 0.40, s * 0.57),
      Offset(s * 0.60, s * 0.57),
      glintPaint,
    );
    canvas.drawCircle(
      Offset(s * 0.32, s * 0.43),
      s * 0.045,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlessingOfVitalityPainter oldDelegate) => false;
}

/// Prayer Room — `Blessing of Clairvoyance`: Golden-framed mystic oracle eye
/// with luminous amethyst iris, celestial foresight rays, and starlight pupil.
class BlessingOfClairvoyanceIcon extends StatelessWidget {
  final double size;

  const BlessingOfClairvoyanceIcon({super.key, this.size = 22.0});

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: const _BlessingOfClairvoyancePainter(),
    );
  }
}

class _BlessingOfClairvoyancePainter extends CustomPainter {
  const _BlessingOfClairvoyancePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, baseWidth: 1.2);
    final thinOutline = _outlinePaint(scale, baseWidth: 0.85);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Three golden prophetic sunbeams crowning the eye
    final rayPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..strokeWidth = math.max(1.0, 1.55 * scale)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s * 0.50, s * 0.10), Offset(s * 0.50, s * 0.22), rayPaint);
    canvas.drawLine(Offset(s * 0.27, s * 0.16), Offset(s * 0.34, s * 0.26), rayPaint);
    canvas.drawLine(Offset(s * 0.73, s * 0.16), Offset(s * 0.66, s * 0.26), rayPaint);

    // 2. Beveled golden outer eye almond bezel
    final outerEye = Path()
      ..moveTo(s * 0.08, s * 0.55)
      ..quadraticBezierTo(s * 0.50, s * 0.21, s * 0.92, s * 0.55)
      ..quadraticBezierTo(s * 0.50, s * 0.89, s * 0.08, s * 0.55)
      ..close();
    canvas.drawPath(
      outerEye,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8E1), Color(0xFFFFD54F), Color(0xFFB27800)],
        ).createShader(Rect.fromLTRB(s * 0.08, s * 0.26, s * 0.92, s * 0.84)),
    );
    canvas.drawPath(outerEye, outline);

    // 3. Soft lavender-ivory inner eye sclera
    final innerEye = Path()
      ..moveTo(s * 0.17, s * 0.55)
      ..quadraticBezierTo(s * 0.50, s * 0.30, s * 0.83, s * 0.55)
      ..quadraticBezierTo(s * 0.50, s * 0.80, s * 0.17, s * 0.55)
      ..close();
    canvas.drawPath(
      innerEye,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFF3E5F5), Color(0xFFD1C4E9)],
        ).createShader(Rect.fromLTRB(s * 0.17, s * 0.34, s * 0.83, s * 0.76)),
    );
    canvas.drawPath(innerEye, thinOutline);

    // 4. Luminous amethyst iris + deep violet pupil + starlight gleam
    final center = Offset(s * 0.50, s * 0.55);
    final irisR = s * 0.175;
    canvas.drawCircle(
      center,
      irisR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.25, -0.25),
          colors: [Color(0xFFE040FB), Color(0xFF9C27B0), Color(0xFF4A148C)],
        ).createShader(Rect.fromCircle(center: center, radius: irisR)),
    );
    canvas.drawCircle(center, irisR, thinOutline);

    // Deep cosmic pupil
    canvas.drawCircle(
      center,
      s * 0.075,
      Paint()..color = const Color(0xFF1A0730),
    );

    // Crisp white specular dot
    canvas.drawCircle(
      Offset(s * 0.44, s * 0.49),
      s * 0.042,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlessingOfClairvoyancePainter oldDelegate) => false;
}

/// Prayer Room — `Blessing of Harvest`: Twin beveled golden abundance wreaths
/// cradling a faceted emerald Elemental Orb crowned with a radiant star burst.
class BlessingOfHarvestIcon extends StatelessWidget {
  final double size;

  const BlessingOfHarvestIcon({super.key, this.size = 22.0});

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: const _BlessingOfHarvestPainter(),
    );
  }
}

class _BlessingOfHarvestPainter extends CustomPainter {
  const _BlessingOfHarvestPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, baseWidth: 1.15);
    final thinOutline = _outlinePaint(scale, baseWidth: 0.8);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Symmetrical golden harvest crescent leaves cradling the central orb
    for (final isLeft in [true, false]) {
      final sign = isLeft ? -1.0 : 1.0;
      double px(double d) => s * (0.50 + sign * d);

      final leaf = Path()
        ..moveTo(px(0.05), s * 0.87)
        ..cubicTo(px(0.36), s * 0.82, px(0.45), s * 0.56, px(0.38), s * 0.30)
        ..cubicTo(px(0.31), s * 0.47, px(0.25), s * 0.67, px(0.05), s * 0.76)
        ..close();
      canvas.drawPath(
        leaf,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF3B0), Color(0xFFFFCA28), Color(0xFFB27800)],
          ).createShader(Rect.fromLTRB(s * 0.06, s * 0.28, s * 0.94, s * 0.88)),
      );
      canvas.drawPath(leaf, thinOutline);
    }

    // 2. Radiant beveled golden ring around the emerald harvest orb
    final orbCenter = Offset(s * 0.50, s * 0.56);
    final bezelR = s * 0.255;
    final orbR = s * 0.195;
    canvas.drawCircle(
      orbCenter,
      bezelR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8E1), Color(0xFFFFD54F), Color(0xFF9A6500)],
        ).createShader(Rect.fromCircle(center: orbCenter, radius: bezelR)),
    );
    canvas.drawCircle(orbCenter, bezelR, outline);

    // 3. Faceted emerald elemental harvest orb
    canvas.drawCircle(
      orbCenter,
      orbR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.30, -0.30),
          colors: [Color(0xFFB9F6CA), Color(0xFF43A047), Color(0xFF1B5E20)],
        ).createShader(Rect.fromCircle(center: orbCenter, radius: orbR)),
    );
    canvas.drawCircle(orbCenter, orbR, thinOutline);
    canvas.drawCircle(
      Offset(s * 0.435, s * 0.495),
      s * 0.045,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );

    // 4. Crown 4-point golden abundance star sparkle above the orb
    final starC = Offset(s * 0.50, s * 0.19);
    final star = Path();
    for (int i = 0; i < 8; i++) {
      final r = i.isEven ? s * 0.145 : s * 0.048;
      final a = -math.pi / 2 + i * (math.pi / 4);
      final pt = starC + Offset(math.cos(a), math.sin(a)) * r;
      if (i == 0) {
        star.moveTo(pt.dx, pt.dy);
      } else {
        star.lineTo(pt.dx, pt.dy);
      }
    }
    star.close();
    canvas.drawPath(
      star,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFE082), Color(0xFFFFB300)],
        ).createShader(Rect.fromCircle(center: starC, radius: s * 0.145)),
    );
    canvas.drawPath(star, thinOutline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlessingOfHarvestPainter oldDelegate) => false;
}

/// Prayer Room — `Blessing of Mana`: Faceted sapphire-cyan arcane mana crystal
/// droplet set inside a beveled golden teardrop bezel with an orbiting golden
/// arcane ring and twin shimmering cyan-white energy sparkles.
class BlessingOfManaIcon extends StatelessWidget {
  final double size;

  const BlessingOfManaIcon({super.key, this.size = 22.0});

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: const _BlessingOfManaPainter(),
    );
  }
}

class _BlessingOfManaPainter extends CustomPainter {
  const _BlessingOfManaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, baseWidth: 1.2);
    final thinOutline = _outlinePaint(scale, baseWidth: 0.8);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Soft radiant arcane glow aura behind the droplet
    canvas.drawCircle(
      Offset(s * 0.50, s * 0.58),
      s * 0.36,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF40C4FF).withValues(alpha: 0.35),
            const Color(0xFF0288D1).withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(s * 0.50, s * 0.58), radius: s * 0.36),
        ),
    );

    // 2. Back arc of tilted golden arcane ring orbiting the mana droplet
    canvas.save();
    canvas.translate(s * 0.50, s * 0.58);
    canvas.rotate(-0.34);
    final ringRect = Rect.fromCenter(
      center: Offset.zero,
      width: s * 0.84,
      height: s * 0.25,
    );
    canvas.drawArc(
      ringRect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFFB27800)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, 2.0 * scale)
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    Path buildDrop(double pad) {
      final t = pad;
      return Path()
        ..moveTo(s * 0.50, s * (0.10 + t * 1.15))
        ..cubicTo(
          s * (0.66 - t * 0.4),
          s * 0.34,
          s * (0.81 - t),
          s * 0.49,
          s * (0.81 - t),
          s * 0.61,
        )
        ..arcToPoint(
          Offset(s * (0.19 + t), s * 0.61),
          radius: Radius.circular(s * (0.31 - t)),
          clockwise: true,
        )
        ..cubicTo(
          s * (0.19 + t),
          s * 0.49,
          s * (0.34 + t * 0.4),
          s * 0.34,
          s * 0.50,
          s * (0.10 + t * 1.15),
        )
        ..close();
    }

    // 3. Beveled golden teardrop bezel
    final outerDrop = buildDrop(0.0);
    canvas.drawPath(
      outerDrop,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8E1),
            Color(0xFFFFE082),
            Color(0xFFFFB300),
            Color(0xFFB27800),
          ],
          stops: [0.0, 0.35, 0.72, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.19, s * 0.10, s * 0.81, s * 0.92)),
    );
    canvas.drawPath(outerDrop, outline);

    // 4. Faceted sapphire-cyan mana crystal core inside the bezel
    final innerDrop = buildDrop(0.075);
    canvas.save();
    canvas.clipPath(innerDrop);

    canvas.drawRect(
      Rect.fromLTRB(s * 0.22, s * 0.16, s * 0.78, s * 0.90),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB2F5FF), Color(0xFF29B6F6), Color(0xFF01579B)],
        ).createShader(Rect.fromLTRB(s * 0.22, s * 0.16, s * 0.78, s * 0.90)),
    );

    // Central bright diamond crystal table facet
    final tableFacet = Path()
      ..moveTo(s * 0.50, s * 0.34)
      ..lineTo(s * 0.64, s * 0.56)
      ..lineTo(s * 0.50, s * 0.74)
      ..lineTo(s * 0.36, s * 0.56)
      ..close();
    canvas.drawPath(
      tableFacet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0F7FA), Color(0xFF00E5FF), Color(0xFF0288D1)],
        ).createShader(Rect.fromLTRB(s * 0.36, s * 0.34, s * 0.64, s * 0.74)),
    );

    // Crisp crystalline facet ridges
    final ridgePaint = Paint()
      ..color = const Color(0xFFE0F7FA).withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, 0.75 * scale)
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(tableFacet, ridgePaint);
    canvas.drawLine(Offset(s * 0.50, s * 0.18), Offset(s * 0.50, s * 0.34), ridgePaint);
    canvas.drawLine(Offset(s * 0.50, s * 0.74), Offset(s * 0.50, s * 0.86), ridgePaint);

    // Bright specular crystal gleam on upper-left shoulder
    canvas.drawCircle(
      Offset(s * 0.39, s * 0.49),
      s * 0.048,
      Paint()..color = Colors.white.withValues(alpha: 0.94),
    );
    canvas.restore();
    canvas.drawPath(innerDrop, thinOutline);

    // 5. Front sweep of tilted golden arcane ring crossing the lower crystal
    canvas.save();
    canvas.translate(s * 0.50, s * 0.58);
    canvas.rotate(-0.34);
    canvas.drawArc(
      ringRect,
      0.08,
      math.pi - 0.16,
      false,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFD54F), Color(0xFFFFB300)],
        ).createShader(ringRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.3, 1.85 * scale)
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // 6. Twin shimmering arcane cyan-white star motes flanking upper crest
    void drawMote(Offset center, double r) {
      final mote = Path()
        ..moveTo(center.dx, center.dy - r)
        ..lineTo(center.dx + r * 0.36, center.dy - r * 0.36)
        ..lineTo(center.dx + r, center.dy)
        ..lineTo(center.dx + r * 0.36, center.dy + r * 0.36)
        ..lineTo(center.dx, center.dy + r)
        ..lineTo(center.dx - r * 0.36, center.dy + r * 0.36)
        ..lineTo(center.dx - r, center.dy)
        ..lineTo(center.dx - r * 0.36, center.dy - r * 0.36)
        ..close();
      canvas.drawPath(mote, Paint()..color = const Color(0xFFE0F7FA));
    }

    drawMote(Offset(s * 0.21, s * 0.26), s * 0.095);
    drawMote(Offset(s * 0.80, s * 0.22), s * 0.075);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlessingOfManaPainter oldDelegate) => false;
}


