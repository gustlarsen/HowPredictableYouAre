import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/localization_service.dart';

/// Compact circular RPG crystal Mana Pool Orb displaying the remaining turns in
/// the 100-round match (`100` down to `0`).
///
/// Features:
/// - Ornate golden-amber outer metallic rim with cardinal rune accents paired
///   with an inner glowing cyan energy ring and soft outer radial glow, shifting
///   to an urgent arcane amber/violet pulse when `remainingMana <= 20`.
/// - Smoothly draining, continuously animated sine-wave liquid surface
///   (`#01579B` -> `#0288D1` -> `#00E5FF`) with a glowing white-cyan meniscus
///   highlight crest and rising mana bubble particles.
/// - 3D glass sphere specular highlight, inner vignette depth, crisp white
///   remaining-turn counter + localized `MANA` label, and floating `-1` drain
///   indicator.
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
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final AnimationController _drainIndicatorController;
  late final AnimationController _waveController;
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
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
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
    return mana.clamp(0, maxMana) * 100 <= maxMana * 20;
  }

  bool _shouldPulse(int mana, int maxMana) =>
      mana > 0 && _isLowMana(mana, maxMana);

  bool _shouldWave(int mana) => mana > 0;

  @override
  void didUpdateWidget(covariant ManaPoolOrb oldWidget) {
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
      if (_drainIndicatorController.isAnimating ||
          _drainIndicatorController.value != 0.0) {
        _drainIndicatorController.stop();
        _drainIndicatorController.reset();
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

      if (newClamped < oldClamped && newSafeMax == oldSafeMax) {
        _lastDrainAmount = oldClamped - newClamped;
        _drainIndicatorController.forward(from: 0.0);
      } else if (newClamped > oldClamped || newSafeMax != oldSafeMax) {
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
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeMaxMana = widget.maxMana <= 0 ? 0 : widget.maxMana;
    final clampedMana = widget.remainingMana.clamp(0, safeMaxMana);
    final manaRatio =
        widget.maxMana <= 0 ? 0.0 : (clampedMana / widget.maxMana.toDouble());
    final isLowMana = _isLowMana(clampedMana, widget.maxMana);
    final isPulsing =
        _shouldPulse(clampedMana, widget.maxMana) && widget.animationsEnabled;
    final manaLabel =
        widget.localization?.t('mana_label', fallback: 'MANA') ?? 'MANA';
    final innerGlassInset = widget.size * 0.085;

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
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.40),
                        blurRadius: 11.0,
                        spreadRadius: 1.1,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.24),
                        blurRadius: 6.5,
                        spreadRadius: 0.4,
                      ),
                    ];

              return Container(
                key: const ValueKey('mana_pool_orb_frame'),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.22, -0.24),
                    radius: 0.92,
                    colors: [
                      Color(0xFF132238),
                      Color(0xFF0A111D),
                      Color(0xFF05080F),
                    ],
                  ),
                  boxShadow: outerGlow,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Inner crystal sphere: animated wavy liquid, bubbles, and 3D glass depth
                    Padding(
                      padding: EdgeInsets.all(innerGlassInset),
                      child: ClipOval(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: manaRatio,
                                end: manaRatio,
                              ),
                              duration: widget.animationsEnabled
                                  ? const Duration(milliseconds: 300)
                                  : Duration.zero,
                              curve: Curves.easeOut,
                              builder: (context, animatedRatio, _) {
                                final clampedRatio =
                                    animatedRatio.clamp(0.0, 1.0);
                                return AnimatedBuilder(
                                  animation: _waveController,
                                  builder: (context, _) {
                                    return CustomPaint(
                                      key: const ValueKey('mana_liquid_paint'),
                                      painter: ManaPoolLiquidPainter(
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

                            // 3D crystal specular highlight & inner spherical vignette
                            const IgnorePointer(
                              child: CustomPaint(
                                key: ValueKey('mana_glass_highlight_paint'),
                                painter: ManaPoolGlassPainter(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Ornate golden-cyan double ring bezel with cardinal rune accents
                    IgnorePointer(
                      child: CustomPaint(
                        key: const ValueKey('mana_orb_frame_paint'),
                        painter: ManaPoolFramePainter(
                          isLowMana: isLowMana,
                          lowManaPulse: pulse,
                        ),
                      ),
                    ),

                    // Centered bold remaining-turns integer & crisp localized MANA label
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
                                  color: Color(0xFF001A2C),
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
                              color: Colors.white.withValues(alpha: 0.96),
                              height: 1.0,
                              letterSpacing: 0.7,
                              shadows: const [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 3.5,
                                  offset: Offset(0, 0.8),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

class _ManaBubbleSpec {
  final double xFraction;
  final double startPhase;
  final int speedMultiplier;
  final double radius;
  final double swayAmplitude;

  const _ManaBubbleSpec({
    required this.xFraction,
    required this.startPhase,
    required this.speedMultiplier,
    required this.radius,
    required this.swayAmplitude,
  });
}

/// Renders the animated sine-wave cyan mana liquid, glowing meniscus highlight
/// crest, and upward-drifting glowing bubble particles inside the crystal orb.
class ManaPoolLiquidPainter extends CustomPainter {
  static const List<_ManaBubbleSpec> _bubbleSpecs = [
    _ManaBubbleSpec(
      xFraction: 0.28,
      startPhase: 0.12,
      speedMultiplier: 1,
      radius: 1.15,
      swayAmplitude: 1.1,
    ),
    _ManaBubbleSpec(
      xFraction: 0.56,
      startPhase: 0.44,
      speedMultiplier: 1,
      radius: 1.40,
      swayAmplitude: 0.9,
    ),
    _ManaBubbleSpec(
      xFraction: 0.73,
      startPhase: 0.72,
      speedMultiplier: 2,
      radius: 0.95,
      swayAmplitude: 1.2,
    ),
    _ManaBubbleSpec(
      xFraction: 0.41,
      startPhase: 0.88,
      speedMultiplier: 1,
      radius: 0.85,
      swayAmplitude: 0.8,
    ),
  ];

  final double fillRatio;
  final double wavePhase;
  final bool isLowMana;
  final double lowManaPulse;

  const ManaPoolLiquidPainter({
    required this.fillRatio,
    required this.wavePhase,
    this.isLowMana = false,
    this.lowManaPulse = 0.0,
  });

  bool get hasLiquid => fillRatio > 0.001;

  bool get hasMeniscus => fillRatio > 0.02;

  double _waveAmplitude(Size size) {
    final clamped = fillRatio.clamp(0.0, 1.0);
    final edgeScale = 0.40 + 0.60 * math.sin(clamped * math.pi);
    return size.height * 0.056 * edgeScale;
  }

  double _baseSurfaceY(Size size) {
    final clamped = fillRatio.clamp(0.0, 1.0);
    // Keep 100% fill slightly inset at the top so the meniscus wave crest remains crisp
    return size.height - (size.height - 1.4) * clamped;
  }

  /// Evaluates the foreground liquid surface Y coordinate at horizontal offset [x].
  double surfaceYAt(double x, Size size, {double phaseOffsetRad = 0.0}) {
    final nx = size.width <= 0 ? 0.0 : (x / size.width).clamp(0.0, 1.0);
    final phaseRad = wavePhase * 2.0 * math.pi + phaseOffsetRad;
    final amp = _waveAmplitude(size);
    final primary = math.sin(nx * math.pi * 2.0 + phaseRad);
    final secondary = math.sin(nx * math.pi * 3.4 - phaseRad * 2.0);
    return _baseSurfaceY(size) + amp * (0.72 * primary + 0.28 * secondary);
  }

  /// Computes current bubble positions and opacities inside the filled region.
  List<({Offset center, double radius, double alpha})> computeVisibleBubbles(
    Size size,
  ) {
    if (!hasLiquid) return const [];
    final results = <({Offset center, double radius, double alpha})>[];
    final scale = size.width / 38.0;
    for (final spec in _bubbleSpecs) {
      final progress = (wavePhase * spec.speedMultiplier + spec.startPhase) % 1.0;
      final y = (size.height - 1.5) - progress * (size.height - 3.5);
      final sway = math.sin(
            progress * 2.0 * math.pi + spec.startPhase * 6.0,
          ) *
          spec.swayAmplitude *
          scale;
      final x = (size.width * spec.xFraction + sway)
          .clamp(spec.radius + 1.0, size.width - spec.radius - 1.0);
      final r = spec.radius * scale;
      final surfY = surfaceYAt(x, size);
      if (y > surfY + r + 0.8) {
        final distBelowSurface = ((y - surfY) / 5.0).clamp(0.0, 1.0);
        final arcFade = math.sin(progress * math.pi).clamp(0.2, 1.0);
        final alpha = (distBelowSurface * arcFade).clamp(0.0, 1.0);
        results.add((center: Offset(x, y), radius: r, alpha: alpha));
      }
    }
    return results;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!hasLiquid || size.isEmpty) return;

    final w = size.width;
    final h = size.height;
    final step = math.max(1.0, w / 28.0);

    // 1. Subtle back-wave layer for 3D meniscus ellipse depth
    final backPath = Path()..moveTo(0, surfaceYAt(0, size, phaseOffsetRad: math.pi * 0.85));
    for (double x = step; x <= w; x += step) {
      backPath.lineTo(x, surfaceYAt(x, size, phaseOffsetRad: math.pi * 0.85));
    }
    backPath
      ..lineTo(w, surfaceYAt(w, size, phaseOffsetRad: math.pi * 0.85))
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      backPath,
      Paint()
        ..color = const Color(0xFF00698F).withValues(alpha: 0.45)
        ..style = PaintingStyle.fill,
    );

    // 2. Foreground wavy liquid body with deep-to-bright cyan-blue gradient
    final waveCrest = Path()..moveTo(0, surfaceYAt(0, size));
    for (double x = step; x <= w; x += step) {
      waveCrest.lineTo(x, surfaceYAt(x, size));
    }
    waveCrest.lineTo(w, surfaceYAt(w, size));

    final liquidBody = Path.from(waveCrest)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final rect = Offset.zero & size;
    final liquidPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF00E5FF),
          Color(0xFF0288D1),
          Color(0xFF01579B),
        ],
        stops: [0.0, 0.48, 1.0],
      ).createShader(rect);
    canvas.drawPath(liquidBody, liquidPaint);

    // Soft internal bioluminescent mana core glow clipped to liquid body
    canvas.save();
    canvas.clipPath(liquidBody);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, 0.15),
          radius: 0.72,
          colors: [
            const Color(0xFF64F7FF).withValues(alpha: 0.28),
            const Color(0xFF00E5FF).withValues(alpha: 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // 3. Tiny glowing cyan/white mana bubbles drifting upward inside the liquid
    for (final bubble in computeVisibleBubbles(size)) {
      canvas.drawCircle(
        bubble.center,
        bubble.radius * 1.9,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.42 * bubble.alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
      canvas.drawCircle(
        bubble.center,
        bubble.radius,
        Paint()
          ..color = const Color(0xFFE0FFFF).withValues(alpha: 0.85 * bubble.alpha),
      );
      canvas.drawCircle(
        bubble.center + Offset(-bubble.radius * 0.28, -bubble.radius * 0.28),
        bubble.radius * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.95 * bubble.alpha),
      );
    }
    canvas.restore();

    // 4. Crisp glowing white-cyan meniscus highlight along the wave crest
    if (hasMeniscus) {
      final glowColor = isLowMana
          ? Color.lerp(
              const Color(0xFFFFD54F),
              const Color(0xFF00E5FF),
              0.35,
            )!
          : const Color(0xFF00E5FF);
      final crestColor = isLowMana
          ? const Color(0xFFFFF5CC)
          : const Color(0xFFE6FFFF);

      canvas.drawPath(
        waveCrest,
        Paint()
          ..color = glowColor.withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
      );

      canvas.drawPath(
        waveCrest,
        Paint()
          ..color = crestColor.withValues(alpha: 0.96)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ManaPoolLiquidPainter oldDelegate) {
    return oldDelegate.fillRatio != fillRatio ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.isLowMana != isLowMana ||
        oldDelegate.lowManaPulse != lowManaPulse;
  }
}

/// Renders the 3D crystal glass sphere depth: inner edge vignette shadow and a
/// subtle curved glossy specular highlight along the upper inner dome.
class ManaPoolGlassPainter extends CustomPainter {
  const ManaPoolGlassPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2.0;

    // 1. Soft inner spherical vignette shadow for 3D crystal depth
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.1, -0.1),
          radius: 1.0,
          colors: [
            Colors.transparent,
            Colors.transparent,
            const Color(0xFF020812).withValues(alpha: 0.34),
            const Color(0xFF01050C).withValues(alpha: 0.62),
          ],
          stops: const [0.0, 0.56, 0.84, 1.0],
        ).createShader(rect),
    );

    // 2. Curved glossy specular arc near the upper inner glass dome
    final arcRect = Rect.fromCircle(
      center: center,
      radius: radius * 0.76,
    );
    canvas.drawArc(
      arcRect,
      -math.pi * 0.80,
      math.pi * 0.56,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.16
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.34),
            const Color(0xFFB2F8FF).withValues(alpha: 0.06),
          ],
        ).createShader(rect),
    );

    // 3. Sharp upper-left pinpoint specular glint
    canvas.save();
    canvas.translate(center.dx - radius * 0.42, center.dy - radius * 0.46);
    canvas.rotate(-0.62);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 0.28,
        height: radius * 0.11,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ManaPoolGlassPainter oldDelegate) => false;
}

/// Renders the ornate RPG golden-amber metallic outer rim with cardinal rune
/// accents and an inner glowing cyan energy ring.
class ManaPoolFramePainter extends CustomPainter {
  final bool isLowMana;
  final double lowManaPulse;

  const ManaPoolFramePainter({
    this.isLowMana = false,
    this.lowManaPulse = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final center = rect.center;
    final half = size.shortestSide / 2.0;

    final outerRadius = half - 1.05;
    final innerRadius = half - size.shortestSide * 0.082;
    final bezelMidRadius = (outerRadius + innerRadius) / 2.0;
    final bezelWidth = (outerRadius - innerRadius).clamp(1.2, 6.0);

    final Color innerRingColor = isLowMana
        ? Color.lerp(
            const Color(0xFFFFB300),
            const Color(0xFFD500F9),
            lowManaPulse,
          )!
        : const Color(0xFF00E5FF);

    final Color outerRimHighlight = isLowMana
        ? Color.lerp(
            const Color(0xFFFFD54F),
            const Color(0xFFE040FB),
            lowManaPulse * 0.7,
          )!
        : const Color(0xFFFFD54F);

    final Color outerRimBase = isLowMana
        ? Color.lerp(
            const Color(0xFFFFB300),
            const Color(0xFFAA00FF),
            lowManaPulse * 0.75,
          )!
        : const Color(0xFFFFB300);

    // 1. Recessed dark metallic bezel channel between the golden and cyan rings
    canvas.drawCircle(
      center,
      bezelMidRadius,
      Paint()
        ..color = const Color(0xFF091322).withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = bezelWidth,
    );

    // 2. Inner glowing cyan energy ring (bloom + crisp core)
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..color = innerRingColor.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..color = Color.lerp(innerRingColor, Colors.white, 0.42)!
            .withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    // 3. Outer thin golden-amber metallic rim
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.65
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            outerRimHighlight,
            outerRimBase,
            const Color(0xFFD98200),
            outerRimHighlight,
          ],
          stops: const [0.0, 0.35, 0.72, 1.0],
        ).createShader(rect),
    );

    // 4. Subtle diagonal rune ticks engraved around the bezel octants
    final tickPaint = Paint()
      ..color = outerRimHighlight.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 4; i++) {
      final baseAngle = (math.pi / 4.0) + i * (math.pi / 2.0);
      for (final offset in [-0.14, 0.0, 0.14]) {
        final a = baseAngle + offset;
        final r1 = innerRadius + 0.35;
        final r2 = outerRadius - 0.35;
        canvas.drawLine(
          center + Offset(math.cos(a) * r1, math.sin(a) * r1),
          center + Offset(math.cos(a) * r2, math.sin(a) * r2),
          tickPaint,
        );
      }
    }

    // 5. Cardinal rune diamond/chevron accents at Top, Right, Bottom, Left
    final runeFillPaint = Paint()
      ..color = outerRimHighlight
      ..style = PaintingStyle.fill;
    final runeCorePaint = Paint()
      ..color = innerRingColor
      ..style = PaintingStyle.fill;
    final flankTickPaint = Paint()
      ..color = innerRingColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 4; i++) {
      final angle = i * (math.pi / 2.0);
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final perpX = -sinA;
      final perpY = cosA;

      // Flanking tiny cyan energy ticks on either side of each cardinal rune
      for (final side in [-0.16, 0.16]) {
        final a = angle + side;
        final r1 = innerRadius + 0.25;
        final r2 = outerRadius - 0.25;
        canvas.drawLine(
          center + Offset(math.cos(a) * r1, math.sin(a) * r1),
          center + Offset(math.cos(a) * r2, math.sin(a) * r2),
          flankTickPaint,
        );
      }

      // Crisp golden diamond rune setting at cardinal point with tiny cyan core
      final mid = center + Offset(cosA * bezelMidRadius, sinA * bezelMidRadius);
      final radialHalf = bezelWidth * 0.62;
      final tangentHalf = bezelWidth * 0.46;

      final diamond = Path()
        ..moveTo(mid.dx + cosA * radialHalf, mid.dy + sinA * radialHalf)
        ..lineTo(mid.dx + perpX * tangentHalf, mid.dy + perpY * tangentHalf)
        ..lineTo(mid.dx - cosA * radialHalf, mid.dy - sinA * radialHalf)
        ..lineTo(mid.dx - perpX * tangentHalf, mid.dy - perpY * tangentHalf)
        ..close();

      canvas.drawPath(diamond, runeFillPaint);
      canvas.drawCircle(mid, bezelWidth * 0.18, runeCorePaint);
    }
  }

  @override
  bool shouldRepaint(covariant ManaPoolFramePainter oldDelegate) {
    return oldDelegate.isLowMana != isLowMana ||
        oldDelegate.lowManaPulse != lowManaPulse;
  }
}
