import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../models/sacred_blessing.dart';
import '../../models/story_chapter.dart';
import '../../services/ad_service.dart';
import '../../services/audio_service.dart';
import '../../services/localization_service.dart';
import '../../services/play_games_service.dart';
import '../../services/update_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/score_header.dart';
import '../widgets/hints_bar.dart';
import '../widgets/versus_arena.dart';
import '../widgets/markov_matrix_view.dart';
import '../widgets/rpg_backpack_icon.dart';
import '../widgets/rpg_teleport_portal_icon.dart';
import '../widgets/adaptive_rewarded_ad_button.dart';
import '../widgets/elemental_energy_sphere.dart';
import '../widgets/elemental_symbol_icon.dart';
import '../dialogs/inventory_dialog.dart';
import '../dialogs/teleport_confirm_dialog.dart';
import '../dialogs/temple_moral_choice_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../dialogs/story_dialog.dart';
import '../dialogs/victory_cutscene_dialog.dart';
import '../dialogs/world_map_war_dialog.dart';

class GameScreen extends StatefulWidget {
  static const int orbSpawnDelayMs = VersusArena.clashTimeMs;
  static const int orbFlightDurationMs = 650;
  static const int backpackPulseDurationMs = 280;
  static const int orbTotalSequenceMs =
      orbSpawnDelayMs + orbFlightDurationMs + backpackPulseDurationMs;

  static Offset calculateOrbControlPoint(Offset startPos, Offset endPos) {
    return Offset(
      ui.lerpDouble(endPos.dx, startPos.dx, 0.15)!,
      ui.lerpDouble(startPos.dy, endPos.dy, 0.10)!,
    );
  }

  static Offset evaluateOrbBezier(
    Offset startPos,
    Offset controlPoint,
    Offset endPos,
    double t,
  ) {
    final oneMinusT = 1.0 - t;
    return Offset(
      oneMinusT * oneMinusT * startPos.dx +
          2 * oneMinusT * t * controlPoint.dx +
          t * t * endPos.dx,
      oneMinusT * oneMinusT * startPos.dy +
          2 * oneMinusT * t * controlPoint.dy +
          t * t * endPos.dy,
    );
  }

  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _isIntroDialogScheduled = false;
  bool _hasCheckedForUpdate = false;
  bool _isInventoryDialogOpen = false;
  bool _isDeathSequenceActive = false;
  bool _isDeathDialogOpen = false;
  bool _isKingdomFallDialogOpen = false;
  bool _isBossVictoryDialogOpen = false;
  bool _metricsRebuildScheduled = false;
  Timer? _deathDialogTimer;
  GameController? _controller;

  // Overcharged Staff Hold-to-Fire state
  Timer? _overchargedHoldStartTimer;
  Timer? _overchargedHoldRepeatTimer;
  String? _overchargedActiveTargetId;
  int? _overchargedActivePointer;
  bool _overchargedIsRapidFiring = false;
  final Set<String> _suppressedTapTargetIds = <String>{};
  late final AnimationController _overchargedChargeController;
  late final AnimationController _overchargedPulseController;

  final GlobalKey _rootStackKey = GlobalKey();
  final GlobalKey _backpackKey = GlobalKey();
  final GlobalKey _pcSlotKey = GlobalKey();
  final GlobalKey _clashCenterKey = GlobalKey();

  late final AnimationController _flyingOrbController;
  late final AnimationController _embersController;
  late final AnimationController _templeAtmosphereController;
  int _lastHandledOrbCollectionEventId = 0;
  int _lastHandledTurnCount = 0;
  HandMove? _activeFlyingOrbMove;
  HandMove? _lastAbsorbedOrbMove;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _flyingOrbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: GameScreen.orbTotalSequenceMs),
    );
    _embersController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    _templeAtmosphereController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _overchargedChargeController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: GameController.overchargedStaffHoldThresholdMs,
      ),
    );
    _overchargedPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasCheckedForUpdate) return;
      _hasCheckedForUpdate = true;
      unawaited(context.read<GameController>().checkForUpdate());
    });
  }

  void _syncAtmosphereAnimations(GameController controller) {
    final enabled = controller.animationsEnabled;
    final isTemple = controller.isSacredTempleArena;

    if (enabled && !isTemple) {
      if (!_embersController.isAnimating) {
        _embersController.repeat();
      }
    } else {
      if (_embersController.isAnimating || _embersController.value != 0.0) {
        _embersController.stop();
        _embersController.reset();
      }
    }

    if (enabled && isTemple) {
      if (!_templeAtmosphereController.isAnimating) {
        _templeAtmosphereController.repeat();
      }
    } else {
      if (_templeAtmosphereController.isAnimating ||
          _templeAtmosphereController.value != 0.0) {
        _templeAtmosphereController.stop();
        _templeAtmosphereController.reset();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = context.read<GameController>();
    if (_controller != nextController) {
      _controller = nextController;
      _lastHandledOrbCollectionEventId = nextController.orbCollectionEventId;
      _lastHandledTurnCount = nextController.turnCount;
      nextController.captureTurn0SnapshotOnBattleEntry();
      unawaited(nextController.audio.playTrack(BgmTrack.battle));
    }
    _syncAtmosphereAnimations(nextController);
  }

  @override
  void dispose() {
    if (_controller?.audio.currentTrack == BgmTrack.battle) {
      unawaited(_controller!.audio.playTrack(BgmTrack.worldMap));
    }
    _cancelOverchargedTimersOnly();
    _overchargedChargeController.dispose();
    _overchargedPulseController.dispose();
    _deathDialogTimer?.cancel();
    _deathDialogTimer = null;
    _flyingOrbController.dispose();
    _embersController.dispose();
    _templeAtmosphereController.dispose();
    _controller?.cancelPendingTimers();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _areBattleInputsLocked(GameController controller) {
    return controller.userHp <= 0 ||
        controller.computerHp <= 0 ||
        controller.isBossVictoryPending ||
        controller.totalRounds >= controller.playerMaxMana ||
        _isDeathSequenceActive ||
        _isBossVictoryDialogOpen;
  }

  bool _isOverchargedSafetyBrakeActive(GameController controller) {
    if (!mounted || !controller.isOverchargedStaffActive) return true;
    if (controller.userHp <= GameController.overchargedStaffCriticalHpLimit) {
      return true;
    }
    if (controller.computerHp <= 0 || controller.isBossVictoryPending) {
      return true;
    }
    if (controller.remainingMana <= 0 ||
        controller.totalRounds >= controller.playerMaxMana ||
        controller.isDeathAlertPending ||
        controller.is100RoundsAlertPending) {
      return true;
    }
    if (_isDeathSequenceActive ||
        _isDeathDialogOpen ||
        _isBossVictoryDialogOpen ||
        _isKingdomFallDialogOpen ||
        _isInventoryDialogOpen) {
      return true;
    }
    return false;
  }

  void _cancelOverchargedTimersOnly() {
    _overchargedHoldStartTimer?.cancel();
    _overchargedHoldStartTimer = null;
    _overchargedHoldRepeatTimer?.cancel();
    _overchargedHoldRepeatTimer = null;
  }

  void _stopOverchargedHold({
    bool notifyUi = true,
    int? onlyPointerId,
    String? clearSuppressedTargetId,
  }) {
    if (onlyPointerId != null && _overchargedActivePointer != onlyPointerId) {
      return;
    }
    _cancelOverchargedTimersOnly();
    final hadActive = _overchargedActiveTargetId != null ||
        _overchargedIsRapidFiring ||
        _overchargedActivePointer != null;
    final previousTargetId = _overchargedActiveTargetId;
    _overchargedActiveTargetId = null;
    _overchargedActivePointer = null;
    _overchargedIsRapidFiring = false;
    _overchargedChargeController.stop();
    _overchargedChargeController.reset();
    _overchargedPulseController.stop();
    _overchargedPulseController.reset();

    final targetToClear = clearSuppressedTargetId ?? previousTargetId;
    if (targetToClear != null && _suppressedTapTargetIds.contains(targetToClear)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _suppressedTapTargetIds.remove(targetToClear);
      });
    }

    if (notifyUi && hadActive && mounted) {
      setState(() {});
    }
  }

  bool _consumeSuppressedTap(String targetId) {
    return _suppressedTapTargetIds.remove(targetId);
  }

  void _startOverchargedHold({
    required String targetId,
    required int pointerId,
    required GameController controller,
    required VoidCallback onFireSingle,
    required VoidCallback onFireRapid,
  }) {
    if (!controller.isOverchargedStaffActive) return;
    final isRouteCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isRouteCurrent || _areBattleInputsLocked(controller)) return;

    _stopOverchargedHold(notifyUi: false);
    _overchargedActivePointer = pointerId;
    _suppressedTapTargetIds.add(targetId);

    // Quick Tap / Initial Press: execute 1 single move immediately with zero delay
    onFireSingle();

    // Auto-stop safety brake: if critical HP (<= 5), victory, defeat, or 0 mana, do not charge rapid-fire
    if (_isOverchargedSafetyBrakeActive(controller)) {
      _overchargedActivePointer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _suppressedTapTargetIds.remove(targetId);
      });
      if (mounted) setState(() {});
      return;
    }

    _overchargedActiveTargetId = targetId;
    _overchargedIsRapidFiring = false;
    _overchargedChargeController.stop();
    if (controller.animationsEnabled) {
      _overchargedChargeController.forward(from: 0.0);
    } else {
      _overchargedChargeController.value = 1.0;
    }
    if (mounted) {
      setState(() {});
    }

    _overchargedHoldStartTimer = Timer(
      const Duration(milliseconds: GameController.overchargedStaffHoldThresholdMs),
      () {
        if (!mounted || _overchargedActiveTargetId != targetId) return;
        final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
        if (!routeCurrent || _isOverchargedSafetyBrakeActive(controller)) {
          _stopOverchargedHold();
          return;
        }

        _overchargedIsRapidFiring = true;
        if (controller.animationsEnabled && !_overchargedPulseController.isAnimating) {
          _overchargedPulseController.repeat(reverse: true);
        }
        if (mounted) {
          setState(() {});
        }

        onFireRapid();
        if (_isOverchargedSafetyBrakeActive(controller)) {
          _stopOverchargedHold();
          return;
        }

        _overchargedHoldRepeatTimer = Timer.periodic(
          controller.overchargedStaffInterval,
          (_) {
            if (!mounted || _overchargedActiveTargetId != targetId) {
              _stopOverchargedHold();
              return;
            }
            final stillCurrent = ModalRoute.of(context)?.isCurrent ?? true;
            if (!stillCurrent || _isOverchargedSafetyBrakeActive(controller)) {
              _stopOverchargedHold();
              return;
            }
            onFireRapid();
            if (_isOverchargedSafetyBrakeActive(controller)) {
              _stopOverchargedHold();
            }
          },
        );
      },
    );
  }

  void _checkFlyingOrbVfx(GameController controller) {
    final turnChanged = controller.turnCount != _lastHandledTurnCount;
    _lastHandledTurnCount = controller.turnCount;

    if (controller.orbCollectionEventId == _lastHandledOrbCollectionEventId) {
      if (turnChanged) {
        _flyingOrbController.stop();
        _flyingOrbController.reset();
      }
      return;
    }
    _lastHandledOrbCollectionEventId = controller.orbCollectionEventId;
    final collectedMove = controller.lastCollectedOrbMove;
    if (collectedMove == null) return;

    _activeFlyingOrbMove = collectedMove;
    _lastAbsorbedOrbMove = collectedMove;
    if (controller.animationsEnabled) {
      _flyingOrbController.forward(from: 0.0);
    } else {
      _flyingOrbController.stop();
      _flyingOrbController.reset();
    }
  }

  void _handleBackpackTap(BuildContext context, GameController controller) {
    _stopOverchargedHold();
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
        builder: (_) => InventoryDialog(controller: controller),
      ).whenComplete(() {
        _isInventoryDialogOpen = false;
      });
    }
  }

  Future<void> _handleTeleportTap(
    BuildContext context,
    GameController controller,
  ) async {
    _stopOverchargedHold();
    controller.audio.playTapVibrate();
    if (controller.userHp <= 0 || _isDeathSequenceActive) return;

    final isTempleMaster = controller.isTempleMasterBoss;
    final isBabyMage = controller.isBabyMageBoss;

    if (isTempleMaster || isBabyMage || controller.confirmBattleTeleport) {
      final confirmed = await TeleportConfirmDialog.show(
        context,
        controller: controller,
      );
      if (!confirmed || !context.mounted) return;
    }

    if (isTempleMaster) {
      await controller.acceptSacredSacrifice();
      if (!context.mounted) return;
      await VictoryCutsceneDialog.show(
        context,
        type: VictoryCutsceneType.sacredSacrifice,
        controller: controller,
      );
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    if (isBabyMage) {
      await controller.triggerDeserterEnding();
      if (!context.mounted) return;
      await VictoryCutsceneDialog.show(
        context,
        type: VictoryCutsceneType.theDeserter,
        controller: controller,
      );
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    _handleExitViaWeekProgression(context, controller);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state != AppLifecycleState.resumed) {
      _stopOverchargedHold();
    }
  }

  void _checkIntroStory(BuildContext context, GameController controller) {
    if (controller.pendingStoryChapter != StoryChapter.intro) {
      _isIntroDialogScheduled = false;
      return;
    }
    if (!_isIntroDialogScheduled && !controller.hasSeenStoryIntro) {
      _isIntroDialogScheduled = true;
      _stopOverchargedHold(notifyUi: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final introChapter = controller.consumePendingStory(StoryChapter.intro);
        if (introChapter != null) {
          StoryDialog.show(
            context,
            chapter: introChapter,
            controller: controller,
          );
        }
      });
    }
  }

  void _handleExitViaWeekProgression(
    BuildContext context,
    GameController controller,
  ) {
    if (controller.willNextWeekExceedLimit) {
      _triggerWeek40KingdomFall(context, controller);
      return;
    }
    controller.completeBattleWeek();
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  /// Modular handler for campaign week > 40 (Week 41 Siege / Ending 2: Invasion) defeat events.
  /// Advances the calendar to Week 41 (where the Cleric's Sacred Capital is
  /// completely besieged on all sides), allows inspecting the Week 41 World Map
  /// state, and triggers Ending 2 (Invasion) via [applyPermadeathReset].
  Future<void> _triggerWeek40KingdomFall(
    BuildContext context,
    GameController controller,
  ) async {
    if (_isKingdomFallDialogOpen || !mounted) return;
    _isKingdomFallDialogOpen = true;
    controller.enterSiegeInvasionWeek();
    controller.audio.playDefeat();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isResetting = false;
        return StatefulBuilder(
          builder: (innerCtx, setDialogState) {
            final loc = controller.localization;
            final palette = AppPalette.of(innerCtx);
            return PopScope(
              canPop: false,
              child: AlertDialog(
                key: const ValueKey('week40_kingdom_fall_dialog'),
                backgroundColor: palette.isDark
                    ? const Color(0xFF1A1014)
                    : palette.dialogSurface,
                surfaceTintColor:
                    palette.isDark ? null : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Colors.redAccent.withValues(alpha: 0.65),
                    width: 1.5,
                  ),
                ),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Text(
                        loc.t(
                          'kingdom_fall_badge',
                          fallback: 'WEEK 40 EXPIRED',
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${loc.t('map_week_label', fallback: 'Week')} ${GameController.siegeInvasionWeek} — ${loc.t('world_map_status_besieged', fallback: 'Besieged — Week 41')}',
                      key: const ValueKey('week41_siege_subtitle_badge'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: palette.isDark
                            ? const Color(0xFFFFAB40)
                            : const Color(0xFFB84A00),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('🏰🔥', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 6),
                    Text(
                      loc.t(
                        'kingdom_fall_title',
                        fallback: 'The Kingdom Has Fallen',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                        color: palette.isDark
                            ? Colors.red.shade200
                            : const Color(0xFF8E1B1B),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc.t(
                        'kingdom_fall_body',
                        fallback:
                            'Time has run out. The Metal Wizard has taken over all neighboring kingdoms and destroyed the Cleric\'s kingdom!',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: palette.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('week41_inspect_world_map_button'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.isDark
                            ? const Color(0xFFF5C22B)
                            : const Color(0xFF8A5A00),
                        side: BorderSide(
                          color: (palette.isDark
                                  ? const Color(0xFFF5C22B)
                                  : const Color(0xFFC8961E))
                              .withValues(alpha: 0.75),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        controller.audio.playTapVibrate();
                        showDialog<void>(
                          context: innerCtx,
                          builder: (_) => WorldMapWarDialog(
                            controller: controller,
                            initialWeek: GameController.siegeInvasionWeek,
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_outlined, size: 17),
                      label: Text(
                        loc.t('observatory_world_map_btn', fallback: 'World Map'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const ValueKey(
                        'week40_kingdom_fall_confirm_button',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB71C1C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isResetting
                          ? null
                          : () async {
                              setDialogState(() => isResetting = true);
                              await controller.applyPermadeathReset(
                                cause: PermadeathCause.deadlineExceeded,
                              );
                              _isKingdomFallDialogOpen = false;
                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop();
                              }
                              if (context.mounted &&
                                  Navigator.of(context).canPop()) {
                                Navigator.of(context).pop(true);
                              }
                            },
                      child: Text(
                        loc.t(
                          'kingdom_fall_confirm_btn',
                          fallback: 'Return to Week 0',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    _isKingdomFallDialogOpen = false;
  }

  void _checkDeathAlert(BuildContext context, GameController controller) {
    if (!controller.isDeathAlertPending ||
        _isDeathSequenceActive ||
        _isDeathDialogOpen) {
      return;
    }
    controller.isDeathAlertPending = false;
    _isDeathSequenceActive = true;

    if (!controller.animationsEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDeathDialogOpen) return;
        _showYouDiedDialog(context, controller);
      });
      return;
    }

    _deathDialogTimer?.cancel();
    _deathDialogTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted || _isDeathDialogOpen) return;
      _showYouDiedDialog(context, controller);
    });
  }

  Future<void> _showYouDiedDialog(
    BuildContext context,
    GameController controller,
  ) async {
    if (_isDeathDialogOpen || !mounted) return;
    _isDeathDialogOpen = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isProcessing = false;
        return StatefulBuilder(
          builder: (innerCtx, setDialogState) {
            return AnimatedBuilder(
              animation: controller,
              builder: (animCtx, _) {
                final loc = controller.localization;
                final palette = AppPalette.of(animCtx);
                final canWatchReviveAd = controller.isReviveAdReady;

                return PopScope(
                  canPop: false,
                  child: AlertDialog(
                    key: const ValueKey('death_dialog'),
                    backgroundColor: palette.isDark
                        ? const Color(0xFF191116)
                        : palette.dialogSurface,
                    surfaceTintColor:
                        palette.isDark ? null : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: Colors.redAccent.withValues(alpha: 0.65),
                        width: 1.5,
                      ),
                    ),
                    title: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💀', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 6),
                        Text(
                          loc.t('death_dialog_title', fallback: 'You Died'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: palette.isDark
                                ? Colors.red.shade200
                                : const Color(0xFF8E1B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loc.t(
                            'death_dialog_subtitle',
                            fallback: 'The Cleric Has Fallen',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    content: Text(
                      loc.t(
                        'death_dialog_body',
                        fallback:
                            'Your HP reached 0. Watch a sacred vision to revive, keep all Elemental Orbs earned, and retreat to the map—or accept death and start over at Week 0.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: palette.secondaryText,
                      ),
                    ),
                    actionsAlignment: MainAxisAlignment.center,
                    actions: [
                      SizedBox(
                        width: double.infinity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (canWatchReviveAd) ...[
                              ElevatedButton.icon(
                                key: const ValueKey('death_revive_ad_button'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: palette.isDark
                                      ? Colors.amber.shade700
                                      : Colors.amber.shade600,
                                  foregroundColor: const Color(0xFF1F180D),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: isProcessing
                                    ? null
                                    : () async {
                                        setDialogState(
                                            () => isProcessing = true);
                                        final revived = await controller
                                            .watchReviveRewardedAd();
                                        if (!mounted) return;
                                        if (revived) {
                                          _isDeathDialogOpen = false;
                                          _isDeathSequenceActive = false;
                                          if (dialogCtx.mounted) {
                                            Navigator.of(dialogCtx).pop();
                                          }
                                          if (context.mounted &&
                                              Navigator.of(context).canPop()) {
                                            Navigator.of(context).pop(false);
                                          }
                                        } else if (dialogCtx.mounted) {
                                          setDialogState(
                                              () => isProcessing = false);
                                        }
                                      },
                                icon: const Icon(
                                  Icons.play_circle_fill_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  loc.t(
                                    'death_revive_ad_btn',
                                    fallback:
                                        'Watch Ad to Revive & Retreat to Map',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            OutlinedButton(
                              key: const ValueKey('death_accept_button'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: BorderSide(
                                  color:
                                      Colors.redAccent.withValues(alpha: 0.6),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: isProcessing
                                  ? null
                                  : () async {
                                      setDialogState(() => isProcessing = true);
                                      final wasTempleMaster =
                                          controller.isTempleMasterBoss;
                                      await controller.applyPermadeathReset(
                                        cause: wasTempleMaster
                                            ? PermadeathCause.sacredSacrifice
                                            : PermadeathCause.battleDefeat,
                                      );
                                      _isDeathDialogOpen = false;
                                      _isDeathSequenceActive = false;
                                      if (dialogCtx.mounted) {
                                        Navigator.of(dialogCtx).pop();
                                      }
                                      if (wasTempleMaster && context.mounted) {
                                        await VictoryCutsceneDialog.show(
                                          context,
                                          type: VictoryCutsceneType
                                              .sacredSacrifice,
                                          controller: controller,
                                        );
                                      }
                                      if (context.mounted &&
                                          Navigator.of(context).canPop()) {
                                        Navigator.of(context).pop(true);
                                      }
                                    },
                              child: Text(
                                loc.t(
                                  'death_accept_btn',
                                  fallback: 'Accept Death',
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
    _isDeathDialogOpen = false;
  }

  void _check100RoundAlert(BuildContext context, GameController controller) {
    if (controller.is100RoundsAlertPending &&
        controller.userHp > 0 &&
        !_isDeathSequenceActive &&
        !_isDeathDialogOpen) {
      controller.is100RoundsAlertPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || controller.userHp <= 0) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            final loc = controller.localization;
            final tier = controller.evaluationTier;
            final pct = controller.percentPredict;

            String alertTitle;
            String alertSubtitle;
            String emoji;

            if (pct == 100) {
              alertTitle = loc.t('string70', fallback: 'You Won!!!');
              alertSubtitle = loc.t('string71', fallback: 'You are the Best Predictor Ever!!!');
              emoji = '👑';
            } else if (pct > 50) {
              alertTitle = loc.t('string72', fallback: 'Not so Bad!!!');
              alertSubtitle = loc.t('string73', fallback: 'Now try to achieve 100%');
              emoji = '🙂';
            } else {
              alertTitle = loc.t('string74', fallback: 'You Lose!!!');
              alertSubtitle = loc.t('string75', fallback: 'Try harder next time...');
              emoji = '🙁';
            }

            return Builder(
              builder: (dialogCtx) {
                final palette = AppPalette.of(dialogCtx);
                return PopScope(
                  canPop: false,
                  child: AlertDialog(
                    backgroundColor:
                        palette.isDark ? null : palette.dialogSurface,
                    surfaceTintColor:
                        palette.isDark ? null : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Row(
                      children: [
                        Text(
                          emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            alertTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: palette.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alertSubtitle,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: palette.primaryText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${loc.t('string2', fallback: 'You are:')} '
                          '${loc.t(tier.key, fallback: tier.fallbackDescription)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: palette.amberText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI Predictability Score: ${pct.toStringAsFixed(1)}%\n'
                          'Your Wins: ${controller.userScore} | PC Wins: ${controller.pcScore}',
                          style: TextStyle(
                            height: 1.4,
                            color: palette.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: palette.rewardedAdCardSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: palette.rewardedAdCardBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 15,
                                color: palette.amberIcon,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  loc.t(
                                    'battle_week_advanced',
                                    fallback:
                                        '+1 Week Passed — Returning to the Kingdom Map',
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: palette.amberText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      ElevatedButton(
                        key: const ValueKey('battle_return_to_map_button'),
                        style: palette.isDark
                            ? null
                            : ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: const Color(0xFF231F1A),
                              ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _handleExitViaWeekProgression(context, controller);
                        },
                        child: Text(
                          loc.t('map_return_to_map', fallback: 'Return to Map'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      });
    }
  }

  Widget _buildSacredBlessingPill(
    BuildContext context,
    GameController controller,
  ) {
    final loc = controller.localization;
    final palette = AppPalette.of(context);
    final SacredBlessing? blessing;
    final String label;

    if (controller.isVitalityBlessingActive) {
      blessing = SacredBlessing.vitality;
      label = loc
          .t(
            'temple_blessing_battle_vitality',
            fallback: 'Vitality: +{hp} Temp HP',
          )
          .replaceAll('{hp}', '${controller.battleBonusTempHp}');
    } else if (controller.isClairvoyanceActive) {
      blessing = SacredBlessing.clairvoyance;
      final predictedMove = controller.crystalBallMoves
          .map(
            (m) => m.displayLabel(
              elemental: controller.isElementalMode,
              localization: loc,
            ),
          )
          .join(' + ');
      label = loc
          .t(
            'temple_blessing_battle_clairvoyance',
            fallback: 'Clairvoyance ({left}/3): {move}',
          )
          .replaceAll('{left}', '${controller.clairvoyanceMovesRemaining}')
          .replaceAll('{move}', predictedMove);
    } else if (controller.isHarvestBlessingActive) {
      blessing = SacredBlessing.harvest;
      label = loc.t(
        'temple_blessing_battle_harvest',
        fallback: 'Harvest: 2x Orbs',
      );
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        key: ValueKey('battle_sacred_blessing_pill_${blessing.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: palette.isDark
              ? blessing.accentColor.withValues(alpha: 0.16)
              : blessing.accentColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: blessing.accentColor.withValues(alpha: 0.72),
            width: 1.1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(blessing.icon, size: 13, color: blessing.accentColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: palette.isDark ? Colors.white : palette.primaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkBossVictoryAlert(BuildContext context, GameController controller) {
    if (!controller.isBossVictoryPending ||
        _isBossVictoryDialogOpen ||
        _isDeathSequenceActive ||
        _isDeathDialogOpen) {
      return;
    }
    _isBossVictoryDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isBossVictoryDialogOpen = false;
        return;
      }
      unawaited(_showBossVictoryModal(controller));
    });
  }

  Future<void> _showBossVictoryModal(GameController controller) async {
    final loc = controller.localization;
    final defeatedStage =
        controller.pendingBossVictoryStage ?? controller.enemyStage;
    final week = controller.pendingBossVictoryWeek ?? controller.currentWeek;

    final bool isStage1ToMetalWizard =
        defeatedStage == 1 && week < GameController.phase2StartWeek;
    final bool isStage1ToArchmage =
        defeatedStage == 1 && week >= GameController.phase2StartWeek;
    final bool isStage2Defeat = defeatedStage == 2;
    final bool isSecretWeek1 = defeatedStage == 3 && week == 0;
    final bool isStage3ToTemple = defeatedStage == 3 && week >= 1;
    final bool isStage5ToBabyMage = defeatedStage == 5;
    final bool isStage4Defeat = defeatedStage == 4;

    // Post-Week-0 Metal Wizard defeat -> Sacred Temple Sanctuary Moral Choice Cutscene
    if (isStage3ToTemple) {
      final choice = await TempleMoralChoiceDialog.show(
        context,
        controller: controller,
      );
      if (!mounted) {
        _isBossVictoryDialogOpen = false;
        return;
      }
      if (choice == TempleMoralChoice.sacrificePrincess) {
        await controller.acceptSacredSacrifice();
        if (!mounted) {
          _isBossVictoryDialogOpen = false;
          return;
        }
        await VictoryCutsceneDialog.show(
          context,
          type: VictoryCutsceneType.sacredSacrifice,
          controller: controller,
        );
        _isBossVictoryDialogOpen = false;
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
        return;
      }
      // Refuse & Protect Her -> Advance to Stage 5 Temple High Master (350 HP)
      controller.advanceAfterBossVictory();
      _isBossVictoryDialogOpen = false;
      return;
    }

    late final String emoji;
    late final Color accent;
    late final String title;
    late final String subtitle;
    late final String body;
    late final String buttonLabel;

    if (isStage1ToMetalWizard) {
      emoji = '⚔️🧙';
      accent = const Color(0xFF90A4AE);
      title = loc.t(
        'boss_victory_p1_title',
        fallback: 'Guardian Robot Destroyed!',
      );
      subtitle = loc.t(
        'boss_victory_s1_to_s3_subtitle',
        fallback: 'The Metal Wizard Enters Battle!',
      );
      body = loc.t(
        'boss_victory_s1_to_s3_body',
        fallback:
            'The Guardian Robot is shattered! Before any backup construct is ready, the Metal Wizard (300 HP) himself steps onto the battlefield wielding Metal and Earth magic behind his Anti-Metal Shield.',
      );
      buttonLabel = loc.t(
        'boss_victory_face_metal_wizard_btn',
        fallback: 'Face Metal Wizard',
      );
    } else if (isStage1ToArchmage) {
      emoji = '🔮🤖';
      accent = const Color(0xFFAB47BC);
      title = loc.t(
        'boss_victory_p1_title',
        fallback: 'Guardian Robot Destroyed!',
      );
      subtitle = loc.t(
        'boss_victory_p2_spawn_subtitle',
        fallback: 'Stage 2: Robot Archmage Approaches!',
      );
      body = loc.t(
        'boss_victory_p2_spawn_body',
        fallback:
            'A superior construct steps forward: Robot Archmage (200 HP, 5 elements, 1-step short-term memory)! Bestiary & Markov Recalibrator shop item unlocked.',
      );
      buttonLabel = loc.t(
        'boss_victory_face_archmage_btn',
        fallback: 'Challenge Robot Archmage',
      );
    } else if (isStage2Defeat) {
      emoji = '⚔️🧙';
      accent = const Color(0xFF90A4AE);
      title = loc.t(
        'boss_victory_p2_defeated_title',
        fallback: 'Robot Archmage Destroyed!',
      );
      subtitle = loc.t(
        'boss_victory_s2_to_s3_subtitle',
        fallback: 'Stage 3: The Metal Wizard Himself!',
      );
      body = loc.t(
        'boss_victory_s2_to_s3_body',
        fallback:
            'The Robot Archmage is destroyed! Now the Metal Wizard (300 HP) steps onto the battlefield himself, wielding Metal and Earth behind his Anti-Metal Shield.',
      );
      buttonLabel = loc.t(
        'boss_victory_face_metal_wizard_btn',
        fallback: 'Face Metal Wizard',
      );
    } else if (isSecretWeek1) {
      emoji = '👑';
      accent = const Color(0xFF00E5FF);
      title = loc.t(
        'boss_victory_s3_defeated_title',
        fallback: 'Metal Wizard Defeated!',
      );
      subtitle = loc.t(
        'boss_victory_secret_w1_subtitle',
        fallback: 'Week 0 Lightning Victory!',
      );
      body = loc.t(
        'boss_victory_secret_w1_body',
        fallback:
            'You defeated both the Guardian Robot and the Metal Wizard in Week 0 before the Archmage or Baby Mage Robot could ever be created! The Princess is rescued untouched.',
      );
      buttonLabel = loc.t(
        'boss_victory_watch_cutscene_btn',
        fallback: 'Watch Ending Cutscene',
      );
    } else if (isStage5ToBabyMage) {
      emoji = '⚡🤖';
      accent = const Color(0xFFFF7043);
      title = loc.t(
        'boss_victory_s5_defeated_title',
        fallback: 'Temple High Master Defeated!',
      );
      subtitle = loc.t(
        'boss_victory_s5_to_s4_subtitle',
        fallback: 'Sanctuary Altar Restores HP & Mana — Baby Mage Robot Awakens!',
      );
      body = loc.t(
        'boss_victory_s5_to_s4_body',
        fallback:
            'As the Temple High Master falls to his knees, the Sacred Temple altar restores your HP and Mana Pool to 100%! Suddenly, the dark seal inside the Princess shatters and the Baby Mage Robot (400 HP, Dual Harmonic Spells & π Core) bursts forth!',
      );
      buttonLabel = loc.t(
        'boss_victory_face_baby_mage_btn',
        fallback: 'Face Baby Mage Robot',
      );
    } else {
      emoji = '🏆';
      accent = const Color(0xFFFFCA28);
      title = loc.t(
        'boss_victory_p3_defeated_title',
        fallback: 'Baby Mage Robot Destroyed!',
      );
      subtitle = loc.t(
        'boss_victory_p3_defeated_subtitle',
        fallback: "Sanctuary Victory — The Princess is Saved!",
      );
      body = loc.t(
        'boss_victory_p3_defeated_body',
        fallback:
            "The Baby Mage Robot has been destroyed inside the Sacred Temple and the Princess is freed from the curse! Sanctuary Victory Ending unlocked.",
      );
      buttonLabel = loc.t(
        'boss_victory_watch_cutscene_btn',
        fallback: 'Watch Ending Cutscene',
      );
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final palette = AppPalette.of(dialogCtx);
        return PopScope(
          canPop: false,
          child: AlertDialog(
            key: const ValueKey('boss_victory_modal'),
            backgroundColor: palette.dialogSurface,
            surfaceTintColor: palette.isDark ? null : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: accent.withValues(alpha: 0.78),
                width: 1.8,
              ),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                    color: palette.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: palette.isDark ? accent : palette.amberText,
                  ),
                ),
              ],
            ),
            content: Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: palette.secondaryText,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const ValueKey('boss_victory_confirm_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: const Color(0xFF12151E),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    controller.audio.playTapVibrate();
                    Navigator.of(dialogCtx).pop();
                  },
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) {
      _isBossVictoryDialogOpen = false;
      return;
    }

    if (isSecretWeek1) {
      await VictoryCutsceneDialog.show(
        context,
        type: VictoryCutsceneType.secretWeek1,
        controller: controller,
      );
      if (!mounted) {
        _isBossVictoryDialogOpen = false;
        return;
      }
      controller.advanceAfterBossVictory();
      _isBossVictoryDialogOpen = false;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    if (isStage4Defeat) {
      await VictoryCutsceneDialog.show(
        context,
        type: VictoryCutsceneType.standardVictory,
        controller: controller,
      );
      if (!mounted) {
        _isBossVictoryDialogOpen = false;
        return;
      }
      controller.advanceAfterBossVictory();
      _isBossVictoryDialogOpen = false;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    controller.advanceAfterBossVictory();
    _isBossVictoryDialogOpen = false;
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

  static const String forgeArenaBackgroundAsset =
      'assets/images/forge_arena_bg.webp';
  static const String templeArenaBackgroundAsset =
      'assets/images/temple_arena_bg.webp';

  String _resolveBackgroundImage(GameController controller) {
    return controller.isSacredTempleArena
        ? templeArenaBackgroundAsset
        : forgeArenaBackgroundAsset;
  }

  Offset _resolveBackpackCenter(Size fallbackSize) {
    final stackBox =
        _rootStackKey.currentContext?.findRenderObject() as RenderBox?;
    final backpackBox =
        _backpackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox != null &&
        backpackBox != null &&
        stackBox.hasSize &&
        backpackBox.hasSize) {
      final globalCenter =
          backpackBox.localToGlobal(backpackBox.size.center(Offset.zero));
      return stackBox.globalToLocal(globalCenter);
    }
    return const Offset(33.0, 31.0);
  }

  Offset _resolveArenaClashCenter(Size fallbackSize) {
    final stackBox =
        _rootStackKey.currentContext?.findRenderObject() as RenderBox?;
    final clashBox =
        _clashCenterKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox != null &&
        clashBox != null &&
        stackBox.hasSize &&
        clashBox.hasSize) {
      final globalCenter =
          clashBox.localToGlobal(clashBox.size.center(Offset.zero));
      return stackBox.globalToLocal(globalCenter);
    }
    return Offset(fallbackSize.width * 0.5, fallbackSize.height * 0.42);
  }

  Widget _buildTopHudBar(
    BuildContext context,
    GameController controller,
    LocalizationService loc,
    bool inputsLocked,
  ) {
    final palette = AppPalette.of(context);
    final ownedOrbs = <HandMove>{
      if (controller.fireOrbs > 0) HandMove.rock,
      if (controller.waterOrbs > 0) HandMove.paper,
      if (controller.woodOrbs > 0) HandMove.scissors,
      if (controller.earthOrbs > 0) HandMove.lizard,
      if (controller.metalOrbs > 0) HandMove.spock,
    };

    final beveledBg = palette.isDark
        ? const Color(0xFF151922).withValues(alpha: 0.92)
        : palette.dialogSurface.withValues(alpha: 0.95);
    final beveledBorder = palette.isDark
        ? const Color(0xFF8A6D3B)
        : palette.sandCardBorder;

    return Padding(
      key: const ValueKey('battle_top_hud_bar'),
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Oversized Open Leather Backpack anchored top-left
          SizedBox(
            width: 54,
            height: 54,
            child: IconButton(
              key: const ValueKey('backpack_inventory_button'),
              padding: EdgeInsets.zero,
              iconSize: 52,
              constraints: const BoxConstraints(
                minWidth: 54,
                maxWidth: 54,
                minHeight: 54,
                maxHeight: 54,
              ),
              tooltip: loc.t(
                'inventory_title',
                fallback: "Cleric's Backpack",
              ),
              onPressed: () => _handleBackpackTap(context, controller),
              icon: AnimatedBuilder(
                animation: _flyingOrbController,
                builder: (context, _) {
                  final elapsedMs = _flyingOrbController.value *
                      GameScreen.orbTotalSequenceMs;
                  const pulseStartMs = GameScreen.orbSpawnDelayMs +
                      GameScreen.orbFlightDurationMs;
                  final isPulsing = _flyingOrbController.isAnimating &&
                      elapsedMs >= pulseStartMs &&
                      elapsedMs < GameScreen.orbTotalSequenceMs;
                  final pulseT = isPulsing
                      ? ((elapsedMs - pulseStartMs) /
                              GameScreen.backpackPulseDurationMs)
                          .clamp(0.0, 1.0)
                      : 0.0;
                  final scale = isPulsing
                      ? 1.0 + math.sin(pulseT * math.pi) * 0.22
                      : 1.0;
                  final pulseColor =
                      _lastAbsorbedOrbMove?.elementalPrimaryColor ??
                          Colors.amber;
                  final glowStrength =
                      isPulsing ? math.sin(pulseT * math.pi) : 0.0;

                  return Transform.scale(
                    scale: scale,
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: RpgBackpackIcon(
                        key: _backpackKey,
                        size: 52,
                        isOpen: true,
                        ownedOrbs: ownedOrbs,
                        pulseColor: isPulsing ? pulseColor : null,
                        glowStrength: glowStrength,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 2),

          // 2. Adaptive Rewarded Video Pill (🎬 +50)
          Expanded(
            child: (controller.isRewardedAdReady &&
                    !controller.isRemoveAdsActive)
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: AdaptiveRewardedAdButton(
                          maxWidth: constraints.maxWidth,
                          onTap: () =>
                              _handleWatchRewardedAd(context, controller),
                          tooltip: controller.rewardedAdDescription,
                          label: AdService.rewardedAdButtonLabel,
                        ),
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 4),

          // 3. Conditional Periodic Gift Button
          if (controller.shouldShowGiftBox) ...[
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                key: const ValueKey('gift_box_button'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                icon: const Text('🎁', style: TextStyle(fontSize: 20)),
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
              ),
            ),
            const SizedBox(width: 4),
          ],

          // 4. Conditional Reset Action Button
          if (controller.showReset) ...[
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                icon: const Icon(
                  Icons.restart_alt,
                  size: 21,
                  color: Colors.redAccent,
                ),
                tooltip: loc.t('string53', fallback: 'RESET'),
                onPressed: () => _confirmReset(context, controller, loc),
              ),
            ),
            const SizedBox(width: 4),
          ],

          // 6. Spiral Arcane Portal Button (Beveled Dark Square)
          SizedBox(
            width: 36,
            height: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: beveledBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: beveledBorder, width: 1.15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: palette.isDark ? 0.38 : 0.12,
                    ),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: IconButton(
                key: const ValueKey('teleport_portal_button'),
                padding: EdgeInsets.zero,
                iconSize: 34,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  maxWidth: 36,
                  minHeight: 36,
                  maxHeight: 36,
                ),
                tooltip: loc.t(
                  'teleport_tooltip',
                  fallback: 'Teleport to World Map (+1 Week)',
                ),
                onPressed: inputsLocked
                    ? null
                    : () => _handleTeleportTap(context, controller),
                icon: const SizedBox(
                  width: 34,
                  height: 34,
                  child: RpgTeleportPortalIcon(size: 34),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),

          // 7. Beveled Dark Square Settings Button
          SizedBox(
            width: 36,
            height: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: beveledBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: beveledBorder, width: 1.15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: palette.isDark ? 0.38 : 0.12,
                    ),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: IconButton(
                key: const ValueKey('battle_settings_button'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  maxWidth: 36,
                  minHeight: 36,
                  maxHeight: 36,
                ),
                icon: Icon(
                  Icons.settings_outlined,
                  size: 20,
                  color: palette.isDark
                      ? const Color(0xFFD9C398)
                      : palette.primaryText,
                ),
                tooltip: 'Settings',
                onPressed: () {
                  _stopOverchargedHold();
                  showDialog(
                    context: context,
                    builder: (_) => SettingsDialog(controller: controller),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final loc = controller.localization;
    final bgImage = _resolveBackgroundImage(controller);
    final inputsLocked = _areBattleInputsLocked(controller);
    final isRouteCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (_overchargedActiveTargetId != null &&
        (!isRouteCurrent ||
            inputsLocked ||
            _isOverchargedSafetyBrakeActive(controller))) {
      _cancelOverchargedTimersOnly();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _stopOverchargedHold();
      });
    }

    _syncAtmosphereAnimations(controller);
    _checkIntroStory(context, controller);
    _checkDeathAlert(context, controller);
    _checkBossVictoryAlert(context, controller);
    _check100RoundAlert(context, controller);
    _checkQaBonusSnackBar(context, controller);
    _checkUpdateSnackBar(context, controller);
    _checkFlyingOrbVfx(controller);

    final isSacredTempleArena = controller.isSacredTempleArena;
    final switcherDuration = controller.animationsEnabled
        ? const Duration(milliseconds: 400)
        : Duration.zero;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          key: _rootStackKey,
          children: [
            // Full-Screen Battle Background (Sacred Temple for Temple High Master & Baby Mage Robot; Dark Stone Forge for Lair bosses)
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: switcherDuration,
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: <Widget>[
                      ...previousChildren,
                      ?currentChild,
                    ],
                  );
                },
                child: Image.asset(
                  bgImage,
                  key: ValueKey<String>(bgImage),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: controller.darkMode
                        ? const Color(0xFF0D0E12)
                        : const Color(0xFFF7F8FA),
                  ),
                ),
              ),
            ),

            // Subtle atmospheric contrast overlay preserving arena art & HUD legibility
            Positioned.fill(
              child: Container(
                color: (controller.darkMode
                        ? Colors.black
                        : const Color(0xFFF5EFE3))
                    .withValues(alpha: controller.darkMode ? 0.22 : 0.35),
              ),
            ),

            // Animated Ambient Atmosphere Layer (Sacred Temple rays/torches/incense/dust for Temple bosses; Forge embers for Lair bosses)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: switcherDuration,
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        ...previousChildren,
                        ?currentChild,
                      ],
                    );
                  },
                  child: isSacredTempleArena
                      ? AnimatedBuilder(
                          key: const ValueKey('temple_arena_atmosphere_layer'),
                          animation: _templeAtmosphereController,
                          builder: (context, _) {
                            return CustomPaint(
                              key: const ValueKey(
                                'temple_arena_atmosphere_paint',
                              ),
                              painter: TempleAtmospherePainter(
                                progress: controller.animationsEnabled
                                    ? _templeAtmosphereController.value
                                    : 0.25,
                                isDark: controller.darkMode,
                              ),
                            );
                          },
                        )
                      : AnimatedBuilder(
                          key: const ValueKey('forge_arena_atmosphere_layer'),
                          animation: _embersController,
                          builder: (context, _) {
                            return CustomPaint(
                              key: const ValueKey('forge_arena_embers_paint'),
                              painter: _ForgeEmbersPainter(
                                progress: controller.animationsEnabled
                                    ? _embersController.value
                                    : 0.25,
                                isDark: controller.darkMode,
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),

            // Main Game Layout: Custom RPG Top HUD + Scrollable Upper Region + Pinned Bottom Deck + Bottom Banner Ad
            SafeArea(
              child: Column(
                children: [
                  // 0. Custom RPG Top HUD Bar
                  _buildTopHudBar(context, controller, loc, inputsLocked),

                  // 1. Bounded Top Scrollable HUD + Stationary Grounded VersusArena
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, middleConstraints) {
                        final hasVisibleHints = controller.showYourPrediction ||
                            controller.showNextMove ||
                            controller.showSuggestion ||
                            controller.showCrystalBall;
                        final isCompactHeight =
                            middleConstraints.maxHeight < 370.0;

                        return Column(
                          children: [
                            // 1a. Bounded Scrollable Upper HUD Panel (ScoreHeader, HintsBar, SacredBlessing, MarkovMatrixView)
                            Expanded(
                              child: ClipRect(
                                child: SingleChildScrollView(
                                  key: const ValueKey('game_upper_scroll_view'),
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    2,
                                    12,
                                    6,
                                  ),
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 480,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Scoreboard & Predictability Gauge Header (hidden unless unlocked & enabled)
                                          AnimatedSize(
                                            duration: const Duration(
                                              milliseconds: 250,
                                            ),
                                            curve: Curves.easeInOut,
                                            child: AnimatedSwitcher(
                                              duration: controller
                                                      .animationsEnabled
                                                  ? const Duration(
                                                      milliseconds: 250,
                                                    )
                                                  : Duration.zero,
                                              child: (controller
                                                          .unlockedPredictability &&
                                                      controller
                                                          .showPredictability)
                                                  ? Padding(
                                                      key: const ValueKey(
                                                        'score_header_visible',
                                                      ),
                                                      padding:
                                                          const EdgeInsets.only(
                                                        bottom: 4,
                                                      ),
                                                      child: ScoreHeader(
                                                        controller: controller,
                                                      ),
                                                    )
                                                  : const SizedBox.shrink(
                                                      key: ValueKey(
                                                        'score_header_hidden',
                                                      ),
                                                    ),
                                            ),
                                          ),

                                          // Unlocked Hint Pills (Prediction, Next move, Suggestion, Crystal Ball)
                                          HintsBar(controller: controller),
                                          if (hasVisibleHints)
                                            const SizedBox(height: 6),

                                          _buildSacredBlessingPill(
                                            context,
                                            controller,
                                          ),

                                          // Live Markov Transition Matrix moved to Top Scrollable HUD (if unlocked & enabled)
                                          if (controller.showAlgorithm) ...[
                                            const SizedBox(height: 6),
                                            MarkovMatrixView(
                                              engine: controller.engine,
                                              lastUserMove:
                                                  controller.lastUserMove,
                                              elementalMode:
                                                  controller.isElementalMode,
                                              localization: loc,
                                              isArchmageShortTermView: controller
                                                      .isArchmageBoss &&
                                                  controller
                                                      .isMarkovRecalibratorActive,
                                              isBabyMageRandomView:
                                                  controller.isBabyMageBoss,
                                              isTempleMasterRandomView:
                                                  controller.isTempleMasterBoss,
                                              isMetalWizardView:
                                                  controller.isMetalWizardBoss,
                                              metalWizardAiState:
                                                  controller.isMetalWizardBoss
                                                      ? controller
                                                          .metalWizardAiState
                                                      : null,
                                              currentPiDigit:
                                                  controller.isBabyMageBoss
                                                      ? controller.currentPiDigit
                                                      : null,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // 1b. Stationary Grounded VersusArena Locked Directly Above Bottom Move Card
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 480,
                                  ),
                                  child: VersusArena(
                                    compactHeight: isCompactHeight,
                                    userMove: controller.currentUserMove,
                                    computerMove:
                                        controller.currentComputerMove,
                                    secondaryComputerMove:
                                        controller.currentSecondaryComputerMove,
                                    dualSpellResult:
                                        controller.lastDualSpellResult,
                                    winner: controller.lastWinner,
                                    localization: loc,
                                    animationsEnabled:
                                        controller.animationsEnabled,
                                    roundId: controller.turnCount,
                                    userHp: controller.userHp,
                                    playerMaxHp:
                                        controller.effectivePlayerMaxHp,
                                    computerHp: controller.computerHp,
                                    computerMaxHp: controller.enemyMaxHp,
                                    remainingMana: controller.remainingMana,
                                    maxMana: controller.playerMaxMana,
                                    elementalMode: controller.isElementalMode,
                                    userDamageAmount:
                                        controller.lastRoundUserDamage > 0
                                            ? controller.lastRoundUserDamage
                                            : controller.bossWinDamageToPlayer,
                                    computerDamageAmount:
                                        controller.lastRoundComputerDamage > 0
                                            ? controller.lastRoundComputerDamage
                                            : controller.playerWinDamageToBoss,
                                    isPhase2: controller.enemyUses5Elements,
                                    enemyStage: controller.enemyStage,
                                    isAntiMetalShieldBlocked: controller
                                        .lastRoundBlockedByAntiMetalShield,
                                    pcSlotKey: _pcSlotKey,
                                    clashCenterKey: _clashCenterKey,
                                    onImpactHaptic: controller.isElementalMode
                                        ? controller.audio.playTapVibrate
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // 2. Pinned Bottom Controls (Glossy 3D Elemental Action Deck)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          14,
                          2,
                          14,
                          controller.shouldShowBannerAd ? 10 : 8,
                        ),
                        child: Builder(
                          builder: (context) {
                            final palette = AppPalette.of(context);
                            return Container(
                              key: const ValueKey('move_selection_card'),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: palette.isDark
                                      ? const Color(0xFF8A6D3B)
                                          .withValues(alpha: 0.72)
                                      : palette.amberBorder
                                          .withValues(alpha: 0.55),
                                  width: 1.25,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: palette.isDark ? 0.55 : 0.22,
                                    ),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                    offset: const Offset(0, -4),
                                  ),
                                ],
                              ),
                              child: Card(
                                margin: EdgeInsets.zero,
                                elevation: 0,
                                color: palette.isDark
                                    ? const Color(0xFF141820)
                                        .withValues(alpha: 0.94)
                                    : palette.deckSurface,
                                surfaceTintColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 8,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Hand move buttons (single row for 3 classic or all 5 hands)
                                      Row(
                                        key: const ValueKey('hand_buttons_row'),
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          for (final move in [
                                            HandMove.rock,
                                            HandMove.paper,
                                            HandMove.scissors,
                                            if (controller.showNewHands) ...[
                                              HandMove.lizard,
                                              HandMove.spock,
                                            ],
                                          ])
                                            _OverchargedPointerRegion(
                                              enabled: controller
                                                      .isOverchargedStaffActive &&
                                                  !inputsLocked,
                                              onPointerDown: (event) =>
                                                  _startOverchargedHold(
                                                targetId: move.name,
                                                pointerId: event.pointer,
                                                controller: controller,
                                                onFireSingle: () =>
                                                    controller.playTurn(move),
                                                onFireRapid: () =>
                                                    controller.playTurn(
                                                  move,
                                                  isRapidFire: true,
                                                ),
                                              ),
                                              onPointerRelease: (pointerId) =>
                                                  _stopOverchargedHold(
                                                onlyPointerId: pointerId,
                                                clearSuppressedTargetId:
                                                    move.name,
                                              ),
                                              child: _HandActionButton(
                                                key: ValueKey(
                                                  'hand_button_${move.name}',
                                                ),
                                                move: move,
                                                compact:
                                                    controller.showNewHands,
                                                elementalMode:
                                                    controller.isElementalMode,
                                                isSelected:
                                                    controller.currentUserMove ==
                                                    move,
                                                localization: loc,
                                                animationsEnabled: controller
                                                    .animationsEnabled,
                                                isOverchargedHolding:
                                                    _overchargedActiveTargetId ==
                                                    move.name,
                                                isOverchargedRapidFiring:
                                                    _overchargedActiveTargetId ==
                                                        move.name &&
                                                    _overchargedIsRapidFiring,
                                                overchargedChargeAnimation:
                                                    _overchargedChargeController,
                                                overchargedPulseAnimation:
                                                    _overchargedPulseController,
                                                consumeSuppressedTap: () =>
                                                    _consumeSuppressedTap(
                                                      move.name,
                                                    ),
                                                onPressed: inputsLocked
                                                    ? null
                                                    : () => controller
                                                        .playTurn(move),
                                              ),
                                            ),
                                        ],
                                      ),

                                      // Optional Random move button (if unlocked & enabled)
                                      if (controller.showRandom) ...[
                                        const SizedBox(height: 6),
                                        _OverchargedPointerRegion(
                                          enabled: controller
                                                  .isOverchargedStaffActive &&
                                              !inputsLocked,
                                          onPointerDown: (event) =>
                                              _startOverchargedHold(
                                            targetId: 'random',
                                            pointerId: event.pointer,
                                            controller: controller,
                                            onFireSingle: () =>
                                                controller.playRandom(),
                                            onFireRapid: () =>
                                                controller.playRandom(
                                              isRapidFire: true,
                                            ),
                                          ),
                                          onPointerRelease: (pointerId) =>
                                              _stopOverchargedHold(
                                            onlyPointerId: pointerId,
                                            clearSuppressedTargetId: 'random',
                                          ),
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: AnimatedBuilder(
                                              animation: Listenable.merge([
                                                _overchargedChargeController,
                                                _overchargedPulseController,
                                              ]),
                                              builder: (context, _) {
                                                final isHoldingRandom =
                                                    _overchargedActiveTargetId ==
                                                    'random';
                                                final isRapidRandom =
                                                    isHoldingRandom &&
                                                    _overchargedIsRapidFiring;
                                                return OutlinedButton.icon(
                                                  key: const ValueKey(
                                                    'random_move_button',
                                                  ),
                                                  onPressed: inputsLocked
                                                      ? null
                                                      : () {
                                                          if (_consumeSuppressedTap(
                                                            'random',
                                                          )) {
                                                            return;
                                                          }
                                                          controller
                                                              .playRandom();
                                                        },
                                                  icon: SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: Stack(
                                                      clipBehavior: Clip.none,
                                                      alignment:
                                                          Alignment.center,
                                                      children: [
                                                        if (isHoldingRandom)
                                                          Positioned.fill(
                                                            child: IgnorePointer(
                                                              child: CustomPaint(
                                                                key: const ValueKey(
                                                                  'overcharged_charge_ring_random',
                                                                ),
                                                                painter:
                                                                    _OverchargedChargeRingPainter(
                                                                  progress: isRapidRandom
                                                                      ? 1.0
                                                                      : _overchargedChargeController
                                                                          .value,
                                                                  pulse: isRapidRandom
                                                                      ? _overchargedPulseController
                                                                          .value
                                                                      : 0.0,
                                                                  isRapidFiring:
                                                                      isRapidRandom,
                                                                  primaryColor:
                                                                      const Color(
                                                                    0xFFF5C22B,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        Icon(
                                                          Icons.shuffle_rounded,
                                                          size: 16,
                                                          color: isHoldingRandom
                                                              ? const Color(
                                                                  0xFFFFD54F,
                                                                )
                                                              : (palette.isDark
                                                                  ? const Color(
                                                                      0xFFD9C398,
                                                                    )
                                                                  : palette
                                                                      .amberText),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  label: Text(
                                                    loc.t(
                                                      'string16',
                                                      fallback: 'RANDOM',
                                                    ),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 12,
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        palette.isDark
                                                            ? const Color(
                                                                0xFFE6D5B8,
                                                              )
                                                            : palette.amberText,
                                                    backgroundColor:
                                                        palette.isDark
                                                            ? const Color(
                                                                0xFF1F2430,
                                                              )
                                                            : palette
                                                                .dialogCardSurface,
                                                    side: BorderSide(
                                                      color: isHoldingRandom
                                                          ? const Color(
                                                              0xFFF5C22B,
                                                            )
                                                          : (palette.isDark
                                                              ? const Color(
                                                                  0xFF8A6D3B,
                                                                ).withValues(
                                                                  alpha: 0.72,
                                                                )
                                                              : palette
                                                                  .amberBorder
                                                                  .withValues(
                                                                    alpha: 0.65,
                                                                  )),
                                                      width: isHoldingRandom
                                                          ? 1.6
                                                          : 1.1,
                                                    ),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      vertical: 7,
                                                      horizontal: 12,
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        14,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // 3. Bottom Banner Ad: anchored at the very bottom inside SafeArea
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

          // Flying Elemental Orb VFX Overlay (from Mid-Arena Clash center to top-left Backpack icon)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _flyingOrbController,
                builder: (context, _) {
                  final orbMove = _activeFlyingOrbMove;
                  final elapsedMs = _flyingOrbController.value *
                      GameScreen.orbTotalSequenceMs;
                  const flightEndMs = GameScreen.orbSpawnDelayMs +
                      GameScreen.orbFlightDurationMs;
                  final isFlying = controller.animationsEnabled &&
                      orbMove != null &&
                      _flyingOrbController.isAnimating &&
                      elapsedMs + 1e-4 >= GameScreen.orbSpawnDelayMs &&
                      elapsedMs < flightEndMs - 1e-4;
                  if (!isFlying) {
                    return const SizedBox.shrink();
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final screenSize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      final startPos = _resolveArenaClashCenter(screenSize);
                      final endPos = _resolveBackpackCenter(screenSize);
                      final controlPoint = GameScreen.calculateOrbControlPoint(
                        startPos,
                        endPos,
                      );
                      final flightRawT = ((elapsedMs -
                                  GameScreen.orbSpawnDelayMs) /
                              GameScreen.orbFlightDurationMs)
                          .clamp(0.0, 1.0);
                      final curvedT = Curves.easeInOutCubic.transform(
                        flightRawT,
                      );

                      Offset bezierPoint(double t) =>
                          GameScreen.evaluateOrbBezier(
                            startPos,
                            controlPoint,
                            endPos,
                            t,
                          );

                      final currentOrbPos = bezierPoint(curvedT);
                      final primary = orbMove.elementalPrimaryColor;
                      final secondary = orbMove.elementalSecondaryColor;

                      return Stack(
                        key: const ValueKey('flying_orb_vfx_overlay'),
                        clipBehavior: Clip.none,
                        children: [
                          // Subtle glowing trail particles along the curved arc
                          for (var i = 1; i <= 4; i++)
                            if (curvedT - i * 0.045 > 0.0)
                              Builder(
                                builder: (context) {
                                  final trailT =
                                      (curvedT - i * 0.045).clamp(0.0, 1.0);
                                  final trailPos = bezierPoint(trailT);
                                  final radius = 9.0 - i * 1.6;
                                  return Positioned(
                                    left: trailPos.dx - radius,
                                    top: trailPos.dy - radius,
                                    child: Container(
                                      width: radius * 2,
                                      height: radius * 2,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primary.withValues(
                                          alpha: (0.48 - i * 0.09)
                                              .clamp(0.05, 0.5),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primary.withValues(
                                              alpha: 0.35 - i * 0.06,
                                            ),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          // Main Flying Elemental Energy Orb
                          Positioned(
                            left: currentOrbPos.dx - 14,
                            top: currentOrbPos.dy - 14,
                            child: Container(
                              key: ValueKey('flying_orb_${orbMove.orbKey}'),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    orbMove == HandMove.lizard
                                        ? const Color(0xFFE29E5A)
                                        : Colors.white,
                                    primary,
                                    secondary,
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  width: 1.3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withValues(alpha: 0.85),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: ElementalSymbolIcon(
                                  move: orbMove,
                                  size: 17,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _handleWatchRewardedAd(
    BuildContext context,
    GameController controller,
  ) async {
    await controller.watchRewardedAd(
      onRewardEarned: () {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(controller.activeRewardedAdSnackBarMessage),
              duration: const Duration(seconds: 2),
            ),
          );
      },
    );
  }

  String _elementShortName(HandMove move, LocalizationService loc) {
    final raw = move.displayLabel(elemental: true, localization: loc).trim();
    if (raw.isEmpty) return move.elementalLabel;
    if (raw.length == 1) return raw.toUpperCase();
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

  Widget _buildLostOrbBadge(
    HandMove move,
    int lostCount,
    AppPalette palette,
    LocalizationService localization,
  ) {
    final primary = move.elementalPrimaryColor;
    final secondary = move.elementalSecondaryColor;
    final fgColor = palette.elementalText(move);
    final label = '-$lostCount ${_elementShortName(move, localization)}';

    return Container(
      key: ValueKey('reset_lost_orb_${move.orbKey}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.elementalCardBackground(move),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.elementalCardBorder(move),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.25, -0.25),
                colors: [
                  Color.lerp(primary, Colors.white, 0.55)!,
                  primary,
                  secondary,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: palette.isDark ? 0.55 : 0.3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Center(
              child: ElementalSymbolIcon(
                move: move,
                size: 15,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    GameController controller,
    LocalizationService localization,
  ) async {
    _stopOverchargedHold();
    final lostEntries = <MapEntry<HandMove, int>>[
      for (final move in HandMove.values)
        if (controller.lostOrbsFor(move) > 0)
          MapEntry(move, controller.lostOrbsFor(move)),
    ];

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = AppPalette.of(dialogContext);
        return AlertDialog(
          key: const ValueKey('reset_confirm_dialog'),
          backgroundColor: palette.isDark
              ? const Color(0xFF14161D)
              : palette.dialogSurface,
          surfaceTintColor: palette.isDark ? null : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: palette.isDark
                  ? Colors.redAccent.withValues(alpha: 0.45)
                  : palette.dangerText.withValues(alpha: 0.38),
              width: 1.2,
            ),
          ),
          title: Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: palette.dangerText,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  localization.t(
                    'reset_rewind_title',
                    fallback: 'Rewind to Turn 0?',
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: palette.primaryText,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localization
                      .t(
                        'reset_rewind_message',
                        fallback:
                            'Resetting will rewind time back to Turn 0, restoring Mana to {mana}, HP to {hp}, scores to 0, and clearing the Markov matrix.',
                      )
                      .replaceAll('{mana}', '${controller.playerMaxMana}')
                      .replaceAll('{hp}', '${controller.playerMaxHp}'),
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: palette.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
                if (lostEntries.isNotEmpty)
                  Container(
                    key: const ValueKey('reset_orbs_lost_card'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.rewardedAdCardSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: palette.rewardedAdCardBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localization.t(
                            'reset_orbs_lost_header',
                            fallback:
                                'Elemental Orbs sent to Castle Spoils (reclaimable anytime):',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: palette.amberText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in lostEntries)
                              _buildLostOrbBadge(
                                entry.key,
                                entry.value,
                                palette,
                                localization,
                              ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    key: const ValueKey('reset_no_orbs_lost_note'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: palette.isDark
                          ? const Color(0xFF16241D)
                          : const Color(0xFFEAF3E8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.successText.withValues(
                          alpha: palette.isDark ? 0.38 : 0.42,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: palette.successText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            localization.t(
                              'reset_no_orbs_lost',
                              fallback: 'No Elemental Orbs will be lost.',
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              color: palette.successText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('reset_cancel_button'),
              style: TextButton.styleFrom(
                foregroundColor: palette.secondaryText,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                localization.t('reset_cancel', fallback: 'Cancel'),
              ),
            ),
            ElevatedButton(
              key: const ValueKey('reset_confirm_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(localization.t('string53', fallback: 'RESET')),
            ),
          ],
        );
      },
    );

    if (shouldReset == true) {
      controller.resetGame();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localization.t(
                'reset_rewind_done',
                fallback: 'Time rewound to Turn 0!',
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _HandActionButton extends StatefulWidget {
  final HandMove move;
  final bool compact;
  final bool elementalMode;
  final bool isSelected;
  final LocalizationService localization;
  final bool animationsEnabled;
  final bool isOverchargedHolding;
  final bool isOverchargedRapidFiring;
  final Animation<double>? overchargedChargeAnimation;
  final Animation<double>? overchargedPulseAnimation;
  final bool Function()? consumeSuppressedTap;
  final VoidCallback? onPressed;

  const _HandActionButton({
    super.key,
    required this.move,
    this.compact = false,
    this.elementalMode = false,
    this.isSelected = false,
    required this.localization,
    required this.animationsEnabled,
    this.isOverchargedHolding = false,
    this.isOverchargedRapidFiring = false,
    this.overchargedChargeAnimation,
    this.overchargedPulseAnimation,
    this.consumeSuppressedTap,
    required this.onPressed,
  });

  @override
  State<_HandActionButton> createState() => _HandActionButtonState();
}

class _HandActionButtonState extends State<_HandActionButton>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  late AnimationController _auraController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncAuraAnimation();
  }

  void _syncAuraAnimation() {
    if (widget.isSelected && widget.animationsEnabled) {
      if (!_auraController.isAnimating) {
        _auraController.repeat();
      }
    } else {
      if (_auraController.isAnimating || _auraController.value != 0.0) {
        _auraController.stop();
        _auraController.reset();
      }
    }
  }

  @override
  void didUpdateWidget(covariant _HandActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected ||
        widget.animationsEnabled != oldWidget.animationsEnabled) {
      _syncAuraAnimation();
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    _auraController.dispose();
    super.dispose();
  }

  void _playPressPulse() {
    if (widget.animationsEnabled) {
      _pressController.stop();
      _pressController.forward(from: 0.0).then((_) {
        if (mounted) {
          _pressController.reverse().catchError((_) {});
        }
      }).catchError((_) {});
    }
  }

  void _handleTap() {
    if (widget.consumeSuppressedTap?.call() ?? false) {
      return;
    }
    final onPressed = widget.onPressed;
    if (onPressed == null) return;
    // Execute the game turn immediately with zero delay
    onPressed();
    _playPressPulse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final hasAsset = widget.move.leftAsset.isNotEmpty;
    final compact = widget.compact;
    final elemental = widget.elementalMode;
    final isSelected = widget.isSelected;
    final primaryColor = widget.move.elementalPrimaryColor;
    final secondaryColor = widget.move.elementalSecondaryColor;
    final elementLabelColor = palette.elementalText(widget.move);

    final (Color orbInnerColor, Color orbOuterColor) = switch (widget.move) {
      HandMove.rock => (const Color(0xFFFF3D00), const Color(0xFF8E0000)),
      HandMove.paper => (const Color(0xFF00B0FF), const Color(0xFF013A63)),
      HandMove.scissors => (const Color(0xFF00C853), const Color(0xFF0B4F22)),
      HandMove.lizard => (const Color(0xFFC47A38), const Color(0xFF3D220E)),
      HandMove.spock => (const Color(0xFFCFD8DC), const Color(0xFF37474F)),
    };

    final horizontalPadding = compact ? 2.0 : 8.0;
    final verticalPadding = compact ? 3.0 : 8.0;
    final borderRadius = compact ? 14.0 : 16.0;
    final circleSize = compact ? 50.0 : 58.0;
    final imageSize = compact ? 26.0 : 34.0;
    final emojiFontSize = compact ? 20.0 : 24.0;
    final elementalSymbolSize = compact ? 25.0 : 30.0;
    final labelFontSize = compact ? 8.8 : 10.0;

    final String buttonLabel = elemental
        ? widget.move
              .displayLabel(elemental: true, localization: widget.localization)
              .toUpperCase()
        : widget.move.label.toUpperCase();

    Widget buttonContent = InkWell(
      onTapDown: widget.onPressed == null ? null : (_) => _playPressPulse(),
      onTap: widget.onPressed == null ? null : _handleTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: elemental
              ? (palette.isDark
                    ? Colors.transparent
                    : palette.elementalCardBackground(widget.move))
              : (palette.isDark
                    ? theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      )
                    : palette.sandCardSurface),
          borderRadius: BorderRadius.circular(borderRadius),
          border: elemental && palette.isDark
              ? null
              : Border.all(
                  color: elemental
                      ? elementLabelColor.withValues(
                          alpha: isSelected ? 0.85 : 0.48,
                        )
                      : (palette.isDark
                            ? theme.colorScheme.outline.withValues(alpha: 0.2)
                            : palette.sandCardBorder),
                  width: elemental && isSelected ? 1.5 : 1.0,
                ),
        ),
        child: Container(
          key: ValueKey('hand_orb_${widget.move.name}'),
          width: circleSize,
          height: circleSize,
          decoration: elemental
              ? null
              : BoxDecoration(
                  color: palette.isDark
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : palette.amberBorder.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Animated CustomPainter flame aura around the active/selected orb
              if (elemental && isSelected)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _auraController,
                      builder: (context, _) {
                        return CustomPaint(
                          key: ValueKey(
                            'active_orb_flame_aura_${widget.move.name}',
                          ),
                          painter: _ActiveOrbFlameAuraPainter(
                            phase: widget.animationsEnabled
                                ? _auraController.value
                                : 0.35,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor,
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Overcharged Staff Charge Ring (fills over 250ms and pulses during rapid-fire)
              if (widget.isOverchargedHolding)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        if (widget.overchargedChargeAnimation != null)
                          widget.overchargedChargeAnimation!,
                        if (widget.overchargedPulseAnimation != null)
                          widget.overchargedPulseAnimation!,
                      ]),
                      builder: (context, _) {
                        return CustomPaint(
                          key: ValueKey(
                            'overcharged_charge_ring_${widget.move.name}',
                          ),
                          painter: _OverchargedChargeRingPainter(
                            progress: widget.isOverchargedRapidFiring
                                ? 1.0
                                : (widget.overchargedChargeAnimation?.value ??
                                    1.0),
                            pulse: widget.isOverchargedRapidFiring
                                ? (widget.overchargedPulseAnimation?.value ??
                                    0.0)
                                : 0.0,
                            isRapidFiring: widget.isOverchargedRapidFiring,
                            primaryColor: primaryColor,
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Glossy 3D Shaded Elemental Energy Sphere with Outer Glow, Inner Bevel & Specular Arc
              if (elemental)
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.28, -0.32),
                      radius: 0.90,
                      colors: [orbInnerColor, orbOuterColor],
                      stops: const [0.10, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: orbInnerColor.withValues(
                          alpha: isSelected ? 0.58 : 0.32,
                        ),
                        blurRadius: isSelected ? 12 : 7,
                        spreadRadius: isSelected ? 1.0 : 0.2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 5,
                        offset: const Offset(0, 2.5),
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ElementalEnergySphere(
                        size: circleSize,
                        primaryColor: orbInnerColor,
                        secondaryColor: orbOuterColor,
                        isDark: palette.isDark,
                      ),
                      IgnorePointer(
                        child: CustomPaint(
                          size: Size.square(circleSize),
                          painter: _ActionOrbGlossPainter(
                            primaryColor: orbInnerColor,
                            secondaryColor: orbOuterColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Crisp Elemental Emblem or Classic Hand in Upper-Middle of Sphere
              Positioned(
                top: elemental ? circleSize * 0.12 : circleSize * 0.12,
                child: elemental
                    ? ElementalSymbolIcon(
                        move: widget.move,
                        size: elementalSymbolSize,
                      )
                    : hasAsset
                    ? Image.asset(
                        widget.move.leftAsset,
                        width: imageSize,
                        height: imageSize,
                        errorBuilder: (context, error, stackTrace) => Text(
                          widget.move.emoji,
                          style: TextStyle(fontSize: emojiFontSize),
                        ),
                      )
                    : Text(
                        widget.move.emoji,
                        style: TextStyle(fontSize: emojiFontSize),
                      ),
              ),

              // Bold Shadowed White Element Label Inside Lower Third of Sphere
              Positioned(
                bottom: elemental ? circleSize * 0.11 : 2.0,
                left: 4,
                right: 4,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    buttonLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: labelFontSize,
                      height: 1.0,
                      letterSpacing: 0.5,
                      color: elemental
                          ? Colors.white
                          : (palette.isDark
                                ? Colors.white
                                : palette.primaryText),
                      shadows: elemental
                          ? const [
                              Shadow(
                                color: Color(0xFF0A0E14),
                                offset: Offset(-0.9, -0.9),
                                blurRadius: 0.6,
                              ),
                              Shadow(
                                color: Color(0xFF0A0E14),
                                offset: Offset(0.9, -0.9),
                                blurRadius: 0.6,
                              ),
                              Shadow(
                                color: Color(0xFF0A0E14),
                                offset: Offset(-0.9, 0.9),
                                blurRadius: 0.6,
                              ),
                              Shadow(
                                color: Color(0xFF0A0E14),
                                offset: Offset(0.9, 0.9),
                                blurRadius: 0.6,
                              ),
                              Shadow(
                                color: Colors.black,
                                blurRadius: 3.5,
                                offset: Offset(0, 1.5),
                              ),
                            ]
                          : palette.isDark
                          ? const [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 3.5,
                                offset: Offset(0, 1),
                              ),
                              Shadow(
                                color: Colors.black,
                                blurRadius: 6.0,
                              ),
                            ]
                          : const [
                              Shadow(
                                color: Colors.white,
                                blurRadius: 3.0,
                              ),
                            ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!widget.animationsEnabled) {
      return buttonContent;
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: buttonContent,
    );
  }
}

/// Renders a crisp dark/light inner beveled rim and glossy top-left glass
/// specular highlight arc for the bottom 3D elemental action orbs.
class _ActionOrbGlossPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  const _ActionOrbGlossPainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double s = size.shortestSide;
    final Offset center = Offset(size.width * 0.5, size.height * 0.5);
    final double radius = s * 0.5;

    // 1. Crisp dark outer border ring
    canvas.drawCircle(
      center,
      radius - 0.7,
      Paint()
        ..color = const Color(0xFF0D1117).withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    // 2. Crisp inner beveled rim (top-left bright highlight -> bottom-right deep rim)
    canvas.drawCircle(
      center,
      radius - 2.1,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.45),
            primaryColor.withValues(alpha: 0.25),
            secondaryColor.withValues(alpha: 0.65),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // 3. Glossy top-left glass specular highlight arc (approx 10 o'clock to 12:30)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.79),
      3.55,
      1.35,
      false,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.62),
            Colors.white.withValues(alpha: 0.14),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.79))
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.055).clamp(2.2, 3.4)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ActionOrbGlossPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

/// Animated CustomPainter flame/energy aura dancing around the active elemental orb.
class _ActiveOrbFlameAuraPainter extends CustomPainter {
  final double phase;
  final Color primaryColor;
  final Color secondaryColor;

  const _ActiveOrbFlameAuraPainter({
    required this.phase,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final baseRadius = size.shortestSide * 0.45;
    final pulse = 0.5 + 0.5 * math.sin(phase * 2.0 * math.pi);

    // 1. Bright outer elemental aura bloom
    canvas.drawCircle(
      center,
      baseRadius * (1.18 + 0.08 * pulse),
      Paint()
        ..color = primaryColor.withValues(alpha: 0.50 + 0.20 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0),
    );

    // 2. 10 flickering flame tongues around the circumference
    const flameCount = 10;
    final flamePath = Path();
    for (int i = 0; i < flameCount; i++) {
      final baseAngle =
          (i / flameCount) * 2.0 * math.pi + phase * 2.0 * math.pi;
      final prevAngle = baseAngle - (math.pi / flameCount) * 0.85;
      final nextAngle = baseAngle + (math.pi / flameCount) * 0.85;
      final wave = math.sin(phase * 4.0 * math.pi + i * 1.7);
      final tipRadius = baseRadius * (1.24 + 0.12 * wave);
      final innerRadius = baseRadius * 0.94;

      final p1 = Offset(
        center.dx + math.cos(prevAngle) * innerRadius,
        center.dy + math.sin(prevAngle) * innerRadius,
      );
      final tip = Offset(
        center.dx + math.cos(baseAngle) * tipRadius,
        center.dy + math.sin(baseAngle) * tipRadius,
      );
      final p2 = Offset(
        center.dx + math.cos(nextAngle) * innerRadius,
        center.dy + math.sin(nextAngle) * innerRadius,
      );

      flamePath
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(tip.dx, tip.dy, p2.dx, p2.dy);
    }

    canvas.drawPath(
      flamePath,
      Paint()
        ..color = Color.lerp(primaryColor, Colors.white, 0.42)!
            .withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // 3. Crisp glowing selection rim
    canvas.drawCircle(
      center,
      baseRadius * 1.02,
      Paint()
        ..color = Color.lerp(primaryColor, Colors.white, 0.55)!
            .withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _ActiveOrbFlameAuraPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

/// Subtle animated drifting forge sparks & embers rising gently across the edges.
class _ForgeEmbersPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  const _ForgeEmbersPainter({
    required this.progress,
    required this.isDark,
  });

  static const List<({double x, double phase, double radius, double sway})>
      _emberSpecs = [
    (x: 0.06, phase: 0.05, radius: 1.8, sway: 8.0),
    (x: 0.14, phase: 0.32, radius: 1.3, sway: 6.0),
    (x: 0.22, phase: 0.68, radius: 1.5, sway: 7.0),
    (x: 0.78, phase: 0.18, radius: 1.4, sway: 7.0),
    (x: 0.86, phase: 0.51, radius: 1.9, sway: 9.0),
    (x: 0.93, phase: 0.82, radius: 1.3, sway: 6.0),
    (x: 0.10, phase: 0.89, radius: 1.6, sway: 5.5),
    (x: 0.90, phase: 0.41, radius: 1.5, sway: 6.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final baseAlpha = isDark ? 0.68 : 0.35;

    for (final spec in _emberSpecs) {
      final t = (progress + spec.phase) % 1.0;
      final y = size.height * (0.92 - 0.80 * t);
      final x = size.width * spec.x +
          math.sin(t * 2.0 * math.pi + spec.phase * 8.0) * spec.sway;
      final fade = math.sin(t * math.pi).clamp(0.0, 1.0);
      final alpha = (baseAlpha * fade).clamp(0.0, 1.0);
      if (alpha <= 0.02) continue;

      final pos = Offset(x, y);
      canvas.drawCircle(
        pos,
        spec.radius * 2.4,
        Paint()
          ..color = const Color(0xFFFF6D00).withValues(alpha: alpha * 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawCircle(
        pos,
        spec.radius,
        Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ForgeEmbersPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}

/// Lightweight 60 FPS Sacred Temple ambient painter layered over `temple_arena_bg`:
/// 1. Shimmering Gothic rose-window diagonal light beams (`~4.0s` breathing cycle).
/// 2. Flickering warm amber wall torch halos & rising altar incense wisps.
/// 3. 32 drifting golden-cyan sacred dust motes across the nave and sunbeams.
class TempleAtmospherePainter extends CustomPainter {
  final double progress;
  final bool isDark;

  const TempleAtmospherePainter({
    required this.progress,
    required this.isDark,
  });

  static const double _imageAspectRatio = 571.0 / 1024.0;

  static const List<
      ({
        double x,
        double yStart,
        double travel,
        double phase,
        double radius,
        double sway,
        bool isGold,
      })> _moteSpecs = [
    (x: 0.12, yStart: 0.86, travel: 0.62, phase: 0.03, radius: 1.5, sway: 7.0, isGold: true),
    (x: 0.18, yStart: 0.78, travel: 0.56, phase: 0.19, radius: 1.2, sway: 5.5, isGold: false),
    (x: 0.24, yStart: 0.90, travel: 0.68, phase: 0.41, radius: 1.7, sway: 8.5, isGold: true),
    (x: 0.29, yStart: 0.72, travel: 0.54, phase: 0.64, radius: 1.3, sway: 6.0, isGold: false),
    (x: 0.33, yStart: 0.84, travel: 0.64, phase: 0.82, radius: 1.6, sway: 7.5, isGold: true),
    (x: 0.36, yStart: 0.68, travel: 0.52, phase: 0.11, radius: 1.4, sway: 6.5, isGold: false),
    (x: 0.39, yStart: 0.88, travel: 0.66, phase: 0.29, radius: 1.8, sway: 8.0, isGold: true),
    (x: 0.42, yStart: 0.74, travel: 0.58, phase: 0.53, radius: 1.2, sway: 5.0, isGold: false),
    (x: 0.45, yStart: 0.62, travel: 0.48, phase: 0.77, radius: 1.5, sway: 6.5, isGold: true),
    (x: 0.47, yStart: 0.80, travel: 0.60, phase: 0.91, radius: 1.3, sway: 7.0, isGold: false),
    (x: 0.50, yStart: 0.70, travel: 0.54, phase: 0.07, radius: 1.7, sway: 6.0, isGold: true),
    (x: 0.52, yStart: 0.89, travel: 0.65, phase: 0.36, radius: 1.4, sway: 8.0, isGold: false),
    (x: 0.54, yStart: 0.64, travel: 0.50, phase: 0.58, radius: 1.6, sway: 5.5, isGold: true),
    (x: 0.57, yStart: 0.79, travel: 0.58, phase: 0.73, radius: 1.2, sway: 7.0, isGold: false),
    (x: 0.60, yStart: 0.85, travel: 0.62, phase: 0.15, radius: 1.8, sway: 8.5, isGold: true),
    (x: 0.63, yStart: 0.71, travel: 0.52, phase: 0.44, radius: 1.3, sway: 6.0, isGold: false),
    (x: 0.66, yStart: 0.88, travel: 0.64, phase: 0.69, radius: 1.5, sway: 7.5, isGold: true),
    (x: 0.69, yStart: 0.66, travel: 0.50, phase: 0.87, radius: 1.4, sway: 5.5, isGold: false),
    (x: 0.72, yStart: 0.81, travel: 0.60, phase: 0.24, radius: 1.7, sway: 8.0, isGold: true),
    (x: 0.76, yStart: 0.75, travel: 0.56, phase: 0.49, radius: 1.3, sway: 6.5, isGold: false),
    (x: 0.81, yStart: 0.87, travel: 0.64, phase: 0.62, radius: 1.6, sway: 7.0, isGold: true),
    (x: 0.86, yStart: 0.77, travel: 0.55, phase: 0.94, radius: 1.2, sway: 5.5, isGold: false),
    (x: 0.90, yStart: 0.84, travel: 0.60, phase: 0.33, radius: 1.5, sway: 6.5, isGold: true),
    (x: 0.15, yStart: 0.58, travel: 0.42, phase: 0.56, radius: 1.3, sway: 5.0, isGold: false),
    (x: 0.27, yStart: 0.54, travel: 0.40, phase: 0.79, radius: 1.4, sway: 6.0, isGold: true),
    (x: 0.41, yStart: 0.52, travel: 0.38, phase: 0.09, radius: 1.5, sway: 5.5, isGold: false),
    (x: 0.49, yStart: 0.48, travel: 0.35, phase: 0.46, radius: 1.3, sway: 4.5, isGold: true),
    (x: 0.56, yStart: 0.51, travel: 0.37, phase: 0.71, radius: 1.5, sway: 5.5, isGold: false),
    (x: 0.64, yStart: 0.55, travel: 0.40, phase: 0.85, radius: 1.4, sway: 6.0, isGold: true),
    (x: 0.74, yStart: 0.57, travel: 0.42, phase: 0.21, radius: 1.3, sway: 5.0, isGold: false),
    (x: 0.84, yStart: 0.60, travel: 0.44, phase: 0.66, radius: 1.6, sway: 6.5, isGold: true),
    (x: 0.35, yStart: 0.93, travel: 0.66, phase: 0.38, radius: 1.4, sway: 7.0, isGold: false),
  ];

  static const List<({double nx, double ny, double radius, double seed})>
      _torchSpecs = [
    (nx: 0.058, ny: 0.521, radius: 32.0, seed: 0.4),
    (nx: 0.937, ny: 0.519, radius: 32.0, seed: 2.1),
    (nx: 0.187, ny: 0.532, radius: 20.0, seed: 3.7),
    (nx: 0.813, ny: 0.530, radius: 20.0, seed: 5.0),
  ];

  static const List<({double nx, double ny, double sideSeed})> _brazierSpecs = [
    (nx: 0.392, ny: 0.555, sideSeed: 0.0),
    (nx: 0.608, ny: 0.555, sideSeed: 2.4),
  ];

  static const List<double> _wispPhases = [0.0, 0.22, 0.45, 0.68, 0.87];

  Rect _resolveCoveredImageRect(Size size) {
    final widgetAspect = size.width / size.height;
    if (widgetAspect > _imageAspectRatio) {
      final drawW = size.width;
      final drawH = size.width / _imageAspectRatio;
      return Rect.fromLTWH(0.0, (size.height - drawH) * 0.5, drawW, drawH);
    }
    final drawH = size.height;
    final drawW = size.height * _imageAspectRatio;
    return Rect.fromLTWH((size.width - drawW) * 0.5, 0.0, drawW, drawH);
  }

  Offset _imgPt(Rect rect, double nx, double ny) {
    return Offset(rect.left + rect.width * nx, rect.top + rect.height * ny);
  }

  void _paintRoseWindowBeams(Canvas canvas, Rect imageRect) {
    final topY = imageRect.top + imageRect.height * 0.15;
    final bottomY = imageRect.top + imageRect.height * 0.65;

    final beams = [
      (
        topLeft: 0.42,
        topRight: 0.49,
        bottomLeft: 0.21,
        bottomRight: 0.38,
        phase: 0.0,
        peakAlpha: isDark ? 0.068 : 0.045,
      ),
      (
        topLeft: 0.46,
        topRight: 0.55,
        bottomLeft: 0.37,
        bottomRight: 0.63,
        phase: 1.6,
        peakAlpha: isDark ? 0.052 : 0.036,
      ),
      (
        topLeft: 0.52,
        topRight: 0.59,
        bottomLeft: 0.61,
        bottomRight: 0.79,
        phase: 3.2,
        peakAlpha: isDark ? 0.064 : 0.042,
      ),
    ];

    for (final beam in beams) {
      final breath = 0.62 +
          0.38 * math.sin(progress * 2.0 * math.pi + beam.phase);
      final alpha = (beam.peakAlpha * breath).clamp(0.0, 0.12);
      if (alpha <= 0.005) continue;

      final path = Path()
        ..moveTo(imageRect.left + imageRect.width * beam.topLeft, topY)
        ..lineTo(imageRect.left + imageRect.width * beam.topRight, topY)
        ..lineTo(imageRect.left + imageRect.width * beam.bottomRight, bottomY)
        ..lineTo(imageRect.left + imageRect.width * beam.bottomLeft, bottomY)
        ..close();

      final shaderRect = Rect.fromLTRB(
        imageRect.left + imageRect.width * beam.bottomLeft,
        topY,
        imageRect.left + imageRect.width * beam.bottomRight,
        bottomY,
      );

      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF80DEEA).withValues(alpha: alpha * 0.35),
              const Color(0xFFE0F7FA).withValues(alpha: alpha),
              const Color(0xFFFFF8E1).withValues(alpha: alpha * 0.55),
              Colors.transparent,
            ],
            stops: const [0.0, 0.28, 0.72, 1.0],
          ).createShader(shaderRect),
      );
    }
  }

  void _paintWallTorches(Canvas canvas, Rect imageRect) {
    final baseAlpha = isDark ? 0.42 : 0.26;
    for (final torch in _torchSpecs) {
      final center = _imgPt(imageRect, torch.nx, torch.ny);
      final wave1 = math.sin(progress * 2.0 * math.pi * 3.0 + torch.seed);
      final wave2 = math.cos(progress * 2.0 * math.pi * 5.0 + torch.seed * 1.7);
      final flicker = (0.72 + 0.16 * wave1 + 0.12 * wave2).clamp(0.42, 1.0);
      final radius = torch.radius * (0.94 + 0.12 * flicker);
      final rect = Rect.fromCircle(center: center, radius: radius);

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFB300).withValues(alpha: baseAlpha * flicker),
              const Color(0xFFFF8F00)
                  .withValues(alpha: baseAlpha * 0.48 * flicker),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(rect),
      );
    }
  }

  void _paintAltarIncenseWisps(Canvas canvas, Rect imageRect) {
    final wispAlphaBase = isDark ? 0.18 : 0.12;
    final riseHeight = imageRect.height * 0.085;
    final wispPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    for (final brazier in _brazierSpecs) {
      final basePos = _imgPt(imageRect, brazier.nx, brazier.ny);
      for (final phase in _wispPhases) {
        final t = (progress + phase + brazier.sideSeed * 0.13) % 1.0;
        final fade = math.sin(t * math.pi).clamp(0.0, 1.0);
        final alpha = (wispAlphaBase * fade).clamp(0.0, 0.30);
        if (alpha <= 0.01) continue;

        final dx = math.sin(t * 2.0 * math.pi + brazier.sideSeed) *
            (3.5 + 3.0 * t);
        final dy = -riseHeight * t;
        final radius = 3.2 + 4.4 * t;
        final pos = Offset(basePos.dx + dx, basePos.dy + dy);

        wispPaint.color = Color.lerp(
          const Color(0xFFFFF8E1),
          const Color(0xFFE0F7FA),
          t,
        )!
            .withValues(alpha: alpha);
        canvas.drawCircle(pos, radius, wispPaint);
      }
    }
  }

  void _paintSacredDustMotes(Canvas canvas, Size size) {
    final baseAlpha = isDark ? 0.72 : 0.42;
    final haloPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
    final corePaint = Paint();

    for (final spec in _moteSpecs) {
      final t = (progress + spec.phase) % 1.0;
      final fade = math.sin(t * math.pi).clamp(0.0, 1.0);
      final alpha = (baseAlpha * fade).clamp(0.0, 1.0);
      if (alpha <= 0.02) continue;

      final y = size.height * (spec.yStart - spec.travel * t);
      final x = size.width * spec.x +
          math.sin(t * 2.0 * math.pi + spec.phase * 9.0) * spec.sway;
      final pos = Offset(x, y);

      final haloColor = spec.isGold
          ? const Color(0xFFFFE082)
          : const Color(0xFF00E5FF);
      final coreColor = spec.isGold
          ? const Color(0xFFFFF8E1)
          : const Color(0xFF80DEEA);

      haloPaint.color = haloColor.withValues(alpha: alpha * 0.48);
      canvas.drawCircle(pos, spec.radius * 2.3, haloPaint);

      corePaint.color = coreColor.withValues(alpha: alpha);
      canvas.drawCircle(pos, spec.radius, corePaint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final imageRect = _resolveCoveredImageRect(size);

    _paintRoseWindowBeams(canvas, imageRect);
    _paintWallTorches(canvas, imageRect);
    _paintAltarIncenseWisps(canvas, imageRect);
    _paintSacredDustMotes(canvas, size);
  }

  @override
  bool shouldRepaint(covariant TempleAtmospherePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}

class _OverchargedPointerRegion extends StatelessWidget {
  final bool enabled;
  final void Function(PointerDownEvent event) onPointerDown;
  final void Function(int pointerId) onPointerRelease;
  final Widget child;

  const _OverchargedPointerRegion({
    required this.enabled,
    required this.onPointerDown,
    required this.onPointerRelease,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: enabled ? onPointerDown : null,
      onPointerMove: enabled
          ? (event) {
              final renderObject = context.findRenderObject();
              if (renderObject is RenderBox && renderObject.hasSize) {
                final bounds = Offset.zero & renderObject.size;
                if (!bounds.contains(event.localPosition)) {
                  onPointerRelease(event.pointer);
                }
              }
            }
          : null,
      onPointerUp: (event) => onPointerRelease(event.pointer),
      onPointerCancel: (event) => onPointerRelease(event.pointer),
      child: child,
    );
  }
}

/// Renders a glowing golden/elemental circular charge ring that fills over the
/// 250ms hold threshold and pulses smoothly while Overcharged Staff rapid-fires.
class _OverchargedChargeRingPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final bool isRapidFiring;
  final Color primaryColor;

  const _OverchargedChargeRingPainter({
    required this.progress,
    required this.pulse,
    required this.isRapidFiring,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0.0) return;

    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.shortestSide * 0.49;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const gold = Color(0xFFF5C22B);
    final brightGold = Color.lerp(gold, Colors.white, isRapidFiring ? 0.25 + 0.25 * pulse : 0.15)!;
    final blendedGlow = Color.lerp(gold, primaryColor, 0.35)!;

    // Subtle background track ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = gold.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );

    const startAngle = -math.pi / 2.0;
    final sweepAngle = 2.0 * math.pi * clamped;

    // Outer radiant glow arc
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = blendedGlow.withValues(alpha: isRapidFiring ? 0.65 + 0.25 * pulse : 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isRapidFiring ? 5.6 + 2.0 * pulse : 5.0)
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          isRapidFiring ? 4.5 + 2.5 * pulse : 3.5,
        ),
    );

    // Crisp bright inner charge arc
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = brightGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isRapidFiring ? 3.2 + 0.8 * pulse : 2.8)
        ..strokeCap = StrokeCap.round,
    );

    // Leading spark dot while filling up to 250ms
    if (clamped < 0.999) {
      final tipAngle = startAngle + sweepAngle;
      final tipPos = Offset(
        center.dx + math.cos(tipAngle) * radius,
        center.dy + math.sin(tipAngle) * radius,
      );
      canvas.drawCircle(
        tipPos,
        3.2,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OverchargedChargeRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.isRapidFiring != isRapidFiring ||
        oldDelegate.primaryColor != primaryColor;
  }
}
