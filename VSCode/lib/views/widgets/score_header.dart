import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../theme/app_theme.dart';

class ScoreHeader extends StatelessWidget {
  final GameController controller;

  const ScoreHeader({super.key, required this.controller});

  static const Color emeraldGreen = Color(0xFF2ECC71);
  static const Color amberGold = Color(0xFFFFB300);
  static const Color crimsonRed = Color(0xFFE74C3C);

  static const Color lightEmeraldGreen = Color(0xFF1B6E36);
  static const Color lightAmberBronze = Color(0xFF8A5A00);
  static const Color lightCrimsonRed = Color(0xFFC62828);

  /// Returns a semantic color matching the RPG HP bar aesthetic:
  /// - Emerald green (`0xFF2ECC71` in Dark Mode, `0xFF1B6E36` in Light Mode) for high percentages (>= 60%)
  /// - Amber/gold (`0xFFFFB300` in Dark Mode, `0xFF8A5A00` in Light Mode) for moderate percentages (30%–59%)
  /// - Crimson red (`0xFFE74C3C` in Dark Mode, `0xFFC62828` in Light Mode) for low percentages (< 30%)
  static Color gaugeColor(double percentPredict, {bool isDark = true}) {
    final clamped = percentPredict.clamp(0.0, 100.0);
    if (clamped >= 60.0) {
      return isDark ? emeraldGreen : lightEmeraldGreen;
    } else if (clamped >= 30.0) {
      return isDark ? amberGold : lightAmberBronze;
    } else {
      return isDark ? crimsonRed : lightCrimsonRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.unlockedPredictability || !controller.showPredictability) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final loc = controller.localization;
    final dividerColor = palette.isDark ? theme.dividerColor : palette.divider;

    return Card(
      elevation: 2,
      color: palette.isDark ? null : palette.dialogSurface.withValues(alpha: 0.95),
      surfaceTintColor: palette.isDark ? null : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: palette.isDark
            ? BorderSide.none
            : BorderSide(color: palette.sandCardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ScoreItem(
              label: loc.t('string6', fallback: 'You'),
              value: '${controller.userScore}',
              color: palette.isDark ? Colors.green : palette.successText,
            ),
            Container(width: 1, height: 28, color: dividerColor),
            _ScoreItem(
              label: loc.t('string7', fallback: 'PC'),
              value: '${controller.pcScore}',
              color: palette.dangerText,
            ),
            Container(width: 1, height: 28, color: dividerColor),
            _ScoreItem(
              label: loc.t('string8', fallback: 'Total'),
              value: '${controller.totalRounds}',
              color: palette.isDark ? Colors.grey : palette.secondaryText,
            ),
            Container(width: 1, height: 28, color: dividerColor),
            _ScoreItem(
              label: loc.t('string5', fallback: 'Gauge'),
              value: '${controller.percentPredict.toStringAsFixed(1)}%',
              color: gaugeColor(
                controller.percentPredict,
                isDark: palette.isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ScoreItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: palette.isDark ? FontWeight.normal : FontWeight.w600,
            color: palette.isDark ? Colors.grey : palette.mutedText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: color,
          ),
        ),
      ],
    );
  }
}
