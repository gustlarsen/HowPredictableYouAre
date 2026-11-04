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

class _VersusArenaState extends State<VersusArena>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _punchAnim;
  late Animation<double> _defeatRotationAnim;
  late Animation<double> _drawRotationAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Winning hand moves directly over the opponent (0.0 -> 1.0) and smoothly returns (1.0 -> 0.0)
    _punchAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 6,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 52,
      ),
    ]).animate(_animController);

    // Opponent makes a 360° rotation once the winning hand arrives directly over it
    _defeatRotationAnim = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.36, 0.95, curve: Curves.easeInOutCubic),
      ),
    );

    // Draw 360° rotation for both hands
    _drawRotationAnim = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.90, curve: Curves.easeInOutCubic),
      ),
    );

    if (widget.roundId > 0 && widget.animationsEnabled) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant VersusArena oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animationsEnabled) {
      if (_animController.isAnimating || _animController.value != 0.0) {
        _animController.stop();
        _animController.reset();
      }
      return;
    }

    if (widget.roundId != oldWidget.roundId) {
      // Immediately stop any active animation, return to initial position (0.0), and restart
      _animController.stop();
      _animController.reset();
      if (widget.roundId > 0) {
        _animController.forward(from: 0.0);
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: winner != null
              ? outcomeColor.withValues(alpha: 0.7)
              : theme.dividerColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: winner != null
                ? outcomeColor.withValues(alpha: 0.25)
                : Colors.black26,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const cardWidth = 86.0;
              const vsWidth = 56.0;
              const totalItemsWidth = cardWidth * 2 + vsWidth;
              final rowWidth = constraints.maxWidth;
              final freeSpace = math.max(0.0, rowWidth - totalItemsWidth);
              final spaceUnit = freeSpace / 3.0;

              final leftX = 0.5 * spaceUnit;
              final rightX = 2.5 * spaceUnit + cardWidth + vsWidth;
              // Exact center-to-center distance so the winning hand moves directly over the opponent
              final targetDistance = rightX - leftX;

              final vsBadge = Align(
                key: const ValueKey('vs_badge'),
                alignment: Alignment.center,
                child: SizedBox(
                  width: vsWidth,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
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
              );

              final userCard = Align(
                key: const ValueKey('user_card'),
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: leftX),
                  child: _MoveCard(
                    label: widget.localization.t(
                      'string9',
                      fallback: 'You Chose:',
                    ),
                    move: widget.userMove,
                    isLeft: true,
                    isWinner: userWins,
                    handBuilder: (context, handWidget) {
                      return AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          Widget animatedChild = child!;
                          if (widget.animationsEnabled && widget.roundId > 0) {
                            if (userWins) {
                              animatedChild = Transform.translate(
                                offset: Offset(
                                  _punchAnim.value * targetDistance,
                                  0,
                                ),
                                child: animatedChild,
                              );
                            } else if (pcWins) {
                              animatedChild = Transform.rotate(
                                angle: _defeatRotationAnim.value,
                                child: animatedChild,
                              );
                            } else if (isDraw) {
                              animatedChild = Transform.rotate(
                                angle: _drawRotationAnim.value,
                                child: animatedChild,
                              );
                            }
                          }
                          return animatedChild;
                        },
                        child: handWidget,
                      );
                    },
                  ),
                ),
              );

              final pcCard = Align(
                key: const ValueKey('pc_card'),
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: rightX),
                  child: _MoveCard(
                    label: widget.localization.t(
                      'string52',
                      fallback: 'PC Chose:',
                    ),
                    move: widget.computerMove,
                    isLeft: false,
                    isWinner: pcWins,
                    handBuilder: (context, handWidget) {
                      return AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          Widget animatedChild = child!;
                          if (widget.animationsEnabled && widget.roundId > 0) {
                            if (pcWins) {
                              animatedChild = Transform.translate(
                                offset: Offset(
                                  -(_punchAnim.value * targetDistance),
                                  0,
                                ),
                                child: animatedChild,
                              );
                            } else if (userWins) {
                              animatedChild = Transform.rotate(
                                angle: -_defeatRotationAnim.value,
                                child: animatedChild,
                              );
                            } else if (isDraw) {
                              animatedChild = Transform.rotate(
                                angle: -_drawRotationAnim.value,
                                child: animatedChild,
                              );
                            }
                          }
                          return animatedChild;
                        },
                        child: handWidget,
                      );
                    },
                  ),
                ),
              );

              // Ensure the winning hand renders on top of both the VS badge and the opponent hand
              final stackChildren = userWins
                  ? <Widget>[vsBadge, pcCard, userCard]
                  : <Widget>[vsBadge, userCard, pcCard];

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: stackChildren,
              );
            },
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
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
  }
}

class _MoveCard extends StatelessWidget {
  final String label;
  final HandMove? move;
  final bool isLeft;
  final bool isWinner;
  final Widget Function(BuildContext context, Widget handWidget) handBuilder;

  const _MoveCard({
    required this.label,
    required this.move,
    required this.isLeft,
    required this.isWinner,
    required this.handBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = isLeft ? move?.leftAsset : move?.rightAsset;
    final hasAsset = assetPath != null && assetPath.isNotEmpty;

    final handCircle = Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: isWinner
            ? Colors.green.withValues(alpha: 0.25)
            : Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
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
            ? const Text(
                '?',
                style: TextStyle(fontSize: 34, color: Colors.grey),
              )
            : hasAsset
            ? Image.asset(
                assetPath,
                width: 58,
                height: 58,
                errorBuilder: (context, error, stackTrace) =>
                    Text(move!.emoji, style: const TextStyle(fontSize: 38)),
              )
            : Text(move!.emoji, style: const TextStyle(fontSize: 38)),
      ),
    );

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
          handBuilder(context, handCircle),
          const SizedBox(height: 6),
          Text(
            move?.label.toUpperCase() ?? 'NONE',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
