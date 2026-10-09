import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/move.dart';
import '../../services/localization_service.dart';

class VersusArena extends StatefulWidget {
  final HandMove? userMove;
  final HandMove? computerMove;
  final RoundWinner? winner;
  final LocalizationService localization;
  final bool animationsEnabled;
  final int roundId;

  const VersusArena({
    super.key,
    required this.userMove,
    required this.computerMove,
    required this.winner,
    required this.localization,
    required this.animationsEnabled,
    required this.roundId,
  });

  @override
  State<VersusArena> createState() => _VersusArenaState();
}

class _VersusArenaState extends State<VersusArena> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _rotationAnim;
  late Animation<double> _punchAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Rotation spin for defeated / draw hand, timed to start on impact
    _rotationAnim = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.9, curve: Curves.easeInOutCubic),
      ),
    );

    // Forward punch to center (near VS letters), impact hold, and return
    _punchAnim = TweenSequence<double>([
      // 1. Fast forward thrust towards VS letters (0 - 35% time)
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      // 2. Impact hold near VS letters (35 - 55% time)
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 20,
      ),
      // 3. Return smoothly to starting position (55 - 100% time)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 45,
      ),
    ]).animate(_animController);

    if (widget.roundId > 0 && widget.animationsEnabled) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant VersusArena oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.roundId != oldWidget.roundId && widget.roundId > 0) {
      if (widget.animationsEnabled) {
        _animController.forward(from: 0.0);
      } else {
        _animController.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final winner = widget.winner;

    Color outcomeColor;
    String outcomeText;
    switch (winner) {
      case RoundWinner.user:
        outcomeColor = Colors.green;
        outcomeText = widget.localization.t('string51', fallback: 'YOU');
        break;
      case RoundWinner.computer:
        outcomeColor = Colors.redAccent;
        outcomeText = widget.localization.t('string50', fallback: 'PC');
        break;
      case RoundWinner.draw:
        outcomeColor = Colors.amber;
        outcomeText = 'DRAW';
        break;
      case null:
        outcomeColor = Colors.grey;
        outcomeText = widget.localization.t('string20', fallback: 'NONE');
        break;
    }

    final userWins = winner == RoundWinner.user;
    final pcWins = winner == RoundWinner.computer;
    final isDraw = winner == RoundWinner.draw;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate dynamic travel distance to move hand almost to the VS letters
        // Available width inside arena padding (padding: 20 on each side = 40)
        final innerWidth = constraints.maxWidth - 40.0;
        // Total width of the 3 components: Left Card (86) + VS Badge (56) + Right Card (86) = 228
        const totalItemsWidth = 228.0;
        final availableSpace = (innerWidth - totalItemsWidth).clamp(24.0, 400.0);
        // Gap between outer card edge and center VS badge edge
        final gap = availableSpace / 3.0;
        // Punch moves across the gap, stopping ~8px before touching the VS badge
        final punchDistance = (gap - 8.0).clamp(36.0, 150.0);

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: winner != null ? outcomeColor.withValues(alpha: 0.7) : theme.dividerColor,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: winner != null ? outcomeColor.withValues(alpha: 0.25) : Colors.black26,
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // User Move: lunges to center near VS, or spins 360 if defeated
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      Widget animatedChild = child!;

                      if (widget.animationsEnabled && widget.roundId > 0) {
                        if (userWins) {
                          // Winner lunges forward towards the VS center
                          animatedChild = Transform.translate(
                            offset: Offset(_punchAnim.value * punchDistance, 0),
                            child: animatedChild,
                          );
                        } else if (pcWins || isDraw) {
                          // Defeated or Draw hand spins 360 degrees
                          animatedChild = Transform.rotate(
                            angle: _rotationAnim.value,
                            child: animatedChild,
                          );
                        }
                      }

                      return animatedChild;
                    },
                    child: _MoveCard(
                      label: widget.localization.t('string9', fallback: 'You Chose:'),
                      move: widget.userMove,
                      isLeft: true,
                      isWinner: userWins,
                    ),
                  ),

                  // VS center badge with fixed width for precise alignment
                  SizedBox(
                    width: 56,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Computer Move: lunges to center near VS, or spins 360 if defeated
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      Widget animatedChild = child!;

                      if (widget.animationsEnabled && widget.roundId > 0) {
                        if (pcWins) {
                          // Winner lunges forward towards the VS center (negative X)
                          animatedChild = Transform.translate(
                            offset: Offset(-(_punchAnim.value * punchDistance), 0),
                            child: animatedChild,
                          );
                        } else if (userWins || isDraw) {
                          // Defeated or Draw hand spins 360 degrees
                          animatedChild = Transform.rotate(
                            angle: -_rotationAnim.value,
                            child: animatedChild,
                          );
                        }
                      }

                      return animatedChild;
                    },
                    child: _MoveCard(
                      label: widget.localization.t('string52', fallback: 'PC Chose:'),
                      move: widget.computerMove,
                      isLeft: false,
                      isWinner: pcWins,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Winner Announcement Banner
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    '${widget.localization.t('string10', fallback: 'Winner')}:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: outcomeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: outcomeColor, width: 1.5),
                    ),
                    child: Text(
                      outcomeText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: outcomeColor,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MoveCard extends StatelessWidget {
  final String label;
  final HandMove? move;
  final bool isLeft;
  final bool isWinner;

  const _MoveCard({
    required this.label,
    required this.move,
    required this.isLeft,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = isLeft ? move?.leftAsset : move?.rightAsset;
    final hasAsset = assetPath != null && assetPath.isNotEmpty;

    return SizedBox(
      width: 86,
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: isWinner
                  ? Colors.green.withValues(alpha: 0.2)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(
                color: isWinner ? Colors.green : Colors.white24,
                width: isWinner ? 3 : 1.5,
              ),
              boxShadow: isWinner
                  ? [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: move == null
                  ? const Text('?', style: TextStyle(fontSize: 34, color: Colors.grey))
                  : hasAsset
                      ? Image.asset(
                          assetPath,
                          width: 58,
                          height: 58,
                          errorBuilder: (context, error, stackTrace) => Text(
                            move!.emoji,
                            style: const TextStyle(fontSize: 38),
                          ),
                        )
                      : Text(
                          move!.emoji,
                          style: const TextStyle(fontSize: 38),
                        ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            move?.label.toUpperCase() ?? 'NONE',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
