import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/watch_tower_icon.dart';
import '../widgets/watchtower_cell_shader_view.dart';

/// Focused telescope/spyglass observation modal displaying the live animated
/// GLSL shader view of the captive Princess inside the dungeon cell.
class WatchtowerSpyglassDialog extends StatelessWidget {
  final GameController controller;

  const WatchtowerSpyglassDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final loc = controller.localization;
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Dialog(
      key: const ValueKey('watchtower_spyglass_dialog'),
      backgroundColor: palette.isDark
          ? const Color(0xFF0D1119)
          : palette.dialogSurface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: palette.isDark
              ? const Color(0xFF00E5FF).withValues(alpha: 0.35)
              : palette.amberBorder.withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(
                        alpha: palette.isDark ? 0.14 : 0.10,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.55),
                      ),
                    ),
                    child: const WatchTowerIcon(size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loc.t(
                        'observatory_spyglass_title',
                        fallback: 'Dungeon Spyglass',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: palette.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Circular Brass-Framed Spyglass Viewport
              Flexible(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth;
                    final maxH = constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : maxW;
                    final diameter = math.min(maxW, math.min(maxH, 380.0));
                    return Center(
                      child: SizedBox(
                        width: diameter,
                        height: diameter,
                        child: _SpyglassLensFrame(
                          child: WatchtowerCellShaderView(
                            animationsEnabled: controller.animationsEnabled,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Subtle lore caption
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  loc.t(
                    'observatory_spyglass_caption',
                    fallback:
                        'Through the Watch Tower lens, the captive Princess awaits rescue...',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                    color: palette.isDark
                        ? const Color(0xFFCFE8FF).withValues(alpha: 0.85)
                        : palette.secondaryText,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Clean Close Button at bottom
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const ValueKey('watchtower_spyglass_close_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.isDark
                        ? const Color(0xFFFFE082)
                        : palette.amberText,
                    side: BorderSide(
                      color: palette.isDark
                          ? const Color(0xFFFFB300).withValues(alpha: 0.65)
                          : palette.amberBorder,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    controller.audio.playTapVibrate();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    loc.t('observatory_spyglass_close_btn', fallback: 'Close'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brass & cyan crystal spyglass aperture bezel framing the circular shader view.
class _SpyglassLensFrame extends StatelessWidget {
  final Widget child;

  const _SpyglassLensFrame({required this.child});

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
