import 'package:flutter/material.dart';
import '../../services/markov_engine.dart';
import '../../services/localization_service.dart';
import '../../models/move.dart';
import '../../theme/app_theme.dart';

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

  Widget _buildMoveHeader(
    AppPalette palette,
    HandMove move, {
    bool isHighlighted = false,
  }) {
    if (elementalMode) {
      final elementColor = palette.elementalText(move);
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                move.elementalIcon,
                size: 18,
                color: elementColor,
              ),
              Text(
                move.displayLabel(elemental: true, localization: localization),
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight:
                      isHighlighted ? FontWeight.bold : FontWeight.w600,
                  color: elementColor,
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
    final palette = AppPalette.of(context);

    return Card(
      color: palette.isDark
          ? theme.colorScheme.surface.withValues(alpha: 0.9)
          : palette.deckSurface,
      surfaceTintColor: palette.isDark ? null : Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: palette.isDark
            ? BorderSide.none
            : BorderSide(color: palette.sandCardBorder),
      ),
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
                color: palette.primaryText,
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
                    ...moves.map((m) => _buildMoveHeader(palette, m)),
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
                            color: palette.amberBorder.withValues(
                              alpha: palette.isDark ? 0.15 : 0.18,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    children: [
                      // Row header
                      _buildMoveHeader(
                        palette,
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
                                ? palette.amberBorder.withValues(
                                    alpha: palette.isDark ? 0.3 : 0.24,
                                  )
                                : (palette.isDark
                                      ? theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.4)
                                      : palette.sandCardSurface),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isMax
                                  ? (palette.isDark
                                        ? Colors.amber
                                        : palette.amberIcon)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$val',
                              style: TextStyle(
                                fontWeight: isMax
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isMax
                                    ? palette.amberText
                                    : palette.primaryText,
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
