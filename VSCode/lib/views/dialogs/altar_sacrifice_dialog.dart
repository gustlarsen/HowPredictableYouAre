import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../models/royal_castle.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/elemental_energy_sphere.dart';
import '../widgets/temple_wing_icons.dart';

/// Animation phases of the Sacred Temple's Altar of Sacrifice & Divine Star Blessing.
enum AltarRitualPhase {
  /// `0.0s – 1.1s`: Elemental orbs settle on the altar basin and are consumed
  /// by rising holocaust flames and ascending embers.
  offeringAndFlame,

  /// `1.1s – 2.0s`: A radiant celestial star and divine beam descend onto the
  /// altar, blossoming into a buffered warm cream/gold wash.
  descendingStarAndFlash,

  /// `2.0s+`: Acquired item emblem, localized title, clear gameplay description,
  /// and Continue action button.
  itemReveal,
}

/// Deterministic position and timing metadata for a single visual orb rendered
/// inside an elemental sacrifice cluster on the altar basin.
class SacrificeVisualOrbNode {
  final HandMove move;
  final Offset normalizedAltarPos;
  final double normalizedRadius;
  final int layerIndex;
  final double stagger;

  const SacrificeVisualOrbNode({
    required this.move,
    required this.normalizedAltarPos,
    required this.normalizedRadius,
    required this.layerIndex,
    required this.stagger,
  });
}

/// Scaled visual orb cluster paired with the exact numeric sacrifice amount for
/// a single required [HandMove] element.
class SacrificeOrbCluster {
  final HandMove move;
  final int exactCost;
  final int visualOrbCount;
  final List<SacrificeVisualOrbNode> orbs;

  const SacrificeOrbCluster({
    required this.move,
    required this.exactCost,
    required this.visualOrbCount,
    required this.orbs,
  });
}

/// Dramatic 3-phase **Altar of Sacrifice / Holocaust & Divine Star Blessing**
/// overlay shown whenever the player unlocks or upgrades an item in the Sacred
/// Temple's **Offerings** (`Altar of Offerings`) wing.
class AltarSacrificeDialog extends StatefulWidget {
  static const String altarAssetPath = 'assets/images/sacred_altar.webp';
  static const Size altarImageIntrinsicSize = Size(764.0, 1024.0);
  static const Duration totalDuration = Duration(milliseconds: 3000);
  static const Duration skipUnlockDelay = Duration(milliseconds: 800);

  static const Color warmCreamFlash = Color(0xFFFFFDF5);
  static const Color warmGoldFlash = Color(0xFFFFE082);
  static const Color _goldFill = Color(0xFFF5C22B);
  static const Color _goldDarkInk = Color(0xFF1E1B16);

  final GameController controller;
  final ShopUpgradeArtifact artifact;
  final String itemTitle;
  final String itemDescription;
  final ElementalCost sacrificedCost;
  final String? badgeLabel;
  final String? emblemAssetPath;
  final IconData fallbackIcon;

  const AltarSacrificeDialog({
    super.key,
    required this.controller,
    required this.artifact,
    required this.itemTitle,
    required this.itemDescription,
    required this.sacrificedCost,
    this.badgeLabel,
    this.emblemAssetPath,
    required this.fallbackIcon,
  });

  /// Maps a canonical [ShopUpgradeArtifact] to its illustrated RPG emblem WebP asset.
  static String? emblemAssetForArtifact(ShopUpgradeArtifact artifact) {
    switch (artifact) {
      case ShopUpgradeArtifact.predictability:
        return 'assets/images/offerings/predictability_score.webp';
      case ShopUpgradeArtifact.reset:
        return 'assets/images/offerings/reset_button.webp';
      case ShopUpgradeArtifact.newHands:
        return 'assets/images/offerings/learn_earth_metal.webp';
      case ShopUpgradeArtifact.random:
        return 'assets/images/offerings/random_button.webp';
      case ShopUpgradeArtifact.overchargedStaff:
        return 'assets/images/offerings/overcharged_staff.webp';
      case ShopUpgradeArtifact.algorithm:
      case ShopUpgradeArtifact.markovRecalibrator:
        return 'assets/images/offerings/show_algorithm.webp';
      case ShopUpgradeArtifact.yourPrediction:
        return 'assets/images/offerings/your_prediction.webp';
      case ShopUpgradeArtifact.nextMove:
        return 'assets/images/offerings/pc_next_move.webp';
      case ShopUpgradeArtifact.giftBox:
        return 'assets/images/offerings/gift_box.webp';
      case ShopUpgradeArtifact.suggestion:
        return 'assets/images/offerings/suggestion.webp';
      case ShopUpgradeArtifact.crystalBall:
      case ShopUpgradeArtifact.crystalBallPlus:
        return 'assets/images/offerings/crystal_ball.webp';
      case ShopUpgradeArtifact.newSkin:
      case ShopUpgradeArtifact.removeAds:
        return null;
    }
  }

  /// Maps an exact elemental orb cost (`15` up to `20,000+`) onto a clean,
  /// legible visual orb pile count (`3..18` for `15..20,000+`) using a smooth
  /// logarithmic curve so larger sacrifices visibly build a richer pyramid on
  /// the altar basin without cluttering or freezing the UI.
  static int visualOrbCountForCost(int cost) {
    if (cost <= 0) return 0;
    if (cost < 15) {
      return math.max(1, (1.0 + 2.0 * (cost / 15.0)).round()).clamp(1, 3);
    }
    const double minLog = 2.70805020110221; // ln(15)
    const double maxLog = 9.903487552536127; // ln(20,000)
    final double normalized =
        ((math.log(cost.toDouble()) - minLog) / (maxLog - minLog)).clamp(
          0.0,
          1.12,
        );
    return (3.0 + normalized * 13.5).round().clamp(3, 18);
  }

  /// Resolves the active [AltarRitualPhase] for normalized controller progress [p] (`0.0..1.0`).
  static AltarRitualPhase phaseForProgress(double p) {
    final seconds = p.clamp(0.0, 1.0) * (totalDuration.inMilliseconds / 1000.0);
    if (seconds < 1.10) {
      return AltarRitualPhase.offeringAndFlame;
    }
    if (seconds < 2.00) {
      return AltarRitualPhase.descendingStarAndFlash;
    }
    return AltarRitualPhase.itemReveal;
  }

  /// Formats an exact orb quantity with localized thousands separators (`15`, `30`, `20,000`).
  static String formatExactQuantity(int value, LocalizationService loc) {
    final sep = loc.currentLanguage == 'en' ? ',' : '.';
    final str = value.toString();
    if (str.length <= 3) return str;
    return str.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}$sep',
    );
  }

  /// Precomputes deterministic pyramidal orb clusters across the recessed
  /// octagonal marble basin (`x ∈ [0.30, 0.70]`, `y ∈ [0.47, 0.54]`) of
  /// `sacred_altar.webp`.
  static List<SacrificeOrbCluster> buildVisualOrbClusters(ElementalCost cost) {
    final entries = cost.nonZeroEntries;
    if (entries.isEmpty) return const [];

    final countElements = entries.length;
    final maxVisual = entries
        .map((e) => visualOrbCountForCost(e.value))
        .fold<int>(0, math.max);

    final double baseRadiusNorm;
    if (countElements <= 2 && maxVisual <= 6) {
      baseRadiusNorm = 0.022;
    } else if (countElements <= 3 && maxVisual <= 7) {
      baseRadiusNorm = 0.0195;
    } else if (maxVisual <= 11) {
      baseRadiusNorm = 0.0168;
    } else {
      baseRadiusNorm = 0.0148;
    }

    final clusters = <SacrificeOrbCluster>[];
    for (int elemIdx = 0; elemIdx < countElements; elemIdx++) {
      final entry = entries[elemIdx];
      final move = entry.key;
      final exact = entry.value;
      final visualCount = visualOrbCountForCost(exact);

      // Evenly distribute element sub-piles across the flat marble basin floor.
      final double sectorCenterX;
      if (countElements == 1) {
        sectorCenterX = 0.50;
      } else {
        final span = countElements == 2
            ? 0.19
            : (countElements == 3 ? 0.28 : 0.36);
        final left = 0.50 - span * 0.5;
        sectorCenterX = left + span * (elemIdx / (countElements - 1));
      }

      // Slight elliptical depth arc so outer piles sit naturally inside the octagonal rim.
      final distFromCenter = (sectorCenterX - 0.50).abs() / 0.20;
      final sectorBaseY = 0.534 - 0.008 * distFromCenter * distFromCenter;

      final int baseCols;
      if (visualCount <= 3) {
        baseCols = 2;
      } else if (visualCount <= 6) {
        baseCols = 3;
      } else if (visualCount <= 10) {
        baseCols = 4;
      } else if (visualCount <= 15) {
        baseCols = 5;
      } else {
        baseCols = 6;
      }

      final nodes = <SacrificeVisualOrbNode>[];
      int remaining = visualCount;
      int row = 0;
      int placed = 0;
      final horizStep = baseRadiusNorm * (countElements >= 5 ? 1.52 : 1.72);
      final vertStep = baseRadiusNorm * 1.34;

      while (remaining > 0) {
        final rowCap = math.max(1, baseCols - row);
        final colsInRow = math.min(remaining, rowCap);
        for (int col = 0; col < colsInRow; col++) {
          final centeredCol = col - (colsInRow - 1) * 0.5;
          // Deterministic micro-jitter so stacked spheres feel organic on stone.
          final seed = (elemIdx * 31 + placed * 17 + move.id * 13);
          final jitterX = (((seed % 9) - 4) / 4.0) * (baseRadiusNorm * 0.14);
          final jitterY =
              ((((seed ~/ 3) % 7) - 3) / 3.0) * (baseRadiusNorm * 0.10);

          final nx = (sectorCenterX + centeredCol * horizStep + jitterX).clamp(
            0.285,
            0.715,
          );
          final ny = (sectorBaseY - row * vertStep + jitterY).clamp(
            0.445,
            0.542,
          );

          final stagger =
              ((elemIdx * 0.13 + placed * 0.045) % 0.42).clamp(0.0, 0.42);

          nodes.add(
            SacrificeVisualOrbNode(
              move: move,
              normalizedAltarPos: Offset(nx, ny),
              normalizedRadius: baseRadiusNorm,
              layerIndex: row * 10 + col,
              stagger: stagger,
            ),
          );
          placed++;
        }
        remaining -= colsInRow;
        row++;
      }

      clusters.add(
        SacrificeOrbCluster(
          move: move,
          exactCost: exact,
          visualOrbCount: visualCount,
          orbs: List.unmodifiable(nodes),
        ),
      );
    }

    return List.unmodifiable(clusters);
  }

  /// Opens the Altar of Sacrifice & Divine Star Blessing modal overlay.
  static Future<void> show(
    BuildContext context, {
    required GameController controller,
    required ShopUpgradeArtifact artifact,
    required String itemTitle,
    required String itemDescription,
    required ElementalCost sacrificedCost,
    String? badgeLabel,
    String? emblemAssetPath,
  }) {
    controller.audio.playStoryChime();
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Altar of Sacrifice',
      barrierColor: Colors.black.withValues(alpha: 0.86),
      transitionDuration: controller.animationsEnabled
          ? const Duration(milliseconds: 240)
          : Duration.zero,
      pageBuilder: (ctx, anim1, anim2) {
        return AltarSacrificeDialog(
          controller: controller,
          artifact: artifact,
          itemTitle: itemTitle,
          itemDescription: itemDescription,
          sacrificedCost: sacrificedCost,
          badgeLabel: badgeLabel,
          emblemAssetPath:
              emblemAssetPath ?? emblemAssetForArtifact(artifact),
          fallbackIcon: artifact.icon,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        if (!controller.animationsEnabled) return child;
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AltarSacrificeDialog> createState() => _AltarSacrificeDialogState();
}

class _AltarSacrificeDialogState extends State<AltarSacrificeDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<SacrificeOrbCluster> _clusters;

  @override
  void initState() {
    super.initState();
    _clusters = AltarSacrificeDialog.buildVisualOrbClusters(
      widget.sacrificedCost,
    );
    _controller = AnimationController(
      vsync: this,
      duration: AltarSacrificeDialog.totalDuration,
    )..forward();
  }

  @override
  void didUpdateWidget(covariant AltarSacrificeDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sacrificedCost != widget.sacrificedCost) {
      _clusters = AltarSacrificeDialog.buildVisualOrbClusters(
        widget.sacrificedCost,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _elapsedSeconds =>
      _controller.value *
      (AltarSacrificeDialog.totalDuration.inMilliseconds / 1000.0);

  bool get _canFastForward {
    final minSeconds =
        AltarSacrificeDialog.skipUnlockDelay.inMilliseconds / 1000.0;
    return _elapsedSeconds >= minSeconds && _controller.value < 0.98;
  }

  void _fastForwardToReveal() {
    if (_controller.value >= 0.98) return;
    widget.controller.audio.playTapVibrate();
    _controller.value = 1.0;
  }

  void _handleStageTap() {
    if (_canFastForward) {
      _fastForwardToReveal();
    }
  }

  void _closeDialog() {
    widget.controller.audio.playTapVibrate();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Smooth bell-curve opacity (`0.0 .. 0.94`) for the buffered luminous
  /// cream/golden flash between `1.50s` and `2.30s` (peak around `1.88s`).
  double _computeWarmFlashAlpha(double p) {
    final sec = p * 3.0;
    if (sec <= 1.50 || sec >= 2.32) return 0.0;
    if (sec < 1.88) {
      final up = ((sec - 1.50) / (1.88 - 1.50)).clamp(0.0, 1.0);
      return 0.94 * Curves.easeInOutCubic.transform(up);
    }
    final down = ((2.32 - sec) / (2.32 - 1.88)).clamp(0.0, 1.0);
    return 0.94 * Curves.easeOutCubic.transform(down);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, _controller]),
      builder: (context, _) {
        final loc = widget.controller.localization;
        final palette = AppPalette.of(context);
        final p = _controller.value.clamp(0.0, 1.0);
        final phase = AltarSacrificeDialog.phaseForProgress(p);
        // Swap underlying stage beneath the peak of the warm golden-cream wash (~1.88s).
        final showRevealStage = p >= (1.88 / 3.0);
        final flashAlpha = _computeWarmFlashAlpha(p);

        final headerTitle = showRevealStage
            ? loc.t(
                'sacred_temple_altar_title',
                fallback: 'Altar of Offerings',
              )
            : loc.t('altar_sacrifice_title', fallback: 'Altar of Sacrifice');

        final String headerSubtitle;
        switch (phase) {
          case AltarRitualPhase.offeringAndFlame:
            headerSubtitle = loc.t(
              'altar_sacrifice_phase_flame',
              fallback: 'Holocaust Flame Consumes Your Offering...',
            );
          case AltarRitualPhase.descendingStarAndFlash:
            headerSubtitle = loc.t(
              'altar_sacrifice_phase_star',
              fallback: 'A Divine Star Descends Upon the Sanctuary...',
            );
          case AltarRitualPhase.itemReveal:
            headerSubtitle = loc.t(
              'altar_blessing_granted_badge',
              fallback: 'SACRED BLESSING GRANTED',
            );
        }

        return Dialog(
          key: const ValueKey('altar_sacrifice_dialog'),
          backgroundColor: palette.dialogSurface,
          surfaceTintColor: palette.isDark ? null : Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 14.0,
            vertical: 14.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: palette.amberBorder.withValues(
                alpha: palette.isDark ? 0.62 : 0.78,
              ),
              width: 1.5,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 680),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22.5),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Sanctuary Ritual Header + Subtle Skip Button (after 0.8s)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: palette.amberBorder.withValues(
                                  alpha: palette.isDark ? 0.18 : 0.14,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: palette.amberBorder.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                              child: const OfferingsAltarIcon(
                                size: 22,
                                isOnGoldBackground: false,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    headerTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: palette.primaryText,
                                    ),
                                  ),
                                  Text(
                                    headerSubtitle,
                                    key: const ValueKey(
                                      'altar_sacrifice_phase_subtitle',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: palette.amberSubtitle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_canFastForward) ...[
                              const SizedBox(width: 6),
                              TextButton.icon(
                                key: const ValueKey(
                                  'altar_sacrifice_skip_button',
                                ),
                                onPressed: _fastForwardToReveal,
                                style: TextButton.styleFrom(
                                  foregroundColor: palette.amberText,
                                  backgroundColor: palette.rewardedAdCardSurface,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: palette.amberBorder.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.fast_forward_rounded,
                                  size: 15,
                                ),
                                label: Text(
                                  loc.t('story_skip', fallback: 'Skip'),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),

                        // 2. Main Animated Altar Stage OR Acquired Item Reveal View
                        Flexible(
                          child: showRevealStage
                              ? _buildItemRevealStage(
                                  context: context,
                                  palette: palette,
                                  loc: loc,
                                  progress: p,
                                )
                              : _buildAltarSacrificeStage(
                                  context: context,
                                  palette: palette,
                                  loc: loc,
                                  progress: p,
                                ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Buffered Warm Golden-Cream Luminous Flash Overlay (#FFFDF5 / #FFE082)
                  if (flashAlpha > 0.005)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          key: const ValueKey('altar_luminous_flash_overlay'),
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0.0, -0.06),
                              radius: 1.05,
                              colors: [
                                AltarSacrificeDialog.warmCreamFlash.withValues(
                                  alpha: flashAlpha,
                                ),
                                AltarSacrificeDialog.warmGoldFlash.withValues(
                                  alpha: (flashAlpha * 0.90).clamp(0.0, 1.0),
                                ),
                                AltarSacrificeDialog.warmCreamFlash.withValues(
                                  alpha: (flashAlpha * 0.78).clamp(0.0, 1.0),
                                ),
                              ],
                              stops: const [0.0, 0.58, 1.0],
                            ),
                          ),
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

  Widget _buildAltarSacrificeStage({
    required BuildContext context,
    required AppPalette palette,
    required LocalizationService loc,
    required double progress,
  }) {
    return GestureDetector(
      key: const ValueKey('altar_sacrifice_stage'),
      behavior: HitTestBehavior.opaque,
      onTap: _handleStageTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 430),
                child: AspectRatio(
                  aspectRatio:
                      AltarSacrificeDialog.altarImageIntrinsicSize.width /
                      AltarSacrificeDialog.altarImageIntrinsicSize.height,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF12131A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: palette.amberBorder.withValues(alpha: 0.55),
                          width: 1.3,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Base Altar of Sacrifice Illustration
                          Image.asset(
                            AltarSacrificeDialog.altarAssetPath,
                            key: const ValueKey('sacred_altar_artwork'),
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (context, error, stackTrace) {
                              return const ColoredBox(
                                color: Color(0xFF1A1822),
                                child: Center(
                                  child: OfferingsAltarIcon(
                                    size: 72,
                                    isOnGoldBackground: false,
                                  ),
                                ),
                              );
                            },
                          ),

                          // CustomPainter: Proportional Orbs, Holocaust Flames, Embers & Descending Star
                          RepaintBoundary(
                            child: CustomPaint(
                              key: const ValueKey(
                                'altar_sacrifice_custom_paint',
                              ),
                              painter: AltarSacrificePainter(
                                progress: progress,
                                clusters: _clusters,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Exact Numeric Sacrificed Orb Quantities Bar
          _buildSacrificedCostBar(
            palette: palette,
            loc: loc,
            containerKey: const ValueKey('altar_sacrifice_cost_bar'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRevealStage({
    required BuildContext context,
    required AppPalette palette,
    required LocalizationService loc,
    required double progress,
  }) {
    // Entrance progress from t = 1.88s -> 2.55s
    final sec = progress * 3.0;
    final entranceT = ((sec - 1.88) / (2.55 - 1.88)).clamp(0.0, 1.0);
    final emblemScale =
        0.74 + 0.26 * Curves.easeOutBack.transform(entranceT);
    final contentOpacity = Curves.easeOutCubic.transform(
      ((sec - 1.92) / 0.45).clamp(0.0, 1.0),
    );

    return Column(
      key: const ValueKey('altar_item_reveal_stage'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Opacity(
              opacity: contentOpacity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sacred Blessing Granted Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.rewardedAdCardSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: palette.amberBorder.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: palette.amberIcon,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            loc.t(
                              'altar_blessing_granted_badge',
                              fallback: 'SACRED BLESSING GRANTED',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: palette.amberText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Centered Acquired Item Emblem with Radiant Scale & Divine Halo
                  Transform.scale(
                    scale: emblemScale,
                    child: _buildItemEmblemMedallion(
                      palette: palette,
                      entranceT: entranceT,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Acquired Item Title + Optional Upgrade Badge (e.g. Lv. 2..6 or +)
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        widget.itemTitle,
                        key: const ValueKey('altar_reveal_item_title'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.bold,
                          color: palette.primaryText,
                        ),
                      ),
                      if (widget.badgeLabel != null &&
                          widget.badgeLabel!.trim().isNotEmpty)
                        Container(
                          key: const ValueKey('altar_reveal_item_badge'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: AltarSacrificeDialog._goldFill,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            widget.badgeLabel!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: AltarSacrificeDialog._goldDarkInk,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Clear, Readable Explanatory Gameplay Description Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: palette.dialogCardSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: palette.amberBorder.withValues(
                          alpha: palette.isDark ? 0.36 : 0.55,
                        ),
                      ),
                    ),
                    child: Text(
                      widget.itemDescription,
                      key: const ValueKey('altar_reveal_item_description'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.42,
                        fontWeight: FontWeight.w500,
                        color: palette.primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Sacrificed Orbs Summary Pill (preserves exact numeric counters in Phase 3)
                  _buildSacrificedCostBar(
                    palette: palette,
                    loc: loc,
                    containerKey: const ValueKey('altar_reveal_cost_summary'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Clean "Continue" Action Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const ValueKey('altar_reveal_collect_button'),
            onPressed: _closeDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AltarSacrificeDialog._goldFill,
              foregroundColor: AltarSacrificeDialog._goldDarkInk,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
            label: Text(
              loc.t('altar_collect_blessing', fallback: 'Continue'),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemEmblemMedallion({
    required AppPalette palette,
    required double entranceT,
  }) {
    final isPlus = widget.artifact == ShopUpgradeArtifact.crystalBallPlus;
    final isRecalibrator =
        widget.artifact == ShopUpgradeArtifact.markovRecalibrator;
    final isNewSkin = widget.artifact == ShopUpgradeArtifact.newSkin;

    Widget emblemCore;
    if (isNewSkin) {
      emblemCore = Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF2B3040), Color(0xFF151821)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 18,
              child: Image.asset(
                'assets/images/PaperL.png',
                width: 46,
                height: 46,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.pan_tool_rounded,
                  color: Color(0xFF4FC3F7),
                  size: 34,
                ),
              ),
            ),
            Positioned(
              bottom: 18,
              left: 16,
              child: Image.asset(
                'assets/images/RockL.png',
                width: 44,
                height: 44,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.circle_rounded,
                  color: Color(0xFFFF7043),
                  size: 32,
                ),
              ),
            ),
            Positioned(
              bottom: 18,
              right: 16,
              child: Image.asset(
                'assets/images/ScissorL.png',
                width: 44,
                height: 44,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.content_cut_rounded,
                  color: Color(0xFF69F0AE),
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (widget.emblemAssetPath != null) {
      emblemCore = Image.asset(
        widget.emblemAssetPath!,
        key: ValueKey('altar_reveal_emblem_image_${widget.artifact.id}'),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => ColoredBox(
          color: const Color(0xFF1A1E29),
          child: Center(
            child: Icon(
              widget.fallbackIcon,
              size: 56,
              color: AltarSacrificeDialog._goldFill,
            ),
          ),
        ),
      );
    } else {
      emblemCore = ColoredBox(
        color: const Color(0xFF1A1E29),
        child: Center(
          child: Icon(
            widget.fallbackIcon,
            size: 56,
            color: AltarSacrificeDialog._goldFill,
          ),
        ),
      );
    }

    return SizedBox(
      key: const ValueKey('altar_reveal_item_emblem'),
      width: 152,
      height: 152,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radiant Starburst Halo Behind Acquired Item
          Positioned.fill(
            child: CustomPaint(
              painter: _RevealHaloPainter(
                entranceProgress: entranceT,
                isDark: palette.isDark,
                isCosmicPlus: isPlus,
              ),
            ),
          ),

          // Ornate Beveled Golden Relic Frame
          Container(
            width: 124,
            height: 124,
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isPlus
                    ? const [
                        Color(0xFF80D8FF),
                        Color(0xFFFFD54F),
                        Color(0xFFCE93D8),
                      ]
                    : const [
                        Color(0xFFFFECB3),
                        Color(0xFFF5C22B),
                        Color(0xFFB27D12),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: (isPlus
                          ? const Color(0xFF40C4FF)
                          : AltarSacrificeDialog._goldFill)
                      .withValues(alpha: palette.isDark ? 0.42 : 0.30),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.5),
              child: emblemCore,
            ),
          ),

          // Corner Overlay Emblem for Crystal Ball+ or Markov Recalibrator
          if (isPlus || isRecalibrator)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: isPlus
                      ? const Color(0xFF6A1B9A)
                      : const Color(0xFF006064),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFE082),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: isPlus
                    ? const Text(
                        '+',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      )
                    : const Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: Color(0xFF84FFFF),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSacrificedCostBar({
    required AppPalette palette,
    required LocalizationService loc,
    required Key containerKey,
  }) {
    final entries = widget.sacrificedCost.nonZeroEntries;
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      key: containerKey,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.summaryBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.amberBorder.withValues(
            alpha: palette.isDark ? 0.34 : 0.50,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            loc.t(
              'altar_sacrificed_orbs_label',
              fallback: 'Sacrificed Elemental Orbs',
            ),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: palette.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 5,
            children: [
              for (final entry in entries)
                Row(
                  key: ValueKey('altar_sacrifice_cost_${entry.key.orbKey}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElementalEnergySphere(
                      key: ValueKey(
                        'altar_sacrifice_orb_sphere_${entry.key.orbKey}',
                      ),
                      size: 16,
                      primaryColor: entry.key.elementalPrimaryColor,
                      secondaryColor: entry.key.elementalSecondaryColor,
                      isDark: palette.isDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AltarSacrificeDialog.formatExactQuantity(
                        entry.value,
                        loc,
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: palette.elementalText(entry.key),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// CustomPainter rendering the 3-stage sacred offering sequence directly over
/// `sacred_altar.webp`:
/// 1. Proportional 3D elemental orb piles settling onto the octagonal marble basin.
/// 2. Solemn cyan-gold altar rune glow + roaring holocaust flames & rising embers
///    that heat and dissolve the sacrificed orbs into ascending sparks.
/// 3. Descending radiant 8-pointed star & divine beam from the cathedral heavens.
class AltarSacrificePainter extends CustomPainter {
  final double progress;
  final List<SacrificeOrbCluster> clusters;

  const AltarSacrificePainter({
    required this.progress,
    required this.clusters,
  });

  int get totalVisualOrbs =>
      clusters.fold<int>(0, (sum, c) => sum + c.visualOrbCount);

  Rect _resolveImageRect(Size canvasSize) {
    final fitted = applyBoxFit(
      BoxFit.cover,
      AltarSacrificeDialog.altarImageIntrinsicSize,
      canvasSize,
    );
    final dst = fitted.destination;
    return Rect.fromLTWH(
      (canvasSize.width - dst.width) * 0.5,
      (canvasSize.height - dst.height) * 0.5,
      dst.width,
      dst.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final imageRect = _resolveImageRect(size);
    final sec = progress.clamp(0.0, 1.0) * 3.0;

    final basinCenter = Offset(
      imageRect.left + imageRect.width * 0.50,
      imageRect.top + imageRect.height * 0.525,
    );

    // 1. Solemn Prayer & Cyan-Gold Basin Rune Glow (0.0s -> 1.45s)
    if (sec < 1.55) {
      _paintBasinPrayerGlow(canvas, imageRect, basinCenter, sec);
    }

    // 2. Back Layer of Holocaust Flame Aura (0.20s -> 1.42s)
    if (sec >= 0.20 && sec < 1.45) {
      _paintHolocaustFlames(
        canvas: canvas,
        imageRect: imageRect,
        basinCenter: basinCenter,
        sec: sec,
        foregroundPass: false,
      );
    }

    // 3. Proportional Elemental Orb Piles Settling & Dissolving in Fire (0.0s -> 1.12s)
    if (sec < 1.14 && clusters.isNotEmpty) {
      _paintSacrificedOrbs(canvas, imageRect, sec);
    }

    // 4. Foreground Holocaust Flames, Rising Elemental Sparks & Embers (0.22s -> 1.50s)
    if (sec >= 0.22 && sec < 1.55) {
      _paintHolocaustFlames(
        canvas: canvas,
        imageRect: imageRect,
        basinCenter: basinCenter,
        sec: sec,
        foregroundPass: true,
      );
      _paintRisingEmbersAndSparks(canvas, imageRect, basinCenter, sec);
    }

    // 5. Phase 2: Descending Bright Star & Divine Sanctuary Beam (1.10s -> 2.00s)
    if (sec >= 1.08 && sec <= 2.05) {
      _paintDescendingDivineStar(canvas, imageRect, basinCenter, sec);
    }
  }

  void _paintBasinPrayerGlow(
    Canvas canvas,
    Rect imageRect,
    Offset basinCenter,
    double sec,
  ) {
    final fadeIn = (sec / 0.25).clamp(0.0, 1.0);
    final fadeOut = ((1.55 - sec) / 0.35).clamp(0.0, 1.0);
    final intensity = fadeIn * fadeOut;
    if (intensity <= 0.0) return;

    final rx = imageRect.width * 0.25;
    final ry = imageRect.height * 0.048;
    final oval = Rect.fromCenter(
      center: basinCenter,
      width: rx * 2.0,
      height: ry * 2.0,
    );

    // Warm sacred gold + cyan rune resonance across the octagonal marble basin
    canvas.save();
    canvas.translate(basinCenter.dx, basinCenter.dy);
    canvas.scale(1.0, ry / rx);
    final circleRect = Rect.fromCircle(center: Offset.zero, radius: rx);
    canvas.drawCircle(
      Offset.zero,
      rx,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF8E1).withValues(alpha: 0.56 * intensity),
            const Color(0xFFFFCA28).withValues(alpha: 0.38 * intensity),
            const Color(0xFF4DD0E1).withValues(alpha: 0.22 * intensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 0.78, 1.0],
        ).createShader(circleRect),
    );
    canvas.restore();

    // Subtle rim rune shimmer along front/back octagonal edges
    canvas.drawOval(
      oval.inflate(imageRect.width * 0.025),
      Paint()
        ..color = const Color(0xFF84FFFF).withValues(alpha: 0.26 * intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );
  }

  void _paintSacrificedOrbs(Canvas canvas, Rect imageRect, double sec) {
    // Flatten and sort back-to-front by Y / layerIndex so pyramid overlap is crisp.
    final allNodes = <SacrificeVisualOrbNode>[
      for (final cluster in clusters) ...cluster.orbs,
    ]..sort((a, b) {
        final cmpLayer = a.layerIndex.compareTo(b.layerIndex);
        if (cmpLayer != 0) return cmpLayer;
        return a.normalizedAltarPos.dy.compareTo(b.normalizedAltarPos.dy);
      });

    for (int i = 0; i < allNodes.length; i++) {
      final node = allNodes[i];
      final settleT = ((sec - node.stagger * 0.30) / 0.26).clamp(0.0, 1.0);
      if (settleT <= 0.0) continue;

      final settleCurve = Curves.easeOutBack.transform(settleT);
      final dropOffset = (1.0 - settleCurve) * (imageRect.height * 0.045);

      // Dissolve window: 0.44s -> 1.06s with per-orb stagger
      final burnStart = 0.42 + node.stagger * 0.42;
      final burnT = ((sec - burnStart) / 0.44).clamp(0.0, 1.0);
      if (burnT >= 1.0) continue;

      final dissolveScale = 1.0 - Curves.easeInBack.transform(burnT).clamp(0.0, 1.0);
      if (dissolveScale <= 0.04) continue;

      // Heat glow: orbs turn incandescent white-gold as holocaust fire consumes them
      final heat = ((sec - 0.30) / 0.55).clamp(0.0, 1.0);
      final riseDrift = burnT * burnT * (imageRect.height * 0.028);
      final shimmerX =
          heat * math.sin(sec * 28.0 + i * 1.7) * (imageRect.width * 0.0025);

      final center = Offset(
        imageRect.left + node.normalizedAltarPos.dx * imageRect.width + shimmerX,
        imageRect.top +
            node.normalizedAltarPos.dy * imageRect.height -
            dropOffset -
            riseDrift,
      );
      final radius =
          (node.normalizedRadius * imageRect.width * dissolveScale).clamp(
            1.2,
            40.0,
          );

      final primary = Color.lerp(
        node.move.elementalPrimaryColor,
        const Color(0xFFFFECB3),
        heat * 0.72,
      )!;
      final secondary = Color.lerp(
        node.move.elementalSecondaryColor,
        const Color(0xFFFF6F00),
        heat * 0.65,
      )!;
      final alpha = (settleT * (1.0 - burnT * 0.85)).clamp(0.0, 1.0);

      // Outer elemental/fire aura
      canvas.drawCircle(
        center,
        radius * (1.35 + heat * 0.35),
        Paint()
          ..color = primary.withValues(alpha: 0.46 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
      );

      // 3D sphere gradient body
      final sphereRect = Rect.fromCircle(center: center, radius: radius);
      final coreWhite = Color.lerp(primary, Colors.white, 0.78)!;
      final shadowEdge = Color.lerp(secondary, const Color(0xFF120B08), 0.52)!;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.28, -0.30),
            radius: 0.96,
            colors: [
              coreWhite.withValues(alpha: 0.98 * alpha),
              primary.withValues(alpha: 0.96 * alpha),
              shadowEdge.withValues(alpha: 0.94 * alpha),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(sphereRect),
      );

      // Specular highlight dot
      canvas.drawCircle(
        center + Offset(-radius * 0.30, -radius * 0.30),
        radius * 0.24,
        Paint()..color = Colors.white.withValues(alpha: 0.86 * alpha),
      );
    }
  }

  void _paintHolocaustFlames({
    required Canvas canvas,
    required Rect imageRect,
    required Offset basinCenter,
    required double sec,
    required bool foregroundPass,
  }) {
    // Flame envelope: ignites at 0.20s, peaks 0.55s..0.98s, subsides smoothly by 1.42s
    final ignite = ((sec - 0.20) / 0.34).clamp(0.0, 1.0);
    final subside = ((1.44 - sec) / 0.42).clamp(0.0, 1.0);
    final flamePower =
        Curves.easeOutCubic.transform(ignite) *
        Curves.easeInOutCubic.transform(subside);
    if (flamePower <= 0.01) return;

    final basinWidth = imageRect.width * 0.44;
    final maxFlameHeight = imageRect.height * (0.28 * flamePower + 0.04);

    if (!foregroundPass) {
      // Warm sanctuary firelight pillar illuminating the vaulted nave
      final glowRect = Rect.fromCenter(
        center: basinCenter - Offset(0, maxFlameHeight * 0.42),
        width: basinWidth * 1.45,
        height: maxFlameHeight * 1.55,
      );
      canvas.drawOval(
        glowRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFAB00).withValues(alpha: 0.46 * flamePower),
              const Color(0xFFFF3D00).withValues(alpha: 0.24 * flamePower),
              Colors.transparent,
            ],
            stops: const [0.0, 0.58, 1.0],
          ).createShader(glowRect),
      );
    }

    final int tongueCount = foregroundPass ? 9 : 7;
    for (int i = 0; i < tongueCount; i++) {
      final frac = tongueCount == 1 ? 0.5 : i / (tongueCount - 1);
      final centered = (frac - 0.5) * 2.0; // -1..1
      final archFactor = 1.0 - 0.42 * centered * centered;

      final baseX = basinCenter.dx + centered * (basinWidth * 0.44);
      final baseY = basinCenter.dy + imageRect.height * 0.010;

      final waveA = math.sin(sec * 11.5 + i * 1.35);
      final waveB = math.cos(sec * 16.0 + i * 2.10);

      final tongueHeight =
          maxFlameHeight *
          archFactor *
          (foregroundPass ? 0.84 : 1.02) *
          (0.86 + 0.16 * waveA);
      final tongueHalfW =
          basinWidth * (foregroundPass ? 0.085 : 0.115) * (0.88 + 0.12 * archFactor);

      final tipX = baseX + waveB * (imageRect.width * 0.026);
      final tipY = baseY - tongueHeight;

      final path = Path()
        ..moveTo(baseX - tongueHalfW, baseY)
        ..cubicTo(
          baseX - tongueHalfW * 1.15,
          baseY - tongueHeight * 0.36,
          tipX - tongueHalfW * 0.45 + waveA * 5.0,
          baseY - tongueHeight * 0.74,
          tipX,
          tipY,
        )
        ..cubicTo(
          tipX + tongueHalfW * 0.45 + waveA * 5.0,
          baseY - tongueHeight * 0.74,
          baseX + tongueHalfW * 1.15,
          baseY - tongueHeight * 0.36,
          baseX + tongueHalfW,
          baseY,
        )
        ..close();

      final shaderRect = Rect.fromLTRB(
        baseX - tongueHalfW * 1.4,
        tipY,
        baseX + tongueHalfW * 1.4,
        baseY,
      );

      final colors = foregroundPass
          ? [
              const Color(0xFFFFFDF5).withValues(alpha: 0.90 * flamePower),
              const Color(0xFFFFD54F).withValues(alpha: 0.82 * flamePower),
              const Color(0xFFFF6D00).withValues(alpha: 0.48 * flamePower),
              Colors.transparent,
            ]
          : [
              const Color(0xFFFFB300).withValues(alpha: 0.78 * flamePower),
              const Color(0xFFFF3D00).withValues(alpha: 0.68 * flamePower),
              const Color(0xFFD50000).withValues(alpha: 0.25 * flamePower),
              Colors.transparent,
            ];

      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: colors,
            stops: const [0.0, 0.38, 0.78, 1.0],
          ).createShader(shaderRect)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            foregroundPass ? 1.8 : 3.5,
          ),
      );
    }
  }

  void _paintRisingEmbersAndSparks(
    Canvas canvas,
    Rect imageRect,
    Offset basinCenter,
    double sec,
  ) {
    final activeColors = clusters.isNotEmpty
        ? [for (final c in clusters) c.move.elementalPrimaryColor]
        : const [Color(0xFFFFB300), Color(0xFFFF7043)];

    const int sparkCount = 34;
    for (int i = 0; i < sparkCount; i++) {
      final birth = 0.28 + (i % 12) * 0.055;
      final life = ((sec - birth) / 0.78).clamp(0.0, 1.0);
      if (life <= 0.0 || life >= 1.0) continue;

      final spreadSeed = ((i * 37) % 100) / 100.0 - 0.5; // -0.5..0.5
      final sway = math.sin(life * 6.2 + i) * (imageRect.width * 0.032);
      final x =
          basinCenter.dx + spreadSeed * (imageRect.width * 0.38) + sway;
      final y =
          basinCenter.dy -
          Curves.easeOutQuad.transform(life) * (imageRect.height * 0.36);

      final sparkAlpha =
          (math.sin(life * math.pi) * 0.95).clamp(0.0, 1.0);
      final elemColor = activeColors[i % activeColors.length];
      final sparkColor = Color.lerp(
        elemColor,
        const Color(0xFFFFECB3),
        0.55,
      )!;
      final radius = (1.5 + (i % 3) * 0.85) * (1.0 - life * 0.45);

      canvas.drawCircle(
        Offset(x, y),
        radius * 2.1,
        Paint()
          ..color = sparkColor.withValues(alpha: 0.38 * sparkAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6),
      );
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = Colors.white.withValues(alpha: 0.92 * sparkAlpha),
      );
    }
  }

  void _paintDescendingDivineStar(
    Canvas canvas,
    Rect imageRect,
    Offset basinCenter,
    double sec,
  ) {
    // Descends from cathedral ceiling (1.10s) to altar basin (1.60s), then expands (1.60s..2.00s)
    final descendT = ((sec - 1.10) / (1.60 - 1.10)).clamp(0.0, 1.0);
    final impactT = ((sec - 1.56) / (1.96 - 1.56)).clamp(0.0, 1.0);
    final beamVisibility = ((sec - 1.08) / 0.18).clamp(0.0, 1.0);

    final startY = imageRect.top - imageRect.height * 0.04;
    final targetY = basinCenter.dy - imageRect.height * 0.012;
    final starY =
        startY + (targetY - startY) * Curves.easeInOutCubic.transform(descendT);
    final starCenter = Offset(basinCenter.dx, starY);

    // 1. Divine Celestial Beam Pillar from Heaven to Star / Basin
    final beamHalfW =
        imageRect.width * (0.048 + 0.18 * Curves.easeInCubic.transform(impactT));
    final beamBottomY = math.max(starY + imageRect.height * 0.04, basinCenter.dy);
    final beamRect = Rect.fromLTRB(
      basinCenter.dx - beamHalfW * 2.0,
      imageRect.top,
      basinCenter.dx + beamHalfW * 2.0,
      beamBottomY,
    );
    canvas.drawRect(
      beamRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            const Color(0xFFFFE082).withValues(alpha: 0.34 * beamVisibility),
            const Color(0xFFFFFDF5).withValues(alpha: 0.78 * beamVisibility),
            const Color(0xFFFFE082).withValues(alpha: 0.34 * beamVisibility),
            Colors.transparent,
          ],
          stops: const [0.0, 0.28, 0.50, 0.72, 1.0],
        ).createShader(beamRect),
    );

    // 2. Luminous Comet Trail behind Descending Star
    if (descendT < 1.0) {
      final trailHeight = imageRect.height * 0.24 * descendT;
      final trailPath = Path()
        ..moveTo(starCenter.dx - imageRect.width * 0.022, starCenter.dy)
        ..lineTo(starCenter.dx, starCenter.dy - trailHeight)
        ..lineTo(starCenter.dx + imageRect.width * 0.022, starCenter.dy)
        ..close();
      final trailRect = Rect.fromLTRB(
        starCenter.dx - imageRect.width * 0.03,
        starCenter.dy - trailHeight,
        starCenter.dx + imageRect.width * 0.03,
        starCenter.dy,
      );
      canvas.drawPath(
        trailPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFFFFFDF5).withValues(alpha: 0.92),
              const Color(0xFFFFE082).withValues(alpha: 0.45),
              Colors.transparent,
            ],
          ).createShader(trailRect),
      );
    }

    // 3. Radiant Star Corona + 8-Pointed Starburst Rays
    final starRadius =
        imageRect.width *
        (0.058 + 0.26 * Curves.easeInExpo.transform(impactT));
    final coronaRect = Rect.fromCircle(
      center: starCenter,
      radius: starRadius * 2.2,
    );
    canvas.drawCircle(
      starCenter,
      starRadius * 2.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFDF5).withValues(alpha: 0.96),
            const Color(0xFFFFE082).withValues(alpha: 0.68),
            const Color(0xFFFFCA28).withValues(alpha: 0.18),
            Colors.transparent,
          ],
          stops: const [0.0, 0.36, 0.72, 1.0],
        ).createShader(coronaRect),
    );

    canvas.save();
    canvas.translate(starCenter.dx, starCenter.dy);
    canvas.rotate(sec * 0.45);

    // 4 Cardinal Long Rays + 4 Diagonal Rays
    for (int ray = 0; ray < 8; ray++) {
      final isCardinal = ray.isEven;
      final len = isCardinal ? starRadius * 2.35 : starRadius * 1.35;
      final halfThick = isCardinal ? starRadius * 0.16 : starRadius * 0.10;
      canvas.save();
      canvas.rotate(ray * (math.pi / 4.0));
      final rayPath = Path()
        ..moveTo(0, -len)
        ..lineTo(halfThick, 0)
        ..lineTo(0, len)
        ..lineTo(-halfThick, 0)
        ..close();
      canvas.drawPath(
        rayPath,
        Paint()
          ..color = (isCardinal
                  ? const Color(0xFFFFFDF5)
                  : const Color(0xFFFFE082))
              .withValues(alpha: isCardinal ? 0.95 : 0.80),
      );
      canvas.restore();
    }

    // Bright Star Core
    canvas.drawCircle(
      Offset.zero,
      starRadius * 0.34,
      Paint()..color = const Color(0xFFFFFDF5),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AltarSacrificePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.clusters != clusters;
  }
}

/// Subtle divine halo & starburst rays painted behind the revealed item emblem.
class _RevealHaloPainter extends CustomPainter {
  final double entranceProgress;
  final bool isDark;
  final bool isCosmicPlus;

  const _RevealHaloPainter({
    required this.entranceProgress,
    required this.isDark,
    required this.isCosmicPlus,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final maxR = math.min(size.width, size.height) * 0.5;
    final t = entranceProgress.clamp(0.0, 1.0);

    final glowColor = isCosmicPlus
        ? const Color(0xFF80D8FF)
        : const Color(0xFFFFD54F);
    final glowAlpha = (isDark ? 0.34 : 0.24) * t;

    canvas.drawCircle(
      center,
      maxR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glowColor.withValues(alpha: glowAlpha),
            const Color(0xFFFFE082).withValues(alpha: glowAlpha * 0.45),
            Colors.transparent,
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: maxR)),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    const int rays = 12;
    for (int i = 0; i < rays; i++) {
      final angle = i * (2 * math.pi / rays);
      final innerR = maxR * 0.68;
      final outerR = maxR * (i.isEven ? 0.98 : 0.86);
      canvas.drawLine(
        Offset(math.cos(angle) * innerR, math.sin(angle) * innerR),
        Offset(math.cos(angle) * outerR, math.sin(angle) * outerR),
        Paint()
          ..color = glowColor.withValues(
            alpha: (isDark ? 0.36 : 0.28) * t,
          )
          ..strokeWidth = i.isEven ? 2.0 : 1.3
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RevealHaloPainter oldDelegate) {
    return oldDelegate.entranceProgress != entranceProgress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isCosmicPlus != isCosmicPlus;
  }
}
