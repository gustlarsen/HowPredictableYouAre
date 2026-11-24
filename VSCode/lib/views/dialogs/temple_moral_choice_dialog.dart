import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/sacred_temple_icon.dart';

/// Identifies the player's moral choice at the Sacred Temple Sanctuary after
/// defeating the Metal Wizard at `currentWeek >= 1`.
enum TempleMoralChoice {
  sacrificePrincess,
  refuseAndProtect,
}

class _MoralChoiceSlideData {
  final Widget iconWidget;
  final Color accentColor;
  final String speakerKey;
  final String fallbackSpeaker;
  final String titleKey;
  final String fallbackTitle;
  final String bodyKey;
  final String fallbackBody;

  const _MoralChoiceSlideData({
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

/// Themed RPG Story & Moral Choice Carousel shown whenever the Cleric defeats
/// the Metal Wizard (`300 HP`) at `Week 1` or later (`currentWeek >= 1`).
///
/// Supports both Dark Mode and Light Mode parchment styling matching the Royal
/// Chronicler / Watchtower cutscene dialogs, culminating in two interactive
/// choices:
/// 1. `"Sacrifice the Princess"` ([TempleMoralChoice.sacrificePrincess])
/// 2. `"Refuse & Protect Her"` ([TempleMoralChoice.refuseAndProtect])
class TempleMoralChoiceDialog extends StatefulWidget {
  final GameController controller;

  const TempleMoralChoiceDialog({
    super.key,
    required this.controller,
  });

  static Future<TempleMoralChoice> show(
    BuildContext context, {
    required GameController controller,
  }) async {
    controller.audio.playStoryChime();
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();

    final choice = await showGeneralDialog<TempleMoralChoice>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Sacred Temple Moral Choice',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: controller.animationsEnabled
          ? const Duration(milliseconds: 300)
          : Duration.zero,
      pageBuilder: (ctx, anim1, anim2) =>
          TempleMoralChoiceDialog(controller: controller),
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
    return choice ?? TempleMoralChoice.refuseAndProtect;
  }

  @override
  State<TempleMoralChoiceDialog> createState() =>
      _TempleMoralChoiceDialogState();
}

class _TempleMoralChoiceDialogState extends State<TempleMoralChoiceDialog> {
  static const Color _darkCardSurface = Color(0xFF161A22);
  static const Color _lightCardSurface = Color(0xFFF5EFE2);
  static const Color _warmGold = Color(0xFFF5C22B);
  static const Color _crimsonWarn = Color(0xFFE53935);
  static const Color _cyanDefy = Color(0xFF00E5FF);

  int _index = 0;

  List<_MoralChoiceSlideData> _buildSlides() {
    return [
      const _MoralChoiceSlideData(
        iconWidget: SacredTempleIcon(size: 42),
        accentColor: _warmGold,
        speakerKey: 'victory_cutscene_narrator',
        fallbackSpeaker: 'Royal Chronicler',
        titleKey: 'temple_choice_s1_title',
        fallbackTitle: 'Sanctuary of the Sacred Temple',
        bodyKey: 'temple_choice_s1_body',
        fallbackBody:
            'With the Metal Wizard defeated, you carry Princess Aria from the ruined citadel to the Sacred Temple so the Temple High Master—who never leaves the sanctuary due to his sacred vows—can heal her.',
      ),
      _MoralChoiceSlideData(
        iconWidget: SizedBox(
          width: 48,
          height: 48,
          child: Image.asset(
            'assets/images/enemies/temple_master_idle.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.account_balance_rounded,
              size: 40,
              color: _crimsonWarn,
            ),
          ),
        ),
        accentColor: _crimsonWarn,
        speakerKey: 'temple_master_speaker',
        fallbackSpeaker: 'Temple High Master',
        titleKey: 'temple_choice_s2_title',
        fallbackTitle: 'A Dark Mechanical Anomaly!',
        bodyKey: 'temple_choice_s2_body',
        fallbackBody:
            'While channeling a healing prayer over the Princess, the Temple High Master recoils! He senses a dark mechanical anomaly sealed inside her by the Metal Wizard and warns that she must be sacrificed at the altar to prevent a kingdom-wide calamity.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.controller.localization;
    final palette = AppPalette.of(context);
    final isDark = palette.isDark;
    final slides = _buildSlides();
    final slide = slides[_index];
    final isFirst = _index == 0;
    final isLast = _index == slides.length - 1;

    final cardBg = isDark ? _darkCardSurface : _lightCardSurface;
    final borderColor = slide.accentColor;
    final narrativeBg =
        isDark ? const Color(0xFF1E2430) : const Color(0xFFFAF6EE);

    final badgeLabel = loc.t(
      'temple_choice_header_badge',
      fallback: 'SACRED TEMPLE SANCTUARY',
    );

    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Material(
                key: const ValueKey('temple_moral_choice_dialog'),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header badge
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Container(
                                    key: const ValueKey(
                                      'temple_moral_choice_badge',
                                    ),
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
                                        color:
                                            borderColor.withValues(alpha: 0.72),
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
                            if (!isLast)
                              TextButton(
                                key: const ValueKey(
                                  'temple_moral_choice_skip_to_decision_button',
                                ),
                                onPressed: () {
                                  widget.controller.audio.playTapVibrate();
                                  setState(() => _index = slides.length - 1);
                                },
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
                        const SizedBox(height: 8),

                        // Framed Sacred Temple backdrop & emblem
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
                                    'assets/images/temple_arena_bg.webp',
                                    key: const ValueKey(
                                      'temple_moral_choice_bg_image',
                                    ),
                                    fit: BoxFit.cover,
                                    alignment: const Alignment(0.0, -0.35),
                                    filterQuality: FilterQuality.high,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
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
                                                    .withValues(alpha: 0.78),
                                              ]
                                            : [
                                                slide.accentColor.withValues(
                                                  alpha: 0.20,
                                                ),
                                                _lightCardSurface.withValues(
                                                  alpha: 0.84,
                                                ),
                                              ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 14,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isDark
                                              ? const Color(0xFF151A24)
                                                  .withValues(alpha: 0.82)
                                              : _lightCardSurface.withValues(
                                                  alpha: 0.90,
                                                ),
                                          border: Border.all(
                                            color: slide.accentColor,
                                            width: 2,
                                          ),
                                        ),
                                        child: slide.iconWidget,
                                      ),
                                      const SizedBox(height: 8),
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
                                      const SizedBox(height: 4),
                                      Text(
                                        loc.t(
                                          slide.titleKey,
                                          fallback: slide.fallbackTitle,
                                        ),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 17.5,
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
                        const SizedBox(height: 10),

                        // Narrative box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
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
                              fontSize: 13.2,
                              height: 1.38,
                              color: palette.primaryText,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Carousel dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(slides.length, (i) {
                            final active = i == _index;
                            return AnimatedContainer(
                              key: ValueKey('temple_moral_choice_dot_$i'),
                              duration: widget.controller.animationsEnabled
                                  ? const Duration(milliseconds: 180)
                                  : Duration.zero,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: active ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: active
                                    ? borderColor
                                    : palette.mutedText.withValues(alpha: 0.35),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 10),

                        // Actions: either Next or the Two Interactive Moral Choices
                        if (!isLast)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              key: const ValueKey(
                                'temple_moral_choice_next_button',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _warmGold,
                                foregroundColor: const Color(0xFF10141D),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                widget.controller.audio.playTapVibrate();
                                setState(() => _index++);
                              },
                              child: Text(
                                loc.t('story_next', fallback: 'Next'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        else ...[
                          // Choice 2 (Primary Heroic Action): Refuse & Protect Her
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              key: const ValueKey(
                                'temple_choice_refuse_protect_button',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? _cyanDefy
                                    : const Color(0xFF00838F),
                                foregroundColor: isDark
                                    ? const Color(0xFF07141C)
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                widget.controller.audio.playTapVibrate();
                                Navigator.of(context).pop(
                                  TempleMoralChoice.refuseAndProtect,
                                );
                              },
                              icon: const Icon(Icons.shield_rounded, size: 18),
                              label: Text(
                                loc.t(
                                  'temple_choice_refuse_btn',
                                  fallback: 'Refuse & Protect Her',
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Choice 1: Sacrifice the Princess
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: const ValueKey(
                                'temple_choice_sacrifice_princess_button',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark
                                    ? const Color(0xFFFF8A80)
                                    : const Color(0xFFB71C1C),
                                side: BorderSide(
                                  color: _crimsonWarn.withValues(alpha: 0.72),
                                  width: 1.4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                widget.controller.audio.playTapVibrate();
                                Navigator.of(context).pop(
                                  TempleMoralChoice.sacrificePrincess,
                                );
                              },
                              icon: const Icon(
                                Icons.volunteer_activism_rounded,
                                size: 17,
                              ),
                              label: Text(
                                loc.t(
                                  'temple_choice_sacrifice_btn',
                                  fallback: 'Sacrifice the Princess',
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          if (!isFirst) ...[
                            const SizedBox(height: 2),
                            TextButton(
                              key: const ValueKey(
                                'temple_moral_choice_back_button',
                              ),
                              onPressed: () {
                                widget.controller.audio.playTapVibrate();
                                setState(() => _index--);
                              },
                              child: Text(
                                loc.t('story_prev', fallback: 'Back'),
                                style: TextStyle(color: palette.secondaryText),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
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
