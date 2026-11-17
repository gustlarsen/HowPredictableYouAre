import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';

class HintsBar extends StatelessWidget {
  final GameController controller;

  const HintsBar({super.key, required this.controller});

  String _formatMoves(List<HandMove> moves) {
    if (moves.isEmpty || moves.length >= controller.engine.size) {
      return '?';
    }
    return moves.map((m) => m.emoji).join(' ');
  }

  List<HandMove> _visibleMoves(List<HandMove> moves) {
    if (moves.isEmpty || moves.length >= controller.engine.size) {
      return const [];
    }
    return moves;
  }

  @override
  Widget build(BuildContext context) {
    final loc = controller.localization;
    final elemental = controller.isElementalMode;
    final hasAnyHint = controller.showYourPrediction ||
        controller.showNextMove ||
        controller.showSuggestion ||
        controller.showCrystalBall;

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
              label: loc.t('string12', fallback: 'You will Chose:'),
              value: _formatMoves(controller.predictedUserMoves),
              moves: _visibleMoves(controller.predictedUserMoves),
              elementalMode: elemental,
              localization: loc,
              color: Colors.blueAccent,
            ),
          if (controller.showNextMove)
            _HintChip(
              icon: Icons.smart_toy_outlined,
              label: loc.t('string13', fallback: 'PC will Chose:'),
              value: _formatMoves(controller.pcNextMoves),
              moves: _visibleMoves(controller.pcNextMoves),
              elementalMode: elemental,
              localization: loc,
              color: Colors.orangeAccent,
            ),
          if (controller.showSuggestion)
            _HintChip(
              icon: Icons.lightbulb_outline,
              label: loc.t('string14', fallback: 'Suggestion:'),
              value: _formatMoves(controller.suggestedMoves),
              moves: _visibleMoves(controller.suggestedMoves),
              elementalMode: elemental,
              localization: loc,
              color: Colors.greenAccent,
            ),
          if (controller.showCrystalBall &&
              controller.showCrystalBallPlus &&
              controller.crystalBallPlusMove != null)
            _HintChip(
              icon: Icons.auto_awesome,
              label: loc.t('string83', fallback: 'Crystal Ball+:'),
              value: controller.crystalBallPlusMove!.emoji,
              moves: [controller.crystalBallPlusMove!],
              elementalMode: elemental,
              localization: loc,
              color: Colors.purpleAccent,
            )
          else if (controller.showCrystalBall &&
              controller.crystalBallMove != null)
            _HintChip(
              icon: Icons.auto_awesome,
              label: loc.t('string81', fallback: 'Crystal Ball:'),
              value: controller.crystalBallMove!.emoji,
              moves: [controller.crystalBallMove!],
              elementalMode: elemental,
              localization: loc,
              color: Colors.purpleAccent,
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
  final List<HandMove> moves;
  final bool elementalMode;
  final dynamic localization;
  final Color color;

  const _HintChip({
    required this.icon,
    required this.label,
    required this.value,
    this.moves = const [],
    this.elementalMode = false,
    this.localization,
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
          if (elementalMode && moves.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < moves.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Icon(
                    moves[i].elementalIcon,
                    size: 16,
                    color: moves[i].elementalPrimaryColor,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    moves[i].displayLabel(
                      elemental: true,
                      localization: localization,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: moves[i].elementalPrimaryColor,
                    ),
                  ),
                ],
              ],
            )
          else
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}
