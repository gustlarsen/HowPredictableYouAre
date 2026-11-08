import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';

class ScoreHeader extends StatelessWidget {
  final GameController controller;

  const ScoreHeader({super.key, required this.controller});

  /// Returns a heat-map color interpolating from green (0% predictability,
  /// user has all wins) through yellow (50% predictability, draw) to red
  /// (100% predictability, PC has all wins).
  static Color gaugeColor(double percentPredict) {
    final clamped = percentPredict.clamp(0.0, 100.0);
    if (clamped <= 50.0) {
      final t = clamped / 50.0;
      return Color.lerp(Colors.green, Colors.yellow, t)!;
    } else {
      final t = (clamped - 50.0) / 50.0;
      return Color.lerp(Colors.yellow, Colors.red, t)!;
    }
  }

  @override
  Widget build(BuildContext context) {
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
            if (controller.showPredictability) ...[
              Container(width: 1, height: 28, color: theme.dividerColor),
              _ScoreItem(
                label: loc.t('string5', fallback: 'Gauge'),
                value: '${controller.percentPredict.toStringAsFixed(1)}%',
                color: gaugeColor(controller.percentPredict),
              ),
            ],
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
