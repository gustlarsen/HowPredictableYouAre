import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/move.dart';
import '../../services/localization_service.dart';
import 'rpg_hp_bar.dart';

class VersusArena extends StatefulWidget {
  final HandMove? userMove;
  final HandMove? computerMove;
  final RoundWinner? winner;
  final LocalizationService localization;
  final bool animationsEnabled;
  final int roundId;
  final int userHp;
  final int computerHp;
  final bool elementalMode;

  const VersusArena({
    super.key,
    required this.userMove,
    required this.computerMove,
    required this.winner,
    required this.localization,
    required this.animationsEnabled,
    required this.roundId,
    this.userHp = 100,
    this.computerHp = 100,
    this.elementalMode = false,
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
      duration: const Duration(milliseconds: 1000),
    );

    // Winning hand takes 500ms (0.0 -> 0.5) to move over to the losing hand,
    // and 500ms (0.5 -> 1.0) to move back to its starting position.
    _punchAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 50,
      ),
    ]).animate(_animController);

    // Losing hand makes a 360° rotation taking 500ms (0.5 -> 1.0),
    // simultaneous with the winning hand's backward movement.
    _defeatRotationAnim = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.5, 1.0, curve: Curves.linear),
      ),
    );

    // Draw 360° rotation for both hands (500ms)
    _drawRotationAnim = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.linear),
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

  double _calculateShake(bool isDamaged) {
    if (!isDamaged || !widget.animationsEnabled || !_animController.isAnimating) {
      return 0.0;
    }
    final t = _animController.value;
    if (t >= 0.5 && t <= 0.8) {
      final progress = (t - 0.5) / 0.3;
      final decay = 1.0 - progress;
      return math.sin(progress * math.pi * 6) * decay * 3.5;
    }
    return 0.0;
  }

  double _calculateFlash(bool isDamaged) {
    if (!isDamaged || !widget.animationsEnabled || !_animController.isAnimating) {
      return 0.0;
    }
    final t = _animController.value;
    if (t >= 0.5 && t <= 0.8) {
      final progress = (t - 0.5) / 0.3;
      return (1.0 - progress) * 0.55;
    }
    return 0.0;
  }

  double? _calculateDamageProgress(bool isDamaged) {
    if (!isDamaged || !widget.animationsEnabled || !_animController.isAnimating) {
      return null;
    }
    final t = _animController.value;
    if (t >= 0.5 && t <= 1.0) {
      return ((t - 0.5) / 0.5).clamp(0.0, 1.0);
    }
    return null;
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

    String? battleDescription;
    Color? battleDescColor;
    if (widget.userMove != null && widget.computerMove != null) {
      if (userWins) {
        battleDescription = widget.userMove!.battleDescriptionAgainst(
          widget.computerMove!,
          elemental: widget.elementalMode,
          localization: widget.localization,
        );
        battleDescColor = widget.elementalMode
            ? widget.userMove!.elementalPrimaryColor
            : Colors.greenAccent;
      } else if (pcWins) {
        battleDescription = widget.computerMove!.battleDescriptionAgainst(
          widget.userMove!,
          elemental: widget.elementalMode,
          localization: widget.localization,
        );
        battleDescColor = widget.elementalMode
            ? widget.computerMove!.elementalPrimaryColor
            : Colors.redAccent;
      }
    }

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
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, _) {
                      final isDamaged = pcWins && widget.roundId > 0;
                      final pulseProgress =
                          (userWins && widget.animationsEnabled)
                              ? _punchAnim.value
                              : 0.0;
                      return _MoveCard(
                        label: widget.localization.t(
                          'string9',
                          fallback: 'You Chose:',
                        ),
                        move: widget.userMove,
                        isLeft: true,
                        isWinner: userWins,
                        elementalMode: widget.elementalMode,
                        localization: widget.localization,
                        pulseProgress: pulseProgress,
                        hp: widget.userHp,
                        hpBarKey: const ValueKey('user_hp_bar'),
                        isDamaged: isDamaged,
                        flashOpacity: _calculateFlash(isDamaged),
                        shakeOffset: _calculateShake(isDamaged),
                        damageIndicatorProgress:
                            _calculateDamageProgress(isDamaged),
                        damageAmount: 1,
                        handBuilder: (context, handWidget) {
                          Widget animatedChild = handWidget;
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
                              // Left hand beaten: rotate 360° anti-clockwise (negative radians)
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
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, _) {
                      final isDamaged = userWins && widget.roundId > 0;
                      final pulseProgress =
                          (pcWins && widget.animationsEnabled)
                              ? _punchAnim.value
                              : 0.0;
                      return _MoveCard(
                        label: widget.localization.t(
                          'string52',
                          fallback: 'PC Chose',
                        ),
                        move: widget.computerMove,
                        isLeft: false,
                        isWinner: pcWins,
                        elementalMode: widget.elementalMode,
                        localization: widget.localization,
                        pulseProgress: pulseProgress,
                        hp: widget.computerHp,
                        hpBarKey: const ValueKey('pc_hp_bar'),
                        isDamaged: isDamaged,
                        flashOpacity: _calculateFlash(isDamaged),
                        shakeOffset: _calculateShake(isDamaged),
                        damageIndicatorProgress:
                            _calculateDamageProgress(isDamaged),
                        damageAmount: 1,
                        handBuilder: (context, handWidget) {
                          Widget animatedChild = handWidget;
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
                              // Right hand beaten: rotate 360° clockwise (positive radians)
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
                widget.localization.t(
                  'string10',
                  fallback: 'The winner of this round:',
                ),
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
          if (battleDescription != null && battleDescription.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              key: const ValueKey('battle_outcome_description'),
              battleDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: battleDescColor ?? Colors.amber,
                letterSpacing: 0.4,
              ),
            ),
          ],
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
  final bool elementalMode;
  final LocalizationService localization;
  final double pulseProgress;
  final int hp;
  final Key? hpBarKey;
  final bool isDamaged;
  final double flashOpacity;
  final double shakeOffset;
  final double? damageIndicatorProgress;
  final int damageAmount;
  final Widget Function(BuildContext context, Widget handWidget) handBuilder;

  const _MoveCard({
    required this.label,
    required this.move,
    required this.isLeft,
    required this.isWinner,
    required this.elementalMode,
    required this.localization,
    this.pulseProgress = 0.0,
    required this.hp,
    this.hpBarKey,
    required this.isDamaged,
    required this.flashOpacity,
    required this.shakeOffset,
    required this.damageIndicatorProgress,
    required this.damageAmount,
    required this.handBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = isLeft ? move?.leftAsset : move?.rightAsset;
    final hasAsset = assetPath != null && assetPath.isNotEmpty;

    final bool isElementalOrb = elementalMode && move != null;
    final Color primaryElementColor =
        move?.elementalPrimaryColor ?? Colors.amber;
    final Color secondaryElementColor =
        move?.elementalSecondaryColor ?? Colors.deepOrange;

    final double orbScale =
        (isElementalOrb && isWinner) ? (1.0 + 0.08 * pulseProgress) : 1.0;
    final double orbDiameter = 86.0 * orbScale;

    final BoxDecoration circleDecoration = isElementalOrb
        ? BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.2, -0.2),
              radius: 0.88,
              colors: [
                const Color(0xFF0A0C12),
                Color.lerp(
                  const Color(0xFF0E121B),
                  secondaryElementColor,
                  isWinner ? 0.55 : 0.38,
                )!,
                primaryElementColor.withValues(alpha: isWinner ? 0.92 : 0.72),
              ],
              stops: const [0.0, 0.58, 1.0],
            ),
            border: Border.all(
              color: isWinner
                  ? Color.lerp(primaryElementColor, Colors.white, 0.45)!
                  : (flashOpacity > 0.0
                      ? Color.lerp(
                          Colors.white,
                          Colors.redAccent,
                          0.65,
                        )!.withValues(alpha: 0.85)
                      : primaryElementColor.withValues(alpha: 0.75)),
              width: isWinner ? 3.0 : (flashOpacity > 0.0 ? 2.5 : 2.0),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryElementColor.withValues(
                  alpha: isWinner
                      ? (0.55 + 0.25 * pulseProgress).clamp(0.0, 1.0)
                      : 0.35,
                ),
                blurRadius: isWinner ? (16.0 + 8.0 * pulseProgress) : 10.0,
                spreadRadius: isWinner ? (3.0 + 2.0 * pulseProgress) : 1.5,
              ),
              if (isWinner)
                BoxShadow(
                  color: secondaryElementColor.withValues(alpha: 0.45),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
            ],
          )
        : BoxDecoration(
            color: isWinner
                ? Colors.green.withValues(alpha: 0.25)
                : Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            border: Border.all(
              color: isWinner
                  ? Colors.green
                  : (flashOpacity > 0.0
                      ? Color.lerp(
                          Colors.white,
                          Colors.redAccent,
                          0.65,
                        )!.withValues(alpha: 0.85)
                      : Colors.white24),
              width: isWinner ? 3 : (flashOpacity > 0.0 ? 2.5 : 1.5),
            ),
            boxShadow: isWinner
                ? [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : (flashOpacity > 0.0
                    ? [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null),
          );

    final handCircle = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          key: isLeft
              ? const ValueKey('user_orb_container')
              : const ValueKey('pc_orb_container'),
          width: orbDiameter,
          height: orbDiameter,
          decoration: circleDecoration,
          child: Center(
            child: move == null
                ? const Text(
                    '?',
                    style: TextStyle(fontSize: 34, color: Colors.grey),
                  )
                : elementalMode
                ? Icon(
                    move!.elementalIcon,
                    size: 42 * orbScale,
                    color: primaryElementColor,
                    shadows: [
                      Shadow(
                        color: primaryElementColor.withValues(alpha: 0.8),
                        blurRadius: 12,
                      ),
                      const Shadow(
                        color: Colors.black87,
                        blurRadius: 4,
                      ),
                    ],
                  )
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
                : Text(move!.emoji, style: const TextStyle(fontSize: 38)),
          ),
        ),

        // Damage White/Red Flash Overlay on hand circle
        if (flashOpacity > 0.0)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  Colors.white,
                  Colors.redAccent,
                  0.65,
                )!.withValues(
                  alpha: flashOpacity.clamp(0.0, 1.0) * 0.65,
                ),
              ),
            ),
          ),

        // Floating Damage Indicator (-1 in crisp red/gold text that fades upward)
        if (damageIndicatorProgress != null)
          Positioned(
            top: 10.0 - (28.0 * Curves.easeOut.transform(damageIndicatorProgress!)),
            child: Opacity(
              opacity: (1.0 - damageIndicatorProgress!).clamp(0.0, 1.0),
              child: Container(
                key: isLeft
                    ? const ValueKey('user_damage_indicator')
                    : const ValueKey('pc_damage_indicator'),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B0505).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.amber.withValues(
                      alpha: 0.85 * (1.0 - damageIndicatorProgress!),
                    ),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(
                        alpha: 0.55 * (1.0 - damageIndicatorProgress!),
                      ),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  '-$damageAmount',
                  style: const TextStyle(
                    color: Color(0xFFFF4D4D),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(color: Colors.amber, blurRadius: 4),
                      Shadow(
                        color: Colors.black,
                        blurRadius: 2,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final paddingLeft = shakeOffset > 0 ? shakeOffset : 0.0;
    final paddingRight = shakeOffset < 0 ? -shakeOffset : 0.0;

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
          Padding(
            padding: EdgeInsets.only(left: paddingLeft, right: paddingRight),
            child: handBuilder(context, handCircle),
          ),
          const SizedBox(height: 6),
          RpgHpBar(
            key: hpBarKey,
            hp: hp,
            flashOpacity: flashOpacity,
            shakeOffset: shakeOffset,
          ),
          const SizedBox(height: 4),
          Text(
            move == null
                ? 'NONE'
                : (elementalMode
                      ? move!
                            .displayLabel(
                              elemental: true,
                              localization: localization,
                            )
                            .toUpperCase()
                      : move!.label.toUpperCase()),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.5,
              color: (elementalMode && move != null)
                  ? move!.elementalPrimaryColor
                  : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
