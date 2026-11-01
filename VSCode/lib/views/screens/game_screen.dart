import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../services/localization_service.dart';
import '../widgets/score_header.dart';
import '../widgets/hints_bar.dart';
import '../widgets/versus_arena.dart';
import '../widgets/markov_matrix_view.dart';
import '../dialogs/shop_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../dialogs/help_dialog.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final controller = context.read<GameController>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller.audio.pauseMusic();
    } else if (state == AppLifecycleState.resumed) {
      controller.audio.resumeMusic();
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

            if (pct == 0) {
              alertTitle = loc.t('string70', fallback: 'You Won!!!');
              alertSubtitle = loc.t('string71', fallback: 'You are the Best Predictor Ever!!!');
              emoji = '👑';
            } else if (pct < 50) {
              alertTitle = loc.t('string72', fallback: 'Not so Bad!!!');
              alertSubtitle = loc.t('string73', fallback: 'Now try to achieve 100%');
              emoji = '🙂';
            } else {
              alertTitle = loc.t('string74', fallback: 'You Lose!!!');
              alertSubtitle = loc.t('string75', fallback: 'Try harder next time...');
              emoji = '🙁';
            }

            return AlertDialog(
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
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    controller.resetGame();
                  },
                  child: Text(
                    loc.t('string76', fallback: 'TRY AGAIN'),
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(loc.t('string77', fallback: 'CONTINUE')),
                ),
              ],
            );
          },
        );
      });
    }
  }

  String _resolveBackgroundImage(GameController controller) {
    if (controller.totalRounds == 0 || controller.lastWinner == null) {
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

    _check100RoundAlert(context, controller);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'How Predictable You Are',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
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
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => HelpDialog(localization: loc),
              );
            },
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
              duration: const Duration(milliseconds: 600),
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

          // Main Scrollable Game Layout
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      // Score & Diamonds Header
                      ScoreHeader(controller: controller),
                      const SizedBox(height: 10),

                      // Unlocked Hint Pills (Prediction, Next move, Suggestion)
                      HintsBar(controller: controller),
                      const SizedBox(height: 10),

                      // Versus Arena with Punch & 360 Spin Animations
                      VersusArena(
                        userMove: controller.currentUserMove,
                        computerMove: controller.currentComputerMove,
                        winner: controller.lastWinner,
                        localization: loc,
                        animationsEnabled: controller.animationsEnabled,
                        roundId: controller.totalRounds,
                      ),
                      const SizedBox(height: 14),

                      // Live Markov Transition Matrix (if unlocked & enabled)
                      if (controller.showAlgorithm) ...[
                        MarkovMatrixView(
                          engine: controller.engine,
                          lastUserMove: controller.lastUserMove,
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
                              // RESET BUTTON: Positioned prominently ABOVE hand moves (matching Kodular Horizontal_Arrangement12)
                              if (controller.showReset) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        side: const BorderSide(color: Colors.redAccent, width: 1.5),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: () => _confirmReset(context, controller, loc),
                                      icon: const Icon(Icons.restart_alt, color: Colors.redAccent, size: 20),
                                      label: Text(
                                        loc.t('string53', fallback: 'RESET').toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              // Extended hands row (Lizard / Spock) if enabled
                              if (controller.showNewHands) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _HandActionButton(
                                      move: HandMove.lizard,
                                      vibrationEnabled: controller.vibrationEnabled,
                                      onPressed: () =>
                                          controller.playTurn(HandMove.lizard),
                                    ),
                                    const SizedBox(width: 12),
                                    _HandActionButton(
                                      move: HandMove.spock,
                                      vibrationEnabled: controller.vibrationEnabled,
                                      onPressed: () =>
                                          controller.playTurn(HandMove.spock),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Standard RPS moves row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _HandActionButton(
                                    move: HandMove.rock,
                                    vibrationEnabled: controller.vibrationEnabled,
                                    onPressed: () =>
                                        controller.playTurn(HandMove.rock),
                                  ),
                                  _HandActionButton(
                                    move: HandMove.paper,
                                    vibrationEnabled: controller.vibrationEnabled,
                                    onPressed: () =>
                                        controller.playTurn(HandMove.paper),
                                  ),
                                  _HandActionButton(
                                    move: HandMove.scissors,
                                    vibrationEnabled: controller.vibrationEnabled,
                                    onPressed: () =>
                                        controller.playTurn(HandMove.scissors),
                                  ),
                                ],
                              ),

                              // Optional Random move button (if unlocked & enabled)
                              if (controller.showRandom) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      if (controller.vibrationEnabled) {
                                        HapticFeedback.selectionClick();
                                      }
                                      controller.playRandom();
                                    },
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
                                        borderRadius: BorderRadius.circular(12),
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
        ],
      ),
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
  final bool vibrationEnabled;
  final VoidCallback onPressed;

  const _HandActionButton({
    required this.move,
    required this.vibrationEnabled,
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

  void _handleTap() async {
    if (widget.vibrationEnabled) {
      HapticFeedback.selectionClick();
    }
    await _pressController.forward();
    await _pressController.reverse();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAsset = widget.move.leftAsset.isNotEmpty;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: hasAsset
                      ? Image.asset(
                          widget.move.leftAsset,
                          width: 36,
                          height: 36,
                          errorBuilder: (context, error, stackTrace) => Text(
                            widget.move.emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        )
                      : Text(
                          widget.move.emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.move.label.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
