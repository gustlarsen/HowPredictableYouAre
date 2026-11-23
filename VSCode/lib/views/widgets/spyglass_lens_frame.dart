import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brass & cyan crystal spyglass aperture bezel framing a circular spyglass view.
class SpyglassLensFrame extends StatelessWidget {
  final Widget child;

  const SpyglassLensFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE082),
            Color(0xFFFFB300),
            Color(0xFF8C5200),
            Color(0xFF4A2C00),
          ],
          stops: [0.0, 0.35, 0.72, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF141B24),
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              // Subtle optical glass reflection arc & inner lens ring
              IgnorePointer(
                child: CustomPaint(
                  painter: _SpyglassOpticsOverlayPainter(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpyglassOpticsOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = math.min(size.width, size.height) * 0.5;

    // Faint inner cyan-gold lens ring
    canvas.drawCircle(
      center,
      radius - 2.0,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Subtle curved glass reflection glint on upper-left lens quadrant
    final arcRect = Rect.fromCircle(center: center, radius: radius * 0.88);
    canvas.drawArc(
      arcRect,
      -math.pi * 0.82,
      math.pi * 0.28,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
