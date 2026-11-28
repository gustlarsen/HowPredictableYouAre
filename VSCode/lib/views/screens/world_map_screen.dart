import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../controllers/game_controller.dart';
import '../../services/audio_service.dart';
import '../../services/play_games_service.dart';
import '../../services/update_service.dart';
import '../../theme/app_theme.dart';
import '../dialogs/inventory_dialog.dart';
import '../dialogs/observatory_dialog.dart';
import '../dialogs/offline_offertory_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../dialogs/shop_dialog.dart';
import '../dialogs/royal_castle_dialog.dart';
import '../dialogs/week0_scream_warning_dialog.dart';
import '../dialogs/week10_archmage_warning_dialog.dart';
import '../widgets/metal_wizard_lair_icon.dart';
import '../widgets/royal_castle_icon.dart';
import '../widgets/rpg_backpack_icon.dart';
import '../widgets/sacred_temple_icon.dart';
import '../widgets/watch_tower_icon.dart';
import 'game_screen.dart';

/// Interactive 9:16 Kingdom World Map hub screen.
///
/// Serves as the primary campaign hub where the player chooses between:
/// - **Metal Wizard's Lair** (`x: 0.76, y: 0.15`): Launches the 100-round battle.
/// - **Watch Tower** (`x: 0.24, y: 0.17`): Opens the Watch Tower dialog.
/// - **Royal Castle** (`x: 0.30, y: 0.47`): Opens the King's Throne Room dialog.
/// - **Sacred Temple** (`x: 0.75, y: 0.75`): Opens the Altar of Offerings (Shop).
class WorldMapScreen extends StatefulWidget {
  /// Exact 9:16 aspect ratio of `assets/images/kingdom_map.jpeg`.
  static const double mapAspectRatio = 9.0 / 16.0;

  /// Normalized (0.0..1.0) landmark coordinates locked to the 9:16 map canvas.
  static const Offset metalWizardLairPos = Offset(0.76, 0.15);
  static const Offset telescopeTowerPos = Offset(0.24, 0.17);
  static const Offset royalCastlePos = Offset(0.30, 0.47);
  static const Offset sacredTemplePos = Offset(0.75, 0.75);

  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  GameController? _controller;
  bool _hasCheckedForUpdate = false;
  bool _isInventoryDialogOpen = false;
  bool _isWeek0ScreamDialogOpen = false;
  bool _isWeek10ArchmageDialogOpen = false;
  bool _isOfflineOffertoryDialogOpen = false;
  bool _isOpeningPendingWatchTower = false;
  bool _isLaunchingTempleSiege = false;
  bool _metricsRebuildScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<GameController>();
      if (!_hasCheckedForUpdate) {
        _hasCheckedForUpdate = true;
        unawaited(controller.checkForUpdate());
      }
      _checkPendingOpenWatchTower(context, controller);
      _checkOfflineOffertoryDialog(context, controller);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = context.read<GameController>();
    if (_controller != nextController) {
      _controller?.detachWorldMap();
      _controller = nextController;
      nextController.attachWorldMap();
      unawaited(nextController.audio.playTrack(BgmTrack.worldMap));
    }
    _syncPulseAnimation(nextController.animationsEnabled);
  }

  void _syncPulseAnimation(bool animationsEnabled) {
    if (animationsEnabled) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating || _pulseController.value != 0.0) {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller?.detachWorldMap();
    _controller?.cancelPendingTimers();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    final controller = _controller ?? context.read<GameController>();
    controller.onWorldMapLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkOfflineOffertoryDialog(context, controller);
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted || _metricsRebuildScheduled) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(() {});
      return;
    }
    _metricsRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metricsRebuildScheduled = false;
      if (mounted) {
        setState(() {});
      }
    });
  }


  void _checkQaBonusSnackBar(BuildContext context, GameController controller) {
    if (controller.pendingStoryChapter != null) return;
    if (controller.pendingQaBonusSnackBar != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final msg = controller.consumePendingQaBonusSnackBar();
        if (msg != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(msg),
                duration: const Duration(seconds: 2),
              ),
            );
        }
      });
    }
  }

  void _checkUpdateSnackBar(BuildContext context, GameController controller) {
    if (controller.pendingUpdateSnackBar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (controller.consumePendingUpdateSnackBar()) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                key: const ValueKey('update_ready_snackbar'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF16181D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Colors.amber.withValues(alpha: 0.65),
                    width: 1.2,
                  ),
                ),
                duration: const Duration(seconds: 10),
                content: const Row(
                  children: [
                    Icon(
                      Icons.system_update_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        UpdateService.updateReadyMessage,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
                action: SnackBarAction(
                  label: UpdateService.restartActionLabel,
                  textColor: Colors.amber,
                  onPressed: () {
                    unawaited(controller.completeFlexibleUpdate());
                  },
                ),
              ),
            );
        }
      });
    }
  }

  void _handleBackpackTap(BuildContext context, GameController controller) {
    controller.audio.playTapVibrate();
    final grantedQa = controller.registerBackpackQaTap();
    if (grantedQa && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(PlayGamesService.qaBonusSnackBarMessage),
            duration: Duration(seconds: 2),
          ),
        );
    }
    if (!_isInventoryDialogOpen) {
      _isInventoryDialogOpen = true;
      showDialog(
        context: context,
        builder: (_) => InventoryDialog(
          controller: controller,
          isInBattle: false,
        ),
      ).whenComplete(() {
        _isInventoryDialogOpen = false;
      });
    }
  }

  void _checkWeek0ScreamWarning(
    BuildContext context,
    GameController controller,
  ) {
    if (!controller.shouldShowWeek0ScreamWarning ||
        _isWeek0ScreamDialogOpen ||
        _isWeek10ArchmageDialogOpen) {
      return;
    }
    _isWeek0ScreamDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !context.mounted) {
        _isWeek0ScreamDialogOpen = false;
        return;
      }
      final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
      if (!isCurrent) {
        _isWeek0ScreamDialogOpen = false;
        return;
      }
      if (!controller.consumePendingWeek0ScreamWarning()) {
        _isWeek0ScreamDialogOpen = false;
        return;
      }
      final action = await Week0ScreamWarningDialog.show(
        context,
        controller: controller,
      );
      _isWeek0ScreamDialogOpen = false;
      if (action == Week0ScreamWarningAction.goToWatchTower &&
          mounted &&
          context.mounted) {
        _openObservatory(context, controller);
      }
    });
  }

  void _checkWeek10ArchmageWarning(
    BuildContext context,
    GameController controller,
  ) {
    if (!controller.shouldShowWeek10ArchmageWarning ||
        _isWeek0ScreamDialogOpen ||
        _isWeek10ArchmageDialogOpen) {
      return;
    }
    _isWeek10ArchmageDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !context.mounted) {
        _isWeek10ArchmageDialogOpen = false;
        return;
      }
      final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
      if (!isCurrent) {
        _isWeek10ArchmageDialogOpen = false;
        return;
      }
      if (!controller.consumePendingWeek10ArchmageWarning()) {
        _isWeek10ArchmageDialogOpen = false;
        return;
      }
      final action = await Week10ArchmageWarningDialog.show(
        context,
        controller: controller,
      );
      _isWeek10ArchmageDialogOpen = false;
      if (action == Week10ArchmageWarningAction.inspectWatchTower &&
          mounted &&
          context.mounted) {
        _openObservatory(context, controller);
      }
    });
  }

  void _checkTempleSiegeAutoLaunch(
    BuildContext context,
    GameController controller,
  ) {
    if (_isLaunchingTempleSiege) return;
    final shouldLaunch = controller.isTempleSiegeActive ||
        controller.currentWeek > GameController.maxCampaignWeeks;
    if (!shouldLaunch) return;

    _isLaunchingTempleSiege = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !context.mounted) {
        _isLaunchingTempleSiege = false;
        return;
      }
      final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
      if (!isCurrent) {
        _isLaunchingTempleSiege = false;
        return;
      }
      if (!controller.isTempleSiegeActive) {
        controller.activateTempleSiege();
      }
      try {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => const GameScreen(),
          ),
        );
        if (mounted) {
          unawaited(controller.audio.playTrack(BgmTrack.worldMap));
        }
      } finally {
        _isLaunchingTempleSiege = false;
      }
    });
  }

  void _checkPendingOpenWatchTower(
    BuildContext context,
    GameController controller,
  ) {
    if (!controller.shouldOpenWatchTower || _isOpeningPendingWatchTower) {
      return;
    }
    _isOpeningPendingWatchTower = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isOpeningPendingWatchTower = false;
      if (!mounted || !context.mounted) return;
      final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
      if (!isCurrent) return;
      if (!controller.consumePendingOpenWatchTower()) return;
      _openObservatory(context, controller);
    });
  }

  void _checkOfflineOffertoryDialog(
    BuildContext context,
    GameController controller,
  ) {
    if (!controller.shouldShowOfflineOffertoryDialog ||
        _isOfflineOffertoryDialogOpen ||
        _isOpeningPendingWatchTower ||
        _isLaunchingTempleSiege ||
        _isWeek0ScreamDialogOpen ||
        _isWeek10ArchmageDialogOpen ||
        _isInventoryDialogOpen ||
        controller.isTempleSiegeActive ||
        controller.currentWeek > GameController.maxCampaignWeeks ||
        controller.shouldOpenWatchTower ||
        controller.shouldShowWeek0ScreamWarning ||
        controller.shouldShowWeek10ArchmageWarning ||
        controller.pendingStoryChapter != null) {
      return;
    }
    _isOfflineOffertoryDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !context.mounted) {
        _isOfflineOffertoryDialogOpen = false;
        return;
      }
      final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
      if (!isCurrent) {
        _isOfflineOffertoryDialogOpen = false;
        return;
      }
      final offlineDuration = controller.pendingOfflineOffertoryDuration;
      if (!controller.shouldShowOfflineOffertoryDialog ||
          offlineDuration == null) {
        _isOfflineOffertoryDialogOpen = false;
        return;
      }
      try {
        await OfflineOffertoryDialog.show(
          context,
          controller: controller,
          offlineDuration: offlineDuration,
        );
      } finally {
        if (controller.shouldShowOfflineOffertoryDialog) {
          controller.dismissOfflineOffertoryPrompt();
        }
        _isOfflineOffertoryDialogOpen = false;
      }
    });
  }

  Future<void> _enterMetalWizardLair(
    BuildContext context,
    GameController controller,
  ) async {
    controller.audio.playTapVibrate();
    if (!controller.isTempleSiegeActive) {
      controller.startNewBattle();
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const GameScreen(),
      ),
    );
    unawaited(controller.audio.playTrack(BgmTrack.worldMap));
    if (context.mounted) {
      _checkWeek0ScreamWarning(context, controller);
      _checkWeek10ArchmageWarning(context, controller);
    }
  }

  void _openObservatory(BuildContext context, GameController controller) {
    controller.audio.playTapVibrate();
    showDialog(
      context: context,
      builder: (_) => ObservatoryDialog(controller: controller),
    );
  }

  void _openThroneRoom(BuildContext context, GameController controller) {
    controller.audio.playTapVibrate();
    showDialog(
      context: context,
      builder: (_) => RoyalCastleDialog(controller: controller),
    );
  }

  void _openSacredTemple(BuildContext context, GameController controller) {
    controller.audio.playTapVibrate();
    showDialog(
      context: context,
      builder: (_) => ShopDialog(controller: controller, fromTemple: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final loc = controller.localization;
    _syncPulseAnimation(controller.animationsEnabled);

    _checkTempleSiegeAutoLaunch(context, controller);
    _checkQaBonusSnackBar(context, controller);
    _checkUpdateSnackBar(context, controller);
    _checkPendingOpenWatchTower(context, controller);
    if (!controller.isTempleSiegeActive &&
        controller.currentWeek <= GameController.maxCampaignWeeks) {
      _checkWeek0ScreamWarning(context, controller);
      _checkWeek10ArchmageWarning(context, controller);
      _checkOfflineOffertoryDialog(context, controller);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: Stack(
        key: const ValueKey('world_map_screen'),
        children: [
          // 1. Atmospheric full-screen map backdrop (fills side wings on wide/tablet screens)
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/kingdom_map.jpeg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: const Color(0xFF101820)),
                ),
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),

          // 2. Locked 9:16 Map Canvas & Interactive Landmark Overlay
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mapHeight = constraints.maxHeight;
                final mapWidth = mapHeight * WorldMapScreen.mapAspectRatio;

                return Center(
                  child: OverflowBox(
                    minWidth: mapWidth,
                    maxWidth: mapWidth,
                    minHeight: mapHeight,
                    maxHeight: mapHeight,
                    child: AspectRatio(
                      key: const ValueKey('world_map_aspect_canvas'),
                      aspectRatio: WorldMapScreen.mapAspectRatio,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              'assets/images/kingdom_map.jpeg',
                              key: const ValueKey('world_map_background_image'),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: const Color(0xFF141E28)),
                            ),
                          ),

                          // 1. Metal Wizard's Lair (top-right dark steampunk castle)
                          _buildLandmarkPin(
                            key: const ValueKey('landmark_metal_wizard_lair'),
                            mapWidth: mapWidth,
                            mapHeight: mapHeight,
                            normalizedPos: WorldMapScreen.metalWizardLairPos,
                            iconWidget: const MetalWizardLairIcon(size: 25),
                            label: loc.t(
                              'map_landmark_wizard_lair',
                              fallback: "Metal Wizard's Lair",
                            ),
                            accentColor: const Color(0xFFFF5722),
                            phaseOffset: 0.0,
                            animationsEnabled: controller.animationsEnabled,
                            onTap: () =>
                                _enterMetalWizardLair(context, controller),
                          ),

                          // 2. Watch Tower (top-left cliff watchtower)
                          _buildLandmarkPin(
                            key: const ValueKey('landmark_telescope_tower'),
                            mapWidth: mapWidth,
                            mapHeight: mapHeight,
                            normalizedPos: WorldMapScreen.telescopeTowerPos,
                            iconWidget: const WatchTowerIcon(size: 25),
                            label: loc.t(
                              'map_landmark_telescope',
                              fallback: 'Watch Tower',
                            ),
                            accentColor: const Color(0xFF4FC3F7),
                            phaseOffset: 0.25,
                            animationsEnabled: controller.animationsEnabled,
                            showNotificationBadge:
                                controller.hasWatchTowerNotification,
                            notificationBadgeKey: const ValueKey(
                              'watch_tower_notification_badge',
                            ),
                            onTap: () => _openObservatory(context, controller),
                          ),

                          // 3. Royal Castle (center-left castle)
                          _buildLandmarkPin(
                            key: const ValueKey('landmark_royal_castle'),
                            mapWidth: mapWidth,
                            mapHeight: mapHeight,
                            normalizedPos: WorldMapScreen.royalCastlePos,
                            iconWidget: const RoyalCastleIcon(size: 24),
                            label: loc.t(
                              'map_landmark_royal_castle',
                              fallback: 'Royal Castle',
                            ),
                            accentColor: Colors.amber,
                            phaseOffset: 0.50,
                            animationsEnabled: controller.animationsEnabled,
                            showNotificationBadge:
                                controller.hasRoyalCastleNotification,
                            notificationBadgeKey: const ValueKey(
                              'royal_castle_notification_badge',
                            ),
                            onTap: () => _openThroneRoom(context, controller),
                          ),

                          // 4. Sacred Temple (bottom-right white & gold temple)
                          _buildLandmarkPin(
                            key: const ValueKey('landmark_sacred_temple'),
                            mapWidth: mapWidth,
                            mapHeight: mapHeight,
                            normalizedPos: WorldMapScreen.sacredTemplePos,
                            iconWidget: const SacredTempleIcon(size: 25),
                            label: loc.t(
                              'map_landmark_sacred_temple',
                              fallback: 'Sacred Temple',
                            ),
                            accentColor: const Color(0xFFFFD54F),
                            phaseOffset: 0.75,
                            animationsEnabled: controller.animationsEnabled,
                            showNotificationBadge:
                                controller.hasSacredTempleNotification,
                            notificationBadgeKey: const ValueKey(
                              'sacred_temple_notification_badge',
                            ),
                            onTap: () => _openSacredTemple(context, controller),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Bottom-Left HUD & Navigation Cluster + Bottom AdMob Banner inside SafeArea
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 12,
                        right: 12,
                        bottom: controller.shouldShowBannerAd ? 10 : 12,
                      ),
                      child: _buildBottomLeftHud(context, controller),
                    ),
                  ),
                  if (controller.shouldShowBannerAd)
                    Padding(
                      key: const ValueKey('bottom_banner_ad_container'),
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Center(
                        child: controller.adService.buildBannerWidget(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandmarkPin({
    required Key key,
    required double mapWidth,
    required double mapHeight,
    required Offset normalizedPos,
    IconData? icon,
    Widget? iconWidget,
    required String label,
    required Color accentColor,
    required double phaseOffset,
    required bool animationsEnabled,
    bool showNotificationBadge = false,
    Key? notificationBadgeKey,
    required VoidCallback onTap,
  }) {
    assert(icon != null || iconWidget != null);
    const double hitboxWidth = 148.0;
    const double hitboxHeight = 104.0;
    final left = normalizedPos.dx * mapWidth - hitboxWidth / 2;
    final top = normalizedPos.dy * mapHeight - hitboxHeight / 2;

    return Positioned(
      left: left,
      top: top,
      width: hitboxWidth,
      height: hitboxHeight,
      child: _LandmarkPinBadge(
        key: key,
        icon: icon,
        iconWidget: iconWidget,
        label: label,
        accentColor: accentColor,
        pulseAnimation: _pulseController,
        phaseOffset: phaseOffset,
        animationsEnabled: animationsEnabled,
        showNotificationBadge: showNotificationBadge,
        notificationBadgeKey: notificationBadgeKey,
        onTap: onTap,
      ),
    );
  }

  Widget _buildBottomLeftHud(BuildContext context, GameController controller) {
    final loc = controller.localization;
    final palette = AppPalette.of(context);
    final weekLabel = loc.t('map_week_label', fallback: 'Week');

    return Container(
      key: const ValueKey('world_map_bottom_left_hud'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.isDark
            ? const Color(0xFF14161D).withValues(alpha: 0.90)
            : palette.dialogSurface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: palette.amberBorder.withValues(
            alpha: palette.isDark ? 0.65 : 0.85,
          ),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.48),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weeks Counter Badge
          Container(
            key: const ValueKey('week_counter_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: palette.isDark
                  ? Colors.amber.withValues(alpha: 0.14)
                  : palette.rewardedAdCardSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: palette.amberBorder.withValues(alpha: 0.55),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: palette.amberIcon,
                ),
                const SizedBox(width: 6),
                Text(
                  '$weekLabel ${controller.currentWeek} / ${GameController.maxCampaignWeeks}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    letterSpacing: 0.3,
                    color: palette.amberText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Navigation & Utility Buttons Row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fixed-size Brown Leather Cleric's Backpack Button (preserves 7-tap QA shortcut)
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  key: const ValueKey('backpack_inventory_button'),
                  padding: EdgeInsets.zero,
                  iconSize: 28,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    maxWidth: 36,
                    minHeight: 36,
                    maxHeight: 36,
                  ),
                  tooltip: loc.t(
                    'inventory_title',
                    fallback: "Cleric's Backpack",
                  ),
                  onPressed: () => _handleBackpackTap(context, controller),
                  icon: const SizedBox(
                    width: 28,
                    height: 28,
                    child: RpgBackpackIcon(size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Compact Settings Button
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  key: const ValueKey('world_map_settings_button'),
                  padding: EdgeInsets.zero,
                  iconSize: 22,
                  color: palette.isDark ? Colors.amber.shade200 : palette.primaryText,
                  tooltip: 'Settings',
                  onPressed: () {
                    controller.audio.playTapVibrate();
                    showDialog(
                      context: context,
                      builder: (_) => SettingsDialog(controller: controller),
                    );
                  },
                  icon: const Icon(Icons.settings_outlined),
                ),
              ),

              // Gift Box Button when unlocked, enabled, and ready
              if (controller.shouldShowGiftBox) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    key: const ValueKey('gift_box_button'),
                    padding: EdgeInsets.zero,
                    tooltip: controller.giftTooltipMessage,
                    onPressed: () {
                      controller.claimGift();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(controller.giftClaimedMessage),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Text('🎁', style: TextStyle(fontSize: 21)),
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

class _LandmarkPinBadge extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final Color accentColor;
  final Animation<double> pulseAnimation;
  final double phaseOffset;
  final bool animationsEnabled;
  final bool showNotificationBadge;
  final Key? notificationBadgeKey;
  final VoidCallback onTap;

  const _LandmarkPinBadge({
    super.key,
    this.icon,
    this.iconWidget,
    required this.label,
    required this.accentColor,
    required this.pulseAnimation,
    required this.phaseOffset,
    required this.animationsEnabled,
    this.showNotificationBadge = false,
    this.notificationBadgeKey,
    required this.onTap,
  }) : assert(icon != null || iconWidget != null);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            final wave = animationsEnabled
                ? (0.5 +
                      0.5 *
                          math.sin(
                            (pulseAnimation.value + phaseOffset) * 2 * math.pi,
                          ))
                : 0.4;
            final floatDy = animationsEnabled ? (wave - 0.5) * 4.0 : 0.0;
            final glowAlpha = 0.25 + wave * 0.35;

            return Transform.translate(
              offset: Offset(0, floatDy),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pulsing RPG Emblem Marker
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF14161D).withValues(alpha: 0.88),
                          border: Border.all(
                            color: accentColor,
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: glowAlpha),
                              blurRadius: 10 + wave * 6,
                              spreadRadius: 1.5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: iconWidget ??
                              Icon(
                                icon,
                                size: 20,
                                color: accentColor,
                              ),
                        ),
                      ),
                      if (showNotificationBadge)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            key: notificationBadgeKey ??
                                const ValueKey(
                                  'royal_castle_notification_badge',
                                ),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFFD54F),
                              border: Border.all(
                                color: const Color(0xFF14161D),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(
                                    alpha: 0.45 + wave * 0.45,
                                  ),
                                  blurRadius: 6 + wave * 4,
                                  spreadRadius: 1.0,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                '!',
                                style: TextStyle(
                                  color: Color(0xFF231F1A),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10.5,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Floating Label Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14161D).withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.72),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
