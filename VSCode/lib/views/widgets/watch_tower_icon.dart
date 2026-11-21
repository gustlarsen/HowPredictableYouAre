import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A bespoke, multi-toned RPG Watch Tower Spyglass & Battlement icon rendered
/// via [CustomPainter] on a transparent background.
///
/// Architectural silhouette features:
/// - Segmented brass watch spyglass angled diagonally toward the top-right with
///   warm metallic shading (`#FFE082` top-left highlight, `#FFB300` mid-tone,
///   `#B26A00` lower shadow) and raised brass collar rings.
/// - Beveled brass objective aperture framing a luminous cyan-blue crystal lens
///   (`#00E5FF` / `#0288D1`) with a white diagonal reflection glint and a small
///   4-point star sparkle outside the lens.
/// - Sturdy crenellated stone parapet base (matching [RoyalCastleIcon]'s
///   stone-gray palette with 3 crisp merlons and an arrow-slit embrasure)
///   anchoring the spyglass pivot mount.
///
/// Set [isOnGoldBackground] to `true` when rendering on a solid gold surface
/// to switch to the high-contrast deep charcoal-slate palette.
class WatchTowerIcon extends StatelessWidget {
  final double size;
  final bool isOnGoldBackground;

  const WatchTowerIcon({
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
          painter: _WatchTowerPainter(
            isOnGoldBackground: isOnGoldBackground,
          ),
        ),
      ),
    );
  }
}

class _WatchTowerPalette {
  final Color brassHighlight;
  final Color brassLight;
  final Color brassMid;
  final Color brassDark;
  final Color lensHighlight;
  final Color lensBright;
  final Color lensDeep;
  final Color stoneHighlight;
  final Color stoneLight;
  final Color stoneMid;
  final Color stoneShadow;
  final Color mountLight;
  final Color mountDark;
  final Color outline;
  final Color sparkleFill;

  const _WatchTowerPalette({
    required this.brassHighlight,
    required this.brassLight,
    required this.brassMid,
    required this.brassDark,
    required this.lensHighlight,
    required this.lensBright,
    required this.lensDeep,
    required this.stoneHighlight,
    required this.stoneLight,
    required this.stoneMid,
    required this.stoneShadow,
    required this.mountLight,
    required this.mountDark,
    required this.outline,
    required this.sparkleFill,
  });

  static const standard = _WatchTowerPalette(
    brassHighlight: Color(0xFFFFF3B0),
    brassLight: Color(0xFFFFE082),
    brassMid: Color(0xFFFFB300),
    brassDark: Color(0xFFB26A00),
    lensHighlight: Color(0xFFB2FEFF),
    lensBright: Color(0xFF00E5FF),
    lensDeep: Color(0xFF0288D1),
    stoneHighlight: Color(0xFFECEFF1),
    stoneLight: Color(0xFFCFD8DC),
    stoneMid: Color(0xFF90A4AE),
    stoneShadow: Color(0xFF607D8B),
    mountLight: Color(0xFF78909C),
    mountDark: Color(0xFF37474F),
    outline: Color(0xFF1A2226),
    sparkleFill: Color(0xFFFFFFFF),
  );

  static const onGold = _WatchTowerPalette(
    brassHighlight: Color(0xFF546E7A),
    brassLight: Color(0xFF37474F),
    brassMid: Color(0xFF263238),
    brassDark: Color(0xFF1A2226),
    lensHighlight: Color(0xFF84FFFF),
    lensBright: Color(0xFF00E5FF),
    lensDeep: Color(0xFF0277BD),
    stoneHighlight: Color(0xFF455A64),
    stoneLight: Color(0xFF37474F),
    stoneMid: Color(0xFF263238),
    stoneShadow: Color(0xFF1A2226),
    mountLight: Color(0xFF37474F),
    mountDark: Color(0xFF1A2226),
    outline: Color(0xFF141B1E),
    sparkleFill: Color(0xFF1A2226),
  );
}

class _WatchTowerPainter extends CustomPainter {
  final bool isOnGoldBackground;

  const _WatchTowerPainter({
    required this.isOnGoldBackground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final offsetX = (size.width - side) * 0.5;
    final offsetY = (size.height - side) * 0.5;
    final scale = side / 24.0;
    final p = isOnGoldBackground
        ? _WatchTowerPalette.onGold
        : _WatchTowerPalette.standard;

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

    // 1. Subtle ground shadow beneath parapet base
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(side * 0.50, side * 0.925),
        width: side * 0.80,
        height: side * 0.072,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: isOnGoldBackground ? 0.16 : 0.28),
    );

    // 2. Pivot mount post rising from behind the stone parapet
    final mountPost = Rect.fromLTRB(
      side * 0.395,
      side * 0.425,
      side * 0.465,
      side * 0.65,
    );
    canvas.drawRect(
      mountPost,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [p.mountLight, p.mountDark],
        ).createShader(mountPost),
    );
    canvas.drawRect(mountPost, outlinePaint);

    // 3. Angled segmented brass spyglass & cyan crystal objective lens
    _paintSpyglass(canvas, side, scale, p, outlinePaint);

    // 4. Foreground stone watchtower battlement parapet (3 crisp merlons)
    _paintBattlementParapet(
      canvas,
      side,
      p,
      outlinePaint,
      detailStrokePaint,
    );

    // 5. Small 4-point star sparkle just outside the top-right lens
    _paintLensSparkle(canvas, side, scale, p);

    canvas.restore();
  }

  void _paintSpyglass(
    Canvas canvas,
    double s,
    double scale,
    _WatchTowerPalette p,
    Paint outlinePaint,
  ) {
    final pivot = Offset(s * 0.43, s * 0.405);
    const angleRad = -0.52; // ~ -29.8 degrees pointing up-right

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angleRad);

    // Tapered segmented brass tubes drawn back-to-front (eyepiece -> mid -> bell)
    void drawBrassTube(Rect rect) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              p.brassHighlight,
              p.brassLight,
              p.brassMid,
              p.brassDark,
            ],
            stops: const [0.0, 0.25, 0.62, 1.0],
          ).createShader(rect),
      );
      canvas.drawRect(rect, outlinePaint);
    }

    // Eyepiece cap (far left)
    final eyeCap = RRect.fromRectAndRadius(
      Rect.fromLTRB(-s * 0.335, -s * 0.052, -s * 0.285, s * 0.052),
      Radius.circular(s * 0.018),
    );
    canvas.drawRRect(
      eyeCap,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.brassLight, p.brassMid, p.brassDark],
        ).createShader(eyeCap.outerRect),
    );
    canvas.drawRRect(eyeCap, outlinePaint);

    // Narrow eyepiece tube
    drawBrassTube(
      Rect.fromLTRB(-s * 0.29, -s * 0.042, -s * 0.10, s * 0.042),
    );

    // Middle barrel
    drawBrassTube(
      Rect.fromLTRB(-s * 0.105, -s * 0.068, s * 0.145, s * 0.068),
    );

    // Wider front objective barrel (flared slightly toward front rim)
    final frontBarrelPath = Path()
      ..moveTo(s * 0.14, -s * 0.088)
      ..lineTo(s * 0.40, -s * 0.112)
      ..lineTo(s * 0.40, s * 0.112)
      ..lineTo(s * 0.14, s * 0.088)
      ..close();
    canvas.drawPath(
      frontBarrelPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            p.brassHighlight,
            p.brassLight,
            p.brassMid,
            p.brassDark,
          ],
          stops: const [0.0, 0.24, 0.62, 1.0],
        ).createShader(Rect.fromLTRB(s * 0.14, -s * 0.112, s * 0.40, s * 0.112)),
    );
    canvas.drawPath(frontBarrelPath, outlinePaint);

    // Raised brass collar rings between segments
    for (final ringRect in [
      Rect.fromLTRB(-s * 0.115, -s * 0.078, -s * 0.075, s * 0.078),
      Rect.fromLTRB(s * 0.125, -s * 0.098, s * 0.170, s * 0.098),
    ]) {
      final rrect = RRect.fromRectAndRadius(
        ringRect,
        Radius.circular(s * 0.015),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.brassHighlight, p.brassMid, p.brassDark],
          ).createShader(ringRect),
      );
      canvas.drawRRect(rrect, outlinePaint);
    }

    // Pivot saddle collar clamping the middle barrel
    canvas.drawCircle(
      Offset.zero,
      s * 0.042,
      Paint()..color = p.brassMid,
    );
    canvas.drawCircle(Offset.zero, s * 0.042, outlinePaint);

    // Beveled brass front objective rim & luminous cyan crystal lens
    final outerBezel = Rect.fromCenter(
      center: Offset(s * 0.408, 0),
      width: s * 0.125,
      height: s * 0.255,
    );
    canvas.drawOval(
      outerBezel,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.brassHighlight, p.brassLight, p.brassMid, p.brassDark],
          stops: const [0.0, 0.30, 0.70, 1.0],
        ).createShader(outerBezel),
    );
    canvas.drawOval(outerBezel, outlinePaint);

    // Glowing cyan objective crystal lens
    final lensRect = Rect.fromCenter(
      center: Offset(s * 0.415, 0),
      width: s * 0.078,
      height: s * 0.185,
    );
    canvas.drawOval(
      lensRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.lensHighlight, p.lensBright, p.lensDeep],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(lensRect),
    );
    canvas.drawOval(
      lensRect,
      Paint()
        ..color = p.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.55, 0.80 * scale),
    );

    // Crisp white diagonal glass reflection glint on upper-left lens face
    canvas.drawLine(
      Offset(s * 0.398, -s * 0.048),
      Offset(s * 0.422, -s * 0.018),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.75, 1.05 * scale)
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  void _paintBattlementParapet(
    Canvas canvas,
    double s,
    _WatchTowerPalette p,
    Paint outlinePaint,
    Paint detailStrokePaint,
  ) {
    // Lower fortified stone tower wall body
    final wallRect = Rect.fromLTRB(s * 0.175, s * 0.68, s * 0.825, s * 0.905);
    canvas.drawRect(
      wallRect,
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
        ).createShader(wallRect),
    );

    // Shadow band directly under corbelled parapet overhang
    canvas.drawRect(
      Rect.fromLTRB(s * 0.175, s * 0.68, s * 0.825, s * 0.715),
      Paint()..color = p.outline.withValues(alpha: 0.24),
    );
    canvas.drawRect(wallRect, outlinePaint);

    // Horizontal stone masonry course lines flanking center arrow slit
    canvas.drawLine(
      Offset(s * 0.215, s * 0.795),
      Offset(s * 0.42, s * 0.795),
      detailStrokePaint,
    );
    canvas.drawLine(
      Offset(s * 0.58, s * 0.795),
      Offset(s * 0.785, s * 0.795),
      detailStrokePaint,
    );

    // Narrow dark arrow-slit window in tower face
    final slitRect = Rect.fromCenter(
      center: Offset(s * 0.50, s * 0.795),
      width: s * 0.046,
      height: s * 0.115,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(slitRect, Radius.circular(slitRect.width * 0.45)),
      Paint()..color = p.outline,
    );

    // Corbelled crenellated parapet with 3 bold merlons
    final parapetPath = Path()
      ..moveTo(s * 0.13, s * 0.685)
      ..lineTo(s * 0.13, s * 0.575)
      ..lineTo(s * 0.30, s * 0.575)
      ..lineTo(s * 0.30, s * 0.625)
      ..lineTo(s * 0.415, s * 0.625)
      ..lineTo(s * 0.415, s * 0.575)
      ..lineTo(s * 0.585, s * 0.575)
      ..lineTo(s * 0.585, s * 0.625)
      ..lineTo(s * 0.70, s * 0.625)
      ..lineTo(s * 0.70, s * 0.575)
      ..lineTo(s * 0.87, s * 0.575)
      ..lineTo(s * 0.87, s * 0.685)
      ..close();

    final parapetBounds = Rect.fromLTRB(s * 0.13, s * 0.575, s * 0.87, s * 0.685);
    canvas.drawPath(
      parapetPath,
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
          stops: const [0.0, 0.30, 0.70, 1.0],
        ).createShader(parapetBounds),
    );
    canvas.drawPath(parapetPath, outlinePaint);
  }

  void _paintLensSparkle(
    Canvas canvas,
    double s,
    double scale,
    _WatchTowerPalette p,
  ) {
    final c = Offset(s * 0.875, s * 0.115);
    final rLong = s * 0.072;
    final rShort = s * 0.022;

    final sparkle = Path()
      ..moveTo(c.dx, c.dy - rLong)
      ..lineTo(c.dx + rShort, c.dy - rShort)
      ..lineTo(c.dx + rLong, c.dy)
      ..lineTo(c.dx + rShort, c.dy + rShort)
      ..lineTo(c.dx, c.dy + rLong)
      ..lineTo(c.dx - rShort, c.dy + rShort)
      ..lineTo(c.dx - rLong, c.dy)
      ..lineTo(c.dx - rShort, c.dy - rShort)
      ..close();

    canvas.drawPath(sparkle, Paint()..color = p.sparkleFill);
    canvas.drawPath(
      sparkle,
      Paint()
        ..color = p.lensBright.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.4, 0.55 * scale)
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_WatchTowerPainter oldDelegate) {
    return oldDelegate.isOnGoldBackground != isOnGoldBackground;
  }
}
