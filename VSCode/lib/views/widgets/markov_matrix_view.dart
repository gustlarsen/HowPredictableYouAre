import 'package:flutter/material.dart';
import '../../services/markov_engine.dart';
import '../../services/localization_service.dart';
import '../../models/move.dart';

class MarkovMatrixView extends StatelessWidget {
  final MarkovEngine engine;
  final HandMove? lastUserMove;
  final bool elementalMode;
  final LocalizationService? localization;

  const MarkovMatrixView({
    super.key,
    required this.engine,
    this.lastUserMove,
    this.elementalMode = false,
    this.localization,
  });

  Widget _buildMoveHeader(HandMove move, {bool isHighlighted = false}) {
    if (elementalMode) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                move.elementalIcon,
                size: 18,
                color: move.elementalPrimaryColor,
              ),
              Text(
                move.displayLabel(elemental: true, localization: localization),
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight:
                      isHighlighted ? FontWeight.bold : FontWeight.w600,
                  color: move.elementalPrimaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Text(
        move.emoji,
        style: TextStyle(
          fontSize: 20,
          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moves = engine.activeMoves;
    final matrix = engine.matrix;
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surface.withValues(alpha: 0.9),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Markov Transition Matrix',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                // Header row
                TableRow(
                  children: [
                    const SizedBox(width: 32),
                    ...moves.map((m) => _buildMoveHeader(m)),
                  ],
                ),
                // Matrix rows
                ...List.generate(moves.length, (rowIdx) {
                  final rowMove = moves[rowIdx];
                  final isCurrentLastMove = lastUserMove == rowMove;
                  final row = matrix[rowIdx];
                  final maxVal = row.reduce((a, b) => a > b ? a : b);

                  return TableRow(
                    decoration: isCurrentLastMove
                        ? BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    children: [
                      // Row header
                      _buildMoveHeader(
                        rowMove,
                        isHighlighted: isCurrentLastMove,
                      ),
                      // Row cells
                      ...List.generate(moves.length, (colIdx) {
                        final val = row[colIdx];
                        final isMax = val > 0 && val == maxVal;

                        return Container(
                          margin: const EdgeInsets.all(3),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isMax
                                ? Colors.amber.withValues(alpha: 0.3)
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isMax ? Colors.amber : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$val',
                              style: TextStyle(
                                fontWeight: isMax ? FontWeight.bold : FontWeight.normal,
                                color: isMax ? Colors.amber : theme.colorScheme.onSurface,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
