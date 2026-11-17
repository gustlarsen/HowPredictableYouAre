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

  Widget _buildRow(List<Widget> chips) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (int i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: chips[i]),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = controller.localization;
    final elemental = controller.isElementalMode;

    final topChips = <Widget>[
      if (controller.showYourPrediction)
        _HintChip(
          icon: Icons.psychology_outlined,
          label: loc.t('string12', fallback: 'Your Choice:'),
          value: _formatMoves(controller.predictedUserMoves),
          moves: _visibleMoves(controller.predictedUserMoves),
          elementalMode: elemental,
          color: Colors.blueAccent,
        ),
      if (controller.showNextMove)
        _HintChip(
          icon: Icons.smart_toy_outlined,
          label: loc.t('string13', fallback: 'PC\'s Choice:'),
          value: _formatMoves(controller.pcNextMoves),
          moves: _visibleMoves(controller.pcNextMoves),
          elementalMode: elemental,
          color: Colors.orangeAccent,
        ),
    ];

    final bottomChips = <Widget>[
      if (controller.showSuggestion)
        _HintChip(
          icon: Icons.lightbulb_outline,
          label: loc.t('string14', fallback: 'Suggestion:'),
          value: _formatMoves(controller.suggestedMoves),
          moves: _visibleMoves(controller.suggestedMoves),
          elementalMode: elemental,
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
          color: Colors.purpleAccent,
        ),
    ];

    if (topChips.isEmpty && bottomChips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (topChips.isNotEmpty) _buildRow(topChips),
          if (topChips.isNotEmpty && bottomChips.isNotEmpty)
            const SizedBox(height: 8),
          if (bottomChips.isNotEmpty) _buildRow(bottomChips),
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
  final Color color;

  const _HintChip({
    required this.icon,
    required this.label,
    required this.value,
    this.moves = const [],
    this.elementalMode = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(width: 3),
              if (elementalMode && moves.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < moves.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Icon(
                        moves[i].elementalIcon,
                        size: 15,
                        color: moves[i].elementalPrimaryColor,
                      ),
                    ],
                  ],
                )
              else
                Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
