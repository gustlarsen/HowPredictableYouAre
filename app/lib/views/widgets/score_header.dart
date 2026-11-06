import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';

class ScoreHeader extends StatelessWidget {
  final GameController controller;

  const ScoreHeader({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = controller.localization;
    final tier = controller.evaluationTier;

    return Column(
      children: [
        // Top row: Diamonds & Predictability %
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Diamonds Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💎', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    '${controller.diamonds}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),

            // Predictability score (if unlocked / enabled)
            if (controller.showPredictability)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${loc.t('string5', fallback: 'Predictability')}: ',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${controller.percentPredict.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.purpleAccent,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        // Scoreboard Card
        Card(
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
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Evaluation Pill / 100-round progress
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${loc.t('string2', fallback: 'You are')}: ',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                loc.t(tier.key, fallback: tier.fallbackDescription),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: controller.totalRounds >= 100 ? Colors.amber : Colors.blueGrey,
                ),
              ),
              if (controller.totalRounds < 100) ...[
                const SizedBox(width: 6),
                Text(
                  '(${controller.totalRounds}/100)',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ],
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
