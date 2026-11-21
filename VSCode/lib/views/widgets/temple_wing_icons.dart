import 'dart:math' as math;
import 'package:flutter/material.dart';

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
    isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFF263238);

Paint _outlinePaint(double scale, {bool isOnGoldBackground = false}) {
  return Paint()
    ..color = _outlineColor(isOnGoldBackground)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.65, 1.05 * scale)
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
}

Paint _detailPaint(
  double scale, {
  bool isOnGoldBackground = false,
  double alpha = 0.72,
}) {
  return Paint()
    ..color = _outlineColor(isOnGoldBackground).withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.45, 0.70 * scale)
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
}

// =============================================================================
// 5 NAVIGATION TAB ICONS (Accepting `size` & `bool isOnGoldBackground`)
// =============================================================================

/// Tab 1 — Consagration: Ornate Sacred Golden Chalice with triangular pedestal
/// base, rounded cup, central ruby gem, and 3 radiant light rays above the rim.
class ConsagrationChaliceIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const ConsagrationChaliceIcon({
    super.key,
    this.size = 20.0,
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
    final outline = _outlinePaint(scale, isOnGoldBackground: isOnGoldBackground);

    final goldLight =
        isOnGoldBackground ? const Color(0xFF37474F) : const Color(0xFFFFE082);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFFFFB300);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFFB27B00);
    final gemLight =
        isOnGoldBackground ? const Color(0xFFD32F2F) : const Color(0xFFFF6E6E);
    final gemDark =
        isOnGoldBackground ? const Color(0xFF7F1D1D) : const Color(0xFFC62828);
    final rayColor =
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFFFFE082);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Three radiant light rays rising above the chalice rim
    final rayPaint = Paint()
      ..color = rayColor.withValues(alpha: isOnGoldBackground ? 0.85 : 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.85, 1.2 * scale)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s * 0.50, s * 0.21), Offset(s * 0.50, s * 0.08), rayPaint);
    canvas.drawLine(Offset(s * 0.34, s * 0.22), Offset(s * 0.25, s * 0.11), rayPaint);
    canvas.drawLine(Offset(s * 0.66, s * 0.22), Offset(s * 0.75, s * 0.11), rayPaint);

    // 2. Chalice stem & knop + triangular pedestal base
    final basePath = Path()
      ..moveTo(s * 0.44, s * 0.58)
      ..lineTo(s * 0.56, s * 0.58)
      ..lineTo(s * 0.56, s * 0.74)
      ..lineTo(s * 0.75, s * 0.89)
      ..lineTo(s * 0.25, s * 0.89)
      ..lineTo(s * 0.44, s * 0.74)
      ..close();
    canvas.drawPath(
      basePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [goldLight, goldMid, goldDark],
        ).createShader(Rect.fromLTRB(s * 0.25, s * 0.58, s * 0.75, s * 0.89)),
    );
    canvas.drawPath(basePath, outline);

    // Stem central ring knop
    final knopRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(s * 0.50, s * 0.665), width: s * 0.20, height: s * 0.07),
      Radius.circular(s * 0.035),
    );
    canvas.drawRRect(
      knopRect,
      Paint()
        ..shader = LinearGradient(
          colors: [goldLight, goldMid, goldDark],
        ).createShader(knopRect.outerRect),
    );
    canvas.drawRRect(knopRect, outline);

    // 3. Rounded chalice cup
    final cupPath = Path()
      ..moveTo(s * 0.22, s * 0.28)
      ..lineTo(s * 0.78, s * 0.28)
      ..cubicTo(s * 0.78, s * 0.52, s * 0.63, s * 0.60, s * 0.50, s * 0.60)
      ..cubicTo(s * 0.37, s * 0.60, s * 0.22, s * 0.52, s * 0.22, s * 0.28)
      ..close();
    canvas.drawPath(
      cupPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [goldLight, goldMid, goldDark],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.22, s * 0.28, s * 0.78, s * 0.60)),
    );
    canvas.drawPath(cupPath, outline);

    // Cup rim band
    final rimRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.20, s * 0.255, s * 0.80, s * 0.315),
      Radius.circular(s * 0.03),
    );
    canvas.drawRRect(
      rimRect,
      Paint()
        ..shader = LinearGradient(
          colors: [goldLight, goldMid],
        ).createShader(rimRect.outerRect),
    );
    canvas.drawRRect(rimRect, outline);

    // 4. Central faceted ruby gem on cup
    final gemCenter = Offset(s * 0.50, s * 0.44);
    final gemPath = Path()
      ..moveTo(gemCenter.dx, gemCenter.dy - s * 0.085)
      ..lineTo(gemCenter.dx + s * 0.07, gemCenter.dy)
      ..lineTo(gemCenter.dx, gemCenter.dy + s * 0.085)
      ..lineTo(gemCenter.dx - s * 0.07, gemCenter.dy)
      ..close();
    canvas.drawPath(
      gemPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gemLight, gemDark],
        ).createShader(Rect.fromCircle(center: gemCenter, radius: s * 0.085)),
    );
    canvas.drawPath(gemPath, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ConsagrationChalicePainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Tab 2 — Offerings: White/ivory marble stone Sacrificial Altar trimmed in
/// gold with a glowing sacred flame burning on top.
class OfferingsAltarIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const OfferingsAltarIcon({
    super.key,
    this.size = 20.0,
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
    final outline = _outlinePaint(scale, isOnGoldBackground: isOnGoldBackground);
    final detail = _detailPaint(scale, isOnGoldBackground: isOnGoldBackground);

    final marbleLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFFAF6EE);
    final marbleMid =
        isOnGoldBackground ? const Color(0xFF37474F) : const Color(0xFFE6DEC8);
    final marbleDark =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFFC8B898);
    final goldLight =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFFFFE082);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFFFFB300);
    final flameOuterTop =
        isOnGoldBackground ? const Color(0xFFE64A19) : const Color(0xFFFF8A65);
    final flameOuterBot =
        isOnGoldBackground ? const Color(0xFF9A1B1B) : const Color(0xFFD84315);
    final flameCore =
        isOnGoldBackground ? const Color(0xFFFF8F00) : const Color(0xFFFFE082);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Glowing sacred flame atop the altar
    final outerFlame = Path()
      ..moveTo(s * 0.50, s * 0.08)
      ..cubicTo(s * 0.64, s * 0.21, s * 0.68, s * 0.36, s * 0.58, s * 0.44)
      ..lineTo(s * 0.42, s * 0.44)
      ..cubicTo(s * 0.32, s * 0.36, s * 0.36, s * 0.21, s * 0.50, s * 0.08)
      ..close();
    canvas.drawPath(
      outerFlame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [flameOuterTop, flameOuterBot],
        ).createShader(Rect.fromLTRB(s * 0.34, s * 0.08, s * 0.66, s * 0.44)),
    );
    canvas.drawPath(outerFlame, outline);

    final innerFlame = Path()
      ..moveTo(s * 0.50, s * 0.21)
      ..cubicTo(s * 0.57, s * 0.30, s * 0.57, s * 0.39, s * 0.52, s * 0.44)
      ..lineTo(s * 0.48, s * 0.44)
      ..cubicTo(s * 0.43, s * 0.39, s * 0.43, s * 0.30, s * 0.50, s * 0.21)
      ..close();
    canvas.drawPath(innerFlame, Paint()..color = flameCore);

    // 2. Marble altar shaft with split light/shadow shading
    final shaftRect = Rect.fromLTRB(s * 0.25, s * 0.53, s * 0.75, s * 0.80);
    canvas.drawRect(
      shaftRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [marbleLight, marbleMid, marbleDark],
        ).createShader(shaftRect),
    );
    canvas.drawRect(shaftRect, outline);
    canvas.drawLine(Offset(s * 0.38, s * 0.56), Offset(s * 0.38, s * 0.77), detail);
    canvas.drawLine(Offset(s * 0.62, s * 0.56), Offset(s * 0.62, s * 0.77), detail);

    // 3. Golden-trimmed top altar slab & base plinth
    final topSlab = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.14, s * 0.43, s * 0.86, s * 0.535),
      Radius.circular(s * 0.03),
    );
    final botPlinth = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.16, s * 0.79, s * 0.84, s * 0.895),
      Radius.circular(s * 0.03),
    );
    for (final slab in [topSlab, botPlinth]) {
      canvas.drawRRect(
        slab,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [goldLight, goldMid],
          ).createShader(slab.outerRect),
      );
      canvas.drawRRect(slab, outline);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_OfferingsAltarPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Tab 3 — Transmute: Sacred Transmutation Prism / Star with interlocking
/// triangles in cyan-gold and curved orbital conversion arcs.
class HolyTransmuteIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const HolyTransmuteIcon({
    super.key,
    this.size = 20.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: _HolyTransmutePainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _HolyTransmutePainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _HolyTransmutePainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, isOnGoldBackground: isOnGoldBackground);

    final goldLight =
        isOnGoldBackground ? const Color(0xFF37474F) : const Color(0xFFFFE082);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFFFFB300);
    final cyanLight =
        isOnGoldBackground ? const Color(0xFF00ACC1) : const Color(0xFF80F3FF);
    final cyanDark =
        isOnGoldBackground ? const Color(0xFF006064) : const Color(0xFF00B0FF);
    final arcColor =
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFFFFE082);

    canvas.save();
    canvas.translate(ox, oy);

    final center = Offset(s * 0.50, s * 0.50);
    final r = s * 0.34;

    Path buildTriangle(double startAngle) {
      final path = Path();
      for (int i = 0; i < 3; i++) {
        final a = startAngle + i * (2 * math.pi / 3);
        final pt = center + Offset(math.cos(a), math.sin(a)) * r;
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      return path;
    }

    // 1. Subtle curved orbital conversion arcs outside the star
    final arcRect = Rect.fromCircle(center: center, radius: s * 0.42);
    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.85, 1.15 * scale)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -math.pi * 0.72, math.pi * 0.48, false, arcPaint);
    canvas.drawArc(arcRect, math.pi * 0.28, math.pi * 0.48, false, arcPaint);

    // 2. Downward triangle (cyan crystalline tone)
    final downTri = buildTriangle(math.pi / 2);
    canvas.drawPath(
      downTri,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cyanLight, cyanDark],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawPath(downTri, outline);

    // 3. Upward interlocking triangle (golden / charcoal prism frame)
    final upTri = buildTriangle(-math.pi / 2);
    canvas.drawPath(
      upTri,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [goldLight, goldDark],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawPath(upTri, outline);

    // 4. Inner glowing cyan core diamond
    final coreR = s * 0.12;
    final corePath = Path()
      ..moveTo(center.dx, center.dy - coreR)
      ..lineTo(center.dx + coreR, center.dy)
      ..lineTo(center.dx, center.dy + coreR)
      ..lineTo(center.dx - coreR, center.dy)
      ..close();
    canvas.drawPath(
      corePath,
      Paint()
        ..shader = LinearGradient(
          colors: [cyanLight, cyanDark],
        ).createShader(Rect.fromCircle(center: center, radius: coreR)),
    );
    canvas.drawPath(corePath, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HolyTransmutePainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Tab 4 — Adoration: Ornate Golden Harp / Lyre with curved golden frame,
/// sculpted pedestal base, and crisp ivory strings.
class AdorationHarpIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const AdorationHarpIcon({
    super.key,
    this.size = 20.0,
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
    final outline = _outlinePaint(scale, isOnGoldBackground: isOnGoldBackground);

    final goldLight =
        isOnGoldBackground ? const Color(0xFF37474F) : const Color(0xFFFFE082);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFFFFB300);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFFB27B00);
    final stringColor =
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFFFAF6EE);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Crisp ivory strings inside the lyre frame
    final stringPaint = Paint()
      ..color = stringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, 0.95 * scale)
      ..strokeCap = StrokeCap.round;
    for (final sx in [s * 0.36, s * 0.453, s * 0.547, s * 0.64]) {
      canvas.drawLine(Offset(sx, s * 0.23), Offset(sx, s * 0.77), stringPaint);
    }

    // 2. Curved golden yoke crossbar across the top
    final yokePath = Path()
      ..moveTo(s * 0.23, s * 0.21)
      ..quadraticBezierTo(s * 0.50, s * 0.14, s * 0.77, s * 0.21)
      ..lineTo(s * 0.75, s * 0.28)
      ..quadraticBezierTo(s * 0.50, s * 0.22, s * 0.25, s * 0.28)
      ..close();
    canvas.drawPath(
      yokePath,
      Paint()
        ..shader = LinearGradient(
          colors: [goldLight, goldMid, goldDark],
        ).createShader(Rect.fromLTRB(s * 0.23, s * 0.14, s * 0.77, s * 0.28)),
    );
    canvas.drawPath(yokePath, outline);

    // 3. Curved golden left & right lyre arms
    for (final isLeft in [true, false]) {
      final sign = isLeft ? -1.0 : 1.0;
      final armPath = Path()
        ..moveTo(s * (0.50 + sign * 0.23), s * 0.24)
        ..cubicTo(
          s * (0.50 + sign * 0.39),
          s * 0.34,
          s * (0.50 + sign * 0.36),
          s * 0.64,
          s * (0.50 + sign * 0.18),
          s * 0.77,
        )
        ..lineTo(s * (0.50 + sign * 0.11), s * 0.77)
        ..cubicTo(
          s * (0.50 + sign * 0.27),
          s * 0.62,
          s * (0.50 + sign * 0.29),
          s * 0.36,
          s * (0.50 + sign * 0.17),
          s * 0.26,
        )
        ..close();
      canvas.drawPath(
        armPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isLeft ? [goldLight, goldMid] : [goldMid, goldDark],
          ).createShader(Rect.fromLTRB(s * 0.12, s * 0.24, s * 0.88, s * 0.78)),
      );
      canvas.drawPath(armPath, outline);
    }

    // 4. Sculpted golden pedestal base
    final basePath = Path()
      ..moveTo(s * 0.31, s * 0.75)
      ..lineTo(s * 0.69, s * 0.75)
      ..lineTo(s * 0.76, s * 0.89)
      ..lineTo(s * 0.24, s * 0.89)
      ..close();
    canvas.drawPath(
      basePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [goldLight, goldMid, goldDark],
        ).createShader(Rect.fromLTRB(s * 0.24, s * 0.75, s * 0.76, s * 0.89)),
    );
    canvas.drawPath(basePath, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_AdorationHarpPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Tab 5 — Prayer: Stylized Praying Hands pressed together in devotion with
/// ivory-gold robe cuffs and a small luminous golden halo above the fingertips.
class PrayerHandsIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const PrayerHandsIcon({
    super.key,
    this.size = 20.0,
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
    final outline = _outlinePaint(scale, isOnGoldBackground: isOnGoldBackground);
    final detail = _detailPaint(scale, isOnGoldBackground: isOnGoldBackground);

    final palmLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFFAF6EE);
    final palmMid =
        isOnGoldBackground ? const Color(0xFF37474F) : const Color(0xFFE6DEC8);
    final palmDark =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFFC8B898);
    final cuffLight =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFFFFE082);
    final cuffDark =
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFFFFB300);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Small luminous halo ring above fingertips
    final haloRect = Rect.fromCenter(
      center: Offset(s * 0.50, s * 0.145),
      width: s * 0.42,
      height: s * 0.12,
    );
    canvas.drawOval(
      haloRect,
      Paint()
        ..color = isOnGoldBackground
            ? const Color(0xFF1A2226)
            : const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, 2.0 * scale),
    );
    if (!isOnGoldBackground) {
      canvas.drawOval(
        haloRect,
        Paint()
          ..color = const Color(0xFFFFE082)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.7, 0.9 * scale),
      );
    }

    // 2. Pressed praying hands silhouette (symmetrical left & right palms)
    final handsPath = Path()
      ..moveTo(s * 0.50, s * 0.25)
      ..cubicTo(s * 0.57, s * 0.28, s * 0.67, s * 0.54, s * 0.72, s * 0.73)
      ..lineTo(s * 0.28, s * 0.73)
      ..cubicTo(s * 0.33, s * 0.54, s * 0.43, s * 0.28, s * 0.50, s * 0.25)
      ..close();
    canvas.drawPath(
      handsPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [palmLight, palmMid, palmDark],
        ).createShader(Rect.fromLTRB(s * 0.28, s * 0.25, s * 0.72, s * 0.73)),
    );
    canvas.drawPath(handsPath, outline);

    // Center palm prayer crease
    canvas.drawLine(Offset(s * 0.50, s * 0.26), Offset(s * 0.50, s * 0.73), detail);

    // 3. Ivory-gold flared robe cuffs at bottom wrists
    final leftCuff = Path()
      ..moveTo(s * 0.24, s * 0.72)
      ..lineTo(s * 0.49, s * 0.72)
      ..lineTo(s * 0.47, s * 0.89)
      ..lineTo(s * 0.16, s * 0.89)
      ..close();
    final rightCuff = Path()
      ..moveTo(s * 0.51, s * 0.72)
      ..lineTo(s * 0.76, s * 0.72)
      ..lineTo(s * 0.84, s * 0.89)
      ..lineTo(s * 0.53, s * 0.89)
      ..close();
    for (final cuff in [leftCuff, rightCuff]) {
      canvas.drawPath(
        cuff,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [cuffLight, cuffDark],
          ).createShader(Rect.fromLTRB(s * 0.16, s * 0.72, s * 0.84, s * 0.89)),
      );
      canvas.drawPath(cuff, outline);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PrayerHandsPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

// =============================================================================
// 9 MODAL HEADER & INTERNAL WING ACCENT ICONS (size: 22–26)
// =============================================================================

/// Modal Header Emblem: Classical golden-and-ivory pillared temple sanctuary.
class SacredTempleEmblemIcon extends StatelessWidget {
  final double size;

  const SacredTempleEmblemIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: const _SacredTempleEmblemPainter(),
    );
  }
}

class _SacredTempleEmblemPainter extends CustomPainter {
  const _SacredTempleEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale);

    canvas.save();
    canvas.translate(ox, oy);

    // Inner dark sanctuary backdrop behind columns
    canvas.drawRect(
      Rect.fromLTRB(s * 0.22, s * 0.38, s * 0.78, s * 0.80),
      Paint()..color = const Color(0xFF263238),
    );

    // 3 ivory marble pillars
    for (final cx in [s * 0.26, s * 0.50, s * 0.74]) {
      final colRect = Rect.fromCenter(
        center: Offset(cx, s * 0.59),
        width: s * 0.13,
        height: s * 0.41,
      );
      canvas.drawRect(
        colRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFAF6EE), Color(0xFFE6DEC8), Color(0xFFBDB097)],
          ).createShader(colRect),
      );
      canvas.drawRect(colRect, outline);
    }

    // Stepped stone & gold base plinth
    final baseUpper = Rect.fromLTRB(s * 0.14, s * 0.78, s * 0.86, s * 0.85);
    final baseLower = Rect.fromLTRB(s * 0.10, s * 0.85, s * 0.90, s * 0.92);
    canvas.drawRect(baseUpper, Paint()..color = const Color(0xFFE6DEC8));
    canvas.drawRect(baseUpper, outline);
    canvas.drawRect(
      baseLower,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFB27B00)],
        ).createShader(baseLower),
    );
    canvas.drawRect(baseLower, outline);

    // Classical golden-trimmed pediment roof
    final roofPath = Path()
      ..moveTo(s * 0.50, s * 0.11)
      ..lineTo(s * 0.90, s * 0.39)
      ..lineTo(s * 0.10, s * 0.39)
      ..close();
    canvas.drawPath(
      roofPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFD97B12)],
        ).createShader(Rect.fromLTRB(s * 0.10, s * 0.11, s * 0.90, s * 0.39)),
    );
    canvas.drawPath(roofPath, outline);

    // Luminous cyan sanctuary orb inside pediment
    canvas.drawCircle(
      Offset(s * 0.50, s * 0.285),
      s * 0.06,
      Paint()..color = const Color(0xFF00E5FF),
    );
    canvas.drawCircle(Offset(s * 0.50, s * 0.285), s * 0.06, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SacredTempleEmblemPainter oldDelegate) => false;
}

/// Wing 1 — `+1 Max HP`: Faceted crimson ruby heart framed in a golden halo.
class VitalityHeartIcon extends StatelessWidget {
  final double size;

  const VitalityHeartIcon({super.key, this.size = 22.0});

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
    final outline = _outlinePaint(scale);

    canvas.save();
    canvas.translate(ox, oy);

    // Golden halo ring framing the heart
    final center = Offset(s * 0.50, s * 0.50);
    canvas.drawCircle(
      center,
      s * 0.41,
      Paint()
        ..color = const Color(0xFFFFE082).withValues(alpha: 0.26),
    );
    canvas.drawCircle(
      center,
      s * 0.41,
      Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, 1.6 * scale),
    );
    canvas.drawCircle(center, s * 0.43, _detailPaint(scale, alpha: 0.55));

    // Faceted crimson ruby heart
    final heart = Path()
      ..moveTo(s * 0.50, s * 0.37)
      ..cubicTo(s * 0.44, s * 0.25, s * 0.22, s * 0.26, s * 0.22, s * 0.45)
      ..cubicTo(s * 0.22, s * 0.62, s * 0.42, s * 0.72, s * 0.50, s * 0.80)
      ..cubicTo(s * 0.58, s * 0.72, s * 0.78, s * 0.62, s * 0.78, s * 0.45)
      ..cubicTo(s * 0.78, s * 0.26, s * 0.56, s * 0.25, s * 0.50, s * 0.37)
      ..close();
    canvas.drawPath(
      heart,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6E6E), Color(0xFFE53935), Color(0xFFB71C1C)],
        ).createShader(Rect.fromLTRB(s * 0.22, s * 0.26, s * 0.78, s * 0.80)),
    );
    canvas.drawPath(heart, outline);

    // Specular glint
    canvas.drawCircle(
      Offset(s * 0.36, s * 0.42),
      s * 0.045,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_VitalityHeartPainter oldDelegate) => false;
}

/// Wing 1 — `+1 Max Mana Pool`: Faceted sapphire-cyan mana droplet crystal in a
/// golden bezel.
class ManaDropIcon extends StatelessWidget {
  final double size;

  const ManaDropIcon({super.key, this.size = 22.0});

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
    final outline = _outlinePaint(scale);
    final detail = _detailPaint(scale, alpha: 0.5);

    canvas.save();
    canvas.translate(ox, oy);

    Path buildDrop(double pad) {
      final t = pad;
      return Path()
        ..moveTo(s * 0.50, s * (0.10 + t * 1.1))
        ..cubicTo(
          s * (0.70 - t * 0.4),
          s * 0.38,
          s * (0.83 - t),
          s * 0.55,
          s * (0.83 - t),
          s * 0.65,
        )
        ..arcToPoint(
          Offset(s * (0.17 + t), s * 0.65),
          radius: Radius.circular(s * (0.33 - t)),
          clockwise: true,
        )
        ..cubicTo(
          s * (0.17 + t),
          s * 0.55,
          s * (0.30 + t * 0.4),
          s * 0.38,
          s * 0.50,
          s * (0.10 + t * 1.1),
        )
        ..close();
    }

    // Golden bezel
    final outerDrop = buildDrop(0.0);
    canvas.drawPath(
      outerDrop,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFB27B00)],
        ).createShader(Rect.fromLTRB(s * 0.17, s * 0.10, s * 0.83, s * 0.92)),
    );
    canvas.drawPath(outerDrop, outline);

    // Faceted sapphire-cyan mana droplet inside
    final innerDrop = buildDrop(0.06);
    canvas.drawPath(
      innerDrop,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB2F5FF), Color(0xFF00E5FF), Color(0xFF0277BD)],
        ).createShader(Rect.fromLTRB(s * 0.23, s * 0.16, s * 0.77, s * 0.88)),
    );
    canvas.drawLine(Offset(s * 0.50, s * 0.20), Offset(s * 0.50, s * 0.85), detail);
    canvas.drawPath(innerDrop, outline);

    canvas.drawCircle(
      Offset(s * 0.40, s * 0.58),
      s * 0.045,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ManaDropPainter oldDelegate) => false;
}

/// Wing 2 — `Altar of Offerings`: Radiant golden-and-cyan star relic icon.
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
    final outline = _outlinePaint(scale);

    canvas.save();
    canvas.translate(ox, oy);

    final c = Offset(s * 0.50, s * 0.50);

    // Outer subtle metallic ring
    canvas.drawCircle(
      c,
      s * 0.34,
      Paint()
        ..color = const Color(0xFFFFB300).withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      c,
      s * 0.34,
      Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.1, 1.5 * scale),
    );

    // 4-point golden star burst
    final star = Path();
    const pts = 8;
    for (int i = 0; i < pts; i++) {
      final r = i.isEven ? s * 0.44 : s * 0.17;
      final a = -math.pi / 2 + i * (math.pi / 4);
      final pt = c + Offset(math.cos(a), math.sin(a)) * r;
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
          colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFD97B12)],
        ).createShader(Rect.fromCircle(center: c, radius: s * 0.44)),
    );
    canvas.drawPath(star, outline);

    // Inner faceted cyan crystal core
    final coreR = s * 0.14;
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
          colors: [Color(0xFF80F3FF), Color(0xFF00B0FF)],
        ).createShader(Rect.fromCircle(center: c, radius: coreR)),
    );
    canvas.drawPath(core, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SacredRelicPainter oldDelegate) => false;
}

/// Wing 3 — `Holy Transmutation (3 → 1)`: Sacred geometric runic conversion circle.
class TransmuteCircleIcon extends StatelessWidget {
  final double size;

  const TransmuteCircleIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return _TempleVectorIcon(
      size: size,
      painter: const _TransmuteCirclePainter(),
    );
  }
}

class _TransmuteCirclePainter extends CustomPainter {
  const _TransmuteCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale);

    canvas.save();
    canvas.translate(ox, oy);

    final c = Offset(s * 0.50, s * 0.50);
    final r = s * 0.39;

    // Arcane indigo circle disc
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF28194E), Color(0xFF151926)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Outer golden runic ring
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, 2.0 * scale),
    );
    canvas.drawCircle(c, r + s * 0.025, outline);

    // Inscribed cyan geometric conversion triangle
    final triR = s * 0.28;
    final tri = Path();
    for (int i = 0; i < 3; i++) {
      final a = -math.pi / 2 + i * (2 * math.pi / 3);
      final pt = c + Offset(math.cos(a), math.sin(a)) * triR;
      if (i == 0) {
        tri.moveTo(pt.dx, pt.dy);
      } else {
        tri.lineTo(pt.dx, pt.dy);
      }
    }
    tri.close();
    canvas.drawPath(
      tri,
      Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, 1.3 * scale),
    );

    // 3 elemental vertex nodes on triangle points
    const nodeColors = [
      Color(0xFFFF5722),
      Color(0xFF00E5FF),
      Color(0xFF4CAF50),
    ];
    for (int i = 0; i < 3; i++) {
      final a = -math.pi / 2 + i * (2 * math.pi / 3);
      final pt = c + Offset(math.cos(a), math.sin(a)) * triR;
      canvas.drawCircle(pt, s * 0.065, Paint()..color = nodeColors[i]);
      canvas.drawCircle(pt, s * 0.065, outline);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TransmuteCirclePainter oldDelegate) => false;
}

/// Wing 4 — `All-Element Orb Bundles`: Golden-trimmed sacred reliquary chest/pouch
/// overflowing with colorful elemental orbs.
class ReliquaryBundleIcon extends StatelessWidget {
  final double size;

  const ReliquaryBundleIcon({super.key, this.size = 22.0});

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
    final outline = _outlinePaint(scale);

    canvas.save();
    canvas.translate(ox, oy);

    // Overflowing colorful orbs peeking from top
    final orbs = [
      (Offset(s * 0.32, s * 0.31), const Color(0xFFFF8A65), const Color(0xFFFF5722)),
      (Offset(s * 0.50, s * 0.25), const Color(0xFF80F3FF), const Color(0xFF00B0FF)),
      (Offset(s * 0.68, s * 0.31), const Color(0xFFA5D6A7), const Color(0xFF4CAF50)),
    ];
    for (final orb in orbs) {
      final r = s * 0.125;
      canvas.drawCircle(
        orb.$1,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: [orb.$2, orb.$3],
          ).createShader(Rect.fromCircle(center: orb.$1, radius: r)),
      );
      canvas.drawCircle(orb.$1, r, outline);
    }

    // Golden-trimmed sacred reliquary vessel body
    final vesselPath = Path()
      ..moveTo(s * 0.16, s * 0.40)
      ..lineTo(s * 0.84, s * 0.40)
      ..lineTo(s * 0.78, s * 0.86)
      ..lineTo(s * 0.22, s * 0.86)
      ..close();
    canvas.drawPath(
      vesselPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFA6662E), Color(0xFF8D5524), Color(0xFF6D3F18)],
        ).createShader(Rect.fromLTRB(s * 0.16, s * 0.40, s * 0.84, s * 0.86)),
    );
    canvas.drawPath(vesselPath, outline);

    // Golden rim & vertical straps
    final rim = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.13, s * 0.36, s * 0.87, s * 0.45),
      Radius.circular(s * 0.03),
    );
    canvas.drawRRect(
      rim,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFB27B00)],
        ).createShader(rim.outerRect),
    );
    canvas.drawRRect(rim, outline);

    final clasp = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(s * 0.50, s * 0.56), width: s * 0.15, height: s * 0.16),
      Radius.circular(s * 0.03),
    );
    canvas.drawRRect(clasp, Paint()..color = const Color(0xFFFFB300));
    canvas.drawRRect(clasp, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ReliquaryBundlePainter oldDelegate) => false;
}

/// Wing 4 — `Single-Element Bulk Packs`: Faceted elemental crystal spire.
class ElementalCrystalIcon extends StatelessWidget {
  final double size;

  const ElementalCrystalIcon({super.key, this.size = 22.0});

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
    final outline = _outlinePaint(scale);
    final detail = _detailPaint(scale, alpha: 0.55);

    canvas.save();
    canvas.translate(ox, oy);

    // Faceted crystal spire
    final top = Offset(s * 0.50, s * 0.09);
    final ul = Offset(s * 0.25, s * 0.36);
    final ur = Offset(s * 0.75, s * 0.36);
    final bl = Offset(s * 0.30, s * 0.78);
    final br = Offset(s * 0.70, s * 0.78);

    final full = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(ur.dx, ur.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..lineTo(ul.dx, ul.dy)
      ..close();

    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(s * 0.50, s * 0.48)
        ..lineTo(ul.dx, ul.dy)
        ..close(),
      Paint()..color = const Color(0xFFB2F5FF),
    );
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(ur.dx, ur.dy)
        ..lineTo(s * 0.50, s * 0.48)
        ..close(),
      Paint()..color = const Color(0xFF00E5FF),
    );
    canvas.drawPath(
      Path()
        ..moveTo(ul.dx, ul.dy)
        ..lineTo(s * 0.50, s * 0.48)
        ..lineTo(s * 0.50, s * 0.78)
        ..lineTo(bl.dx, bl.dy)
        ..close(),
      Paint()..color = const Color(0xFF00B0FF),
    );
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.50, s * 0.48)
        ..lineTo(ur.dx, ur.dy)
        ..lineTo(br.dx, br.dy)
        ..lineTo(s * 0.50, s * 0.78)
        ..close(),
      Paint()..color = const Color(0xFF0277BD),
    );
    canvas.drawLine(ul, Offset(s * 0.50, s * 0.48), detail);
    canvas.drawLine(ur, Offset(s * 0.50, s * 0.48), detail);
    canvas.drawLine(top, Offset(s * 0.50, s * 0.78), detail);
    canvas.drawPath(full, outline);

    // Golden base setting collar
    final collar = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.25, s * 0.75, s * 0.75, s * 0.90),
      Radius.circular(s * 0.04),
    );
    canvas.drawRRect(
      collar,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFB27B00)],
        ).createShader(collar.outerRect),
    );
    canvas.drawRRect(collar, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ElementalCrystalPainter oldDelegate) => false;
}

/// Wing 5 — `Meditation for Free Orbs (Watch Ad +50 Orbs)`: Radiant golden
/// sun/meditation halo icon.
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
    final outline = _outlinePaint(scale);

    canvas.save();
    canvas.translate(ox, oy);

    final c = Offset(s * 0.50, s * 0.50);

    // 8 radiant golden sunbeams
    final rayPaint = Paint()
      ..color = const Color(0xFFFFB300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.3, 1.8 * scale)
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final a = i * (math.pi / 4);
      final innerR = s * 0.30;
      final outerR = i.isEven ? s * 0.45 : s * 0.40;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * innerR,
        c + Offset(math.cos(a), math.sin(a)) * outerR,
        rayPaint,
      );
    }

    // Concentric golden sun disc
    canvas.drawCircle(
      c,
      s * 0.25,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.25, -0.25),
          colors: [Color(0xFFFFF8E1), Color(0xFFFFE082), Color(0xFFFFB300)],
        ).createShader(Rect.fromCircle(center: c, radius: s * 0.25)),
    );
    canvas.drawCircle(c, s * 0.25, outline);

    // Inner serene cyan-gold meditation core
    canvas.drawCircle(
      c,
      s * 0.10,
      Paint()..color = const Color(0xFF00E5FF),
    );
    canvas.drawCircle(c, s * 0.10, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MeditationHaloPainter oldDelegate) => false;
}

/// Wing 5 — `Pre-Battle Sacred Blessings`: Winged golden-and-ivory blessing
/// shield/cross.
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
    final outline = _outlinePaint(scale);

    canvas.save();
    canvas.translate(ox, oy);

    // Symmetrical swept ivory-gold angel wings flanking the shield
    for (final isLeft in [true, false]) {
      final sign = isLeft ? -1.0 : 1.0;
      final wing = Path()
        ..moveTo(s * (0.50 + sign * 0.18), s * 0.36)
        ..cubicTo(
          s * (0.50 + sign * 0.44),
          s * 0.20,
          s * (0.50 + sign * 0.46),
          s * 0.42,
          s * (0.50 + sign * 0.36),
          s * 0.56,
        )
        ..lineTo(s * (0.50 + sign * 0.20), s * 0.62)
        ..close();
      canvas.drawPath(
        wing,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isLeft
                ? const [Color(0xFFFAF6EE), Color(0xFFE6DEC8)]
                : const [Color(0xFFE6DEC8), Color(0xFFC8B898)],
          ).createShader(Rect.fromLTRB(s * 0.05, s * 0.20, s * 0.95, s * 0.64)),
      );
      canvas.drawPath(wing, outline);
    }

    // Central golden-trimmed heater shield
    final shield = Path()
      ..moveTo(s * 0.50, s * 0.16)
      ..lineTo(s * 0.74, s * 0.25)
      ..cubicTo(s * 0.74, s * 0.58, s * 0.63, s * 0.78, s * 0.50, s * 0.87)
      ..cubicTo(s * 0.37, s * 0.78, s * 0.26, s * 0.58, s * 0.26, s * 0.25)
      ..close();
    canvas.drawPath(
      shield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFD97B12)],
        ).createShader(Rect.fromLTRB(s * 0.26, s * 0.16, s * 0.74, s * 0.87)),
    );
    canvas.drawPath(shield, outline);

    // Radiant ivory-white sacred cross inside shield
    final crossPaint = Paint()
      ..color = const Color(0xFFFAF6EE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, 2.3 * scale)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s * 0.50, s * 0.33), Offset(s * 0.50, s * 0.69), crossPaint);
    canvas.drawLine(Offset(s * 0.37, s * 0.47), Offset(s * 0.63, s * 0.47), crossPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SacredBlessingPainter oldDelegate) => false;
}
