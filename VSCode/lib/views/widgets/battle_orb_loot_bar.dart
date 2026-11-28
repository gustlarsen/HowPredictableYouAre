import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../theme/app_theme.dart';
import 'elemental_energy_sphere.dart';

/// Compact single-row horizontal pill bar positioned directly between the top
/// battle HUD bar (`AppBar`) and `ScoreHeader`, showing only the elemental orbs
/// collected during the active battle/run (`+N` delta since Turn 0).
class BattleOrbLootBar extends StatefulWidget {
  static const double barHeight = 29.0;
  static const double orbSphereSize = 16.0;
  static const double pulsePeakScale = 1.18;
  static const int localPulseDurationMs = 280;

  final GameController controller;
  final VoidCallback? onTap;
  final Animation<double>? orbFlightAnimation;
  final Set<HandMove> pulsingOrbMoves;
  final int orbTotalSequenceMs;
  final int orbPulseStartMs;
  final int orbPulseDurationMs;

  const BattleOrbLootBar({
    super.key,
    required this.controller,
    this.onTap,
    this.orbFlightAnimation,
    this.pulsingOrbMoves = const <HandMove>{},
    this.orbTotalSequenceMs = 1230,
    this.orbPulseStartMs = 950,
    this.orbPulseDurationMs = 280,
  });

  @override
  State<BattleOrbLootBar> createState() => _BattleOrbLootBarState();
}

class _BattleOrbLootBarState extends State<BattleOrbLootBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _localPulseController;
  final Map<HandMove, int> _lastSeenCounts = <HandMove, int>{};
  int _lastSeenOrbEventId = 0;
  Set<HandMove> _localPulsingMoves = const <HandMove>{};

  @override
  void initState() {
    super.initState();
    _localPulseController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: BattleOrbLootBar.localPulseDurationMs,
      ),
    );
    _snapshotCounts();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant BattleOrbLootBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      _snapshotCounts();
      widget.controller.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _localPulseController.dispose();
    super.dispose();
  }

  void _snapshotCounts() {
    _lastSeenOrbEventId = widget.controller.orbCollectionEventId;
    for (final move in HandMove.values) {
      _lastSeenCounts[move] = widget.controller.battleCollectedOrbsFor(move);
    }
  }

  bool get _isFlightAnimating {
    final anim = widget.orbFlightAnimation;
    if (anim == null) return false;
    return anim.status == AnimationStatus.forward ||
        anim.status == AnimationStatus.reverse;
  }

  void _handleControllerChanged() {
    final increasedMoves = <HandMove>{};
    for (final move in HandMove.values) {
      final prev = _lastSeenCounts[move] ?? 0;
      final next = widget.controller.battleCollectedOrbsFor(move);
      if (next > prev) {
        increasedMoves.add(move);
      }
      _lastSeenCounts[move] = next;
    }

    final currentEventId = widget.controller.orbCollectionEventId;
    final hasNewFlightEvent = currentEventId != _lastSeenOrbEventId;
    _lastSeenOrbEventId = currentEventId;

    if (increasedMoves.isEmpty) return;

    // If animations are disabled, skip local pulse.
    if (!widget.controller.animationsEnabled) {
      _localPulseController.stop();
      _localPulseController.reset();
      _localPulsingMoves = const <HandMove>{};
      return;
    }

    // Round-win flying orbs pulse synchronized at backpack arrival via
    // `orbFlightAnimation`; only trigger an immediate local pulse for passive /
    // non-flying gains (e.g. Spirit Guide passive generation or Gift Box).
    final Set<HandMove> flightHandledMoves;
    if (widget.orbFlightAnimation != null &&
        (hasNewFlightEvent || _isFlightAnimating)) {
      if (widget.controller.lastCollectedOrbMoves.isNotEmpty) {
        flightHandledMoves = widget.controller.lastCollectedOrbMoves.toSet();
      } else if (widget.controller.lastCollectedOrbMove != null) {
        flightHandledMoves = {widget.controller.lastCollectedOrbMove!};
      } else {
        flightHandledMoves = widget.pulsingOrbMoves;
      }
    } else {
      flightHandledMoves = const <HandMove>{};
    }

    final nonFlyingIncreases = increasedMoves.difference(flightHandledMoves);
    if (nonFlyingIncreases.isNotEmpty) {
      _localPulsingMoves = nonFlyingIncreases;
      _localPulseController.forward(from: 0.0);
    }
  }

  double _scaleForMove(HandMove move) {
    if (!widget.controller.animationsEnabled) return 1.0;

    double maxBoost = 0.0;

    // 1. Synchronized pulse when parabolic flying orb lands in the backpack
    final flightAnim = widget.orbFlightAnimation;
    if (flightAnim != null &&
        _isFlightAnimating &&
        widget.pulsingOrbMoves.contains(move)) {
      final elapsedMs = flightAnim.value * widget.orbTotalSequenceMs;
      if (elapsedMs >= widget.orbPulseStartMs &&
          elapsedMs < widget.orbTotalSequenceMs) {
        final pulseT = ((elapsedMs - widget.orbPulseStartMs) /
                widget.orbPulseDurationMs)
            .clamp(0.0, 1.0);
        final boost = math.sin(pulseT * math.pi) *
            (BattleOrbLootBar.pulsePeakScale - 1.0);
        if (boost > maxBoost) maxBoost = boost;
      }
    }

    // 2. Local pulse for passive/instant battle orb increments
    if (_localPulseController.isAnimating &&
        _localPulsingMoves.contains(move)) {
      final boost = math.sin(_localPulseController.value * math.pi) *
          (BattleOrbLootBar.pulsePeakScale - 1.0);
      if (boost > maxBoost) maxBoost = boost;
    }

    return 1.0 + maxBoost;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final loc = widget.controller.localization;
    final activeMoves = widget.controller.battleLootMoves;

    final barBg = palette.isDark
        ? const Color(0xFF151820).withValues(alpha: 0.90)
        : palette.dialogSurface.withValues(alpha: 0.95);
    final borderColor = palette.isDark
        ? const Color(0xFF8A6D3B)
        : palette.sandCardBorder;

    final listenables = <Listenable>[
      widget.controller,
      _localPulseController,
      if (widget.orbFlightAnimation != null) widget.orbFlightAnimation!,
    ];

    return Tooltip(
      message: loc.t('inventory_title', fallback: "Cleric's Backpack"),
      child: SizedBox(
        key: const ValueKey('battle_orb_loot_bar'),
        width: double.infinity,
        height: BattleOrbLootBar.barHeight,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            key: const ValueKey('battle_orb_loot_bar_tap_target'),
            borderRadius: BorderRadius.circular(15),
            onTap: widget.onTap,
            child: Ink(
              decoration: BoxDecoration(
                color: barBg,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: borderColor,
                  width: 1.25,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: palette.isDark ? 0.35 : 0.08,
                    ),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge(listenables),
                    builder: (context, _) {
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            for (int i = 0; i < activeMoves.length; i++) ...[
                              if (i > 0) const SizedBox(width: 12),
                              _BattleLootElementSlot(
                                move: activeMoves[i],
                                count: widget.controller
                                    .battleCollectedOrbsFor(activeMoves[i]),
                                scale: _scaleForMove(activeMoves[i]),
                                palette: palette,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BattleLootElementSlot extends StatelessWidget {
  final HandMove move;
  final int count;
  final double scale;
  final AppPalette palette;

  const _BattleLootElementSlot({
    required this.move,
    required this.count,
    required this.scale,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final hasCollected = count > 0;
    final textColor = palette.isDark
        ? (hasCollected
              ? const Color(0xFFFFE082)
              : Colors.white.withValues(alpha: 0.78))
        : (hasCollected ? palette.amberText : palette.secondaryText);

    return Transform.scale(
      key: ValueKey('battle_loot_slot_${move.orbKey}'),
      scale: scale,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ElementalEnergySphere(
            key: ValueKey('battle_loot_sphere_${move.orbKey}'),
            size: BattleOrbLootBar.orbSphereSize,
            primaryColor: move.elementalPrimaryColor,
            secondaryColor: move.elementalSecondaryColor,
            isDark: palette.isDark,
          ),
          const SizedBox(width: 4),
          Text(
            '+$count',
            key: ValueKey('battle_loot_count_${move.orbKey}'),
            maxLines: 1,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.0,
              fontWeight: FontWeight.w800,
              color: textColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
