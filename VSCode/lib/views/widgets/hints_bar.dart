import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';

class HintsBar extends StatelessWidget {
  final GameController controller;

  const HintsBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final loc = controller.localization;
    final hasAnyHint = controller.showYourPrediction ||
        controller.showNextMove ||
        controller.showSuggestion;

    if (!hasAnyHint) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          if (controller.showYourPrediction)
            _HintChip(
              icon: Icons.psychology_outlined,
              label: loc.t('string12', fallback: 'Probably you choose:'),
              value: controller.predictedUserMove?.emoji ?? '?',
              color: Colors.blueAccent,
            ),
          if (controller.showNextMove)
            _HintChip(
              icon: Icons.smart_toy_outlined,
              label: loc.t('string13', fallback: 'PC will choose:'),
              value: controller.pcNextMove?.emoji ?? '?',
              color: Colors.orangeAccent,
            ),
          if (controller.showSuggestion)
            _HintChip(
              icon: Icons.lightbulb_outline,
              label: loc.t('string14', fallback: 'Suggestion:'),
              value: controller.suggestedMove?.emoji ?? '?',
              color: Colors.greenAccent,
            ),
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _HintChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
