import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shared helper wrapper matching [RoyalCastleIcon] so every custom vector icon
/// renders cleanly at a fixed square dimension inside a [RepaintBoundary].
class _CastleVectorIcon extends StatelessWidget {
  final double size;
  final CustomPainter painter;

  const _CastleVectorIcon({
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

Paint _detailPaint(double scale, {bool isOnGoldBackground = false, double alpha = 0.72}) {
  return Paint()
    ..color = _outlineColor(isOnGoldBackground).withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.45, 0.70 * scale)
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
}

// =============================================================================
// 6 NAVIGATION TAB ICONS (Accepting `size` & `bool isOnGoldBackground`)
// =============================================================================

/// Tab 1 — Throne: Jeweled Royal Crown with 3 peaks, spheres, and center ruby.
class ThroneCrownIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const ThroneCrownIcon({
    super.key,
    this.size = 20.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _CastleVectorIcon(
      size: size,
      painter: _ThroneCrownPainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _ThroneCrownPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _ThroneCrownPainter({required this.isOnGoldBackground});

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
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFFD97B12);
    final rubyLight =
        isOnGoldBackground ? const Color(0xFFD32F2F) : const Color(0xFFFF6E6E);
    final rubyDark =
        isOnGoldBackground ? const Color(0xFF7F1D1D) : const Color(0xFFC62828);
    final sideGem =
        isOnGoldBackground ? const Color(0xFF00838F) : const Color(0xFF00E5FF);

    canvas.save();
    canvas.translate(ox, oy);

    // Crown upper body (3 triangular peaks)
    final bodyPath = Path()
      ..moveTo(s * 0.16, s * 0.68)
      ..lineTo(s * 0.14, s * 0.30)
      ..lineTo(s * 0.34, s * 0.50)
      ..lineTo(s * 0.50, s * 0.21)
      ..lineTo(s * 0.66, s * 0.50)
      ..lineTo(s * 0.86, s * 0.30)
      ..lineTo(s * 0.84, s * 0.68)
      ..close();

    final bodyRect = Rect.fromLTRB(s * 0.14, s * 0.21, s * 0.86, s * 0.68);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [goldLight, goldMid, goldDark],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(bodyRect),
    );
    canvas.drawPath(bodyPath, outline);

    // Crown curved base band
    final bandPath = Path()
      ..moveTo(s * 0.14, s * 0.65)
      ..quadraticBezierTo(s * 0.50, s * 0.69, s * 0.86, s * 0.65)
      ..lineTo(s * 0.84, s * 0.81)
      ..quadraticBezierTo(s * 0.50, s * 0.86, s * 0.16, s * 0.81)
      ..close();

    final bandRect = Rect.fromLTRB(s * 0.14, s * 0.65, s * 0.86, s * 0.86);
    canvas.drawPath(
      bandPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [goldLight, goldMid, goldDark],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bandRect),
    );
    canvas.drawPath(bandPath, outline);

    // Peak spheres
    final sphereCenters = [
      Offset(s * 0.14, s * 0.27),
      Offset(s * 0.50, s * 0.175),
      Offset(s * 0.86, s * 0.27),
    ];
    for (int i = 0; i < sphereCenters.length; i++) {
      final r = i == 1 ? s * 0.062 : s * 0.052;
      final c = sphereCenters[i];
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            colors: [goldLight, goldMid, goldDark],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      canvas.drawCircle(c, r, outline);
    }

    // Center faceted ruby gem
    final gemCenter = Offset(s * 0.50, s * 0.56);
    final gemPath = Path()
      ..moveTo(gemCenter.dx, gemCenter.dy - s * 0.105)
      ..lineTo(gemCenter.dx + s * 0.085, gemCenter.dy)
      ..lineTo(gemCenter.dx, gemCenter.dy + s * 0.105)
      ..lineTo(gemCenter.dx - s * 0.085, gemCenter.dy)
      ..close();
    canvas.drawPath(
      gemPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [rubyLight, rubyDark],
        ).createShader(Rect.fromCircle(center: gemCenter, radius: s * 0.10)),
    );
    canvas.drawPath(gemPath, outline);

    // Side cyan rivets on band
    for (final cx in [s * 0.30, s * 0.70]) {
      final pos = Offset(cx, s * 0.74);
      canvas.drawCircle(pos, s * 0.04, Paint()..color = sideGem);
      canvas.drawCircle(pos, s * 0.04, _detailPaint(scale, isOnGoldBackground: isOnGoldBackground));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThroneCrownPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Tab 2 — Library: Open Arcane Tome with burgundy leather cover, curved ivory
/// pages with script lines, and hanging golden bookmark ribbon.
class LibraryTomeIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const LibraryTomeIcon({
    super.key,
    this.size = 20.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _CastleVectorIcon(
      size: size,
      painter: _LibraryTomePainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _LibraryTomePainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _LibraryTomePainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, isOnGoldBackground: isOnGoldBackground);
    final detail = _detailPaint(scale, isOnGoldBackground: isOnGoldBackground);

    final coverLight =
        isOnGoldBackground ? const Color(0xFF4A2511) : const Color(0xFF8D5524);
    final coverDark =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFF6D3F18);
    final pageLeft =
        isOnGoldBackground ? const Color(0xFF37474F) : const Color(0xFFFAF6EE);
    final pageLeftShade =
        isOnGoldBackground ? const Color(0xFF2C3A41) : const Color(0xFFEAE2D3);
    final pageRight =
        isOnGoldBackground ? const Color(0xFF2C3A41) : const Color(0xFFF0E9DA);
    final pageRightShade =
        isOnGoldBackground ? const Color(0xFF1F2A30) : const Color(0xFFD5C9B4);
    final ribbonTop =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFFFFE082);
    final ribbonBot =
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFFFFB300);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Hanging golden bookmark ribbon below spine
    final ribbonPath = Path()
      ..moveTo(s * 0.455, s * 0.68)
      ..lineTo(s * 0.545, s * 0.68)
      ..lineTo(s * 0.545, s * 0.92)
      ..lineTo(s * 0.50, s * 0.855)
      ..lineTo(s * 0.455, s * 0.92)
      ..close();
    canvas.drawPath(
      ribbonPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ribbonTop, ribbonBot],
        ).createShader(Rect.fromLTRB(s * 0.45, s * 0.68, s * 0.55, s * 0.92)),
    );
    canvas.drawPath(ribbonPath, outline);

    // 2. Burgundy-leather outer cover
    final coverPath = Path()
      ..moveTo(s * 0.07, s * 0.28)
      ..lineTo(s * 0.50, s * 0.34)
      ..lineTo(s * 0.93, s * 0.28)
      ..lineTo(s * 0.93, s * 0.74)
      ..lineTo(s * 0.50, s * 0.80)
      ..lineTo(s * 0.07, s * 0.74)
      ..close();
    canvas.drawPath(
      coverPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [coverLight, coverDark],
        ).createShader(Rect.fromLTRB(s * 0.07, s * 0.28, s * 0.93, s * 0.80)),
    );
    canvas.drawPath(coverPath, outline);

    // 3. Left curved parchment page
    final leftPagePath = Path()
      ..moveTo(s * 0.50, s * 0.30)
      ..quadraticBezierTo(s * 0.32, s * 0.19, s * 0.115, s * 0.235)
      ..lineTo(s * 0.115, s * 0.685)
      ..quadraticBezierTo(s * 0.32, s * 0.645, s * 0.50, s * 0.745)
      ..close();
    canvas.drawPath(
      leftPagePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [pageLeft, pageLeftShade],
        ).createShader(Rect.fromLTRB(s * 0.11, s * 0.20, s * 0.50, s * 0.75)),
    );
    canvas.drawPath(leftPagePath, outline);

    // 4. Right curved parchment page
    final rightPagePath = Path()
      ..moveTo(s * 0.50, s * 0.30)
      ..quadraticBezierTo(s * 0.68, s * 0.19, s * 0.885, s * 0.235)
      ..lineTo(s * 0.885, s * 0.685)
      ..quadraticBezierTo(s * 0.68, s * 0.645, s * 0.50, s * 0.745)
      ..close();
    canvas.drawPath(
      rightPagePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [pageRightShade, pageRight],
        ).createShader(Rect.fromLTRB(s * 0.50, s * 0.20, s * 0.89, s * 0.75)),
    );
    canvas.drawPath(rightPagePath, outline);

    // 5. Subtle script lines on both pages
    final scriptPaint = Paint()
      ..color = isOnGoldBackground
          ? const Color(0xFF1A2226).withValues(alpha: 0.75)
          : const Color(0xFF6D3F18).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.55, 0.75 * scale)
      ..strokeCap = StrokeCap.round;

    for (final dy in [0.35, 0.47, 0.59]) {
      canvas.drawLine(
        Offset(s * 0.19, s * (dy - 0.02)),
        Offset(s * 0.41, s * (dy + 0.02)),
        scriptPaint,
      );
      canvas.drawLine(
        Offset(s * 0.59, s * (dy + 0.02)),
        Offset(s * 0.81, s * (dy - 0.02)),
        scriptPaint,
      );
    }

    // Center spine crease highlight
    canvas.drawLine(Offset(s * 0.50, s * 0.30), Offset(s * 0.50, s * 0.745), detail);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LibraryTomePainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Tab 3 — Treasury: Royal Treasure Chest in warm wood with slightly ajar lid,
/// golden inner glow beam, golden side bands, and central gold lock.
class TreasuryChestIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const TreasuryChestIcon({
    super.key,
    this.size = 20.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _CastleVectorIcon(
      size: size,
      painter: _TreasuryChestPainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _TreasuryChestPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _TreasuryChestPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, isOnGoldBackground: isOnGoldBackground);

    final woodLight =
        isOnGoldBackground ? const Color(0xFF4A2B11) : const Color(0xFFA6662E);
    final woodMid =
        isOnGoldBackground ? const Color(0xFF36200E) : const Color(0xFF8D5524);
    final woodDark =
        isOnGoldBackground ? const Color(0xFF24170C) : const Color(0xFF6D3F18);
    final goldLight =
        isOnGoldBackground ? const Color(0xFF37474F) : const Color(0xFFFFE082);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFFFFB300);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFFB27B00);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Subtle golden light glow emerging behind ajar lid
    if (!isOnGoldBackground) {
      final glowBeam = Path()
        ..moveTo(s * 0.16, s * 0.48)
        ..lineTo(s * 0.24, s * 0.14)
        ..lineTo(s * 0.76, s * 0.14)
        ..lineTo(s * 0.84, s * 0.48)
        ..close();
      canvas.drawPath(
        glowBeam,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFFFFE082).withValues(alpha: 0.55),
              const Color(0xFFFFB300).withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTRB(s * 0.16, s * 0.14, s * 0.84, s * 0.48)),
      );
    }

    // 2. Lower chest box
    final boxRect = Rect.fromLTRB(s * 0.12, s * 0.50, s * 0.88, s * 0.88);
    final boxRRect = RRect.fromRectAndCorners(
      boxRect,
      bottomLeft: Radius.circular(s * 0.08),
      bottomRight: Radius.circular(s * 0.08),
    );
    canvas.drawRRect(
      boxRRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [woodLight, woodMid, woodDark],
        ).createShader(boxRect),
    );

    // Golden vertical side bands on box
    for (final bx in [s * 0.21, s * 0.71]) {
      final bandRect = Rect.fromLTWH(bx, s * 0.50, s * 0.085, s * 0.38);
      canvas.drawRect(
        bandRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [goldLight, goldMid, goldDark],
          ).createShader(bandRect),
      );
      canvas.drawRect(bandRect, _detailPaint(scale, isOnGoldBackground: isOnGoldBackground));
    }
    canvas.drawRRect(boxRRect, outline);

    // 3. Narrow luminous gap between box & slightly ajar lid
    final gapRect = Rect.fromLTRB(s * 0.14, s * 0.43, s * 0.86, s * 0.505);
    canvas.drawRect(
      gapRect,
      Paint()
        ..color = isOnGoldBackground
            ? const Color(0xFF1A2226)
            : const Color(0xFFFFE082),
    );
    canvas.drawRect(gapRect, outline);

    // 4. Arched wooden lid (slightly lifted / ajar)
    final lidPath = Path()
      ..moveTo(s * 0.11, s * 0.435)
      ..lineTo(s * 0.13, s * 0.28)
      ..quadraticBezierTo(s * 0.50, s * 0.13, s * 0.87, s * 0.28)
      ..lineTo(s * 0.89, s * 0.435)
      ..close();
    final lidBounds = Rect.fromLTRB(s * 0.11, s * 0.17, s * 0.89, s * 0.435);
    canvas.drawPath(
      lidPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [woodLight, woodMid, woodDark],
        ).createShader(lidBounds),
    );

    // Golden straps on lid
    for (final bx in [s * 0.21, s * 0.71]) {
      final strapRect = Rect.fromLTRB(bx, s * 0.23, bx + s * 0.085, s * 0.435);
      canvas.save();
      canvas.clipPath(lidPath);
      canvas.drawRect(
        strapRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [goldLight, goldMid],
          ).createShader(strapRect),
      );
      canvas.drawRect(strapRect, _detailPaint(scale, isOnGoldBackground: isOnGoldBackground));
      canvas.restore();
    }
    canvas.drawPath(lidPath, outline);

    // 5. Central golden lock clasp
    final lockRect = Rect.fromCenter(
      center: Offset(s * 0.50, s * 0.52),
      width: s * 0.16,
      height: s * 0.19,
    );
    final lockRRect = RRect.fromRectAndRadius(lockRect, Radius.circular(s * 0.04));
    canvas.drawRRect(
      lockRRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [goldLight, goldMid, goldDark],
        ).createShader(lockRect),
    );
    canvas.drawRRect(lockRRect, outline);
    canvas.drawCircle(
      Offset(s * 0.50, s * 0.525),
      s * 0.028,
      Paint()
        ..color = isOnGoldBackground
            ? const Color(0xFFF5C22B)
            : const Color(0xFF263238),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TreasuryChestPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Tab 4 — Relics: Angled Sacred Runic Blade with steel-silver blade, ornate
/// golden crossguard, and glowing cyan crystal embedded in the hilt.
class RelicsSwordIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const RelicsSwordIcon({
    super.key,
    this.size = 20.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _CastleVectorIcon(
      size: size,
      painter: _RelicsSwordPainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _RelicsSwordPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _RelicsSwordPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, isOnGoldBackground: isOnGoldBackground);

    final steelLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFECEFF1);
    final steelDark =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFF90A4AE);
    final goldLight =
        isOnGoldBackground ? const Color(0xFF37474F) : const Color(0xFFFFE082);
    final goldMid =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFFFFB300);
    final goldDark =
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFFB27B00);
    final cyanLight =
        isOnGoldBackground ? const Color(0xFF00ACC1) : const Color(0xFF80F3FF);
    final cyanDark =
        isOnGoldBackground ? const Color(0xFF006064) : const Color(0xFF00B0FF);

    canvas.save();
    canvas.translate(ox + s * 0.50, oy + s * 0.50);
    canvas.rotate(math.pi / 4); // Points blade toward top-right

    // 1. Steel double-edged blade (split left-light / right-shadow)
    final bladeLeft = Path()
      ..moveTo(0, -s * 0.52)
      ..lineTo(-s * 0.085, -s * 0.36)
      ..lineTo(-s * 0.085, s * 0.10)
      ..lineTo(0, s * 0.10)
      ..close();
    final bladeRight = Path()
      ..moveTo(0, -s * 0.52)
      ..lineTo(0, s * 0.10)
      ..lineTo(s * 0.085, s * 0.10)
      ..lineTo(s * 0.085, -s * 0.36)
      ..close();
    final bladeFull = Path()
      ..moveTo(0, -s * 0.52)
      ..lineTo(s * 0.085, -s * 0.36)
      ..lineTo(s * 0.085, s * 0.10)
      ..lineTo(-s * 0.085, s * 0.10)
      ..lineTo(-s * 0.085, -s * 0.36)
      ..close();

    canvas.drawPath(bladeLeft, Paint()..color = steelLight);
    canvas.drawPath(bladeRight, Paint()..color = steelDark);
    canvas.drawPath(bladeFull, outline);
    canvas.drawLine(
      Offset(0, -s * 0.42),
      Offset(0, s * 0.06),
      _detailPaint(scale, isOnGoldBackground: isOnGoldBackground),
    );

    // 2. Leather grip & golden pommel
    final gripRect = Rect.fromCenter(
      center: Offset(0, s * 0.25),
      width: s * 0.095,
      height: s * 0.22,
    );
    canvas.drawRect(
      gripRect,
      Paint()
        ..color = isOnGoldBackground
            ? const Color(0xFF1A2226)
            : const Color(0xFF6D3F18),
    );
    canvas.drawRect(gripRect, outline);

    final pommelCenter = Offset(0, s * 0.40);
    final pommelPath = Path()
      ..moveTo(pommelCenter.dx, pommelCenter.dy - s * 0.085)
      ..lineTo(pommelCenter.dx + s * 0.085, pommelCenter.dy)
      ..lineTo(pommelCenter.dx, pommelCenter.dy + s * 0.085)
      ..lineTo(pommelCenter.dx - s * 0.085, pommelCenter.dy)
      ..close();
    canvas.drawPath(
      pommelPath,
      Paint()
        ..shader = LinearGradient(
          colors: [goldLight, goldMid, goldDark],
        ).createShader(Rect.fromCircle(center: pommelCenter, radius: s * 0.09)),
    );
    canvas.drawPath(pommelPath, outline);

    // 3. Ornate golden crossguard
    final guardPath = Path()
      ..moveTo(-s * 0.25, s * 0.05)
      ..quadraticBezierTo(0, s * 0.12, s * 0.25, s * 0.05)
      ..lineTo(s * 0.21, s * 0.16)
      ..quadraticBezierTo(0, s * 0.19, -s * 0.21, s * 0.16)
      ..close();
    canvas.drawPath(
      guardPath,
      Paint()
        ..shader = LinearGradient(
          colors: [goldLight, goldMid, goldDark],
        ).createShader(Rect.fromLTRB(-s * 0.25, s * 0.05, s * 0.25, s * 0.19)),
    );
    canvas.drawPath(guardPath, outline);

    // 4. Glowing cyan crystal embedded in hilt
    final gemCenter = Offset(0, s * 0.125);
    final gemPath = Path()
      ..moveTo(gemCenter.dx, gemCenter.dy - s * 0.075)
      ..lineTo(gemCenter.dx + s * 0.065, gemCenter.dy)
      ..lineTo(gemCenter.dx, gemCenter.dy + s * 0.075)
      ..lineTo(gemCenter.dx - s * 0.065, gemCenter.dy)
      ..close();
    canvas.drawPath(
      gemPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cyanLight, cyanDark],
        ).createShader(Rect.fromCircle(center: gemCenter, radius: s * 0.08)),
    );
    canvas.drawPath(gemPath, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RelicsSwordPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Tab 5 — Spoils: Tied brown leather satchel cinched with a golden cord,
/// with crimson Fire and cyan Water orbs peeking from the top opening.
class SpoilsPouchIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const SpoilsPouchIcon({
    super.key,
    this.size = 20.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _CastleVectorIcon(
      size: size,
      painter: _SpoilsPouchPainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _SpoilsPouchPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _SpoilsPouchPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, isOnGoldBackground: isOnGoldBackground);

    final leatherLight =
        isOnGoldBackground ? const Color(0xFF5D3314) : const Color(0xFFA6662E);
    final leatherMid =
        isOnGoldBackground ? const Color(0xFF3E220D) : const Color(0xFF8D5524);
    final leatherDark =
        isOnGoldBackground ? const Color(0xFF26160A) : const Color(0xFF6D3F18);
    final cordLight =
        isOnGoldBackground ? const Color(0xFF37474F) : const Color(0xFFFFE082);
    final cordMid =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFFFFB300);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Back rim of open leather pouch collar
    final backCollar = Path()
      ..moveTo(s * 0.32, s * 0.39)
      ..lineTo(s * 0.25, s * 0.25)
      ..quadraticBezierTo(s * 0.50, s * 0.20, s * 0.75, s * 0.25)
      ..lineTo(s * 0.68, s * 0.39)
      ..close();
    canvas.drawPath(backCollar, Paint()..color = leatherDark);
    canvas.drawPath(backCollar, outline);

    // 2. Two small glowing orbs peeking out (crimson Fire & cyan Water)
    void drawOrb(Offset center, double r, Color hi, Color mid, Color lo) {
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.32, -0.32),
            colors: [hi, mid, lo],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
      canvas.drawCircle(center, r, outline);
      canvas.drawCircle(
        center + Offset(-r * 0.32, -r * 0.32),
        r * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    drawOrb(
      Offset(s * 0.39, s * 0.27),
      s * 0.125,
      isOnGoldBackground ? const Color(0xFFFF6E6E) : const Color(0xFFFF9E80),
      isOnGoldBackground ? const Color(0xFFC62828) : const Color(0xFFFF5722),
      isOnGoldBackground ? const Color(0xFF7F1D1D) : const Color(0xFFBF360C),
    );
    drawOrb(
      Offset(s * 0.61, s * 0.25),
      s * 0.132,
      isOnGoldBackground ? const Color(0xFF4FC3F7) : const Color(0xFF80F3FF),
      isOnGoldBackground ? const Color(0xFF0288D1) : const Color(0xFF00E5FF),
      isOnGoldBackground ? const Color(0xFF01579B) : const Color(0xFF00838F),
    );

    // 3. Plump leather satchel body + front ruffled collar lip
    final pouchPath = Path()
      ..moveTo(s * 0.32, s * 0.39)
      ..quadraticBezierTo(s * 0.50, s * 0.34, s * 0.68, s * 0.39)
      ..lineTo(s * 0.68, s * 0.43)
      ..cubicTo(s * 0.86, s * 0.52, s * 0.88, s * 0.86, s * 0.64, s * 0.90)
      ..lineTo(s * 0.36, s * 0.90)
      ..cubicTo(s * 0.12, s * 0.86, s * 0.14, s * 0.52, s * 0.32, s * 0.43)
      ..close();

    final pouchBounds = Rect.fromLTRB(s * 0.15, s * 0.36, s * 0.85, s * 0.90);
    canvas.drawPath(
      pouchPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [leatherLight, leatherMid, leatherDark],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(pouchBounds),
    );
    canvas.drawPath(pouchPath, outline);

    // 4. Cinched golden cord around the pouch neck
    final cordRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.29, s * 0.395, s * 0.71, s * 0.465),
      Radius.circular(s * 0.035),
    );
    canvas.drawRRect(
      cordRect,
      Paint()
        ..shader = LinearGradient(
          colors: [cordLight, cordMid],
        ).createShader(cordRect.outerRect),
    );
    canvas.drawRRect(cordRect, outline);

    // Hanging cord knot tails
    final cordDetail = Paint()
      ..color = cordMid
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, 1.6 * scale)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s * 0.49, s * 0.46), Offset(s * 0.43, s * 0.57), outline);
    canvas.drawLine(Offset(s * 0.49, s * 0.46), Offset(s * 0.43, s * 0.57), cordDetail);
    canvas.drawLine(Offset(s * 0.51, s * 0.46), Offset(s * 0.57, s * 0.58), outline);
    canvas.drawLine(Offset(s * 0.51, s * 0.46), Offset(s * 0.57, s * 0.58), cordDetail);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpoilsPouchPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

/// Tab 6 — Heroes: Paladin Steel Helmet with split steel shading, dark T-visor
/// slit, and golden crest plume on top.
class HeroesHelmIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const HeroesHelmIcon({
    super.key,
    this.size = 20.0,
    this.isOnGoldBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return _CastleVectorIcon(
      size: size,
      painter: _HeroesHelmPainter(isOnGoldBackground: isOnGoldBackground),
    );
  }
}

class _HeroesHelmPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _HeroesHelmPainter({required this.isOnGoldBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale, isOnGoldBackground: isOnGoldBackground);

    final steelLight =
        isOnGoldBackground ? const Color(0xFF455A64) : const Color(0xFFECEFF1);
    final steelMid =
        isOnGoldBackground ? const Color(0xFF37474F) : const Color(0xFFCFD8DC);
    final steelDark =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFF90A4AE);
    final crestLight =
        isOnGoldBackground ? const Color(0xFF263238) : const Color(0xFFFFE082);
    final crestDark =
        isOnGoldBackground ? const Color(0xFF1A2226) : const Color(0xFFFFB300);
    final visorColor = const Color(0xFF1A2226);

    canvas.save();
    canvas.translate(ox, oy);

    // 1. Golden crest plume on top
    final crestPath = Path()
      ..moveTo(s * 0.42, s * 0.25)
      ..quadraticBezierTo(s * 0.42, s * 0.09, s * 0.50, s * 0.08)
      ..quadraticBezierTo(s * 0.62, s * 0.09, s * 0.62, s * 0.27)
      ..close();
    canvas.drawPath(
      crestPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [crestLight, crestDark],
        ).createShader(Rect.fromLTRB(s * 0.42, s * 0.08, s * 0.62, s * 0.27)),
    );
    canvas.drawPath(crestPath, outline);

    // 2. Paladin helmet dome & cheek guards
    final helmPath = Path()
      ..moveTo(s * 0.50, s * 0.21)
      ..cubicTo(s * 0.78, s * 0.21, s * 0.82, s * 0.40, s * 0.80, s * 0.68)
      ..lineTo(s * 0.67, s * 0.88)
      ..lineTo(s * 0.33, s * 0.88)
      ..lineTo(s * 0.20, s * 0.68)
      ..cubicTo(s * 0.18, s * 0.40, s * 0.22, s * 0.21, s * 0.50, s * 0.21)
      ..close();

    final helmBounds = Rect.fromLTRB(s * 0.18, s * 0.21, s * 0.82, s * 0.88);
    canvas.drawPath(
      helmPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [steelLight, steelMid, steelDark],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(helmBounds),
    );
    canvas.drawPath(helmPath, outline);

    // Golden brow trim band
    final browPath = Path()
      ..moveTo(s * 0.22, s * 0.42)
      ..lineTo(s * 0.50, s * 0.45)
      ..lineTo(s * 0.78, s * 0.42);
    canvas.drawPath(
      browPath,
      Paint()
        ..color = crestDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, 1.7 * scale)
        ..strokeCap = StrokeCap.round,
    );

    // 3. Dark T-visor slit
    final visorPath = Path()
      ..moveTo(s * 0.27, s * 0.48)
      ..lineTo(s * 0.73, s * 0.48)
      ..lineTo(s * 0.71, s * 0.56)
      ..lineTo(s * 0.555, s * 0.56)
      ..lineTo(s * 0.555, s * 0.83)
      ..lineTo(s * 0.445, s * 0.83)
      ..lineTo(s * 0.445, s * 0.56)
      ..lineTo(s * 0.29, s * 0.56)
      ..close();
    canvas.drawPath(visorPath, Paint()..color = visorColor);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroesHelmPainter oldDelegate) =>
      oldDelegate.isOnGoldBackground != isOnGoldBackground;
}

// =============================================================================
// 9 INTERNAL SECTION ACCENT ICONS (size: 22–26)
// =============================================================================

/// Wing 1 — Royal Decrees: Rolled parchment scroll with a crimson wax seal.
class RoyalScrollIcon extends StatelessWidget {
  final double size;

  const RoyalScrollIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return _CastleVectorIcon(size: size, painter: const _RoyalScrollPainter());
  }
}

class _RoyalScrollPainter extends CustomPainter {
  const _RoyalScrollPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale);
    final detail = _detailPaint(scale);

    canvas.save();
    canvas.translate(ox, oy);

    // Parchment sheet
    final sheetPath = Path()
      ..moveTo(s * 0.22, s * 0.22)
      ..lineTo(s * 0.78, s * 0.22)
      ..lineTo(s * 0.78, s * 0.80)
      ..lineTo(s * 0.22, s * 0.80)
      ..close();
    canvas.drawPath(
      sheetPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFAF6EE), Color(0xFFE6DEC8)],
        ).createShader(Rect.fromLTRB(s * 0.22, s * 0.22, s * 0.78, s * 0.80)),
    );
    canvas.drawPath(sheetPath, outline);

    // Top & bottom curled scroll cylinders
    final topRoll = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.16, s * 0.14, s * 0.84, s * 0.28),
      Radius.circular(s * 0.07),
    );
    final botRoll = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.16, s * 0.74, s * 0.74, s * 0.88),
      Radius.circular(s * 0.07),
    );
    for (final roll in [topRoll, botRoll]) {
      canvas.drawRRect(
        roll,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFAF6EE), Color(0xFFD5C9B4)],
          ).createShader(roll.outerRect),
      );
      canvas.drawRRect(roll, outline);
    }

    // Script lines
    for (final dy in [0.39, 0.51, 0.63]) {
      canvas.drawLine(
        Offset(s * 0.31, s * dy),
        Offset(s * (dy > 0.55 ? 0.54 : 0.68), s * dy),
        detail,
      );
    }

    // Crimson wax seal + ribbon tails
    final ribbonPath = Path()
      ..moveTo(s * 0.62, s * 0.74)
      ..lineTo(s * 0.59, s * 0.93)
      ..lineTo(s * 0.67, s * 0.87)
      ..lineTo(s * 0.75, s * 0.93)
      ..lineTo(s * 0.72, s * 0.74)
      ..close();
    canvas.drawPath(ribbonPath, Paint()..color = const Color(0xFFB71C1C));
    canvas.drawPath(ribbonPath, outline);

    final sealCenter = Offset(s * 0.67, s * 0.71);
    canvas.drawCircle(
      sealCenter,
      s * 0.14,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFFFF6E6E), Color(0xFFE53935), Color(0xFFB71C1C)],
        ).createShader(Rect.fromCircle(center: sealCenter, radius: s * 0.14)),
    );
    canvas.drawCircle(sealCenter, s * 0.14, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoyalScrollPainter oldDelegate) => false;
}

/// Wing 1 — Week 40 Deadline: Ornate golden hourglass with glowing sand.
class GoldenHourglassIcon extends StatelessWidget {
  final double size;

  const GoldenHourglassIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return _CastleVectorIcon(size: size, painter: const _GoldenHourglassPainter());
  }
}

class _GoldenHourglassPainter extends CustomPainter {
  const _GoldenHourglassPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale);

    canvas.save();
    canvas.translate(ox, oy);

    // Glass bulb outline
    final glassPath = Path()
      ..moveTo(s * 0.27, s * 0.18)
      ..lineTo(s * 0.73, s * 0.18)
      ..cubicTo(s * 0.73, s * 0.42, s * 0.54, s * 0.47, s * 0.53, s * 0.50)
      ..cubicTo(s * 0.54, s * 0.53, s * 0.73, s * 0.58, s * 0.73, s * 0.82)
      ..lineTo(s * 0.27, s * 0.82)
      ..cubicTo(s * 0.27, s * 0.58, s * 0.46, s * 0.53, s * 0.47, s * 0.50)
      ..cubicTo(s * 0.46, s * 0.47, s * 0.27, s * 0.42, s * 0.27, s * 0.18)
      ..close();

    canvas.drawPath(
      glassPath,
      Paint()..color = const Color(0xFFB2EBF2).withValues(alpha: 0.72),
    );

    // Glowing amber-gold sand inside upper & lower bulbs
    canvas.save();
    canvas.clipPath(glassPath);
    final upperSand = Path()
      ..moveTo(s * 0.30, s * 0.31)
      ..lineTo(s * 0.70, s * 0.31)
      ..lineTo(s * 0.50, s * 0.49)
      ..close();
    final lowerSand = Path()
      ..moveTo(s * 0.50, s * 0.65)
      ..lineTo(s * 0.73, s * 0.82)
      ..lineTo(s * 0.27, s * 0.82)
      ..close();
    final sandPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
      ).createShader(Rect.fromLTRB(s * 0.27, s * 0.30, s * 0.73, s * 0.82));
    canvas.drawPath(upperSand, sandPaint);
    canvas.drawPath(lowerSand, sandPaint);
    canvas.drawLine(
      Offset(s * 0.50, s * 0.48),
      Offset(s * 0.50, s * 0.67),
      Paint()
        ..color = const Color(0xFFFFE082)
        ..strokeWidth = math.max(0.8, 1.1 * scale),
    );
    canvas.restore();
    canvas.drawPath(glassPath, outline);

    // Side golden frame pillars
    for (final px in [s * 0.24, s * 0.76]) {
      canvas.drawLine(
        Offset(px, s * 0.18),
        Offset(px, s * 0.82),
        Paint()
          ..color = const Color(0xFFD97B12)
          ..strokeWidth = math.max(1.0, 1.3 * scale),
      );
    }

    // Ornate golden top & bottom caps
    for (final y in [s * 0.10, s * 0.80]) {
      final capRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.18, y, s * 0.64, s * 0.10),
        Radius.circular(s * 0.04),
      );
      canvas.drawRRect(
        capRect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFB27B00)],
          ).createShader(capRect.outerRect),
      );
      canvas.drawRRect(capRect, outline);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_GoldenHourglassPainter oldDelegate) => false;
}

/// Wing 2 — Endings Discovered: Golden victory laurel wreath.
class LaurelWreathIcon extends StatelessWidget {
  final double size;

  const LaurelWreathIcon({super.key, this.size = 22.0});

  @override
  Widget build(BuildContext context) {
    return _CastleVectorIcon(size: size, painter: const _LaurelWreathPainter());
  }
}

class _LaurelWreathPainter extends CustomPainter {
  const _LaurelWreathPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale);

    canvas.save();
    canvas.translate(ox, oy);

    // Draw symmetrical laurel leaves along left & right arcs
    void drawLeaf(Offset pos, double angle, bool bright) {
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);
      final leaf = Path()
        ..moveTo(0, -s * 0.115)
        ..quadraticBezierTo(s * 0.075, -s * 0.02, 0, s * 0.115)
        ..quadraticBezierTo(-s * 0.075, -s * 0.02, 0, -s * 0.115)
        ..close();
      canvas.drawPath(
        leaf,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: bright
                ? const [Color(0xFFFFE082), Color(0xFFFFB300)]
                : const [Color(0xFFFFB300), Color(0xFFD97B12)],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: s * 0.11)),
      );
      canvas.drawPath(leaf, outline);
      canvas.restore();
    }

    const angles = [-2.55, -2.10, -1.55, -1.00];
    for (int i = 0; i < angles.length; i++) {
      final t = i / (angles.length - 1);
      final theta = math.pi * (0.64 + t * 0.62);
      final lx = s * (0.50 + math.cos(theta) * 0.30);
      final ly = s * (0.52 + math.sin(theta) * 0.32);
      drawLeaf(Offset(lx, ly), theta - math.pi * 0.48, true);

      final rTheta = math.pi - theta;
      final rx = s * (0.50 + math.cos(rTheta) * 0.30);
      final ry = s * (0.52 + math.sin(rTheta) * 0.32);
      drawLeaf(Offset(rx, ry), rTheta + math.pi * 0.48, false);
    }

    // Bottom golden clasp tie
    final tieRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(s * 0.50, s * 0.85), width: s * 0.18, height: s * 0.09),
      Radius.circular(s * 0.03),
    );
    canvas.drawRRect(tieRect, Paint()..color = const Color(0xFFE53935));
    canvas.drawRRect(tieRect, outline);

    // Top crowning star glint
    final starCenter = Offset(s * 0.50, s * 0.21);
    final sr = s * 0.11;
    final star = Path()
      ..moveTo(starCenter.dx, starCenter.dy - sr)
      ..quadraticBezierTo(starCenter.dx, starCenter.dy, starCenter.dx + sr, starCenter.dy)
      ..quadraticBezierTo(starCenter.dx, starCenter.dy, starCenter.dx, starCenter.dy + sr)
      ..quadraticBezierTo(starCenter.dx, starCenter.dy, starCenter.dx - sr, starCenter.dy)
      ..quadraticBezierTo(starCenter.dx, starCenter.dy, starCenter.dx, starCenter.dy - sr)
      ..close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFE082));
    canvas.drawPath(star, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LaurelWreathPainter oldDelegate) => false;
}

/// Wing 2 — Arcane Bestiary: Stylized clockwork robot-mage head with brass gear.
class AutomatonHeadIcon extends StatelessWidget {
  final double size;

  const AutomatonHeadIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return _CastleVectorIcon(size: size, painter: const _AutomatonHeadPainter());
  }
}

class _AutomatonHeadPainter extends CustomPainter {
  const _AutomatonHeadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale);

    canvas.save();
    canvas.translate(ox, oy);

    // Top arcane antenna spire
    canvas.drawLine(
      Offset(s * 0.45, s * 0.26),
      Offset(s * 0.45, s * 0.12),
      outline,
    );
    canvas.drawCircle(Offset(s * 0.45, s * 0.11), s * 0.05, Paint()..color = const Color(0xFF00E5FF));
    canvas.drawCircle(Offset(s * 0.45, s * 0.11), s * 0.05, outline);

    // Chamfered steel automaton head
    final headPath = Path()
      ..moveTo(s * 0.25, s * 0.25)
      ..lineTo(s * 0.65, s * 0.25)
      ..lineTo(s * 0.74, s * 0.36)
      ..lineTo(s * 0.74, s * 0.76)
      ..lineTo(s * 0.62, s * 0.87)
      ..lineTo(s * 0.28, s * 0.87)
      ..lineTo(s * 0.16, s * 0.76)
      ..lineTo(s * 0.16, s * 0.36)
      ..close();
    canvas.drawPath(
      headPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFECEFF1), Color(0xFFCFD8DC), Color(0xFF90A4AE)],
        ).createShader(Rect.fromLTRB(s * 0.16, s * 0.25, s * 0.74, s * 0.87)),
    );
    canvas.drawPath(headPath, outline);

    // Dark visor screen + glowing cyan optical eyes
    final visorRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.23, s * 0.42, s * 0.67, s * 0.63),
      Radius.circular(s * 0.06),
    );
    canvas.drawRRect(visorRect, Paint()..color = const Color(0xFF1A2226));
    canvas.drawRRect(visorRect, outline);
    canvas.drawCircle(Offset(s * 0.35, s * 0.525), s * 0.045, Paint()..color = const Color(0xFF00E5FF));
    canvas.drawCircle(Offset(s * 0.55, s * 0.525), s * 0.045, Paint()..color = const Color(0xFF00E5FF));

    // Grille mouth vents
    for (final gx in [s * 0.36, s * 0.45, s * 0.54]) {
      canvas.drawLine(Offset(gx, s * 0.71), Offset(gx, s * 0.79), outline);
    }

    // Brass gear accent at upper-right temple
    final gearCenter = Offset(s * 0.76, s * 0.34);
    final gearOuter = s * 0.15;
    final gearInner = s * 0.105;
    final gearPath = Path();
    const teeth = 6;
    for (int i = 0; i < teeth * 2; i++) {
      final r = i.isEven ? gearOuter : gearInner;
      final a = (i / (teeth * 2)) * 2 * math.pi;
      final pt = gearCenter + Offset(math.cos(a), math.sin(a)) * r;
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
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFB27B00)],
        ).createShader(Rect.fromCircle(center: gearCenter, radius: gearOuter)),
    );
    canvas.drawPath(gearPath, outline);
    canvas.drawCircle(gearCenter, s * 0.045, Paint()..color = const Color(0xFF263238));

    canvas.restore();
  }

  @override
  bool shouldRepaint(_AutomatonHeadPainter oldDelegate) => false;
}

/// Wing 3 — Royal Alchemy: Translucent glass flask with bubbling purple-cyan
/// arcane liquid and cork stopper.
class AlchemyFlaskIcon extends StatelessWidget {
  final double size;

  const AlchemyFlaskIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return _CastleVectorIcon(size: size, painter: const _AlchemyFlaskPainter());
  }
}

class _AlchemyFlaskPainter extends CustomPainter {
  const _AlchemyFlaskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale);

    canvas.save();
    canvas.translate(ox, oy);

    // Cork stopper
    final corkPath = Path()
      ..moveTo(s * 0.40, s * 0.10)
      ..lineTo(s * 0.60, s * 0.10)
      ..lineTo(s * 0.57, s * 0.24)
      ..lineTo(s * 0.43, s * 0.24)
      ..close();
    canvas.drawPath(
      corkPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFA6662E), Color(0xFF6D3F18)],
        ).createShader(Rect.fromLTRB(s * 0.40, s * 0.10, s * 0.60, s * 0.24)),
    );
    canvas.drawPath(corkPath, outline);

    // Flask glass body
    final flaskPath = Path()
      ..moveTo(s * 0.37, s * 0.24)
      ..lineTo(s * 0.63, s * 0.24)
      ..lineTo(s * 0.60, s * 0.29)
      ..lineTo(s * 0.58, s * 0.43)
      ..cubicTo(s * 0.80, s * 0.51, s * 0.84, s * 0.86, s * 0.64, s * 0.90)
      ..lineTo(s * 0.36, s * 0.90)
      ..cubicTo(s * 0.16, s * 0.86, s * 0.20, s * 0.51, s * 0.42, s * 0.43)
      ..lineTo(s * 0.40, s * 0.29)
      ..close();

    canvas.drawPath(
      flaskPath,
      Paint()..color = const Color(0xFFE0F7FA).withValues(alpha: 0.58),
    );

    // Bubbling purple-cyan arcane liquid inside lower flask
    canvas.save();
    canvas.clipPath(flaskPath);
    final liquidPath = Path()
      ..moveTo(s * 0.14, s * 0.60)
      ..quadraticBezierTo(s * 0.34, s * 0.56, s * 0.50, s * 0.60)
      ..quadraticBezierTo(s * 0.66, s * 0.64, s * 0.86, s * 0.59)
      ..lineTo(s * 0.86, s * 0.92)
      ..lineTo(s * 0.14, s * 0.92)
      ..close();
    canvas.drawPath(
      liquidPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF), Color(0xFF9C27B0)],
        ).createShader(Rect.fromLTRB(s * 0.18, s * 0.56, s * 0.82, s * 0.92)),
    );
    // Tiny glowing bubbles
    canvas.drawCircle(Offset(s * 0.43, s * 0.72), s * 0.042, Paint()..color = const Color(0xFF80F3FF));
    canvas.drawCircle(Offset(s * 0.57, s * 0.67), s * 0.032, Paint()..color = Colors.white.withValues(alpha: 0.85));
    canvas.drawCircle(Offset(s * 0.48, s * 0.52), s * 0.028, Paint()..color = const Color(0xFF80F3FF));
    canvas.restore();

    canvas.drawPath(flaskPath, outline);

    // Crisp glass specular arc on left shoulder
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.30, s * 0.60)
        ..quadraticBezierTo(s * 0.25, s * 0.71, s * 0.31, s * 0.80),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.9, 1.25 * scale)
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_AlchemyFlaskPainter oldDelegate) => false;
}

/// Wing 4 — Relic Chamber: Ornate steel-and-gold runic crest shield.
class RunicShieldIcon extends StatelessWidget {
  final double size;

  const RunicShieldIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return _CastleVectorIcon(size: size, painter: const _RunicShieldPainter());
  }
}

class _RunicShieldPainter extends CustomPainter {
  const _RunicShieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale);

    canvas.save();
    canvas.translate(ox, oy);

    // Outer golden shield rim
    final outerShield = Path()
      ..moveTo(s * 0.50, s * 0.10)
      ..lineTo(s * 0.84, s * 0.21)
      ..cubicTo(s * 0.84, s * 0.58, s * 0.69, s * 0.80, s * 0.50, s * 0.90)
      ..cubicTo(s * 0.31, s * 0.80, s * 0.16, s * 0.58, s * 0.16, s * 0.21)
      ..close();
    canvas.drawPath(
      outerShield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFB27B00)],
        ).createShader(Rect.fromLTRB(s * 0.16, s * 0.10, s * 0.84, s * 0.90)),
    );
    canvas.drawPath(outerShield, outline);

    // Inner split-shaded steel shield plate
    final innerShield = Path()
      ..moveTo(s * 0.50, s * 0.18)
      ..lineTo(s * 0.75, s * 0.265)
      ..cubicTo(s * 0.75, s * 0.56, s * 0.64, s * 0.73, s * 0.50, s * 0.81)
      ..cubicTo(s * 0.36, s * 0.73, s * 0.25, s * 0.56, s * 0.25, s * 0.265)
      ..close();
    canvas.drawPath(
      innerShield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFECEFF1), Color(0xFFCFD8DC), Color(0xFF90A4AE)],
          stops: [0.0, 0.49, 0.51],
        ).createShader(Rect.fromLTRB(s * 0.25, s * 0.18, s * 0.75, s * 0.81)),
    );
    canvas.drawPath(innerShield, outline);

    // Glowing cyan runic diamond emblem
    final runeCenter = Offset(s * 0.50, s * 0.48);
    final rune = Path()
      ..moveTo(runeCenter.dx, runeCenter.dy - s * 0.14)
      ..lineTo(runeCenter.dx + s * 0.10, runeCenter.dy)
      ..lineTo(runeCenter.dx, runeCenter.dy + s * 0.14)
      ..lineTo(runeCenter.dx - s * 0.10, runeCenter.dy)
      ..close();
    canvas.drawPath(
      rune,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF80F3FF), Color(0xFF00B0FF)],
        ).createShader(Rect.fromCircle(center: runeCenter, radius: s * 0.14)),
    );
    canvas.drawPath(rune, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RunicShieldPainter oldDelegate) => false;
}

/// Wing 5 — Spoils of War: Crimson-and-gold royal battle standard.
class WarBannerIcon extends StatelessWidget {
  final double size;

  const WarBannerIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return _CastleVectorIcon(size: size, painter: const _WarBannerPainter());
  }
}

class _WarBannerPainter extends CustomPainter {
  const _WarBannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale);

    canvas.save();
    canvas.translate(ox, oy);

    // Draped crimson & gold swallowtail battle banner
    final bannerPath = Path()
      ..moveTo(s * 0.26, s * 0.22)
      ..lineTo(s * 0.74, s * 0.22)
      ..lineTo(s * 0.74, s * 0.86)
      ..lineTo(s * 0.50, s * 0.72)
      ..lineTo(s * 0.26, s * 0.86)
      ..close();
    canvas.drawPath(
      bannerPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFE53935), Color(0xFFC62828), Color(0xFF8E0000)],
        ).createShader(Rect.fromLTRB(s * 0.26, s * 0.22, s * 0.74, s * 0.86)),
    );
    canvas.drawPath(bannerPath, outline);

    // Gold vertical side trim & central royal diamond crest
    final crest = Path()
      ..moveTo(s * 0.50, s * 0.35)
      ..lineTo(s * 0.61, s * 0.48)
      ..lineTo(s * 0.50, s * 0.61)
      ..lineTo(s * 0.39, s * 0.48)
      ..close();
    canvas.drawPath(
      crest,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
        ).createShader(Rect.fromLTRB(s * 0.39, s * 0.35, s * 0.61, s * 0.61)),
    );
    canvas.drawPath(crest, outline);

    // Golden flagpole & crossbar
    final polePaint = Paint()
      ..color = const Color(0xFFFFB300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, 2.2 * scale)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s * 0.22, s * 0.22), Offset(s * 0.78, s * 0.22), outline);
    canvas.drawLine(Offset(s * 0.22, s * 0.22), Offset(s * 0.78, s * 0.22), polePaint);
    canvas.drawLine(Offset(s * 0.50, s * 0.08), Offset(s * 0.50, s * 0.22), outline);
    canvas.drawLine(Offset(s * 0.50, s * 0.08), Offset(s * 0.50, s * 0.22), polePaint);
    canvas.drawCircle(Offset(s * 0.50, s * 0.10), s * 0.055, Paint()..color = const Color(0xFFFFE082));
    canvas.drawCircle(Offset(s * 0.50, s * 0.10), s * 0.055, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_WarBannerPainter oldDelegate) => false;
}

/// Wing 6 — Peak Max HP: Faceted crimson ruby heart in a golden bezel.
class RubyHeartIcon extends StatelessWidget {
  final double size;

  const RubyHeartIcon({super.key, this.size = 22.0});

  @override
  Widget build(BuildContext context) {
    return _CastleVectorIcon(size: size, painter: const _RubyHeartPainter());
  }
}

class _RubyHeartPainter extends CustomPainter {
  const _RubyHeartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) * 0.5;
    final oy = (size.height - s) * 0.5;
    final scale = s / 24.0;
    final outline = _outlinePaint(scale);

    canvas.save();
    canvas.translate(ox, oy);

    Path buildHeart(double pad) {
      final t = pad;
      final l = s * (0.12 + t);
      final r = s * (0.88 - t);
      final top = s * (0.20 + t);
      final bot = s * (0.88 - t * 0.9);
      final cx = s * 0.50;
      return Path()
        ..moveTo(cx, s * (0.32 + t))
        ..cubicTo(cx - s * 0.06, top, l, top, l, s * 0.42)
        ..cubicTo(l, s * 0.62, cx - s * 0.06, s * 0.74, cx, bot)
        ..cubicTo(cx + s * 0.06, s * 0.74, r, s * 0.62, r, s * 0.42)
        ..cubicTo(r, top, cx + s * 0.06, top, cx, s * (0.32 + t))
        ..close();
    }

    // Golden bezel
    final outerHeart = buildHeart(0.0);
    canvas.drawPath(
      outerHeart,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFB27B00)],
        ).createShader(Rect.fromLTRB(s * 0.12, s * 0.18, s * 0.88, s * 0.88)),
    );
    canvas.drawPath(outerHeart, outline);

    // Faceted crimson ruby center
    final innerHeart = buildHeart(0.065);
    canvas.drawPath(
      innerHeart,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6E6E), Color(0xFFE53935), Color(0xFFB71C1C)],
        ).createShader(Rect.fromLTRB(s * 0.18, s * 0.25, s * 0.82, s * 0.82)),
    );
    canvas.drawPath(innerHeart, outline);

    // Specular jewel glint
    canvas.drawCircle(
      Offset(s * 0.34, s * 0.39),
      s * 0.05,
      Paint()..color = Colors.white.withValues(alpha: 0.88),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RubyHeartPainter oldDelegate) => false;
}

/// Wing 6 — Peak Max Mana Pool: Faceted sapphire-cyan mana crystal.
class ManaCrystalIcon extends StatelessWidget {
  final double size;

  const ManaCrystalIcon({super.key, this.size = 22.0});

  @override
  Widget build(BuildContext context) {
    return _CastleVectorIcon(size: size, painter: const _ManaCrystalPainter());
  }
}

class _ManaCrystalPainter extends CustomPainter {
  const _ManaCrystalPainter();

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

    // Outer hexagonal crystal silhouette
    final top = Offset(s * 0.50, s * 0.09);
    final ul = Offset(s * 0.24, s * 0.34);
    final ur = Offset(s * 0.76, s * 0.34);
    final ll = Offset(s * 0.26, s * 0.68);
    final lr = Offset(s * 0.74, s * 0.68);
    final bot = Offset(s * 0.50, s * 0.91);

    final fullPath = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(ur.dx, ur.dy)
      ..lineTo(lr.dx, lr.dy)
      ..lineTo(bot.dx, bot.dy)
      ..lineTo(ll.dx, ll.dy)
      ..lineTo(ul.dx, ul.dy)
      ..close();

    // Faceted fills (left-lit cyan to right-shadowed sapphire)
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
        ..lineTo(ll.dx, ll.dy)
        ..close(),
      Paint()..color = const Color(0xFF00B0FF),
    );
    canvas.drawPath(
      Path()
        ..moveTo(ur.dx, ur.dy)
        ..lineTo(lr.dx, lr.dy)
        ..lineTo(s * 0.50, s * 0.48)
        ..close(),
      Paint()..color = const Color(0xFF0288D1),
    );
    canvas.drawPath(
      Path()
        ..moveTo(ll.dx, ll.dy)
        ..lineTo(s * 0.50, s * 0.48)
        ..lineTo(lr.dx, lr.dy)
        ..lineTo(bot.dx, bot.dy)
        ..close(),
      Paint()..color = const Color(0xFF01579B),
    );

    // Internal facet creases + outer crystal outline
    canvas.drawLine(ul, Offset(s * 0.50, s * 0.48), detail);
    canvas.drawLine(ur, Offset(s * 0.50, s * 0.48), detail);
    canvas.drawLine(ll, Offset(s * 0.50, s * 0.48), detail);
    canvas.drawLine(lr, Offset(s * 0.50, s * 0.48), detail);
    canvas.drawLine(top, bot, detail);
    canvas.drawPath(fullPath, outline);

    // Bright specular dot
    canvas.drawCircle(
      Offset(s * 0.41, s * 0.30),
      s * 0.042,
      Paint()..color = Colors.white.withValues(alpha: 0.90),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ManaCrystalPainter oldDelegate) => false;
}
