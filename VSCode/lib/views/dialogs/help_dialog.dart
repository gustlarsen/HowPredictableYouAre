import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/elemental_matchup_diagram.dart';

class HelpDialog extends StatelessWidget {
  final LocalizationService localization;
  final bool initialFiveElements;

  const HelpDialog({
    super.key,
    required this.localization,
    this.initialFiveElements = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final helpText = localization.t(
      'string34',
      fallback:
          'Channel Elemental Orbs as a Cleric (Fire, Water, Wood — plus Earth & Metal once unlocked) to defeat the Metal Wizard\'s predictive automatons.\n'
          'Understand and reverse-engineer their Markov pattern to outsmart every prediction.\n'
          'Earn Elemental Orbs from defeated elements on every won round.\n'
          'Spend your Orbs on blessings and arcane upgrades at the Sacred Temple\'s Altar of Offerings.',
    );

    return Dialog(
      backgroundColor: palette.isDark ? null : palette.dialogSurface,
      surfaceTintColor: palette.isDark ? null : Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.help_outline, color: palette.amberIcon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      localization.t('string35', fallback: 'How It Works'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: palette.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(
                height: 18,
                color: palette.isDark ? null : palette.divider,
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        helpText,
                        style: TextStyle(
                          height: 1.48,
                          fontSize: 13,
                          color: palette.primaryText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElementalMatchupDiagram(
                        localization: localization,
                        initialFiveElements: initialFiveElements,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: palette.rewardedAdCardSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: palette.isDark
                                ? Colors.amber.withValues(alpha: 0.3)
                                : palette.rewardedAdCardBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localization.t(
                                'help_pro_tip_title',
                                fallback: '💡 Pro Tip: The Markov Model',
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: palette.amberText,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              localization.t(
                                'help_pro_tip_body',
                                fallback:
                                    'The automaton tracks your transitions (which element you channel right after Fire, Water, Wood, Earth, or Metal). '
                                    'To outsmart it, avoid repetitive patterns or unlock the Markov Transition Matrix at the Sacred Temple to see what it expects!',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: palette.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: palette.isDark
                      ? null
                      : TextButton.styleFrom(
                          foregroundColor: palette.amberText,
                        ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localization.t('string36', fallback: 'Got It')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
