import 'dart:async';
import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/story_chapter.dart';

typedef ComicCutsceneOverlay = StoryDialog;

class StoryDialog extends StatefulWidget {
  final StoryChapter chapter;
  final GameController controller;

  const StoryDialog({
    super.key,
    required this.chapter,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required StoryChapter chapter,
    required GameController controller,
  }) {
    controller.markStorySeen(chapter);
    controller.audio.playStoryChime();
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Story Cutscene',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: controller.animationsEnabled
          ? const Duration(milliseconds: 320)
          : Duration.zero,
      pageBuilder: (ctx, anim1, anim2) {
        return StoryDialog(
          chapter: chapter,
          controller: controller,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        if (!controller.animationsEnabled) return child;
        final curved = CurvedAnimation(
          parent: anim1,
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
  State<StoryDialog> createState() => _StoryDialogState();
}

class _StoryDialogState extends State<StoryDialog> {
  final ScrollController _scrollController = ScrollController();
  final TransformationController _zoomController = TransformationController();

  int _currentPanelIndex = 0;
  int _revealedCharCount = 0;
  double _horizontalDragDelta = 0.0;
  Timer? _typewriterTimer;

  List<StoryPanelData> get _panels => widget.chapter.panels;

  StoryPanelData get _activePanel => _panels[_currentPanelIndex];

  String _localizedPanelText(StoryPanelData panel) {
    return widget.controller.localization.t(
      panel.textKey,
      fallback: panel.fallbackText,
    );
  }

  String _localizedSpeaker(StoryPanelData panel) {
    return widget.controller.localization.t(
      panel.speakerKey,
      fallback: panel.fallbackSpeaker,
    );
  }

  bool get _isCurrentPanelTextComplete {
    final fullText = _localizedPanelText(_activePanel);
    return _revealedCharCount >= fullText.length;
  }

  bool get _isFirstPanel => _currentPanelIndex <= 0;

  bool get _isLastPanel => _currentPanelIndex >= _panels.length - 1;

  @override
  void initState() {
    super.initState();
    if (!widget.controller.hasSeenStory(widget.chapter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.controller.markStorySeen(widget.chapter);
        }
      });
    }
    _startTypewriterForCurrentPanel();
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _scrollController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  void _startTypewriterForCurrentPanel() {
    _typewriterTimer?.cancel();
    final fullText = _localizedPanelText(_activePanel);
    if (!widget.controller.animationsEnabled || fullText.isEmpty) {
      setState(() {
        _revealedCharCount = fullText.length;
      });
      return;
    }

    setState(() {
      _revealedCharCount = 0;
    });

    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final targetLength = _localizedPanelText(_activePanel).length;
      if (_revealedCharCount < targetLength) {
        setState(() {
          _revealedCharCount = (_revealedCharCount + 3).clamp(0, targetLength);
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _scrollToPanel(int panelIndex) {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    final fraction = (panelIndex / (_panels.length - 1)).clamp(0.0, 1.0);
    final targetOffset = maxExtent * fraction;
    if (widget.controller.animationsEnabled) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }
  }

  void _handleCanvasTap() {
    widget.controller.audio.playTapVibrate();

    if (!_isCurrentPanelTextComplete) {
      _typewriterTimer?.cancel();
      setState(() {
        _revealedCharCount = _localizedPanelText(_activePanel).length;
      });
      return;
    }

    _advanceOrClose();
  }

  void _handleBackButtonTap() {
    if (_isFirstPanel) return;
    widget.controller.audio.playTapVibrate();
    _rewindPanel();
  }

  void _handleNextButtonTap() {
    widget.controller.audio.playTapVibrate();
    _advanceOrClose();
  }

  void _rewindPanel() {
    if (!_isFirstPanel) {
      setState(() {
        _currentPanelIndex--;
      });
      _startTypewriterForCurrentPanel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToPanel(_currentPanelIndex);
      });
    }
  }

  void _advancePanelOnly() {
    if (!_isLastPanel) {
      setState(() {
        _currentPanelIndex++;
      });
      _startTypewriterForCurrentPanel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToPanel(_currentPanelIndex);
      });
    }
  }

  void _advanceOrClose() {
    if (!_isLastPanel) {
      _advancePanelOnly();
    } else {
      _closeCutscene();
    }
  }

  void _handleDialogueHorizontalDragStart(DragStartDetails details) {
    _horizontalDragDelta = 0.0;
  }

  void _handleDialogueHorizontalDragUpdate(DragUpdateDetails details) {
    _horizontalDragDelta += details.primaryDelta ?? 0.0;
  }

  void _handleDialogueHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    if (_horizontalDragDelta > 24 || velocity > 150) {
      // Sliding finger to the right -> rewind to previous panel
      if (!_isFirstPanel) {
        widget.controller.audio.playTapVibrate();
        _rewindPanel();
      }
    } else if (_horizontalDragDelta < -24 || velocity < -150) {
      // Sliding finger to the left -> move forward to next panel
      if (!_isLastPanel) {
        widget.controller.audio.playTapVibrate();
        _advancePanelOnly();
      }
    }
    _horizontalDragDelta = 0.0;
  }

  void _closeCutscene() {
    _typewriterTimer?.cancel();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.controller.localization;
    final chapterTitle = loc.t(
      widget.chapter.titleKey,
      fallback: widget.chapter.fallbackTitle,
    );
    final skipLabel = loc.t('story_skip', fallback: 'Skip');
    final backLabel = loc.t('story_back', fallback: 'Back');
    final nextLabel = loc.t('story_next', fallback: 'Next');
    final tapContinueLabel = loc.t(
      'story_tap_continue',
      fallback: 'Tap to Continue',
    );
    final finishLabel = loc.t('story_finish', fallback: 'Continue');
    final panelWord = loc.t('story_panel_of', fallback: 'Panel');

    final activePanel = _activePanel;
    final activeFullText = _localizedPanelText(activePanel);
    final visibleActiveText = activeFullText.substring(
      0,
      _revealedCharCount.clamp(0, activeFullText.length),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  // Top Bar: Chapter Title & Clean Skip Button in the corner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14161F).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.chapter.icon,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chapterTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$panelWord ${_currentPanelIndex + 1} / ${_panels.length}',
                                style: TextStyle(
                                  color: Colors.amber.shade200,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          key: const ValueKey('story_skip_button'),
                          onPressed: () {
                            widget.controller.audio.playTapVibrate();
                            _closeCutscene();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.skip_next_rounded, size: 18),
                          label: Text(
                            skipLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Main High-Res Vertical Comic Reader with Pinch-to-Zoom & Scroll
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1017),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: GestureDetector(
                          key: const ValueKey('story_comic_canvas'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _handleCanvasTap,
                          child: InteractiveViewer(
                            transformationController: _zoomController,
                            minScale: 1.0,
                            maxScale: 3.0,
                            panEnabled: true,
                            scaleEnabled: true,
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.all(8),
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: widget.chapter.imageAspectRatio,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // High-Res Vertical Comic Strip Artwork
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.asset(
                                          widget.chapter.assetPath,
                                          fit: BoxFit.cover,
                                          filterQuality: FilterQuality.high,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              color: const Color(0xFF1C202B),
                                              child: Center(
                                                child: Icon(
                                                  widget.chapter.icon,
                                                  size: 64,
                                                  color: Colors.amber,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),

                                      // 4 Scene Panel Overlays (No speech bubbles over the artwork)
                                      Column(
                                        children: List.generate(
                                          _panels.length,
                                          (index) {
                                            final isRevealed =
                                                index <= _currentPanelIndex;
                                            final isActive =
                                                index == _currentPanelIndex;

                                            return Expanded(
                                              child: AnimatedContainer(
                                                duration: widget
                                                        .controller
                                                        .animationsEnabled
                                                    ? const Duration(
                                                        milliseconds: 280,
                                                      )
                                                    : Duration.zero,
                                                decoration: BoxDecoration(
                                                  color: isRevealed
                                                      ? Colors.transparent
                                                      : Colors.black.withValues(
                                                          alpha: 0.58,
                                                        ),
                                                  border: isActive
                                                      ? Border.all(
                                                          color: Colors.amber
                                                              .withValues(
                                                            alpha: 0.85,
                                                          ),
                                                          width: 2.2,
                                                        )
                                                      : null,
                                                ),
                                                child: isRevealed
                                                    ? const SizedBox.expand()
                                                    : Center(
                                                        child: Icon(
                                                          Icons
                                                              .auto_awesome_outlined,
                                                          color: Colors.white
                                                              .withValues(
                                                            alpha: 0.25,
                                                          ),
                                                          size: 24,
                                                        ),
                                                      ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Bottom Control Bar: Swipeable Active Dialogue Box + Back & Next Buttons
                  GestureDetector(
                    key: const ValueKey('story_dialogue_box'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _handleCanvasTap,
                    onHorizontalDragStart: _handleDialogueHorizontalDragStart,
                    onHorizontalDragUpdate: _handleDialogueHorizontalDragUpdate,
                    onHorizontalDragEnd: _handleDialogueHorizontalDragEnd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14161F).withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Active speaker & panel progress dots
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _localizedSpeaker(activePanel).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Panel progress dots
                              Row(
                                children: List.generate(_panels.length, (i) {
                                  final selected = i == _currentPanelIndex;
                                  final passed = i < _currentPanelIndex;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    width: selected ? 18 : 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.amber
                                          : (passed
                                              ? Colors.amber.withValues(
                                                  alpha: 0.45,
                                                )
                                              : Colors.white24),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              visibleActiveText,
                              key: const ValueKey('story_active_dialogue_text'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.touch_app_outlined,
                                      size: 15,
                                      color: Colors.amber.shade200,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        tapContinueLabel,
                                        style: TextStyle(
                                          color: Colors.amber.shade200,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton.icon(
                                    key: const ValueKey('story_back_button'),
                                    onPressed: _isFirstPanel
                                        ? null
                                        : _handleBackButtonTap,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          Colors.white.withValues(alpha: 0.05),
                                      disabledForegroundColor: Colors.white38,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      size: 17,
                                    ),
                                    label: Text(
                                      backLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    key: const ValueKey('story_next_button'),
                                    onPressed: _handleNextButtonTap,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: Icon(
                                      _isLastPanel
                                          ? Icons.check_circle_outline
                                          : Icons.arrow_forward_rounded,
                                      size: 17,
                                    ),
                                    label: Text(
                                      _isLastPanel ? finishLabel : nextLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

