import 'dart:async';
import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/metal_wizard_lair_icon.dart';
import '../widgets/watch_tower_icon.dart';

class _Week0ScreamSlideData {
  final Widget iconWidget;
  final Color accentColor;
  final String speakerKey;
  final String fallbackSpeaker;
  final String titleKey;
  final String fallbackTitle;
  final String bodyKey;
  final String fallbackBody;

  const _Week0ScreamSlideData({
    required this.iconWidget,
    required this.accentColor,
    required this.speakerKey,
    required this.fallbackSpeaker,
    required this.titleKey,
    required this.fallbackTitle,
    required this.bodyKey,
    required this.fallbackBody,
  });
}

/// Result action chosen by the player on the Week 0 scream warning alert.
enum Week0ScreamWarningAction { close, goToWatchTower }

/// 2-slide Royal Chronicler-styled warning carousel shown once per campaign when
/// the player leaves Week 0 for Week 1 without defeating both the Guardian
/// Robot and the Metal Wizard.
class Week0ScreamWarningDialog extends StatefulWidget {
  final GameController controller;

  const Week0ScreamWarningDialog({
    super.key,
    required this.controller,
  });

  static Future<Week0ScreamWarningAction?> show(
    BuildContext context, {
    required GameController controller,
  }) async {
    unawaited(controller.audio.playPrincessScream());
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();

    final action = await showGeneralDialog<Week0ScreamWarningAction>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Watch Tower Alert',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: controller.animationsEnabled
          ? const Duration(milliseconds: 300)
          : Duration.zero,
      pageBuilder: (ctx, anim1, anim2) =>
          Week0ScreamWarningDialog(controller: controller),
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
    unawaited(controller.audio.finishPrincessScreamAndRestoreBgm());
    return action;
  }

  @override
  State<Week0ScreamWarningDialog> createState() =>
      _Week0ScreamWarningDialogState();
}

class _Week0ScreamWarningDialogState extends State<Week0ScreamWarningDialog> {
  static const Color _darkCardSurface = Color(0xFF161A22);
  static const Color _lightCardSurface = Color(0xFFF5EFE2);
  static const Color _primaryOrange = Color(0xFFF57C00);
  static const Color _warmGold = Color(0xFFF5C22B);

  int _index = 0;

  static const List<_Week0ScreamSlideData> _slides = [
    _Week0ScreamSlideData(
      iconWidget: MetalWizardLairIcon(size: 42),
      accentColor: _primaryOrange,
      speakerKey: 'week0_scream_s1_speaker',
      fallbackSpeaker: "Metal Wizard's Lair",
      titleKey: 'week0_scream_s1_title',
      fallbackTitle: 'A Piercing Scream Echoes!',
      bodyKey: 'week0_scream_s1_body',
      fallbackBody:
          "As the Cleric returned from the Metal Wizard's Lair without defeating both the first robot and the Metal Wizard, a loud, piercing scream echoed from inside the Wizard's Lair.",
    ),
    _Week0ScreamSlideData(
      iconWidget: WatchTowerIcon(size: 42),
      accentColor: _warmGold,
      speakerKey: 'week0_scream_s2_speaker',
      fallbackSpeaker: 'Watch Tower Lookout',
      titleKey: 'week0_scream_s2_title',
      fallbackTitle: 'Check the Watch Tower',
      bodyKey: 'week0_scream_s2_body',
      fallbackBody:
          'Visit the Watch Tower on the World Map and inspect the dungeon through the spyglass to see what may have happened inside.',
    ),
  ];

  void _dismissDialog(Week0ScreamWarningAction action) {
    widget.controller.audio.playTapVibrate();
    widget.controller.markWeek0ScreamWarningDismissed();
    Navigator.of(context).pop(action);
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.controller.localization;
    final palette = AppPalette.of(context);
    final isDark = palette.isDark;
    final slide = _slides[_index];
    final isLast = _index == _slides.length - 1;

    final cardBg = isDark ? _darkCardSurface : _lightCardSurface;
    final borderColor = _index == 0 ? _primaryOrange : _warmGold;
    final narrativeBg =
        isDark ? const Color(0xFF1E2430) : const Color(0xFFFAF6EE);
    final watchTowerLinkColor =
        isDark ? const Color(0xFFFFD54F) : const Color(0xFF7A4E00);

    final badgeLabel = loc.t(
      'week0_scream_alert_badge',
      fallback: 'WATCH TOWER ALERT',
    );

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Material(
              key: const ValueKey('week0_scream_warning_dialog'),
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: borderColor.withValues(alpha: 0.85),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.24),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top header row: rounded badge pill + Skip button
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Container(
                                  key: const ValueKey('week0_scream_badge'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: borderColor.withValues(
                                      alpha: isDark ? 0.18 : 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: borderColor.withValues(alpha: 0.72),
                                    ),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                      color: isDark
                                          ? borderColor
                                          : const Color(0xFF7A3E00),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            key: const ValueKey('week0_scream_skip_button'),
                            onPressed: () =>
                                _dismissDialog(Week0ScreamWarningAction.close),
                            child: Text(
                              loc.t('story_skip', fallback: 'Skip'),
                              style: TextStyle(
                                color: palette.mutedText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Framed illustration / emblem card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: borderColor.withValues(alpha: 0.50),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/images/story/robot_mage_cliff.webp',
                                  key: const ValueKey(
                                    'week0_scream_bg_image',
                                  ),
                                  fit: BoxFit.cover,
                                  alignment: const Alignment(0.0, -0.45),
                                  filterQuality: FilterQuality.high,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: isDark
                                          ? [
                                              slide.accentColor.withValues(
                                                alpha: 0.24,
                                              ),
                                              const Color(0xFF151A24)
                                                  .withValues(alpha: 0.76),
                                            ]
                                          : [
                                              slide.accentColor.withValues(
                                                alpha: 0.20,
                                              ),
                                              _lightCardSurface.withValues(
                                                alpha: 0.82,
                                              ),
                                            ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                  horizontal: 14,
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(13),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark
                                            ? const Color(0xFF151A24)
                                                .withValues(alpha: 0.78)
                                            : _lightCardSurface.withValues(
                                                alpha: 0.88,
                                              ),
                                        border: Border.all(
                                          color: slide.accentColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: slide.iconWidget,
                                    ),
                                    const SizedBox(height: 11),
                                    Text(
                                      loc.t(
                                        slide.speakerKey,
                                        fallback: slide.fallbackSpeaker,
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.9,
                                        color: isDark
                                            ? _warmGold
                                            : const Color(0xFF7A4E00),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      loc.t(
                                        slide.titleKey,
                                        fallback: slide.fallbackTitle,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                        color: palette.primaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bordered narrative text box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: narrativeBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _warmGold.withValues(
                              alpha: isDark ? 0.35 : 0.55,
                            ),
                          ),
                        ),
                        child: Text(
                          loc.t(
                            slide.bodyKey,
                            fallback: slide.fallbackBody,
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: palette.primaryText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Carousel page indicator dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (i) {
                          final active = i == _index;
                          return AnimatedContainer(
                            key: ValueKey('week0_scream_dot_$i'),
                            duration: widget.controller.animationsEnabled
                                ? const Duration(milliseconds: 180)
                                : Duration.zero,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: active
                                  ? _primaryOrange
                                  : palette.mutedText.withValues(alpha: 0.35),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Full-width orange primary action button ("Next" / "Got It")
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: ValueKey(
                            isLast
                                ? 'week0_scream_got_it_button'
                                : 'week0_scream_next_button',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryOrange,
                            foregroundColor: const Color(0xFF10141D),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (isLast) {
                              _dismissDialog(Week0ScreamWarningAction.close);
                            } else {
                              widget.controller.audio.playTapVibrate();
                              setState(() => _index++);
                            }
                          },
                          child: Text(
                            isLast
                                ? loc.t(
                                    'week0_scream_got_it',
                                    fallback: 'Got It',
                                  )
                                : loc.t('story_next', fallback: 'Next'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      if (isLast) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          key: const ValueKey(
                            'week0_scream_go_to_watchtower_button',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: watchTowerLinkColor,
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
                          onPressed: () => _dismissDialog(
                            Week0ScreamWarningAction.goToWatchTower,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const WatchTowerIcon(size: 16),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  loc.t(
                                    'week0_scream_go_to_watchtower_btn',
                                    fallback: 'Go to Watch Tower',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: watchTowerLinkColor,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                    decorationColor: watchTowerLinkColor
                                        .withValues(alpha: 0.75),
                                    decorationThickness: 1.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '→',
                                style: TextStyle(
                                  color: watchTowerLinkColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
      ),
    );
  }
}
