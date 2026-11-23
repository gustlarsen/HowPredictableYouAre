import 'package:flutter/material.dart';
import '../../models/move.dart';

/// Bespoke multi-toned RPG vector emblem widget rendered via [CustomPainter]
/// for the 5 elemental attacks: Fire, Water, Wood, Earth, and Metal.
///
/// Uses proportional `0.0..1.0` coordinates, split light/shadow shading,
/// and crisp dark slate outlines (`#1A2226`) so emblems read sharply at both
/// compact `16px` hint/badge sizes and `30px–36px` bottom action orb sizes.
class ElementalSymbolIcon extends StatelessWidget {
  final HandMove move;
  final double size;

  const ElementalSymbolIcon({
    super.key,
    required this.move,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size.square(size),
        painter: _ElementalSymbolPainter(move: move),
      ),
    );
  }
}

class _ElementalSymbolPainter extends CustomPainter {
  final HandMove move;

  static const Color _outlineColor = Color(0xFF1A2226);

  const _ElementalSymbolPainter({required this.move});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double s = size.shortestSide;
    final double dx = (size.width - s) * 0.5;
    final double dy = (size.height - s) * 0.5;

    canvas.save();
    canvas.translate(dx, dy);

    final double strokeWidth = (s * 0.062).clamp(1.0, 2.5);

    switch (move) {
      case HandMove.rock:
        _paintFire(canvas, s, strokeWidth);
      case HandMove.paper:
        _paintWater(canvas, s, strokeWidth);
      case HandMove.scissors:
        _paintWood(canvas, s, strokeWidth);
      case HandMove.lizard:
        _paintEarth(canvas, s, strokeWidth);
      case HandMove.spock:
        _paintMetal(canvas, s, strokeWidth);
    }

    canvas.restore();
  }

  Offset _p(double s, double x, double y) => Offset(s * x, s * y);

  Paint _outlinePaint(double width) => Paint()
    ..color = _outlineColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  void _paintFire(Canvas canvas, double s, double strokeWidth) {
    final Rect bounds = Rect.fromLTWH(0, 0, s, s);

    // Dynamic curved flame tongue silhouette
    final Path outerFlame = Path()
      ..moveTo(s * 0.50, s * 0.91)
      // Left swelling curve up to a lower flicker and main apex
      ..cubicTo(
        s * 0.23,
        s * 0.88,
        s * 0.16,
        s * 0.60,
        s * 0.28,
        s * 0.42,
      )
      ..quadraticBezierTo(s * 0.30, s * 0.50, s * 0.36, s * 0.52)
      ..cubicTo(
        s * 0.33,
        s * 0.34,
        s * 0.44,
        s * 0.18,
        s * 0.55,
        s * 0.08,
      )
      // Sweeping right flame tongue curve
      ..cubicTo(
        s * 0.50,
        s * 0.24,
        s * 0.67,
        s * 0.32,
        s * 0.65,
        s * 0.49,
      )
      ..quadraticBezierTo(s * 0.72, s * 0.44, s * 0.73, s * 0.37)
      ..cubicTo(
        s * 0.84,
        s * 0.55,
        s * 0.78,
        s * 0.88,
        s * 0.50,
        s * 0.91,
      )
      ..close();

    // Base luminous orange-amber gradient fill
    canvas.drawPath(
      outerFlame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFB300),
            Color(0xFFFF6D00),
            Color(0xFFE65100),
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(bounds),
    );

    // Right-side split shadow crescent clipped inside flame
    canvas.save();
    canvas.clipPath(outerFlame);
    final Path shadowHalf = Path()
      ..moveTo(s * 0.54, s * 0.06)
      ..lineTo(s * 0.95, s * 0.06)
      ..lineTo(s * 0.95, s * 0.96)
      ..lineTo(s * 0.52, s * 0.96)
      ..quadraticBezierTo(s * 0.66, s * 0.60, s * 0.54, s * 0.06)
      ..close();
    canvas.drawPath(
      shadowHalf,
      Paint()..color = const Color(0xFFFF6D00).withValues(alpha: 0.45),
    );
    canvas.restore();

    // Crisp outer dark slate outline
    canvas.drawPath(outerFlame, _outlinePaint(strokeWidth));

    // Bright golden-white inner teardrop core
    final Path innerCore = Path()
      ..moveTo(s * 0.50, s * 0.84)
      ..cubicTo(
        s * 0.36,
        s * 0.82,
        s * 0.35,
        s * 0.62,
        s * 0.51,
        s * 0.43,
      )
      ..cubicTo(
        s * 0.64,
        s * 0.62,
        s * 0.64,
        s * 0.82,
        s * 0.50,
        s * 0.84,
      )
      ..close();

    canvas.drawPath(
      innerCore,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF59D),
            Color(0xFFFFFFFF),
            Color(0xFFFFE082),
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(bounds),
    );
    canvas.drawPath(
      innerCore,
      Paint()
        ..color = const Color(0xFFE65100)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (strokeWidth * 0.52).clamp(0.75, 1.4)
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintWater(Canvas canvas, double s, double strokeWidth) {
    final Rect bounds = Rect.fromLTWH(0, 0, s, s);

    // Plump smooth water droplet
    final Path droplet = Path()
      ..moveTo(s * 0.50, s * 0.09)
      ..cubicTo(
        s * 0.35,
        s * 0.31,
        s * 0.19,
        s * 0.48,
        s * 0.19,
        s * 0.64,
      )
      ..cubicTo(
        s * 0.19,
        s * 0.82,
        s * 0.33,
        s * 0.91,
        s * 0.50,
        s * 0.91,
      )
      ..cubicTo(
        s * 0.67,
        s * 0.91,
        s * 0.81,
        s * 0.82,
        s * 0.81,
        s * 0.64,
      )
      ..cubicTo(
        s * 0.81,
        s * 0.48,
        s * 0.65,
        s * 0.31,
        s * 0.50,
        s * 0.09,
      )
      ..close();

    // Base vibrant sky-cyan gradient fill
    canvas.drawPath(
      droplet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF40C4FF),
            Color(0xFF00B0FF),
            Color(0xFF0277BD),
          ],
          stops: [0.0, 0.52, 1.0],
        ).createShader(bounds),
    );

    // Split deep sapphire shadow plane along the lower-right curve
    canvas.save();
    canvas.clipPath(droplet);
    final Path sapphireShadow = Path()
      ..moveTo(s * 0.50, s * 0.08)
      ..lineTo(s * 0.90, s * 0.08)
      ..lineTo(s * 0.90, s * 0.95)
      ..lineTo(s * 0.28, s * 0.95)
      ..cubicTo(
        s * 0.62,
        s * 0.86,
        s * 0.72,
        s * 0.54,
        s * 0.50,
        s * 0.08,
      )
      ..close();
    canvas.drawPath(
      sapphireShadow,
      Paint()..color = const Color(0xFF0277BD).withValues(alpha: 0.78),
    );
    canvas.restore();

    // Curved white specular highlight on upper-left
    final Path specularArc = Path()
      ..moveTo(s * 0.43, s * 0.33)
      ..cubicTo(
        s * 0.34,
        s * 0.44,
        s * 0.29,
        s * 0.53,
        s * 0.29,
        s * 0.63,
      );
    canvas.drawPath(
      specularArc,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.075).clamp(1.2, 3.0)
        ..strokeCap = StrokeCap.round,
    );

    // Small lower-left glossy glint
    canvas.drawCircle(
      _p(s, 0.33, 0.73),
      (s * 0.042).clamp(0.8, 1.8),
      Paint()..color = Colors.white.withValues(alpha: 0.88),
    );

    // Crisp outer dark slate outline
    canvas.drawPath(droplet, _outlinePaint(strokeWidth));
  }

  void _paintWood(Canvas canvas, double s, double strokeWidth) {
    // Lush angled broad botanical leaf from bottom-left to top-right
    final Path leafBlade = Path()
      ..moveTo(s * 0.25, s * 0.75)
      ..cubicTo(
        s * 0.14,
        s * 0.44,
        s * 0.38,
        s * 0.17,
        s * 0.86,
        s * 0.14,
      )
      ..cubicTo(
        s * 0.83,
        s * 0.62,
        s * 0.56,
        s * 0.86,
        s * 0.25,
        s * 0.75,
      )
      ..close();

    // Upper-left highlight half (vibrant emerald-lime)
    final Path upperHalf = Path()
      ..moveTo(s * 0.25, s * 0.75)
      ..cubicTo(
        s * 0.14,
        s * 0.44,
        s * 0.38,
        s * 0.17,
        s * 0.86,
        s * 0.14,
      )
      ..quadraticBezierTo(s * 0.52, s * 0.45, s * 0.25, s * 0.75)
      ..close();

    // Lower-right shaded half (rich forest green)
    final Path lowerHalf = Path()
      ..moveTo(s * 0.25, s * 0.75)
      ..quadraticBezierTo(s * 0.52, s * 0.45, s * 0.86, s * 0.14)
      ..cubicTo(
        s * 0.83,
        s * 0.62,
        s * 0.56,
        s * 0.86,
        s * 0.25,
        s * 0.75,
      )
      ..close();

    final Rect bounds = Rect.fromLTWH(0, 0, s, s);
    canvas.drawPath(
      upperHalf,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF69F0AE),
            Color(0xFF00E676),
          ],
        ).createShader(bounds),
    );
    canvas.drawPath(
      lowerHalf,
      Paint()..color = const Color(0xFF2E7D32),
    );

    // Petiole stem extending below-left of blade
    final Paint stemOutline = Paint()
      ..color = _outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (strokeWidth * 1.35).clamp(1.6, 3.8)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(_p(s, 0.13, 0.87), _p(s, 0.26, 0.74), stemOutline);

    // Crisp outer leaf outline
    canvas.drawPath(leafBlade, _outlinePaint(strokeWidth));

    // Central stem & diagonal leaf veins (dark crisp lines + pale lime spine)
    final Paint veinDark = Paint()
      ..color = _outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (strokeWidth * 0.68).clamp(0.85, 1.7)
      ..strokeCap = StrokeCap.round;
    final Paint midribHighlight = Paint()
      ..color = const Color(0xFFB9F6CA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (strokeWidth * 0.55).clamp(0.7, 1.4)
      ..strokeCap = StrokeCap.round;

    // Diagonal lateral veins inside blade
    canvas.save();
    canvas.clipPath(leafBlade);
    canvas.drawLine(_p(s, 0.37, 0.63), _p(s, 0.34, 0.42), veinDark);
    canvas.drawLine(_p(s, 0.37, 0.63), _p(s, 0.58, 0.66), veinDark);
    canvas.drawLine(_p(s, 0.51, 0.49), _p(s, 0.48, 0.30), veinDark);
    canvas.drawLine(_p(s, 0.51, 0.49), _p(s, 0.70, 0.52), veinDark);
    canvas.drawLine(_p(s, 0.65, 0.35), _p(s, 0.63, 0.21), veinDark);
    canvas.drawLine(_p(s, 0.65, 0.35), _p(s, 0.79, 0.37), veinDark);
    canvas.restore();

    // Central spine & stem highlight
    canvas.drawLine(_p(s, 0.25, 0.75), _p(s, 0.75, 0.25), veinDark);
    canvas.drawLine(_p(s, 0.14, 0.86), _p(s, 0.72, 0.28), midribHighlight);
  }

  void _paintEarth(Canvas canvas, double s, double strokeWidth) {
    // Cluster of 4 faceted polygonal boulders grounded on a stable base
    final Paint outline = _outlinePaint(strokeWidth);
    final Paint innerCrease = Paint()
      ..color = _outlineColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (strokeWidth * 0.55).clamp(0.75, 1.35)
      ..strokeJoin = StrokeJoin.round;

    // 1. Back-right secondary boulder
    final Path backRight = Path()
      ..moveTo(s * 0.48, s * 0.42)
      ..lineTo(s * 0.64, s * 0.26)
      ..lineTo(s * 0.82, s * 0.34)
      ..lineTo(s * 0.87, s * 0.66)
      ..lineTo(s * 0.52, s * 0.68)
      ..close();
    canvas.drawPath(backRight, Paint()..color = const Color(0xFFB57239));
    final Path backRightShadow = Path()
      ..moveTo(s * 0.64, s * 0.26)
      ..lineTo(s * 0.82, s * 0.34)
      ..lineTo(s * 0.87, s * 0.66)
      ..lineTo(s * 0.66, s * 0.67)
      ..lineTo(s * 0.68, s * 0.43)
      ..close();
    canvas.drawPath(backRightShadow, Paint()..color = const Color(0xFF6E3D14));
    canvas.drawPath(backRight, outline);

    // 2. Main hero center-left boulder
    final Path heroRock = Path()
      ..moveTo(s * 0.20, s * 0.78)
      ..lineTo(s * 0.19, s * 0.40)
      ..lineTo(s * 0.38, s * 0.17)
      ..lineTo(s * 0.59, s * 0.22)
      ..lineTo(s * 0.68, s * 0.52)
      ..lineTo(s * 0.60, s * 0.82)
      ..close();

    // Base mid-tone caramel
    canvas.drawPath(heroRock, Paint()..color = const Color(0xFFD68C45));

    // Top-left sunlit highlight facet
    final Path heroHighlight = Path()
      ..moveTo(s * 0.19, s * 0.40)
      ..lineTo(s * 0.38, s * 0.17)
      ..lineTo(s * 0.59, s * 0.22)
      ..lineTo(s * 0.45, s * 0.44)
      ..lineTo(s * 0.26, s * 0.50)
      ..close();
    canvas.drawPath(heroHighlight, Paint()..color = const Color(0xFFE29E5A));

    // Right deep shadow facet
    final Path heroShadow = Path()
      ..moveTo(s * 0.59, s * 0.22)
      ..lineTo(s * 0.68, s * 0.52)
      ..lineTo(s * 0.60, s * 0.82)
      ..lineTo(s * 0.46, s * 0.80)
      ..lineTo(s * 0.45, s * 0.44)
      ..close();
    canvas.drawPath(heroShadow, Paint()..color = const Color(0xFF6E3D14));

    canvas.drawLine(_p(s, 0.45, 0.44), _p(s, 0.59, 0.22), innerCrease);
    canvas.drawLine(_p(s, 0.45, 0.44), _p(s, 0.20, 0.50), innerCrease);
    canvas.drawPath(heroRock, outline);

    // 3. Front-left grounded stone
    final Path frontLeft = Path()
      ..moveTo(s * 0.09, s * 0.81)
      ..lineTo(s * 0.11, s * 0.60)
      ..lineTo(s * 0.25, s * 0.52)
      ..lineTo(s * 0.39, s * 0.64)
      ..lineTo(s * 0.37, s * 0.85)
      ..lineTo(s * 0.15, s * 0.85)
      ..close();
    canvas.drawPath(frontLeft, Paint()..color = const Color(0xFFE29E5A));
    final Path frontLeftShadow = Path()
      ..moveTo(s * 0.25, s * 0.52)
      ..lineTo(s * 0.39, s * 0.64)
      ..lineTo(s * 0.37, s * 0.85)
      ..lineTo(s * 0.26, s * 0.85)
      ..lineTo(s * 0.28, s * 0.67)
      ..close();
    canvas.drawPath(frontLeftShadow, Paint()..color = const Color(0xFF6E3D14));
    canvas.drawPath(frontLeft, outline);

    // 4. Front-right foreground stone
    final Path frontRight = Path()
      ..moveTo(s * 0.51, s * 0.85)
      ..lineTo(s * 0.53, s * 0.59)
      ..lineTo(s * 0.70, s * 0.48)
      ..lineTo(s * 0.89, s * 0.59)
      ..lineTo(s * 0.90, s * 0.83)
      ..lineTo(s * 0.74, s * 0.86)
      ..close();
    canvas.drawPath(frontRight, Paint()..color = const Color(0xFFD68C45));
    final Path frontRightTop = Path()
      ..moveTo(s * 0.53, s * 0.59)
      ..lineTo(s * 0.70, s * 0.48)
      ..lineTo(s * 0.77, s * 0.58)
      ..lineTo(s * 0.64, s * 0.67)
      ..close();
    canvas.drawPath(frontRightTop, Paint()..color = const Color(0xFFE29E5A));
    final Path frontRightShadow = Path()
      ..moveTo(s * 0.77, s * 0.58)
      ..lineTo(s * 0.89, s * 0.59)
      ..lineTo(s * 0.90, s * 0.83)
      ..lineTo(s * 0.74, s * 0.86)
      ..lineTo(s * 0.68, s * 0.67)
      ..close();
    canvas.drawPath(frontRightShadow, Paint()..color = const Color(0xFF4E2A0C));
    canvas.drawLine(_p(s, 0.68, 0.67), _p(s, 0.77, 0.58), innerCrease);
    canvas.drawPath(frontRight, outline);
  }

  void _paintMetal(Canvas canvas, double s, double strokeWidth) {
    final Offset center = Offset(s * 0.50, s * 0.50);
    final double outerRadius = s * 0.41;
    final double grooveRadius = s * 0.295;
    final double hubRadius = s * 0.185;
    final Rect outerBounds = Rect.fromCircle(center: center, radius: outerRadius);
    final Rect hubBounds = Rect.fromCircle(center: center, radius: hubRadius);

    // 1. Beveled bright silver-steel outer disc
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFECEFF1),
            Color(0xFFB0BEC5),
            Color(0xFF78909C),
          ],
          stops: [0.0, 0.52, 1.0],
        ).createShader(outerBounds),
    );

    // Top-left bright bevel arc highlight on outer ring
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius * 0.88),
      3.55,
      1.8,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.045).clamp(0.7, 1.8)
        ..strokeCap = StrokeCap.round,
    );

    // Outer forged-steel dark outline
    canvas.drawCircle(center, outerRadius, _outlinePaint(strokeWidth));

    // 2. Recessed dark-slate metallic groove
    canvas.drawCircle(
      center,
      grooveRadius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF455A64),
            Color(0xFF607D8B),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: grooveRadius)),
    );
    canvas.drawCircle(
      center,
      grooveRadius,
      _outlinePaint((strokeWidth * 0.78).clamp(0.85, 1.9)),
    );

    // 3. Raised central steel boss/hub with diagonal metallic sheen
    canvas.drawCircle(
      center,
      hubRadius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFECEFF1),
            Color(0xFFB0BEC5),
            Color(0xFF78909C),
          ],
          stops: [0.0, 0.35, 0.72, 1.0],
        ).createShader(hubBounds),
    );

    // Crisp white diagonal metallic sheen band clipped inside central hub
    canvas.save();
    canvas.clipPath(Path()..addOval(hubBounds));
    final Path sheen = Path()
      ..moveTo(s * 0.34, s * 0.56)
      ..lineTo(s * 0.56, s * 0.34)
      ..lineTo(s * 0.62, s * 0.40)
      ..lineTo(s * 0.40, s * 0.62)
      ..close();
    canvas.drawPath(
      sheen,
      Paint()..color = Colors.white.withValues(alpha: 0.82),
    );
    canvas.restore();

    canvas.drawCircle(
      center,
      hubRadius,
      _outlinePaint((strokeWidth * 0.85).clamp(0.9, 2.0)),
    );
  }

  @override
  bool shouldRepaint(covariant _ElementalSymbolPainter oldDelegate) {
    return oldDelegate.move != move;
  }
}
