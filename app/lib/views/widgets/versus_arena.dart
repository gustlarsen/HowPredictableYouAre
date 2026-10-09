import 'package:flutter/material.dart';
import '../../models/move.dart';
import '../../services/localization_service.dart';

class VersusArena extends StatelessWidget {
  final HandMove? userMove;
  final HandMove? computerMove;
  final RoundWinner? winner;
  final LocalizationService localization;

  const VersusArena({
    super.key,
    required this.userMove,
    required this.computerMove,
    required this.winner,
    required this.localization,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color outcomeColor;
    String outcomeText;
    switch (winner) {
      case RoundWinner.user:
        outcomeColor = Colors.green;
        outcomeText = localization.t('string51', fallback: 'YOU');
        break;
      case RoundWinner.computer:
        outcomeColor = Colors.redAccent;
        outcomeText = localization.t('string50', fallback: 'PC');
        break;
      case RoundWinner.draw:
        outcomeColor = Colors.amber;
        outcomeText = 'DRAW';
        break;
      case null:
        outcomeColor = Colors.grey;
        outcomeText = localization.t('string20', fallback: 'NONE');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: winner != null ? outcomeColor.withValues(alpha: 0.5) : theme.dividerColor,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // User Move Side
              _MoveCard(
                label: localization.t('string9', fallback: 'You Chose:'),
                move: userMove,
                isLeft: true,
                isWinner: winner == RoundWinner.user,
              ),

              // VS divider
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),

              // Computer Move Side
              _MoveCard(
                label: localization.t('string52', fallback: 'PC Chose:'),
                move: computerMove,
                isLeft: false,
                isWinner: winner == RoundWinner.computer,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Winner Announcement Banner
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${localization.t('string10', fallback: 'Winner')}: ',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: outcomeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: outcomeColor, width: 1),
                ),
                child: Text(
                  outcomeText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: outcomeColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoveCard extends StatelessWidget {
  final String label;
  final HandMove? move;
  final bool isLeft;
  final bool isWinner;

  const _MoveCard({
    required this.label,
    required this.move,
    required this.isLeft,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = isLeft ? move?.leftAsset : move?.rightAsset;
    final hasAsset = assetPath != null && assetPath.isNotEmpty;

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isWinner
                ? Colors.green.withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: isWinner ? Colors.green : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: move == null
                ? const Text('?', style: TextStyle(fontSize: 32, color: Colors.grey))
                : hasAsset
                    ? Image.asset(
                        assetPath,
                        width: 54,
                        height: 54,
                        errorBuilder: (context, error, stackTrace) => Text(
                          move!.emoji,
                          style: const TextStyle(fontSize: 36),
                        ),
                      )
                    : Text(
                        move!.emoji,
                        style: const TextStyle(fontSize: 36),
                      ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          move?.label.toUpperCase() ?? 'NONE',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
