import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renders a luminous 3D translucent elemental energy sphere matching the orbs
/// inside the open Cleric's Backpack illustration, with no embedded symbols.
class ElementalEnergySphere extends StatelessWidget {
  final double size;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isLocked;
  final bool isDark;

  const ElementalEnergySphere({
    super.key,
    required this.size,
    required this.primaryColor,
    required this.secondaryColor,
    this.isLocked = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(size, size),
        painter: _ElementalEnergySpherePainter(
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          isLocked: isLocked,
          isDark: isDark,
        ),
      ),
    );
  }
}

class _ElementalEnergySpherePainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final bool isLocked;
  final bool isDark;

  _ElementalEnergySpherePainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.isLocked,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);
    final radius = math.min(w, h) * 0.42;

    // 1. Soft Outer Radial Glow
    final outerGlowAlpha = isDark
        ? (isLocked ? 0.36 : 0.62)
        : (isLocked ? 0.24 : 0.42);
    canvas.drawCircle(
      center,
      radius * (isLocked ? 1.28 : 1.40),
      Paint()
        ..color = primaryColor.withValues(alpha: outerGlowAlpha)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          isLocked ? 5.5 : 8.0,
        ),
    );

    // 2. Translucent 3D Sphere Base Gradient
    final sphereRect = Rect.fromCircle(center: center, radius: radius);
    final coreTint = Color.lerp(primaryColor, Colors.white, 0.72)!;
    final deepEdge = Color.lerp(secondaryColor, const Color(0xFF0A0C12), 0.46)!;
    final shadowRim =
        Color.lerp(secondaryColor, const Color(0xFF06080E), 0.74)!;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.26, -0.28),
          radius: 0.96,
          colors: [
            coreTint.withValues(alpha: isLocked ? 0.88 : 0.98),
            primaryColor.withValues(alpha: isLocked ? 0.85 : 0.96),
            deepEdge.withValues(alpha: 0.95),
            shadowRim,
          ],
          stops: const [0.0, 0.36, 0.76, 1.0],
        ).createShader(sphereRect),
    );

    // Clip internal light layers to the sphere boundary
    canvas.save();
    canvas.clipPath(Path()..addOval(sphereRect));

    // 3. Bright Inner Energy Core
    final innerCoreCenter = center + Offset(-radius * 0.14, -radius * 0.16);
    canvas.drawCircle(
      innerCoreCenter,
      radius * 0.62,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: isLocked ? 0.52 : 0.76),
            primaryColor.withValues(alpha: isLocked ? 0.25 : 0.42),
            Colors.transparent,
          ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(
          Rect.fromCircle(center: innerCoreCenter, radius: radius * 0.62),
        ),
    );

    // 4. Translucent Internal Caustic / Bottom-Right Bounce Reflection
    final bounceCenter = center + Offset(radius * 0.34, radius * 0.36);
    canvas.drawCircle(
      bounceCenter,
      radius * 0.52,
      Paint()
        ..color = Color.lerp(primaryColor, Colors.white, 0.48)!
            .withValues(alpha: isLocked ? 0.22 : 0.36)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );

    // 5. Curved Glossy Glass Highlight (Top-Left Specular Arc)
    canvas.save();
    canvas.translate(
      center.dx - radius * 0.34,
      center.dy - radius * 0.36,
    );
    canvas.rotate(-math.pi / 4.8);
    final highlightRect = Rect.fromCenter(
      center: Offset.zero,
      width: radius * 0.66,
      height: radius * 0.32,
    );
    canvas.drawOval(
      highlightRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: isLocked ? 0.68 : 0.90),
            Colors.white.withValues(alpha: 0.08),
          ],
        ).createShader(highlightRect),
    );
    canvas.restore();

    // Small crisp specular glint dot
    canvas.drawCircle(
      center + Offset(-radius * 0.46, -radius * 0.22),
      radius * 0.085,
      Paint()..color = Colors.white.withValues(alpha: isLocked ? 0.65 : 0.88),
    );

    canvas.restore();

    // 6. Luminous Translucent Rim Border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Color.lerp(primaryColor, Colors.white, 0.40)!
            .withValues(alpha: isLocked ? 0.68 : 0.94)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  @override
  bool shouldRepaint(_ElementalEnergySpherePainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.isLocked != isLocked ||
        oldDelegate.isDark != isDark;
  }
}
