import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../widgets/watchtower_cell_shader_view.dart';
import '../widgets/watchtower_forge_view.dart';
import 'metal_wizard_spyglass_dialog.dart';

enum SpyglassTarget { princessCell, metalWizard }

/// Full-screen interactive Spyglass exploration view displaying either the
/// animated 9:16 dungeon cell or the Metal Wizard's underground forge with
/// pinch-to-zoom, drag/pan, and double-tap zoom.
class FullScreenSpyglassView extends StatefulWidget {
  final GameController controller;
  final SpyglassTarget target;

  const FullScreenSpyglassView({
    super.key,
    required this.controller,
    this.target = SpyglassTarget.princessCell,
  });

  /// Pushes [FullScreenSpyglassView] using a smooth scale + fade transition.
  static Route<void> route({
    required GameController controller,
    SpyglassTarget target = SpyglassTarget.princessCell,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) =>
          FullScreenSpyglassView(controller: controller, target: target),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<FullScreenSpyglassView> createState() => _FullScreenSpyglassViewState();
}

class _FullScreenSpyglassViewState extends State<FullScreenSpyglassView>
    with SingleTickerProviderStateMixin {
  static const double _dungeonAspect = 576.0 / 1024.0;
  static const double _forgeAspect = 1024.0 / 764.0;
  static const double _doubleTapScale = 2.2;

  final TransformationController _transformationController =
      TransformationController();
  late final AnimationController _zoomAnimController;
  Animation<Matrix4>? _zoomAnimation;
  Offset _doubleTapLocalPosition = Offset.zero;
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        final anim = _zoomAnimation;
        if (anim != null) {
          _transformationController.value = anim.value;
        }
      });
  }

  @override
  void dispose() {
    _zoomAnimController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _animateToMatrix(Matrix4 target) {
    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _zoomAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    _zoomAnimController.forward(from: 0.0);
  }

  void _handleDoubleTap() {
    widget.controller.audio.playTapVibrate();
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.05) {
      _animateToMatrix(Matrix4.identity());
      return;
    }

    final w = _viewportSize.width;
    final h = _viewportSize.height;
    if (w <= 0 || h <= 0) return;

    final focal = _doubleTapLocalPosition;
    final rawTx = -focal.dx * (_doubleTapScale - 1.0);
    final rawTy = -focal.dy * (_doubleTapScale - 1.0);
    final clampedTx = rawTx.clamp(-w * (_doubleTapScale - 1.0), 0.0);
    final clampedTy = rawTy.clamp(-h * (_doubleTapScale - 1.0), 0.0);

    final target = Matrix4.identity()
      ..translateByDouble(clampedTx, clampedTy, 0.0, 1.0)
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1.0, 1.0);
    _animateToMatrix(target);
  }

  void _handleResetZoom() {
    widget.controller.audio.playTapVibrate();
    _animateToMatrix(Matrix4.identity());
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.controller.localization;
    final isMetalWizard = widget.target == SpyglassTarget.metalWizard;
    final aspect = isMetalWizard ? _forgeAspect : _dungeonAspect;

    return Scaffold(
      key: const ValueKey('full_screen_spyglass_view'),
      backgroundColor: const Color(0xFF05070B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen interactive animated scene
          LayoutBuilder(
            builder: (context, constraints) {
              _viewportSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              return GestureDetector(
                onDoubleTapDown: (details) {
                  _doubleTapLocalPosition = details.localPosition;
                },
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  key: const ValueKey('full_screen_spyglass_interactive_viewer'),
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 4.0,
                  panEnabled: true,
                  scaleEnabled: true,
                  boundaryMargin: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: aspect,
                        child: isMetalWizard
                            ? WatchtowerForgeView(
                                isFullScreen: true,
                                animationsEnabled:
                                    widget.controller.animationsEnabled,
                                isCoolingDown:
                                    MetalWizardSpyglassDialog.isForgeCoolingDown(
                                      widget.controller,
                                    ),
                              )
                            : WatchtowerCellShaderView(
                                isFullScreen: true,
                                animationsEnabled:
                                    widget.controller.animationsEnabled,
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Subtle bordered RPG lore box along the bottom for Metal Wizard's Forge
          if (isMetalWizard)
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: SafeArea(
                top: false,
                child: IgnorePointer(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Container(
                        key: const ValueKey('full_screen_metal_wizard_lore_box'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1018).withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFB300)
                                .withValues(alpha: 0.55),
                            width: 1.1,
                          ),
                        ),
                        child: Text(
                          MetalWizardSpyglassDialog.resolveNarrativeCaption(
                            widget.controller,
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            height: 1.35,
                            color: const Color(0xFFFFECB3)
                                .withValues(alpha: 0.94),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Minimal floating top controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ValueListenableBuilder<Matrix4>(
                    valueListenable: _transformationController,
                    builder: (context, matrix, _) {
                      final scale = matrix.getMaxScaleOnAxis();
                      if (scale <= 1.05) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.62),
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: const Color(0xFF00E5FF)
                                  .withValues(alpha: 0.65),
                            ),
                          ),
                          child: InkWell(
                            key: const ValueKey(
                              'full_screen_spyglass_reset_zoom_button',
                            ),
                            customBorder: const StadiumBorder(),
                            onTap: _handleResetZoom,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.center_focus_strong_rounded,
                                    size: 16,
                                    color: Color(0xFF00E5FF),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    loc.t(
                                      'observatory_spyglass_reset_zoom',
                                      fallback: 'Reset Zoom',
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFFFFE082),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Close (X) button
                  Material(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: CircleBorder(
                      side: BorderSide(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.72),
                        width: 1.2,
                      ),
                    ),
                    child: IconButton(
                      key: const ValueKey('full_screen_spyglass_close_button'),
                      tooltip: loc.t(
                        'observatory_spyglass_close_btn',
                        fallback: 'Close',
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFFFFE082),
                      ),
                      onPressed: () {
                        widget.controller.audio.playTapVibrate();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
