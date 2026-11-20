import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../theme/app_theme.dart';

class HintsBar extends StatelessWidget {
  final GameController controller;

  const HintsBar({super.key, required this.controller});

  String _formatMoves(List<HandMove> moves, {required int poolSize}) {
    if (moves.isEmpty || moves.length >= poolSize) {
      return '?';
    }
    return moves.map((m) => m.emoji).join(' ');
  }

  List<HandMove> _visibleMoves(List<HandMove> moves, {required int poolSize}) {
    if (moves.isEmpty || moves.length >= poolSize) {
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
    final palette = AppPalette.of(context);
    final elemental = controller.isElementalMode;
    final playerPoolSize = controller.engine.size;
    final enemyPoolSize = controller.engine.enemySize;

    final topChips = <Widget>[
      if (controller.showYourPrediction)
        _HintChip(
          icon: Icons.psychology_outlined,
          label: loc.t('string12', fallback: 'Your Choice:'),
          value: _formatMoves(
            controller.predictedUserMoves,
            poolSize: playerPoolSize,
          ),
          moves: _visibleMoves(
            controller.predictedUserMoves,
            poolSize: playerPoolSize,
          ),
          elementalMode: elemental,
          color: palette.blueAccent,
        ),
      if (controller.showNextMove)
        _HintChip(
          icon: Icons.smart_toy_outlined,
          label: loc.t('string13', fallback: 'PC\'s Choice:'),
          value: _formatMoves(
            controller.pcNextMoves,
            poolSize: enemyPoolSize,
          ),
          moves: _visibleMoves(
            controller.pcNextMoves,
            poolSize: enemyPoolSize,
          ),
          elementalMode: elemental,
          color: palette.orangeAccent,
        ),
    ];

    final bottomChips = <Widget>[
      if (controller.showSuggestion)
        _HintChip(
          icon: Icons.lightbulb_outline,
          label: loc.t('string14', fallback: 'Suggestion:'),
          value: _formatMoves(
            controller.suggestedMoves,
            poolSize: playerPoolSize,
          ),
          moves: _visibleMoves(
            controller.suggestedMoves,
            poolSize: playerPoolSize,
          ),
          elementalMode: elemental,
          color: palette.successText,
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
          color: palette.purpleAccent,
        )
      else if (controller.showCrystalBall &&
          controller.crystalBallMove != null)
        _HintChip(
          icon: Icons.auto_awesome,
          label: loc.t('string81', fallback: 'Crystal Ball:'),
          value: controller.crystalBallMove!.emoji,
          moves: [controller.crystalBallMove!],
          elementalMode: elemental,
          color: palette.purpleAccent,
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
  static const double pillHeight = 34.0;
  static const double iconSlotSize = 16.0;

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
    final palette = AppPalette.of(context);
    final backgroundColor = palette.isDark
        ? color.withValues(alpha: 0.12)
        : Color.alphaBlend(
            color.withValues(alpha: 0.12),
            const Color(0xFFFAF6EE),
          ).withValues(alpha: 0.94);

    return SizedBox(
      height: pillHeight,
      child: Container(
        height: pillHeight,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: palette.isDark ? 0.4 : 0.6),
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              height: iconSlotSize,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: iconSlotSize,
                    height: iconSlotSize,
                    child: Center(
                      child: Icon(icon, size: 15, color: color),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.0,
                      fontWeight:
                          palette.isDark ? FontWeight.normal : FontWeight.w600,
                      color:
                          palette.isDark ? Colors.grey : palette.secondaryText,
                    ),
                  ),
                  const SizedBox(width: 3),
                  if (elementalMode && moves.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (int i = 0; i < moves.length; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          SizedBox(
                            width: iconSlotSize,
                            height: iconSlotSize,
                            child: Center(
                              child: Icon(
                                moves[i].elementalIcon,
                                size: 15,
                                color: palette.elementalText(moves[i]),
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  else if (value == '?')
                    SizedBox(
                      width: iconSlotSize,
                      height: iconSlotSize,
                      child: Center(
                        child: Text(
                          '?',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.0,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: iconSlotSize,
                      child: Center(
                        child: Text(
                          value,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.0,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
