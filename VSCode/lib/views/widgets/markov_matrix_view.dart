import 'package:flutter/material.dart';
import '../../services/markov_engine.dart';
import '../../services/localization_service.dart';
import '../../models/metal_wizard_ai_state.dart';
import '../../models/move.dart';
import '../../theme/app_theme.dart';
import 'elemental_symbol_icon.dart';
import 'metal_wizard_lair_icon.dart';

class MarkovMatrixView extends StatelessWidget {
  final MarkovEngine engine;
  final HandMove? lastUserMove;
  final bool elementalMode;
  final LocalizationService? localization;
  final bool isArchmageShortTermView;
  final bool isBabyMageRandomView;
  final bool isTempleMasterRandomView;
  final bool isMetalWizardView;
  final MetalWizardAiState? metalWizardAiState;
  final int? currentPiDigit;
  final bool initiallyExpanded;
  final double? maxBodyHeight;

  const MarkovMatrixView({
    super.key,
    required this.engine,
    this.lastUserMove,
    this.elementalMode = false,
    this.localization,
    this.isArchmageShortTermView = false,
    this.isBabyMageRandomView = false,
    this.isTempleMasterRandomView = false,
    this.isMetalWizardView = false,
    this.metalWizardAiState,
    this.currentPiDigit,
    this.initiallyExpanded = true,
    this.maxBodyHeight,
  });

  bool get _dimsTransitionMatrix =>
      isBabyMageRandomView || isTempleMasterRandomView || isMetalWizardView;

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
              ElementalSymbolIcon(
                move: move,
                size: 18,
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

  Widget _buildInlineElementBadge(AppPalette palette, HandMove move) {
    final label = move.displayLabel(
      elemental: elementalMode,
      localization: localization,
    );
    if (elementalMode) {
      final color = palette.elementalText(move);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElementalSymbolIcon(move: move, size: 14),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      );
    }
    return Text(
      '${move.emoji} $label',
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: palette.primaryText,
      ),
    );
  }

  Widget _buildBabyMagePiDecoder(AppPalette palette) {
    final loc = localization;
    final accent = palette.orangeAccent;
    final title = loc?.t(
          'markov_pi_decoder_title',
          fallback: 'Irrational π Core Decoder (C / d = 3.14159...)',
        ) ??
        'Irrational π Core Decoder (C / d = 3.14159...)';
    final subtitle = loc?.t(
          'markov_baby_mage_banner',
          fallback:
              'Baby Mage Robot channels dual harmonic spells driven by the deterministic digits of π (3.1415926535...).',
        ) ??
        'Baby Mage Robot channels dual harmonic spells driven by the deterministic digits of π (3.1415926535...).';
    final digitsHeader = loc?.t(
          'markov_pi_decoder_col_digits',
          fallback: 'π Digit',
        ) ??
        'π Digit';
    final spellsHeader = loc?.t(
          'markov_pi_decoder_col_spells',
          fallback: 'Dual Harmonic Spells',
        ) ??
        'Dual Harmonic Spells';
    final counterHeader = loc?.t(
          'markov_pi_decoder_col_counter',
          fallback: 'Common Weakness',
        ) ??
        'Common Weakness';
    final weaknessRuleNote = loc?.t(
          'markov_baby_mage_common_weakness_note',
          fallback:
              'Dual-Spell Shield: Only the unique common weakness that defeats both spells deals -1 HP to Baby Mage Robot (all other elements deal 0 boss damage).',
        ) ??
        'Dual-Spell Shield: Only the unique common weakness that defeats both spells deals -1 HP to Baby Mage Robot (all other elements deal 0 boss damage).';

    const rows = <({
      String range,
      int d0,
      int d1,
      HandMove spellA,
      HandMove spellB,
      HandMove weakness,
    })>[
      (
        range: '0 – 1',
        d0: 0,
        d1: 1,
        spellA: HandMove.fire,
        spellB: HandMove.water,
        weakness: HandMove.earth,
      ),
      (
        range: '2 – 3',
        d0: 2,
        d1: 3,
        spellA: HandMove.water,
        spellB: HandMove.earth,
        weakness: HandMove.wood,
      ),
      (
        range: '4 – 5',
        d0: 4,
        d1: 5,
        spellA: HandMove.earth,
        spellB: HandMove.wood,
        weakness: HandMove.metal,
      ),
      (
        range: '6 – 7',
        d0: 6,
        d1: 7,
        spellA: HandMove.wood,
        spellB: HandMove.metal,
        weakness: HandMove.fire,
      ),
      (
        range: '8 – 9',
        d0: 8,
        d1: 9,
        spellA: HandMove.metal,
        spellB: HandMove.fire,
        weakness: HandMove.water,
      ),
    ];

    return Container(
      key: const ValueKey('markov_baby_mage_random_banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: palette.isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accent.withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        key: const ValueKey('markov_baby_mage_pi_decoder'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.functions_rounded, size: 17, color: accent),
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
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: palette.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          size: 13,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            weaknessRuleNote,
                            key: const ValueKey(
                              'markov_baby_mage_common_weakness_note',
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              color: palette.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: palette.isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accent.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        digitsHeader,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: palette.secondaryText,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        spellsHeader,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: palette.secondaryText,
                        ),
                      ),
                    ),
                    Text(
                      counterHeader,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: palette.secondaryText,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 8, thickness: 0.6),
                for (final row in rows) ...[
                  Builder(
                    builder: (context) {
                      final isActiveDigit = currentPiDigit == row.d0 ||
                          currentPiDigit == row.d1;
                      return Container(
                        key: ValueKey('pi_decoder_row_${row.d0}_${row.d1}'),
                        margin: const EdgeInsets.symmetric(vertical: 1.5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 3,
                        ),
                        decoration: isActiveDigit
                            ? BoxDecoration(
                                color: accent.withValues(
                                  alpha: palette.isDark ? 0.22 : 0.16,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.75),
                                ),
                              )
                            : null,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: Text(
                                row.range,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isActiveDigit
                                      ? accent
                                      : palette.primaryText,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  _buildInlineElementBadge(palette, row.spellA),
                                  Text(
                                    '+',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      color: palette.secondaryText,
                                    ),
                                  ),
                                  _buildInlineElementBadge(palette, row.spellB),
                                ],
                              ),
                            ),
                            _buildInlineElementBadge(palette, row.weakness),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
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
      final ai = metalWizardAiState;
      final String stanceText;
      if (ai != null && ai.isExecutingScriptedSequence) {
        if (ai.activeScriptType == MetalWizardScriptType.fiveMetalFiveEarth) {
          stanceText = loc?.t(
                'markov_metal_wizard_stance_barrage',
                fallback: '5-Metal / 5-Earth Barrage',
              ) ??
              '5-Metal / 5-Earth Barrage';
        } else {
          stanceText = loc?.t(
                'markov_metal_wizard_stance_alternating',
                fallback: '10-Turn Alternating Protocol',
              ) ??
              '10-Turn Alternating Protocol';
        }
      } else if (ai != null &&
          ai.strategyMode == MetalWizardStrategyMode.inverse) {
        stanceText = loc?.t(
              'markov_metal_wizard_stance_inverse',
              fallback: 'Inverse Strategy: Win-Shift / Lose-Stay',
            ) ??
            'Inverse Strategy: Win-Shift / Lose-Stay';
      } else {
        stanceText = loc?.t(
              'markov_metal_wizard_stance_normal',
              fallback: 'Initial Strategy: Win-Stay / Lose-Shift',
            ) ??
            'Initial Strategy: Win-Stay / Lose-Shift';
      }

      final lossCount = ai?.consecutiveLosses ?? 0;
      final lossStreakText = (loc?.t(
                'markov_metal_wizard_loss_streak',
                fallback: 'Consecutive Losses: {count}',
              ) ??
              'Consecutive Losses: {count}')
          .replaceAll('{count}', '$lossCount');

      final scriptedRemaining = ai?.scriptedQueue.length ?? 0;
      final scriptedRemainingText = scriptedRemaining > 0
          ? (loc?.t(
                    'markov_metal_wizard_scripted_remaining',
                    fallback: 'Protocol Turns Left: {count}',
                  ) ??
                  'Protocol Turns Left: {count}')
              .replaceAll('{count}', '$scriptedRemaining')
          : null;

      final shieldNote = loc?.t(
            'markov_metal_wizard_shield_note',
            fallback: 'Anti-Metal Shield: Blocks all Metal attacks (0 damage).',
          ) ??
          'Anti-Metal Shield: Blocks all Metal attacks (0 damage).';

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
            const MetalWizardLairIcon(size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stanceText,
                    key: const ValueKey('markov_metal_wizard_stance'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: palette.primaryText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        key: const ValueKey('markov_metal_wizard_loss_streak'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: palette.amberBorder.withValues(
                            alpha: palette.isDark ? 0.22 : 0.16,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: palette.amberBorder.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Text(
                          lossStreakText,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: palette.amberText,
                          ),
                        ),
                      ),
                      if (scriptedRemainingText != null)
                        Container(
                          key: const ValueKey(
                            'markov_metal_wizard_scripted_remaining',
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.purpleAccent.withValues(
                              alpha: palette.isDark ? 0.22 : 0.14,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color:
                                  palette.purpleAccent.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Text(
                            scriptedRemainingText,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: palette.isDark
                                  ? const Color(0xFFE1BEE7)
                                  : palette.purpleAccent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 13,
                        color: palette.isDark
                            ? const Color(0xFF80D8FF)
                            : const Color(0xFF01579B),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          shieldNote,
                          key: const ValueKey(
                            'markov_metal_wizard_shield_note',
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            color: palette.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (isTempleMasterRandomView) {
      final accent = palette.orangeAccent;
      final body = loc?.t(
            'markov_temple_master_banner',
            fallback:
                'Temple High Master ignores all transition history and channels all 5 elements with pure uniform randomness (1/5 per element).',
          ) ??
          'Temple High Master ignores all transition history and channels all 5 elements with pure uniform randomness (1/5 per element).';
      return Container(
        key: const ValueKey('markov_temple_master_random_banner'),
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
    if (isBabyMageRandomView) {
      return _buildBabyMagePiDecoder(palette);
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
        : isBabyMageRandomView
            ? (localization?.t(
                  'markov_pi_decoder_title',
                  fallback: 'Irrational π Core Decoder (C / d = 3.14159...)',
                ) ??
                'Irrational π Core Decoder (C / d = 3.14159...)')
            : (localization?.t(
                  'markov_matrix_title',
                  fallback: 'Markov Transition Matrix',
                ) ??
                'Markov Transition Matrix');

    return _MarkovCollapsibleCard(
      initiallyExpanded: initiallyExpanded,
      headerTitle: headerTitle,
      palette: palette,
      theme: theme,
      maxBodyHeight: maxBodyHeight,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          if (isArchmageShortTermView ||
              isBabyMageRandomView ||
              isTempleMasterRandomView ||
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
                        final isMax = !_dimsTransitionMatrix &&
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
                                color: _dimsTransitionMatrix
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
    );
  }
}

class _MarkovCollapsibleCard extends StatefulWidget {
  final bool initiallyExpanded;
  final String headerTitle;
  final AppPalette palette;
  final ThemeData theme;
  final double? maxBodyHeight;
  final Widget body;

  const _MarkovCollapsibleCard({
    required this.initiallyExpanded,
    required this.headerTitle,
    required this.palette,
    required this.theme,
    this.maxBodyHeight,
    required this.body,
  });

  @override
  State<_MarkovCollapsibleCard> createState() => _MarkovCollapsibleCardState();
}

class _MarkovCollapsibleCardState extends State<_MarkovCollapsibleCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final theme = widget.theme;
    final expandedBody = widget.maxBodyHeight != null
        ? ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxBodyHeight!),
            child: SingleChildScrollView(
              key: const ValueKey('markov_matrix_body_scroll_view'),
              child: widget.body,
            ),
          )
        : widget.body;

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
        padding: EdgeInsets.fromLTRB(12, 8, 12, _isExpanded ? 12 : 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              key: const ValueKey('markov_matrix_collapse_toggle'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    Expanded(
                      child: Text(
                        widget.headerTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: palette.primaryText,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(
                        child: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          key: const ValueKey('markov_matrix_collapse_icon'),
                          size: 20,
                          color: palette.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? expandedBody
                  : const SizedBox.shrink(
                      key: ValueKey('markov_matrix_collapsed_body'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

