import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/royal_garden_tutorial_controller.dart';
import '../../models/move.dart';
import '../../services/audio_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import '../screens/game_screen.dart';
import 'elemental_energy_sphere.dart';
import 'elemental_symbol_icon.dart';
import 'versus_arena.dart';

enum _CombatActionType {
  none,
  attack,
  hit,
}

/// Playable Royal Garden Prologue Tutorial Battle (`3 Royal Guardian Mages`
/// vs. `Guardian Robot`) embedded inside [IntroStoryScreen].
///
/// Reuses the exact battle choreography, timing constants, [BattleVfxPainter]
/// projectile/clash/impact VFX, recoil/flash feedback, and curved
/// [GameScreen.evaluateOrbBezier] collectible orb flight from the main Cleric
/// battle (`GameScreen` / `VersusArena`), paired with a true coordinated
/// position swap between the chosen living mage and the front/active mage slot.
class RoyalGardenTutorialBattle extends StatefulWidget {
  final GameController gameController;
  final RoyalGardenTutorialController? tutorialController;
  final bool isReplay;
  final VoidCallback onSkip;
  final void Function({
    required int fireOrbs,
    required int waterOrbs,
    required int woodOrbs,
  }) onBattleCompleted;

  const RoyalGardenTutorialBattle({
    super.key,
    required this.gameController,
    this.tutorialController,
    this.isReplay = false,
    required this.onSkip,
    required this.onBattleCompleted,
  });

  @override
  State<RoyalGardenTutorialBattle> createState() =>
      _RoyalGardenTutorialBattleState();
}

class _RoyalGardenTutorialBattleState extends State<RoyalGardenTutorialBattle>
    with TickerProviderStateMixin {
  /// Clean desaturation color matrix for defeated mage buttons (no cracks/chains).
  static const ColorFilter _grayscaleFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  final GlobalKey _rootStackKey = GlobalKey();
  final GlobalKey _clashCenterKey = GlobalKey();
  final GlobalKey _orbPouchKey = GlobalKey();

  late final RoyalGardenTutorialController _tutorial;
  late final bool _ownsTutorialController;

  // Ambient & highlight animation controllers
  late final AnimationController _gardenAtmosphereController;
  late final AnimationController _idleBobController;
  late final AnimationController _highlightPulseController;

  // Main-battle-identical combat choreography controllers (VersusArena + GameScreen)
  late final AnimationController _vfxController;
  late final AnimationController _damageIndicatorController;
  late final AnimationController _playerActionController;
  late final AnimationController _bossActionController;
  late final AnimationController _flyingOrbController;
  late final Animation<double> _damageIndicatorAnim;

  _CombatActionType _playerActionType = _CombatActionType.none;
  _CombatActionType _bossActionType = _CombatActionType.none;
  HandMove? _impactTargetMage;
  bool _didTriggerImpactHaptic = false;
  bool _didTriggerImpact = false;
  bool _activeUserDamage = false;
  bool _activeRobotDamage = false;

  // Impact-synchronized displayed HP (matching VersusArena._commitImpact)
  late int _displayedRobotHp;
  late Map<HandMove, int> _displayedMageHp;
  int? _pendingRobotHp;
  final Map<HandMove, int> _pendingMageHp = {};

  int _lastHandledOrbEventId = 0;
  int _lastHandledRoundId = 0;
  HandMove? _activeFlyingOrbMove;

  BgmTrack? _previousBgmTrack;
  Timer? _completionTimer;
  bool _hasReportedCompletion = false;

  bool get _roundDealsRobotDamage =>
      _tutorial.lastRoundWinner == RoundWinner.user;

  bool get _roundDealsMageDamage =>
      _tutorial.lastRoundWinner == RoundWinner.computer;

  bool get _roundHasAnyImpactDamage =>
      _roundDealsRobotDamage || _roundDealsMageDamage;

  @override
  void initState() {
    super.initState();
    _ownsTutorialController = widget.tutorialController == null;
    _tutorial = widget.tutorialController ??
        RoyalGardenTutorialController(isSandboxReplay: widget.isReplay);
    _lastHandledOrbEventId = _tutorial.orbCollectionEventId;
    _lastHandledRoundId = _tutorial.roundId;
    _displayedRobotHp = _tutorial.robotHp;
    _displayedMageHp = {
      for (final m in _tutorial.mages) m.element: m.hp,
    };
    _tutorial.addListener(_onTutorialChanged);

    _gardenAtmosphereController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );
    _idleBobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _highlightPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
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
            _activeUserDamage = false;
            _activeRobotDamage = false;
          });
        }
      });
    _damageIndicatorAnim = CurvedAnimation(
      parent: _damageIndicatorController,
      curve: Curves.easeOut,
    );
    _playerActionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: VersusArena.bossActionDurationMs),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _playerActionType = _CombatActionType.none;
          });
        }
      });
    _bossActionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: VersusArena.bossActionDurationMs),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _bossActionType = _CombatActionType.none;
          });
        }
      });
    _flyingOrbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: GameScreen.orbTotalSequenceMs),
    );

    _previousBgmTrack = widget.gameController.audio.currentTrack;
    unawaited(widget.gameController.audio.playTrack(BgmTrack.battle));

    _syncAnimations();
  }

  @override
  void didUpdateWidget(covariant RoyalGardenTutorialBattle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimations();
  }

  void _syncAnimations() {
    final enabled = widget.gameController.animationsEnabled;
    if (enabled) {
      if (!_gardenAtmosphereController.isAnimating) {
        _gardenAtmosphereController.repeat();
      }
      if (!_idleBobController.isAnimating) {
        _idleBobController.repeat(reverse: true);
      }
      if (!_highlightPulseController.isAnimating) {
        _highlightPulseController.repeat(reverse: true);
      }
    } else {
      _gardenAtmosphereController
        ..stop()
        ..reset();
      _idleBobController
        ..stop()
        ..reset();
      _highlightPulseController
        ..stop()
        ..reset();
      _stopRoundAnimations();
      _flushPendingHpNow();
    }
  }

  void _stopRoundAnimations() {
    _didTriggerImpactHaptic = false;
    _didTriggerImpact = false;
    _playerActionType = _CombatActionType.none;
    _bossActionType = _CombatActionType.none;
    _activeUserDamage = false;
    _activeRobotDamage = false;
    if (_vfxController.isAnimating || _vfxController.value != 0.0) {
      _vfxController
        ..stop()
        ..reset();
    }
    if (_damageIndicatorController.isAnimating ||
        _damageIndicatorController.value != 0.0) {
      _damageIndicatorController
        ..stop()
        ..reset();
    }
    if (_playerActionController.isAnimating ||
        _playerActionController.value != 0.0) {
      _playerActionController
        ..stop()
        ..reset();
    }
    if (_bossActionController.isAnimating ||
        _bossActionController.value != 0.0) {
      _bossActionController
        ..stop()
        ..reset();
    }
    if (_flyingOrbController.isAnimating || _flyingOrbController.value != 0.0) {
      _flyingOrbController
        ..stop()
        ..reset();
    }
  }

  void _flushPendingHpNow() {
    _pendingRobotHp = null;
    _pendingMageHp.clear();
    _displayedRobotHp = _tutorial.robotHp;
    for (final m in _tutorial.mages) {
      _displayedMageHp[m.element] = m.hp;
    }
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _completionTimer = null;
    _tutorial.removeListener(_onTutorialChanged);
    if (_ownsTutorialController) {
      _tutorial.dispose();
    }
    _vfxController.removeListener(_handleVfxTick);
    _gardenAtmosphereController.dispose();
    _idleBobController.dispose();
    _highlightPulseController.dispose();
    _vfxController.dispose();
    _damageIndicatorController.dispose();
    _playerActionController.dispose();
    _bossActionController.dispose();
    _flyingOrbController.dispose();
    final prevTrack = _previousBgmTrack;
    if (prevTrack != null &&
        prevTrack != BgmTrack.battle &&
        widget.gameController.audio.currentTrack == BgmTrack.battle) {
      unawaited(widget.gameController.audio.playTrack(prevTrack));
    }
    super.dispose();
  }

  void _handleVfxTick() {
    if (!widget.gameController.animationsEnabled ||
        _tutorial.lastRoundWinner == null) {
      return;
    }
    if (!_vfxController.isAnimating &&
        _vfxController.status != AnimationStatus.completed) {
      return;
    }
    final elapsedMs = _vfxController.value * VersusArena.vfxDurationMs;
    if (!_didTriggerImpactHaptic) {
      final triggerThresholdMs = !_roundHasAnyImpactDamage
          ? VersusArena.clashTimeMs.toDouble()
          : VersusArena.impactTimeMs.toDouble();
      if (elapsedMs >= triggerThresholdMs) {
        _didTriggerImpactHaptic = true;
        widget.gameController.audio.playVibrate(durationMs: 35);
      }
    }
    if (!_didTriggerImpact &&
        _roundHasAnyImpactDamage &&
        elapsedMs >= VersusArena.impactTimeMs.toDouble()) {
      _didTriggerImpact = true;
      _commitImpact();
    }
  }

  void _commitImpact() {
    if (!mounted) return;
    setState(() {
      if (_pendingRobotHp != null) {
        _displayedRobotHp = _pendingRobotHp!;
        _pendingRobotHp = null;
      }
      if (_pendingMageHp.isNotEmpty) {
        for (final entry in _pendingMageHp.entries) {
          _displayedMageHp[entry.key] = entry.value;
        }
        _pendingMageHp.clear();
      }
      final dealsUser = _roundDealsMageDamage;
      final dealsRobot = _roundDealsRobotDamage;
      if (dealsUser || dealsRobot) {
        _activeUserDamage = dealsUser;
        _activeRobotDamage = dealsRobot;
        _damageIndicatorController.forward(from: 0.0);
        if (widget.gameController.animationsEnabled) {
          if (dealsUser) {
            _playerActionType = _CombatActionType.hit;
            _playerActionController.forward(from: 0.0);
          }
          if (dealsRobot) {
            _bossActionType = _CombatActionType.hit;
            _bossActionController.forward(from: 0.0);
          }
        }
      }
    });
  }

  void _startRoundChoreography() {
    final animationsEnabled = widget.gameController.animationsEnabled;
    if (!animationsEnabled) {
      _stopRoundAnimations();
      _flushPendingHpNow();
      return;
    }

    // Flush any pending HP from an interrupted turn before starting this round.
    if (_pendingRobotHp != null) {
      _displayedRobotHp = _pendingRobotHp!;
      _pendingRobotHp = null;
    }
    if (_pendingMageHp.isNotEmpty) {
      for (final entry in _pendingMageHp.entries) {
        _displayedMageHp[entry.key] = entry.value;
      }
      _pendingMageHp.clear();
    }

    // Defer HP display drop until impactTimeMs (550ms) matching VersusArena.
    if (_tutorial.robotHp != _displayedRobotHp) {
      _pendingRobotHp = _tutorial.robotHp;
    }
    for (final m in _tutorial.mages) {
      final displayed = _displayedMageHp[m.element] ?? m.maxHp;
      if (m.hp != displayed) {
        _pendingMageHp[m.element] = m.hp;
      }
    }

    _impactTargetMage = _tutorial.lastPlayerMove;
    _didTriggerImpactHaptic = false;
    _didTriggerImpact = false;
    _activeUserDamage = false;
    _activeRobotDamage = false;
    _playerActionType = _CombatActionType.none;
    _bossActionType = _CombatActionType.none;

    if (_roundDealsMageDamage) {
      _bossActionType = _CombatActionType.attack;
      _bossActionController.forward(from: 0.0);
    }
    if (_roundDealsRobotDamage ||
        _tutorial.lastRoundWinner == RoundWinner.draw) {
      _playerActionType = _CombatActionType.attack;
      _playerActionController.forward(from: 0.0);
    }

    _vfxController.forward(from: 0.0);
  }

  double _calculateShake(bool isDamaged) {
    if (!isDamaged ||
        !widget.gameController.animationsEnabled ||
        !_vfxController.isAnimating ||
        _vfxController.value >= 1.0) {
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
    if (!isDamaged ||
        !widget.gameController.animationsEnabled ||
        !_vfxController.isAnimating ||
        _vfxController.value >= 1.0) {
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

  double? _calculateDamageProgress({required bool isMage}) {
    final isActive = isMage ? _activeUserDamage : _activeRobotDamage;
    if (!widget.gameController.animationsEnabled ||
        !isActive ||
        !_damageIndicatorController.isAnimating) {
      return null;
    }
    return _damageIndicatorAnim.value.clamp(0.0, 1.0);
  }

  void _onTutorialChanged() {
    if (!mounted) return;
    final roundChanged = _tutorial.roundId != _lastHandledRoundId;
    _lastHandledRoundId = _tutorial.roundId;

    if (roundChanged && _tutorial.roundId > 0) {
      _startRoundChoreography();
    } else if (!widget.gameController.animationsEnabled) {
      _flushPendingHpNow();
    }

    if (_tutorial.orbCollectionEventId != _lastHandledOrbEventId) {
      _lastHandledOrbEventId = _tutorial.orbCollectionEventId;
      _activeFlyingOrbMove = _tutorial.lastCollectedOrb;
      if (widget.gameController.animationsEnabled &&
          _activeFlyingOrbMove != null) {
        _flyingOrbController.forward(from: 0.0);
      } else {
        _flyingOrbController
          ..stop()
          ..reset();
      }
    } else if (roundChanged) {
      _flyingOrbController
        ..stop()
        ..reset();
    }

    if (_tutorial.isBattleFinished && !_hasReportedCompletion) {
      _scheduleBattleCompletionTransition();
    }
    setState(() {});
  }

  void _scheduleBattleCompletionTransition() {
    if (_completionTimer != null || _hasReportedCompletion) return;
    widget.gameController.audio.playDefeat();
    final delay = widget.gameController.animationsEnabled
        ? const Duration(milliseconds: 1450)
        : const Duration(milliseconds: 120);
    _completionTimer = Timer(delay, _finishBattleNow);
  }

  void _finishBattleNow() {
    if (_hasReportedCompletion || !mounted) return;
    _hasReportedCompletion = true;
    _completionTimer?.cancel();
    _completionTimer = null;
    widget.onBattleCompleted(
      fireOrbs: _tutorial.collectedFireOrbs,
      waterOrbs: _tutorial.collectedWaterOrbs,
      woodOrbs: _tutorial.collectedWoodOrbs,
    );
  }

  void _handleElementTap(HandMove element) {
    if (!_tutorial.isElementButtonEnabled(element)) return;
    final audio = widget.gameController.audio;
    audio.playTapVibrate();

    final played = _tutorial.playTurn(element);
    if (!played) return;

    final winner = _tutorial.lastRoundWinner;
    if (winner == RoundWinner.user) {
      audio.playWin();
    } else if (winner == RoundWinner.computer) {
      audio.playDefeat();
    } else {
      audio.playDraw();
    }
  }

  Offset _resolveCenterInRoot(GlobalKey targetKey, Offset fallback) {
    final rootBox =
        _rootStackKey.currentContext?.findRenderObject() as RenderBox?;
    final targetBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (rootBox == null ||
        targetBox == null ||
        !rootBox.hasSize ||
        !targetBox.hasSize) {
      return fallback;
    }
    final localCenter = Offset(
      targetBox.size.width * 0.5,
      targetBox.size.height * 0.5,
    );
    final globalCenter = targetBox.localToGlobal(localCenter);
    return rootBox.globalToLocal(globalCenter);
  }

  String _localizedMageName(
    RoyalGuardianMageState mage,
    LocalizationService loc,
  ) {
    return loc.t(mage.nameKey, fallback: mage.fallbackName);
  }

  ({String text, Color accent, IconData icon}) _resolveBannerContent(
    LocalizationService loc,
    AppPalette palette,
  ) {
    if (_tutorial.isBattleFinished) {
      if (_tutorial.triggeredOverdriveFailsafe) {
        return (
          text: loc.t(
            'tutorial_overdrive_strike',
            fallback:
                'Markov Overdrive! The automaton overwhelms the exhausted mages!',
          ),
          accent: const Color(0xFFFF7043),
          icon: Icons.bolt_rounded,
        );
      }
      return (
        text: loc.t(
          'tutorial_mages_fallen',
          fallback: 'The three Royal Guardian Mages have fallen...',
        ),
        accent: const Color(0xFFEF5350),
        icon: Icons.shield_outlined,
      );
    }

    if (_tutorial.isAct1) {
      final tipKey = _tutorial.act1TipKey!;
      final tipFallback = _tutorial.act1TipFallback!;
      final req = _tutorial.act1RequiredPlayerMove!;
      return (
        text: loc.t(tipKey, fallback: tipFallback),
        accent: req.elementalPrimaryColor,
        icon: Icons.auto_awesome_rounded,
      );
    }

    if (_tutorial.justEnteredAct2) {
      return (
        text: loc.t(
          'tutorial_markov_online',
          fallback: 'Markov Matrix online — analyzing patterns...',
        ),
        accent: const Color(0xFF4FC3F7),
        icon: Icons.memory_rounded,
      );
    }

    final koElement = _tutorial.lastKnockedOutMage;
    if (koElement != null) {
      final mageName = _localizedMageName(_tutorial.mageFor(koElement), loc);
      return (
        text: loc
            .t('tutorial_mage_knocked_out', fallback: '{mage} knocked out!')
            .replaceAll('{mage}', mageName),
        accent: const Color(0xFFEF5350),
        icon: Icons.warning_amber_rounded,
      );
    }

    final pMove = _tutorial.lastPlayerMove;
    final rMove = _tutorial.lastRobotMove;
    final winner = _tutorial.lastRoundWinner;
    if (pMove != null && rMove != null && winner != null) {
      if (winner == RoundWinner.user) {
        final desc = pMove.battleDescriptionAgainst(
              rMove,
              elemental: true,
              localization: loc,
            ) ??
            '';
        return (
          text: desc,
          accent: pMove.elementalPrimaryColor,
          icon: Icons.check_circle_outline_rounded,
        );
      } else if (winner == RoundWinner.computer) {
        final desc = rMove.battleDescriptionAgainst(
              pMove,
              elemental: true,
              localization: loc,
            ) ??
            '';
        return (
          text: desc,
          accent: const Color(0xFFFF7043),
          icon: Icons.flash_on_rounded,
        );
      } else {
        return (
          text: loc.t(
            'battle_draw_elemental',
            fallback: "It's a Draw! Elements neutralized.",
          ),
          accent: Colors.amber,
          icon: Icons.balance_rounded,
        );
      }
    }

    return (
      text: loc.t(
        'battle_idle_elemental',
        fallback: 'Choose an element to attack!',
      ),
      accent: Colors.amber,
      icon: Icons.auto_fix_high_rounded,
    );
  }

  String _resolveRobotSpriteAsset() {
    if (widget.gameController.animationsEnabled) {
      switch (_bossActionType) {
        case _CombatActionType.attack:
          return 'assets/images/enemies/guardian_robot_attack.png';
        case _CombatActionType.hit:
          return 'assets/images/enemies/guardian_robot_hit.png';
        case _CombatActionType.none:
          break;
      }
    }
    return 'assets/images/enemies/guardian_robot_idle.png';
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.gameController.localization;
    final palette = AppPalette.of(context);
    final isDark = palette.isDark;
    final animationsEnabled = widget.gameController.animationsEnabled;

    final skipLabel = loc.t('story_skip', fallback: 'Skip');
    final actBadgeLabel = _tutorial.isAct1
        ? loc.t('tutorial_act1_badge', fallback: 'PROLOGUE • ACT I')
        : loc.t('tutorial_act2_badge', fallback: 'PROLOGUE • ACT II');
    final banner = _resolveBannerContent(loc, palette);

    return Scaffold(
      key: const ValueKey('royal_garden_tutorial_battle'),
      backgroundColor: isDark
          ? const Color(0xFF0E1117)
          : const Color(0xFF1F1B18),
      body: Stack(
        key: _rootStackKey,
        fit: StackFit.expand,
        children: [
          // 1. Royal Garden Arena Background
          Image.asset(
            'assets/images/royal_garden_arena_bg.png',
            key: const ValueKey('royal_garden_arena_bg_image'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2B2233), Color(0xFF1C241E)],
                ),
              ),
            ),
          ),

          // 2. Subtle atmospheric scrim so UI bars & sprites remain crisp
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: isDark ? 0.56 : 0.40),
                    Colors.black.withValues(alpha: isDark ? 0.14 : 0.06),
                    Colors.black.withValues(alpha: isDark ? 0.18 : 0.10),
                    Colors.black.withValues(alpha: isDark ? 0.72 : 0.54),
                  ],
                  stops: const [0.0, 0.24, 0.72, 1.0],
                ),
              ),
            ),
          ),

          // 3. Ambient 60 FPS Royal Garden VFX (floating rose petals + warm gold dust)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _gardenAtmosphereController,
                builder: (context, _) {
                  return CustomPaint(
                    key: const ValueKey('royal_garden_atmosphere_paint'),
                    painter: RoyalGardenAtmospherePainter(
                      progress: animationsEnabled
                          ? _gardenAtmosphereController.value
                          : 0.25,
                      isDark: isDark,
                    ),
                  );
                },
              ),
            ),
          ),

          // 4. Foreground Battle HUD, Arena Stage, and 3 Elemental Orb Controls
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Bar: Act Badge + Collected Orbs Pouch + Top-Right Skip (NO Teleport)
                      _buildTopBar(
                        loc: loc,
                        palette: palette,
                        actBadgeLabel: actBadgeLabel,
                        skipLabel: skipLabel,
                        animationsEnabled: animationsEnabled,
                      ),
                      const SizedBox(height: 8),

                      // Concise 1-Line Tactical Guide / Markov Activation / Combat Log Banner
                      _buildTacticalBanner(
                        loc: loc,
                        palette: palette,
                        banner: banner,
                      ),
                      const SizedBox(height: 6),

                      // Center Stone Circle Battle Stage:
                      // Left = 3 Royal Guardian Mages swapping across 3 non-overlapping slots
                      // Center = Exact BattleVfxPainter spell launch/clash/impact VFX
                      // Right = Guardian Robot (100 HP)
                      Expanded(
                        child: _buildArenaStage(
                          loc: loc,
                          palette: palette,
                          animationsEnabled: animationsEnabled,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Bottom Action Deck: 3 Glossy Elemental Buttons (Fire, Water, Wood)
                      _buildBottomActionDeck(
                        loc: loc,
                        palette: palette,
                        animationsEnabled: animationsEnabled,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 5. Collectible Orb Flight Overlay (exact GameScreen curved Bézier path
          //    spawning at 300ms from mid-arena clash center to the top orb pouch)
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
                  final isFlying = animationsEnabled &&
                      orbMove != null &&
                      _flyingOrbController.isAnimating &&
                      elapsedMs + 1e-4 >= GameScreen.orbSpawnDelayMs &&
                      elapsedMs < flightEndMs - 1e-4;
                  if (!isFlying) {
                    return const SizedBox.shrink();
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final fallbackStart = Offset(
                        constraints.maxWidth * 0.56,
                        constraints.maxHeight * 0.54,
                      );
                      final fallbackEnd = Offset(
                        constraints.maxWidth * 0.34,
                        44.0,
                      );
                      final startPos = _resolveCenterInRoot(
                        _clashCenterKey,
                        fallbackStart,
                      );
                      final endPos = _resolveCenterInRoot(
                        _orbPouchKey,
                        fallbackEnd,
                      );
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
                      final currentOrbPos = GameScreen.evaluateOrbBezier(
                        startPos,
                        controlPoint,
                        endPos,
                        curvedT,
                      );
                      final primary = orbMove.elementalPrimaryColor;
                      final secondary = orbMove.elementalSecondaryColor;

                      return Stack(
                        key: const ValueKey('tutorial_flying_orb_vfx'),
                        clipBehavior: Clip.none,
                        children: [
                          for (var i = 1; i <= 4; i++)
                            if (curvedT - i * 0.045 > 0.0)
                              Builder(
                                builder: (_) {
                                  final trailT =
                                      (curvedT - i * 0.045).clamp(0.0, 1.0);
                                  final trailPos = GameScreen.evaluateOrbBezier(
                                    startPos,
                                    controlPoint,
                                    endPos,
                                    trailT,
                                  );
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
                                              alpha: 0.35,
                                            ),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          Positioned(
                            left: currentOrbPos.dx - 13,
                            top: currentOrbPos.dy - 13,
                            child: ElementalEnergySphere(
                              size: 26,
                              primaryColor: primary,
                              secondaryColor: secondary,
                              isDark: true,
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

  Widget _buildTopBar({
    required LocalizationService loc,
    required AppPalette palette,
    required String actBadgeLabel,
    required String skipLabel,
    required bool animationsEnabled,
  }) {
    final isDark = palette.isDark;
    final borderColor = isDark
        ? const Color(0xFFFFB300)
        : const Color(0xFFD9A426);

    return Row(
      key: const ValueKey('tutorial_top_bar'),
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Prologue Act Badge
              Container(
                key: const ValueKey('tutorial_act_badge'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF151923).withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: _tutorial.isAct2
                        ? const Color(0xFF4FC3F7).withValues(alpha: 0.72)
                        : borderColor.withValues(alpha: 0.65),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _tutorial.isAct2
                          ? Icons.memory_rounded
                          : Icons.local_florist_rounded,
                      size: 13,
                      color: _tutorial.isAct2
                          ? const Color(0xFF4FC3F7)
                          : const Color(0xFFFFCA28),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      actBadgeLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: _tutorial.isAct2
                            ? const Color(0xFFB3E5FC)
                            : const Color(0xFFFFE082),
                      ),
                    ),
                  ],
                ),
              ),

              // Compact Tutorial Orbs Pouch (pulses on orb arrival matching GameScreen)
              AnimatedBuilder(
                animation: _flyingOrbController,
                builder: (context, child) {
                  final elapsedMs = _flyingOrbController.value *
                      GameScreen.orbTotalSequenceMs;
                  const pulseStartMs = GameScreen.orbSpawnDelayMs +
                      GameScreen.orbFlightDurationMs;
                  final isPulsing = animationsEnabled &&
                      _flyingOrbController.isAnimating &&
                      elapsedMs >= pulseStartMs;
                  final pulseT = isPulsing
                      ? ((elapsedMs - pulseStartMs) /
                              GameScreen.backpackPulseDurationMs)
                          .clamp(0.0, 1.0)
                      : 0.0;
                  final scale = isPulsing
                      ? 1.0 + math.sin(pulseT * math.pi) * 0.14
                      : 1.0;
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  key: _orbPouchKey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151923).withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    key: const ValueKey('tutorial_orb_pouch'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MiniOrbCount(
                        key: const ValueKey('tutorial_pouch_fire'),
                        move: HandMove.fire,
                        count: _tutorial.collectedFireOrbs,
                      ),
                      const SizedBox(width: 6),
                      _MiniOrbCount(
                        key: const ValueKey('tutorial_pouch_water'),
                        move: HandMove.water,
                        count: _tutorial.collectedWaterOrbs,
                      ),
                      const SizedBox(width: 6),
                      _MiniOrbCount(
                        key: const ValueKey('tutorial_pouch_wood'),
                        move: HandMove.wood,
                        count: _tutorial.collectedWoodOrbs,
                      ),
                    ],
                  ),
                ),
              ),

              if (widget.isReplay)
                Container(
                  key: const ValueKey('tutorial_sandbox_badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Text(
                    loc.t('tutorial_sandbox_badge', fallback: 'REPLAY'),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFE082),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Top-Right Skip Button (Teleport button intentionally omitted)
        TextButton.icon(
          key: const ValueKey('intro_skip_button'),
          onPressed: () {
            widget.gameController.audio.playTapVibrate();
            widget.onSkip();
          },
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFFFE082),
            backgroundColor: const Color(0xFF151923).withValues(alpha: 0.84),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: borderColor.withValues(alpha: 0.55)),
            ),
          ),
          icon: const Icon(Icons.skip_next_rounded, size: 17),
          label: Text(
            skipLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  Widget _buildTacticalBanner({
    required LocalizationService loc,
    required AppPalette palette,
    required ({String text, Color accent, IconData icon}) banner,
  }) {
    final isDark = palette.isDark;
    final surfaceColor = isDark
        ? const Color(0xFF151923).withValues(alpha: 0.90)
        : const Color(0xFFFAF4E6).withValues(alpha: 0.94);
    final textColor = isDark ? Colors.white : const Color(0xFF231F1A);

    return AnimatedContainer(
      key: const ValueKey('tutorial_tactical_banner'),
      height: 50,
      alignment: Alignment.center,
      duration: widget.gameController.animationsEnabled
          ? const Duration(milliseconds: 220)
          : Duration.zero,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: banner.accent.withValues(alpha: 0.78),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: banner.accent.withValues(alpha: 0.22),
            blurRadius: 10,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(banner.icon, size: 18, color: banner.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              banner.text,
              key: const ValueKey('tutorial_tactical_banner_text'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: textColor,
                height: 1.2,
              ),
            ),
          ),
          if (_tutorial.isBattleFinished) ...[
            const SizedBox(width: 8),
            ElevatedButton(
              key: const ValueKey('tutorial_finish_continue_button'),
              onPressed: _finishBattleNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5C22B),
                foregroundColor: const Color(0xFF1E1B16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                loc.t('tutorial_continue_story_btn', fallback: 'Continue'),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArenaStage({
    required LocalizationService loc,
    required AppPalette palette,
    required bool animationsEnabled,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final isCompact = h < 310 || w < 350;

        final double mageSpriteSize =
            (h * (isCompact ? 0.24 : 0.26)).clamp(56.0, 96.0).toDouble();
        final double robotSpriteSize =
            (h * (isCompact ? 0.34 : 0.38)).clamp(80.0, 142.0).toDouble();
        final double mageCardWidth = (w * 0.285).clamp(96.0, 126.0).toDouble();
        final double robotCardWidth = (w * 0.35).clamp(114.0, 160.0).toDouble();

        final double cardEstimatedH = mageSpriteSize + 38.0;
        final double availH = math.max(0.0, h - cardEstimatedH);

        // 3 distinct non-overlapping grounded slots on the Royal Garden stone circle:
        // - upperRear: upper-left rear flank (grounded below top arches)
        // - frontActive: front-center active casting slot facing the Guardian Robot
        // - lowerRear: lower-left rear flank
        final double rearLeft = (w * 0.01).clamp(0.0, 6.0).toDouble();
        final double frontLeft = math.max(
          rearLeft + mageCardWidth * 0.86,
          (w * 0.26).clamp(84.0, 140.0).toDouble(),
        );

        final double upperRearTop = (availH * 0.16)
            .clamp(math.min(12.0, availH), availH)
            .toDouble();
        final double frontActiveTop =
            (availH * 0.54).clamp(0.0, availH).toDouble();
        final double lowerRearTop =
            (availH * 0.92).clamp(0.0, availH).toDouble();

        ({double left, double top}) coordsForSlot(RoyalGardenMageSlot slot) {
          switch (slot) {
            case RoyalGardenMageSlot.upperRear:
              return (left: rearLeft, top: upperRearTop);
            case RoyalGardenMageSlot.frontActive:
              return (left: frontLeft, top: frontActiveTop);
            case RoyalGardenMageSlot.lowerRear:
              return (left: rearLeft, top: lowerRearTop);
          }
        }

        final swapDuration = animationsEnabled
            ? const Duration(milliseconds: 280)
            : Duration.zero;

        final fireSlot = _tutorial.slotOf(HandMove.fire);
        final woodSlot = _tutorial.slotOf(HandMove.wood);
        final waterSlot = _tutorial.slotOf(HandMove.water);

        final firePos = coordsForSlot(fireSlot);
        final woodPos = coordsForSlot(woodSlot);
        final waterPos = coordsForSlot(waterSlot);

        final robotAvailH = math.max(0.0, h - (robotSpriteSize + 78.0));
        final double robotTop = (robotAvailH * 0.54).clamp(4.0, h).toDouble();

        // Exact horizontal clash axis linking the front/active mage and Guardian Robot
        final double leftCenterX = frontLeft + mageCardWidth * 0.5;
        final double rightCenterX = w - robotCardWidth * 0.5;
        final double clashCenterX = (leftCenterX + rightCenterX) * 0.5;
        final double clashCenterY = frontActiveTop + mageSpriteSize * 0.5;

        return AnimatedBuilder(
          animation: Listenable.merge([
            _idleBobController,
            _vfxController,
            _damageIndicatorController,
            _playerActionController,
            _bossActionController,
          ]),
          builder: (context, _) {
            final isVfxActive = animationsEnabled &&
                _tutorial.roundId > 0 &&
                _tutorial.lastPlayerMove != null &&
                _tutorial.lastRobotMove != null &&
                _tutorial.lastRoundWinner != null &&
                _vfxController.isAnimating &&
                _vfxController.value < 1.0;

            final mageDamageProgress = _calculateDamageProgress(isMage: true);
            final robotDamageProgress = _calculateDamageProgress(isMage: false);

            Widget buildMageSlot({
              required HandMove element,
              required RoyalGardenMageSlot slot,
              required ({double left, double top}) pos,
              required double idlePhaseShift,
            }) {
              final mage = _tutorial.mageFor(element);
              final isFront = slot == RoyalGardenMageSlot.frontActive;
              final isTargetOfRound = _impactTargetMage == element;
              final isDamagedThisRound =
                  isTargetOfRound && _roundDealsMageDamage && _tutorial.roundId > 0;
              final actionType =
                  isTargetOfRound ? _playerActionType : _CombatActionType.none;
              final displayedHp = _displayedMageHp[element] ?? mage.hp;
              final isVisuallyDefeated =
                  animationsEnabled ? displayedHp <= 0 : mage.isKnockedOut;

              return AnimatedPositioned(
                key: ValueKey('tutorial_mage_pos_${element.orbKey}'),
                duration: swapDuration,
                curve: Curves.easeInOutCubic,
                left: pos.left,
                top: pos.top,
                width: mageCardWidth,
                child: _RoyalMageCombatant(
                  mage: mage,
                  displayedHp: displayedHp,
                  isVisuallyDefeated: isVisuallyDefeated,
                  spriteSize: mageSpriteSize,
                  idleProgress: animationsEnabled
                      ? ((_idleBobController.value + idlePhaseShift) % 1.0)
                      : 0.0,
                  isFrontActive: isFront && !isVisuallyDefeated,
                  actionType: actionType,
                  actionProgress: animationsEnabled
                      ? _playerActionController.value
                      : 0.0,
                  flashOpacity: _calculateFlash(isDamagedThisRound),
                  shakeOffset: _calculateShake(isDamagedThisRound),
                  damageIndicatorProgress:
                      isTargetOfRound ? mageDamageProgress : null,
                  animationsEnabled: animationsEnabled,
                ),
              );
            }

            return Stack(
              key: const ValueKey('tutorial_arena_stage'),
              clipBehavior: Clip.none,
              children: [
                // Fire Mage
                buildMageSlot(
                  element: HandMove.fire,
                  slot: fireSlot,
                  pos: firePos,
                  idlePhaseShift: 0.0,
                ),

                // Wood Mage
                buildMageSlot(
                  element: HandMove.wood,
                  slot: woodSlot,
                  pos: woodPos,
                  idlePhaseShift: 0.35,
                ),

                // Water Mage
                buildMageSlot(
                  element: HandMove.water,
                  slot: waterSlot,
                  pos: waterPos,
                  idlePhaseShift: 0.65,
                ),

                // Guardian Robot (Right Side of Stone Circle)
                Positioned(
                  right: 0,
                  top: robotTop,
                  width: robotCardWidth,
                  child: _buildGuardianRobotSide(
                    loc: loc,
                    spriteSize: robotSpriteSize,
                    idleProgress:
                        animationsEnabled ? _idleBobController.value : 0.0,
                    actionProgress:
                        animationsEnabled ? _bossActionController.value : 0.0,
                    flashOpacity: _calculateFlash(
                      _roundDealsRobotDamage && _tutorial.roundId > 0,
                    ),
                    shakeOffset: _calculateShake(
                      _roundDealsRobotDamage && _tutorial.roundId > 0,
                    ),
                    damageIndicatorProgress: robotDamageProgress,
                    animationsEnabled: animationsEnabled,
                  ),
                ),

                // Exact Mid-Arena Clash Anchor for Collectible Orb Spawn (300ms)
                Positioned(
                  left: clashCenterX - 18.0,
                  top: clashCenterY - 18.0,
                  width: 36.0,
                  height: 36.0,
                  child: IgnorePointer(
                    child: SizedBox(
                      key: _clashCenterKey,
                      width: 36.0,
                      height: 36.0,
                    ),
                  ),
                ),

                // Identical Main-Battle Elemental Projectile, Mid-Arena Clash (300ms),
                // and Impact Explosion Layer (BattleVfxPainter from VersusArena)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: const ValueKey('tutorial_battle_vfx_layer'),
                      painter: BattleVfxPainter(
                        progress: _vfxController.value,
                        isAnimating: isVfxActive,
                        userMove: _tutorial.lastPlayerMove,
                        computerMove: _tutorial.lastRobotMove,
                        winner: _tutorial.lastRoundWinner,
                        elementalMode: true,
                        roundId: _tutorial.roundId,
                        leftCenterX: leftCenterX,
                        rightCenterX: rightCenterX,
                        centerX: clashCenterX,
                        orbCenterY: clashCenterY,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildGuardianRobotSide({
    required LocalizationService loc,
    required double spriteSize,
    required double idleProgress,
    required double actionProgress,
    required double flashOpacity,
    required double shakeOffset,
    required double? damageIndicatorProgress,
    required bool animationsEnabled,
  }) {
    final robotName = loc.t(
      'castle_bestiary_guardian_name',
      fallback: 'Guardian Robot',
    );
    final telegraphedMove = _tutorial.act1TelegraphedRobotMove;
    final double hpRatio =
        (_displayedRobotHp / _tutorial.robotMaxHp).clamp(0.0, 1.0).toDouble();

    final floatDy =
        animationsEnabled ? -math.sin(idleProgress * math.pi) * 2.5 : 0.0;
    double scale = animationsEnabled ? (1.0 + 0.024 * idleProgress) : 1.0;
    double actionDx = 0.0;
    double glowAlpha = 0.22 + (animationsEnabled ? 0.10 * idleProgress : 0.0);
    Color glowColor = const Color(0xFFAB47BC);

    if (animationsEnabled && _bossActionType != _CombatActionType.none) {
      final t = actionProgress.clamp(0.0, 1.0);
      final arc = math.sin(t * math.pi);
      if (_bossActionType == _CombatActionType.attack) {
        actionDx = -5.5 * arc;
        scale += 0.06 * arc;
        glowAlpha = 0.30 + 0.45 * arc;
        glowColor = const Color(0xFFCE93D8);
      } else {
        actionDx = math.sin(t * math.pi * 6) * (1.0 - t) * 5.0;
        glowAlpha = 0.32 + 0.48 * (1.0 - t);
        glowColor = Colors.redAccent;
      }
    }

    return Column(
      key: const ValueKey('tutorial_guardian_robot'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Act 1 Telegraph Chip (e.g. "Preparing Wood")
        if (telegraphedMove != null)
          Container(
            key: const ValueKey('tutorial_robot_telegraph'),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF141822).withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: telegraphedMove.elementalPrimaryColor.withValues(
                  alpha: 0.85,
                ),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElementalSymbolIcon(move: telegraphedMove, size: 13),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    loc
                        .t(
                          'tutorial_robot_preparing',
                          fallback: 'Preparing {element}',
                        )
                        .replaceAll(
                          '{element}',
                          telegraphedMove.displayLabel(
                            elemental: true,
                            localization: loc,
                          ),
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: telegraphedMove.elementalPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox(height: 6),

        // Guardian Robot Sprite with VersusArena lunge, hit recoil, shake & flash
        Transform.translate(
          offset: Offset(actionDx + shakeOffset, floatDy),
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: spriteSize,
              height: spriteSize,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: spriteSize * 0.68,
                    height: spriteSize * 0.68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withValues(
                            alpha: glowAlpha.clamp(0.0, 0.9),
                          ),
                          blurRadius: 18,
                          spreadRadius: 1.5,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: spriteSize * 0.68,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Image.asset(
                    _resolveRobotSpriteAsset(),
                    key: const ValueKey('tutorial_robot_sprite'),
                    gaplessPlayback: true,
                    width: spriteSize,
                    height: spriteSize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.memory_rounded,
                      size: spriteSize * 0.65,
                      color: const Color(0xFF4FC3F7),
                    ),
                  ),
                  if (flashOpacity > 0.01)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent.withValues(
                              alpha: (flashOpacity * 0.55).clamp(0.0, 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (damageIndicatorProgress != null)
                    Positioned(
                      top: -4.0 - 22.0 * damageIndicatorProgress,
                      right: 8,
                      child: Opacity(
                        opacity: (1.0 - damageIndicatorProgress).clamp(0.0, 1.0),
                        child: Text(
                          '-1',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.amber.shade200,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Guardian Robot Name & HP Bar (100 / 100)
        Transform.translate(
          offset: Offset(shakeOffset * 0.6, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF141822).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: flashOpacity > 0.05
                    ? Colors.redAccent.withValues(alpha: 0.9)
                    : const Color(0xFF4FC3F7).withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  robotName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: hpRatio,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFEF5350),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_displayedRobotHp / ${_tutorial.robotMaxHp}',
                  key: const ValueKey('tutorial_robot_hp'),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFCDD2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionDeck({
    required LocalizationService loc,
    required AppPalette palette,
    required bool animationsEnabled,
  }) {
    final isDark = palette.isDark;
    return Container(
      key: const ValueKey('tutorial_action_deck'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF12151E).withValues(alpha: 0.86)
            : const Color(0xFFFAF4E6).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.amberBorder.withValues(alpha: isDark ? 0.45 : 0.65),
          width: 1.3,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final element in RoyalGardenTutorialController.tutorialElements)
            _buildElementOrbButton(
              element: element,
              loc: loc,
              palette: palette,
              animationsEnabled: animationsEnabled,
            ),
        ],
      ),
    );
  }

  Widget _buildElementOrbButton({
    required HandMove element,
    required LocalizationService loc,
    required AppPalette palette,
    required bool animationsEnabled,
  }) {
    final enabled = _tutorial.isElementButtonEnabled(element);
    final highlighted = _tutorial.isElementButtonHighlighted(element);
    final dimmedForGuide = _tutorial.isElementButtonDimmedForGuide(element);
    final knockedOut = _tutorial.isElementButtonKnockedOut(element);
    final label = element.displayLabel(elemental: true, localization: loc);

    const double orbSize = 74.0;

    Widget orbWidget = SizedBox(
      width: orbSize,
      height: orbSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          ElementalEnergySphere(
            size: orbSize,
            primaryColor: element.elementalPrimaryColor,
            secondaryColor: element.elementalSecondaryColor,
            isDark: palette.isDark,
          ),
          Positioned(
            top: orbSize * 0.13,
            child: ElementalSymbolIcon(move: element, size: 28),
          ),
          Positioned(
            bottom: orbSize * 0.12,
            left: 4,
            right: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 3),
                    Shadow(
                      color: Colors.black,
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (knockedOut) {
      // Clean grayscale/desaturated disabled state — no cracks or chains.
      orbWidget = Opacity(
        opacity: 0.46,
        child: ColorFiltered(
          key: ValueKey('tutorial_move_grayscale_${element.orbKey}'),
          colorFilter: _grayscaleFilter,
          child: orbWidget,
        ),
      );
    } else if (dimmedForGuide) {
      orbWidget = Opacity(
        key: ValueKey('tutorial_move_dimmed_${element.orbKey}'),
        opacity: 0.34,
        child: orbWidget,
      );
    } else if (highlighted) {
      orbWidget = AnimatedBuilder(
        animation: _highlightPulseController,
        builder: (context, child) {
          final pulse = animationsEnabled
              ? _highlightPulseController.value
              : 0.5;
          final scale = 1.03 + 0.05 * pulse;
          return Transform.scale(
            scale: scale,
            child: Container(
              key: ValueKey('tutorial_move_highlight_${element.orbKey}'),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Color.lerp(
                    const Color(0xFFFFD54F),
                    Colors.white,
                    pulse * 0.65,
                  )!,
                  width: 2.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: element.elementalPrimaryColor.withValues(
                      alpha: 0.45 + 0.30 * pulse,
                    ),
                    blurRadius: 14 + 4 * pulse,
                    spreadRadius: 1.5,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: orbWidget,
      );
    }

    // Reserve uniform outer slot dimensions so Act 1 highlight rings never
    // resize the action deck or shift the arena stage vertically into Act 2.
    const double orbSlotSize = orbSize + 12.0;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          key: ValueKey('tutorial_move_btn_${element.orbKey}'),
          customBorder: const CircleBorder(),
          onTap: enabled ? () => _handleElementTap(element) : null,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              width: orbSlotSize,
              height: orbSlotSize,
              child: Center(child: orbWidget),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniOrbCount extends StatelessWidget {
  final HandMove move;
  final int count;

  const _MiniOrbCount({
    super.key,
    required this.move,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final hasOrb = count > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: hasOrb ? 1.0 : 0.42,
          child: ElementalEnergySphere(
            size: 14,
            primaryColor: move.elementalPrimaryColor,
            secondaryColor: move.elementalSecondaryColor,
            isDark: true,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: hasOrb ? Colors.white : Colors.white54,
          ),
        ),
      ],
    );
  }
}

class _RoyalMageCombatant extends StatelessWidget {
  final RoyalGuardianMageState mage;
  final int displayedHp;
  final bool isVisuallyDefeated;
  final double spriteSize;
  final double idleProgress;
  final bool isFrontActive;
  final _CombatActionType actionType;
  final double actionProgress;
  final double flashOpacity;
  final double shakeOffset;
  final double? damageIndicatorProgress;
  final bool animationsEnabled;

  const _RoyalMageCombatant({
    required this.mage,
    required this.displayedHp,
    required this.isVisuallyDefeated,
    required this.spriteSize,
    required this.idleProgress,
    required this.isFrontActive,
    required this.actionType,
    required this.actionProgress,
    required this.flashOpacity,
    required this.shakeOffset,
    required this.damageIndicatorProgress,
    required this.animationsEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final isDefeated = isVisuallyDefeated;
    final double hpRatio = (displayedHp / mage.maxHp).clamp(0.0, 1.0).toDouble();
    final double manaRatio =
        (mage.mana / mage.maxMana).clamp(0.0, 1.0).toDouble();
    final accent = mage.element.elementalPrimaryColor;

    final floatDy = !isDefeated && animationsEnabled
        ? -math.sin(idleProgress * math.pi) * 2.2
        : 0.0;
    double scale = !isDefeated && animationsEnabled
        ? (1.0 + 0.022 * idleProgress)
        : 1.0;
    double actionDx = 0.0;
    double glowAlpha = isFrontActive
        ? 0.24 + (animationsEnabled ? 0.10 * idleProgress : 0.0)
        : 0.0;
    Color glowColor = accent;

    if (!isDefeated && animationsEnabled && actionType != _CombatActionType.none) {
      final t = actionProgress.clamp(0.0, 1.0);
      final arc = math.sin(t * math.pi);
      if (actionType == _CombatActionType.attack) {
        actionDx = 5.5 * arc;
        scale += 0.06 * arc;
        glowAlpha = 0.30 + 0.48 * arc;
      } else {
        actionDx = math.sin(t * math.pi * 6) * (1.0 - t) * 5.0;
        glowAlpha = 0.32 + 0.48 * (1.0 - t);
        glowColor = Colors.redAccent;
      }
    }

    final spriteAsset =
        isDefeated ? mage.deadSpriteAsset : mage.spriteAsset;

    return Column(
      key: ValueKey('tutorial_mage_${mage.element.orbKey}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: Offset(
            actionDx + shakeOffset,
            isDefeated ? 4.0 : floatDy,
          ),
          child: Transform.scale(
            scale: isFrontActive ? scale * 1.05 : scale,
            child: SizedBox(
              width: isDefeated ? spriteSize * 1.12 : spriteSize,
              height: spriteSize,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  if (!isDefeated && glowAlpha > 0.01)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          width: spriteSize * 0.66,
                          height: spriteSize * 0.66,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: glowColor.withValues(
                                  alpha: glowAlpha.clamp(0.0, 0.9),
                                ),
                                blurRadius: 18,
                                spreadRadius: 1.5,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Ground shadow ellipse anchored under feet or fallen body
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: isDefeated ? spriteSize * 0.96 : spriteSize * 0.65,
                      height: isDefeated ? 10 : 9,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.40),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  // Active sprite: swaps directly to mage_<element>_dead.png at 0 HP (no KO badge)
                  Align(
                    alignment: isDefeated
                        ? Alignment.bottomCenter
                        : Alignment.center,
                    child: Image.asset(
                      spriteAsset,
                      key: ValueKey(
                        'tutorial_mage_sprite_${mage.element.orbKey}',
                      ),
                      gaplessPlayback: true,
                      width: isDefeated ? spriteSize * 1.12 : spriteSize,
                      height: isDefeated ? spriteSize * 0.78 : spriteSize,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        mage.element.elementalIcon,
                        size: spriteSize * 0.65,
                        color: accent,
                      ),
                    ),
                  ),
                  if (flashOpacity > 0.01 && !isDefeated)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent.withValues(
                              alpha: (flashOpacity * 0.55).clamp(0.0, 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (damageIndicatorProgress != null)
                    Positioned(
                      top: -4.0 - 20.0 * damageIndicatorProgress!,
                      right: 2,
                      child: Opacity(
                        opacity:
                            (1.0 - damageIndicatorProgress!).clamp(0.0, 1.0),
                        child: Text(
                          '-1',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.redAccent.shade100,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),

        // Compact Mini HP (5/5) & Mana (100/100) Indicator Pill
        Transform.translate(
          offset: Offset(shakeOffset * 0.5, 0),
          child: Container(
            key: ValueKey('tutorial_mage_stats_${mage.element.orbKey}'),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF141822)
                  .withValues(alpha: isDefeated ? 0.68 : 0.88),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDefeated
                    ? Colors.white24
                    : (flashOpacity > 0.05
                          ? Colors.redAccent.withValues(alpha: 0.9)
                          : (isFrontActive
                                ? Colors.amber.withValues(alpha: 0.92)
                                : accent.withValues(alpha: 0.72))),
                width: isFrontActive && !isDefeated ? 1.3 : 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // HP Mini Bar + 5/5 counter
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 9.0,
                      color: Color(0xFFEF5350),
                    ),
                    const SizedBox(width: 2.5),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: hpRatio,
                          minHeight: 4,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDefeated
                                ? Colors.grey
                                : (displayedHp <= 2
                                      ? const Color(0xFFFF5252)
                                      : const Color(0xFF66BB6A)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$displayedHp/${mage.maxHp}',
                      key: ValueKey('tutorial_mage_hp_${mage.element.orbKey}'),
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: isDefeated ? Colors.white54 : Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Mana Mini Bar + 100/100 counter
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.water_drop_rounded,
                      size: 9.0,
                      color: Color(0xFF4FC3F7),
                    ),
                    const SizedBox(width: 2.5),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: manaRatio,
                          minHeight: 3.5,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF29B6F6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${mage.mana}/${mage.maxMana}',
                      key: ValueKey('tutorial_mage_mana_${mage.element.orbKey}'),
                      style: TextStyle(
                        fontSize: 8.0,
                        fontWeight: FontWeight.w700,
                        color: isDefeated
                            ? Colors.white38
                            : const Color(0xFFB3E5FC),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Lightweight 60 FPS ambient particle painter for the Royal Garden arena:
/// - Floating rose petals drifting gently across the courtyard.
/// - Warm golden sunlight dust motes floating through the sunset glow.
class RoyalGardenAtmospherePainter extends CustomPainter {
  final double progress;
  final bool isDark;

  const RoyalGardenAtmospherePainter({
    required this.progress,
    required this.isDark,
  });

  static const List<
      ({
        double xStart,
        double yStart,
        double driftX,
        double driftY,
        double phase,
        double size,
        double spin,
        bool isDeepRose,
      })> _petalSpecs = [
    (xStart: 0.08, yStart: 0.14, driftX: 0.24, driftY: 0.62, phase: 0.02, size: 4.8, spin: 2.0, isDeepRose: true),
    (xStart: 0.22, yStart: 0.08, driftX: 0.20, driftY: 0.68, phase: 0.17, size: 4.0, spin: -1.8, isDeepRose: false),
    (xStart: 0.36, yStart: 0.18, driftX: 0.26, driftY: 0.58, phase: 0.31, size: 4.5, spin: 2.3, isDeepRose: true),
    (xStart: 0.52, yStart: 0.10, driftX: 0.22, driftY: 0.66, phase: 0.46, size: 3.8, spin: -2.1, isDeepRose: false),
    (xStart: 0.66, yStart: 0.16, driftX: 0.18, driftY: 0.60, phase: 0.61, size: 5.0, spin: 1.7, isDeepRose: true),
    (xStart: 0.78, yStart: 0.12, driftX: 0.16, driftY: 0.64, phase: 0.76, size: 4.2, spin: -2.4, isDeepRose: false),
    (xStart: 0.14, yStart: 0.34, driftX: 0.28, driftY: 0.52, phase: 0.88, size: 4.4, spin: 1.9, isDeepRose: false),
    (xStart: 0.44, yStart: 0.28, driftX: 0.21, driftY: 0.54, phase: 0.12, size: 4.6, spin: -1.6, isDeepRose: true),
    (xStart: 0.72, yStart: 0.30, driftX: 0.19, driftY: 0.55, phase: 0.54, size: 3.9, spin: 2.2, isDeepRose: false),
    (xStart: 0.04, yStart: 0.48, driftX: 0.30, driftY: 0.42, phase: 0.39, size: 4.7, spin: -2.0, isDeepRose: true),
    (xStart: 0.58, yStart: 0.42, driftX: 0.23, driftY: 0.46, phase: 0.71, size: 4.1, spin: 1.5, isDeepRose: false),
    (xStart: 0.86, yStart: 0.26, driftX: -0.14, driftY: 0.56, phase: 0.25, size: 4.3, spin: -1.9, isDeepRose: true),
    (xStart: 0.29, yStart: 0.52, driftX: 0.25, driftY: 0.38, phase: 0.93, size: 3.7, spin: 2.1, isDeepRose: false),
    (xStart: 0.82, yStart: 0.46, driftX: -0.12, driftY: 0.42, phase: 0.67, size: 4.6, spin: 1.8, isDeepRose: true),
  ];

  static const List<
      ({
        double x,
        double yStart,
        double travel,
        double phase,
        double radius,
        double sway,
      })> _sunDustSpecs = [
    (x: 0.11, yStart: 0.82, travel: 0.44, phase: 0.05, radius: 1.5, sway: 6.5),
    (x: 0.19, yStart: 0.68, travel: 0.38, phase: 0.22, radius: 1.3, sway: 5.5),
    (x: 0.28, yStart: 0.76, travel: 0.42, phase: 0.41, radius: 1.7, sway: 7.0),
    (x: 0.35, yStart: 0.60, travel: 0.36, phase: 0.63, radius: 1.4, sway: 6.0),
    (x: 0.43, yStart: 0.86, travel: 0.48, phase: 0.81, radius: 1.8, sway: 7.5),
    (x: 0.49, yStart: 0.70, travel: 0.40, phase: 0.14, radius: 1.3, sway: 5.0),
    (x: 0.55, yStart: 0.56, travel: 0.34, phase: 0.36, radius: 1.6, sway: 6.5),
    (x: 0.61, yStart: 0.80, travel: 0.45, phase: 0.58, radius: 1.5, sway: 7.0),
    (x: 0.68, yStart: 0.64, travel: 0.38, phase: 0.79, radius: 1.4, sway: 5.5),
    (x: 0.74, yStart: 0.88, travel: 0.46, phase: 0.92, radius: 1.7, sway: 8.0),
    (x: 0.81, yStart: 0.72, travel: 0.40, phase: 0.27, radius: 1.3, sway: 6.0),
    (x: 0.89, yStart: 0.62, travel: 0.36, phase: 0.49, radius: 1.6, sway: 6.5),
    (x: 0.24, yStart: 0.44, travel: 0.28, phase: 0.73, radius: 1.4, sway: 5.0),
    (x: 0.46, yStart: 0.40, travel: 0.26, phase: 0.09, radius: 1.5, sway: 5.5),
    (x: 0.64, yStart: 0.46, travel: 0.30, phase: 0.52, radius: 1.3, sway: 5.0),
    (x: 0.77, yStart: 0.42, travel: 0.28, phase: 0.86, radius: 1.5, sway: 6.0),
    (x: 0.38, yStart: 0.90, travel: 0.42, phase: 0.19, radius: 1.6, sway: 7.0),
    (x: 0.53, yStart: 0.84, travel: 0.44, phase: 0.66, radius: 1.4, sway: 6.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final dustBaseAlpha = isDark ? 0.62 : 0.52;
    for (final mote in _sunDustSpecs) {
      final t = (progress + mote.phase) % 1.0;
      final fade = math.sin(t * math.pi).clamp(0.0, 1.0);
      final alpha = (dustBaseAlpha * fade).clamp(0.0, 1.0);
      if (alpha <= 0.02) continue;

      final x = size.width * mote.x +
          math.sin(t * 2.0 * math.pi + mote.phase * 7.0) * mote.sway;
      final y = size.height * (mote.yStart - mote.travel * t);
      final pos = Offset(x, y);

      canvas.drawCircle(
        pos,
        mote.radius * 2.5,
        Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: alpha * 0.42)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawCircle(
        pos,
        mote.radius,
        Paint()..color = const Color(0xFFFFF8E1).withValues(alpha: alpha),
      );
    }

    final petalBaseAlpha = isDark ? 0.78 : 0.84;
    for (final petal in _petalSpecs) {
      final t = (progress + petal.phase) % 1.0;
      final fade = math.sin(t * math.pi).clamp(0.0, 1.0);
      final alpha = (petalBaseAlpha * fade).clamp(0.0, 1.0);
      if (alpha <= 0.02) continue;

      final sway = math.sin(t * 4.0 * math.pi + petal.phase * 6.0) * 10.0;
      final x = size.width * (petal.xStart + petal.driftX * t) + sway;
      final y = size.height * (petal.yStart + petal.driftY * t);
      final angle = t * 2.0 * math.pi * petal.spin + petal.phase * 4.0;
      final flutter = 0.55 + 0.45 * math.cos(t * 6.0 * math.pi + petal.phase);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.scale(1.0, flutter);

      final petalPath = Path()
        ..moveTo(-petal.size, 0)
        ..quadraticBezierTo(0, -petal.size * 0.85, petal.size, 0)
        ..quadraticBezierTo(0, petal.size * 0.75, -petal.size, 0)
        ..close();

      final color = petal.isDeepRose
          ? const Color(0xFFE53935)
          : const Color(0xFFF48FB1);
      canvas.drawPath(
        petalPath,
        Paint()..color = color.withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant RoyalGardenAtmospherePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
