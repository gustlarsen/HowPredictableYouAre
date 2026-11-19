import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../theme/app_theme.dart';

/// Royal Castle landmark dialog: displays the King's Throne Room with current
/// campaign story status and week milestones (Week 1, Week 10 Archmage warning,
/// and Week 40 deadline).
class ThroneRoomDialog extends StatelessWidget {
  final GameController controller;

  const ThroneRoomDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final loc = controller.localization;
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final week = controller.currentWeek;
    final weekLabel = loc.t('map_week_label', fallback: 'Week');

    final String statusMessage;
    final Color statusAccent;
    final IconData statusIcon;
    if (week >= GameController.maxCampaignWeeks) {
      statusMessage = loc.t(
        'throne_status_deadline',
        fallback:
            "The 40-Week reckoning has arrived! Challenge the Metal Wizard's Lair with everything you have learned to seal Master Hand's fate!",
      );
      statusAccent = palette.dangerText;
      statusIcon = Icons.warning_amber_rounded;
    } else if (week >= 10) {
      statusMessage = loc.t(
        'throne_status_archmage',
        fallback:
            "The Archmage's warning echoes across the realm! Master Hand's predictive power grows sharper—stay unpredictable and master the Markov algorithm!",
      );
      statusAccent = palette.orangeAccent;
      statusIcon = Icons.auto_fix_high_rounded;
    } else {
      statusMessage = loc.t(
        'throne_status_early',
        fallback:
            "The Kingdom stands resilient. Gather Elemental Orbs in the Metal Wizard's Lair and forge arcane artifacts before the storm intensifies.",
      );
      statusAccent = palette.amberText;
      statusIcon = Icons.shield_outlined;
    }

    return Dialog(
      key: const ValueKey('throne_room_dialog'),
      backgroundColor: palette.isDark ? null : palette.dialogSurface,
      surfaceTintColor: palette.isDark ? null : Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: palette.amberBorder.withValues(
                        alpha: palette.isDark ? 0.18 : 0.14,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.amberBorder.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Icon(
                      Icons.castle_rounded,
                      color: palette.amberIcon,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.t(
                            'throne_title',
                            fallback: "King's Throne Room",
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: palette.primaryText,
                          ),
                        ),
                        Text(
                          loc.t(
                            'throne_subtitle',
                            fallback: 'Royal Campaign Status & Week Milestones',
                          ),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: palette.amberSubtitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: palette.rewardedAdCardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.rewardedAdCardBorder),
                    ),
                    child: Text(
                      '$weekLabel $week / ${GameController.maxCampaignWeeks}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: palette.amberText,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(
                height: 22,
                color: palette.isDark ? null : palette.divider,
              ),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Current Story Status Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: statusAccent.withValues(
                            alpha: palette.isDark ? 0.12 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: statusAccent.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(statusIcon, color: statusAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                statusMessage,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: palette.primaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        loc.t(
                          'throne_milestones_title',
                          fallback: 'Campaign Milestones',
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: palette.amberText,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Week 1 Milestone
                      _MilestoneTile(
                        key: const ValueKey('throne_milestone_week_1'),
                        title: loc.t(
                          'throne_milestone_w1_title',
                          fallback: 'Week 1 — Royal Summons',
                        ),
                        description: loc.t(
                          'throne_milestone_w1_desc',
                          fallback:
                              "The King entrusts you to confront the Metal Wizard and shatter Master Hand's predictions.",
                        ),
                        isReached: week >= 1,
                        accentColor: palette.successText,
                      ),
                      const SizedBox(height: 8),

                      // Week 10 Archmage Warning Milestone
                      _MilestoneTile(
                        key: const ValueKey('throne_milestone_week_10'),
                        title: loc.t(
                          'throne_milestone_w10_title',
                          fallback: "Week 10 — Archmage's Warning",
                        ),
                        description: loc.t(
                          'throne_milestone_w10_desc',
                          fallback:
                              'The Archmage warns that Master Hand adapts faster; seek upgrades at the Sacred Temple.',
                        ),
                        isReached: week >= 10,
                        accentColor: palette.orangeAccent,
                      ),
                      const SizedBox(height: 8),

                      // Week 40 Deadline Milestone
                      _MilestoneTile(
                        key: const ValueKey('throne_milestone_week_40'),
                        title: loc.t(
                          'throne_milestone_w40_title',
                          fallback: 'Week 40 — The Final Deadline',
                        ),
                        description: loc.t(
                          'throne_milestone_w40_desc',
                          fallback:
                              "The Kingdom's 40-week defense horizon—stand ready for the ultimate battle of minds.",
                        ),
                        isReached: week >= GameController.maxCampaignWeeks,
                        accentColor: palette.dangerText,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('throne_room_close_button'),
                  style: palette.isDark
                      ? null
                      : TextButton.styleFrom(foregroundColor: palette.amberText),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(loc.t('string36', fallback: 'Ok')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  final String title;
  final String description;
  final bool isReached;
  final Color accentColor;

  const _MilestoneTile({
    super.key,
    required this.title,
    required this.description,
    required this.isReached,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReached
            ? palette.dialogCardSurface
            : palette.sandCardSurface.withValues(alpha: palette.isDark ? 0.5 : 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isReached
              ? accentColor.withValues(alpha: 0.6)
              : palette.sandCardBorder,
          width: isReached ? 1.3 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isReached
                ? Icons.check_circle_rounded
                : Icons.hourglass_empty_rounded,
            size: 18,
            color: isReached ? accentColor : palette.mutedText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isReached ? palette.primaryText : palette.secondaryText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
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
}
