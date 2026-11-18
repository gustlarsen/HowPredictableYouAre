import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../models/story_chapter.dart';
import '../../services/ad_service.dart';
import '../../services/localization_service.dart';
import '../../services/play_games_service.dart';
import '../../services/update_service.dart';
import '../widgets/score_header.dart';
import '../widgets/hints_bar.dart';
import '../widgets/versus_arena.dart';
import '../widgets/markov_matrix_view.dart';
import '../widgets/rpg_backpack_icon.dart';
import '../widgets/adaptive_rewarded_ad_button.dart';
import '../dialogs/inventory_dialog.dart';
import '../dialogs/shop_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../dialogs/story_dialog.dart';

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
    }
  }

  @override
  void dispose() {
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
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

  void _check100RoundAlert(BuildContext context, GameController controller) {
    if (controller.is100RoundsAlertPending) {
      controller.is100RoundsAlertPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
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

            return PopScope(
              canPop: false,
              child: AlertDialog(
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${loc.t('string2', fallback: 'You are:')} '
                    '${loc.t(tier.key, fallback: tier.fallbackDescription)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI Predictability Score: ${pct.toStringAsFixed(1)}%\n'
                    'Your Wins: ${controller.userScore} | PC Wins: ${controller.pcScore}',
                    style: const TextStyle(height: 1.4),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    controller.resetGame();
                  },
                  child: Text(
                    loc.t('string76', fallback: 'TRY AGAIN'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
          },
        );
      });
    }
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

    _checkIntroStory(context, controller);
    _check100RoundAlert(context, controller);
    _checkQaBonusSnackBar(context, controller);
    _checkUpdateSnackBar(context, controller);
    _checkFlyingOrbVfx(controller);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
        title: controller.isRewardedAdReady
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
                        tooltip: loc.t(
                          'rewarded_ad_desc',
                          fallback:
                              'Watch a video ad for +50 of each Elemental Orb',
                        ),
                        label: AdService.rewardedAdButtonLabel,
                      ),
                    ),
                  );
                },
              )
            : null,
        actions: [
          // Periodic Gift button (matching Kodular ButtonGift / Clock1)
          if (controller.isGiftAvailable)
            IconButton(
              icon: const Text('🎁', style: TextStyle(fontSize: 22)),
              tooltip: loc.t(
                'gift_tooltip',
                fallback: 'Claim Free +5 Elemental Orbs Gift',
              ),
              onPressed: () {
                controller.claimGift();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      loc.t(
                        'gift_claimed_msg',
                        fallback: '🎁 +5 Elemental Orbs Gift Claimed!',
                      ),
                    ),
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
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Shop',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ShopDialog(controller: controller),
              );
            },
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
                                  computerHp: controller.computerHp,
                                  elementalMode: controller.isElementalMode,
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
                      child: Container(
                        key: const ValueKey('move_selection_card'),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.25),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 12,
                              spreadRadius: 1,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.94),
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
                                            controller.currentUserMove == move,
                                        localization: loc,
                                        animationsEnabled:
                                            controller.animationsEnabled,
                                        onPressed: () =>
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
                                      key: const ValueKey('random_move_button'),
                                      onPressed: controller.playRandom,
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
                                        visualDensity: VisualDensity.compact,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
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
                                    Colors.white,
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
            const SnackBar(
              content: Text(GameController.rewardedAdSnackBarMessage),
              duration: Duration(seconds: 2),
            ),
          );
      },
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    GameController controller,
    LocalizationService localization,
  ) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localization.t('string53', fallback: 'RESET')),
        content: const Text(
          'This will clear your scores and prediction history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localization.t('string53', fallback: 'RESET')),
          ),
        ],
      ),
    );

    if (shouldReset == true) {
      controller.resetGame();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Game and prediction matrix have been reset!'),
            duration: Duration(seconds: 2),
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
  final VoidCallback onPressed;

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
    // Execute the game turn immediately with zero delay
    widget.onPressed();

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
    final hasAsset = widget.move.leftAsset.isNotEmpty;
    final compact = widget.compact;
    final elemental = widget.elementalMode;
    final isSelected = widget.isSelected;
    final primaryColor = widget.move.elementalPrimaryColor;
    final secondaryColor = widget.move.elementalSecondaryColor;

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
              center: const Alignment(-0.2, -0.2),
              radius: 0.88,
              colors: [
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
                  ? Color.lerp(primaryColor, Colors.white, 0.45)!
                  : primaryColor.withValues(alpha: 0.75),
              width: isSelected ? 2.2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: isSelected ? 0.65 : 0.35),
                blurRadius: isSelected ? 12 : 8,
                spreadRadius: isSelected ? 2.0 : 1.0,
              ),
            ],
          )
        : BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          );

    Widget buttonContent = InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: elemental
              ? const Color(0xFF10131C).withValues(alpha: 0.85)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: elemental
                ? primaryColor.withValues(alpha: isSelected ? 0.7 : 0.35)
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: elemental && isSelected ? 1.5 : 1.0,
          ),
          boxShadow: elemental && isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.25),
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
                        color: primaryColor,
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
                color: elemental ? primaryColor : null,
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
