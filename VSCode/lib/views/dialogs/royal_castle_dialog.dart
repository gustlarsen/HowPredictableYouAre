import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../models/royal_castle.dart';
import '../../models/story_chapter.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/elemental_energy_sphere.dart';
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
  late HandMove _alchemySource;
  late HandMove _alchemyTarget;

  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _selectedWing = widget.initialWing;
    _alchemySource = HandMove.values.firstWhere(
      (m) => controller.orbsFor(m) >= 3,
      orElse: () => HandMove.rock,
    );
    _alchemyTarget = _alchemySource == HandMove.paper
        ? HandMove.rock
        : HandMove.paper;
  }

  void _cycleAlchemySource() {
    controller.audio.playTapVibrate();
    const moves = HandMove.values;
    final startIdx = moves.indexOf(_alchemySource);
    for (int offset = 1; offset < moves.length; offset++) {
      final candidate = moves[(startIdx + offset) % moves.length];
      if (candidate != _alchemyTarget) {
        setState(() => _alchemySource = candidate);
        return;
      }
    }
  }

  void _cycleAlchemyTarget() {
    controller.audio.playTapVibrate();
    const moves = HandMove.values;
    final startIdx = moves.indexOf(_alchemyTarget);
    for (int offset = 1; offset < moves.length; offset++) {
      final candidate = moves[(startIdx + offset) % moves.length];
      if (candidate != _alchemySource) {
        setState(() => _alchemyTarget = candidate);
        return;
      }
    }
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
    final tabs = [
      (
        wing: CastleWing.throneRoom,
        key: const ValueKey('castle_tab_throne'),
        icon: Icons.castle_rounded,
        label: loc.t('castle_tab_throne_short', fallback: 'Throne'),
        hasDot: false,
      ),
      (
        wing: CastleWing.library,
        key: const ValueKey('castle_tab_library'),
        icon: Icons.menu_book_rounded,
        label: loc.t('castle_tab_library_short', fallback: 'Library'),
        hasDot: false,
      ),
      (
        wing: CastleWing.treasury,
        key: const ValueKey('castle_tab_treasury'),
        icon: Icons.inventory_2_rounded,
        label: loc.t('castle_tab_treasury_short', fallback: 'Treasury'),
        hasDot: controller.isAnyTreasuryElementFull,
      ),
      (
        wing: CastleWing.relicChamber,
        key: const ValueKey('castle_tab_relics'),
        icon: Icons.auto_awesome_rounded,
        label: loc.t('castle_tab_relics_short', fallback: 'Relics'),
        hasDot: controller.hasAvailableRelicChamberUpgrades,
      ),
      (
        wing: CastleWing.spoilsOfWar,
        key: const ValueKey('castle_tab_spoils'),
        icon: Icons.savings_rounded,
        label: loc.t('castle_tab_spoils_short', fallback: 'Spoils'),
        hasDot: controller.hasSpoilsOfWarOrbs,
      ),
      (
        wing: CastleWing.hallOfHeroes,
        key: const ValueKey('castle_tab_hall_of_heroes'),
        icon: Icons.workspace_premium_rounded,
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
              icon: tabs[i].icon,
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
  // WING 3: ROYAL TREASURY (VAULT WITH 5 3D ORBS + VISUAL 3->1 ROYAL ALCHEMY)
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

    final sourceAvailable = controller.orbsFor(_alchemySource);
    final targetAvailable = controller.orbsFor(_alchemyTarget);
    final canTransmute =
        _alchemySource != _alchemyTarget && sourceAvailable >= 3;

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

    final alchemyBg =
        palette.isDark ? const Color(0xFF1E222B) : palette.dialogCardSurface;
    final alchemyBorder = palette.isDark
        ? Colors.white.withValues(alpha: 0.14)
        : palette.sandCardBorder;

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
                  Icon(
                    Icons.inventory_2_rounded,
                    size: 19,
                    color: vaultBorderColor,
                  ),
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
        const SizedBox(height: 10),

        // 2. Compact Visual Royal Alchemy Card (3 -> 1 Side-by-Side)
        Container(
          key: const ValueKey('royal_alchemy_card'),
          padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
          decoration: BoxDecoration(
            color: alchemyBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: alchemyBorder, width: 1.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      loc.t(
                        'castle_alchemy_short_title',
                        fallback: 'Royal Alchemy',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: palette.primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      loc.t(
                        'castle_alchemy_tap_hint',
                        fallback: 'Tap orbs to switch',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: palette.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Left Side: Interactive 3 -> 1 Orb Diagram
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 3 Clustered Glowing Source Orbs (tappable to cycle)
                          InkWell(
                            key: const ValueKey('alchemy_source_selector'),
                            onTap: _cycleAlchemySource,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 56,
                                    height: 48,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned(
                                          top: 0,
                                          left: 15,
                                          child: ElementalEnergySphere(
                                            size: 26,
                                            primaryColor: _alchemySource
                                                .elementalPrimaryColor,
                                            secondaryColor: _alchemySource
                                                .elementalSecondaryColor,
                                            isDark: palette.isDark,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          child: ElementalEnergySphere(
                                            size: 26,
                                            primaryColor: _alchemySource
                                                .elementalPrimaryColor,
                                            secondaryColor: _alchemySource
                                                .elementalSecondaryColor,
                                            isDark: palette.isDark,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: ElementalEnergySphere(
                                            size: 26,
                                            primaryColor: _alchemySource
                                                .elementalPrimaryColor,
                                            secondaryColor: _alchemySource
                                                .elementalSecondaryColor,
                                            isDark: palette.isDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '3× ${_shortElementTitle(_alchemySource, loc)} ($sourceAvailable)',
                                    key: const ValueKey('alchemy_source_label'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: sourceAvailable >= 3
                                          ? palette.elementalText(_alchemySource)
                                          : palette.dangerText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Bold Golden Arrow
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 24,
                            color: palette.isDark ? _goldFill : palette.amberIcon,
                          ),
                          const SizedBox(width: 6),

                          // 1 Target Orb (tappable to cycle)
                          InkWell(
                            key: const ValueKey('alchemy_target_selector'),
                            onTap: _cycleAlchemyTarget,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: 48,
                                    child: Center(
                                      child: ElementalEnergySphere(
                                        size: 38,
                                        primaryColor:
                                            _alchemyTarget.elementalPrimaryColor,
                                        secondaryColor: _alchemyTarget
                                            .elementalSecondaryColor,
                                        isDark: palette.isDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '1× ${_shortElementTitle(_alchemyTarget, loc)} ($targetAvailable)',
                                    key: const ValueKey('alchemy_target_label'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: palette.elementalText(_alchemyTarget),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Right Side: Compact Bright-Gold Exchange Button
                  ElevatedButton.icon(
                    key: const ValueKey('alchemy_transmute_button'),
                    onPressed: canTransmute
                        ? () {
                            final ok = controller.transmuteOrbs(
                              _alchemySource,
                              _alchemyTarget,
                            );
                            if (ok && context.mounted) {
                              final srcName =
                                  _alchemySource.elementalOrbName(loc);
                              final dstName =
                                  _alchemyTarget.elementalOrbName(loc);
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
                      backgroundColor: _goldFill,
                      foregroundColor: _goldDarkInk,
                      disabledBackgroundColor: _goldFill.withValues(alpha: 0.28),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(
                      loc.t(
                        'castle_alchemy_exchange_btn',
                        fallback: 'Exchange',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
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
  // WING 6: HALL OF HEROES (RESTORE FALLEN CLERIC'S HP & MANA STAT BLESSINGS)
  // ---------------------------------------------------------------------------
  Widget _buildHallOfHeroesWing(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final hpBonus = controller.hallOfHeroesHpBonus;
    final manaBonus = controller.hallOfHeroesManaBonus;
    final hasBlessings = controller.hasHallOfHeroesBlessings;
    final isRemoveAds = controller.isRemoveAdsActive;
    final canRestoreAd = hasBlessings && controller.adService.isRewardedAdReady;

    return Column(
      key: const ValueKey('castle_wing_hall_of_heroes'),
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
                Icons.workspace_premium_rounded,
                color: palette.amberIcon,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loc.t(
                    'castle_heroes_desc',
                    fallback:
                        'Stat blessings forged by a fallen Cleric (+Max HP & +Max Mana) are enshrined here. Restore them once into your current campaign.',
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

        if (!hasBlessings)
          Container(
            key: const ValueKey('hall_of_heroes_empty_state'),
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
                    'castle_heroes_empty',
                    fallback: 'No fallen hero blessings awaiting restoration.',
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
                if (hpBonus > 0)
                  Row(
                    key: const ValueKey('hall_of_heroes_hp_bonus_row'),
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 18,
                        color: palette.dangerText,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.t(
                            'castle_heroes_hp_blessing',
                            fallback: 'Fallen Hero Max HP Blessing',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: palette.primaryText,
                          ),
                        ),
                      ),
                      Text(
                        '+$hpBonus Max HP',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: palette.dangerText,
                        ),
                      ),
                    ],
                  ),
                if (hpBonus > 0 && manaBonus > 0) const SizedBox(height: 10),
                if (manaBonus > 0)
                  Row(
                    key: const ValueKey('hall_of_heroes_mana_bonus_row'),
                    children: [
                      const Icon(
                        Icons.water_drop_rounded,
                        size: 18,
                        color: Color(0xFF00B0FF),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.t(
                            'castle_heroes_mana_blessing',
                            fallback: 'Fallen Hero Max Mana Blessing',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: palette.primaryText,
                          ),
                        ),
                      ),
                      Text(
                        '+$manaBonus Max ${loc.t('mana_label', fallback: 'Mana')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: Color(0xFF00B0FF),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                backgroundColor: Colors.amber,
                foregroundColor: const Color(0xFF231F1A),
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
      ],
    );
  }
}

class _CompactVerticalTabPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool showDot;
  final AppPalette palette;
  final VoidCallback onTap;

  const _CompactVerticalTabPill({
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
    final fgColor = selected
        ? goldDarkInk
        : (palette.isDark ? goldFill : palette.amberIcon);
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
                  Icon(icon, size: 17, color: fgColor),
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
