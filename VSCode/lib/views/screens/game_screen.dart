import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../models/story_chapter.dart';
import '../../services/ad_service.dart';
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
import '../dialogs/inventory_dialog.dart';
import '../dialogs/teleport_confirm_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../dialogs/story_dialog.dart';
import '../dialogs/victory_cutscene_dialog.dart';

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

  final GlobalKey _rootStackKey = GlobalKey();
  final GlobalKey _backpackKey = GlobalKey();
  final GlobalKey _pcSlotKey = GlobalKey();
  final GlobalKey _clashCenterKey = GlobalKey();

  late final AnimationController _flyingOrbController;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasCheckedForUpdate) return;
      _hasCheckedForUpdate = true;
      unawaited(context.read<GameController>().checkForUpdate());
    });
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
    }
  }

  @override
  void dispose() {
    _deathDialogTimer?.cancel();
    _deathDialogTimer = null;
    _flyingOrbController.dispose();
    _controller?.cancelPendingTimers();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    controller.audio.playTapVibrate();
    if (controller.userHp <= 0 || _isDeathSequenceActive) return;
    if (controller.confirmBattleTeleport) {
      final confirmed = await TeleportConfirmDialog.show(
        context,
        controller: controller,
      );
      if (!confirmed || !context.mounted) return;
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
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final controller = context.read<GameController>();
    controller.didChangeAppLifecycleState(state);
  }

  void _checkIntroStory(BuildContext context, GameController controller) {
    if (controller.pendingStoryChapter != StoryChapter.intro) {
      _isIntroDialogScheduled = false;
      return;
    }
    if (!_isIntroDialogScheduled && !controller.hasSeenStoryIntro) {
      _isIntroDialogScheduled = true;
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

  /// Modular handler for campaign week > 40 defeat events.
  /// Structured as a standalone entry point so a full multi-panel comic
  /// cutscene can be plugged in before executing [applyPermadeathReset].
  Future<void> _triggerWeek40KingdomFall(
    BuildContext context,
    GameController controller,
  ) async {
    if (_isKingdomFallDialogOpen || !mounted) return;
    _isKingdomFallDialogOpen = true;
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
                    const SizedBox(height: 10),
                    const Text('🏰🔥', style: TextStyle(fontSize: 34)),
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
                content: Text(
                  loc.t(
                    'kingdom_fall_body',
                    fallback:
                        'Time has run out. The Metal Wizard has taken over all neighboring kingdoms and destroyed the Cleric\'s kingdom!',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: palette.secondaryText,
                  ),
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
                              await controller.applyPermadeathReset();
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
                                      await controller.applyPermadeathReset();
                                      _isDeathDialogOpen = false;
                                      _isDeathSequenceActive = false;
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

  Widget _buildBossPhasePill(BuildContext context, GameController controller) {
    final palette = AppPalette.of(context);
    final phase = controller.enemyPhase;
    final bossName = controller.currentEnemyName;
    final Color accent;
    final IconData icon;
    if (phase == 2) {
      accent = const Color(0xFFCE93D8);
      icon = Icons.auto_fix_high_rounded;
    } else if (phase == 3) {
      accent = const Color(0xFFFF8A65);
      icon = Icons.bolt_rounded;
    } else {
      accent = const Color(0xFF4FC3F7);
      icon = Icons.shield_outlined;
    }
    return Container(
      key: ValueKey('boss_phase_pill_$phase'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.isDark
            ? Colors.black.withValues(alpha: 0.45)
            : palette.deckSurface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withValues(alpha: 0.72),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Phase $phase • $bossName (${controller.enemyMaxHp} HP)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: palette.isDark ? Colors.white : palette.primaryText,
              ),
            ),
          ),
        ],
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
    final defeatedPhase =
        controller.pendingBossVictoryPhase ?? controller.enemyPhase;
    final week = controller.pendingBossVictoryWeek ?? controller.currentWeek;

    final bool isSecretWeek1 = defeatedPhase == 1 && week == 1;
    final bool isEarlyRush =
        defeatedPhase == 1 && week >= 2 && week < GameController.phase2StartWeek;
    final bool isLatePhase1 =
        defeatedPhase == 1 && week >= GameController.phase2StartWeek;
    final bool isPhase2Defeat = defeatedPhase == 2;
    final bool isPhase3Defeat = defeatedPhase == 3;

    late final String emoji;
    late final Color accent;
    late final String title;
    late final String subtitle;
    late final String body;
    late final String buttonLabel;

    if (isSecretWeek1) {
      emoji = '👑';
      accent = const Color(0xFF00E5FF);
      title = loc.t(
        'boss_victory_p1_title',
        fallback: 'Guardian Robot Destroyed!',
      );
      subtitle = loc.t(
        'boss_victory_secret_w1_subtitle',
        fallback: 'Week 1 Lightning Victory!',
      );
      body = loc.t(
        'boss_victory_secret_w1_body',
        fallback:
            'You shattered the Guardian Robot immediately in Week 1 before the Metal Wizard could build any backup constructs! The Princess is rescued intact.',
      );
      buttonLabel = loc.t(
        'boss_victory_watch_cutscene_btn',
        fallback: 'Watch Ending Cutscene',
      );
    } else if (isEarlyRush) {
      emoji = '⚡🤖';
      accent = const Color(0xFFFF7043);
      title = loc.t(
        'boss_victory_p1_title',
        fallback: 'Guardian Robot Destroyed!',
      );
      subtitle = loc.t(
        'boss_victory_early_rush_subtitle',
        fallback: 'Panicked Metal Wizard Unleashes Prototype!',
      );
      body = loc.t(
        'boss_victory_early_rush_body',
        fallback:
            'Alert! Caught off-guard, the panicked Metal Wizard unleashes his chaotic prototype: Baby Mage Robot (400 HP, 5 elements, pure uniform random AI)!',
      );
      buttonLabel = loc.t(
        'boss_victory_face_baby_mage_btn',
        fallback: 'Face Baby Mage Robot',
      );
    } else if (isLatePhase1) {
      emoji = '🔮🤖';
      accent = const Color(0xFFAB47BC);
      title = loc.t(
        'boss_victory_p1_title',
        fallback: 'Guardian Robot Destroyed!',
      );
      subtitle = loc.t(
        'boss_victory_p2_spawn_subtitle',
        fallback: 'Phase 2: Robot Archmage Approaches!',
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
    } else if (isPhase2Defeat) {
      emoji = '⚡🤖';
      accent = const Color(0xFFFF7043);
      title = loc.t(
        'boss_victory_p2_defeated_title',
        fallback: 'Robot Archmage Destroyed!',
      );
      subtitle = loc.t(
        'boss_victory_p2_defeated_subtitle',
        fallback: 'Final Construct: Baby Mage Robot',
      );
      body = loc.t(
        'boss_victory_p2_defeated_body',
        fallback:
            'The Robot Archmage is destroyed! Desperate, the Metal Wizard deploys his final chaotic prototype: Baby Mage Robot (400 HP, 5 elements, pure random AI).',
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
        fallback: "Metal Wizard's Lair Defeated!",
      );
      body = loc.t(
        'boss_victory_p3_defeated_body',
        fallback:
            "The Baby Mage Robot has been destroyed and the Metal Wizard's lair is defeated! Standard Victory Ending unlocked.",
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

    if (isPhase3Defeat) {
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

  String _resolveBackgroundImage(GameController controller) {
    if (controller.lastWinner == null) {
      return 'assets/images/Splash.png';
    }
    switch (controller.lastWinner) {
      case RoundWinner.user:
        return 'assets/images/BGBlue.jpg';
      case RoundWinner.computer:
        return 'assets/images/BGRed.jpg';
      case RoundWinner.draw:
        return 'assets/images/BGDraw.jpg';
      case null:
        return 'assets/images/Splash.png';
    }
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
    return const Offset(24.0, 28.0);
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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final loc = controller.localization;
    final bgImage = _resolveBackgroundImage(controller);
    final inputsLocked = controller.userHp <= 0 ||
        controller.computerHp <= 0 ||
        controller.isBossVictoryPending ||
        controller.totalRounds >= controller.playerMaxMana ||
        _isDeathSequenceActive ||
        _isBossVictoryDialogOpen;

    _checkIntroStory(context, controller);
    _checkDeathAlert(context, controller);
    _checkBossVictoryAlert(context, controller);
    _check100RoundAlert(context, controller);
    _checkQaBonusSnackBar(context, controller);
    _checkUpdateSnackBar(context, controller);
    _checkFlyingOrbVfx(controller);

    return PopScope(
      canPop: false,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          centerTitle: false,
          automaticallyImplyLeading: false,
          leadingWidth: 48,
          leading: Center(
            child: SizedBox(
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
                        ? 1.0 + math.sin(pulseT * math.pi) * 0.24
                        : 1.0;
                    final pulseColor =
                        _lastAbsorbedOrbMove?.elementalPrimaryColor ??
                            Colors.amber;
                    final glowStrength =
                        isPulsing ? math.sin(pulseT * math.pi) : 0.0;

                    return Transform.scale(
                      scale: scale,
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: RpgBackpackIcon(
                          key: _backpackKey,
                          size: 28,
                          pulseColor: isPulsing ? pulseColor : null,
                          glowStrength: glowStrength,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        titleSpacing: 4,
        title: (controller.isRewardedAdReady && !controller.isRemoveAdsActive)
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: AdaptiveRewardedAdButton(
                        maxWidth: constraints.maxWidth,
                        onTap: () =>
                            _handleWatchRewardedAd(context, controller),
                        tooltip: controller.rewardedAdDescription,
                        label: AdService.rewardedAdButtonLabel,
                      ),
                    ),
                  );
                },
              )
            : null,
        actions: [
          // Periodic Gift button (unlocked & enabled in Shop, and cooldown ready)
          if (controller.shouldShowGiftBox)
            IconButton(
              key: const ValueKey('gift_box_button'),
              icon: const Text('🎁', style: TextStyle(fontSize: 22)),
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
          // Reset action button in AppBar when unlocked & active
          if (controller.showReset)
            IconButton(
              icon: const Icon(Icons.restart_alt, color: Colors.redAccent),
              tooltip: loc.t('string53', fallback: 'RESET'),
              onPressed: () => _confirmReset(context, controller, loc),
            ),
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              key: const ValueKey('teleport_portal_button'),
              padding: EdgeInsets.zero,
              iconSize: 28,
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
                width: 28,
                height: 28,
                child: RpgTeleportPortalIcon(size: 28),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => SettingsDialog(controller: controller),
              );
            },
          ),
        ],
      ),
      body: Stack(
        key: _rootStackKey,
        children: [
          // Dynamic Background Image with Animated Fade Transition
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: controller.animationsEnabled
                  ? const Duration(milliseconds: 600)
                  : Duration.zero,
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

          // Contrast Overlay for clear text legibility
          Positioned.fill(
            child: Container(
              color: (controller.darkMode ? Colors.black : Colors.black54)
                  .withValues(alpha: controller.darkMode ? 0.65 : 0.45),
            ),
          ),

          // Main Game Layout: Scrollable Upper Region + Pinned Bottom Move-Selection Deck + Safe Bottom Banner Area
          SafeArea(
            child: Column(
              children: [
                // 1. Scrollable Upper Region (ScoreHeader, HintsBar, VersusArena, MarkovMatrixView)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, viewportConstraints) {
                      final hasVisibleHints = controller.showYourPrediction ||
                          controller.showNextMove ||
                          controller.showSuggestion ||
                          controller.showCrystalBall;

                      return SingleChildScrollView(
                        key: const ValueKey('game_upper_scroll_view'),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 480,
                              minHeight: (viewportConstraints.maxHeight - 20)
                                  .clamp(0.0, double.infinity),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Scoreboard & Predictability Gauge Header (hidden unless unlocked & enabled)
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  child: AnimatedSwitcher(
                                    duration: controller.animationsEnabled
                                        ? const Duration(milliseconds: 250)
                                        : Duration.zero,
                                    child: (controller.unlockedPredictability &&
                                            controller.showPredictability)
                                        ? Padding(
                                            key: const ValueKey(
                                              'score_header_visible',
                                            ),
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
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
                                if (hasVisibleHints) const SizedBox(height: 8),

                                // Compact Boss Phase Indicator Pill
                                _buildBossPhasePill(context, controller),
                                const SizedBox(height: 6),

                                // Versus Arena: Classic Hand-Lunge (New Skin OFF) or Stationary Orbs + Projectile Clash VFX (New Skin ON)
                                VersusArena(
                                  userMove: controller.currentUserMove,
                                  computerMove: controller.currentComputerMove,
                                  winner: controller.lastWinner,
                                  localization: loc,
                                  animationsEnabled:
                                      controller.animationsEnabled,
                                  roundId: controller.turnCount,
                                  userHp: controller.userHp,
                                  playerMaxHp: controller.playerMaxHp,
                                  computerHp: controller.computerHp,
                                  computerMaxHp: controller.enemyMaxHp,
                                  remainingMana: controller.remainingMana,
                                  maxMana: controller.playerMaxMana,
                                  elementalMode: controller.isElementalMode,
                                  userDamageAmount:
                                      controller.bossWinDamageToPlayer,
                                  computerDamageAmount:
                                      controller.playerWinDamageToBoss,
                                  isPhase2: controller.enemyUses5Elements,
                                  pcSlotKey: _pcSlotKey,
                                  clashCenterKey: _clashCenterKey,
                                  onImpactHaptic: controller.isElementalMode
                                      ? controller.audio.playTapVibrate
                                      : null,
                                ),

                                // Live Markov Transition Matrix (if unlocked & enabled)
                                if (controller.showAlgorithm) ...[
                                  const SizedBox(height: 12),
                                  MarkovMatrixView(
                                    engine: controller.engine,
                                    lastUserMove: controller.lastUserMove,
                                    elementalMode: controller.isElementalMode,
                                    localization: loc,
                                    isArchmageShortTermView:
                                        controller.isArchmageBoss &&
                                        controller.isMarkovRecalibratorActive,
                                    isBabyMageRandomView:
                                        controller.isBabyMageBoss,
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

                // 2. Pinned Bottom Controls (Move Selection Card)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
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
                                color: palette.amberBorder.withValues(
                                  alpha: palette.isDark ? 0.25 : 0.45,
                                ),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: palette.isDark ? 0.45 : 0.22,
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
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.surface.withValues(alpha: 0.94)
                                  : palette.deckSurface,
                              surfaceTintColor:
                                  palette.isDark ? null : Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 10,
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
                                          _HandActionButton(
                                            key: ValueKey(
                                              'hand_button_${move.name}',
                                            ),
                                            move: move,
                                            compact: controller.showNewHands,
                                            elementalMode:
                                                controller.isElementalMode,
                                            isSelected:
                                                controller.currentUserMove ==
                                                move,
                                            localization: loc,
                                            animationsEnabled:
                                                controller.animationsEnabled,
                                            onPressed: inputsLocked
                                                ? null
                                                : () =>
                                                    controller.playTurn(move),
                                          ),
                                      ],
                                    ),

                                    // Optional Random move button (if unlocked & enabled)
                                    if (controller.showRandom) ...[
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          key: const ValueKey(
                                            'random_move_button',
                                          ),
                                          onPressed: inputsLocked
                                              ? null
                                              : controller.playRandom,
                                          icon: const Icon(
                                            Icons.casino_outlined,
                                            size: 18,
                                          ),
                                          label: Text(
                                            loc.t(
                                              'string16',
                                              fallback: 'RANDOM MOVE',
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: palette.isDark
                                                ? null
                                                : palette.amberText,
                                            backgroundColor: palette.isDark
                                                ? null
                                                : palette.dialogCardSurface,
                                            side: palette.isDark
                                                ? null
                                                : BorderSide(
                                                    color: palette.amberBorder
                                                        .withValues(alpha: 0.65),
                                                  ),
                                            visualDensity: VisualDensity.compact,
                                            tapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
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
                                child: Icon(
                                  orbMove.elementalIcon,
                                  size: 15,
                                  color: Colors.white,
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
              child: Icon(
                move.elementalIcon,
                size: 13,
                color: Colors.white,
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
                      color: palette.isDark
                          ? const Color(0xFF23171B)
                          : const Color(0xFFFDF0EE),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: palette.dangerText.withValues(
                          alpha: palette.isDark ? 0.45 : 0.35,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localization.t(
                            'reset_orbs_lost_header',
                            fallback: 'Elemental Orbs that will be lost:',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: palette.dangerText,
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
  final VoidCallback? onPressed;

  const _HandActionButton({
    super.key,
    required this.move,
    this.compact = false,
    this.elementalMode = false,
    this.isSelected = false,
    required this.localization,
    required this.animationsEnabled,
    required this.onPressed,
  });

  @override
  State<_HandActionButton> createState() => _HandActionButtonState();
}

class _HandActionButtonState extends State<_HandActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

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
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTap() {
    final onPressed = widget.onPressed;
    if (onPressed == null) return;
    // Execute the game turn immediately with zero delay
    onPressed();

    // Trigger visual scale animation asynchronously only if animations are enabled
    if (widget.animationsEnabled) {
      _pressController.stop();
      _pressController.forward(from: 0.0).then((_) {
        if (mounted) {
          _pressController.reverse().catchError((_) {});
        }
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final hasAsset = widget.move.leftAsset.isNotEmpty;
    final compact = widget.compact;
    final elemental = widget.elementalMode;
    final isSelected = widget.isSelected;
    final bool isEarth = widget.move == HandMove.lizard;
    final primaryColor = widget.move.elementalPrimaryColor;
    final secondaryColor = widget.move.elementalSecondaryColor;
    final elementLabelColor = palette.elementalText(widget.move);
    final Color earthIconColor =
        isSelected ? const Color(0xFFE29E5A) : const Color(0xFFD68C45);

    final horizontalPadding = compact ? 6.0 : 14.0;
    final verticalPadding = compact ? 8.0 : 10.0;
    final borderRadius = compact ? 12.0 : 16.0;
    final circleSize = compact ? 38.0 : 52.0;
    final imageSize = compact ? 26.0 : 36.0;
    final emojiFontSize = compact ? 20.0 : 26.0;
    final iconSize = compact ? 22.0 : 30.0;
    final labelSpacing = compact ? 4.0 : 6.0;
    final labelFontSize = compact ? 9.5 : 12.0;
    final letterSpacing = compact ? 0.2 : 0.5;

    final String buttonLabel = elemental
        ? widget.move
              .displayLabel(elemental: true, localization: widget.localization)
              .toUpperCase()
        : widget.move.label.toUpperCase();

    final BoxDecoration orbDecoration = elemental
        ? BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: isEarth
                  ? const Alignment(-0.24, -0.24)
                  : const Alignment(-0.2, -0.2),
              radius: 0.88,
              colors: isEarth
                  ? [
                      Color.lerp(
                        const Color(0xFF3D220E),
                        const Color(0xFFE29E5A),
                        isSelected ? 0.28 : 0.16,
                      )!,
                      Color.lerp(
                        const Color(0xFF3D220E),
                        secondaryColor,
                        isSelected ? 0.90 : 0.72,
                      )!,
                      primaryColor.withValues(alpha: isSelected ? 0.96 : 0.85),
                    ]
                  : [
                      const Color(0xFF0A0C12),
                      Color.lerp(
                        const Color(0xFF0E121B),
                        secondaryColor,
                        isSelected ? 0.55 : 0.38,
                      )!,
                      primaryColor.withValues(alpha: isSelected ? 0.92 : 0.72),
                    ],
              stops: const [0.0, 0.58, 1.0],
            ),
            border: Border.all(
              color: isSelected
                  ? (isEarth
                        ? Color.lerp(primaryColor, const Color(0xFFE29E5A), 0.55)!
                        : Color.lerp(primaryColor, Colors.white, 0.45)!)
                  : primaryColor.withValues(alpha: isEarth ? 0.88 : 0.75),
              width: isSelected ? 2.2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: isSelected ? 0.65 : 0.38),
                blurRadius: isSelected ? 12 : 8,
                spreadRadius: isSelected ? 2.0 : 1.0,
              ),
            ],
          )
        : BoxDecoration(
            color: palette.isDark
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : palette.amberBorder.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          );

    Widget buttonContent = InkWell(
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
                    ? const Color(0xFF10131C).withValues(alpha: 0.85)
                    : palette.elementalCardBackground(widget.move))
              : (palette.isDark
                    ? theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      )
                    : palette.sandCardSurface),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: elemental
                ? (palette.isDark
                      ? primaryColor.withValues(alpha: isSelected ? 0.75 : 0.45)
                      : elementLabelColor.withValues(
                          alpha: isSelected ? 0.85 : 0.48,
                        ))
                : (palette.isDark
                      ? theme.colorScheme.outline.withValues(alpha: 0.2)
                      : palette.sandCardBorder),
            width: elemental && isSelected ? 1.5 : 1.0,
          ),
          boxShadow: elemental && isSelected
              ? [
                  BoxShadow(
                    color: (palette.isDark ? primaryColor : elementLabelColor)
                        .withValues(alpha: palette.isDark ? 0.25 : 0.18),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              key: ValueKey('hand_orb_${widget.move.name}'),
              width: circleSize,
              height: circleSize,
              decoration: orbDecoration,
              child: Center(
                child: elemental
                    ? Icon(
                        widget.move.elementalIcon,
                        size: iconSize,
                        color: isEarth ? earthIconColor : primaryColor,
                        shadows: [
                          Shadow(
                            color: primaryColor.withValues(alpha: 0.75),
                            blurRadius: 8,
                          ),
                        ],
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
            ),
            SizedBox(height: labelSpacing),
            Text(
              buttonLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: labelFontSize,
                letterSpacing: letterSpacing,
                color: elemental
                    ? elementLabelColor
                    : (palette.isDark ? null : palette.primaryText),
              ),
            ),
          ],
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
