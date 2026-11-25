import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A horizontal crystal-vial RPG Mana Bar (`RpgManaBar`) displaying the Cleric's
/// remaining turns (`$remainingMana / $maxMana`) directly beneath the Player HP bar.
///
/// Features:
/// - Metallic golden-cyan beveled frame over a dark translucent obsidian track
///   matching `RpgHpBar`'s craftsmanship.
/// - Smoothly draining (~300ms ease-out) horizontal liquid fill painted via
///   [RpgManaLiquidPainter] with a rich sapphire-to-cyan gradient
///   (`#01579B` -> `#00B0FF` -> `#00E5FF`), a continuously animated vertical
///   sine-wave liquid tip with a glowing white-cyan meniscus crest, and subtle
///   rising micro-bubbles inside the filled region.
/// - 3D glass specular sheen overlay, miniature glowing mana crystal accent, and
///   crisp centered `$remainingMana / $maxMana` numeric readout.
/// - Urgent arcane amber/violet (`#FFB300` / `#D500F9`) glow & accent pulse when
///   remaining mana reaches critical levels (`<= 20%` of `maxMana` or `<= 20` turns).
class RpgManaBar extends StatefulWidget {
  final int remainingMana;
  final int maxMana;
  final double width;
  final double height;
  final bool animationsEnabled;

  const RpgManaBar({
    super.key,
    required this.remainingMana,
    this.maxMana = 100,
    this.width = 104.0,
    this.height = 17.0,
    this.animationsEnabled = true,
  });

  @override
  State<RpgManaBar> createState() => _RpgManaBarState();
}

class _RpgManaBarState extends State<RpgManaBar>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final AnimationController _waveController;

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
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    if (_shouldPulse(widget.remainingMana, widget.maxMana) &&
        widget.animationsEnabled) {
      _pulseController.repeat(reverse: true);
    }
    if (_shouldWave(widget.remainingMana) && widget.animationsEnabled) {
      _waveController.repeat();
    }
  }

  bool _isLowMana(int mana, int maxMana) {
    if (maxMana <= 0) return true;
    final clamped = mana.clamp(0, maxMana);
    return clamped <= 20 || (clamped * 100 <= maxMana * 20);
  }

  bool _shouldPulse(int mana, int maxMana) =>
      mana > 0 && _isLowMana(mana, maxMana);

  bool _shouldWave(int mana) => mana > 0;

  @override
  void didUpdateWidget(covariant RpgManaBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSafeMax = oldWidget.maxMana <= 0 ? 0 : oldWidget.maxMana;
    final newSafeMax = widget.maxMana <= 0 ? 0 : widget.maxMana;
    final oldClamped = oldWidget.remainingMana.clamp(0, oldSafeMax);
    final newClamped = widget.remainingMana.clamp(0, newSafeMax);
    final wasPulsing = _shouldPulse(oldClamped, oldWidget.maxMana);
    final shouldPulseNow = _shouldPulse(newClamped, widget.maxMana);
    final shouldWaveNow = _shouldWave(newClamped);

    if (!widget.animationsEnabled) {
      if (_pulseController.isAnimating || _pulseController.value != 0.0) {
        _pulseController.stop();
        _pulseController.reset();
      }
      if (_waveController.isAnimating || _waveController.value != 0.0) {
        _waveController.stop();
        _waveController.reset();
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

      if (shouldWaveNow) {
        if (!_waveController.isAnimating) {
          _waveController.repeat();
        }
      } else {
        if (_waveController.isAnimating || _waveController.value != 0.0) {
          _waveController.stop();
          _waveController.reset();
        }
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeMaxMana = widget.maxMana <= 0 ? 1 : widget.maxMana;
    final clampedMana = widget.remainingMana.clamp(0, safeMaxMana);
    final manaRatio =
        widget.maxMana <= 0 ? 0.0 : (clampedMana / widget.maxMana.toDouble());
    final isLowMana = _isLowMana(clampedMana, widget.maxMana);
    final isPulsing =
        _shouldPulse(clampedMana, widget.maxMana) && widget.animationsEnabled;
    final radius = widget.height / 2.0;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) {
        final pulse = isLowMana
            ? (isPulsing ? _pulseAnim.value : 0.5)
            : 0.0;

        final Color borderColor = isLowMana
            ? Color.lerp(
                const Color(0xFFFFB300),
                const Color(0xFFD500F9),
                pulse,
              )!
            : Color.lerp(
                const Color(0xFF8A6D3B),
                const Color(0xFF00E5FF),
                0.42,
              )!;

        final List<BoxShadow> outerGlow = isLowMana
            ? [
                BoxShadow(
                  color: Color.lerp(
                    const Color(0xFFFFB300),
                    const Color(0xFFD500F9),
                    pulse,
                  )!
                      .withValues(alpha: 0.44 + 0.36 * pulse),
                  blurRadius: 6.0 + 4.5 * pulse,
                  spreadRadius: 0.6 + 1.0 * pulse,
                ),
                BoxShadow(
                  color: const Color(0xFFAB47BC)
                      .withValues(alpha: 0.24 + 0.22 * pulse),
                  blurRadius: 9.0,
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.26),
                  blurRadius: 5.5,
                  spreadRadius: 0.3,
                ),
                const BoxShadow(
                  color: Colors.black54,
                  blurRadius: 3.5,
                  offset: Offset(0, 1.5),
                ),
              ];

        return Container(
          key: const ValueKey('rpg_mana_bar_frame'),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0D1524),
                Color(0xFF080D17),
                Color(0xFF0D1726),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor,
              width: isLowMana ? 1.35 : 1.15,
            ),
            boxShadow: outerGlow,
          ),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular((radius - 1.0).clamp(2.0, 20.0)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Smoothly draining animated horizontal liquid fill with vertical sine-wave tip & micro-bubbles
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: manaRatio, end: manaRatio),
                  duration: widget.animationsEnabled
                      ? const Duration(milliseconds: 300)
                      : Duration.zero,
                  curve: Curves.easeOut,
                  builder: (context, animatedRatio, _) {
                    final clampedRatio = animatedRatio.clamp(0.0, 1.0);
                    return AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, _) {
                        return CustomPaint(
                          key: const ValueKey('rpg_mana_liquid_paint'),
                          painter: RpgManaLiquidPainter(
                            fillRatio: clampedRatio,
                            wavePhase: widget.animationsEnabled
                                ? _waveController.value
                                : 0.18,
                            isLowMana: isLowMana,
                            lowManaPulse: pulse,
                          ),
                        );
                      },
                    );
                  },
                ),

                // 2. 3D glass vial specular sheen & recessed metallic inner bevel
                IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey('rpg_mana_glass_paint'),
                    painter: _RpgManaGlassBevelPainter(
                      isLowMana: isLowMana,
                      lowManaPulse: pulse,
                    ),
                  ),
                ),

                // 3. Crisp centered mana crystal accent + bold numeric readout "$clampedMana / $safeMaxMana"
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            key: const ValueKey('rpg_mana_crystal_icon'),
                            width: 8.5,
                            height: 10.5,
                            child: CustomPaint(
                              painter: _ManaCrystalAccentPainter(
                                isLowMana: isLowMana,
                                lowManaPulse: pulse,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3.5),
                          Text(
                            '$clampedMana / $safeMaxMana',
                            key: const ValueKey('rpg_mana_value_text'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withValues(alpha: 0.98),
                              letterSpacing: 0.3,
                              height: 1.0,
                              shadows: const [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 3.0,
                                  offset: Offset(0, 0.8),
                                ),
                                Shadow(
                                  color: Color(0xFF001A2C),
                                  blurRadius: 5.0,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ManaVialBubbleSpec {
  final double yFraction;
  final double startPhase;
  final double xSpread;
  final int speedMultiplier;
  final double radius;

  const _ManaVialBubbleSpec({
    required this.yFraction,
    required this.startPhase,
    required this.xSpread,
    required this.speedMultiplier,
    required this.radius,
  });
}

/// Paints the horizontal glowing mana liquid inside [RpgManaBar]:
/// - Deep sapphire-to-cyan gradient (`#01579B` -> `#00B0FF` -> `#00E5FF`),
///   shifting accent toward arcane amber/violet during low-mana pulse.
/// - Animated vertical sine-wave liquid tip on the right boundary with a
///   secondary back-wave and crisp glowing white-cyan meniscus highlight line.
/// - Subtle glowing cyan/white micro-bubbles drifting inside the filled region.
class RpgManaLiquidPainter extends CustomPainter {
  static const List<_ManaVialBubbleSpec> _bubbleSpecs = [
    _ManaVialBubbleSpec(
      yFraction: 0.30,
      startPhase: 0.10,
      xSpread: 0.24,
      speedMultiplier: 1,
      radius: 1.05,
    ),
    _ManaVialBubbleSpec(
      yFraction: 0.64,
      startPhase: 0.42,
      xSpread: 0.52,
      speedMultiplier: 1,
      radius: 1.25,
    ),
    _ManaVialBubbleSpec(
      yFraction: 0.45,
      startPhase: 0.71,
      xSpread: 0.74,
      speedMultiplier: 2,
      radius: 0.90,
    ),
    _ManaVialBubbleSpec(
      yFraction: 0.72,
      startPhase: 0.86,
      xSpread: 0.38,
      speedMultiplier: 1,
      radius: 0.85,
    ),
  ];

  final double fillRatio;
  final double wavePhase;
  final bool isLowMana;
  final double lowManaPulse;

  const RpgManaLiquidPainter({
    required this.fillRatio,
    required this.wavePhase,
    this.isLowMana = false,
    this.lowManaPulse = 0.0,
  });

  bool get hasLiquid => fillRatio > 0.001;

  bool get hasMeniscus => fillRatio > 0.02;

  double _waveAmplitude(Size size) {
    final clamped = fillRatio.clamp(0.0, 1.0);
    final edgeScale = 0.38 + 0.62 * math.sin(clamped * math.pi);
    return (size.height * 0.16).clamp(1.6, 3.2) * edgeScale;
  }

  double _baseRightX(Size size) {
    final clamped = fillRatio.clamp(0.0, 1.0);
    // Keep 100% fill slightly inset by 1.1px so the glistening meniscus rim remains visible
    return (size.width - 1.1) * clamped;
  }

  /// Evaluates the rippling vertical liquid edge X coordinate at vertical offset [y].
  double waveEdgeXAt(double y, Size size, {double phaseOffsetRad = 0.0}) {
    final ny = size.height <= 0 ? 0.0 : (y / size.height).clamp(0.0, 1.0);
    final phaseRad = wavePhase * 2.0 * math.pi + phaseOffsetRad;
    final amp = _waveAmplitude(size);
    final primary = math.sin(ny * math.pi * 2.0 + phaseRad);
    final secondary = math.sin(ny * math.pi * 3.4 - phaseRad * 2.0);
    final rawX = _baseRightX(size) + amp * (0.72 * primary + 0.28 * secondary);
    return rawX.clamp(0.0, size.width);
  }

  /// Computes visible glowing micro-bubbles drifting gently inside the filled mana region.
  List<({Offset center, double radius, double alpha})> computeVisibleBubbles(
    Size size,
  ) {
    if (!hasLiquid || size.isEmpty) return const [];
    final results = <({Offset center, double radius, double alpha})>[];
    final scale = (size.height / 15.0).clamp(0.75, 1.6);

    for (final spec in _bubbleSpecs) {
      final progress =
          (wavePhase * spec.speedMultiplier + spec.startPhase) % 1.0;
      final r = spec.radius * scale;
      // Gentle horizontal drift toward the right tip + subtle vertical buoyancy bob
      final baseX = (spec.xSpread * size.width +
              math.sin(progress * 2.0 * math.pi + spec.startPhase * 5.0) * 3.2)
          .clamp(r + 1.5, size.width - r - 1.5);
      final y = (size.height * spec.yFraction +
              math.cos(progress * 2.0 * math.pi + spec.startPhase * 6.0) *
                  (size.height * 0.14))
          .clamp(r + 1.2, size.height - r - 1.2);
      final edgeX = waveEdgeXAt(y, size);
      if (baseX < edgeX - r - 1.2) {
        final distFromEdge = ((edgeX - baseX) / 6.0).clamp(0.0, 1.0);
        final shimmer = 0.45 + 0.55 * math.sin(progress * math.pi);
        final alpha = (distFromEdge * shimmer).clamp(0.0, 1.0);
        results.add((center: Offset(baseX, y), radius: r, alpha: alpha));
      }
    }
    return results;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!hasLiquid || size.isEmpty) return;

    final w = size.width;
    final h = size.height;
    final step = math.max(1.0, h / 14.0);

    // 1. Subtle phase-shifted back-wave layer for 3D meniscus tube depth
    final backPath = Path()
      ..moveTo(0, 0)
      ..lineTo(waveEdgeXAt(0, size, phaseOffsetRad: math.pi * 0.85), 0);
    for (double y = step; y <= h; y += step) {
      backPath.lineTo(
        waveEdgeXAt(y, size, phaseOffsetRad: math.pi * 0.85),
        y,
      );
    }
    backPath
      ..lineTo(waveEdgeXAt(h, size, phaseOffsetRad: math.pi * 0.85), h)
      ..lineTo(0, h)
      ..close();

    final backWaveColor = isLowMana
        ? Color.lerp(
            const Color(0xFF7B1FA2),
            const Color(0xFFFF8F00),
            lowManaPulse,
          )!
            .withValues(alpha: 0.42)
        : const Color(0xFF00698F).withValues(alpha: 0.48);
    canvas.drawPath(backPath, Paint()..color = backWaveColor);

    // 2. Foreground wavy liquid body
    final waveEdge = Path()..moveTo(waveEdgeXAt(0, size), 0);
    for (double y = step; y <= h; y += step) {
      waveEdge.lineTo(waveEdgeXAt(y, size), y);
    }
    waveEdge.lineTo(waveEdgeXAt(h, size), h);

    final liquidBody = Path()
      ..moveTo(0, 0)
      ..lineTo(waveEdgeXAt(0, size), 0);
    for (double y = step; y <= h; y += step) {
      liquidBody.lineTo(waveEdgeXAt(y, size), y);
    }
    liquidBody
      ..lineTo(waveEdgeXAt(h, size), h)
      ..lineTo(0, h)
      ..close();

    final rect = Offset.zero & size;
    final List<Color> gradientColors = isLowMana
        ? [
            Color.lerp(
              const Color(0xFF01579B),
              const Color(0xFF6A1B9A),
              0.42 + 0.25 * lowManaPulse,
            )!,
            Color.lerp(
              const Color(0xFF00B0FF),
              const Color(0xFFD500F9),
              0.38 + 0.30 * lowManaPulse,
            )!,
            Color.lerp(
              const Color(0xFF00E5FF),
              const Color(0xFFFFB300),
              0.50 + 0.35 * lowManaPulse,
            )!,
          ]
        : const [
            Color(0xFF01579B),
            Color(0xFF00B0FF),
            Color(0xFF00E5FF),
          ];

    canvas.drawPath(
      liquidBody,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: gradientColors,
          stops: const [0.0, 0.56, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, math.max(8.0, w * fillRatio), h)),
    );

    // Cylindrical core glow + subtle micro-bubbles clipped inside liquid body
    canvas.save();
    canvas.clipPath(liquidBody);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            const Color(0xFF64F7FF).withValues(alpha: 0.18),
            const Color(0xFF001F3F).withValues(alpha: 0.28),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );

    for (final bubble in computeVisibleBubbles(size)) {
      final bubbleHaloColor = isLowMana
          ? Color.lerp(
              const Color(0xFFFFD54F),
              const Color(0xFFE040FB),
              lowManaPulse,
            )!
          : const Color(0xFF00E5FF);
      canvas.drawCircle(
        bubble.center,
        bubble.radius * 1.85,
        Paint()
          ..color = bubbleHaloColor.withValues(alpha: 0.42 * bubble.alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
      canvas.drawCircle(
        bubble.center,
        bubble.radius,
        Paint()
          ..color =
              const Color(0xFFE0FFFF).withValues(alpha: 0.82 * bubble.alpha),
      );
      canvas.drawCircle(
        bubble.center + Offset(-bubble.radius * 0.28, -bubble.radius * 0.28),
        bubble.radius * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.95 * bubble.alpha),
      );
    }
    canvas.restore();

    // 3. Glowing white-cyan meniscus highlight tracing the rippling right edge
    if (hasMeniscus) {
      final glowColor = isLowMana
          ? Color.lerp(
              const Color(0xFFFFB300),
              const Color(0xFFD500F9),
              lowManaPulse,
            )!
          : const Color(0xFF00E5FF);
      final crestColor = isLowMana
          ? const Color(0xFFFFF5CC)
          : const Color(0xFFE6FFFF);

      canvas.drawPath(
        waveEdge,
        Paint()
          ..color = glowColor.withValues(alpha: 0.80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
      );

      canvas.drawPath(
        waveEdge,
        Paint()
          ..color = crestColor.withValues(alpha: 0.96)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.25
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RpgManaLiquidPainter oldDelegate) {
    return oldDelegate.fillRatio != fillRatio ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.isLowMana != isLowMana ||
        oldDelegate.lowManaPulse != lowManaPulse;
  }
}

/// Paints the glossy upper crystal vial specular sheen and subtle inner rim depth.
class _RpgManaGlassBevelPainter extends CustomPainter {
  final bool isLowMana;
  final double lowManaPulse;

  const _RpgManaGlassBevelPainter({
    required this.isLowMana,
    required this.lowManaPulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // 1. Upper glossy glass reflection band
    final topGlossRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.42);
    canvas.drawRect(
      topGlossRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.24),
            const Color(0xFFB2F8FF).withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.65, 1.0],
        ).createShader(topGlossRect),
    );

    // 2. Subtle dark bottom cylinder shadow
    final bottomShadowRect =
        Rect.fromLTWH(0, size.height * 0.68, size.width, size.height * 0.32);
    canvas.drawRect(
      bottomShadowRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF020710).withValues(alpha: 0.34),
          ],
        ).createShader(bottomShadowRect),
    );

    // 3. Crisp inner golden-cyan rim glint along the top edge
    final rimColor = isLowMana
        ? Color.lerp(
            const Color(0xFFFFD54F),
            const Color(0xFFE040FB),
            lowManaPulse,
          )!
        : const Color(0xFFFFD54F);
    canvas.drawLine(
      Offset(size.height * 0.45, 0.7),
      Offset(size.width - size.height * 0.45, 0.7),
      Paint()
        ..color = rimColor.withValues(alpha: 0.32)
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RpgManaGlassBevelPainter oldDelegate) {
    return oldDelegate.isLowMana != isLowMana ||
        oldDelegate.lowManaPulse != lowManaPulse;
  }
}

/// Miniature faceted glowing mana crystal/droplet accent placed left of the value text.
class _ManaCrystalAccentPainter extends CustomPainter {
  final bool isLowMana;
  final double lowManaPulse;

  const _ManaCrystalAccentPainter({
    required this.isLowMana,
    required this.lowManaPulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;

    final path = Path()
      ..moveTo(cx, 0.5)
      ..lineTo(w - 0.8, h * 0.48)
      ..lineTo(cx, h - 0.5)
      ..lineTo(0.8, h * 0.48)
      ..close();

    final glowColor = isLowMana
        ? Color.lerp(
            const Color(0xFFFFB300),
            const Color(0xFFD500F9),
            lowManaPulse,
          )!
        : const Color(0xFF00E5FF);

    canvas.drawPath(
      path,
      Paint()
        ..color = glowColor.withValues(alpha: 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isLowMana
              ? [
                  const Color(0xFFFFF8E1),
                  Color.lerp(
                    const Color(0xFFFFB300),
                    const Color(0xFFE040FB),
                    lowManaPulse,
                  )!,
                  const Color(0xFF7B1FA2),
                ]
              : const [
                  Color(0xFFE0FFFF),
                  Color(0xFF00E5FF),
                  Color(0xFF01579B),
                ],
        ).createShader(Offset.zero & size),
    );

    // Specular facet highlight
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.65,
    );
  }

  @override
  bool shouldRepaint(covariant _ManaCrystalAccentPainter oldDelegate) {
    return oldDelegate.isLowMana != isLowMana ||
        oldDelegate.lowManaPulse != lowManaPulse;
  }
}
