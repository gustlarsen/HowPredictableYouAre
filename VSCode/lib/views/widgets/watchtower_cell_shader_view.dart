import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Visual progression stage of the captive Princess inside the Watch Tower cell.
enum WatchtowerPrincessStage {
  /// Week 0: Original standing pose with 0% belly growth.
  standing,

  /// Week 1: Kneeling crying pose (right hand resting on lap) with 0% belly growth.
  cryingWeek1,

  /// Week 2–40: Dedicated crisp weekly sprite (`princess_week_02.png`..`princess_week_40.png`).
  cryingPregnant,
}

/// Renders the animated Watch Tower Dungeon Cell + captive Princess scene
/// via `shaders/watchtower_prisoner.frag`, with a safe static [Stack] fallback
/// when fragment shaders are unavailable (e.g. headless CI `flutter test`).
class WatchtowerCellShaderView extends StatefulWidget {
  static const int maxProgressionWeek = 40;
  static const double blinkCycleDurationSeconds = 16.8;

  static const String standingAsset = 'assets/images/princess_captive.png';
  static const String cryingWeek1Asset =
      'assets/images/princess_captive_crying.png';
  static const String cryingBlinkAsset =
      'assets/images/princess_crying_blink.png';

  /// Returns the dedicated crisp weekly sprite asset path for Weeks 2 through 40.
  static String weeklyAssetForWeek(int week) {
    final w = week.clamp(2, maxProgressionWeek);
    return 'assets/images/princess_weeks/princess_week_${w.toString().padLeft(2, '0')}.png';
  }

  /// Computes a smooth, natural eyelid blink curve (`0.0` = eyes open, `1.0` = eyes closed)
  /// with ~180ms blinks every ~3.8s–4.5s and an occasional double-blink.
  static double computeBlinkValue(double timeSeconds) {
    if (timeSeconds < 0.0) return 0.0;
    final t = timeSeconds % blinkCycleDurationSeconds;
    // Schedule across 16.8s loop:
    //  - 2.60s: single blink (180ms)
    //  - 6.60s: single blink (+4.0s, 180ms)
    //  - 11.10s: double blink (+4.5s, 170ms + 130ms pause + 170ms)
    //  - 14.90s: single blink (+3.8s, 180ms) -> wraps +4.5s back to 2.60s
    final b0 = _evalSingleBlink(t, start: 2.60, duration: 0.18);
    final b1 = _evalSingleBlink(t, start: 6.60, duration: 0.18);
    final b2a = _evalSingleBlink(t, start: 11.10, duration: 0.17);
    final b2b = _evalSingleBlink(t, start: 11.40, duration: 0.17);
    final b3 = _evalSingleBlink(t, start: 14.90, duration: 0.18);
    var m = b0;
    if (b1 > m) m = b1;
    if (b2a > m) m = b2a;
    if (b2b > m) m = b2b;
    if (b3 > m) m = b3;
    return m;
  }

  static double _evalSingleBlink(
    double t, {
    required double start,
    required double duration,
  }) {
    final local = t - start;
    if (local <= 0.0 || local >= duration) return 0.0;
    final closeEnd = duration * 0.38;
    final openStart = duration * 0.56;
    if (local < closeEnd) {
      return _smoothstep(0.0, closeEnd, local);
    }
    if (local <= openStart) {
      return 1.0;
    }
    return 1.0 - _smoothstep(openStart, duration, local);
  }

  static double _smoothstep(double edge0, double edge1, double x) {
    final u = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return u * u * (3.0 - 2.0 * u);
  }

  final bool animationsEnabled;
  final bool forceStaticFallback;
  final bool isFullScreen;
  final int currentWeek;
  final bool _isCryingOverride;

  const WatchtowerCellShaderView({
    super.key,
    this.animationsEnabled = true,
    this.forceStaticFallback = false,
    this.isFullScreen = false,
    this.currentWeek = 0,
    bool isCrying = false,
  }) : _isCryingOverride = isCrying;

  /// Campaign week clamped to the 0..40 spyglass progression range.
  int get clampedWeek => currentWeek.clamp(0, maxProgressionWeek);

  /// Whether the Princess is in a kneeling crying state (Week 1+ or post-scream).
  bool get isCrying => clampedWeek >= 1 || _isCryingOverride;

  /// Active progression stage (`Week 0` -> `Week 1` -> `Week 2..40`).
  WatchtowerPrincessStage get princessStage {
    if (clampedWeek >= 2) {
      return WatchtowerPrincessStage.cryingPregnant;
    }
    if (clampedWeek >= 1 || _isCryingOverride) {
      return WatchtowerPrincessStage.cryingWeek1;
    }
    return WatchtowerPrincessStage.standing;
  }

  /// Normalized overall abdomen/belly growth progress (`uAbdomenGrowth`):
  /// `0.0` for Week 0–1, smoothly ramping from `1/39` at Week 2 to `1.0` at Week 40.
  /// Drives 3D top-window daylight, underside shading, and synchronized belly breathing.
  double get bellyProgress {
    if (clampedWeek < 2) return 0.0;
    return ((clampedWeek - 1) / 39.0).clamp(0.0, 1.0);
  }

  /// Alias matching the `uAbdomenGrowth` GLSL shader uniform (`0.0`..`1.0`).
  double get abdomenGrowth => bellyProgress;

  /// Whether periodic natural eye-blinking (`uBlinkTexture`) is active (`Week 1..40` / crying).
  bool get blinkEnabled => isCrying;

  /// Single dedicated sprite asset loaded for the current week (100% crisp, zero cross-fade).
  String get activePrincessAsset {
    switch (princessStage) {
      case WatchtowerPrincessStage.standing:
        return standingAsset;
      case WatchtowerPrincessStage.cryingWeek1:
        return cryingWeek1Asset;
      case WatchtowerPrincessStage.cryingPregnant:
        return weeklyAssetForWeek(clampedWeek);
    }
  }

  /// Alias for [activePrincessAsset] bound as `uTexture` in the fragment shader.
  String get primaryPrincessAsset => activePrincessAsset;

  @override
  State<WatchtowerCellShaderView> createState() =>
      _WatchtowerCellShaderViewState();
}

class _WatchtowerCellShaderViewState extends State<WatchtowerCellShaderView>
    with SingleTickerProviderStateMixin {
  static const String _shaderAsset = 'shaders/watchtower_prisoner.frag';
  static const String _bgAsset = 'assets/images/watchtower_dungeon_cell.jpeg';

  final ValueNotifier<double> _timeSeconds = ValueNotifier<double>(0.0);
  late final Ticker _ticker;

  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  ui.Image? _bgImage;
  ui.Image? _princessImage;
  ui.Image? _blinkImage;
  String? _loadedPrincessAsset;
  bool _shaderFailed = false;
  bool _disposed = false;
  int _loadGeneration = 0;

  bool get _hasRequiredTextures =>
      _princessImage != null &&
      _loadedPrincessAsset == widget.activePrincessAsset &&
      (!widget.blinkEnabled || _blinkImage != null);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (_disposed) return;
      _timeSeconds.value = elapsed.inMicroseconds / 1000000.0;
    });
    if (widget.forceStaticFallback) {
      _shaderFailed = true;
    } else {
      unawaited(_loadAssets());
    }
  }

  @override
  void didUpdateWidget(covariant WatchtowerCellShaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final princessChanged =
        oldWidget.activePrincessAsset != widget.activePrincessAsset ||
        _loadedPrincessAsset != widget.activePrincessAsset;
    final needsBlink = widget.blinkEnabled && _blinkImage == null;
    final assetsChanged = princessChanged || needsBlink;

    if (oldWidget.animationsEnabled != widget.animationsEnabled) {
      _syncTicker();
    }
    if (oldWidget.forceStaticFallback != widget.forceStaticFallback) {
      if (widget.forceStaticFallback) {
        _loadGeneration++;
        _ticker.stop();
        setState(() {
          _shaderFailed = true;
        });
      } else if (_program == null) {
        _shaderFailed = false;
        unawaited(_loadAssets());
      } else if (assetsChanged) {
        unawaited(_reloadPrincessAssets());
      } else {
        setState(() {
          _shaderFailed = false;
        });
        _syncTicker();
      }
    } else if (assetsChanged && !widget.forceStaticFallback && !_shaderFailed) {
      if (_program == null) {
        unawaited(_loadAssets());
      } else {
        unawaited(_reloadPrincessAssets());
      }
    }
  }

  Future<void> _loadAssets() async {
    final gen = ++_loadGeneration;
    final princessAsset = widget.activePrincessAsset;
    final shouldLoadBlink = widget.blinkEnabled;
    try {
      final results = await Future.wait<Object?>([
        ui.FragmentProgram.fromAsset(_shaderAsset),
        _decodeAssetImage(_bgAsset),
        _decodeAssetImage(princessAsset),
        shouldLoadBlink
            ? _decodeAssetImage(WatchtowerCellShaderView.cryingBlinkAsset)
            : Future<Object?>.value(null),
      ]);

      final program = results[0] as ui.FragmentProgram;
      final bgImage = results[1] as ui.Image;
      final princessImage = results[2] as ui.Image;
      final blinkImage = results[3] as ui.Image?;

      if (_disposed || gen != _loadGeneration) {
        bgImage.dispose();
        princessImage.dispose();
        blinkImage?.dispose();
        return;
      }

      final shader = program.fragmentShader();
      final oldBg = _bgImage;
      final oldPrincess = _princessImage;
      final oldBlink = blinkImage != null ? _blinkImage : null;
      final oldShader = _shader;
      setState(() {
        _program = program;
        _shader = shader;
        _bgImage = bgImage;
        _princessImage = princessImage;
        _loadedPrincessAsset = princessAsset;
        if (blinkImage != null) {
          _blinkImage = blinkImage;
        }
        _shaderFailed = false;
      });
      oldBg?.dispose();
      oldPrincess?.dispose();
      oldBlink?.dispose();
      oldShader?.dispose();
      _syncTicker();
    } catch (_) {
      if (_disposed || gen != _loadGeneration) return;
      setState(() {
        _shaderFailed = true;
      });
    }
  }

  Future<void> _reloadPrincessAssets() async {
    final gen = ++_loadGeneration;
    final princessAsset = widget.activePrincessAsset;
    final shouldLoadPrincess =
        _princessImage == null || _loadedPrincessAsset != princessAsset;
    final shouldLoadBlink = widget.blinkEnabled && _blinkImage == null;
    if (!shouldLoadPrincess && !shouldLoadBlink) {
      _syncTicker();
      return;
    }

    try {
      final results = await Future.wait<ui.Image?>([
        shouldLoadPrincess
            ? _decodeAssetImage(princessAsset)
            : Future<ui.Image?>.value(null),
        shouldLoadBlink
            ? _decodeAssetImage(WatchtowerCellShaderView.cryingBlinkAsset)
            : Future<ui.Image?>.value(null),
      ]);
      final newPrincess = results[0];
      final newBlink = results[1];

      if (_disposed || gen != _loadGeneration) {
        newPrincess?.dispose();
        newBlink?.dispose();
        return;
      }

      final oldPrincess = newPrincess != null ? _princessImage : null;
      final oldBlink = newBlink != null ? _blinkImage : null;
      setState(() {
        if (newPrincess != null) {
          _princessImage = newPrincess;
          _loadedPrincessAsset = princessAsset;
        }
        if (newBlink != null) {
          _blinkImage = newBlink;
        }
      });
      oldPrincess?.dispose();
      oldBlink?.dispose();
      _syncTicker();
    } catch (_) {
      if (_disposed || gen != _loadGeneration) return;
      setState(() {
        _shaderFailed = true;
      });
    }
  }

  Future<ui.Image> _decodeAssetImage(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      Uint8List.sublistView(byteData),
    );
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  void _syncTicker() {
    if (_disposed) return;
    final canAnimate =
        widget.animationsEnabled &&
        !_shaderFailed &&
        _shader != null &&
        _bgImage != null &&
        _hasRequiredTextures;
    if (canAnimate && !_ticker.isActive) {
      _ticker.start();
    } else if (!canAnimate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    _timeSeconds.dispose();
    _shader?.dispose();
    _bgImage?.dispose();
    _princessImage?.dispose();
    if (_blinkImage != null && !identical(_blinkImage, _princessImage)) {
      _blinkImage?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    final bgImage = _bgImage;
    final texture = _loadedPrincessAsset == widget.activePrincessAsset
        ? _princessImage
        : null;
    final blinkTexture = widget.blinkEnabled ? _blinkImage : texture;

    if (!_shaderFailed &&
        shader != null &&
        bgImage != null &&
        texture != null &&
        blinkTexture != null) {
      return RepaintBoundary(
        child: CustomPaint(
          key: const ValueKey('watchtower_spyglass_shader_paint'),
          painter: _WatchtowerCellShaderPainter(
            shader: shader,
            bgImage: bgImage,
            princessTexture: texture,
            blinkTexture: blinkTexture,
            timeSeconds: _timeSeconds,
            isFullScreen: widget.isFullScreen,
            isCrying: widget.isCrying,
            abdomenGrowth: widget.abdomenGrowth,
            blinkEnabled: widget.blinkEnabled,
          ),
          child: const SizedBox.expand(),
        ),
      );
    }

    return _StaticDungeonFallback(
      isFullScreen: widget.isFullScreen,
      stage: widget.princessStage,
      clampedWeek: widget.clampedWeek,
      princessAsset: widget.activePrincessAsset,
    );
  }
}

class _WatchtowerCellShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image bgImage;
  final ui.Image princessTexture;
  final ui.Image blinkTexture;
  final ValueNotifier<double> timeSeconds;
  final bool isFullScreen;
  final bool isCrying;
  final double abdomenGrowth;
  final bool blinkEnabled;

  _WatchtowerCellShaderPainter({
    required this.shader,
    required this.bgImage,
    required this.princessTexture,
    required this.blinkTexture,
    required this.timeSeconds,
    required this.isFullScreen,
    required this.isCrying,
    required this.abdomenGrowth,
    required this.blinkEnabled,
  }) : super(repaint: timeSeconds);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final t = timeSeconds.value;
    final blink = blinkEnabled
        ? WatchtowerCellShaderView.computeBlinkValue(t)
        : 0.0;

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, t);
    shader.setFloat(3, isFullScreen ? 1.0 : 0.0);
    shader.setFloat(4, isCrying ? 1.0 : 0.0);
    shader.setFloat(5, abdomenGrowth);
    shader.setFloat(6, blink);
    shader.setImageSampler(0, bgImage);
    shader.setImageSampler(1, princessTexture);
    shader.setImageSampler(2, blinkTexture);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _WatchtowerCellShaderPainter oldDelegate) {
    return oldDelegate.shader != shader ||
        oldDelegate.bgImage != bgImage ||
        oldDelegate.princessTexture != princessTexture ||
        oldDelegate.blinkTexture != blinkTexture ||
        oldDelegate.isFullScreen != isFullScreen ||
        oldDelegate.isCrying != isCrying ||
        oldDelegate.abdomenGrowth != abdomenGrowth ||
        oldDelegate.blinkEnabled != blinkEnabled;
  }
}

/// Clean static fallback rendered while the shader is loading or when running
/// in headless CI test environments without GPU shader support.
class _StaticDungeonFallback extends StatelessWidget {
  final bool isFullScreen;
  final WatchtowerPrincessStage stage;
  final int clampedWeek;
  final String princessAsset;

  const _StaticDungeonFallback({
    required this.isFullScreen,
    required this.stage,
    required this.clampedWeek,
    required this.princessAsset,
  });

  static const double _texAspect = 576.0 / 1024.0;
  static const double _standingFgScale = 0.425;
  static const double _cryingFgScale = 0.365;

  @override
  Widget build(BuildContext context) {
    final isKneeling = stage != WatchtowerPrincessStage.standing;
    final String imageKey;
    switch (stage) {
      case WatchtowerPrincessStage.standing:
        imageKey = 'watchtower_spyglass_princess_standing_image';
      case WatchtowerPrincessStage.cryingWeek1:
        imageKey = 'watchtower_spyglass_princess_crying_image';
      case WatchtowerPrincessStage.cryingPregnant:
        imageKey =
            'watchtower_spyglass_princess_week_${clampedWeek.toString().padLeft(2, '0')}_image';
    }

    return LayoutBuilder(
      key: const ValueKey('watchtower_spyglass_fallback_stack'),
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final viewAspect = h > 0 ? w / h : 1.0;

        final targetY = isFullScreen ? 0.50 : 0.535;

        // Match the shader's full-body scene coordinate transform
        final double sceneWidth;
        final double sceneHeight;
        final double offsetX;
        final double offsetY;
        if (viewAspect > _texAspect) {
          sceneWidth = w;
          sceneHeight = w / _texAspect;
          offsetX = 0.0;
          offsetY = h * 0.5 - sceneHeight * targetY;
        } else {
          sceneHeight = h;
          sceneWidth = h * _texAspect;
          offsetX = w * 0.5 - sceneWidth * 0.5;
          offsetY = 0.0;
        }

        final fgScale = isKneeling ? _cryingFgScale : _standingFgScale;
        final fgSizeW = sceneWidth * fgScale;
        final fgSizeH = sceneHeight * fgScale;
        final fgLeft = offsetX +
            sceneWidth *
                (isKneeling
                    ? (0.520 - 0.495 * fgScale)
                    : (0.485 - 0.5 * fgScale));
        final fgTop = offsetY +
            sceneHeight *
                (isKneeling
                    ? (0.752 - 0.827 * fgScale)
                    : (0.745 - 0.955 * fgScale));

        final shadowW = sceneWidth * (isKneeling ? 0.24 : 0.11);
        final shadowH = sceneHeight * (isKneeling ? 0.044 : 0.028);
        final shadowLeft =
            offsetX + sceneWidth * (isKneeling ? 0.510 : 0.478) - shadowW * 0.5;
        final shadowTop =
            offsetY + sceneHeight * (isKneeling ? 0.742 : 0.744) - shadowH * 0.5;

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: offsetX,
                top: offsetY,
                width: sceneWidth,
                height: sceneHeight,
                child: Image.asset(
                  _WatchtowerCellShaderViewState._bgAsset,
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                left: shadowLeft,
                top: shadowTop,
                width: shadowW,
                height: shadowH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.62),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: fgLeft,
                top: fgTop,
                width: fgSizeW,
                height: fgSizeH,
                child: Image.asset(
                  princessAsset,
                  key: ValueKey(imageKey),
                  fit: BoxFit.fill,
                ),
              ),
              // Spyglass optical vignette overlay (circular in modal, subtle corner in full screen)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: isFullScreen
                        ? RadialGradient(
                            radius: 1.15,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.36),
                            ],
                            stops: const [0.0, 0.62, 1.0],
                          )
                        : RadialGradient(
                            radius: 0.92,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              const Color(0xFF04141C).withValues(alpha: 0.45),
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            stops: const [0.0, 0.62, 0.86, 1.0],
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
