import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Renders the animated Watch Tower Dungeon Cell + captive Princess scene
/// via `shaders/watchtower_prisoner.frag`, with a safe static [Stack] fallback
/// when fragment shaders are unavailable (e.g. headless CI `flutter test`).
class WatchtowerCellShaderView extends StatefulWidget {
  final bool animationsEnabled;
  final bool forceStaticFallback;
  final bool isFullScreen;
  final bool isCrying;

  const WatchtowerCellShaderView({
    super.key,
    this.animationsEnabled = true,
    this.forceStaticFallback = false,
    this.isFullScreen = false,
    this.isCrying = false,
  });

  @override
  State<WatchtowerCellShaderView> createState() =>
      _WatchtowerCellShaderViewState();
}

class _WatchtowerCellShaderViewState extends State<WatchtowerCellShaderView>
    with SingleTickerProviderStateMixin {
  static const String _shaderAsset = 'shaders/watchtower_prisoner.frag';
  static const String _bgAsset = 'assets/images/watchtower_dungeon_cell.jpeg';
  static const String _princessAsset = 'assets/images/princess_captive.png';
  static const String _princessCryingAsset =
      'assets/images/princess_captive_crying.png';

  final ValueNotifier<double> _timeSeconds = ValueNotifier<double>(0.0);
  late final Ticker _ticker;

  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  ui.Image? _bgImage;
  ui.Image? _princessImage;
  bool _shaderFailed = false;
  bool _disposed = false;
  int _loadGeneration = 0;

  String get _activePrincessAsset =>
      widget.isCrying ? _princessCryingAsset : _princessAsset;

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
      } else if (oldWidget.isCrying != widget.isCrying) {
        unawaited(_reloadPrincessAsset());
      }
    } else if (oldWidget.isCrying != widget.isCrying &&
        !widget.forceStaticFallback &&
        !_shaderFailed) {
      if (_program == null) {
        unawaited(_loadAssets());
      } else {
        unawaited(_reloadPrincessAsset());
      }
    }
  }

  Future<void> _loadAssets() async {
    final gen = ++_loadGeneration;
    final princessAsset = _activePrincessAsset;
    try {
      final results = await Future.wait<Object>([
        ui.FragmentProgram.fromAsset(_shaderAsset),
        _decodeAssetImage(_bgAsset),
        _decodeAssetImage(princessAsset),
      ]);

      final program = results[0] as ui.FragmentProgram;
      final bgImage = results[1] as ui.Image;
      final princessImage = results[2] as ui.Image;

      if (_disposed || gen != _loadGeneration) {
        bgImage.dispose();
        princessImage.dispose();
        return;
      }

      final shader = program.fragmentShader();
      final oldBg = _bgImage;
      final oldPrincess = _princessImage;
      final oldShader = _shader;
      setState(() {
        _program = program;
        _shader = shader;
        _bgImage = bgImage;
        _princessImage = princessImage;
        _shaderFailed = false;
      });
      oldBg?.dispose();
      oldPrincess?.dispose();
      oldShader?.dispose();
      _syncTicker();
    } catch (_) {
      if (_disposed || gen != _loadGeneration) return;
      setState(() {
        _shaderFailed = true;
      });
    }
  }

  Future<void> _reloadPrincessAsset() async {
    final gen = ++_loadGeneration;
    final princessAsset = _activePrincessAsset;
    try {
      final princessImage = await _decodeAssetImage(princessAsset);
      if (_disposed || gen != _loadGeneration) {
        princessImage.dispose();
        return;
      }
      final oldPrincess = _princessImage;
      setState(() {
        _princessImage = princessImage;
      });
      oldPrincess?.dispose();
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
        _princessImage != null;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    final bgImage = _bgImage;
    final princessImage = _princessImage;

    if (!_shaderFailed &&
        shader != null &&
        bgImage != null &&
        princessImage != null) {
      return RepaintBoundary(
        child: CustomPaint(
          key: const ValueKey('watchtower_spyglass_shader_paint'),
          painter: _WatchtowerCellShaderPainter(
            shader: shader,
            bgImage: bgImage,
            princessImage: princessImage,
            timeSeconds: _timeSeconds,
            isFullScreen: widget.isFullScreen,
            isCrying: widget.isCrying,
          ),
          child: const SizedBox.expand(),
        ),
      );
    }

    return _StaticDungeonFallback(
      isFullScreen: widget.isFullScreen,
      isCrying: widget.isCrying,
    );
  }
}

class _WatchtowerCellShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image bgImage;
  final ui.Image princessImage;
  final ValueNotifier<double> timeSeconds;
  final bool isFullScreen;
  final bool isCrying;

  _WatchtowerCellShaderPainter({
    required this.shader,
    required this.bgImage,
    required this.princessImage,
    required this.timeSeconds,
    required this.isFullScreen,
    required this.isCrying,
  }) : super(repaint: timeSeconds);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, timeSeconds.value);
    shader.setFloat(3, isFullScreen ? 1.0 : 0.0);
    shader.setFloat(4, isCrying ? 1.0 : 0.0);
    shader.setImageSampler(0, bgImage);
    shader.setImageSampler(1, princessImage);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _WatchtowerCellShaderPainter oldDelegate) {
    return oldDelegate.shader != shader ||
        oldDelegate.bgImage != bgImage ||
        oldDelegate.princessImage != princessImage ||
        oldDelegate.isFullScreen != isFullScreen ||
        oldDelegate.isCrying != isCrying;
  }
}

/// Clean static fallback rendered while the shader is loading or when running
/// in headless CI test environments without GPU shader support.
class _StaticDungeonFallback extends StatelessWidget {
  final bool isFullScreen;
  final bool isCrying;

  const _StaticDungeonFallback({
    required this.isFullScreen,
    required this.isCrying,
  });

  static const double _texAspect = 576.0 / 1024.0;
  static const double _standingFgScale = 0.425;
  static const double _cryingFgScale = 0.365;

  @override
  Widget build(BuildContext context) {
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

        final fgScale = isCrying ? _cryingFgScale : _standingFgScale;
        final fgSizeW = sceneWidth * fgScale;
        final fgSizeH = sceneHeight * fgScale;
        final fgLeft = offsetX +
            sceneWidth *
                (isCrying
                    ? (0.520 - 0.495 * fgScale)
                    : (0.485 - 0.5 * fgScale));
        final fgTop = offsetY +
            sceneHeight *
                (isCrying
                    ? (0.752 - 0.827 * fgScale)
                    : (0.745 - 0.955 * fgScale));

        final shadowW = sceneWidth * (isCrying ? 0.24 : 0.11);
        final shadowH = sceneHeight * (isCrying ? 0.044 : 0.028);
        final shadowLeft =
            offsetX + sceneWidth * (isCrying ? 0.510 : 0.478) - shadowW * 0.5;
        final shadowTop =
            offsetY + sceneHeight * (isCrying ? 0.742 : 0.744) - shadowH * 0.5;

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
                  isCrying
                      ? _WatchtowerCellShaderViewState._princessCryingAsset
                      : _WatchtowerCellShaderViewState._princessAsset,
                  key: ValueKey(
                    isCrying
                        ? 'watchtower_spyglass_princess_crying_image'
                        : 'watchtower_spyglass_princess_standing_image',
                  ),
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
