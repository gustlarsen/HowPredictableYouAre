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
  final bool isArchmageShortTermView;
  final bool isBabyMageRandomView;
  final bool isMetalWizardView;

  const MarkovMatrixView({
    super.key,
    required this.engine,
    this.lastUserMove,
    this.elementalMode = false,
    this.localization,
    this.isArchmageShortTermView = false,
    this.isBabyMageRandomView = false,
    this.isMetalWizardView = false,
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

  Widget _buildModeBanner(AppPalette palette) {
    final loc = localization;
    if (isArchmageShortTermView) {
      final accent = palette.purpleAccent;
      final title = loc?.t(
            'markov_recalibrator_banner_title',
            fallback: 'Recalibrated: 1-Step Short-Term Memory',
          ) ??
          'Recalibrated: 1-Step Short-Term Memory';
      final body = loc?.t(
            'markov_recalibrator_archmage_banner',
            fallback:
                'Robot Archmage ignores cumulative history and counters only your single most recent state transition.',
          ) ??
          'Robot Archmage ignores cumulative history and counters only your single most recent state transition.';
      return Container(
        key: const ValueKey('markov_archmage_short_term_banner'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: palette.isDark ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: accent.withValues(alpha: 0.65),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_fix_high_rounded, size: 17, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: palette.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: palette.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (isMetalWizardView) {
      const accent = Color(0xFF90A4AE);
      final body = loc?.t(
            'markov_metal_wizard_banner',
            fallback:
                'Metal Wizard bypasses the Markov matrix and conjures exclusively Metal (100%) on every turn.',
          ) ??
          'Metal Wizard bypasses the Markov matrix and conjures exclusively Metal (100%) on every turn.';
      return Container(
        key: const ValueKey('markov_metal_wizard_banner'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: palette.isDark ? 0.16 : 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: accent.withValues(alpha: 0.65),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.hardware_rounded, size: 17, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                body,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: palette.secondaryText,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (isBabyMageRandomView) {
      final accent = palette.orangeAccent;
      final body = loc?.t(
            'markov_baby_mage_banner',
            fallback:
                'Baby Mage Robot ignores all transition history and picks uniformly at random (1/5 per element).',
          ) ??
          'Baby Mage Robot ignores all transition history and picks uniformly at random (1/5 per element).';
      return Container(
        key: const ValueKey('markov_baby_mage_random_banner'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: palette.isDark ? 0.14 : 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: accent.withValues(alpha: 0.60),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.casino_outlined, size: 17, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                body,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: palette.secondaryText,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final moves = engine.activeMoves;
    final matrix = engine.matrix;
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final headerTitle = isArchmageShortTermView
        ? (localization?.t(
              'markov_matrix_short_term_title',
              fallback: 'Markov Short-Term Memory (Recalibrated)',
            ) ??
            'Markov Short-Term Memory (Recalibrated)')
        : (localization?.t(
              'markov_matrix_title',
              fallback: 'Markov Transition Matrix',
            ) ??
            'Markov Transition Matrix');

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
              headerTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: palette.primaryText,
              ),
            ),
            const SizedBox(height: 10),
            if (isArchmageShortTermView ||
                isBabyMageRandomView ||
                isMetalWizardView)
              _buildModeBanner(palette),
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
                  final shortTermTarget = isArchmageShortTermView
                      ? engine.lastTransitionFor(rowMove)
                      : null;

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
                        final colMove = moves[colIdx];
                        if (isArchmageShortTermView) {
                          final isActiveLatest = shortTermTarget == colMove;
                          return Container(
                            margin: const EdgeInsets.all(3),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isActiveLatest
                                  ? palette.purpleAccent.withValues(
                                      alpha: palette.isDark ? 0.30 : 0.20,
                                    )
                                  : (palette.isDark
                                        ? theme
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.22)
                                        : palette.sandCardSurface
                                              .withValues(alpha: 0.55)),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isActiveLatest
                                    ? palette.purpleAccent
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: isActiveLatest
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '1',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: palette.purpleAccent,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          '100%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: palette.primaryText,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      '0',
                                      style: TextStyle(
                                        fontWeight: FontWeight.normal,
                                        color: palette.mutedText
                                            .withValues(alpha: 0.55),
                                        fontSize: 12,
                                      ),
                                    ),
                            ),
                          );
                        }

                        final val = row[colIdx];
                        final isMax = !isBabyMageRandomView &&
                            val > 0 &&
                            val == maxVal;

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
                                color: isBabyMageRandomView
                                    ? palette.mutedText.withValues(alpha: 0.65)
                                    : (isMax
                                          ? palette.amberText
                                          : palette.primaryText),
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
