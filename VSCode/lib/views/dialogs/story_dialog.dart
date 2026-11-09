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

  void _handleNextButtonTap() {
    widget.controller.audio.playTapVibrate();
    _advanceOrClose();
  }

  void _advanceOrClose() {
    if (!_isLastPanel) {
      setState(() {
        _currentPanelIndex++;
      });
      _startTypewriterForCurrentPanel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToPanel(_currentPanelIndex);
      });
    } else {
      _closeCutscene();
    }
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

                                      // 4 Scene Panel Overlays + Dynamic Speech Bubbles
                                      Column(
                                        children: List.generate(
                                          _panels.length,
                                          (index) {
                                            final panel = _panels[index];
                                            final isRevealed =
                                                index <= _currentPanelIndex;
                                            final isActive =
                                                index == _currentPanelIndex;
                                            final fullPanelText =
                                                _localizedPanelText(panel);
                                            final bubbleText = isActive
                                                ? visibleActiveText
                                                : fullPanelText;
                                            final speaker =
                                                _localizedSpeaker(panel);

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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8,
                                                ),
                                                child: isRevealed
                                                    ? Align(
                                                        alignment: panel
                                                            .bubbleAlignment,
                                                        child:
                                                            _ComicSpeechBubble(
                                                          key: ValueKey(
                                                            'comic_bubble_$index',
                                                          ),
                                                          speaker: speaker,
                                                          text: bubbleText,
                                                          isActive: isActive,
                                                          tailOnLeft:
                                                              panel.tailOnLeft,
                                                        ),
                                                      )
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

                  // Bottom Control Bar: Active Dialogue Box + Stylized "Next / Tap to Continue" Indicator
                  Container(
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
                        // Active speaker & typewriter dialogue preview for effortless reading on any screen size
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
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
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
                        GestureDetector(
                          onTap: _handleCanvasTap,
                          child: SizedBox(
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
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: _handleCanvasTap,
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
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              key: const ValueKey('story_next_button'),
                              onPressed: _handleNextButtonTap,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
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

class _ComicSpeechBubble extends StatelessWidget {
  final String speaker;
  final String text;
  final bool isActive;
  final bool tailOnLeft;

  const _ComicSpeechBubble({
    super.key,
    required this.speaker,
    required this.text,
    required this.isActive,
    required this.tailOnLeft,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            tailOnLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isActive ? 0.96 : 0.88),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF11131A),
                width: isActive ? 2.2 : 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 6,
                  offset: const Offset(2, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  speaker.toUpperCase(),
                  style: TextStyle(
                    color: Colors.deepOrange.shade800,
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF11131A),
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: CustomPaint(
              size: const Size(14, 8),
              painter: _BubbleTailPainter(
                tailOnLeft: tailOnLeft,
                fillColor:
                    Colors.white.withValues(alpha: isActive ? 0.96 : 0.88),
                borderColor: const Color(0xFF11131A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final bool tailOnLeft;
  final Color fillColor;
  final Color borderColor;

  const _BubbleTailPainter({
    required this.tailOnLeft,
    required this.fillColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (tailOnLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width * 0.3, size.height);
      path.lineTo(size.width, 0);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width * 0.7, size.height);
      path.lineTo(size.width, 0);
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return oldDelegate.tailOnLeft != tailOnLeft ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}

