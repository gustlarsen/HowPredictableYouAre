import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../models/royal_castle.dart';
import '../../models/story_chapter.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import 'story_gallery_dialog.dart';

/// Identifies the 5 wings inside the [RoyalCastleDialog] hub.
enum CastleWing {
  throneRoom,
  library,
  treasury,
  relicChamber,
  spoilsOfWar,
}

/// Comprehensive 5-wing Royal Castle Hub dialog accessed from the Royal Castle
/// landmark on [WorldMapScreen].
class RoyalCastleDialog extends StatefulWidget {
  final GameController controller;
  final CastleWing initialWing;

  const RoyalCastleDialog({
    super.key,
    required this.controller,
    this.initialWing = CastleWing.throneRoom,
  });

  @override
  State<RoyalCastleDialog> createState() => _RoyalCastleDialogState();
}

class _RoyalCastleDialogState extends State<RoyalCastleDialog> {
  late CastleWing _selectedWing;
  HandMove _alchemySource = HandMove.rock;
  HandMove _alchemyTarget = HandMove.paper;

  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _selectedWing = widget.initialWing;
  }

  String _wingSubtitle(LocalizationService loc) {
    switch (_selectedWing) {
      case CastleWing.throneRoom:
        return loc.t(
          'castle_wing_throne_subtitle',
          fallback: "King's Throne Room & Royal Decrees",
        );
      case CastleWing.library:
        return loc.t(
          'castle_wing_library_subtitle',
          fallback: 'Royal Library, Bestiary & Story Memories',
        );
      case CastleWing.treasury:
        return loc.t(
          'castle_wing_treasury_subtitle',
          fallback: 'Royal Treasury & 3-to-1 Alchemy',
        );
      case CastleWing.relicChamber:
        return loc.t(
          'castle_wing_relics_subtitle',
          fallback: 'Restore Lost Artifacts',
        );
      case CastleWing.spoilsOfWar:
        return loc.t(
          'castle_wing_spoils_subtitle',
          fallback: 'Reclaim Lost Elemental Orbs',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final loc = controller.localization;
        final theme = Theme.of(context);
        final palette = AppPalette.of(context);
        final week = controller.currentWeek;
        final weekLabel = loc.t('map_week_label', fallback: 'Week');

        return Dialog(
          key: const ValueKey('royal_castle_dialog'),
          backgroundColor: palette.dialogSurface,
          surfaceTintColor: palette.isDark ? null : Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: palette.amberBorder.withValues(
                alpha: palette.isDark ? 0.45 : 0.65,
              ),
              width: 1.4,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Royal Castle Header
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
                                'map_landmark_royal_castle',
                                fallback: 'Royal Castle',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: palette.primaryText,
                              ),
                            ),
                            Text(
                              _wingSubtitle(loc),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                          border: Border.all(
                            color: palette.rewardedAdCardBorder,
                          ),
                        ),
                        child: Text(
                          '$weekLabel $week / ${GameController.maxCampaignWeeks}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            color: palette.amberText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 5 Castle Wing Navigation Pills
                  _buildWingTabStrip(context, palette, loc),

                  Divider(
                    height: 18,
                    color: palette.isDark ? null : palette.divider,
                  ),

                  // Wing Body
                  Expanded(
                    child: SingleChildScrollView(
                      key: ValueKey('castle_wing_scroll_${_selectedWing.name}'),
                      child: _buildSelectedWing(context, palette, loc),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey('royal_castle_close_button'),
                      style: palette.isDark
                          ? null
                          : TextButton.styleFrom(
                              foregroundColor: palette.amberText,
                            ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(loc.t('string36', fallback: 'Ok')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWingTabStrip(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final tabs = [
      (
        wing: CastleWing.throneRoom,
        key: const ValueKey('castle_tab_throne'),
        icon: Icons.castle_rounded,
        label: loc.t('castle_tab_throne', fallback: 'Throne Room'),
        hasDot: false,
      ),
      (
        wing: CastleWing.library,
        key: const ValueKey('castle_tab_library'),
        icon: Icons.auto_stories_rounded,
        label: loc.t('castle_tab_library', fallback: 'Library'),
        hasDot: false,
      ),
      (
        wing: CastleWing.treasury,
        key: const ValueKey('castle_tab_treasury'),
        icon: Icons.savings_rounded,
        label: loc.t('castle_tab_treasury', fallback: 'Treasury'),
        hasDot: controller.isAnyTreasuryElementFull,
      ),
      (
        wing: CastleWing.relicChamber,
        key: const ValueKey('castle_tab_relics'),
        icon: Icons.auto_awesome_rounded,
        label: loc.t('castle_tab_relics', fallback: 'Relic Chamber'),
        hasDot: controller.hasAvailableRelicChamberUpgrades,
      ),
      (
        wing: CastleWing.spoilsOfWar,
        key: const ValueKey('castle_tab_spoils'),
        icon: Icons.military_tech_rounded,
        label: loc.t('castle_tab_spoils', fallback: 'Spoils of War'),
        hasDot: controller.hasSpoilsOfWarOrbs,
      ),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tab in tabs)
          _WingNavPill(
            key: tab.key,
            icon: tab.icon,
            label: tab.label,
            selected: _selectedWing == tab.wing,
            showDot: tab.hasDot,
            palette: palette,
            onTap: () {
              controller.audio.playTapVibrate();
              setState(() => _selectedWing = tab.wing);
            },
          ),
      ],
    );
  }

  Widget _buildSelectedWing(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    switch (_selectedWing) {
      case CastleWing.throneRoom:
        return _buildThroneRoomWing(context, palette, loc);
      case CastleWing.library:
        return _buildLibraryWing(context, palette, loc);
      case CastleWing.treasury:
        return _buildTreasuryWing(context, palette, loc);
      case CastleWing.relicChamber:
        return _buildRelicChamberWing(context, palette, loc);
      case CastleWing.spoilsOfWar:
        return _buildSpoilsOfWarWing(context, palette, loc);
    }
  }

  // ---------------------------------------------------------------------------
  // WING 1: KING'S THRONE ROOM + ROYAL DECREES
  // ---------------------------------------------------------------------------
  Widget _buildThroneRoomWing(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final week = controller.currentWeek;
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

    final decrees = controller.activeRoyalDecrees;

    return Column(
      key: const ValueKey('castle_wing_throne_room'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Wing Title Banner
        Text(
          loc.t('throne_title', fallback: "King's Throne Room"),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: palette.primaryText,
          ),
        ),
        const SizedBox(height: 8),

        // Current Story Status Banner
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: statusAccent.withValues(alpha: palette.isDark ? 0.12 : 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusAccent.withValues(alpha: 0.45)),
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
                    height: 1.4,
                    color: palette.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Campaign Milestones
        Text(
          loc.t('throne_milestones_title', fallback: 'Campaign Milestones'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: palette.amberText,
          ),
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 16),

        // Royal Decrees (Optional Mini-Quests)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                loc.t('castle_decrees_title', fallback: 'Royal Decrees'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: palette.amberText,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: palette.rewardedAdCardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: palette.amberBorder.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                '${loc.t('castle_decrees_completed_count', fallback: 'Completed')}: ${controller.totalDecreesCompleted}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: palette.amberText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          loc.t(
            'castle_decrees_subtitle',
            fallback:
                'Complete quests in battle to automatically deposit bonus orbs into the Royal Treasury.',
          ),
          style: TextStyle(
            fontSize: 11.5,
            color: palette.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        for (final decree in decrees) ...[
          _RoyalDecreeCard(
            key: ValueKey('royal_decree_card_${decree.id}'),
            decree: decree,
            progress: controller.decreeProgressFor(decree),
            isCompleted: controller.isDecreeCompletedInCycle(decree),
            loc: loc,
            palette: palette,
            onRefresh: () {
              controller.audio.playTapVibrate();
              controller.rotateCompletedDecree(decree);
            },
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WING 2: ROYAL LIBRARY (ENDINGS + MARKOV BESTIARY + STORY MEMORIES)
  // ---------------------------------------------------------------------------
  Widget _buildLibraryWing(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final chapters = StoryChapter.values;
    final unlockedStories =
        chapters.where((c) => controller.isStoryChapterUnlocked(c)).length;

    return Column(
      key: const ValueKey('castle_wing_library'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Endings Discovered (X / 4)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                loc.t('castle_endings_title', fallback: 'Narrative Endings'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: palette.amberText,
                ),
              ),
            ),
            Container(
              key: const ValueKey('library_endings_counter_badge'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: palette.rewardedAdCardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.rewardedAdCardBorder),
              ),
              child: Text(
                '${loc.t('castle_endings_discovered', fallback: 'Endings Discovered')}: ${controller.unlockedEndingsCount} / ${NarrativeEnding.values.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                  color: palette.amberText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final ending in NarrativeEnding.values) ...[
          _EndingCard(
            key: ValueKey('library_ending_${ending.id}'),
            ending: ending,
            unlocked: controller.isEndingUnlocked(ending),
            loc: loc,
            palette: palette,
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 12),

        // 2. Arcane Bestiary (Markov Bestiary)
        Text(
          loc.t('castle_bestiary_title', fallback: 'Arcane Bestiary'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
            color: palette.amberText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          loc.t(
            'castle_bestiary_subtitle',
            fallback:
                'Mathematical constructs encountered in the Metal Wizard\'s Lair.',
          ),
          style: TextStyle(fontSize: 11.5, color: palette.secondaryText),
        ),
        const SizedBox(height: 8),
        for (final creature in BestiaryCreature.values) ...[
          _BestiaryCard(
            key: ValueKey('library_bestiary_${creature.id}'),
            creature: creature,
            encountered: controller.isBestiaryEncountered(creature),
            loc: loc,
            palette: palette,
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),

        // 3. Story Memories Comic Gallery
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                loc.t('story_gallery_title', fallback: 'Story Memories'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: palette.amberText,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: palette.rewardedAdCardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: palette.amberBorder.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                '$unlockedStories / ${chapters.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                  color: palette.amberText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StoryMemoriesSection(controller: controller, shrinkWrap: true),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WING 3: ROYAL TREASURY (PIGGY BANK + 3-TO-1 ALCHEMY EXCHANGE)
  // ---------------------------------------------------------------------------
  Widget _buildTreasuryWing(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final totalStored = controller.totalTreasuryOrbs;
    final overallFraction =
        (totalStored / GameController.maxTreasuryTotal).clamp(0.0, 1.0);
    final isRemoveAds = controller.isRemoveAdsActive;
    final canClaimAd = totalStored > 0 && controller.adService.isRewardedAdReady;
    final canClaimDirect = isRemoveAds && totalStored > 0;
    final canTransmute = _alchemySource != _alchemyTarget &&
        controller.orbsFor(_alchemySource) >= 3;

    return Column(
      key: const ValueKey('castle_wing_treasury'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Piggy Bank Vault Section
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.dialogCardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: palette.amberBorder.withValues(
                alpha: palette.isDark ? 0.45 : 0.65,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      loc.t(
                        'castle_treasury_vault_title',
                        fallback: 'Royal Treasury Vault',
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: palette.primaryText,
                      ),
                    ),
                  ),
                  Text(
                    '$totalStored / ${GameController.maxTreasuryTotal}',
                    key: const ValueKey('treasury_total_count'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: palette.amberText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                loc.t(
                  'castle_treasury_vault_desc',
                  fallback:
                      'Every battle round won deposits +1 mirror orb here (max 50 per element).',
                ),
                style: TextStyle(fontSize: 11.5, color: palette.secondaryText),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  key: const ValueKey('treasury_total_progress'),
                  value: overallFraction,
                  minHeight: 8,
                  backgroundColor: palette.sandCardSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    controller.isAnyTreasuryElementFull
                        ? Colors.amber
                        : palette.amberBorder,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Per-element capacity breakdown
              for (final move in HandMove.values) ...[
                _TreasuryElementRow(
                  key: ValueKey('treasury_element_${move.orbKey}'),
                  move: move,
                  count: controller.treasuryOrbsFor(move),
                  cap: GameController.maxTreasuryPerElement,
                  loc: loc,
                  palette: palette,
                ),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 8),

              // AdMob-compliant Claim Button or Remove Ads Direct Claim
              if (isRemoveAds)
                ElevatedButton.icon(
                  key: const ValueKey('treasury_claim_direct_button'),
                  onPressed: canClaimDirect
                      ? () {
                          final ok = controller.claimTreasuryDirect();
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    loc.t(
                                      'castle_treasury_claimed_msg',
                                      fallback:
                                          'Treasury orbs transferred to your backpack!',
                                    ),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: const Color(0xFF231F1A),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.savings_rounded, size: 18),
                  label: Text(
                    loc.t(
                      'castle_treasury_claim_direct',
                      fallback: 'Claim Treasury Orbs',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
              else ...[
                ElevatedButton.icon(
                  key: const ValueKey('treasury_claim_ad_button'),
                  onPressed: canClaimAd
                      ? () {
                          controller.watchAdToClaimTreasury(
                            onClaimed: () {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      loc.t(
                                        'castle_treasury_claimed_msg',
                                        fallback:
                                            'Treasury orbs transferred to your backpack!',
                                      ),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                            },
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: const Color(0xFF231F1A),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                  label: Text(
                    loc.t(
                      'castle_treasury_claim_ad',
                      fallback: 'Watch Ad to Claim Treasury',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  loc.t(
                    'castle_treasury_ad_disclosure',
                    fallback:
                        'Rewarded Video Ad: watch an ad to claim all accumulated Treasury orbs into your backpack.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: palette.mutedText,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Royal Alchemy (3-to-1 Orb Exchange)
        Container(
          key: const ValueKey('royal_alchemy_card'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.dialogCardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: palette.purpleAccent.withValues(
                alpha: palette.isDark ? 0.45 : 0.55,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.science_rounded,
                    color: palette.purpleAccent,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.t(
                        'castle_alchemy_title',
                        fallback: 'Royal Alchemy (3 → 1 Exchange)',
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: palette.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                loc.t(
                  'castle_alchemy_desc',
                  fallback:
                      'Transmute 3 surplus Elemental Orbs of one element into 1 Elemental Orb of another.',
                ),
                style: TextStyle(fontSize: 11.5, color: palette.secondaryText),
              ),
              const SizedBox(height: 10),

              // Source Element Selector
              Text(
                loc.t(
                  'castle_alchemy_source_label',
                  fallback: 'Spend 3 Orbs From:',
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: palette.amberText,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final move in HandMove.values)
                    _AlchemyElementChip(
                      key: ValueKey('alchemy_source_${move.orbKey}'),
                      move: move,
                      balance: controller.orbsFor(move),
                      selected: _alchemySource == move,
                      palette: palette,
                      loc: loc,
                      onTap: () {
                        controller.audio.playTapVibrate();
                        setState(() => _alchemySource = move);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Target Element Selector
              Text(
                loc.t(
                  'castle_alchemy_target_label',
                  fallback: 'Create 1 Orb Of:',
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: palette.amberText,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final move in HandMove.values)
                    _AlchemyElementChip(
                      key: ValueKey('alchemy_target_${move.orbKey}'),
                      move: move,
                      balance: controller.orbsFor(move),
                      selected: _alchemyTarget == move,
                      palette: palette,
                      loc: loc,
                      onTap: () {
                        controller.audio.playTapVibrate();
                        setState(() => _alchemyTarget = move);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Preview & Validation Feedback
              if (_alchemySource == _alchemyTarget)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    loc.t(
                      'castle_alchemy_same_error',
                      fallback: 'Choose two different elements to transmute.',
                    ),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: palette.dangerText,
                    ),
                  ),
                )
              else if (controller.orbsFor(_alchemySource) < 3)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    loc.t(
                      'castle_alchemy_insufficient_error',
                      fallback: 'Need at least 3 orbs of the source element.',
                    ),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: palette.dangerText,
                    ),
                  ),
                ),

              ElevatedButton.icon(
                key: const ValueKey('alchemy_transmute_button'),
                onPressed: canTransmute
                    ? () {
                        final ok = controller.transmuteOrbs(
                          _alchemySource,
                          _alchemyTarget,
                        );
                        if (ok && context.mounted) {
                          final srcName = _alchemySource.elementalOrbName(loc);
                          final dstName = _alchemyTarget.elementalOrbName(loc);
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text('3 $srcName → 1 $dstName'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.purpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.auto_fix_high_rounded, size: 17),
                label: Text(
                  loc.t(
                    'castle_alchemy_transmute_btn',
                    fallback: 'Transmute (3 → 1)',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WING 4: RELIC CHAMBER (RESTORE PREVIOUS RUN'S SHOP UPGRADES)
  // ---------------------------------------------------------------------------
  Widget _buildRelicChamberWing(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final artifacts = controller.availableRelicChamberArtifacts;
    final isRemoveAds = controller.isRemoveAdsActive;
    final canRestoreAd =
        artifacts.isNotEmpty && controller.adService.isRewardedAdReady;

    return Column(
      key: const ValueKey('castle_wing_relic_chamber'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: palette.rewardedAdCardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.rewardedAdCardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: palette.amberIcon,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loc.t(
                    'castle_relics_desc',
                    fallback:
                        'Upgrades lost when a previous campaign fell are preserved here. Restore them once into your current run.',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: palette.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (artifacts.isEmpty)
          Container(
            key: const ValueKey('relic_chamber_empty_state'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.dialogCardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.sandCardBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 32,
                  color: palette.mutedText,
                ),
                const SizedBox(height: 8),
                Text(
                  loc.t(
                    'castle_relics_empty',
                    fallback: 'No lost relics awaiting restoration.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: palette.secondaryText,
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (final artifact in artifacts) ...[
            Container(
              key: ValueKey('relic_chamber_item_${artifact.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: palette.dialogCardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: palette.amberBorder.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(artifact.icon, color: palette.amberIcon, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loc.t(
                        artifact.titleKey,
                        fallback: artifact.fallbackTitle,
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: palette.primaryText,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.history_edu_rounded,
                    size: 16,
                    color: palette.amberSubtitle,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          if (isRemoveAds)
            ElevatedButton.icon(
              key: const ValueKey('relic_chamber_restore_direct_button'),
              onPressed: () {
                final ok = controller.restoreRelicsDirect();
                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          loc.t(
                            'castle_relics_restored_msg',
                            fallback: 'Lost relics restored to your campaign!',
                          ),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: const Color(0xFF231F1A),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                loc.t(
                  'castle_relics_restore_direct',
                  fallback: 'Restore Relics',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          else ...[
            ElevatedButton.icon(
              key: const ValueKey('relic_chamber_restore_ad_button'),
              onPressed: canRestoreAd
                  ? () {
                      controller.watchAdToRestoreRelics(
                        onRestored: () {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  loc.t(
                                    'castle_relics_restored_msg',
                                    fallback:
                                        'Lost relics restored to your campaign!',
                                  ),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                        },
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: const Color(0xFF231F1A),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
              label: Text(
                loc.t(
                  'castle_relics_restore_ad',
                  fallback: 'Watch Ad to Restore Relics',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              loc.t(
                'castle_relics_ad_disclosure',
                fallback:
                    'Rewarded Video Ad: watch an ad to restore all lost run upgrades once.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: palette.mutedText),
            ),
          ],
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WING 5: SPOILS OF WAR (RECOVER ORBS LOST ON RESET OR DEFEAT)
  // ---------------------------------------------------------------------------
  Widget _buildSpoilsOfWarWing(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final totalSpoils = controller.totalSpoilsOfWarOrbs;
    final isRemoveAds = controller.isRemoveAdsActive;
    final canReclaimAd =
        totalSpoils > 0 && controller.adService.isRewardedAdReady;

    return Column(
      key: const ValueKey('castle_wing_spoils_of_war'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: palette.rewardedAdCardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.rewardedAdCardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.military_tech_rounded,
                color: palette.amberIcon,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loc.t(
                    'castle_spoils_desc',
                    fallback:
                        'Elemental Orbs lost from Turn 0 Battle Resets or Campaign Defeats are held here for one-time recovery.',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: palette.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (totalSpoils == 0)
          Container(
            key: const ValueKey('spoils_empty_state'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.dialogCardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.sandCardBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 32,
                  color: palette.mutedText,
                ),
                const SizedBox(height: 8),
                Text(
                  loc.t(
                    'castle_spoils_empty',
                    fallback: 'No lost orbs waiting to be reclaimed.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: palette.secondaryText,
                  ),
                ),
              ],
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.dialogCardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: palette.amberBorder.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              children: [
                for (final move in HandMove.values) ...[
                  Row(
                    key: ValueKey('spoils_orb_row_${move.orbKey}'),
                    children: [
                      Icon(
                        move.elementalIcon,
                        size: 18,
                        color: palette.elementalText(move),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          move.elementalOrbName(loc),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: palette.primaryText,
                          ),
                        ),
                      ),
                      Text(
                        '+${controller.spoilsOrbsFor(move)}',
                        key: ValueKey('spoils_orb_count_${move.orbKey}'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: palette.elementalText(move),
                        ),
                      ),
                    ],
                  ),
                  if (move != HandMove.spock) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isRemoveAds)
            ElevatedButton.icon(
              key: const ValueKey('spoils_reclaim_direct_button'),
              onPressed: () {
                final ok = controller.reclaimSpoilsDirect();
                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          loc.t(
                            'castle_spoils_reclaimed_msg',
                            fallback: 'Lost orbs reclaimed into your backpack!',
                          ),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: const Color(0xFF231F1A),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.military_tech_rounded, size: 18),
              label: Text(
                loc.t(
                  'castle_spoils_reclaim_direct',
                  fallback: 'Reclaim Spoils',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          else ...[
            ElevatedButton.icon(
              key: const ValueKey('spoils_reclaim_ad_button'),
              onPressed: canReclaimAd
                  ? () {
                      controller.watchAdToReclaimSpoils(
                        onReclaimed: () {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  loc.t(
                                    'castle_spoils_reclaimed_msg',
                                    fallback:
                                        'Lost orbs reclaimed into your backpack!',
                                  ),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                        },
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: const Color(0xFF231F1A),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
              label: Text(
                loc.t(
                  'castle_spoils_reclaim_ad',
                  fallback: 'Watch Ad to Reclaim Spoils',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              loc.t(
                'castle_spoils_ad_disclosure',
                fallback:
                    'Rewarded Video Ad: watch an ad to recover lost orbs into your backpack.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: palette.mutedText),
            ),
          ],
        ],
      ],
    );
  }
}

class _WingNavPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool showDot;
  final AppPalette palette;
  final VoidCallback onTap;

  const _WingNavPill({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.showDot,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? (palette.isDark
                      ? Colors.amber.withValues(alpha: 0.22)
                      : Colors.amber.withValues(alpha: 0.30))
                : palette.dialogCardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? palette.amberBorder
                  : palette.sandCardBorder,
              width: selected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? palette.amberIcon : palette.secondaryText,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                  color: selected ? palette.amberText : palette.secondaryText,
                ),
              ),
              if (showDot) ...[
                const SizedBox(width: 5),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.65),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
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
            : palette.sandCardSurface.withValues(
                alpha: palette.isDark ? 0.5 : 0.7,
              ),
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
                    color:
                        isReached ? palette.primaryText : palette.secondaryText,
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

class _RoyalDecreeCard extends StatelessWidget {
  final RoyalDecreeType decree;
  final int progress;
  final bool isCompleted;
  final LocalizationService loc;
  final AppPalette palette;
  final VoidCallback onRefresh;

  const _RoyalDecreeCard({
    super.key,
    required this.decree,
    required this.progress,
    required this.isCompleted,
    required this.loc,
    required this.palette,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (progress / decree.target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.dialogCardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? palette.successText.withValues(alpha: 0.65)
              : palette.amberBorder.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCompleted ? Icons.verified_rounded : decree.icon,
                size: 18,
                color: isCompleted ? palette.successText : palette.amberIcon,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.t(decree.titleKey, fallback: decree.fallbackTitle),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: palette.primaryText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.rewardedAdCardSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${decree.rewardPerElement} ${loc.t('castle_decree_all_orbs', fallback: 'All → Vault')}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: palette.amberText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            loc.t(decree.descKey, fallback: decree.fallbackDesc),
            style: TextStyle(
              fontSize: 11.5,
              color: palette.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: palette.sandCardSurface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? palette.successText : Colors.amber,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isCompleted
                    ? loc.t('castle_decree_completed', fallback: 'Completed!')
                    : '$progress / ${decree.target}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? palette.successText : palette.amberText,
                ),
              ),
              if (isCompleted) ...[
                const SizedBox(width: 6),
                InkWell(
                  key: ValueKey('decree_rotate_${decree.id}'),
                  onTap: onRefresh,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: palette.amberIcon,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EndingCard extends StatelessWidget {
  final NarrativeEnding ending;
  final bool unlocked;
  final LocalizationService loc;
  final AppPalette palette;

  const _EndingCard({
    super.key,
    required this.ending,
    required this.unlocked,
    required this.loc,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final lockedLabel = loc.t('castle_locked_mystery', fallback: '??? (Locked)');
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: unlocked
            ? palette.dialogCardSurface
            : palette.sandCardSurface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? ending.accentColor.withValues(alpha: 0.6)
              : palette.sandCardBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            unlocked ? ending.icon : Icons.lock_outline_rounded,
            size: 19,
            color: unlocked ? ending.accentColor : palette.mutedText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unlocked
                      ? loc.t(ending.titleKey, fallback: ending.fallbackTitle)
                      : lockedLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: unlocked ? palette.primaryText : palette.mutedText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unlocked
                      ? loc.t(ending.descKey, fallback: ending.fallbackDesc)
                      : loc.t(ending.hintKey, fallback: ending.fallbackHint),
                  style: TextStyle(
                    fontSize: 11,
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

class _BestiaryCard extends StatelessWidget {
  final BestiaryCreature creature;
  final bool encountered;
  final LocalizationService loc;
  final AppPalette palette;

  const _BestiaryCard({
    super.key,
    required this.creature,
    required this.encountered,
    required this.loc,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: encountered
            ? palette.dialogCardSurface
            : palette.sandCardSurface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: encountered
              ? creature.accentColor.withValues(alpha: 0.55)
              : palette.sandCardBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (encountered ? creature.accentColor : palette.mutedText)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              encountered ? creature.icon : Icons.help_outline_rounded,
              size: 20,
              color: encountered ? creature.accentColor : palette.mutedText,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      encountered
                          ? loc.t(
                              creature.nameKey,
                              fallback: creature.fallbackName,
                            )
                          : loc.t(
                              'castle_bestiary_unknown',
                              fallback: 'Unknown Construct',
                            ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: encountered
                            ? palette.primaryText
                            : palette.mutedText,
                      ),
                    ),
                    if (encountered)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: creature.accentColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          loc.t(
                            creature.mathModelKey,
                            fallback: creature.fallbackMathModel,
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: palette.isDark
                                ? creature.accentColor
                                : palette.primaryText,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  encountered
                      ? loc.t(creature.loreKey, fallback: creature.fallbackLore)
                      : loc.t(creature.hintKey, fallback: creature.fallbackHint),
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

class _TreasuryElementRow extends StatelessWidget {
  final HandMove move;
  final int count;
  final int cap;
  final LocalizationService loc;
  final AppPalette palette;

  const _TreasuryElementRow({
    super.key,
    required this.move,
    required this.count,
    required this.cap,
    required this.loc,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = count >= cap;
    final fg = palette.elementalText(move);
    return Row(
      children: [
        Icon(move.elementalIcon, size: 17, color: fg),
        const SizedBox(width: 8),
        SizedBox(
          width: 82,
          child: Text(
            move.elementalOrbName(loc),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.primaryText,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: (count / cap).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: palette.sandCardSurface,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count / $cap',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isFull ? palette.amberText : palette.secondaryText,
          ),
        ),
        if (isFull) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              loc.t('castle_treasury_full_tag', fallback: 'FULL'),
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF231F1A),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AlchemyElementChip extends StatelessWidget {
  final HandMove move;
  final int balance;
  final bool selected;
  final AppPalette palette;
  final LocalizationService loc;
  final VoidCallback onTap;

  const _AlchemyElementChip({
    super.key,
    required this.move,
    required this.balance,
    required this.selected,
    required this.palette,
    required this.loc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = palette.elementalText(move);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? fg.withValues(alpha: palette.isDark ? 0.22 : 0.16)
              : palette.sandCardSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? fg : palette.sandCardBorder,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(move.elementalIcon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              '${move.displayLabel(elemental: true, localization: loc)} ($balance)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? palette.primaryText : palette.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
