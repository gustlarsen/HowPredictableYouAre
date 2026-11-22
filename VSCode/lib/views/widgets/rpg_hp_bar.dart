import 'package:flutter/material.dart';

/// A sleek, widened RPG-style HP bar with metallic bronze-stone styling,
/// smooth health fill tween, dynamic color transition (Green -> Amber -> Red),
/// gentle pulsing glow when in critical condition (< 30% HP),
/// "$clampedHp / $maxHp" numeric display, and damage flash/micro-shake effects.
class RpgHpBar extends StatefulWidget {
  final int hp;
  final int maxHp;
  final double width;
  final double height;
  final double flashOpacity;
  final double shakeOffset;
  final bool animationsEnabled;

  const RpgHpBar({
    super.key,
    required this.hp,
    this.maxHp = 100,
    this.width = 104.0,
    this.height = 17.0,
    this.flashOpacity = 0.0,
    this.shakeOffset = 0.0,
    this.animationsEnabled = true,
  });

  @override
  State<RpgHpBar> createState() => _RpgHpBarState();
}

class _RpgHpBarState extends State<RpgHpBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

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

    if (_isCritical(widget.hp, widget.maxHp) && widget.animationsEnabled) {
      _pulseController.repeat(reverse: true);
    }
  }

  bool _isCritical(int hp, int maxHp) {
    if (maxHp <= 0) return true;
    return (hp.clamp(0, maxHp) * 100) < (maxHp * 30);
  }

  @override
  void didUpdateWidget(covariant RpgHpBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasCritical = _isCritical(oldWidget.hp, oldWidget.maxHp);
    final isCrit = _isCritical(widget.hp, widget.maxHp);

    if (!widget.animationsEnabled) {
      if (_pulseController.isAnimating || _pulseController.value != 0.0) {
        _pulseController.stop();
        _pulseController.reset();
      }
    } else if (isCrit && (!wasCritical || !oldWidget.animationsEnabled)) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else if (!isCrit && wasCritical) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _resolveHpColor(double ratio) {
    if (ratio >= 0.60) {
      return const Color(0xFF2ECC71); // Emerald green (>= 60%)
    } else if (ratio >= 0.30) {
      return const Color(0xFFFFB300); // Amber (30%–59%)
    } else {
      return const Color(0xFFE74C3C); // Crimson red (< 30%)
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeMaxHp = widget.maxHp <= 0 ? 1 : widget.maxHp;
    final clampedHp = widget.hp.clamp(0, safeMaxHp);
    final hpRatio =
        widget.maxHp <= 0 ? 0.0 : clampedHp / widget.maxHp.toDouble();
    final isCritical = _isCritical(widget.hp, widget.maxHp);

    final shake = widget.shakeOffset;
    final paddingLeft = shake > 0 ? shake : 0.0;
    final paddingRight = shake < 0 ? -shake : 0.0;
    final radius = widget.height / 2.0;

    return Padding(
      padding: EdgeInsets.only(left: paddingLeft, right: paddingRight),
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, _) {
          final pulse = isCritical
              ? (widget.animationsEnabled ? _pulseAnim.value : 0.5)
              : 0.0;

          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFF14171E).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: isCritical
                    ? Color.lerp(
                        const Color(0xFFD32F2F),
                        const Color(0xFFFF5252),
                        pulse,
                      )!
                    : const Color(0xFF8A6D3B).withValues(alpha: 0.90),
                width: isCritical ? 1.4 : 1.15,
              ),
              boxShadow: [
                if (isCritical)
                  BoxShadow(
                    color: Colors.redAccent.withValues(
                      alpha: 0.35 + 0.45 * pulse,
                    ),
                    blurRadius: 5.0 + 5.0 * pulse,
                    spreadRadius: 0.8 + 1.2 * pulse,
                  )
                else
                  const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 3.5,
                    offset: Offset(0, 1.5),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular((radius - 1.0).clamp(2.0, 20.0)),
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.centerLeft,
                children: [
                  // Animated Health Fill Bar
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: hpRatio, end: hpRatio),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedRatio, _) {
                      final fillColor = _resolveHpColor(animatedRatio);

                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: animatedRatio.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                fillColor.withValues(alpha: 0.96),
                                fillColor.withValues(alpha: 0.72),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Subtle Top Gloss Highlight Line
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: widget.height * 0.38,
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),

                  // Damage Flash Overlay
                  if (widget.flashOpacity > 0.0)
                    Positioned.fill(
                      child: Container(
                        color: Color.lerp(
                          Colors.white,
                          Colors.redAccent,
                          0.65,
                        )!.withValues(
                          alpha: widget.flashOpacity.clamp(0.0, 1.0),
                        ),
                      ),
                    ),

                  // RPG Numeric Label "$clampedHp / $safeMaxHp"
                  Center(
                    child: Text(
                      '$clampedHp / $safeMaxHp',
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
                            color: Colors.black87,
                            blurRadius: 4.5,
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
    );
  }
}
