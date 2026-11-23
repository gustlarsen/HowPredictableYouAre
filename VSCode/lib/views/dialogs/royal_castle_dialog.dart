import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../models/royal_castle.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import '../screens/intro_story_screen.dart';
import '../widgets/castle_wing_icons.dart';
import '../widgets/elemental_energy_sphere.dart';
import '../widgets/forfeit_flag_icon.dart';
import '../widgets/metal_wizard_lair_icon.dart';
import '../widgets/royal_castle_icon.dart';
import 'story_gallery_dialog.dart';

/// Identifies the 6 wings inside the [RoyalCastleDialog] hub.
enum CastleWing {
  throneRoom,
  library,
  treasury,
  relicChamber,
  spoilsOfWar,
  hallOfHeroes,
}

/// Comprehensive 6-wing Royal Castle Hub dialog accessed from the Royal Castle
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
  static const Color _goldFill = Color(0xFFF5C22B);
  static const Color _goldDarkInk = Color(0xFF1E1B16);
  static const Color _alertRed = Color(0xFFE53935);

  late CastleWing _selectedWing;

  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _selectedWing = widget.initialWing;
  }

  String _shortElementTitle(HandMove move, LocalizationService loc) {
    final raw = move.displayLabel(elemental: true, localization: loc).trim();
    if (raw.isEmpty) return move.elementalLabel;
    if (raw.length == 1) return raw.toUpperCase();
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
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
            vertical: 16,
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
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Royal Castle Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: palette.amberBorder.withValues(
                            alpha: palette.isDark ? 0.18 : 0.14,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: palette.amberBorder.withValues(alpha: 0.55),
                          ),
                        ),
                        child: const RoyalCastleIcon(size: 24),
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
                              loc.t(
                                'castle_hub_subtitle',
                                fallback: 'Kingdom Hub & Royal Wings',
                              ),
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.2,
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
                  const SizedBox(height: 10),

                  // 6 Compact Vertical Navigation Tabs in a Single Row
                  _buildWingTabBar(context, palette, loc),

                  Divider(
                    height: 14,
                    color: palette.isDark ? null : palette.divider,
                  ),

                  // Active Wing Content
                  Flexible(
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
                      style: TextButton.styleFrom(
                        foregroundColor: palette.amberText,
                        backgroundColor: palette.isDark
                            ? palette.amberBorder.withValues(alpha: 0.16)
                            : palette.rewardedAdCardSurface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: palette.amberBorder.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        loc.t('string36', fallback: 'Ok'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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

  Widget _buildWingTabBar(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final List<({
      CastleWing wing,
      ValueKey<String> key,
      Widget Function(bool isSelected) iconBuilder,
      String label,
      bool hasDot,
    })> tabs = [
      (
        wing: CastleWing.throneRoom,
        key: const ValueKey('castle_tab_throne'),
        iconBuilder: (isSelected) => ThroneCrownIcon(
          size: 20,
          isOnGoldBackground: isSelected,
        ),
        label: loc.t('castle_tab_throne_short', fallback: 'Throne'),
        hasDot: false,
      ),
      (
        wing: CastleWing.library,
        key: const ValueKey('castle_tab_library'),
        iconBuilder: (isSelected) => LibraryTomeIcon(
          size: 20,
          isOnGoldBackground: isSelected,
        ),
        label: loc.t('castle_tab_library_short', fallback: 'Library'),
        hasDot: false,
      ),
      (
        wing: CastleWing.treasury,
        key: const ValueKey('castle_tab_treasury'),
        iconBuilder: (isSelected) => TreasuryChestIcon(
          size: 20,
          isOnGoldBackground: isSelected,
        ),
        label: loc.t('castle_tab_treasury_short', fallback: 'Treasury'),
        hasDot: controller.isAnyTreasuryElementFull,
      ),
      (
        wing: CastleWing.relicChamber,
        key: const ValueKey('castle_tab_relics'),
        iconBuilder: (isSelected) => RelicsSwordIcon(
          size: 20,
          isOnGoldBackground: isSelected,
        ),
        label: loc.t('castle_tab_relics_short', fallback: 'Relics'),
        hasDot: controller.hasAvailableRelicChamberUpgrades,
      ),
      (
        wing: CastleWing.spoilsOfWar,
        key: const ValueKey('castle_tab_spoils'),
        iconBuilder: (isSelected) => SpoilsPouchIcon(
          size: 20,
          isOnGoldBackground: isSelected,
        ),
        label: loc.t('castle_tab_spoils_short', fallback: 'Spoils'),
        hasDot: controller.hasSpoilsOfWarOrbs,
      ),
      (
        wing: CastleWing.hallOfHeroes,
        key: const ValueKey('castle_tab_hall_of_heroes'),
        iconBuilder: (isSelected) => HeroesHelmIcon(
          size: 20,
          isOnGoldBackground: isSelected,
        ),
        label: loc.t('castle_tab_heroes_short', fallback: 'Heroes'),
        hasDot: controller.hasHallOfHeroesBlessings,
      ),
    ];

    return Row(
      key: const ValueKey('royal_castle_tab_bar'),
      children: [
        for (int i = 0; i < tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: _CompactVerticalTabPill(
              key: tabs[i].key,
              iconBuilder: tabs[i].iconBuilder,
              label: tabs[i].label,
              selected: _selectedWing == tabs[i].wing,
              showDot: tabs[i].hasDot,
              palette: palette,
              onTap: () {
                controller.audio.playTapVibrate();
                setState(() => _selectedWing = tabs[i].wing);
              },
            ),
          ),
        ],
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
      case CastleWing.hallOfHeroes:
        return _buildHallOfHeroesWing(context, palette, loc);
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
          leadingIcon: const GoldenHourglassIcon(size: 24),
        ),
        const SizedBox(height: 16),

        // Royal Decrees (Optional Mini-Quests)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const RoyalScrollIcon(size: 22),
            const SizedBox(width: 7),
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
    final totalStories = controller.totalStoryMemoriesCount;
    final unlockedStories = controller.unlockedStoryMemoriesCount;

    return Column(
      key: const ValueKey('castle_wing_library'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                key: const ValueKey('library_endings_counter_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.rewardedAdCardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.rewardedAdCardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LaurelWreathIcon(size: 22),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${loc.t('castle_endings_discovered', fallback: 'Endings Discovered')}: ${controller.unlockedEndingsCount} / ${NarrativeEnding.values.length}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                          color: palette.amberText,
                        ),
                      ),
                    ),
                  ],
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

        Row(
          children: [
            const AutomatonHeadIcon(size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.t('castle_bestiary_title', fallback: 'Arcane Bestiary'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: palette.amberText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          loc.t(
            'castle_bestiary_subtitle',
            fallback:
                "Mathematical constructs encountered in the Metal Wizard's Lair.",
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
              key: const ValueKey('library_story_memories_counter'),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: palette.rewardedAdCardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: palette.amberBorder.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                '$unlockedStories / $totalStories',
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
        ElevatedButton.icon(
          key: const ValueKey('library_replay_intro_button'),
          onPressed: () {
            controller.audio.playTapVibrate();
            IntroStoryScreen.showReplay(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _goldFill,
            foregroundColor: _goldDarkInk,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: palette.amberBorder,
                width: 1.2,
              ),
            ),
          ),
          icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
          label: Text(
            loc.t('story_replay_intro', fallback: 'Replay Intro'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(height: 10),
        StoryMemoriesSection(controller: controller, shrinkWrap: true),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WING 3: ROYAL TREASURY (PIGGY BANK ORB VAULT WITH 5 3D ORBS)
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

    final vaultBg = palette.isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5A451B), Color(0xFF3E3012)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF6E8C6), Color(0xFFEBDCB4)],
          );
    final vaultBorderColor = palette.isDark ? _goldFill : palette.amberBorder;

    return Column(
      key: const ValueKey('castle_wing_treasury'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Royal Treasury Vault Card
        Container(
          key: const ValueKey('treasury_vault_card'),
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: BoxDecoration(
            gradient: vaultBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: vaultBorderColor, width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title & Chest Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      loc.t(
                        'castle_treasury_vault_title',
                        fallback: 'Royal Treasury Vault',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: palette.isDark
                            ? const Color(0xFFFBE29A)
                            : palette.primaryText,
                      ),
                    ),
                  ),
                  const TreasuryChestIcon(size: 22),
                ],
              ),
              const SizedBox(height: 8),

              // Full-Width Integrated Progress Bar (X / 250 centered inside)
              Container(
                height: 21,
                decoration: BoxDecoration(
                  color: palette.isDark
                      ? const Color(0xFF281F0C)
                      : const Color(0xFFDCC99E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: vaultBorderColor.withValues(alpha: 0.55),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: overallFraction,
                        child: Container(
                          key: const ValueKey('treasury_total_progress'),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFD97B12), _goldFill],
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          '$totalStored / ${GameController.maxTreasuryTotal}',
                          key: const ValueKey('treasury_total_count'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            color: palette.isDark
                                ? Colors.white
                                : const Color(0xFF231F1A),
                            shadows: palette.isDark
                                ? const [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 3,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 5 Glowing 3D Elemental Spheres in One Horizontal Row
              Row(
                key: const ValueKey('treasury_orbs_horizontal_row'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final move in HandMove.values)
                    Expanded(
                      child: _TreasuryHorizontalOrbColumn(
                        key: ValueKey('treasury_element_${move.orbKey}'),
                        move: move,
                        count: controller.treasuryOrbsFor(move),
                        cap: GameController.maxTreasuryPerElement,
                        label: _shortElementTitle(move, loc),
                        fullTag: loc.t(
                          'castle_treasury_full_tag',
                          fallback: 'FULL',
                        ),
                        palette: palette,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Wide Bright-Gold Claim Button & AdMob Disclosure
              if (isRemoveAds)
                SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
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
                      backgroundColor: _goldFill,
                      foregroundColor: _goldDarkInk,
                      disabledBackgroundColor: _goldFill.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.savings_rounded, size: 18),
                    label: Text(
                      loc.t(
                        'castle_treasury_claim_direct_short',
                        fallback: 'Claim Treasury',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                )
              else ...[
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
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
                      backgroundColor: _goldFill,
                      foregroundColor: _goldDarkInk,
                      disabledBackgroundColor: _goldFill.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            loc.t(
                              'castle_treasury_claim_ad_short',
                              fallback: 'Watch Ad to Claim',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.ondemand_video_rounded, size: 19),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  loc.t(
                    'castle_treasury_ad_disclosure_short',
                    fallback:
                        'Watch a rewarded video ad to transfer orbs to your backpack.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.25,
                    color: palette.isDark
                        ? Colors.white.withValues(alpha: 0.72)
                        : palette.secondaryText,
                  ),
                ),
              ],
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
              const RunicShieldIcon(size: 24),
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
                      artifact == ShopUpgradeArtifact.overchargedStaff &&
                              controller.storedRelicOverchargedStaffLevel > 0
                          ? '${loc.t(artifact.titleKey, fallback: artifact.fallbackTitle)} (${loc.t('overcharged_staff_level_prefix', fallback: 'Lv.')} ${controller.storedRelicOverchargedStaffLevel})'
                          : loc.t(
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
                backgroundColor: _goldFill,
                foregroundColor: _goldDarkInk,
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
                backgroundColor: _goldFill,
                foregroundColor: _goldDarkInk,
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
              const WarBannerIcon(size: 24),
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
                      ElementalEnergySphere(
                        size: 24,
                        primaryColor: move.elementalPrimaryColor,
                        secondaryColor: move.elementalSecondaryColor,
                        isDark: palette.isDark,
                      ),
                      const SizedBox(width: 10),
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
                backgroundColor: _goldFill,
                foregroundColor: _goldDarkInk,
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
                backgroundColor: _goldFill,
                foregroundColor: _goldDarkInk,
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

  // ---------------------------------------------------------------------------
  // WING 6: HALL OF HEROES (FALLEN HERO BLESSINGS + LIFETIME KINGDOM CHRONICLES)
  // ---------------------------------------------------------------------------
  Widget _buildHallOfHeroesWing(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final peakHp = controller.peakHpUpgradeLevel;
    final peakMana = controller.peakManaUpgradeLevel;
    final targetHp = controller.hallOfHeroesTargetMaxHp;
    final targetMana = controller.hallOfHeroesTargetMaxMana;
    final hasBlessings = controller.hasHallOfHeroesBlessings;
    final isRemoveAds = controller.isRemoveAdsActive;
    final canRestoreAd = hasBlessings && controller.adService.isRewardedAdReady;
    final hasAnyPeakRecord = peakHp > 0 || peakMana > 0;
    final weekLabel = loc.t('map_week_label', fallback: 'Week');
    final fastestWeek = controller.fastestVictoryWeek;
    final fastestText =
        (fastestWeek != null && fastestWeek >= 0) ? '$weekLabel $fastestWeek' : '--';

    final Color secretAccent = palette.isDark
        ? const Color(0xFF00E5FF)
        : const Color(0xFF006B7A);
    final Color guardianAccent = palette.isDark
        ? const Color(0xFF4FC3F7)
        : const Color(0xFF02689B);
    final Color metalWizardAccent = palette.isDark
        ? const Color(0xFFB0BEC5)
        : const Color(0xFF455A64);
    final Color cardBorder = palette.isDark
        ? palette.amberBorder.withValues(alpha: 0.35)
        : palette.sandCardBorder;

    return Column(
      key: const ValueKey('castle_wing_hall_of_heroes'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Top Section — Fallen Hero Blessings
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.rewardedAdCardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.rewardedAdCardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HeroesHelmIcon(size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loc.t(
                    'castle_heroes_desc',
                    fallback:
                        'Restores your Cleric\'s Max HP and Max Mana back up to the highest levels achieved in past journeys (once per campaign cycle).',
                  ),
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: palette.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (!hasBlessings)
          Container(
            key: const ValueKey('hall_of_heroes_empty_state'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.dialogCardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.sandCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      hasAnyPeakRecord
                          ? Icons.verified_rounded
                          : Icons.shield_outlined,
                      size: 18,
                      color: hasAnyPeakRecord
                          ? palette.successText
                          : palette.mutedText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasAnyPeakRecord
                            ? loc.t(
                                'castle_heroes_already_claimed',
                                fallback: 'Blessing already claimed this cycle',
                              )
                            : loc.t(
                                'castle_heroes_empty',
                                fallback:
                                    'No fallen hero blessings awaiting restoration.',
                              ),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: palette.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasAnyPeakRecord) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (peakHp > 0)
                        Container(
                          key: const ValueKey('hall_of_heroes_peak_hp_chip'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: palette.dangerText.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: palette.dangerText.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            '${loc.t('castle_heroes_hp_blessing', fallback: 'Peak Max HP Record')}: Lv. $peakHp ($targetHp)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: palette.dangerText,
                            ),
                          ),
                        ),
                      if (peakMana > 0)
                        Container(
                          key: const ValueKey('hall_of_heroes_peak_mana_chip'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00B0FF,
                            ).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(
                                0xFF00B0FF,
                              ).withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            '${loc.t('castle_heroes_mana_blessing', fallback: 'Peak Max Mana Record')}: Lv. $peakMana ($targetMana)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: palette.isDark
                                  ? const Color(0xFF40C4FF)
                                  : const Color(0xFF01579B),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: palette.dialogCardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: palette.amberBorder.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              children: [
                if (peakHp > 0)
                  Row(
                    key: const ValueKey('hall_of_heroes_hp_bonus_row'),
                    children: [
                      const RubyHeartIcon(size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.t(
                            'castle_heroes_hp_blessing',
                            fallback: 'Peak Max HP Record',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            color: palette.primaryText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Lv. $peakHp • $targetHp Max HP',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: palette.dangerText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (peakHp > 0 && peakMana > 0) const SizedBox(height: 10),
                if (peakMana > 0)
                  Row(
                    key: const ValueKey('hall_of_heroes_mana_bonus_row'),
                    children: [
                      const ManaCrystalIcon(size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.t(
                            'castle_heroes_mana_blessing',
                            fallback: 'Peak Max Mana Record',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            color: palette.primaryText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Lv. $peakMana • $targetMana Max ${loc.t('mana_title_word', fallback: 'Mana')}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: palette.isDark
                                  ? const Color(0xFF00B0FF)
                                  : const Color(0xFF01579B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (isRemoveAds)
            ElevatedButton.icon(
              key: const ValueKey('hall_of_heroes_restore_direct_button'),
              onPressed: () {
                final ok = controller.restoreHallOfHeroesDirect();
                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          loc.t(
                            'castle_heroes_restored_msg',
                            fallback:
                                'Fallen hero blessings restored to your Cleric!',
                          ),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _goldFill,
                foregroundColor: _goldDarkInk,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
              label: Text(
                loc.t(
                  'castle_heroes_restore_direct',
                  fallback: 'Restore Blessings',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          else ...[
            ElevatedButton.icon(
              key: const ValueKey('hall_of_heroes_restore_ad_button'),
              onPressed: canRestoreAd
                  ? () {
                      controller.watchAdToRestoreHallOfHeroes(
                        onRestored: () {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  loc.t(
                                    'castle_heroes_restored_msg',
                                    fallback:
                                        'Fallen hero blessings restored to your Cleric!',
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
                backgroundColor: _goldFill,
                foregroundColor: _goldDarkInk,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
              label: Text(
                loc.t(
                  'castle_heroes_restore_ad',
                  fallback: 'Watch Ad to Restore',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              loc.t(
                'castle_heroes_ad_disclosure',
                fallback:
                    'Rewarded Video Ad: watch an ad to restore your fallen hero\'s Max HP and Max Mana blessings once.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: palette.mutedText),
            ),
          ],
        ],

        const SizedBox(height: 14),
        Divider(height: 1, color: palette.divider),
        const SizedBox(height: 12),

        // 2. Main Section — Always-Visible Kingdom Chronicles
        Row(
          key: const ValueKey('heroes_kingdom_chronicles_header'),
          children: [
            Icon(
              Icons.history_edu_rounded,
              size: 18,
              color: palette.amberIcon,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                loc.t(
                  'castle_heroes_chronicles_title',
                  fallback: 'Kingdom Chronicles',
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: palette.amberText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Headline Stat Card: Total Cycles / Resets & Fastest Victory
        Container(
          key: const ValueKey('heroes_chronicles_headline_card'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: palette.dialogCardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: palette.amberBorder.withValues(
                alpha: palette.isDark ? 0.45 : 0.65,
              ),
              width: 1.2,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restart_alt_rounded,
                            size: 15,
                            color: palette.amberIcon,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              loc.t(
                                'castle_heroes_total_cycles',
                                fallback: 'Total Cycles / Resets',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: palette.secondaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${controller.totalCyclesCount}',
                        key: const ValueKey('heroes_stat_total_cycles'),
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: palette.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                VerticalDivider(
                  width: 18,
                  thickness: 1,
                  color: palette.divider,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 15,
                            color: secretAccent,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              loc.t(
                                'castle_heroes_fastest_victory',
                                fallback: 'Fastest Victory',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: palette.secondaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fastestText,
                        key: const ValueKey('heroes_stat_fastest_victory'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: (fastestWeek != null && fastestWeek >= 0)
                              ? palette.amberText
                              : palette.mutedText,
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

        // 4 Endings Breakdown (2x2 Compact Grid)
        Text(
          loc.t('castle_endings_title', fallback: 'Narrative Endings'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
            color: palette.amberText,
          ),
        ),
        const SizedBox(height: 6),
        Column(
          key: const ValueKey('heroes_chronicles_endings_grid'),
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ChronicleStatCard(
                      key: const ValueKey('heroes_ending_ruin_card'),
                      icon: Icons.heart_broken_rounded,
                      accentColor: palette.dangerText,
                      title: loc.t(
                        'castle_heroes_ending_1_title',
                        fallback: 'Ending I: Ruin',
                      ),
                      subtitle: loc.t(
                        'castle_heroes_ending_1_sub',
                        fallback: '0 HP',
                      ),
                      count: controller.deathDefeatCount,
                      palette: palette,
                      borderColor: cardBorder,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChronicleStatCard(
                      key: const ValueKey('heroes_ending_invasion_card'),
                      icon: Icons.hourglass_disabled_rounded,
                      accentColor: palette.orangeAccent,
                      title: loc.t(
                        'castle_heroes_ending_2_title',
                        fallback: 'Ending II: Invasion',
                      ),
                      subtitle: loc.t(
                        'castle_heroes_ending_2_sub',
                        fallback: 'Week 40',
                      ),
                      count: controller.timeoutDefeatCount,
                      palette: palette,
                      borderColor: cardBorder,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ChronicleStatCard(
                      key: const ValueKey('heroes_ending_victory_card'),
                      icon: Icons.emoji_events_rounded,
                      accentColor: palette.amberText,
                      title: loc.t(
                        'castle_heroes_ending_3_title',
                        fallback: 'Ending III: Victory',
                      ),
                      subtitle: loc.t(
                        'castle_heroes_ending_3_sub',
                        fallback: 'Stage 4',
                      ),
                      count: controller.standardVictoryCount,
                      palette: palette,
                      borderColor: cardBorder,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChronicleStatCard(
                      key: const ValueKey('heroes_ending_secret_card'),
                      icon: Icons.auto_awesome_rounded,
                      accentColor: secretAccent,
                      title: loc.t(
                        'castle_heroes_ending_4_title',
                        fallback: 'Ending IV: Secret Rescue',
                      ),
                      subtitle: loc.t(
                        'castle_heroes_ending_4_sub',
                        fallback: 'Week 0',
                      ),
                      count: controller.secretVictoryCount,
                      palette: palette,
                      borderColor: cardBorder,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Forfeited Journeys Row / Card
        Container(
          key: const ValueKey('heroes_forfeit_runs_card'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: palette.dialogCardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: palette.sandCardSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const ForfeitFlagIcon(size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loc.t(
                    'castle_heroes_forfeited_runs',
                    fallback: 'Forfeited Runs',
                  ),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: palette.primaryText,
                  ),
                ),
              ),
              Text(
                '${controller.forfeitRunCount}',
                key: const ValueKey('heroes_stat_forfeit_runs'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: palette.primaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Bosses Defeated (2x2 Compact Mini-Cards)
        Text(
          loc.t(
            'castle_heroes_bosses_defeated',
            fallback: 'Bosses Defeated',
          ),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
            color: palette.amberText,
          ),
        ),
        const SizedBox(height: 6),
        Column(
          key: const ValueKey('heroes_chronicles_bosses_grid'),
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ChronicleStatCard(
                      key: const ValueKey('heroes_boss_guardian_card'),
                      icon: BestiaryCreature.guardianRobot.icon,
                      accentColor: guardianAccent,
                      title: loc.t(
                        'boss_name_guardian',
                        fallback: 'Guardian Robot',
                      ),
                      count: controller.guardianRobotDefeatedCount,
                      palette: palette,
                      borderColor: cardBorder,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChronicleStatCard(
                      key: const ValueKey('heroes_boss_archmage_card'),
                      icon: BestiaryCreature.archmageRobot.icon,
                      accentColor: palette.orangeAccent,
                      title: loc.t(
                        'boss_name_archmage',
                        fallback: 'Robot Archmage',
                      ),
                      count: controller.robotArchmageDefeatedCount,
                      palette: palette,
                      borderColor: cardBorder,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ChronicleStatCard(
                      key: const ValueKey('heroes_boss_metal_wizard_card'),
                      leadingWidget: const MetalWizardLairIcon(size: 18),
                      accentColor: metalWizardAccent,
                      title: loc.t(
                        'boss_name_metal_wizard',
                        fallback: 'Metal Wizard',
                      ),
                      count: controller.metalWizardDefeatedCount,
                      palette: palette,
                      borderColor: cardBorder,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChronicleStatCard(
                      key: const ValueKey('heroes_boss_baby_mage_card'),
                      icon: BestiaryCreature.babyRobot.icon,
                      accentColor: palette.purpleAccent,
                      title: loc.t(
                        'boss_name_baby_mage',
                        fallback: 'Baby Mage Robot',
                      ),
                      count: controller.babyMageRobotDefeatedCount,
                      palette: palette,
                      borderColor: cardBorder,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactVerticalTabPill extends StatelessWidget {
  final Widget Function(bool isSelected) iconBuilder;
  final String label;
  final bool selected;
  final bool showDot;
  final AppPalette palette;
  final VoidCallback onTap;

  const _CompactVerticalTabPill({
    super.key,
    required this.iconBuilder,
    required this.label,
    required this.selected,
    required this.showDot,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const goldFill = _RoyalCastleDialogState._goldFill;
    const goldDarkInk = _RoyalCastleDialogState._goldDarkInk;
    const alertRed = _RoyalCastleDialogState._alertRed;

    final bgColor = selected
        ? goldFill
        : (palette.isDark
              ? const Color(0xFF1F1C16)
              : palette.dialogCardSurface);
    final borderColor = selected
        ? goldFill
        : palette.amberBorder.withValues(alpha: palette.isDark ? 0.45 : 0.6);
    final textColor = selected
        ? goldDarkInk
        : (palette.isDark
              ? Colors.white.withValues(alpha: 0.88)
              : palette.primaryText);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: selected ? 1.4 : 1.0,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconBuilder(selected),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 13,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDot)
          Positioned(
            top: -3,
            right: -2,
            child: Container(
              key: Key('${(key as ValueKey<String>).value}_dot'),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: alertRed,
                border: Border.all(
                  color: palette.dialogSurface,
                  width: 1.4,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TreasuryHorizontalOrbColumn extends StatelessWidget {
  final HandMove move;
  final int count;
  final int cap;
  final String label;
  final String fullTag;
  final AppPalette palette;

  const _TreasuryHorizontalOrbColumn({
    super.key,
    required this.move,
    required this.count,
    required this.cap,
    required this.label,
    required this.fullTag,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = count >= cap;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElementalEnergySphere(
          size: 38,
          primaryColor: move.elementalPrimaryColor,
          secondaryColor: move.elementalSecondaryColor,
          isDark: palette.isDark,
        ),
        const SizedBox(height: 5),
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
            color: isFull
                ? (palette.isDark
                      ? _RoyalCastleDialogState._goldFill
                      : palette.amberText)
                : palette.primaryText,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            color: palette.isDark
                ? Colors.white.withValues(alpha: 0.78)
                : palette.secondaryText,
          ),
        ),
        if (isFull) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: _RoyalCastleDialogState._goldFill,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              fullTag,
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: _RoyalCastleDialogState._goldDarkInk,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  final String title;
  final String description;
  final bool isReached;
  final Color accentColor;
  final Widget? leadingIcon;

  const _MilestoneTile({
    super.key,
    required this.title,
    required this.description,
    required this.isReached,
    required this.accentColor,
    this.leadingIcon,
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
          leadingIcon ??
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
    final lockedLabel =
        loc.t('castle_locked_mystery', fallback: '??? (Locked)');
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
          _BestiaryPortraitBox(
            creature: creature,
            encountered: encountered,
            palette: palette,
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

class _BestiaryPortraitBox extends StatelessWidget {
  final BestiaryCreature creature;
  final bool encountered;
  final AppPalette palette;

  const _BestiaryPortraitBox({
    required this.creature,
    required this.encountered,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final silhouetteColor = palette.isDark
        ? const Color(0xFF0A0C12)
        : const Color(0xFF2B2722);
    final portraitAsset = creature.portraitAsset;

    final Widget artwork;
    if (portraitAsset != null) {
      final image = Image.asset(
        portraitAsset,
        key: encountered
            ? ValueKey('bestiary_portrait_${creature.id}')
            : ValueKey('bestiary_silhouette_${creature.id}_img'),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => Icon(
          encountered ? creature.icon : Icons.help_outline_rounded,
          size: 26,
          color: encountered ? creature.accentColor : palette.mutedText,
        ),
      );
      artwork = encountered
          ? image
          : ColorFiltered(
              key: ValueKey('bestiary_silhouette_${creature.id}'),
              colorFilter: ColorFilter.mode(silhouetteColor, BlendMode.srcATop),
              child: Opacity(opacity: 0.72, child: image),
            );
    } else {
      const iconWidget = MetalWizardLairIcon(size: 32);
      artwork = encountered
          ? iconWidget
          : ColorFiltered(
              key: ValueKey('bestiary_silhouette_${creature.id}'),
              colorFilter: ColorFilter.mode(silhouetteColor, BlendMode.srcATop),
              child: const Opacity(opacity: 0.65, child: iconWidget),
            );
    }

    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: (encountered ? creature.accentColor : palette.mutedText)
            .withValues(alpha: palette.isDark ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: encountered
              ? creature.accentColor.withValues(alpha: 0.48)
              : palette.sandCardBorder,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: Center(child: artwork)),
          if (!encountered)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.dialogSurface.withValues(alpha: 0.85),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 11,
                  color: palette.mutedText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChronicleStatCard extends StatelessWidget {
  final IconData? icon;
  final Widget? leadingWidget;
  final Color accentColor;
  final String title;
  final String? subtitle;
  final int count;
  final AppPalette palette;
  final Color borderColor;

  const _ChronicleStatCard({
    super.key,
    this.icon,
    this.leadingWidget,
    required this.accentColor,
    required this.title,
    this.subtitle,
    required this.count,
    required this.palette,
    required this.borderColor,
  }) : assert(icon != null || leadingWidget != null);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: palette.dialogCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: count > 0
              ? accentColor.withValues(alpha: palette.isDark ? 0.55 : 0.65)
              : borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(
                    alpha: palette.isDark ? 0.14 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: leadingWidget ??
                    Icon(
                      icon,
                      size: 16,
                      color: accentColor,
                    ),
              ),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: count > 0 ? accentColor : palette.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: palette.primaryText,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: palette.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
