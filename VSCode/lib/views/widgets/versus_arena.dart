import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/move.dart';
import '../../services/localization_service.dart';
import 'rpg_hp_bar.dart';

/// Phases of the 750ms VersusArena projectile clash & impact VFX sequence.
enum BattleVfxPhase {
  idle,
  launch,
  clash,
  impact,
}

/// Visual theme for a launched projectile, its particle trail, and its explosion burst.
enum BattleVfxElement {
  classic,
  fire,
  water,
  wood,
  earth,
  metal,
}

class VersusArena extends StatefulWidget {
  static const int vfxDurationMs = 750;
  static const int clashTimeMs = 300;
  static const int impactTimeMs = 550;

  final HandMove? userMove;
  final HandMove? computerMove;
  final RoundWinner? winner;
  final LocalizationService localization;
  final bool animationsEnabled;
  final int roundId;
  final int userHp;
  final int computerHp;
  final bool elementalMode;
  final VoidCallback? onImpactHaptic;
  final Key? pcSlotKey;

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
    this.onImpactHaptic,
    this.pcSlotKey,
  });

  @override
  State<VersusArena> createState() => _VersusArenaState();
}

class _VersusArenaState extends State<VersusArena>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _vfxController;
  late Animation<double> _punchAnim;
  late Animation<double> _defeatRotationAnim;
  late Animation<double> _drawRotationAnim;
  bool _didTriggerImpactHaptic = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _vfxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: VersusArena.vfxDurationMs),
    )..addListener(_handleVfxTick);

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
      _startRoundAnimations();
    }
  }

  void _startRoundAnimations() {
    _didTriggerImpactHaptic = false;
    if (widget.elementalMode) {
      _vfxController.forward(from: 0.0);
    } else {
      _animController.forward(from: 0.0);
    }
  }

  void _stopRoundAnimations() {
    _didTriggerImpactHaptic = false;
    if (_animController.isAnimating || _animController.value != 0.0) {
      _animController.stop();
      _animController.reset();
    }
    if (_vfxController.isAnimating || _vfxController.value != 0.0) {
      _vfxController.stop();
      _vfxController.reset();
    }
  }

  void _handleVfxTick() {
    if (!widget.elementalMode ||
        !widget.animationsEnabled ||
        !_vfxController.isAnimating ||
        _didTriggerImpactHaptic ||
        widget.winner == null) {
      return;
    }
    final elapsedMs = _vfxController.value * VersusArena.vfxDurationMs;
    final triggerThresholdMs = widget.winner == RoundWinner.draw
        ? VersusArena.clashTimeMs.toDouble()
        : VersusArena.impactTimeMs.toDouble();
    if (elapsedMs >= triggerThresholdMs) {
      _didTriggerImpactHaptic = true;
      widget.onImpactHaptic?.call();
    }
  }

  @override
  void didUpdateWidget(covariant VersusArena oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animationsEnabled) {
      _stopRoundAnimations();
      return;
    }

    if (widget.elementalMode != oldWidget.elementalMode) {
      _stopRoundAnimations();
    }

    if (widget.roundId != oldWidget.roundId) {
      // Immediately cancel any active animation, return to initial state, and restart cleanly
      _stopRoundAnimations();
      if (widget.roundId > 0) {
        _startRoundAnimations();
      }
    }
  }

  @override
  void dispose() {
    _vfxController.removeListener(_handleVfxTick);
    _vfxController.dispose();
    _animController.dispose();
    super.dispose();
  }

  double _calculateShake(bool isDamaged) {
    if (!isDamaged || !widget.animationsEnabled) {
      return 0.0;
    }
    if (!widget.elementalMode) {
      if (!_animController.isAnimating) return 0.0;
      final t = _animController.value;
      if (t >= 0.5 && t <= 0.8) {
        final progress = (t - 0.5) / 0.3;
        final decay = 1.0 - progress;
        return math.sin(progress * math.pi * 6) * decay * 3.5;
      }
      return 0.0;
    }
    if (!_vfxController.isAnimating || _vfxController.value >= 1.0) {
      return 0.0;
    }
    final elapsedMs = _vfxController.value * VersusArena.vfxDurationMs;
    if (elapsedMs >= VersusArena.impactTimeMs &&
        elapsedMs < VersusArena.vfxDurationMs) {
      final progress = (elapsedMs - VersusArena.impactTimeMs) /
          (VersusArena.vfxDurationMs - VersusArena.impactTimeMs);
      final decay = 1.0 - progress;
      return math.sin(progress * math.pi * 6) * decay * 4.0;
    }
    return 0.0;
  }

  double _calculateFlash(bool isDamaged) {
    if (!isDamaged || !widget.animationsEnabled) {
      return 0.0;
    }
    if (!widget.elementalMode) {
      if (!_animController.isAnimating) return 0.0;
      final t = _animController.value;
      if (t >= 0.5 && t <= 0.8) {
        final progress = (t - 0.5) / 0.3;
        return (1.0 - progress) * 0.55;
      }
      return 0.0;
    }
    if (!_vfxController.isAnimating || _vfxController.value >= 1.0) {
      return 0.0;
    }
    final elapsedMs = _vfxController.value * VersusArena.vfxDurationMs;
    if (elapsedMs >= VersusArena.impactTimeMs &&
        elapsedMs < VersusArena.vfxDurationMs) {
      final progress = (elapsedMs - VersusArena.impactTimeMs) /
          (VersusArena.vfxDurationMs - VersusArena.impactTimeMs);
      return (1.0 - progress) * 0.65;
    }
    return 0.0;
  }

  double? _calculateDamageProgress(bool isDamaged) {
    if (!isDamaged || !widget.animationsEnabled) {
      return null;
    }
    if (!widget.elementalMode) {
      if (!_animController.isAnimating) return null;
      final t = _animController.value;
      if (t >= 0.5 && t <= 1.0) {
        return ((t - 0.5) / 0.5).clamp(0.0, 1.0);
      }
      return null;
    }
    if (!_vfxController.isAnimating || _vfxController.value >= 1.0) {
      return null;
    }
    final elapsedMs = _vfxController.value * VersusArena.vfxDurationMs;
    if (elapsedMs >= VersusArena.impactTimeMs &&
        elapsedMs < VersusArena.vfxDurationMs) {
      return ((elapsedMs - VersusArena.impactTimeMs) /
              (VersusArena.vfxDurationMs - VersusArena.impactTimeMs))
          .clamp(0.0, 1.0);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final winner = widget.winner;

    Color outcomeColor;
    switch (winner) {
      case RoundWinner.user:
        outcomeColor = Colors.green;
        break;
      case RoundWinner.computer:
        outcomeColor = Colors.redAccent;
        break;
      case RoundWinner.draw:
        outcomeColor = Colors.amber;
        break;
      case null:
        outcomeColor = Colors.grey;
        break;
    }

    final userWins = winner == RoundWinner.user;
    final pcWins = winner == RoundWinner.computer;
    final isDraw = winner == RoundWinner.draw;

    String battleDescription;
    Color battleDescColor;
    if (widget.userMove != null && widget.computerMove != null) {
      if (userWins) {
        battleDescription = widget.userMove!.battleDescriptionAgainst(
              widget.computerMove!,
              elemental: widget.elementalMode,
              localization: widget.localization,
            ) ??
            '';
        battleDescColor = widget.elementalMode
            ? widget.userMove!.elementalPrimaryColor
            : Colors.greenAccent;
      } else if (pcWins) {
        battleDescription = widget.computerMove!.battleDescriptionAgainst(
              widget.userMove!,
              elemental: widget.elementalMode,
              localization: widget.localization,
            ) ??
            '';
        battleDescColor = widget.elementalMode
            ? widget.computerMove!.elementalPrimaryColor
            : Colors.redAccent;
      } else if (isDraw) {
        final drawKey = widget.elementalMode
            ? 'battle_draw_elemental'
            : 'battle_draw_classic';
        final drawFallback = widget.elementalMode
            ? "It's a Draw! Elements neutralized."
            : "It's a Draw! Moves neutralized.";
        battleDescription = widget.localization.t(
          drawKey,
          fallback: drawFallback,
        );
        battleDescColor = Colors.amber;
      } else {
        final idleKey = widget.elementalMode
            ? 'battle_idle_elemental'
            : 'battle_idle_classic';
        final idleFallback = widget.elementalMode
            ? 'Choose an element to attack!'
            : 'Choose a move to battle!';
        battleDescription = widget.localization.t(
          idleKey,
          fallback: idleFallback,
        );
        battleDescColor = Colors.grey.shade400;
      }
    } else if (isDraw) {
      final drawKey = widget.elementalMode
          ? 'battle_draw_elemental'
          : 'battle_draw_classic';
      final drawFallback = widget.elementalMode
          ? "It's a Draw! Elements neutralized."
          : "It's a Draw! Moves neutralized.";
      battleDescription = widget.localization.t(
        drawKey,
        fallback: drawFallback,
      );
      battleDescColor = Colors.amber;
    } else {
      final idleKey = widget.elementalMode
          ? 'battle_idle_elemental'
          : 'battle_idle_classic';
      final idleFallback = widget.elementalMode
          ? 'Choose an element to attack!'
          : 'Choose a move to battle!';
      battleDescription = widget.localization.t(
        idleKey,
        fallback: idleFallback,
      );
      battleDescColor = Colors.grey.shade400;
    }

    if (battleDescription.isEmpty) {
      final idleKey = widget.elementalMode
          ? 'battle_idle_elemental'
          : 'battle_idle_classic';
      final idleFallback = widget.elementalMode
          ? 'Choose an element to attack!'
          : 'Choose a move to battle!';
      battleDescription = widget.localization.t(
        idleKey,
        fallback: idleFallback,
      );
      battleDescColor = Colors.grey.shade400;
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
              final maxCardLeft = math.max(0.0, rowWidth - cardWidth);
              final freeSpace = math.max(0.0, rowWidth - totalItemsWidth);
              final spaceUnit = freeSpace / 3.0;

              final leftX = (0.5 * spaceUnit).clamp(0.0, maxCardLeft);
              final rightX = rowWidth >= totalItemsWidth
                  ? (2.5 * spaceUnit + cardWidth + vsWidth)
                      .clamp(0.0, maxCardLeft)
                  : maxCardLeft;
              // Exact center-to-center distance so the winning hand moves directly over the opponent
              final targetDistance = rightX - leftX;

              final leftCenterX = leftX + cardWidth / 2.0;
              final rightCenterX = rightX + cardWidth / 2.0;
              final centerX = rowWidth / 2.0;
              const orbCenterY = 67.0;

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
                    animation: Listenable.merge([
                      _animController,
                      _vfxController,
                    ]),
                    builder: (context, _) {
                      final isDamaged = pcWins && widget.roundId > 0;
                      final pulseProgress = widget.animationsEnabled
                          ? (widget.elementalMode
                              ? (_vfxController.isAnimating
                                  ? math.sin(_vfxController.value * math.pi)
                                  : 0.0)
                              : (userWins ? _punchAnim.value : 0.0))
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
                          if (!widget.elementalMode &&
                              widget.animationsEnabled &&
                              widget.roundId > 0) {
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
                    animation: Listenable.merge([
                      _animController,
                      _vfxController,
                    ]),
                    builder: (context, _) {
                      final isDamaged = userWins && widget.roundId > 0;
                      final pulseProgress = widget.animationsEnabled
                          ? (widget.elementalMode
                              ? (_vfxController.isAnimating
                                  ? math.sin(_vfxController.value * math.pi)
                                  : 0.0)
                              : (pcWins ? _punchAnim.value : 0.0))
                          : 0.0;
                      return KeyedSubtree(
                        key: widget.pcSlotKey,
                        child: _MoveCard(
                          label: widget.localization.t(
                            'string52',
                            fallback: 'PC Chose:',
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
                            if (!widget.elementalMode &&
                                widget.animationsEnabled &&
                                widget.roundId > 0) {
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
                        ),
                      );
                    },
                  ),
                ),
              );

              final vfxOverlay = Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _vfxController,
                    builder: (context, _) {
                      final isVfxActive = widget.elementalMode &&
                          widget.animationsEnabled &&
                          widget.roundId > 0 &&
                          widget.userMove != null &&
                          widget.computerMove != null &&
                          widget.winner != null &&
                          _vfxController.isAnimating &&
                          _vfxController.value < 1.0;
                      return CustomPaint(
                        key: const ValueKey('versus_battle_vfx_layer'),
                        painter: BattleVfxPainter(
                          progress: _vfxController.value,
                          isAnimating: isVfxActive,
                          userMove: widget.userMove,
                          computerMove: widget.computerMove,
                          winner: widget.winner,
                          elementalMode: widget.elementalMode,
                          roundId: widget.roundId,
                          leftCenterX: leftCenterX,
                          rightCenterX: rightCenterX,
                          centerX: centerX,
                          orbCenterY: orbCenterY,
                        ),
                      );
                    },
                  ),
                ),
              );

              // Ensure the winning hand renders on top of both the VS badge and the opponent hand,
              // with the alpha-transparent projectile & explosion VFX layer rendered above all cards.
              final stackChildren = userWins
                  ? <Widget>[vsBadge, pcCard, userCard, vfxOverlay]
                  : <Widget>[vsBadge, userCard, pcCard, vfxOverlay];

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: stackChildren,
              );
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: Center(
              child: Text(
                key: const ValueKey('battle_outcome_description'),
                battleDescription,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: battleDescColor,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 60-FPS procedural CustomPainter for elemental & classic projectiles, trails,
/// mid-arena clash bursts, and impact explosions with full alpha transparency.
class BattleVfxPainter extends CustomPainter {
  final double progress;
  final bool isAnimating;
  final HandMove? userMove;
  final HandMove? computerMove;
  final RoundWinner? winner;
  final bool elementalMode;
  final int roundId;
  final double leftCenterX;
  final double rightCenterX;
  final double centerX;
  final double orbCenterY;

  const BattleVfxPainter({
    required this.progress,
    required this.isAnimating,
    required this.userMove,
    required this.computerMove,
    required this.winner,
    required this.elementalMode,
    required this.roundId,
    required this.leftCenterX,
    required this.rightCenterX,
    required this.centerX,
    required this.orbCenterY,
  });

  static BattleVfxElement elementFor(
    HandMove move, {
    required bool elementalMode,
  }) {
    if (!elementalMode) return BattleVfxElement.classic;
    switch (move) {
      case HandMove.rock:
        return BattleVfxElement.fire;
      case HandMove.paper:
        return BattleVfxElement.water;
      case HandMove.scissors:
        return BattleVfxElement.wood;
      case HandMove.lizard:
        return BattleVfxElement.earth;
      case HandMove.spock:
        return BattleVfxElement.metal;
    }
  }

  double get elapsedMs => progress * VersusArena.vfxDurationMs;

  BattleVfxPhase get phase {
    if (!elementalMode ||
        !isAnimating ||
        progress >= 1.0 ||
        userMove == null ||
        computerMove == null ||
        winner == null) {
      return BattleVfxPhase.idle;
    }
    final ms = elapsedMs;
    if (ms < VersusArena.clashTimeMs) {
      return BattleVfxPhase.launch;
    } else if (ms < VersusArena.impactTimeMs) {
      return BattleVfxPhase.clash;
    } else {
      return BattleVfxPhase.impact;
    }
  }

  BattleVfxElement? get leftElement => userMove == null
      ? null
      : elementFor(userMove!, elementalMode: elementalMode);

  BattleVfxElement? get rightElement => computerMove == null
      ? null
      : elementFor(computerMove!, elementalMode: elementalMode);

  Offset? get leftProjectilePosition {
    final currentPhase = phase;
    if (currentPhase == BattleVfxPhase.launch) {
      final p1 = Curves.easeInQuad.transform(
        (elapsedMs / VersusArena.clashTimeMs).clamp(0.0, 1.0),
      );
      return Offset(
        ui.lerpDouble(leftCenterX, centerX, p1)!,
        orbCenterY,
      );
    }
    if (currentPhase == BattleVfxPhase.clash && winner == RoundWinner.user) {
      final p2 = Curves.easeOutQuad.transform(
        ((elapsedMs - VersusArena.clashTimeMs) /
                (VersusArena.impactTimeMs - VersusArena.clashTimeMs))
            .clamp(0.0, 1.0),
      );
      return Offset(
        ui.lerpDouble(centerX, rightCenterX, p2)!,
        orbCenterY,
      );
    }
    return null;
  }

  Offset? get rightProjectilePosition {
    final currentPhase = phase;
    if (currentPhase == BattleVfxPhase.launch) {
      final p1 = Curves.easeInQuad.transform(
        (elapsedMs / VersusArena.clashTimeMs).clamp(0.0, 1.0),
      );
      return Offset(
        ui.lerpDouble(rightCenterX, centerX, p1)!,
        orbCenterY,
      );
    }
    if (currentPhase == BattleVfxPhase.clash &&
        winner == RoundWinner.computer) {
      final p2 = Curves.easeOutQuad.transform(
        ((elapsedMs - VersusArena.clashTimeMs) /
                (VersusArena.impactTimeMs - VersusArena.clashTimeMs))
            .clamp(0.0, 1.0),
      );
      return Offset(
        ui.lerpDouble(centerX, leftCenterX, p2)!,
        orbCenterY,
      );
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final currentPhase = phase;
    if (currentPhase == BattleVfxPhase.idle) return;

    final leftElem = leftElement!;
    final rightElem = rightElement!;
    final ms = elapsedMs;
    final clashCenter = Offset(centerX, orbCenterY);
    final leftOrigin = Offset(leftCenterX, orbCenterY);
    final rightOrigin = Offset(rightCenterX, orbCenterY);

    // 1. Phase 1: Simultaneous Launch (0ms -> 300ms)
    if (currentPhase == BattleVfxPhase.launch) {
      final p1 = (ms / VersusArena.clashTimeMs).clamp(0.0, 1.0);
      final leftPos = leftProjectilePosition!;
      final rightPos = rightProjectilePosition!;

      // Launch muzzle rings at both origins during the first 160ms
      if (ms < 160.0) {
        final muzzleT = (ms / 160.0).clamp(0.0, 1.0);
        _paintMuzzlePulse(canvas, leftOrigin, leftElem, muzzleT);
        _paintMuzzlePulse(canvas, rightOrigin, rightElem, muzzleT);
      }

      _paintProjectileWithTrail(
        canvas: canvas,
        origin: leftOrigin,
        currentPos: leftPos,
        direction: 1.0,
        element: leftElem,
        phaseProgress: p1,
        intensityScale: 1.0,
        seed: roundId * 17 + 1,
      );
      _paintProjectileWithTrail(
        canvas: canvas,
        origin: rightOrigin,
        currentPos: rightPos,
        direction: -1.0,
        element: rightElem,
        phaseProgress: p1,
        intensityScale: 1.0,
        seed: roundId * 31 + 2,
      );
      return;
    }

    // 2. Phase 2: Mid-Arena Clash (300ms -> 550ms) & Tie Dissipation (300ms -> 750ms)
    if (winner == RoundWinner.draw) {
      final tieProgress = ((ms - VersusArena.clashTimeMs) /
              (VersusArena.vfxDurationMs - VersusArena.clashTimeMs))
          .clamp(0.0, 1.0);
      _paintTieClashExplosion(
        canvas: canvas,
        center: clashCenter,
        leftElem: leftElem,
        rightElem: rightElem,
        t: tieProgress,
        seed: roundId * 43 + 7,
      );
      return;
    }

    // On a Win or Loss:
    // A) Center clash flash + losing projectile shatter at center (300ms -> 550ms)
    if (ms >= VersusArena.clashTimeMs && ms < VersusArena.impactTimeMs) {
      final clashT = ((ms - VersusArena.clashTimeMs) /
              (VersusArena.impactTimeMs - VersusArena.clashTimeMs))
          .clamp(0.0, 1.0);
      final winningElem =
          winner == RoundWinner.user ? leftElem : rightElem;
      final losingElem =
          winner == RoundWinner.user ? rightElem : leftElem;
      final losingDeflectDir = winner == RoundWinner.user ? 1.0 : -1.0;

      _paintCenterOverpowerBurst(
        canvas: canvas,
        center: clashCenter,
        winningElem: winningElem,
        losingElem: losingElem,
        losingDeflectDir: losingDeflectDir,
        t: clashT,
        seed: roundId * 59 + 3,
      );

      // B) Winning projectile surges from center into the losing combatant's position
      if (winner == RoundWinner.user) {
        final surgePos = leftProjectilePosition!;
        _paintProjectileWithTrail(
          canvas: canvas,
          origin: clashCenter,
          currentPos: surgePos,
          direction: 1.0,
          element: leftElem,
          phaseProgress: clashT,
          intensityScale: 1.25,
          seed: roundId * 71 + 5,
        );
      } else if (winner == RoundWinner.computer) {
        final surgePos = rightProjectilePosition!;
        _paintProjectileWithTrail(
          canvas: canvas,
          origin: clashCenter,
          currentPos: surgePos,
          direction: -1.0,
          element: rightElem,
          phaseProgress: clashT,
          intensityScale: 1.25,
          seed: roundId * 79 + 6,
        );
      }
      return;
    }

    // 3. Phase 3: Impact Explosion on the losing combatant (550ms -> 750ms)
    if (currentPhase == BattleVfxPhase.impact) {
      final impactT = ((ms - VersusArena.impactTimeMs) /
              (VersusArena.vfxDurationMs - VersusArena.impactTimeMs))
          .clamp(0.0, 1.0);
      final targetCenter =
          winner == RoundWinner.user ? rightOrigin : leftOrigin;
      final winningElem =
          winner == RoundWinner.user ? leftElem : rightElem;

      _paintElementalImpactExplosion(
        canvas: canvas,
        center: targetCenter,
        element: winningElem,
        t: impactT,
        seed: roundId * 97 + 11,
      );
    }
  }

  _ElementPalette _paletteFor(BattleVfxElement element) {
    switch (element) {
      case BattleVfxElement.fire:
        return const _ElementPalette(
          core: Color(0xFFFFF8E1),
          primary: Color(0xFFFF5722),
          secondary: Color(0xFFFF3D00),
          accent: Color(0xFFFFCA28),
        );
      case BattleVfxElement.water:
        return const _ElementPalette(
          core: Color(0xFFE1F5FE),
          primary: Color(0xFF00B0FF),
          secondary: Color(0xFF2979FF),
          accent: Color(0xFF80D8FF),
        );
      case BattleVfxElement.wood:
        return const _ElementPalette(
          core: Color(0xFFE8F5E9),
          primary: Color(0xFF00E676),
          secondary: Color(0xFF2E7D32),
          accent: Color(0xFFB9F6CA),
        );
      case BattleVfxElement.earth:
        return const _ElementPalette(
          core: Color(0xFFFFF3E0),
          primary: Color(0xFFFFB300),
          secondary: Color(0xFFD87A16),
          accent: Color(0xFFFFE082),
        );
      case BattleVfxElement.metal:
        return const _ElementPalette(
          core: Color(0xFFFFFFFF),
          primary: Color(0xFFCFD8DC),
          secondary: Color(0xFF80D8FF),
          accent: Color(0xFF00E5FF),
        );
      case BattleVfxElement.classic:
        return const _ElementPalette(
          core: Color(0xFFFFFDE7),
          primary: Color(0xFFFFC107),
          secondary: Color(0xFFFF8F00),
          accent: Color(0xFFFFE082),
        );
    }
  }

  void _paintMuzzlePulse(
    Canvas canvas,
    Offset origin,
    BattleVfxElement element,
    double t,
  ) {
    final palette = _paletteFor(element);
    final alpha = (1.0 - t).clamp(0.0, 1.0);
    final radius = 10.0 + 22.0 * Curves.easeOut.transform(t);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * alpha
      ..color = palette.primary.withValues(alpha: 0.65 * alpha);
    canvas.drawCircle(origin, radius, ringPaint);
  }

  void _paintProjectileWithTrail({
    required Canvas canvas,
    required Offset origin,
    required Offset currentPos,
    required double direction,
    required BattleVfxElement element,
    required double phaseProgress,
    required double intensityScale,
    required int seed,
  }) {
    final palette = _paletteFor(element);
    final trailLength = (currentPos.dx - origin.dx).abs();
    final maxTrailSpan = math.min(trailLength, 78.0 * intensityScale);
    final tailStart = Offset(
      currentPos.dx - direction * maxTrailSpan,
      currentPos.dy,
    );

    // 1. Glowing energy ribbon trail
    if (maxTrailSpan > 2.0) {
      final trailShader = ui.Gradient.linear(
        tailStart,
        currentPos,
        [
          palette.secondary.withValues(alpha: 0.0),
          palette.primary.withValues(alpha: 0.55),
          palette.core.withValues(alpha: 0.92),
        ],
        const [0.0, 0.65, 1.0],
      );
      final outerTrailPaint = Paint()
        ..shader = trailShader
        ..strokeWidth = 10.0 * intensityScale
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawLine(tailStart, currentPos, outerTrailPaint);

      final innerTrailPaint = Paint()
        ..shader = trailShader
        ..strokeWidth = 4.0 * intensityScale
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tailStart, currentPos, innerTrailPaint);
    }

    // 2. Element-specific trailing wake particles
    const particleCount = 10;
    for (int i = 0; i < particleCount; i++) {
      final frac = (i + 1) / (particleCount + 1);
      final hash = _pseudoRandom(seed + i * 13);
      final hash2 = _pseudoRandom(seed + i * 29 + 7);
      final px = ui.lerpDouble(currentPos.dx, tailStart.dx, frac)!;
      final wave = math.sin(phaseProgress * math.pi * 4 + i * 1.3);
      final spreadY = (hash - 0.5) * 20.0 * frac + wave * 4.5 * (1.0 - frac * 0.5);
      final particlePos = Offset(px, currentPos.dy + spreadY);
      final particleAlpha = (1.0 - frac * 0.85).clamp(0.0, 1.0);
      final particleRadius = (2.2 + hash2 * 2.8) * (1.0 - frac * 0.4) * intensityScale;

      _paintElementParticle(
        canvas: canvas,
        pos: particlePos,
        radius: particleRadius,
        angle: phaseProgress * 6.0 + i,
        alpha: particleAlpha,
        element: element,
        palette: palette,
      );
    }

    // 3. Element-specific Projectile Head
    _paintProjectileHead(
      canvas: canvas,
      pos: currentPos,
      direction: direction,
      element: element,
      palette: palette,
      phaseProgress: phaseProgress,
      scale: intensityScale,
    );
  }

  void _paintProjectileHead({
    required Canvas canvas,
    required Offset pos,
    required double direction,
    required BattleVfxElement element,
    required _ElementPalette palette,
    required double phaseProgress,
    required double scale,
  }) {
    final baseRadius = 11.5 * scale;

    // Outer ambient elemental halo
    final haloPaint = Paint()
      ..color = palette.primary.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawCircle(pos, baseRadius * 1.45, haloPaint);

    switch (element) {
      case BattleVfxElement.fire:
        // Flame tongues trailing backward from the blazing fireball core
        for (int i = -1; i <= 1; i++) {
          final flicker = math.sin(phaseProgress * math.pi * 8 + i * 2.1) * 3.0;
          final tonguePath = Path()
            ..moveTo(pos.dx, pos.dy - 6.0 * scale + i * 3.0)
            ..quadraticBezierTo(
              pos.dx - direction * 14.0 * scale,
              pos.dy + flicker + i * 5.0,
              pos.dx - direction * 24.0 * scale,
              pos.dy + flicker * 0.6 + i * 3.5,
            )
            ..quadraticBezierTo(
              pos.dx - direction * 12.0 * scale,
              pos.dy + 6.0 * scale + i * 2.5,
              pos.dx,
              pos.dy + 5.0 * scale + i * 2.0,
            )
            ..close();
          canvas.drawPath(
            tonguePath,
            Paint()
              ..color = (i == 0 ? palette.accent : palette.secondary)
                  .withValues(alpha: 0.82),
          );
        }
        canvas.drawCircle(
          pos,
          baseRadius,
          Paint()..color = palette.primary,
        );
        canvas.drawCircle(
          pos,
          baseRadius * 0.58,
          Paint()..color = palette.core,
        );
        break;

      case BattleVfxElement.water:
        // Swirling cyan/blue hydro-orb with rotating crescent vortex arcs
        canvas.drawCircle(
          pos,
          baseRadius,
          Paint()..color = palette.secondary.withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          pos,
          baseRadius * 0.78,
          Paint()..color = palette.primary,
        );
        final vortexPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * scale
          ..strokeCap = StrokeCap.round
          ..color = palette.accent.withValues(alpha: 0.9);
        for (int a = 0; a < 2; a++) {
          final startAngle = phaseProgress * math.pi * 4 + a * math.pi;
          canvas.drawArc(
            Rect.fromCircle(center: pos, radius: baseRadius * 1.15),
            startAngle,
            math.pi * 0.65,
            false,
            vortexPaint,
          );
        }
        canvas.drawCircle(
          Offset(pos.dx + direction * 2.5, pos.dy - 2.5),
          baseRadius * 0.42,
          Paint()..color = palette.core,
        );
        break;

      case BattleVfxElement.wood:
        // Emerald nature energy spiral with intersecting helical ribbons
        final spiralPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * scale
          ..color = palette.accent.withValues(alpha: 0.9);
        for (int s = 0; s < 3; s++) {
          final angle = phaseProgress * math.pi * 5 + (s * 2 * math.pi / 3);
          canvas.drawArc(
            Rect.fromCircle(center: pos, radius: baseRadius * 1.1),
            angle,
            math.pi * 0.55,
            false,
            spiralPaint,
          );
        }
        canvas.drawCircle(
          pos,
          baseRadius * 0.85,
          Paint()..color = palette.primary,
        );
        canvas.drawCircle(
          pos,
          baseRadius * 0.48,
          Paint()..color = palette.core,
        );
        break;

      case BattleVfxElement.earth:
        // Rotating jagged golden-amber meteor/rock polygon with magma core
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(phaseProgress * math.pi * 3 * direction);
        final rockPath = Path();
        const vertices = 7;
        for (int v = 0; v < vertices; v++) {
          final theta = (v / vertices) * 2 * math.pi;
          final r = baseRadius * (v.isEven ? 1.12 : 0.84);
          final vx = math.cos(theta) * r;
          final vy = math.sin(theta) * r;
          if (v == 0) {
            rockPath.moveTo(vx, vy);
          } else {
            rockPath.lineTo(vx, vy);
          }
        }
        rockPath.close();
        canvas.drawPath(rockPath, Paint()..color = palette.secondary);
        canvas.drawPath(
          rockPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8 * scale
            ..color = palette.primary,
        );
        canvas.drawCircle(
          Offset.zero,
          baseRadius * 0.42,
          Paint()..color = palette.core,
        );
        canvas.restore();
        break;

      case BattleVfxElement.metal:
        // Silver/ice-blue razor energy slash crescent + spinning steel star core
        final slashPath = Path()
          ..moveTo(pos.dx + direction * baseRadius * 1.4, pos.dy)
          ..quadraticBezierTo(
            pos.dx + direction * baseRadius * 0.3,
            pos.dy - baseRadius * 1.35,
            pos.dx - direction * baseRadius * 0.9,
            pos.dy - baseRadius * 0.9,
          )
          ..quadraticBezierTo(
            pos.dx + direction * baseRadius * 0.45,
            pos.dy,
            pos.dx - direction * baseRadius * 0.9,
            pos.dy + baseRadius * 0.9,
          )
          ..quadraticBezierTo(
            pos.dx + direction * baseRadius * 0.3,
            pos.dy + baseRadius * 1.35,
            pos.dx + direction * baseRadius * 1.4,
            pos.dy,
          )
          ..close();
        canvas.drawPath(slashPath, Paint()..color = palette.secondary);
        canvas.drawPath(
          slashPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * scale
            ..color = palette.core,
        );
        canvas.drawCircle(
          pos,
          baseRadius * 0.48,
          Paint()..color = palette.core,
        );
        break;

      case BattleVfxElement.classic:
        // Sleek cosmic/amber energy bolt matching the dark/gold theme
        final boltPath = Path()
          ..moveTo(pos.dx + direction * baseRadius * 1.35, pos.dy)
          ..lineTo(pos.dx - direction * baseRadius * 0.85, pos.dy - baseRadius * 0.72)
          ..lineTo(pos.dx - direction * baseRadius * 0.35, pos.dy)
          ..lineTo(pos.dx - direction * baseRadius * 0.85, pos.dy + baseRadius * 0.72)
          ..close();
        canvas.drawPath(boltPath, Paint()..color = palette.primary);
        canvas.drawCircle(
          pos,
          baseRadius * 0.55,
          Paint()..color = palette.core,
        );
        break;
    }
  }

  void _paintElementParticle({
    required Canvas canvas,
    required Offset pos,
    required double radius,
    required double angle,
    required double alpha,
    required BattleVfxElement element,
    required _ElementPalette palette,
  }) {
    if (alpha <= 0.01 || radius <= 0.2) return;
    final paint = Paint()
      ..color = Color.lerp(palette.primary, palette.accent, 0.45)!
          .withValues(alpha: alpha.clamp(0.0, 1.0));

    switch (element) {
      case BattleVfxElement.wood:
        // Pointed leaf silhouette
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(angle);
        final leaf = Path()
          ..moveTo(-radius * 1.3, 0)
          ..quadraticBezierTo(0, -radius * 0.9, radius * 1.3, 0)
          ..quadraticBezierTo(0, radius * 0.9, -radius * 1.3, 0)
          ..close();
        canvas.drawPath(leaf, paint);
        canvas.restore();
        break;

      case BattleVfxElement.earth:
        // Angular rock shard / pebble
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(angle);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * 1.7,
            height: radius * 1.4,
          ),
          paint,
        );
        canvas.restore();
        break;

      case BattleVfxElement.metal:
      case BattleVfxElement.classic:
        // Sharp 4-point spark diamond
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(angle);
        final spark = Path()
          ..moveTo(0, -radius * 1.5)
          ..lineTo(radius * 0.65, 0)
          ..lineTo(0, radius * 1.5)
          ..lineTo(-radius * 0.65, 0)
          ..close();
        canvas.drawPath(spark, paint);
        canvas.restore();
        break;

      case BattleVfxElement.fire:
      case BattleVfxElement.water:
        canvas.drawCircle(pos, radius, paint);
        break;
    }
  }

  void _paintCenterOverpowerBurst({
    required Canvas canvas,
    required Offset center,
    required BattleVfxElement winningElem,
    required BattleVfxElement losingElem,
    required double losingDeflectDir,
    required double t,
    required int seed,
  }) {
    final winPalette = _paletteFor(winningElem);
    final losePalette = _paletteFor(losingElem);
    final fade = (1.0 - t).clamp(0.0, 1.0);

    // Bright center collision flash & shockwave ring
    final ringRadius = 10.0 + 36.0 * Curves.easeOut.transform(t);
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * fade
        ..color = winPalette.core.withValues(alpha: 0.85 * fade),
    );
    canvas.drawCircle(
      center,
      18.0 * fade,
      Paint()
        ..color = winPalette.primary.withValues(alpha: 0.6 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0),
    );

    // Losing projectile shatters into deflected elemental fragments
    const shatterCount = 12;
    for (int i = 0; i < shatterCount; i++) {
      final rand1 = _pseudoRandom(seed + i * 19);
      final rand2 = _pseudoRandom(seed + i * 37 + 5);
      final spreadAngle =
          (losingDeflectDir > 0 ? 0.0 : math.pi) + (rand1 - 0.5) * math.pi * 1.15;
      final dist = (10.0 + rand2 * 42.0) * Curves.easeOutCubic.transform(t);
      final shardPos = Offset(
        center.dx + math.cos(spreadAngle) * dist,
        center.dy + math.sin(spreadAngle) * dist,
      );
      _paintElementParticle(
        canvas: canvas,
        pos: shardPos,
        radius: (2.4 + rand1 * 2.5) * fade,
        angle: spreadAngle + t * 5.0,
        alpha: fade,
        element: losingElem,
        palette: losePalette,
      );
    }
  }

  void _paintTieClashExplosion({
    required Canvas canvas,
    required Offset center,
    required BattleVfxElement leftElem,
    required BattleVfxElement rightElem,
    required double t,
    required int seed,
  }) {
    final leftPalette = _paletteFor(leftElem);
    final rightPalette = _paletteFor(rightElem);
    final fade = (1.0 - t).clamp(0.0, 1.0);
    final easeT = Curves.easeOutCubic.transform(t);

    // Neutral gold/white shockwave rings + core flash
    final outerRadius = 12.0 + 54.0 * easeT;
    final innerRadius = 8.0 + 34.0 * easeT;
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * fade
        ..color = Colors.amberAccent.withValues(alpha: 0.85 * fade),
    );
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * fade
        ..color = Colors.white.withValues(alpha: 0.8 * fade),
    );
    canvas.drawCircle(
      center,
      24.0 * fade,
      Paint()
        ..color = Colors.amber.withValues(alpha: 0.65 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0),
    );

    // Both projectiles shatter radially in a neutral + dual-element spark burst
    const totalSparks = 20;
    for (int i = 0; i < totalSparks; i++) {
      final isLeftSpark = i.isEven;
      final elem = isLeftSpark ? leftElem : rightElem;
      final palette = isLeftSpark ? leftPalette : rightPalette;
      final r1 = _pseudoRandom(seed + i * 23);
      final r2 = _pseudoRandom(seed + i * 41 + 9);
      final angle = (i / totalSparks) * 2 * math.pi + (r1 - 0.5) * 0.35;
      final dist = (12.0 + r2 * 52.0) * easeT;
      final pos = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );
      _paintElementParticle(
        canvas: canvas,
        pos: pos,
        radius: (2.5 + r1 * 3.0) * fade,
        angle: angle + t * 6.0,
        alpha: fade,
        element: elem,
        palette: palette,
      );
    }
  }

  void _paintElementalImpactExplosion({
    required Canvas canvas,
    required Offset center,
    required BattleVfxElement element,
    required double t,
    required int seed,
  }) {
    final palette = _paletteFor(element);
    final fade = (1.0 - t).clamp(0.0, 1.0);
    final easeT = Curves.easeOutCubic.transform(t);

    // 1. Ambient explosion glow + bright core flash
    canvas.drawCircle(
      center,
      (36.0 + 22.0 * easeT) * fade,
      Paint()
        ..color = palette.primary.withValues(alpha: 0.65 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0),
    );
    canvas.drawCircle(
      center,
      22.0 * fade,
      Paint()..color = palette.core.withValues(alpha: 0.9 * fade),
    );

    // 2. Expanding shockwave rings
    final primaryRingRadius = 14.0 + 52.0 * easeT;
    canvas.drawCircle(
      center,
      primaryRingRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.8 * fade
        ..color = palette.primary.withValues(alpha: 0.9 * fade),
    );

    final secondaryRingRadius = 8.0 + 38.0 * easeT;
    canvas.drawCircle(
      center,
      secondaryRingRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * fade
        ..color = palette.accent.withValues(alpha: 0.8 * fade),
    );

    // 3. Element-specific signature burst overlay (slash lines / splash waves / flame rays)
    if (element == BattleVfxElement.metal) {
      final slashPaint = Paint()
        ..strokeWidth = 2.6 * fade
        ..strokeCap = StrokeCap.round
        ..color = palette.core.withValues(alpha: 0.92 * fade);
      for (int s = 0; s < 4; s++) {
        final a = (s * math.pi / 4) + 0.35;
        final len = 24.0 + 34.0 * easeT;
        canvas.drawLine(
          Offset(center.dx - math.cos(a) * len, center.dy - math.sin(a) * len),
          Offset(center.dx + math.cos(a) * len, center.dy + math.sin(a) * len),
          slashPaint,
        );
      }
    } else if (element == BattleVfxElement.water) {
      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * fade
        ..strokeCap = StrokeCap.round
        ..color = palette.core.withValues(alpha: 0.85 * fade);
      for (int w = 0; w < 4; w++) {
        final startA = w * (math.pi / 2) + t * 2.0;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: 18.0 + 36.0 * easeT),
          startA,
          math.pi * 0.32,
          false,
          wavePaint,
        );
      }
    }

    // 4. Radial flying elemental particles (embers, droplets, leaves, shards, or sparks)
    const burstParticles = 20;
    for (int i = 0; i < burstParticles; i++) {
      final r1 = _pseudoRandom(seed + i * 17);
      final r2 = _pseudoRandom(seed + i * 31 + 3);
      final angle = (i / burstParticles) * 2 * math.pi + (r1 - 0.5) * 0.28;
      final dist = (14.0 + r2 * 50.0) * easeT;
      final pos = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );
      _paintElementParticle(
        canvas: canvas,
        pos: pos,
        radius: (2.8 + r1 * 3.4) * fade,
        angle: angle + t * 6.0,
        alpha: fade,
        element: element,
        palette: palette,
      );
    }
  }

  double _pseudoRandom(int seed) {
    final x = math.sin(seed * 12.9898 + 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant BattleVfxPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isAnimating != isAnimating ||
        oldDelegate.roundId != roundId ||
        oldDelegate.userMove != userMove ||
        oldDelegate.computerMove != computerMove ||
        oldDelegate.winner != winner ||
        oldDelegate.elementalMode != elementalMode ||
        oldDelegate.leftCenterX != leftCenterX ||
        oldDelegate.rightCenterX != rightCenterX ||
        oldDelegate.centerX != centerX;
  }
}

class _ElementPalette {
  final Color core;
  final Color primary;
  final Color secondary;
  final Color accent;

  const _ElementPalette({
    required this.core,
    required this.primary,
    required this.secondary,
    required this.accent,
  });
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
    const double orbDiameter = 86.0;

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
