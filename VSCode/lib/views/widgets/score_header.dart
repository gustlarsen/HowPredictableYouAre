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
    final dividerColor = palette.isDark
        ? Colors.white.withValues(alpha: 0.14)
        : palette.divider;
    final activeGaugeColor = gaugeColor(
      controller.percentPredict,
      isDark: palette.isDark,
    );

    return Card(
      elevation: 2,
      color: palette.isDark
          ? const Color(0xFF14171F).withValues(alpha: 0.94)
          : palette.dialogSurface.withValues(alpha: 0.95),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: palette.isDark
              ? palette.amberBorder.withValues(alpha: 0.35)
              : palette.sandCardBorder,
          width: 1.1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ScoreItem(
              label: loc.t('string6', fallback: 'You'),
              value: '${controller.userScore}',
              color: palette.isDark ? Colors.green : palette.successText,
            ),
            Container(width: 1, height: 24, color: dividerColor),
            _ScoreItem(
              label: loc.t('string7', fallback: 'PC'),
              value: '${controller.pcScore}',
              color: palette.dangerText,
            ),
            Container(width: 1, height: 24, color: dividerColor),
            _ScoreItem(
              label: loc.t('string8', fallback: 'Total'),
              value: '${controller.totalRounds}',
              color: palette.isDark
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.82)
                  : palette.secondaryText,
            ),
            Container(width: 1, height: 24, color: dividerColor),
            _GaugePill(
              key: const ValueKey('score_header_gauge_pill'),
              label: loc.t('string5', fallback: 'Gauge'),
              value: '${controller.percentPredict.toStringAsFixed(1)}%',
              color: activeGaugeColor,
              isDark: palette.isDark,
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: palette.isDark ? FontWeight.w500 : FontWeight.w600,
            color: palette.isDark ? Colors.grey.shade400 : palette.mutedText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            height: 1.05,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _GaugePill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _GaugePill({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.72 : 0.65),
          width: 1.2,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.22),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white.withValues(alpha: 0.90) : color,
            ),
          ),
          Text(
            ': ',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white.withValues(alpha: 0.75) : color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
              height: 1.0,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
