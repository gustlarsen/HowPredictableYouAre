import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';

class ScoreHeader extends StatelessWidget {
  final GameController controller;

  const ScoreHeader({super.key, required this.controller});

  static const Color emeraldGreen = Color(0xFF2ECC71);
  static const Color amberGold = Color(0xFFFFB300);
  static const Color crimsonRed = Color(0xFFE74C3C);

  /// Returns a semantic color matching the RPG HP bar aesthetic:
  /// - Emerald green (`0xFF2ECC71`) for high percentages (>= 60%)
  /// - Amber/gold (`0xFFFFB300`) for moderate percentages (30%–59%)
  /// - Crimson red (`0xFFE74C3C`) for low percentages (< 30%)
  static Color gaugeColor(double percentPredict) {
    final clamped = percentPredict.clamp(0.0, 100.0);
    if (clamped >= 60.0) {
      return emeraldGreen;
    } else if (clamped >= 30.0) {
      return amberGold;
    } else {
      return crimsonRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.unlockedPredictability || !controller.showPredictability) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final loc = controller.localization;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ScoreItem(
              label: loc.t('string6', fallback: 'You'),
              value: '${controller.userScore}',
              color: Colors.green,
            ),
            Container(width: 1, height: 28, color: theme.dividerColor),
            _ScoreItem(
              label: loc.t('string7', fallback: 'PC'),
              value: '${controller.pcScore}',
              color: Colors.redAccent,
            ),
            Container(width: 1, height: 28, color: theme.dividerColor),
            _ScoreItem(
              label: loc.t('string8', fallback: 'Total'),
              value: '${controller.totalRounds}',
              color: Colors.grey,
            ),
            Container(width: 1, height: 28, color: theme.dividerColor),
            _ScoreItem(
              label: loc.t('string5', fallback: 'Gauge'),
              value: '${controller.percentPredict.toStringAsFixed(1)}%',
              color: gaugeColor(controller.percentPredict),
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
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
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
