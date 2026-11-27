import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/royal_garden_tutorial_controller.dart';
import '../../models/story_chapter.dart';
import '../../theme/app_theme.dart';
import '../dialogs/observatory_dialog.dart';
import '../widgets/royal_garden_tutorial_battle.dart';
import '../widgets/watch_tower_icon.dart';
import 'world_map_screen.dart';

/// Interactive 5-Scene Prologue Story & Playable Royal Garden Tutorial Battle
/// shown on first launch (`hasSeenIntro == false`) and replayable anytime in
/// isolated sandbox mode from Royal Castle Library `#1`, Watch Tower Story Log,
/// or Settings.
class IntroStoryScreen extends StatefulWidget {
  final bool isReplay;
  final int initialPage;
  final VoidCallback? onFinished;
  final RoyalGardenTutorialController? tutorialController;

  const IntroStoryScreen({
    super.key,
    this.isReplay = false,
    this.initialPage = 0,
    this.onFinished,
    this.tutorialController,
  });

  /// Opens [IntroStoryScreen] as a full-screen replay modal (e.g., from Royal
  /// Castle -> Library or Settings) in isolated sandbox mode without altering
  /// campaign progress.
  static Future<void> showReplay(
    BuildContext context, {
    int initialPage = 0,
    RoyalGardenTutorialController? tutorialController,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => IntroStoryScreen(
          isReplay: true,
          initialPage: initialPage.clamp(0, IntroStoryCardData.cards.length - 1),
          tutorialController: tutorialController,
        ),
      ),
    );
  }

  @override
  State<IntroStoryScreen> createState() => _IntroStoryScreenState();
}

class _IntroStoryScreenState extends State<IntroStoryScreen> {
  static const Duration _typewriterCharInterval = Duration(milliseconds: 25);
  static const int _tutorialTriggerSlideIndex = 1; // Slide 2 (intro_2)
  static const int _postTutorialResumeSlideIndex = 2; // Slide 3 (intro_3)

  late PageController _pageController;
  late int _currentPage;
  int _revealedCharCount = 0;
  Timer? _typewriterTimer;
  GameController? _controller;
  bool _hasCompleted = false;

  bool _isInTutorialBattle = false;
  bool _hasPassedTutorialGate = false;
  bool _hasCompletedTutorialBattle = false;
  int _earnedFireOrbs = 0;
  int _earnedWaterOrbs = 0;
  int _earnedWoodOrbs = 0;

  List<IntroStoryCardData> get _cards => IntroStoryCardData.cards;
  IntroStoryCardData get _activeCard => _cards[_currentPage];
  bool get _isLastCard => _currentPage >= _cards.length - 1;
  bool get _shouldLaunchTutorialAfterCurrentCard =>
      _currentPage == _tutorialTriggerSlideIndex && !_hasPassedTutorialGate;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, _cards.length - 1);
    _hasPassedTutorialGate = _currentPage > _tutorialTriggerSlideIndex;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = context.read<GameController>();
    if (_controller != nextController) {
      final isInitialAttach = _controller == null;
      _controller = nextController;
      if (isInitialAttach && !_isInTutorialBattle) {
        _startTypewriterForPage(_currentPage);
      }
    }
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  String _localizedCaption(
    IntroStoryCardData card,
    GameController controller,
  ) {
    return controller.localization.t(
      card.captionKey,
      fallback: card.fallbackCaption,
    );
  }

  void _startTypewriterForPage(int pageIndex) {
    _typewriterTimer?.cancel();
    final controller = _controller;
    if (controller == null) return;
    final fullText = _localizedCaption(_cards[pageIndex], controller);

    if (!controller.animationsEnabled || fullText.isEmpty) {
      _revealedCharCount = fullText.length;
      return;
    }

    _revealedCharCount = 0;
    _typewriterTimer = Timer.periodic(_typewriterCharInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final targetLength = _localizedCaption(_activeCard, controller).length;
      if (_revealedCharCount < targetLength) {
        setState(() {
          _revealedCharCount = (_revealedCharCount + 1).clamp(0, targetLength);
        });
      } else {
        timer.cancel();
      }
    });
  }

  bool _isCardTextComplete(GameController controller) {
    final fullText = _localizedCaption(_activeCard, controller);
    return _revealedCharCount >= fullText.length;
  }

  void _revealFullTextNow(GameController controller) {
    _typewriterTimer?.cancel();
    final fullLength = _localizedCaption(_activeCard, controller).length;
    setState(() {
      _revealedCharCount = fullLength;
    });
  }

  void _enterTutorialBattle() {
    _typewriterTimer?.cancel();
    setState(() {
      _isInTutorialBattle = true;
    });
  }

  void _resumeAtPostTutorialSlide() {
    _pageController.dispose();
    _pageController = PageController(initialPage: _postTutorialResumeSlideIndex);
    setState(() {
      _isInTutorialBattle = false;
      _currentPage = _postTutorialResumeSlideIndex;
      _startTypewriterForPage(_postTutorialResumeSlideIndex);
    });
  }

  void _handleTutorialBattleCompleted({
    required int fireOrbs,
    required int waterOrbs,
    required int woodOrbs,
  }) {
    if (!mounted) return;
    _earnedFireOrbs = fireOrbs;
    _earnedWaterOrbs = waterOrbs;
    _earnedWoodOrbs = woodOrbs;
    _hasCompletedTutorialBattle = true;
    _hasPassedTutorialGate = true;
    _resumeAtPostTutorialSlide();
  }

  void _handleTutorialBattleSkipped() {
    if (!mounted) return;
    _earnedFireOrbs = 0;
    _earnedWaterOrbs = 0;
    _earnedWoodOrbs = 0;
    _hasCompletedTutorialBattle = false;
    _hasPassedTutorialGate = true;
    _resumeAtPostTutorialSlide();
  }

  void _goToPage(int nextPage) {
    final controller = _controller;
    if (controller == null) return;
    final maxAllowedPage = _hasPassedTutorialGate
        ? _cards.length - 1
        : _tutorialTriggerSlideIndex;
    final clamped = nextPage.clamp(0, maxAllowedPage);
    if (clamped == _currentPage) return;

    if (controller.animationsEnabled && _pageController.hasClients) {
      _pageController.animateToPage(
        clamped,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else if (_pageController.hasClients) {
      _pageController.jumpToPage(clamped);
    } else {
      setState(() {
        _currentPage = clamped;
        _startTypewriterForPage(clamped);
      });
    }
  }

  void _finishIntro() {
    if (_hasCompleted) return;
    _hasCompleted = true;
    _typewriterTimer?.cancel();

    final controller = _controller ?? context.read<GameController>();
    if (widget.isReplay) {
      if (widget.onFinished != null) {
        widget.onFinished!();
      } else if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    controller.completeIntroStory(
      grantTutorialOrbs: _hasCompletedTutorialBattle,
      fireOrbsBonus: _earnedFireOrbs,
      waterOrbsBonus: _earnedWaterOrbs,
      woodOrbsBonus: _earnedWoodOrbs,
    );
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const WorldMapScreen()),
      );
    }
  }

  void _handleGoToWatchTowerTap(GameController controller) {
    if (_hasCompleted) return;
    _hasCompleted = true;
    _typewriterTimer?.cancel();
    controller.audio.playTapVibrate();

    if (widget.isReplay) {
      if (!controller.hasSeenIntro) {
        controller.completeIntroStory();
      }
      final navigator = Navigator.of(context);
      if (widget.onFinished != null) {
        widget.onFinished!();
      } else if (navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }

      if (controller.isWorldMapAttached) {
        controller.requestOpenWatchTower();
      } else {
        final hostContext = navigator.context;
        if (hostContext.mounted) {
          showDialog<void>(
            context: hostContext,
            builder: (_) => WatchTowerDialog(controller: controller),
          );
        }
      }
      return;
    }

    controller.requestOpenWatchTower();
    controller.completeIntroStory(
      grantTutorialOrbs: _hasCompletedTutorialBattle,
      fireOrbsBonus: _earnedFireOrbs,
      waterOrbsBonus: _earnedWaterOrbs,
      woodOrbsBonus: _earnedWoodOrbs,
    );
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const WorldMapScreen()),
      );
    }
  }

  void _handleDialogueTap(GameController controller) {
    controller.audio.playTapVibrate();
    if (!_isCardTextComplete(controller)) {
      _revealFullTextNow(controller);
      return;
    }
    if (_shouldLaunchTutorialAfterCurrentCard) {
      _enterTutorialBattle();
    } else if (_isLastCard) {
      _finishIntro();
    } else {
      _goToPage(_currentPage + 1);
    }
  }

  void _handleActionButtonTap(GameController controller) {
    controller.audio.playTapVibrate();
    if (_shouldLaunchTutorialAfterCurrentCard) {
      _enterTutorialBattle();
    } else if (_isLastCard) {
      _finishIntro();
    } else {
      _goToPage(_currentPage + 1);
    }
  }

  void _handleSkipTap(GameController controller) {
    controller.audio.playTapVibrate();
    _finishIntro();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final loc = controller.localization;
    final palette = AppPalette.of(context);
    final isDark = palette.isDark;

    if (_isInTutorialBattle) {
      return RoyalGardenTutorialBattle(
        key: const ValueKey('intro_royal_garden_tutorial_battle'),
        gameController: controller,
        tutorialController: widget.tutorialController,
        isReplay: widget.isReplay,
        onSkip: _handleTutorialBattleSkipped,
        onBattleCompleted: _handleTutorialBattleCompleted,
      );
    }

    final skipLabel = loc.t('story_skip', fallback: 'Skip');
    final nextLabel = loc.t('story_next', fallback: 'Next');
    final beginQuestLabel = loc.t(
      'story_begin_quest',
      fallback: 'Begin Quest',
    );
    final goToWatchTowerLabel = loc.t(
      'story_go_to_watchtower_btn',
      fallback: 'Go to Watch Tower',
    );

    final bgColors = isDark
        ? const [Color(0xFF0D0E12), Color(0xFF161923)]
        : const [Color(0xFFFAF6EE), Color(0xFFF0E7D4)];

    final frameBorderColor = isDark
        ? const Color(0xFFFFB300)
        : const Color(0xFFC8961E);

    return Scaffold(
      key: const ValueKey('intro_story_screen'),
      backgroundColor: bgColors.first,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bgColors,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Row with Skip Button aligned to the top-right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.amber.withValues(alpha: 0.14)
                                : const Color(0xFFEAE0CA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: frameBorderColor.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_stories_rounded,
                                size: 15,
                                color: palette.amberIcon,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_currentPage + 1} / ${_cards.length}',
                                key: const ValueKey('intro_page_counter'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: palette.amberText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          key: const ValueKey('intro_skip_button'),
                          onPressed: () => _handleSkipTap(controller),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.amber.shade200
                                : const Color(0xFF7A4E00),
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFEAE0CA),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: frameBorderColor.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.skip_next_rounded, size: 18),
                          label: Text(
                            skipLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Center 1-Card-Per-Page Storybook Carousel
                    Expanded(
                      child: PageView.builder(
                        key: const ValueKey('intro_story_page_view'),
                        controller: _pageController,
                        itemCount: _hasPassedTutorialGate
                            ? _cards.length
                            : _tutorialTriggerSlideIndex + 1,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                            _startTypewriterForPage(index);
                          });
                        },
                        itemBuilder: (context, index) {
                          final card = _cards[index];
                          final isActive = index == _currentPage;
                          return _IntroStoryCardPage(
                            card: card,
                            controller: controller,
                            palette: palette,
                            frameBorderColor: frameBorderColor,
                            revealedCharCount: isActive
                                ? _revealedCharCount
                                : _localizedCaption(card, controller).length,
                            isTextComplete: isActive
                                ? _isCardTextComplete(controller)
                                : true,
                            onDialogueTap: () => _handleDialogueTap(controller),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bottom Row: 5 Animated Page Indicator Dots + Golden RPG Action Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          key: const ValueKey('intro_page_indicators'),
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_cards.length, (i) {
                            final isSelected = i == _currentPage;
                            final isVisited = i < _currentPage;
                            return AnimatedContainer(
                              key: ValueKey('intro_page_dot_$i'),
                              duration: controller.animationsEnabled
                                  ? const Duration(milliseconds: 240)
                                  : Duration.zero,
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.only(right: 8),
                              width: isSelected ? 24 : 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? frameBorderColor
                                    : (isVisited
                                        ? frameBorderColor.withValues(alpha: 0.48)
                                        : (isDark
                                            ? Colors.white24
                                            : const Color(0xFFD0C3AB))),
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: frameBorderColor.withValues(
                                            alpha: 0.45,
                                          ),
                                          blurRadius: 6,
                                          spreadRadius: 0.5,
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: ElevatedButton.icon(
                            key: const ValueKey('intro_action_button'),
                            onPressed: () => _handleActionButtonTap(controller),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF5C22B),
                              foregroundColor: const Color(0xFF1E1B16),
                              elevation: 4,
                              shadowColor: Colors.amber.withValues(alpha: 0.45),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(
                                  color: Color(0xFFC8961E),
                                  width: 1.4,
                                ),
                              ),
                            ),
                            icon: Icon(
                              _isLastCard
                                  ? Icons.shield_outlined
                                  : Icons.arrow_forward_rounded,
                              size: 19,
                            ),
                            label: Text(
                              _isLastCard ? beginQuestLabel : nextLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isLastCard) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          key: const ValueKey('intro_go_to_watchtower_button'),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark
                                ? const Color(0xFFFFD54F)
                                : const Color(0xFF7A4E00),
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _handleGoToWatchTowerTap(controller),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const WatchTowerIcon(size: 16),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  goToWatchTowerLabel,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFFFD54F)
                                        : const Color(0xFF7A4E00),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                    decorationColor: (isDark
                                            ? const Color(0xFFFFD54F)
                                            : const Color(0xFF7A4E00))
                                        .withValues(alpha: 0.75),
                                    decorationThickness: 1.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '→',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFFFD54F)
                                      : const Color(0xFF7A4E00),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroStoryCardPage extends StatelessWidget {
  final IntroStoryCardData card;
  final GameController controller;
  final AppPalette palette;
  final Color frameBorderColor;
  final int revealedCharCount;
  final bool isTextComplete;
  final VoidCallback onDialogueTap;

  const _IntroStoryCardPage({
    required this.card,
    required this.controller,
    required this.palette,
    required this.frameBorderColor,
    required this.revealedCharCount,
    required this.isTextComplete,
    required this.onDialogueTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = controller.localization;
    final isDark = palette.isDark;

    final chapterLabel = loc.t(
      card.chapterKey,
      fallback: card.fallbackChapter,
    );
    final chapterTitle = loc.t(
      card.titleKey,
      fallback: card.fallbackTitle,
    );
    final fullCaption = loc.t(
      card.captionKey,
      fallback: card.fallbackCaption,
    );
    final visibleCaption = fullCaption.substring(
      0,
      revealedCharCount.clamp(0, fullCaption.length),
    );
    final tapContinueLabel = loc.t(
      'story_tap_continue',
      fallback: 'Tap to Continue',
    );

    final boxBgColor = isDark
        ? const Color(0xFF161923)
        : const Color(0xFFF5EFE2);
    final boxBorderColor = isDark
        ? const Color(0xFFFFB300).withValues(alpha: 0.50)
        : const Color(0xFFC8961E);
    final chapterTextColor = isDark
        ? const Color(0xFFFFB300)
        : const Color(0xFF7A4E00);
    final bodyTextColor = isDark
        ? Colors.white
        : const Color(0xFF231F1A);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight * 0.85),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Artwork Frame (1024x571 widescreen, rounded RPG frame, golden-amber border, no cropping)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: (constraints.maxHeight * 0.52).clamp(160.0, 420.0),
                    ),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1024.0 / 571.0,
                        child: Container(
                          key: ValueKey('intro_artwork_frame_${card.id}'),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF12151E)
                                : const Color(0xFFEDE4D2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: frameBorderColor,
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.58)
                                    : const Color(0xFF7A4E00).withValues(alpha: 0.18),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: frameBorderColor.withValues(
                                  alpha: isDark ? 0.16 : 0.12,
                                ),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              card.assetPath,
                              key: ValueKey('intro_artwork_image_${card.id}'),
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: isDark
                                      ? const Color(0xFF1C202B)
                                      : const Color(0xFFEAE0CA),
                                  child: Center(
                                    child: Icon(
                                      card.icon,
                                      size: 56,
                                      color: frameBorderColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bottom Narrative Dialogue Box (Tap to reveal or advance)
                  GestureDetector(
                    key: ValueKey('intro_dialogue_box_${card.index}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onDialogueTap,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: boxBgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: boxBorderColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.42 : 0.10,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Chapter Badge + Title
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5C22B),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  chapterLabel,
                                  style: const TextStyle(
                                    color: Color(0xFF1E1B16),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  chapterTitle,
                                  style: TextStyle(
                                    color: chapterTextColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Narrative Caption with Typewriter Reveal
                          // Stack reserves full text height cleanly so the box never jumps while typing
                          Stack(
                            children: [
                              Opacity(
                                opacity: 0.0,
                                child: IgnorePointer(
                                  child: Text(
                                    fullCaption,
                                    style: TextStyle(
                                      color: bodyTextColor,
                                      fontSize: 14,
                                      height: 1.45,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                visibleCaption,
                                key: ValueKey('intro_caption_text_${card.index}'),
                                style: TextStyle(
                                  color: bodyTextColor,
                                  fontSize: 14,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Subtle Tap-to-Continue Hint
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(
                                isTextComplete
                                    ? Icons.touch_app_outlined
                                    : Icons.fast_forward_rounded,
                                size: 14,
                                color: chapterTextColor.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                tapContinueLabel,
                                style: TextStyle(
                                  color: chapterTextColor.withValues(alpha: 0.85),
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                ),
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
        );
      },
    );
  }
}
