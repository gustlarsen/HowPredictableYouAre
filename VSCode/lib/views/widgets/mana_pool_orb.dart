import 'package:flutter/material.dart';
import '../../services/localization_service.dart';

/// Compact circular Mana Pool Orb (`Option A` liquid-fill style) displaying the
/// remaining turns in the 100-round match (`100` down to `0`).
///
/// Features:
/// - Smoothly draining cyan-blue liquid fill (`#00E5FF` / `#0288D1`) with a
///   brighter surface meniscus line proportional to `remainingMana / maxMana`.
/// - Thin glowing golden-cyan frame & subtle outer radial glow, shifting to an
///   urgent arcane amber/violet pulse when `remainingMana <= 20`.
/// - Subtle cyan `-1` floating indicator drifting upward and fading out on drain.
class ManaPoolOrb extends StatefulWidget {
  final int remainingMana;
  final int maxMana;
  final double size;
  final LocalizationService? localization;
  final bool animationsEnabled;

  const ManaPoolOrb({
    super.key,
    required this.remainingMana,
    this.maxMana = 100,
    this.size = 46.0,
    this.localization,
    this.animationsEnabled = true,
  });

  @override
  State<ManaPoolOrb> createState() => _ManaPoolOrbState();
}

class _ManaPoolOrbState extends State<ManaPoolOrb>
    with TickerProviderStateMixin {
  static const int lowManaThreshold = 20;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final AnimationController _drainIndicatorController;
  int _lastDrainAmount = 1;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _drainIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    if (_shouldPulse(widget.remainingMana) && widget.animationsEnabled) {
      _pulseController.repeat(reverse: true);
    }
  }

  bool _isLowMana(int mana) => mana <= lowManaThreshold;

  bool _shouldPulse(int mana) => mana > 0 && mana <= lowManaThreshold;

  @override
  void didUpdateWidget(covariant ManaPoolOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldClamped = oldWidget.remainingMana.clamp(0, widget.maxMana);
    final newClamped = widget.remainingMana.clamp(0, widget.maxMana);
    final wasPulsing = _shouldPulse(oldClamped);
    final shouldPulseNow = _shouldPulse(newClamped);

    if (!widget.animationsEnabled) {
      if (_pulseController.isAnimating || _pulseController.value != 0.0) {
        _pulseController.stop();
        _pulseController.reset();
      }
      if (_drainIndicatorController.isAnimating ||
          _drainIndicatorController.value != 0.0) {
        _drainIndicatorController.stop();
        _drainIndicatorController.reset();
      }
    } else {
      if (shouldPulseNow && (!wasPulsing || !oldWidget.animationsEnabled)) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      } else if (!shouldPulseNow && wasPulsing) {
        if (_pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.reset();
        }
      }

      if (newClamped < oldClamped) {
        _lastDrainAmount = oldClamped - newClamped;
        _drainIndicatorController.forward(from: 0.0);
      } else if (newClamped > oldClamped) {
        if (_drainIndicatorController.isAnimating ||
            _drainIndicatorController.value != 0.0) {
          _drainIndicatorController.stop();
          _drainIndicatorController.reset();
        }
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _drainIndicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clampedMana = widget.remainingMana.clamp(0, widget.maxMana);
    final manaRatio =
        widget.maxMana <= 0 ? 0.0 : (clampedMana / widget.maxMana.toDouble());
    final isLowMana = _isLowMana(clampedMana);
    final isPulsing = _shouldPulse(clampedMana) && widget.animationsEnabled;
    final manaLabel =
        widget.localization?.t('mana_label', fallback: 'MANA') ?? 'MANA';

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, _) {
              final pulse = isLowMana
                  ? (isPulsing ? _pulseAnim.value : 0.5)
                  : 0.0;

              final Color ringColor = isLowMana
                  ? Color.lerp(
                      const Color(0xFFFFB300),
                      const Color(0xFFD500F9),
                      pulse,
                    )!
                  : Color.lerp(
                      const Color(0xFFFFD54F),
                      const Color(0xFF00E5FF),
                      0.52,
                    )!;

              final List<BoxShadow> outerGlow = isLowMana
                  ? [
                      BoxShadow(
                        color: Color.lerp(
                          const Color(0xFFFFB300),
                          const Color(0xFFD500F9),
                          pulse,
                        )!
                            .withValues(alpha: 0.52 + 0.34 * pulse),
                        blurRadius: 10.0 + 6.0 * pulse,
                        spreadRadius: 1.2 + 1.4 * pulse,
                      ),
                      BoxShadow(
                        color: const Color(0xFFAB47BC)
                            .withValues(alpha: 0.30 + 0.25 * pulse),
                        blurRadius: 14.0,
                        spreadRadius: 0.8,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.36),
                        blurRadius: 10.0,
                        spreadRadius: 1.0,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.22),
                        blurRadius: 6.0,
                        spreadRadius: 0.3,
                      ),
                    ];

              return Container(
                key: const ValueKey('mana_pool_orb_frame'),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.25, -0.25),
                    radius: 0.9,
                    colors: [
                      Color(0xFF141D2E),
                      Color(0xFF0A0E17),
                    ],
                  ),
                  border: Border.all(
                    color: ringColor,
                    width: isLowMana ? 2.0 : 1.8,
                  ),
                  boxShadow: outerGlow,
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Smoothly draining cyan-blue liquid mana fill
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: manaRatio, end: manaRatio),
                        duration: widget.animationsEnabled
                            ? const Duration(milliseconds: 300)
                            : Duration.zero,
                        curve: Curves.easeOut,
                        builder: (context, animatedRatio, _) {
                          final clampedRatio = animatedRatio.clamp(0.0, 1.0);
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              key: const ValueKey('mana_liquid_fill'),
                              widthFactor: 1.0,
                              heightFactor: clampedRatio,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF00E5FF),
                                          Color(0xFF0288D1),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (clampedRatio > 0.02)
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      height: 2.0,
                                      child: Container(
                                        key: const ValueKey(
                                          'mana_liquid_meniscus',
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withValues(
                                                alpha: 0.35,
                                              ),
                                              isLowMana
                                                  ? const Color(0xFFFFE082)
                                                  : const Color(0xFFB2F8FF),
                                              Colors.white.withValues(
                                                alpha: 0.35,
                                              ),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (isLowMana
                                                      ? const Color(0xFFFFB300)
                                                      : const Color(0xFF00E5FF))
                                                  .withValues(alpha: 0.75),
                                              blurRadius: 4.0,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Subtle curved top-left glass specular sheen
                      Positioned(
                        top: 3,
                        left: 6,
                        child: IgnorePointer(
                          child: Container(
                            width: widget.size * 0.36,
                            height: widget.size * 0.16,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.22),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Centered remaining turn integer & localized MANA label
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$clampedMana',
                              key: const ValueKey('mana_value_text'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0,
                                letterSpacing: 0.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                  Shadow(
                                    color: Color(0xFF001F33),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 1.5),
                            Text(
                              manaLabel,
                              key: const ValueKey('mana_label_text'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 7.2,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.94),
                                height: 1.0,
                                letterSpacing: 0.7,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 3,
                                    offset: Offset(0, 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Subtle cyan -1 floating indicator drifting upward & fading on drain
          AnimatedBuilder(
            animation: _drainIndicatorController,
            builder: (context, _) {
              if (!_drainIndicatorController.isAnimating ||
                  _drainIndicatorController.value >= 1.0) {
                return const SizedBox.shrink();
              }
              final t = _drainIndicatorController.value;
              final drift = 18.0 * Curves.easeOut.transform(t);
              final opacity = (1.0 - t).clamp(0.0, 1.0);
              return Positioned(
                top: -4.0 - drift,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      key: const ValueKey('mana_drain_indicator'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF061624).withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.75),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF)
                                .withValues(alpha: 0.45),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Text(
                        '-$_lastDrainAmount',
                        style: const TextStyle(
                          color: Color(0xFF64F5FF),
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
