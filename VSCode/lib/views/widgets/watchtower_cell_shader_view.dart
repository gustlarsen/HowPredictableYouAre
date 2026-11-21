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

  const WatchtowerCellShaderView({
    super.key,
    this.animationsEnabled = true,
    this.forceStaticFallback = false,
    this.isFullScreen = false,
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

  final ValueNotifier<double> _timeSeconds = ValueNotifier<double>(0.0);
  late final Ticker _ticker;

  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  ui.Image? _bgImage;
  ui.Image? _princessImage;
  bool _shaderFailed = false;
  bool _disposed = false;

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
        _ticker.stop();
        setState(() {
          _shaderFailed = true;
        });
      } else if (_program == null) {
        _shaderFailed = false;
        unawaited(_loadAssets());
      }
    }
  }

  Future<void> _loadAssets() async {
    try {
      final results = await Future.wait<Object>([
        ui.FragmentProgram.fromAsset(_shaderAsset),
        _decodeAssetImage(_bgAsset),
        _decodeAssetImage(_princessAsset),
      ]);

      final program = results[0] as ui.FragmentProgram;
      final bgImage = results[1] as ui.Image;
      final princessImage = results[2] as ui.Image;

      if (_disposed) {
        bgImage.dispose();
        princessImage.dispose();
        return;
      }

      final shader = program.fragmentShader();
      setState(() {
        _program = program;
        _shader = shader;
        _bgImage = bgImage;
        _princessImage = princessImage;
        _shaderFailed = false;
      });
      _syncTicker();
    } catch (_) {
      if (_disposed) return;
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
          ),
          child: const SizedBox.expand(),
        ),
      );
    }

    return _StaticDungeonFallback(isFullScreen: widget.isFullScreen);
  }
}

class _WatchtowerCellShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image bgImage;
  final ui.Image princessImage;
  final ValueNotifier<double> timeSeconds;
  final bool isFullScreen;

  _WatchtowerCellShaderPainter({
    required this.shader,
    required this.bgImage,
    required this.princessImage,
    required this.timeSeconds,
    required this.isFullScreen,
  }) : super(repaint: timeSeconds);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, timeSeconds.value);
    shader.setFloat(3, isFullScreen ? 1.0 : 0.0);
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
        oldDelegate.isFullScreen != isFullScreen;
  }
}

/// Clean static fallback rendered while the shader is loading or when running
/// in headless CI test environments without GPU shader support.
class _StaticDungeonFallback extends StatelessWidget {
  final bool isFullScreen;

  const _StaticDungeonFallback({required this.isFullScreen});

  static const double _texAspect = 576.0 / 1024.0;
  static const double _fgScale = 0.62;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('watchtower_spyglass_fallback_stack'),
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final viewAspect = h > 0 ? w / h : 1.0;

        final lensZoom = isFullScreen ? 1.0 : 1.45;
        final targetX = isFullScreen ? 0.50 : 0.49;
        final targetY = isFullScreen ? 0.50 : 0.465;

        // Match the shader's scene coordinate & optical lens zoom transform
        final double sceneWidth;
        final double sceneHeight;
        if (viewAspect > _texAspect) {
          sceneWidth = w * lensZoom;
          sceneHeight = (w / _texAspect) * lensZoom;
        } else {
          sceneHeight = h * lensZoom;
          sceneWidth = (h * _texAspect) * lensZoom;
        }
        final offsetX = w * 0.5 - sceneWidth * targetX;
        final offsetY = h * 0.5 - sceneHeight * targetY;

        final fgSizeW = sceneWidth * _fgScale;
        final fgSizeH = sceneHeight * _fgScale;
        final fgLeft = offsetX + sceneWidth * (0.490 - 0.5 * _fgScale);
        final fgTop = offsetY + sceneHeight * (0.815 - 0.955 * _fgScale);

        final shadowW = sceneWidth * 0.16;
        final shadowH = sceneHeight * 0.042;
        final shadowLeft = offsetX + sceneWidth * 0.478 - shadowW * 0.5;
        final shadowTop = offsetY + sceneHeight * 0.814 - shadowH * 0.5;

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
                  _WatchtowerCellShaderViewState._princessAsset,
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
