import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/move.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import 'elemental_symbol_icon.dart';
import 'mana_pool_orb.dart';
import 'metal_wizard_lair_icon.dart';
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

enum _BossActionType {
  none,
  attack,
  hit,
}

class VersusArena extends StatefulWidget {
  static const int vfxDurationMs = 750;
  static const int clashTimeMs = 300;
  static const int impactTimeMs = 550;
  static const int damageIndicatorDurationMs = 650;
  static const int bossActionDurationMs = 450;

  final HandMove? userMove;
  final HandMove? computerMove;
  final RoundWinner? winner;
  final LocalizationService localization;
  final bool animationsEnabled;
  final int roundId;
  final int userHp;
  final int playerMaxHp;
  final int computerHp;
  final int computerMaxHp;
  final int remainingMana;
  final int maxMana;
  final bool elementalMode;
  final int userDamageAmount;
  final int computerDamageAmount;
  final bool isPhase2;
  final int enemyStage;
  final VoidCallback? onImpactHaptic;
  final Key? pcSlotKey;
  final Key? clashCenterKey;

  const VersusArena({
    super.key,
    required this.userMove,
    required this.computerMove,
    required this.winner,
    required this.localization,
    required this.animationsEnabled,
    required this.roundId,
    this.userHp = 50,
    this.playerMaxHp = 50,
    this.computerHp = 100,
    this.computerMaxHp = 100,
    this.remainingMana = 100,
    this.maxMana = 100,
    this.elementalMode = false,
    this.userDamageAmount = 1,
    this.computerDamageAmount = 1,
    this.isPhase2 = false,
    this.enemyStage = 1,
    this.onImpactHaptic,
    this.pcSlotKey,
    this.clashCenterKey,
  });

  @override
  State<VersusArena> createState() => _VersusArenaState();
}

class _VersusArenaState extends State<VersusArena>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _vfxController;
  late AnimationController _damageIndicatorController;
  late AnimationController _bossIdleController;
  late AnimationController _bossActionController;
  late AnimationController _playerActionController;
  late Animation<double> _punchAnim;
  late Animation<double> _defeatRotationAnim;
  late Animation<double> _drawRotationAnim;
  late Animation<double> _damageIndicatorAnim;
  bool _didTriggerImpactHaptic = false;
  bool _didTriggerImpact = false;
  _BossActionType _bossActionType = _BossActionType.none;
  _BossActionType _playerActionType = _BossActionType.none;

  late int displayedPlayerHp;
  late int displayedPcHp;
  int? _pendingPlayerHp;
  int? _pendingPcHp;
  bool? _activeDamageIsUser;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(_handleClassicTick);
    _vfxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: VersusArena.vfxDurationMs),
    )..addListener(_handleVfxTick);
    _damageIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: VersusArena.damageIndicatorDurationMs,
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _activeDamageIsUser = null;
          });
        }
      });
    _bossIdleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _bossActionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: VersusArena.bossActionDurationMs),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _bossActionType = _BossActionType.none;
          });
        }
      });
    _playerActionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: VersusArena.bossActionDurationMs),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _playerActionType = _BossActionType.none;
          });
        }
      });
    _syncBossIdleAnimation();

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

    _damageIndicatorAnim = CurvedAnimation(
      parent: _damageIndicatorController,
      curve: Curves.easeOut,
    );

    displayedPlayerHp = widget.userHp;
    displayedPcHp = widget.computerHp;

    if (widget.roundId > 0 && widget.animationsEnabled) {
      if (widget.winner == RoundWinner.user) {
        _pendingPcHp = widget.computerHp;
        displayedPcHp = math.min(
          widget.computerMaxHp,
          widget.computerHp + widget.computerDamageAmount,
        );
      } else if (widget.winner == RoundWinner.computer) {
        _pendingPlayerHp = widget.userHp;
        displayedPlayerHp = math.min(
          widget.playerMaxHp,
          widget.userHp + widget.userDamageAmount,
        );
      }
      _startRoundAnimations();
    }
  }

  void _syncBossIdleAnimation() {
    if (widget.animationsEnabled) {
      if (!_bossIdleController.isAnimating) {
        _bossIdleController.repeat(reverse: true);
      }
    } else {
      if (_bossIdleController.isAnimating || _bossIdleController.value != 0.0) {
        _bossIdleController.stop();
        _bossIdleController.reset();
      }
    }
  }

  void _resetBossAction() {
    _bossActionType = _BossActionType.none;
    if (_bossActionController.isAnimating ||
        _bossActionController.value != 0.0) {
      _bossActionController.stop();
      _bossActionController.reset();
    }
    _playerActionType = _BossActionType.none;
    if (_playerActionController.isAnimating ||
        _playerActionController.value != 0.0) {
      _playerActionController.stop();
      _playerActionController.reset();
    }
  }

  void _startRoundAnimations() {
    _didTriggerImpactHaptic = false;
    _didTriggerImpact = false;
    _resetBossAction();
    if (widget.animationsEnabled) {
      if (widget.winner == RoundWinner.computer) {
        _bossActionType = _BossActionType.attack;
        _bossActionController.forward(from: 0.0);
      }
      if (widget.winner == RoundWinner.user ||
          widget.winner == RoundWinner.draw) {
        _playerActionType = _BossActionType.attack;
        _playerActionController.forward(from: 0.0);
      }
    }
    if (widget.elementalMode) {
      _vfxController.forward(from: 0.0);
    } else {
      _animController.forward(from: 0.0);
    }
  }

  void _stopRoundAnimations() {
    _didTriggerImpactHaptic = false;
    _didTriggerImpact = false;
    _resetBossAction();
    if (_animController.isAnimating || _animController.value != 0.0) {
      _animController.stop();
      _animController.reset();
    }
    if (_vfxController.isAnimating || _vfxController.value != 0.0) {
      _vfxController.stop();
      _vfxController.reset();
    }
  }

  void _resetDamageIndicator() {
    _activeDamageIsUser = null;
    if (_damageIndicatorController.isAnimating ||
        _damageIndicatorController.value != 0.0) {
      _damageIndicatorController.stop();
      _damageIndicatorController.reset();
    }
  }

  void _flushPendingHp(VersusArena fallbackWidget) {
    displayedPlayerHp = _pendingPlayerHp ?? fallbackWidget.userHp;
    displayedPcHp = _pendingPcHp ?? fallbackWidget.computerHp;
    _pendingPlayerHp = null;
    _pendingPcHp = null;
  }

  void _commitImpact() {
    if (!mounted) return;
    setState(() {
      if (_pendingPlayerHp != null) {
        displayedPlayerHp = _pendingPlayerHp!;
        _pendingPlayerHp = null;
      }
      if (_pendingPcHp != null) {
        displayedPcHp = _pendingPcHp!;
        _pendingPcHp = null;
      }
      if (widget.winner == RoundWinner.computer) {
        _activeDamageIsUser = true;
        _damageIndicatorController.forward(from: 0.0);
        if (widget.animationsEnabled) {
          _playerActionType = _BossActionType.hit;
          _playerActionController.forward(from: 0.0);
        }
      } else if (widget.winner == RoundWinner.user) {
        _activeDamageIsUser = false;
        _damageIndicatorController.forward(from: 0.0);
        if (widget.animationsEnabled) {
          _bossActionType = _BossActionType.hit;
          _bossActionController.forward(from: 0.0);
        }
      }
    });
  }

  void _handleClassicTick() {
    if (widget.elementalMode ||
        !widget.animationsEnabled ||
        _didTriggerImpact ||
        widget.winner == null ||
        widget.winner == RoundWinner.draw) {
      return;
    }
    if (!_animController.isAnimating &&
        _animController.status != AnimationStatus.completed) {
      return;
    }
    if (_animController.value >= 0.5) {
      _didTriggerImpact = true;
      _commitImpact();
    }
  }

  void _handleVfxTick() {
    if (!widget.elementalMode ||
        !widget.animationsEnabled ||
        widget.winner == null) {
      return;
    }
    if (!_vfxController.isAnimating &&
        _vfxController.status != AnimationStatus.completed) {
      return;
    }
    final elapsedMs = _vfxController.value * VersusArena.vfxDurationMs;
    if (!_didTriggerImpactHaptic) {
      final triggerThresholdMs = widget.winner == RoundWinner.draw
          ? VersusArena.clashTimeMs.toDouble()
          : VersusArena.impactTimeMs.toDouble();
      if (elapsedMs >= triggerThresholdMs) {
        _didTriggerImpactHaptic = true;
        widget.onImpactHaptic?.call();
      }
    }
    if (!_didTriggerImpact &&
        widget.winner != RoundWinner.draw &&
        elapsedMs >= VersusArena.impactTimeMs.toDouble()) {
      _didTriggerImpact = true;
      _commitImpact();
    }
  }

  @override
  void didUpdateWidget(covariant VersusArena oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.animationsEnabled != oldWidget.animationsEnabled) {
      _syncBossIdleAnimation();
    }
    if (widget.enemyStage != oldWidget.enemyStage) {
      _resetBossAction();
    }

    final bool isMatchReset = widget.roundId == 0 ||
        (widget.userHp == widget.playerMaxHp &&
            widget.computerHp == widget.computerMaxHp &&
            (oldWidget.userHp < oldWidget.playerMaxHp ||
                oldWidget.computerHp < oldWidget.computerMaxHp));

    if (isMatchReset) {
      _stopRoundAnimations();
      _resetDamageIndicator();
      _pendingPlayerHp = null;
      _pendingPcHp = null;
      displayedPlayerHp = widget.userHp;
      displayedPcHp = widget.computerHp;
      return;
    }

    if (!widget.animationsEnabled) {
      _stopRoundAnimations();
      _resetDamageIndicator();
      _pendingPlayerHp = null;
      _pendingPcHp = null;
      displayedPlayerHp = widget.userHp;
      displayedPcHp = widget.computerHp;
      return;
    }

    if (widget.elementalMode != oldWidget.elementalMode) {
      _stopRoundAnimations();
      _resetDamageIndicator();
      _flushPendingHp(oldWidget);
    }

    if (widget.roundId != oldWidget.roundId) {
      // Flush any pending HP change from an interrupted turn before starting the next round
      _flushPendingHp(oldWidget);
      _stopRoundAnimations();
      if (widget.roundId > 0) {
        if (widget.userHp != displayedPlayerHp) {
          _pendingPlayerHp = widget.userHp;
        }
        if (widget.computerHp != displayedPcHp) {
          _pendingPcHp = widget.computerHp;
        }
        _startRoundAnimations();
      } else {
        displayedPlayerHp = widget.userHp;
        displayedPcHp = widget.computerHp;
      }
    } else if (widget.userHp != oldWidget.userHp ||
        widget.computerHp != oldWidget.computerHp) {
      _pendingPlayerHp = null;
      _pendingPcHp = null;
      displayedPlayerHp = widget.userHp;
      displayedPcHp = widget.computerHp;
    }
  }

  @override
  void dispose() {
    _animController.removeListener(_handleClassicTick);
    _vfxController.removeListener(_handleVfxTick);
    _bossIdleController.dispose();
    _bossActionController.dispose();
    _playerActionController.dispose();
    _damageIndicatorController.dispose();
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

  double? _calculateDamageProgress({required bool isUser}) {
    if (!widget.animationsEnabled ||
        _activeDamageIsUser != isUser ||
        !_damageIndicatorController.isAnimating) {
      return null;
    }
    return _damageIndicatorAnim.value.clamp(0.0, 1.0);
  }

  String _resolveBossCombatantTitle() {
    switch (widget.enemyStage) {
      case 2:
        return widget.localization
            .t('castle_bestiary_archmage_name', fallback: 'ROBOT ARCHMAGE')
            .toUpperCase();
      case 3:
        return widget.localization
            .t('castle_bestiary_metal_wizard_name', fallback: 'METAL WIZARD')
            .toUpperCase();
      case 4:
        return widget.localization
            .t('castle_bestiary_baby_name', fallback: 'BABY MAGE ROBOT')
            .toUpperCase();
      default:
        return widget.localization
            .t('castle_bestiary_guardian_name', fallback: 'GUARDIAN ROBOT')
            .toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final winner = widget.winner;

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
            ? palette.elementalText(widget.userMove!)
            : palette.successText;
      } else if (pcWins) {
        battleDescription = widget.computerMove!.battleDescriptionAgainst(
              widget.userMove!,
              elemental: widget.elementalMode,
              localization: widget.localization,
            ) ??
            '';
        battleDescColor = widget.elementalMode
            ? palette.elementalText(widget.computerMove!)
            : palette.dangerText;
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
        battleDescColor = palette.isDark ? Colors.white : palette.amberText;
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
        battleDescColor =
            palette.isDark ? const Color(0xFFD6DCE8) : palette.secondaryText;
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
      battleDescColor = palette.isDark ? Colors.white : palette.amberText;
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
      battleDescColor =
          palette.isDark ? const Color(0xFFD6DCE8) : palette.secondaryText;
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
      battleDescColor =
          palette.isDark ? const Color(0xFFD6DCE8) : palette.secondaryText;
    }

    final playerCombatantTitle = widget.localization
        .t('arena_player_label', fallback: 'PLAYER')
        .toUpperCase();
    final bossCombatantTitle = _resolveBossCombatantTitle();

    // Transparent floor container: combatants stand directly on the forge stone floor
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const cardWidth = 104.0;
              const vsWidth = 48.0;
              const totalItemsWidth = cardWidth * 2 + vsWidth;
              const spriteWidth = 112.0;
              const spriteHeight = 112.0;
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
              const orbCenterY = 43.0;
              const floorRunesCenterY = 92.0;

              final playerLeft = (leftCenterX - spriteWidth / 2.0)
                  .clamp(0.0, math.max(0.0, rowWidth - spriteWidth))
                  .toDouble();
              final bossLeft = (rightCenterX - spriteWidth / 2.0)
                  .clamp(0.0, math.max(0.0, rowWidth - spriteWidth))
                  .toDouble();

              final sanctuaryRunesLayer = Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _bossIdleController,
                      _vfxController,
                    ]),
                    builder: (context, _) {
                      final clashPulse = _vfxController.isAnimating
                          ? math.sin(_vfxController.value * math.pi)
                          : 0.0;
                      final idlePulse = widget.animationsEnabled
                          ? _bossIdleController.value
                          : 0.35;
                      return CustomPaint(
                        key: const ValueKey('sanctuary_runes_floor_paint'),
                        painter: SanctuaryRunesFloorPainter(
                          centerX: centerX,
                          centerY: floorRunesCenterY,
                          idlePulse: idlePulse,
                          clashPulse: clashPulse,
                          isDark: palette.isDark,
                          suppressRunesGeometry: widget.enemyStage == 4,
                          leftCenterX: leftCenterX,
                          rightCenterX: rightCenterX,
                        ),
                      );
                    },
                  ),
                ),
              );

              final playerSprite = Positioned(
                top: -2,
                left: playerLeft,
                width: spriteWidth,
                height: spriteHeight,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _bossIdleController,
                      _playerActionController,
                    ]),
                    builder: (context, _) {
                      return _PlayerArenaSprite(
                        key: const ValueKey('versus_player_sprite'),
                        actionType: _playerActionType,
                        idleProgress: widget.animationsEnabled
                            ? _bossIdleController.value
                            : 0.0,
                        actionProgress: widget.animationsEnabled
                            ? _playerActionController.value
                            : 0.0,
                        animationsEnabled: widget.animationsEnabled,
                      );
                    },
                  ),
                ),
              );

              final bossSprite = Positioned(
                top: -2,
                left: bossLeft,
                width: spriteWidth,
                height: spriteHeight,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _bossIdleController,
                      _bossActionController,
                    ]),
                    builder: (context, _) {
                      return _BossArenaSprite(
                        key: ValueKey(
                          'versus_boss_sprite_stage_${widget.enemyStage}',
                        ),
                        enemyStage: widget.enemyStage,
                        actionType: _bossActionType,
                        idleProgress: widget.animationsEnabled
                            ? _bossIdleController.value
                            : 0.0,
                        actionProgress: widget.animationsEnabled
                            ? _bossActionController.value
                            : 0.0,
                        animationsEnabled: widget.animationsEnabled,
                      );
                    },
                  ),
                ),
              );

              final centerColumn = Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: ManaPoolOrb(
                    key: const ValueKey('mana_pool_orb'),
                    size: 88.0,
                    remainingMana: widget.remainingMana,
                    maxMana: widget.maxMana,
                    localization: widget.localization,
                    animationsEnabled: widget.animationsEnabled,
                  ),
                ),
              );

              // Anchor for mid-arena projectile clash and parabolic orb-collection flight arc
              final clashCenterAnchor = Positioned(
                top: orbCenterY - 18.0,
                left: centerX - 18.0,
                width: 36.0,
                height: 36.0,
                child: IgnorePointer(
                  child: SizedBox(
                    key: widget.clashCenterKey,
                    width: 36.0,
                    height: 36.0,
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
                      _damageIndicatorController,
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
                        combatantName: playerCombatantTitle,
                        combatantNameKey:
                            const ValueKey('arena_player_name_label'),
                        move: widget.userMove,
                        isLeft: true,
                        isWinner: userWins,
                        elementalMode: widget.elementalMode,
                        localization: widget.localization,
                        pulseProgress: pulseProgress,
                        hp: displayedPlayerHp,
                        maxHp: widget.playerMaxHp,
                        hpBarKey: const ValueKey('user_hp_bar'),
                        animationsEnabled: widget.animationsEnabled,
                        isDamaged: isDamaged,
                        flashOpacity: _calculateFlash(isDamaged),
                        shakeOffset: _calculateShake(isDamaged),
                        damageIndicatorProgress:
                            _calculateDamageProgress(isUser: true),
                        damageAmount: widget.userDamageAmount,
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
                      _damageIndicatorController,
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
                          combatantName: bossCombatantTitle,
                          combatantNameKey:
                              const ValueKey('arena_boss_name_label'),
                          move: widget.computerMove,
                          isLeft: false,
                          isWinner: pcWins,
                          elementalMode: widget.elementalMode,
                          localization: widget.localization,
                          pulseProgress: pulseProgress,
                          hp: displayedPcHp,
                          maxHp: widget.computerMaxHp,
                          hpBarKey: const ValueKey('pc_hp_bar'),
                          animationsEnabled: widget.animationsEnabled,
                          isDamaged: isDamaged,
                          flashOpacity: _calculateFlash(isDamaged),
                          shakeOffset: _calculateShake(isDamaged),
                          damageIndicatorProgress:
                              _calculateDamageProgress(isUser: false),
                          damageAmount: widget.computerDamageAmount,
                          showElementalShield: widget.isPhase2,
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

              final stackChildren = userWins
                  ? <Widget>[
                      sanctuaryRunesLayer,
                      playerSprite,
                      bossSprite,
                      centerColumn,
                      clashCenterAnchor,
                      pcCard,
                      userCard,
                      vfxOverlay,
                    ]
                  : <Widget>[
                      sanctuaryRunesLayer,
                      playerSprite,
                      bossSprite,
                      centerColumn,
                      clashCenterAnchor,
                      userCard,
                      pcCard,
                      vfxOverlay,
                    ];

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: stackChildren,
              );
            },
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 28,
            child: Center(
              child: Text(
                key: const ValueKey('battle_outcome_description'),
                battleDescription,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: battleDescColor,
                  letterSpacing: 0.3,
                  shadows: const [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 7,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Perspective-compressed (scaleY ~ 0.32) glowing golden-amber runic floor circle
/// painted directly onto the forge stone floor beneath the Cleric and Boss.
///
/// When [suppressRunesGeometry] is `true` (used over `temple_arena_bg`, which
/// already features a painted golden-cyan rune circle), the redundant ring and
/// spoke geometry is suppressed, leaving only soft radial cyan-gold contact
/// shadows beneath the combatants and mid-arena clash light bounce on the stone floor.
class SanctuaryRunesFloorPainter extends CustomPainter {
  final double centerX;
  final double centerY;
  final double idlePulse;
  final double clashPulse;
  final bool isDark;
  final bool suppressRunesGeometry;
  final double? leftCenterX;
  final double? rightCenterX;

  const SanctuaryRunesFloorPainter({
    required this.centerX,
    required this.centerY,
    required this.idlePulse,
    required this.clashPulse,
    required this.isDark,
    this.suppressRunesGeometry = false,
    this.leftCenterX,
    this.rightCenterX,
  });

  void _paintTempleContactShadow(
    Canvas canvas, {
    required double x,
    required double y,
    required Color accentColor,
    required double glowAlpha,
  }) {
    const shadowRadius = 46.0;
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(1.0, 0.28);

    // Subtle grounding contact shadow
    final shadowRect = Rect.fromCircle(center: Offset.zero, radius: shadowRadius);
    canvas.drawCircle(
      Offset.zero,
      shadowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: isDark ? 0.42 : 0.24),
            Colors.black.withValues(alpha: isDark ? 0.16 : 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(shadowRect),
    );

    // Soft radial cyan-gold floor bounce under the combatant
    final bounceRadius = shadowRadius * 1.18;
    final bounceRect = Rect.fromCircle(center: Offset.zero, radius: bounceRadius);
    canvas.drawCircle(
      Offset.zero,
      bounceRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accentColor.withValues(alpha: glowAlpha * 0.42),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(bounceRect),
    );

    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final radiusX = math.min(size.width * 0.44, 165.0);
    const scaleY = 0.32;
    final glowAlpha = (isDark ? 0.36 : 0.24) + 0.12 * idlePulse + 0.24 * clashPulse;

    if (suppressRunesGeometry) {
      // Soft radial cyan-gold contact shadows under Cleric (left) & Baby Mage Robot (right)
      final contactY = centerY - 2.0;
      _paintTempleContactShadow(
        canvas,
        x: leftCenterX ?? (centerX - radiusX * 0.62),
        y: contactY,
        accentColor: const Color(0xFF00E5FF),
        glowAlpha: glowAlpha,
      );
      _paintTempleContactShadow(
        canvas,
        x: rightCenterX ?? (centerX + radiusX * 0.62),
        y: contactY,
        accentColor: const Color(0xFFFFE082),
        glowAlpha: glowAlpha,
      );

      // Soft mid-arena cyan-gold clash light bounce over the Temple's painted rune floor
      canvas.save();
      canvas.translate(centerX, centerY);
      canvas.scale(1.0, scaleY);
      final bounceRadius = radiusX * (0.95 + 0.18 * clashPulse);
      final bounceRect = Rect.fromCircle(center: Offset.zero, radius: bounceRadius);
      canvas.drawCircle(
        Offset.zero,
        bounceRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFE082).withValues(
                alpha: (glowAlpha * (0.34 + 0.55 * clashPulse)).clamp(0.0, 0.85),
              ),
              const Color(0xFF80DEEA).withValues(
                alpha: (glowAlpha * (0.24 + 0.40 * clashPulse)).clamp(0.0, 0.70),
              ),
              Colors.transparent,
            ],
            stops: const [0.0, 0.52, 1.0],
          ).createShader(bounceRect),
      );
      canvas.restore();
      return;
    }

    final runeAlpha = (isDark ? 0.72 : 0.55) + 0.14 * idlePulse + 0.14 * clashPulse;

    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.scale(1.0, scaleY);

    // 1. Soft radial golden-amber sanctuary floor lighting
    final glowRect = Rect.fromCircle(center: Offset.zero, radius: radiusX * 1.15);
    canvas.drawCircle(
      Offset.zero,
      radiusX * 1.15,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD54F).withValues(alpha: glowAlpha * 0.85),
            const Color(0xFFFF8F00).withValues(alpha: glowAlpha * 0.48),
            Colors.transparent,
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(glowRect),
    );

    // 2. Outer and inner runic rings
    final outerRingPaint = Paint()
      ..color = const Color(0xFFFFCA28).withValues(alpha: runeAlpha.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final innerRingPaint = Paint()
      ..color = const Color(0xFFFFE082).withValues(alpha: (runeAlpha * 0.85).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawCircle(Offset.zero, radiusX, outerRingPaint);
    canvas.drawCircle(Offset.zero, radiusX * 0.84, innerRingPaint);
    canvas.drawCircle(Offset.zero, radiusX * 0.46, innerRingPaint);

    // 3. 12 radial arcane rune spokes & sigil ticks between the two outer rings
    final tickPaint = Paint()
      ..color = const Color(0xFFFFECB3).withValues(alpha: (runeAlpha * 0.90).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final angle = i * (math.pi / 6.0);
      final c = math.cos(angle);
      final s = math.sin(angle);
      final rIn = (i % 3 == 0) ? radiusX * 0.46 : radiusX * 0.84;
      canvas.drawLine(
        Offset(c * rIn, s * rIn),
        Offset(c * radiusX, s * radiusX),
        tickPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SanctuaryRunesFloorPainter oldDelegate) {
    return oldDelegate.centerX != centerX ||
        oldDelegate.centerY != centerY ||
        oldDelegate.idlePulse != idlePulse ||
        oldDelegate.clashPulse != clashPulse ||
        oldDelegate.isDark != isDark ||
        oldDelegate.suppressRunesGeometry != suppressRunesGeometry ||
        oldDelegate.leftCenterX != leftCenterX ||
        oldDelegate.rightCenterX != rightCenterX;
  }
}

/// Full-body Player Cleric sprite (`assets/images/player/cleric_idle.png`) with
/// subtle breathing bob, forward cast lunge/glow pulse, and hit shake/flash.
class _PlayerArenaSprite extends StatelessWidget {
  final _BossActionType actionType;
  final double idleProgress;
  final double actionProgress;
  final bool animationsEnabled;

  const _PlayerArenaSprite({
    super.key,
    required this.actionType,
    required this.idleProgress,
    required this.actionProgress,
    required this.animationsEnabled,
  });

  @override
  Widget build(BuildContext context) {
    const assetPath = 'assets/images/player/cleric_idle.png';
    final floatDy =
        animationsEnabled ? -math.sin(idleProgress * math.pi) * 2.2 : 0.0;
    double scale = animationsEnabled ? (1.0 + 0.022 * idleProgress) : 1.0;
    double dx = 0.0;
    double dy = floatDy;
    double glowAlpha = 0.22 + (animationsEnabled ? 0.10 * idleProgress : 0.0);
    Color glowColor = const Color(0xFF00E5FF);

    if (animationsEnabled && actionType != _BossActionType.none) {
      final t = actionProgress.clamp(0.0, 1.0);
      final arc = math.sin(t * math.pi);
      if (actionType == _BossActionType.attack) {
        dx = 5.5 * arc;
        scale += 0.06 * arc;
        glowAlpha = 0.30 + 0.48 * arc;
        glowColor = const Color(0xFF64F5FF);
      } else {
        dx = math.sin(t * math.pi * 6) * (1.0 - t) * 5.0;
        glowAlpha = 0.32 + 0.48 * (1.0 - t);
        glowColor = Colors.redAccent;
      }
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: glowAlpha.clamp(0.0, 0.9)),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: scale,
            child: Image.asset(
              assetPath,
              key: const ValueKey<String>(assetPath),
              gaplessPlayback: true,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.person_rounded,
                size: 48,
                color: Color(0xFF00E5FF),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BossArenaSprite extends StatelessWidget {
  final int enemyStage;
  final _BossActionType actionType;
  final double idleProgress;
  final double actionProgress;
  final bool animationsEnabled;

  const _BossArenaSprite({
    super.key,
    required this.enemyStage,
    required this.actionType,
    required this.idleProgress,
    required this.actionProgress,
    required this.animationsEnabled,
  });

  String? _resolveSpriteAsset() {
    switch (enemyStage) {
      case 2:
        return 'assets/images/enemies/robot_archmage_idle.png';
      case 3:
        return 'assets/images/enemies/metal_wizard_idle.png';
      case 4:
        return 'assets/images/enemies/baby_robot_mage_idle.png';
      default:
        switch (actionType) {
          case _BossActionType.attack:
            return 'assets/images/enemies/guardian_robot_attack.png';
          case _BossActionType.hit:
            return 'assets/images/enemies/guardian_robot_hit.png';
          case _BossActionType.none:
            return 'assets/images/enemies/guardian_robot_idle.png';
        }
    }
  }

  Color _stageAuraColor() {
    switch (enemyStage) {
      case 2:
        return const Color(0xFFCE93D8);
      case 3:
        return const Color(0xFFFFCA28);
      case 4:
        return const Color(0xFFFF8A65);
      default:
        return const Color(0xFFAB47BC);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = _resolveSpriteAsset();
    final auraBase = _stageAuraColor();

    // Gentle idle breathing & floating motion
    final floatDy =
        animationsEnabled ? -math.sin(idleProgress * math.pi) * 2.5 : 0.0;
    double scale = animationsEnabled ? (1.0 + 0.024 * idleProgress) : 1.0;
    double dx = 0.0;
    double dy = floatDy;
    double tiltAngle = 0.0;
    double glowAlpha = 0.22 + (animationsEnabled ? 0.10 * idleProgress : 0.0);
    Color glowColor = auraBase;

    if (animationsEnabled && actionType != _BossActionType.none) {
      final t = actionProgress.clamp(0.0, 1.0);
      final arc = math.sin(t * math.pi);

      if (enemyStage == 4) {
        // Baby Mage Robot: playful bounce & tilt on attack and hit
        if (actionType == _BossActionType.attack) {
          dy += -arc * 7.5;
          tiltAngle = math.sin(t * math.pi * 2) * 0.14;
          scale += 0.07 * arc;
          glowAlpha = 0.25 + 0.45 * arc;
          glowColor = const Color(0xFFBA68C8);
        } else {
          dx = math.sin(t * math.pi * 6) * (1.0 - t) * 5.0;
          dy += -arc * 4.5;
          tiltAngle = -arc * 0.12;
          glowAlpha = 0.30 + 0.45 * (1.0 - t);
          glowColor = Colors.redAccent;
        }
      } else if (enemyStage == 2) {
        // Robot Archmage: subtle scale/glow pulse on attack and shake on hit
        if (actionType == _BossActionType.attack) {
          scale += 0.10 * arc;
          glowAlpha = 0.30 + 0.55 * arc;
          glowColor = const Color(0xFFFFB300);
        } else {
          dx = math.sin(t * math.pi * 6) * (1.0 - t) * 5.0;
          glowAlpha = 0.30 + 0.45 * (1.0 - t);
          glowColor = Colors.redAccent;
        }
      } else if (enemyStage == 3) {
        // Metal Wizard: golden clockwork glow pulse on attack and shake on hit
        if (actionType == _BossActionType.attack) {
          dx = -5.0 * arc;
          scale += 0.08 * arc;
          glowAlpha = 0.30 + 0.52 * arc;
          glowColor = const Color(0xFFFFD54F);
        } else {
          dx = math.sin(t * math.pi * 6) * (1.0 - t) * 5.0;
          glowAlpha = 0.30 + 0.45 * (1.0 - t);
          glowColor = Colors.redAccent;
        }
      } else {
        // Phase 1 Guardian Robot: attack swap + subtle lunge pulse; hit swap + horizontal shake
        if (actionType == _BossActionType.attack) {
          dx = -4.5 * arc;
          scale += 0.07 * arc;
          glowAlpha = 0.28 + 0.48 * arc;
          glowColor = const Color(0xFFCE93D8);
        } else {
          dx = math.sin(t * math.pi * 6) * (1.0 - t) * 5.0;
          glowAlpha = 0.28 + 0.45 * (1.0 - t);
          glowColor = Colors.redAccent;
        }
      }
    }

    final Widget spriteContent = assetPath != null
        ? Image.asset(
            assetPath,
            key: ValueKey<String>(assetPath),
            gaplessPlayback: true,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.smart_toy_rounded,
              size: 48,
              color: auraBase,
            ),
          )
        : const MetalWizardLairIcon(size: 52);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Subtle radial stage aura behind the boss sprite
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: glowAlpha.clamp(0.0, 0.9)),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: tiltAngle,
            child: Transform.scale(
              scale: scale,
              child: spriteContent,
            ),
          ),
        ),
      ],
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
          core: Color(0xFFFFECD6),
          primary: Color(0xFFC47A38),
          secondary: Color(0xFF593214),
          accent: Color(0xFFE29E5A),
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
        // Rotating jagged bronze-brown meteor/rock polygon with luminous caramel core
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
  final String combatantName;
  final Key? combatantNameKey;
  final HandMove? move;
  final bool isLeft;
  final bool isWinner;
  final bool elementalMode;
  final LocalizationService localization;
  final double pulseProgress;
  final int hp;
  final int maxHp;
  final Key? hpBarKey;
  final bool animationsEnabled;
  final bool isDamaged;
  final double flashOpacity;
  final double shakeOffset;
  final double? damageIndicatorProgress;
  final int damageAmount;
  final bool showElementalShield;
  final Widget Function(BuildContext context, Widget handWidget) handBuilder;

  const _MoveCard({
    required this.combatantName,
    this.combatantNameKey,
    required this.move,
    required this.isLeft,
    required this.isWinner,
    required this.elementalMode,
    required this.localization,
    this.pulseProgress = 0.0,
    required this.hp,
    required this.maxHp,
    this.hpBarKey,
    this.animationsEnabled = true,
    required this.isDamaged,
    required this.flashOpacity,
    required this.shakeOffset,
    required this.damageIndicatorProgress,
    required this.damageAmount,
    this.showElementalShield = false,
    required this.handBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final assetPath = isLeft ? move?.leftAsset : move?.rightAsset;
    final hasAsset = assetPath != null && assetPath.isNotEmpty;

    final bool isElementalOrb = elementalMode && move != null;
    final bool isEarth = move == HandMove.lizard;
    final Color primaryElementColor =
        move?.elementalPrimaryColor ?? Colors.amber;
    final Color secondaryElementColor =
        move?.elementalSecondaryColor ?? Colors.deepOrange;
    const Color earthIconColor = Color(0xFFE29E5A);

    final double orbScale =
        (isElementalOrb && isWinner) ? (1.0 + 0.08 * pulseProgress) : 1.0;
    const double orbDiameter = 86.0;

    // In Elemental Mode, keep the container transparent so the full-body Cleric and Boss
    // sprites stand directly on the forge sanctuary runes, while displaying a compact
    // glowing spell-cast crest near the staff head when a move is active.
    final BoxDecoration circleDecoration = elementalMode
        ? const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          )
        : BoxDecoration(
            color: isWinner
                ? (palette.isDark
                      ? Colors.green.withValues(alpha: 0.25)
                      : palette.successText.withValues(alpha: 0.14))
                : (palette.isDark
                      ? Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.85,
                        )
                      : palette.sandCardSurface),
            shape: BoxShape.circle,
            border: Border.all(
              color: isWinner
                  ? (palette.isDark ? Colors.green : palette.successText)
                  : (flashOpacity > 0.0
                      ? Color.lerp(
                          Colors.white,
                          Colors.redAccent,
                          0.65,
                        )!.withValues(alpha: 0.85)
                      : (palette.isDark
                            ? Colors.white24
                            : palette.sandCardBorder)),
              width: isWinner ? 3 : (flashOpacity > 0.0 ? 2.5 : 1.5),
            ),
            boxShadow: isWinner
                ? [
                    BoxShadow(
                      color: (palette.isDark
                              ? Colors.green
                              : palette.successText)
                          .withValues(alpha: 0.35),
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
          child: elementalMode
              ? Align(
                  alignment:
                      isLeft ? Alignment.topRight : Alignment.topLeft,
                  child: move == null
                      ? const SizedBox.shrink()
                      : Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0E121B)
                                .withValues(alpha: 0.84),
                            border: Border.all(
                              color: isEarth
                                  ? earthIconColor
                                  : primaryElementColor,
                              width: isWinner ? 1.8 : 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryElementColor.withValues(
                                  alpha: isWinner ? 0.65 : 0.40,
                                ),
                                blurRadius: isWinner ? 10 : 6,
                              ),
                              if (isWinner)
                                BoxShadow(
                                  color: secondaryElementColor
                                      .withValues(alpha: 0.35),
                                  blurRadius: 12,
                                ),
                            ],
                          ),
                          child: Center(
                            child: ElementalSymbolIcon(
                              move: move!,
                              size: 18 * orbScale,
                            ),
                          ),
                        ),
                )
              : Center(
                  child: move == null
                      ? Text(
                          '?',
                          style: TextStyle(
                            fontSize: 34,
                            color: palette.isDark
                                ? Colors.grey
                                : palette.mutedText,
                          ),
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
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    Colors.white,
                    Colors.redAccent,
                    0.65,
                  )!.withValues(
                    alpha: flashOpacity.clamp(0.0, 1.0) *
                        (elementalMode ? 0.32 : 0.65),
                  ),
                ),
              ),
            ),
          ),

        // Phase 2 Archmage Elemental Shield badge (overlay, zero layout height change)
        if (showElementalShield)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              key: const ValueKey('phase2_boss_shield_badge'),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF14161D),
                border: Border.all(
                  color: Colors.amber,
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.55),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_rounded,
                size: 13,
                color: Colors.amber,
              ),
            ),
          ),
      ],
    );

    final paddingLeft = shakeOffset > 0 ? shakeOffset : 0.0;
    final paddingRight = shakeOffset < 0 ? -shakeOffset : 0.0;

    return SizedBox(
      width: 104,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(left: paddingLeft, right: paddingRight),
            child: handBuilder(context, handCircle),
          ),
          const SizedBox(height: 4),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              RpgHpBar(
                key: hpBarKey,
                width: 104.0,
                height: 17.0,
                hp: hp,
                maxHp: maxHp,
                flashOpacity: flashOpacity,
                shakeOffset: shakeOffset,
                animationsEnabled: animationsEnabled,
              ),
              if (damageIndicatorProgress != null)
                Positioned(
                  bottom: 18.0 + (24.0 * damageIndicatorProgress!),
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (1.0 - damageIndicatorProgress!).clamp(0.0, 1.0),
                      child: Row(
                        key: isLeft
                            ? const ValueKey('user_damage_indicator')
                            : const ValueKey('pc_damage_indicator'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '-$damageAmount',
                            style: const TextStyle(
                              color: Color(0xFFFF5A5F),
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              height: 1.0,
                              letterSpacing: 0.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 3.0,
                                  offset: Offset(0, 1),
                                ),
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 6.0,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.favorite_rounded,
                            size: 10.5,
                            color: Color(0xFFFF5A5F),
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 3.0,
                                offset: Offset(0, 1),
                              ),
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 6.0,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: 104,
            height: 14,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  combatantName,
                  key: combatantNameKey,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                    height: 1.1,
                    letterSpacing: 0.5,
                    color: palette.isDark ? Colors.white : palette.primaryText,
                    shadows: const [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
