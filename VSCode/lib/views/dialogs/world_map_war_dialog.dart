import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/watch_tower_icon.dart';

/// Represents the war status of a continental realm at a specific campaign week.
enum RealmWarStatus {
  /// Metal Wizard's Dominion: Origin of the automaton army (Week 1–41).
  originDominion,

  /// Unconquered and peaceful.
  free,

  /// Under immediate invasion threat / border alert (e.g., Cleric's Capital in Weeks 35–40).
  underThreat,

  /// Conquered by the Metal Wizard's automaton legions on [fallWeek].
  conquered,

  /// Besieged & surrounded on all sides on Week 41 (Cleric's Sacred Capital).
  besieged,
}

/// Canonical definition for each of the 6 interactive realms on the 3:4 World Map.
enum WorldRealmRegion {
  metalWizardDominion(
    id: 'dominion',
    position: Offset(0.78, 0.20),
    fallWeek: 1,
    nameKey: 'world_map_realm_dominion_name',
    fallbackName: "Metal Wizard's Dominion",
    loreFreeKey: 'world_map_realm_dominion_lore',
    fallbackLoreFree:
        'Volcanic iron fortress where the Metal Wizard forges his relentless automaton legions.',
    loreConqueredKey: 'world_map_realm_dominion_lore',
    fallbackLoreConquered:
        'Volcanic iron fortress where the Metal Wizard forges his relentless automaton legions.',
    icon: Icons.precision_manufacturing_rounded,
  ),
  kingdomOfSolaria(
    id: 'solaria',
    position: Offset(0.62, 0.45),
    fallWeek: 10,
    nameKey: 'world_map_realm_solaria_name',
    fallbackName: 'Kingdom of Solaria',
    loreFreeKey: 'world_map_realm_solaria_lore_free',
    fallbackLoreFree:
        'Golden wheat fields and sun-blessed citadels guarding the eastern river valley.',
    loreConqueredKey: 'world_map_realm_solaria_lore_conquered',
    fallbackLoreConquered:
        'Harvest plains scorched into ash; smelter towers now churn molten slag along the river.',
    icon: Icons.wb_sunny_rounded,
  ),
  stoneCitadel(
    id: 'citadel',
    position: Offset(0.27, 0.22),
    fallWeek: 18,
    nameKey: 'world_map_realm_citadel_name',
    fallbackName: 'Stone Citadel',
    loreFreeKey: 'world_map_realm_citadel_lore_free',
    fallbackLoreFree:
        'Impregnable frost-peak bastion carved into the northern glaciers.',
    loreConqueredKey: 'world_map_realm_citadel_lore_conquered',
    fallbackLoreConquered:
        'High mountain keep hollowed into a dark foundry pumping black smoke over the peaks.',
    icon: Icons.fort_rounded,
  ),
  verdantDuchy(
    id: 'duchy',
    position: Offset(0.25, 0.48),
    fallWeek: 26,
    nameKey: 'world_map_realm_duchy_name',
    fallbackName: 'Verdant Duchy',
    loreFreeKey: 'world_map_realm_duchy_lore_free',
    fallbackLoreFree:
        'Ancient elder-tree spires and druidic groves thriving with elemental life.',
    loreConqueredKey: 'world_map_realm_duchy_lore_conquered',
    fallbackLoreConquered:
        'Sacred canopy withered and bound in iron scaffolding as automatons strip the groves.',
    icon: Icons.park_rounded,
  ),
  crystalPort(
    id: 'port',
    position: Offset(0.72, 0.73),
    fallWeek: 34,
    nameKey: 'world_map_realm_port_name',
    fallbackName: 'Crystal Port',
    loreFreeKey: 'world_map_realm_port_lore_free',
    fallbackLoreFree:
        'Bustling maritime harbor whose white-sailed fleet connects the southern seas.',
    loreConqueredKey: 'world_map_realm_port_lore_conquered',
    fallbackLoreConquered:
        'Harbor blockaded by ironclad dreadnoughts; dockyards retrofitted into war factories.',
    icon: Icons.anchor_rounded,
  ),
  clericSacredCapital(
    id: 'capital',
    position: Offset(0.28, 0.78),
    fallWeek: 41,
    nameKey: 'world_map_realm_capital_name',
    fallbackName: "Cleric's Sacred Capital",
    loreFreeKey: 'world_map_realm_capital_lore_free',
    fallbackLoreFree:
        'Radiant cathedral and royal keep where the Cleric prepares to break Master Hand.',
    loreConqueredKey: 'world_map_realm_capital_lore_besieged',
    fallbackLoreConquered:
        'Siege towers, red war banners, and iron legions encircle the Sacred Capital on all sides!',
    icon: Icons.church_rounded,
  );

  final String id;
  final Offset position;
  final int fallWeek;
  final String nameKey;
  final String fallbackName;
  final String loreFreeKey;
  final String fallbackLoreFree;
  final String loreConqueredKey;
  final String fallbackLoreConquered;
  final IconData icon;

  const WorldRealmRegion({
    required this.id,
    required this.position,
    required this.fallWeek,
    required this.nameKey,
    required this.fallbackName,
    required this.loreFreeKey,
    required this.fallbackLoreFree,
    required this.loreConqueredKey,
    required this.fallbackLoreConquered,
    required this.icon,
  });

  /// Evaluates the realm's war status at [week] (`1..41`).
  RealmWarStatus statusForWeek(int week) {
    final w = week.clamp(1, GameController.siegeInvasionWeek);
    if (this == WorldRealmRegion.metalWizardDominion) {
      return RealmWarStatus.originDominion;
    }
    if (this == WorldRealmRegion.clericSacredCapital) {
      if (w >= GameController.siegeInvasionWeek) {
        return RealmWarStatus.besieged;
      }
      if (w >= 35) {
        return RealmWarStatus.underThreat;
      }
      return RealmWarStatus.free;
    }
    return w >= fallWeek ? RealmWarStatus.conquered : RealmWarStatus.free;
  }

  String localizedName(LocalizationService loc) =>
      loc.t(nameKey, fallback: fallbackName);

  String localizedStatusBadge(LocalizationService loc, int week) {
    final status = statusForWeek(week);
    switch (status) {
      case RealmWarStatus.originDominion:
        return loc.t(
          'world_map_status_origin',
          fallback: 'Automaton Stronghold — Week 1',
        );
      case RealmWarStatus.free:
        return loc.t('world_map_status_free', fallback: 'Free');
      case RealmWarStatus.underThreat:
        return loc.t(
          'world_map_status_under_threat',
          fallback: 'Under Threat — Border Alert',
        );
      case RealmWarStatus.conquered:
        final template = loc.t(
          'world_map_status_conquered_week',
          fallback: 'Conquered — Week {week}',
        );
        return template.replaceAll('{week}', '$fallWeek');
      case RealmWarStatus.besieged:
        return loc.t(
          'world_map_status_besieged',
          fallback: 'Besieged — Week 41',
        );
    }
  }

  String localizedLore(LocalizationService loc, int week) {
    final status = statusForWeek(week);
    if (this == WorldRealmRegion.clericSacredCapital &&
        status == RealmWarStatus.underThreat) {
      return loc.t(
        'world_map_realm_capital_lore_threat',
        fallback:
            'All neighboring realms have fallen. Only a sacred ward holds back the encircling automaton armies!',
      );
    }
    if (status == RealmWarStatus.conquered ||
        status == RealmWarStatus.besieged ||
        status == RealmWarStatus.originDominion) {
      return loc.t(loreConqueredKey, fallback: fallbackLoreConquered);
    }
    return loc.t(loreFreeKey, fallback: fallbackLoreFree);
  }
}

/// Interactive World Map War Chronicle modal (`3:4` aspect ratio) accessible
/// from the Watch Tower, allowing the player to inspect the Metal Wizard's
/// progressive conquest from Week 1 through Week 41.
class WorldMapWarDialog extends StatefulWidget {
  /// Exact 3:4 vertical aspect ratio of `world_map_peace.jpeg` & `world_map_conquered.jpeg`.
  static const double mapAspectRatio = 3.0 / 4.0;

  final GameController controller;
  final int? initialWeek;

  const WorldMapWarDialog({
    super.key,
    required this.controller,
    this.initialWeek,
  });

  @override
  State<WorldMapWarDialog> createState() => _WorldMapWarDialogState();
}

class _WorldMapWarDialogState extends State<WorldMapWarDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late int _displayedWeek;
  WorldRealmRegion _selectedRegion = WorldRealmRegion.clericSacredCapital;

  int get _maxScrubWeek => widget.controller.maxInspectableWorldMapWeek;

  @override
  void initState() {
    super.initState();
    final defaultWeek =
        widget.initialWeek ?? widget.controller.currentWeek.clamp(1, _maxScrubWeek);
    _displayedWeek = defaultWeek.clamp(1, _maxScrubWeek);
    _selectedRegion = _defaultRegionForWeek(_displayedWeek);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _syncAnimation();
  }

  WorldRealmRegion _defaultRegionForWeek(int week) {
    if (week >= 35) return WorldRealmRegion.clericSacredCapital;
    if (week >= 34) return WorldRealmRegion.crystalPort;
    if (week >= 26) return WorldRealmRegion.verdantDuchy;
    if (week >= 18) return WorldRealmRegion.stoneCitadel;
    if (week >= 10) return WorldRealmRegion.kingdomOfSolaria;
    return WorldRealmRegion.clericSacredCapital;
  }

  void _syncAnimation() {
    if (widget.controller.animationsEnabled) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating || _pulseController.value != 0.0) {
        _pulseController.stop();
        _pulseController.value = 0.5;
      }
    }
  }

  @override
  void didUpdateWidget(covariant WorldMapWarDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _accentForStatus(RealmWarStatus status, AppPalette palette) {
    switch (status) {
      case RealmWarStatus.originDominion:
        return const Color(0xFFFF6D00);
      case RealmWarStatus.free:
        return palette.isDark
            ? const Color(0xFF4CAF50)
            : const Color(0xFF1B6E36);
      case RealmWarStatus.underThreat:
        return const Color(0xFFFF9100);
      case RealmWarStatus.conquered:
        return const Color(0xFFFF3D00);
      case RealmWarStatus.besieged:
        return const Color(0xFFD50000);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.controller.localization;
    final palette = AppPalette.of(context);
    final isDark = palette.isDark;
    final bgSurface =
        isDark ? const Color(0xFF161A22) : const Color(0xFFF5EFE2);
    final cardSurface =
        isDark ? const Color(0xFF1E2430) : const Color(0xFFFAF6EE);
    final goldAccent =
        isDark ? const Color(0xFFF5C22B) : const Color(0xFFB8860B);
    final maxWeek = _maxScrubWeek;
    final displayedWeek = _displayedWeek.clamp(1, maxWeek);
    final isBorderAlertWeek = displayedWeek >= 35 && displayedWeek <= 40;
    final isSiegeWeek41 = displayedWeek >= GameController.siegeInvasionWeek;
    final conqueredCount = WorldRealmRegion.values
        .where(
          (r) =>
              r.statusForWeek(displayedWeek) == RealmWarStatus.conquered ||
              r.statusForWeek(displayedWeek) == RealmWarStatus.besieged ||
              r.statusForWeek(displayedWeek) == RealmWarStatus.originDominion,
        )
        .length;

    return Dialog(
      key: const ValueKey('world_map_war_dialog'),
      backgroundColor: bgSurface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: goldAccent.withValues(alpha: isDark ? 0.65 : 0.80),
          width: 1.6,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Row (Single-Line Title + Fixed-MinWidth Week Pill)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: goldAccent.withValues(
                          alpha: isDark ? 0.16 : 0.14,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: goldAccent.withValues(alpha: 0.55),
                        ),
                      ),
                      child: const WatchTowerIcon(size: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                loc.t(
                                  'world_map_modal_title',
                                  fallback: 'World Map — War Chronicle',
                                ),
                                key: const ValueKey('world_map_modal_title_text'),
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.5,
                                  color: palette.primaryText,
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                loc.t(
                                  'world_map_modal_subtitle',
                                  fallback:
                                      'Tap any realm pin or scrub the timeline to track the invasion',
                                ),
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.secondaryText,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 112,
                        maxWidth: 112,
                      ),
                      child: Container(
                        key: const ValueKey('world_map_week_pill'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSiegeWeek41
                              ? const Color(0xFFD50000).withValues(alpha: 0.18)
                              : isBorderAlertWeek
                                  ? const Color(0xFFFF6D00)
                                      .withValues(alpha: 0.18)
                                  : goldAccent.withValues(
                                      alpha: isDark ? 0.16 : 0.14,
                                    ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSiegeWeek41
                                ? const Color(0xFFFF5252)
                                : isBorderAlertWeek
                                    ? const Color(0xFFFF9100)
                                    : goldAccent.withValues(alpha: 0.65),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${loc.t('map_week_label', fallback: 'Week')} $displayedWeek / ${GameController.maxCampaignWeeks}',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: isSiegeWeek41
                                  ? (isDark
                                      ? const Color(0xFFFF8A80)
                                      : const Color(0xFFB71C1C))
                                  : isBorderAlertWeek
                                      ? (isDark
                                          ? const Color(0xFFFFAB40)
                                          : const Color(0xFFE65100))
                                      : (isDark
                                          ? const Color(0xFFF5C22B)
                                          : const Color(0xFF7A4E00)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 2. Locked 3:4 Interactive Progressive Conquest Map Viewport
                // Sized strictly from the dialog's inner width so its width & height
                // remain 100% identical across Weeks 1..41 with zero side gaps.
                SizedBox(
                  width: double.infinity,
                  child: AspectRatio(
                    key: const ValueKey('world_map_war_aspect_viewport'),
                    aspectRatio: WorldMapWarDialog.mapAspectRatio,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final mapW = constraints.maxWidth;
                        final mapH = constraints.maxHeight;

                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSiegeWeek41
                                  ? const Color(0xFFFF1744)
                                  : isBorderAlertWeek
                                      ? const Color(0xFFFF9100)
                                      : goldAccent.withValues(alpha: 0.75),
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, _) {
                                final pulse = widget.controller.animationsEnabled
                                    ? _pulseController.value
                                    : 0.5;

                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Base Peaceful Layer
                                    Image.asset(
                                      'assets/images/world_map_peace.jpeg',
                                      key: const ValueKey(
                                        'world_map_peace_image',
                                      ),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: const Color(0xFF1B3B2B),
                                      ),
                                    ),

                                    // Clipped Conquered Layer (0% on Week 1, progressive 2..34, sanctuary ring 35..40, 100% on Week 41)
                                    if (displayedWeek > 1)
                                      ClipPath(
                                        key: const ValueKey(
                                          'world_map_conquered_clip_layer',
                                        ),
                                        clipper: ConquestFrontClipper(
                                          displayedWeek: displayedWeek,
                                        ),
                                        child: Image.asset(
                                          'assets/images/world_map_conquered.jpeg',
                                          key: const ValueKey(
                                            'world_map_conquered_image',
                                          ),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            color: const Color(0xFF3E2723),
                                          ),
                                        ),
                                      ),

                                    // Frontline Glow, Sanctuary Border Alert Ring (Weeks 35–40), and Siege Arrows (Week 41)
                                    IgnorePointer(
                                      child: CustomPaint(
                                        key: const ValueKey(
                                          'world_map_conquest_front_painter',
                                        ),
                                        painter: ConquestOverlayPainter(
                                          displayedWeek: displayedWeek,
                                          pulseValue: pulse,
                                        ),
                                      ),
                                    ),

                                    // Top Floating Status / Border Alert Banner (inside map Stack)
                                    if (isBorderAlertWeek || isSiegeWeek41)
                                      Positioned(
                                        top: 8,
                                        left: 10,
                                        right: 10,
                                        child: IgnorePointer(
                                          child: Center(
                                            child: Container(
                                              key: ValueKey(
                                                isSiegeWeek41
                                                    ? 'world_map_siege_week41_banner'
                                                    : 'world_map_border_alert_banner',
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: (isSiegeWeek41
                                                        ? const Color(
                                                            0xFF880E4F,
                                                          )
                                                        : const Color(
                                                            0xFFB71C1C,
                                                          ))
                                                    .withValues(
                                                      alpha:
                                                          0.86 + 0.12 * pulse,
                                                    ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFFFD54F,
                                                  ),
                                                  width: 1.3,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFFFF3D00,
                                                    ).withValues(
                                                      alpha: 0.55 * pulse,
                                                    ),
                                                    blurRadius: 10,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      size: 15,
                                                      color: Color(0xFFFFE082),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      isSiegeWeek41
                                                          ? loc.t(
                                                              'world_map_siege_active_badge',
                                                              fallback:
                                                                  'Final Siege — The Sacred Capital Is Surrounded!',
                                                            )
                                                          : loc.t(
                                                              'world_map_border_alert_badge',
                                                              fallback:
                                                                  'Border Alert — Siege Imminent!',
                                                            ),
                                                      maxLines: 1,
                                                      softWrap: false,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 11,
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    // 6 Interactive Realm Pins
                                    for (final region
                                        in WorldRealmRegion.values)
                                      _buildRealmPin(
                                        context: context,
                                        region: region,
                                        mapWidth: mapW,
                                        mapHeight: mapH,
                                        displayedWeek: displayedWeek,
                                        pulse: pulse,
                                        loc: loc,
                                        palette: palette,
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Selected Realm Lore & Status Card (Strict Fixed Height)
                _buildSelectedRealmCard(
                  context: context,
                  region: _selectedRegion,
                  displayedWeek: displayedWeek,
                  conqueredCount: conqueredCount,
                  loc: loc,
                  palette: palette,
                  cardSurface: cardSurface,
                  goldAccent: goldAccent,
                ),
                const SizedBox(height: 6),

                // 4. Interactive Timeline Scrubbing Slider
                _buildTimelineScrubber(
                  context: context,
                  displayedWeek: displayedWeek,
                  maxWeek: maxWeek,
                  loc: loc,
                  palette: palette,
                  cardSurface: cardSurface,
                  goldAccent: goldAccent,
                ),
                const SizedBox(height: 4),

                // 5. Close Button Row
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const ValueKey('world_map_war_close_button'),
                    style: TextButton.styleFrom(
                      foregroundColor: goldAccent,
                      visualDensity: VisualDensity.compact,
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
      ),
    );
  }

  Widget _buildRealmPin({
    required BuildContext context,
    required WorldRealmRegion region,
    required double mapWidth,
    required double mapHeight,
    required int displayedWeek,
    required double pulse,
    required LocalizationService loc,
    required AppPalette palette,
  }) {
    final isSelected = _selectedRegion == region;
    final status = region.statusForWeek(displayedWeek);
    final accent = _accentForStatus(status, palette);
    final labelText = region.localizedName(loc);
    final labelStyle = TextStyle(
      color: isSelected
          ? const Color(0xFFFFE082)
          : Colors.white.withValues(alpha: 0.96),
      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
      fontSize: 10.5,
      height: 1.15,
    );

    const double edgePad = 6.0;
    const double badgeMaxDiameter = 32.0;
    const double labelGap = 2.0;
    const double labelPillPadH = 12.0; // 6 left + 6 right
    const double labelPillPadV = 4.0; // 2 top + 2 bottom

    final painter = TextPainter(
      text: TextSpan(text: labelText, style: labelStyle),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();

    final maxAvailableW = math.max(40.0, mapWidth - edgePad * 2);
    final pillW = math.min(maxAvailableW, painter.width + labelPillPadH + 2.0);
    final pillH = painter.height + labelPillPadV + 2.0;
    final badgeDiameter = isSelected ? badgeMaxDiameter : 27.0;

    final iconCenterX = region.position.dx * mapWidth;
    final iconCenterY = region.position.dy * mapHeight;

    final iconLeft = (iconCenterX - badgeDiameter / 2)
        .clamp(edgePad, math.max(edgePad, mapWidth - edgePad - badgeDiameter))
        .toDouble();
    final pillLeft = (iconCenterX - pillW / 2)
        .clamp(edgePad, math.max(edgePad, mapWidth - edgePad - pillW))
        .toDouble();

    final totalH = badgeMaxDiameter + labelGap + pillH;
    final boxLeft = math.min(iconLeft, pillLeft);
    final boxRight = math.max(iconLeft + badgeDiameter, pillLeft + pillW);
    final boxTop = (iconCenterY - badgeMaxDiameter / 2)
        .clamp(edgePad, math.max(edgePad, mapHeight - edgePad - totalH))
        .toDouble();

    return Positioned(
      left: boxLeft,
      top: boxTop,
      width: boxRight - boxLeft,
      height: totalH,
      child: GestureDetector(
        key: ValueKey('world_map_pin_${region.id}'),
        behavior: HitTestBehavior.deferToChild,
        onTap: () {
          widget.controller.audio.playTapVibrate();
          setState(() {
            _selectedRegion = region;
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: iconLeft - boxLeft,
              top: (badgeMaxDiameter - badgeDiameter) / 2,
              width: badgeDiameter,
              height: badgeDiameter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: badgeDiameter,
                height: badgeDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF14161D).withValues(alpha: 0.90),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFF5C22B) : accent,
                    width: isSelected ? 2.4 : 1.7,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isSelected ? const Color(0xFFF5C22B) : accent)
                          .withValues(
                            alpha: isSelected ? 0.65 : 0.38 + 0.2 * pulse,
                          ),
                      blurRadius: isSelected ? 12 : 7,
                      spreadRadius: isSelected ? 1.8 : 0.8,
                    ),
                  ],
                ),
                child: Icon(
                  region.icon,
                  size: isSelected ? 17 : 14.5,
                  color: isSelected ? const Color(0xFFF5C22B) : accent,
                ),
              ),
            ),
            Positioned(
              left: pillLeft - boxLeft,
              top: badgeMaxDiameter + labelGap,
              width: pillW,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10131A).withValues(
                    alpha: isSelected ? 0.94 : 0.84,
                  ),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: (isSelected ? const Color(0xFFF5C22B) : accent)
                        .withValues(alpha: isSelected ? 0.90 : 0.55),
                    width: isSelected ? 1.2 : 0.8,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    labelText,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    style: labelStyle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedRealmCard({
    required BuildContext context,
    required WorldRealmRegion region,
    required int displayedWeek,
    required int conqueredCount,
    required LocalizationService loc,
    required AppPalette palette,
    required Color cardSurface,
    required Color goldAccent,
  }) {
    final status = region.statusForWeek(displayedWeek);
    final statusColor = _accentForStatus(status, palette);
    final statusLabel = region.localizedStatusBadge(loc, displayedWeek);
    final loreText = region.localizedLore(loc, displayedWeek);

    return SizedBox(
      height: 124,
      child: Container(
        key: const ValueKey('world_map_selected_realm_card'),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: statusColor.withValues(alpha: palette.isDark ? 0.55 : 0.65),
            width: 1.3,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Realm Icon + Full Realm Name (single-line, never truncated)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Icon(
                    region.icon,
                    size: 16,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        region.localizedName(loc),
                        key: const ValueKey('world_map_selected_realm_name'),
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: palette.primaryText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),

            // Row 2: Dedicated Status Badge Row (single-line, never squeezed/truncated)
            Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Container(
                  key: const ValueKey('world_map_selected_realm_status_badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(
                      alpha: palette.isDark ? 0.18 : 0.14,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                      color: palette.isDark
                          ? Color.lerp(statusColor, Colors.white, 0.25)!
                          : Color.lerp(statusColor, Colors.black, 0.20)!,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),

            // Row 3: Up to 3 lines of lore text inside the fixed-height card
            Expanded(
              child: Text(
                loreText,
                key: const ValueKey('world_map_selected_realm_lore'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.3,
                  color: palette.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineScrubber({
    required BuildContext context,
    required int displayedWeek,
    required int maxWeek,
    required LocalizationService loc,
    required AppPalette palette,
    required Color cardSurface,
    required Color goldAccent,
  }) {
    final weekLabel = loc.t('map_week_label', fallback: 'Week');
    final canScrub = maxWeek > 1;

    return Container(
      key: const ValueKey('world_map_timeline_container'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: goldAccent.withValues(alpha: palette.isDark ? 0.38 : 0.50),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_edu_rounded,
                size: 15,
                color: goldAccent,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      loc.t(
                        'world_map_timeline_label',
                        fallback: 'Conquest Timeline',
                      ),
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        color: palette.primaryText,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$weekLabel 1 — $weekLabel $maxWeek',
                key: const ValueKey('world_map_timeline_range_label'),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: palette.secondaryText,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 32,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: goldAccent,
                inactiveTrackColor:
                    goldAccent.withValues(alpha: palette.isDark ? 0.22 : 0.25),
                thumbColor: goldAccent,
                overlayColor: goldAccent.withValues(alpha: 0.16),
                trackHeight: 4.0,
              ),
              child: Slider(
                key: const ValueKey('world_map_timeline_slider'),
                min: 1.0,
                max: math.max(1.0, maxWeek.toDouble()),
                divisions: canScrub ? (maxWeek - 1) : null,
                value: displayedWeek.clamp(1, maxWeek).toDouble(),
                label: '$weekLabel $displayedWeek',
                onChanged: canScrub
                    ? (val) {
                        final nextWeek = val.round().clamp(1, maxWeek);
                        if (nextWeek != _displayedWeek) {
                          setState(() {
                            _displayedWeek = nextWeek;
                          });
                        }
                      }
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Computes the progressive conquest geometry for [displayedWeek] (`1..41`)
/// anchored to the `3:4` map coordinate system:
/// - **Week 1:** `0%` conquered (`Path()` is empty).
/// - **Weeks 2..34:** An organic wavy arc expands from the Metal Wizard's
///   Dominion (`0.78, 0.20`) across the continent so each kingdom is engulfed
///   on its exact fall week (Solaria W10, Stone Citadel W18, Verdant Duchy W26,
///   Crystal Port W34) while leaving the Cleric's Sacred Capital (`0.28, 0.78`)
///   unconquered.
/// - **Weeks 35..40:** All 5 outer regions are conquered, leaving only a
///   circular protective sanctuary around the Cleric's Sacred Capital (`0.28, 0.78`).
/// - **Week 41:** Sanctuary closes (`100%` of `world_map_conquered` revealed).
class ConquestFrontGeometry {
  static const Offset dominionOrigin = Offset(0.78, 0.20);
  static const Offset clericCapitalCenter = Offset(0.28, 0.78);

  /// Normalized radius (relative to map width) of the Cleric's protective
  /// sanctuary ring during Weeks 35–40.
  static double sanctuaryRadiusForWeek(int week, Size size) {
    if (week >= GameController.siegeInvasionWeek) return 0.0;
    // Shrinks slightly as siege tightens from Week 35 to Week 40
    final t = ((week - 35).clamp(0, 5)) / 5.0;
    final normalizedRadius = 0.215 - (0.035 * t);
    return size.width * normalizedRadius;
  }

  /// Normalized radial reach from [dominionOrigin] (`0.78, 0.20`) for Weeks 2..34.
  /// Calibrated against each kingdom's Euclidean distance in normalized `(x, y * 4/3)` space:
  /// - Dominion (0.78, 0.20) -> dist 0.0
  /// - Solaria (0.62, 0.45) -> dist ~0.37 (Fall Week 10)
  /// - Stone Citadel (0.27, 0.22) -> dist ~0.51 (Fall Week 18)
  /// - Verdant Duchy (0.25, 0.48) -> dist ~0.65 (Fall Week 26)
  /// - Crystal Port (0.72, 0.73) -> dist ~0.71 (Fall Week 34)
  /// - Cleric's Capital (0.28, 0.78) -> dist ~0.92 (Protected until Week 41)
  static double frontRadiusInPixels(int week, Size size) {
    final w = week.clamp(1, GameController.siegeInvasionWeek);
    if (w <= 1) return 0.0;

    // Piecewise linear interpolation hitting each kingdom's threshold cleanly
    final double normRadius;
    if (w < 10) {
      // Weeks 2..9: expand from Dominion (0.14) to just before Solaria (0.34)
      final t = (w - 2) / 8.0;
      normRadius = 0.16 + t * (0.34 - 0.16);
    } else if (w < 18) {
      // Weeks 10..17: engulf Solaria at W10 (0.42) -> approach Stone Citadel (0.49)
      final t = (w - 10) / 8.0;
      normRadius = 0.42 + t * (0.49 - 0.42);
    } else if (w < 26) {
      // Weeks 18..25: engulf Stone Citadel at W18 (0.56) -> approach Verdant Duchy (0.62)
      final t = (w - 18) / 8.0;
      normRadius = 0.56 + t * (0.62 - 0.56);
    } else if (w < 34) {
      // Weeks 26..33: engulf Verdant Duchy at W26 (0.68) -> approach Crystal Port (0.72)
      final t = (w - 26) / 8.0;
      normRadius = 0.68 + t * (0.72 - 0.68);
    } else {
      // Week 34: engulf Crystal Port (0.86)
      normRadius = 0.86;
    }
    return normRadius * size.width;
  }

  /// Builds the organic wavy invasion front polygon centered on [dominionOrigin].
  static Path buildWaveFrontPath(int week, Size size) {
    final baseR = frontRadiusInPixels(week, size);
    if (baseR <= 0) return Path();

    final origin = Offset(
      dominionOrigin.dx * size.width,
      dominionOrigin.dy * size.height,
    );
    final path = Path();
    const int steps = 72;
    final waveAmp = size.width * 0.018;

    for (int i = 0; i <= steps; i++) {
      final theta = (i / steps) * 2 * math.pi;
      final wave = math.sin(theta * 5 + week * 0.45) * waveAmp +
          math.cos(theta * 3 - week * 0.3) * (waveAmp * 0.55);
      final r = math.max(4.0, baseR + wave);
      // Scale y slightly by aspect ratio so radial distance matches visual distance
      final px = origin.dx + r * math.cos(theta);
      final py = origin.dy + r * math.sin(theta) * (1.0 / 1.05);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();

    // Always subtract the Cleric's Sacred Capital sanctuary during Weeks 2..40
    final sanctuaryCenter = Offset(
      clericCapitalCenter.dx * size.width,
      clericCapitalCenter.dy * size.height,
    );
    final sanctuaryR = sanctuaryRadiusForWeek(35, size);
    final sanctuaryPath = Path()
      ..addOval(
        Rect.fromCircle(center: sanctuaryCenter, radius: sanctuaryR),
      );

    return Path.combine(PathOperation.difference, path, sanctuaryPath);
  }

  /// Builds the clip path for `world_map_conquered.jpeg` at [week].
  static Path buildClipPath(int week, Size size) {
    final w = week.clamp(1, GameController.siegeInvasionWeek);
    if (w <= 1) {
      return Path();
    }
    final fullRect = Path()..addRect(Offset.zero & size);
    if (w >= GameController.siegeInvasionWeek) {
      return fullRect;
    }
    if (w >= 35) {
      // Weeks 35..40: entire continent conquered EXCEPT circular sanctuary around Cleric's Capital
      final sanctuaryCenter = Offset(
        clericCapitalCenter.dx * size.width,
        clericCapitalCenter.dy * size.height,
      );
      final sanctuaryR = sanctuaryRadiusForWeek(w, size);
      final hole = Path()
        ..addOval(
          Rect.fromCircle(center: sanctuaryCenter, radius: sanctuaryR),
        );
      return Path.combine(PathOperation.difference, fullRect, hole);
    }
    return buildWaveFrontPath(w, size);
  }
}

/// Dynamic [CustomClipper] revealing `world_map_conquered.jpeg` according to [displayedWeek].
class ConquestFrontClipper extends CustomClipper<Path> {
  final int displayedWeek;

  const ConquestFrontClipper({required this.displayedWeek});

  @override
  Path getClip(Size size) =>
      ConquestFrontGeometry.buildClipPath(displayedWeek, size);

  @override
  bool shouldReclip(covariant ConquestFrontClipper oldClipper) =>
      oldClipper.displayedWeek != displayedWeek;
}

/// Draws the glowing ember/molten-orange frontline border (`#FF6D00` / `#FF3D00`)
/// during Weeks 2–34, the pulsing red/amber sanctuary border alert during
/// Weeks 35–40, and the animated siege assault markers encircling the Cleric's
/// Sacred Capital on Week 41.
class ConquestOverlayPainter extends CustomPainter {
  final int displayedWeek;
  final double pulseValue;

  const ConquestOverlayPainter({
    required this.displayedWeek,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = displayedWeek.clamp(1, GameController.siegeInvasionWeek);
    if (w <= 1) return;

    final capitalCenter = Offset(
      ConquestFrontGeometry.clericCapitalCenter.dx * size.width,
      ConquestFrontGeometry.clericCapitalCenter.dy * size.height,
    );

    if (w >= 2 && w <= 34) {
      // Glowing molten-orange invasion frontline
      final frontPath = ConquestFrontGeometry.buildWaveFrontPath(w, size);
      final outerGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..color = const Color(0xFFFF3D00).withValues(
          alpha: 0.40 + 0.25 * pulseValue,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      final coreLine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = Color.lerp(
          const Color(0xFFFF6D00),
          const Color(0xFFFFD54F),
          pulseValue * 0.5,
        )!;

      canvas.drawPath(frontPath, outerGlow);
      canvas.drawPath(frontPath, coreLine);
      return;
    }

    if (w >= 35 && w <= 40) {
      // Dramatic pulsing red/amber border alert ring around the Cleric's Sacred Capital
      final radius = ConquestFrontGeometry.sanctuaryRadiusForWeek(w, size);
      final outerAlertGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0 + 4.0 * pulseValue
        ..color = const Color(0xFFFF1744).withValues(
          alpha: 0.45 + 0.35 * pulseValue,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

      final innerAmberRing = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..color = Color.lerp(
          const Color(0xFFFF3D00),
          const Color(0xFFFFCA28),
          pulseValue,
        )!;

      canvas.drawCircle(capitalCenter, radius, outerAlertGlow);
      canvas.drawCircle(capitalCenter, radius, innerAmberRing);

      // Dashed / ticked ward markers around the sanctuary ring
      const int ticks = 16;
      final tickPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFE082).withValues(
          alpha: 0.65 + 0.30 * pulseValue,
        );
      for (int i = 0; i < ticks; i++) {
        final angle = (i / ticks) * 2 * math.pi + (pulseValue * 0.15);
        final p1 = Offset(
          capitalCenter.dx + (radius - 4) * math.cos(angle),
          capitalCenter.dy + (radius - 4) * math.sin(angle),
        );
        final p2 = Offset(
          capitalCenter.dx + (radius + 5) * math.cos(angle),
          capitalCenter.dy + (radius + 5) * math.sin(angle),
        );
        canvas.drawLine(p1, p2, tickPaint);
      }
      return;
    }

    if (w >= GameController.siegeInvasionWeek) {
      // Week 41: Sanctuary breached — pulsing siege ring & inward assault arrows around (0.28, 0.78)
      final siegeRadius = size.width * (0.145 - 0.015 * pulseValue);
      final siegeGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..color = const Color(0xFFD50000).withValues(
          alpha: 0.50 + 0.35 * pulseValue,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawCircle(capitalCenter, siegeRadius, siegeGlow);

      final arrowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Color.lerp(
          const Color(0xFFFF1744),
          const Color(0xFFFFD54F),
          pulseValue * 0.45,
        )!;

      const int arrowCount = 8;
      for (int i = 0; i < arrowCount; i++) {
        final angle = (i / arrowCount) * 2 * math.pi;
        final tipDist = siegeRadius * 0.72;
        final tailDist = siegeRadius * 1.12;
        final tip = Offset(
          capitalCenter.dx + tipDist * math.cos(angle),
          capitalCenter.dy + tipDist * math.sin(angle),
        );
        final leftWing = Offset(
          capitalCenter.dx + tailDist * math.cos(angle - 0.14),
          capitalCenter.dy + tailDist * math.sin(angle - 0.14),
        );
        final rightWing = Offset(
          capitalCenter.dx + tailDist * math.cos(angle + 0.14),
          capitalCenter.dy + tailDist * math.sin(angle + 0.14),
        );
        final arrowPath = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(leftWing.dx, leftWing.dy)
          ..lineTo(rightWing.dx, rightWing.dy)
          ..close();
        canvas.drawPath(arrowPath, arrowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ConquestOverlayPainter oldDelegate) =>
      oldDelegate.displayedWeek != displayedWeek ||
      oldDelegate.pulseValue != pulseValue;
}
