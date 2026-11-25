import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Visual progression stage of the captive Princess inside the Watch Tower cell.
enum WatchtowerPrincessStage {
  /// Week 0: Original standing pose with 0% belly growth.
  standing,

  /// Week 1: Base kneeling crying pose (`princess_crying_stage_0.png`) with 0% growth.
  cryingWeek1,

  /// Week 2–40: Progressive 5-keyframe piecewise belly growth (`stage_0`..`stage_4`).
  cryingPregnant,
}

/// Renders the animated Watch Tower Dungeon Cell + captive Princess scene
/// via `shaders/watchtower_prisoner.frag`, with a safe static [Stack] fallback
/// when fragment shaders are unavailable (e.g. headless CI `flutter test`).
class WatchtowerCellShaderView extends StatefulWidget {
  static const int maxProgressionWeek = 40;
  static const int maxBlinkWeek = 10;

  static const String standingAsset = 'assets/images/princess_captive.png';
  static const List<String> cryingStageAssets = <String>[
    'assets/images/princess_crying_stage_0.png',
    'assets/images/princess_crying_stage_1.png',
    'assets/images/princess_crying_stage_2.png',
    'assets/images/princess_crying_stage_3.png',
    'assets/images/princess_crying_stage_4.png',
  ];
  static const String cryingBlinkAsset =
      'assets/images/princess_crying_blink.png';

  /// Legacy aliases kept aligned with the 5-stage progressive keyframes.
  static const String cryingWeek1Asset = 'assets/images/princess_crying_stage_0.png';
  static const String cryingOpenAsset = 'assets/images/princess_crying_stage_0.png';
  static const String cryingPregAsset = 'assets/images/princess_crying_stage_4.png';

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
  double get bellyProgress {
    if (clampedWeek < 2) return 0.0;
    return ((clampedWeek - 1) / 39.0).clamp(0.0, 1.0);
  }

  /// Alias matching the `uAbdomenGrowth` GLSL shader uniform (`0.0`..`1.0`).
  double get abdomenGrowth => bellyProgress;

  /// Lower adjacent keyframe index (`0..3`) for Week 2–40 piecewise blending,
  /// or `0` for Week 1.
  int get stageFromIndex {
    if (princessStage != WatchtowerPrincessStage.cryingPregnant) return 0;
    final maxInterval = cryingStageAssets.length - 2; // 3 (intervals 0..3)
    return (bellyProgress * (cryingStageAssets.length - 1))
        .floor()
        .clamp(0, maxInterval);
  }

  /// Upper adjacent keyframe index (`1..4`) for Week 2–40 piecewise blending,
  /// or `0` for Week 1.
  int get stageToIndex {
    if (princessStage != WatchtowerPrincessStage.cryingPregnant) return 0;
    return (stageFromIndex + 1).clamp(0, cryingStageAssets.length - 1);
  }

  /// Local fractional blend (`uStageBlend` in `0.0..1.0`) between
  /// [primaryPrincessAsset] (`texFrom`) and [secondaryPrincessAsset] (`texTo`).
  double get stageBlend {
    if (princessStage != WatchtowerPrincessStage.cryingPregnant) return 0.0;
    final scaled = bellyProgress * (cryingStageAssets.length - 1);
    return (scaled - stageFromIndex).clamp(0.0, 1.0);
  }

  /// Nearest discrete keyframe index (`0..4`) used by the static CI fallback.
  int get nearestStageIndex {
    if (princessStage != WatchtowerPrincessStage.cryingPregnant) return 0;
    return (bellyProgress * (cryingStageAssets.length - 1))
        .round()
        .clamp(0, cryingStageAssets.length - 1);
  }

  /// Whether periodic ~4.2s eye-blink shader compositing is enabled (early crying weeks).
  bool get blinkEnabled => isCrying && clampedWeek <= maxBlinkWeek;

  /// Lower adjacent keyframe texture (`uTextureA` / `texFrom`) bound to the shader.
  String get primaryPrincessAsset {
    switch (princessStage) {
      case WatchtowerPrincessStage.standing:
        return standingAsset;
      case WatchtowerPrincessStage.cryingWeek1:
        return cryingStageAssets[0];
      case WatchtowerPrincessStage.cryingPregnant:
        return cryingStageAssets[stageFromIndex];
    }
  }

  /// Upper adjacent keyframe texture (`uTextureB` / `texTo`) blended across
  /// Week 2–40, or `null` during Week 0–1.
  String? get secondaryPrincessAsset =>
      princessStage == WatchtowerPrincessStage.cryingPregnant
          ? cryingStageAssets[stageToIndex]
          : null;

  /// Asset path displayed by the headless static fallback for the current week.
  String get fallbackPrincessAsset {
    switch (princessStage) {
      case WatchtowerPrincessStage.standing:
        return standingAsset;
      case WatchtowerPrincessStage.cryingWeek1:
        return cryingStageAssets[0];
      case WatchtowerPrincessStage.cryingPregnant:
        return cryingStageAssets[nearestStageIndex];
    }
  }

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
  ui.Image? _princessImageA;
  ui.Image? _princessImageB;
  ui.Image? _blinkImage;
  String? _loadedPrimaryAsset;
  String? _loadedSecondaryAsset;
  bool _shaderFailed = false;
  bool _disposed = false;
  int _loadGeneration = 0;

  bool get _hasRequiredTextures =>
      _princessImageA != null &&
      (widget.secondaryPrincessAsset == null ||
          (_princessImageB != null &&
              _loadedSecondaryAsset == widget.secondaryPrincessAsset)) &&
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
    final primaryChanged =
        oldWidget.primaryPrincessAsset != widget.primaryPrincessAsset ||
        _loadedPrimaryAsset != widget.primaryPrincessAsset;
    final secondaryChanged =
        widget.secondaryPrincessAsset != null &&
        (_princessImageB == null ||
            _loadedSecondaryAsset != widget.secondaryPrincessAsset);
    final needsBlink = widget.blinkEnabled && _blinkImage == null;
    final assetsChanged = primaryChanged || secondaryChanged || needsBlink;

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
    final primaryAsset = widget.primaryPrincessAsset;
    final secondaryAsset = widget.secondaryPrincessAsset;
    final shouldLoadBlink = widget.blinkEnabled;
    try {
      final results = await Future.wait<Object?>([
        ui.FragmentProgram.fromAsset(_shaderAsset),
        _decodeAssetImage(_bgAsset),
        _decodeAssetImage(primaryAsset),
        secondaryAsset != null
            ? _decodeAssetImage(secondaryAsset)
            : Future<Object?>.value(null),
        shouldLoadBlink
            ? _decodeAssetImage(WatchtowerCellShaderView.cryingBlinkAsset)
            : Future<Object?>.value(null),
      ]);

      final program = results[0] as ui.FragmentProgram;
      final bgImage = results[1] as ui.Image;
      final princessImageA = results[2] as ui.Image;
      final princessImageB = results[3] as ui.Image?;
      final blinkImage = results[4] as ui.Image?;

      if (_disposed || gen != _loadGeneration) {
        bgImage.dispose();
        princessImageA.dispose();
        princessImageB?.dispose();
        blinkImage?.dispose();
        return;
      }

      final shader = program.fragmentShader();
      final oldBg = _bgImage;
      final oldPrincessA = _princessImageA;
      final oldPrincessB = princessImageB != null ? _princessImageB : null;
      final oldBlink = blinkImage != null ? _blinkImage : null;
      final oldShader = _shader;
      setState(() {
        _program = program;
        _shader = shader;
        _bgImage = bgImage;
        _princessImageA = princessImageA;
        _loadedPrimaryAsset = primaryAsset;
        if (princessImageB != null) {
          _princessImageB = princessImageB;
          _loadedSecondaryAsset = secondaryAsset;
        }
        if (blinkImage != null) {
          _blinkImage = blinkImage;
        }
        _shaderFailed = false;
      });
      oldBg?.dispose();
      oldPrincessA?.dispose();
      oldPrincessB?.dispose();
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
    final primaryAsset = widget.primaryPrincessAsset;
    final secondaryAsset = widget.secondaryPrincessAsset;
    final shouldLoadPrimary =
        _princessImageA == null || _loadedPrimaryAsset != primaryAsset;
    final shouldLoadSecondary =
        secondaryAsset != null &&
        (_princessImageB == null || _loadedSecondaryAsset != secondaryAsset);
    final shouldLoadBlink = widget.blinkEnabled && _blinkImage == null;
    if (!shouldLoadPrimary && !shouldLoadSecondary && !shouldLoadBlink) {
      _syncTicker();
      return;
    }

    try {
      final results = await Future.wait<ui.Image?>([
        shouldLoadPrimary
            ? _decodeAssetImage(primaryAsset)
            : Future<ui.Image?>.value(null),
        shouldLoadSecondary
            ? _decodeAssetImage(secondaryAsset)
            : Future<ui.Image?>.value(null),
        shouldLoadBlink
            ? _decodeAssetImage(WatchtowerCellShaderView.cryingBlinkAsset)
            : Future<ui.Image?>.value(null),
      ]);
      final newPrimary = results[0];
      final newSecondary = results[1];
      final newBlink = results[2];

      if (_disposed || gen != _loadGeneration) {
        newPrimary?.dispose();
        newSecondary?.dispose();
        newBlink?.dispose();
        return;
      }

      final oldPrimary = newPrimary != null ? _princessImageA : null;
      final oldSecondary = newSecondary != null ? _princessImageB : null;
      final oldBlink = newBlink != null ? _blinkImage : null;
      setState(() {
        if (newPrimary != null) {
          _princessImageA = newPrimary;
          _loadedPrimaryAsset = primaryAsset;
        }
        if (newSecondary != null) {
          _princessImageB = newSecondary;
          _loadedSecondaryAsset = secondaryAsset;
        }
        if (newBlink != null) {
          _blinkImage = newBlink;
        }
      });
      oldPrimary?.dispose();
      oldSecondary?.dispose();
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
    _princessImageA?.dispose();
    if (_princessImageB != null &&
        !identical(_princessImageB, _princessImageA)) {
      _princessImageB?.dispose();
    }
    if (_blinkImage != null &&
        !identical(_blinkImage, _princessImageA) &&
        !identical(_blinkImage, _princessImageB)) {
      _blinkImage?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    final bgImage = _bgImage;
    final textureA = _princessImageA;
    final textureB = widget.secondaryPrincessAsset != null
        ? (_loadedSecondaryAsset == widget.secondaryPrincessAsset
              ? _princessImageB
              : null)
        : _princessImageA;
    final blinkTexture = widget.blinkEnabled ? _blinkImage : _princessImageA;

    if (!_shaderFailed &&
        shader != null &&
        bgImage != null &&
        textureA != null &&
        textureB != null &&
        blinkTexture != null) {
      return RepaintBoundary(
        child: CustomPaint(
          key: const ValueKey('watchtower_spyglass_shader_paint'),
          painter: _WatchtowerCellShaderPainter(
            shader: shader,
            bgImage: bgImage,
            textureA: textureA,
            textureB: textureB,
            blinkTexture: blinkTexture,
            timeSeconds: _timeSeconds,
            isFullScreen: widget.isFullScreen,
            isCrying: widget.isCrying,
            abdomenGrowth: widget.abdomenGrowth,
            stageBlend: widget.stageBlend,
            blinkEnabled: widget.blinkEnabled,
          ),
          child: const SizedBox.expand(),
        ),
      );
    }

    return _StaticDungeonFallback(
      isFullScreen: widget.isFullScreen,
      stage: widget.princessStage,
      nearestStageIndex: widget.nearestStageIndex,
      princessAsset: widget.fallbackPrincessAsset,
    );
  }
}

class _WatchtowerCellShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image bgImage;
  final ui.Image textureA;
  final ui.Image textureB;
  final ui.Image blinkTexture;
  final ValueNotifier<double> timeSeconds;
  final bool isFullScreen;
  final bool isCrying;
  final double abdomenGrowth;
  final double stageBlend;
  final bool blinkEnabled;

  _WatchtowerCellShaderPainter({
    required this.shader,
    required this.bgImage,
    required this.textureA,
    required this.textureB,
    required this.blinkTexture,
    required this.timeSeconds,
    required this.isFullScreen,
    required this.isCrying,
    required this.abdomenGrowth,
    required this.stageBlend,
    required this.blinkEnabled,
  }) : super(repaint: timeSeconds);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, timeSeconds.value);
    shader.setFloat(3, isFullScreen ? 1.0 : 0.0);
    shader.setFloat(4, isCrying ? 1.0 : 0.0);
    shader.setFloat(5, abdomenGrowth);
    shader.setFloat(6, stageBlend);
    shader.setFloat(7, blinkEnabled ? 1.0 : 0.0);
    shader.setImageSampler(0, bgImage);
    shader.setImageSampler(1, textureA);
    shader.setImageSampler(2, textureB);
    shader.setImageSampler(3, blinkTexture);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _WatchtowerCellShaderPainter oldDelegate) {
    return oldDelegate.shader != shader ||
        oldDelegate.bgImage != bgImage ||
        oldDelegate.textureA != textureA ||
        oldDelegate.textureB != textureB ||
        oldDelegate.blinkTexture != blinkTexture ||
        oldDelegate.isFullScreen != isFullScreen ||
        oldDelegate.isCrying != isCrying ||
        oldDelegate.abdomenGrowth != abdomenGrowth ||
        oldDelegate.stageBlend != stageBlend ||
        oldDelegate.blinkEnabled != blinkEnabled;
  }
}

/// Clean static fallback rendered while the shader is loading or when running
/// in headless CI test environments without GPU shader support.
class _StaticDungeonFallback extends StatelessWidget {
  final bool isFullScreen;
  final WatchtowerPrincessStage stage;
  final int nearestStageIndex;
  final String princessAsset;

  const _StaticDungeonFallback({
    required this.isFullScreen,
    required this.stage,
    required this.nearestStageIndex,
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
            'watchtower_spyglass_princess_crying_stage_$nearestStageIndex';
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
