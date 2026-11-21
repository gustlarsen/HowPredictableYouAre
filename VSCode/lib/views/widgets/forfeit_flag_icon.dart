import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A crisp white surrender flag icon rendered via [CustomPainter].
///
/// Draws a slender metallic/dark-slate flagpole (`#90A4AE` / `#455A64`) with a
/// gently waving white flag cloth (`#FFFFFF`) outlined by a thin slate border
/// (`#455A64`) so it stands out clearly on both Dark Mode and parchment Light
/// Mode surfaces.
class ForfeitFlagIcon extends StatelessWidget {
  final double size;

  const ForfeitFlagIcon({super.key, this.size = 19.0});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(size, size),
        painter: const _ForfeitFlagPainter(),
      ),
    );
  }
}

class _ForfeitFlagPainter extends CustomPainter {
  const _ForfeitFlagPainter();

  static const Color _cPoleMetallic = Color(0xFF90A4AE);
  static const Color _cSlateDark = Color(0xFF455A64);
  static const Color _cFlagWhite = Color(0xFFFFFFFF);
  static const Color _cFlagFoldShadow = Color(0xFFE3E9EE);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final scale = math.min(w, h) / 20.0;

    final poleX = w * 0.23;
    final poleTopY = h * 0.15;
    final poleBottomY = h * 0.89;
    final hoistX = poleX + 0.55 * scale;

    // 1. Gently waving white flag cloth
    final flagPath = Path()
      ..moveTo(hoistX, h * 0.19)
      ..cubicTo(w * 0.44, h * 0.10, w * 0.64, h * 0.27, w * 0.88, h * 0.18)
      ..quadraticBezierTo(w * 0.84, h * 0.37, w * 0.86, h * 0.55)
      ..cubicTo(w * 0.63, h * 0.64, w * 0.44, h * 0.47, hoistX, h * 0.56)
      ..close();

    // Subtle soft drop shadow for lift on light parchment & dark surfaces
    canvas.drawPath(
      flagPath.shift(Offset(0.4 * scale, 0.7 * scale)),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );

    // Pure white flag cloth base
    canvas.drawPath(flagPath, Paint()..color = _cFlagWhite);

    // Subtle wave-trough shading inside the flag for cloth dimension
    canvas.save();
    canvas.clipPath(flagPath);
    final foldRect = Rect.fromLTWH(w * 0.53, h * 0.12, w * 0.22, h * 0.52);
    canvas.drawRect(
      foldRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _cFlagWhite.withValues(alpha: 0.0),
            _cFlagFoldShadow.withValues(alpha: 0.75),
            _cFlagWhite.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(foldRect),
    );
    canvas.restore();

    // Thin slate outline around the white cloth
    canvas.drawPath(
      flagPath,
      Paint()
        ..color = _cSlateDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, 1.15 * scale)
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // 2. Slender metallic/dark-slate flagpole
    canvas.drawLine(
      Offset(poleX, poleTopY),
      Offset(poleX, poleBottomY),
      Paint()
        ..color = _cSlateDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.8, 2.2 * scale)
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawLine(
      Offset(poleX, poleTopY),
      Offset(poleX, poleBottomY - 0.5 * scale),
      Paint()
        ..color = _cPoleMetallic
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.85, 1.0 * scale)
        ..strokeCap = StrokeCap.round,
    );

    // Top finial ball
    final finialCenter = Offset(poleX, h * 0.13);
    final finialRadius = math.max(1.2, 1.45 * scale);
    canvas.drawCircle(
      finialCenter,
      finialRadius,
      Paint()..color = _cPoleMetallic,
    );
    canvas.drawCircle(
      finialCenter,
      finialRadius,
      Paint()
        ..color = _cSlateDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, 0.9 * scale),
    );

    // Small hoist ties connecting the flag to the pole
    final tiePaint = Paint()
      ..color = _cSlateDark
      ..strokeWidth = math.max(0.9, 1.0 * scale)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(poleX - 0.5 * scale, h * 0.21),
      Offset(hoistX + 0.5 * scale, h * 0.21),
      tiePaint,
    );
    canvas.drawLine(
      Offset(poleX - 0.5 * scale, h * 0.54),
      Offset(hoistX + 0.5 * scale, h * 0.54),
      tiePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ForfeitFlagPainter oldDelegate) => false;
}
