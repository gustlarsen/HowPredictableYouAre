import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../models/story_chapter.dart';
import '../../services/ad_service.dart';
import '../../services/localization_service.dart';
import '../widgets/score_header.dart';
import '../widgets/hints_bar.dart';
import '../widgets/versus_arena.dart';
import '../widgets/markov_matrix_view.dart';
import '../dialogs/shop_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../dialogs/story_dialog.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  bool _isIntroDialogScheduled = false;
  GameController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = context.read<GameController>();
  }

  @override
  void dispose() {
    _controller?.cancelPendingTimers();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final loc = controller.localization;
    final bgImage = _resolveBackgroundImage(controller);

    _checkIntroStory(context, controller);
    _check100RoundAlert(context, controller);
    _checkQaBonusSnackBar(context, controller);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💎', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  '${controller.diamonds}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Voluntary Rewarded Video Ad ("Watch Ad +50 💎") button with explicit disclosure,
          // shown only when a rewarded ad is preloaded and not on cooldown
          if (controller.isRewardedAdReady)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Tooltip(
                message: 'Watch a video ad to earn +50 💎',
                child: InkWell(
                  key: const ValueKey('watch_rewarded_ad_button'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _handleWatchRewardedAd(context, controller),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.55),
                      ),
                    ),
                    child: const Text(
                      AdService.rewardedAdButtonLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Periodic Gift button (matching Kodular ButtonGift / Clock1)
          if (controller.isGiftAvailable)
            IconButton(
              icon: const Text('🎁', style: TextStyle(fontSize: 22)),
              tooltip: 'Claim Free 5 💎 Gift',
              onPressed: () {
                controller.claimGift();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎁 +5 💎 Gift Claimed!'),
                    duration: Duration(seconds: 2),
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

          // Main Scrollable Game Layout + Safe Bottom Banner Area
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          controller.shouldShowBannerAd ? 24 : 12,
                        ),
                        child: Column(
                          children: [
                            // Score & Diamonds Header
                            ScoreHeader(controller: controller),
                            const SizedBox(height: 10),

                            // Unlocked Hint Pills (Prediction, Next move, Suggestion)
                            HintsBar(controller: controller),
                            const SizedBox(height: 10),

                            // Versus Arena: Classic Hand-Lunge (New Skin OFF) or Stationary Orbs + Projectile Clash VFX (New Skin ON)
                            VersusArena(
                              userMove: controller.currentUserMove,
                              computerMove: controller.currentComputerMove,
                              winner: controller.lastWinner,
                              localization: loc,
                              animationsEnabled: controller.animationsEnabled,
                              roundId: controller.turnCount,
                              userHp: controller.userHp,
                              computerHp: controller.computerHp,
                              elementalMode: controller.isElementalMode,
                              onImpactHaptic: controller.isElementalMode
                                  ? controller.audio.playTapVibrate
                                  : null,
                            ),
                            const SizedBox(height: 14),

                            // Live Markov Transition Matrix (if unlocked & enabled)
                            if (controller.showAlgorithm) ...[
                              MarkovMatrixView(
                                engine: controller.engine,
                                lastUserMove: controller.lastUserMove,
                                elementalMode: controller.isElementalMode,
                                localization: loc,
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Move Controls Section
                            Card(
                              elevation: 4,
                              color: Theme.of(
                                context,
                              ).colorScheme.surface.withValues(alpha: 0.9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 10,
                                ),
                                child: Column(
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
                                            onPressed: () =>
                                                controller.playTurn(move),
                                          ),
                                      ],
                                    ),

                                    // Optional Random move button (if unlocked & enabled)
                                    if (controller.showRandom) ...[
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Banner Ad: placed at the very bottom inside SafeArea with generous top spacing
                if (controller.shouldShowBannerAd)
                  Padding(
                    key: const ValueKey('bottom_banner_ad_container'),
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: Center(
                      child: controller.adService.buildBannerWidget(),
                    ),
                  ),
              ],
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
