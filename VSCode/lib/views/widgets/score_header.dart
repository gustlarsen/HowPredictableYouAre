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

    final palette = AppPalette.of(context);
    final loc = controller.localization;
    final gColor = gaugeColor(
      controller.percentPredict,
      isDark: palette.isDark,
    );

    final cardBg = palette.isDark
        ? const Color(0xFF151820).withValues(alpha: 0.90)
        : palette.dialogSurface.withValues(alpha: 0.95);
    final borderColor = palette.isDark
        ? const Color(0xFF8A6D3B)
        : palette.sandCardBorder;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      elevation: 3,
      color: cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: 1.25),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _InlineScoreCounter(
                    label: loc.t('string6', fallback: 'Your Score:'),
                    value: '${controller.userScore}',
                    valueColor: palette.isDark
                        ? Colors.white
                        : palette.primaryText,
                  ),
                  const SizedBox(width: 12),
                  _InlineScoreCounter(
                    label: loc.t('string7', fallback: 'PC Score:'),
                    value: '${controller.pcScore}',
                    valueColor: palette.isDark
                        ? Colors.white
                        : palette.primaryText,
                  ),
                  const SizedBox(width: 12),
                  _InlineScoreCounter(
                    label: loc.t('string8', fallback: 'Total:'),
                    value: '${controller.totalRounds}',
                    valueColor: palette.isDark
                        ? Colors.white
                        : palette.primaryText,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Container(
              key: const ValueKey('score_header_gauge_pill'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2.5),
              decoration: BoxDecoration(
                color: gColor.withValues(alpha: palette.isDark ? 0.22 : 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: gColor.withValues(alpha: palette.isDark ? 0.78 : 0.65),
                  width: 1.15,
                ),
                boxShadow: [
                  if (palette.isDark)
                    BoxShadow(
                      color: gColor.withValues(alpha: 0.20),
                      blurRadius: 6,
                    ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc.t('string5', fallback: 'Gauge'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: gColor,
                    ),
                  ),
                  Text(
                    ': ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: gColor,
                    ),
                  ),
                  Text(
                    '${controller.percentPredict.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: gColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineScoreCounter extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _InlineScoreCounter({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final normalizedLabel = label.endsWith(':') ? label : '$label:';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          normalizedLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: palette.isDark
                ? const Color(0xFFB5BAC6)
                : palette.secondaryText,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
