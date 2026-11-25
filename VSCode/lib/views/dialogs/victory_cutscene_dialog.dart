import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/metal_wizard_lair_icon.dart';
import '../widgets/sacred_temple_icon.dart';

enum VictoryCutsceneType {
  secretWeek1,
  standardVictory,
  sacredSacrifice,
  theDeserter,
  templeSiegeVictory,
  templeSiegeDeserter,
}

class _VictoryPanelData {
  final IconData icon;
  final Widget? iconWidget;
  final Color accentColor;
  final String speakerKey;
  final String fallbackSpeaker;
  final String titleKey;
  final String fallbackTitle;
  final String bodyKey;
  final String fallbackBody;

  const _VictoryPanelData({
    required this.icon,
    this.iconWidget,
    required this.accentColor,
    required this.speakerKey,
    required this.fallbackSpeaker,
    required this.titleKey,
    required this.fallbackTitle,
    required this.bodyKey,
    required this.fallbackBody,
  });
}

class VictoryCutsceneDialog extends StatefulWidget {
  final VictoryCutsceneType type;
  final GameController controller;

  const VictoryCutsceneDialog({
    super.key,
    required this.type,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required VictoryCutsceneType type,
    required GameController controller,
  }) {
    controller.audio.playStoryChime();
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Victory Cutscene',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: controller.animationsEnabled
          ? const Duration(milliseconds: 300)
          : Duration.zero,
      pageBuilder: (ctx, anim1, anim2) => VictoryCutsceneDialog(
        type: type,
        controller: controller,
      ),
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
  State<VictoryCutsceneDialog> createState() => _VictoryCutsceneDialogState();
}

class _VictoryCutsceneDialogState extends State<VictoryCutsceneDialog> {
  int _index = 0;

  List<_VictoryPanelData> get _panels {
    switch (widget.type) {
      case VictoryCutsceneType.secretWeek1:
        return const [
          _VictoryPanelData(
            icon: Icons.flash_on_rounded,
            accentColor: Color(0xFF00E5FF),
            speakerKey: 'victory_cutscene_narrator',
            fallbackSpeaker: 'Royal Chronicler',
            titleKey: 'secret_cutscene_p1_title',
            fallbackTitle: 'A Week-Zero Miracle!',
            bodyKey: 'secret_cutscene_p1_body',
            fallbackBody:
                'On Week 0, at the very dawn of the siege, your decisive counters shatter the Guardian Robot and defeat the Metal Wizard himself before the Archmage or Baby Mage Robot could ever be created!',
          ),
          _VictoryPanelData(
            icon: Icons.favorite_rounded,
            accentColor: Color(0xFFFFD54F),
            speakerKey: 'victory_cutscene_princess',
            fallbackSpeaker: 'Princess Aria',
            titleKey: 'secret_cutscene_p2_title',
            fallbackTitle: 'Rescued Intact',
            bodyKey: 'secret_cutscene_p2_body',
            fallbackBody:
                'With the citadel vault unsealed in Week 0, you rescue the Princess completely untouched before the dark foundry\'s contingencies can awaken.',
          ),
          _VictoryPanelData(
            icon: Icons.emoji_events_rounded,
            accentColor: Color(0xFF69F0AE),
            speakerKey: 'victory_cutscene_king',
            fallbackSpeaker: 'King Aldric',
            titleKey: 'secret_cutscene_p3_title',
            fallbackTitle: 'Secret Ending Unlocked',
            bodyKey: 'secret_cutscene_p3_body',
            fallbackBody:
                'Peace returns in record time! The Flawless Rescue (Secret Ending) has been inscribed in the Royal Library as you prepare for the next cycle.',
          ),
        ];
      case VictoryCutsceneType.standardVictory:
        return const [
          _VictoryPanelData(
            icon: Icons.auto_awesome_rounded,
            accentColor: Color(0xFFFF7043),
            speakerKey: 'victory_cutscene_narrator',
            fallbackSpeaker: 'Royal Chronicler',
            titleKey: 'standard_cutscene_p1_title',
            fallbackTitle: 'The Final Construct Falls!',
            bodyKey: 'standard_cutscene_p1_body',
            fallbackBody:
                'Inside the Sacred Temple, you decode the Baby Mage Robot\'s irrational π core and shatter its dual harmonic elemental spells across 400 HP!',
          ),
          _VictoryPanelData(
            icon: Icons.fort_rounded,
            iconWidget: MetalWizardLairIcon(size: 42),
            accentColor: Color(0xFFFFCA28),
            speakerKey: 'victory_cutscene_princess',
            fallbackSpeaker: 'Princess Aria',
            titleKey: 'standard_cutscene_p2_title',
            fallbackTitle: "Metal Wizard's Lair Defeated",
            bodyKey: 'standard_cutscene_p2_body',
            fallbackBody:
                'Purged of the mechanical anomaly and protected from sacrifice, Princess Aria awakens unharmed beside the Sacred Altar as the Temple High Master bows in awe.',
          ),
          _VictoryPanelData(
            icon: Icons.military_tech_rounded,
            accentColor: Color(0xFF4FC3F7),
            speakerKey: 'victory_cutscene_king',
            fallbackSpeaker: 'King Aldric',
            titleKey: 'standard_cutscene_p3_title',
            fallbackTitle: 'Champion of the Realm',
            bodyKey: 'standard_cutscene_p3_body',
            fallbackBody:
                'The kingdom celebrates your triumph! Sanctuary Victory (Standard Ending) is recorded in the Royal Library as a new cycle dawns.',
          ),
        ];
      case VictoryCutsceneType.sacredSacrifice:
        return const [
          _VictoryPanelData(
            icon: Icons.volunteer_activism_rounded,
            iconWidget: SacredTempleIcon(size: 42),
            accentColor: Color(0xFFFFB74D),
            speakerKey: 'temple_master_speaker',
            fallbackSpeaker: 'Temple High Master',
            titleKey: 'sacrifice_cutscene_p1_title',
            fallbackTitle: 'The Altar of Containment',
            bodyKey: 'sacrifice_cutscene_p1_body',
            fallbackBody:
                'Beneath the rose window of the Sacred Temple, the Temple High Master completes the ancient rite, sealing the dark mechanical anomaly—and the Princess\'s life—into the sanctum stone.',
          ),
          _VictoryPanelData(
            icon: Icons.shield_rounded,
            accentColor: Color(0xFFFFCA28),
            speakerKey: 'victory_cutscene_narrator',
            fallbackSpeaker: 'Royal Chronicler',
            titleKey: 'sacrifice_cutscene_p2_title',
            fallbackTitle: 'A Kingdom Saved in Sorrow',
            bodyKey: 'sacrifice_cutscene_p2_body',
            fallbackBody:
                'The Baby Mage Robot never awakens. Though the realm is spared from mechanical devastation, the bells of the capital toll in mourning for Princess Aria.',
          ),
          _VictoryPanelData(
            icon: Icons.menu_book_rounded,
            accentColor: Color(0xFFFF8A65),
            speakerKey: 'victory_cutscene_king',
            fallbackSpeaker: 'King Aldric',
            titleKey: 'sacrifice_cutscene_p3_title',
            fallbackTitle: 'Ending: The Sacred Sacrifice',
            bodyKey: 'sacrifice_cutscene_p3_body',
            fallbackBody:
                'The Sacred Sacrifice has been inscribed in the Royal Library. Time rewinds to Week 0 so you may seek a brighter fate.',
          ),
        ];
      case VictoryCutsceneType.theDeserter:
        return const [
          _VictoryPanelData(
            icon: Icons.directions_run_rounded,
            accentColor: Color(0xFFBA68C8),
            speakerKey: 'victory_cutscene_narrator',
            fallbackSpeaker: 'Royal Chronicler',
            titleKey: 'deserter_cutscene_p1_title',
            fallbackTitle: 'Flight from the Sanctuary',
            bodyKey: 'deserter_cutscene_p1_body',
            fallbackBody:
                'Overwhelmed by the Baby Mage Robot\'s dual harmonic spells, you step through the arcane portal and abandon the Sacred Temple.',
          ),
          _VictoryPanelData(
            icon: Icons.whatshot_rounded,
            accentColor: Color(0xFFEF5350),
            speakerKey: 'victory_cutscene_narrator',
            fallbackSpeaker: 'Royal Chronicler',
            titleKey: 'deserter_cutscene_p2_title',
            fallbackTitle: 'The Capital Falls',
            bodyKey: 'deserter_cutscene_p2_body',
            fallbackBody:
                'With no Cleric left to stand in its way, the awakened Baby Mage Robot bursts from the Temple gates and reduces the Royal Capital to ashes while you flee into exile.',
          ),
          _VictoryPanelData(
            icon: Icons.history_edu_rounded,
            accentColor: Color(0xFFAB47BC),
            speakerKey: 'victory_cutscene_narrator',
            fallbackSpeaker: 'Royal Chronicler',
            titleKey: 'deserter_cutscene_p3_title',
            fallbackTitle: 'Ending: The Deserter',
            bodyKey: 'deserter_cutscene_p3_body',
            fallbackBody:
                'The Deserter ending has been recorded in the Royal Library. The chronicle resets to Week 0 for another chance at redemption.',
          ),
        ];
      case VictoryCutsceneType.templeSiegeVictory:
        return const [
          _VictoryPanelData(
            icon: Icons.shield_rounded,
            iconWidget: SacredTempleIcon(size: 42),
            accentColor: Color(0xFFFFCA28),
            speakerKey: 'victory_cutscene_narrator',
            fallbackSpeaker: 'Royal Chronicler',
            titleKey: 'siege_victory_cutscene_p1_title',
            fallbackTitle: 'The Siege Is Broken!',
            bodyKey: 'siege_victory_cutscene_p1_body',
            fallbackBody:
                'Inside the Sacred Temple, your last stand shatters the Metal Wizard and his invading army at the very gates of the sanctuary!',
          ),
          _VictoryPanelData(
            icon: Icons.favorite_rounded,
            accentColor: Color(0xFF69F0AE),
            speakerKey: 'victory_cutscene_princess',
            fallbackSpeaker: 'Princess Aria',
            titleKey: 'siege_victory_cutscene_p2_title',
            fallbackTitle: 'City & Princess Saved',
            bodyKey: 'siege_victory_cutscene_p2_body',
            fallbackBody:
                'With the Metal Wizard defeated and his troop routed, the Sacred City endures and Princess Aria is freed without harm.',
          ),
          _VictoryPanelData(
            icon: Icons.emoji_events_rounded,
            accentColor: Color(0xFF4FC3F7),
            speakerKey: 'victory_cutscene_king',
            fallbackSpeaker: 'King Aldric',
            titleKey: 'siege_victory_cutscene_p3_title',
            fallbackTitle: 'Savior of the Realm',
            bodyKey: 'siege_victory_cutscene_p3_body',
            fallbackBody:
                'Your heroic defense of the Sacred Temple is inscribed in the Royal Library as the Victory Ending, and a new cycle begins at Week 0.',
          ),
        ];
      case VictoryCutsceneType.templeSiegeDeserter:
        return const [
          _VictoryPanelData(
            icon: Icons.directions_run_rounded,
            accentColor: Color(0xFFBA68C8),
            speakerKey: 'victory_cutscene_narrator',
            fallbackSpeaker: 'Royal Chronicler',
            titleKey: 'siege_deserter_cutscene_p1_title',
            fallbackTitle: 'Cowardly Escape',
            bodyKey: 'siege_deserter_cutscene_p1_body',
            fallbackBody:
                'When the city needed you most, you fled through an arcane portal from the Sacred Temple—sparing your own life in cowardice.',
          ),
          _VictoryPanelData(
            icon: Icons.whatshot_rounded,
            accentColor: Color(0xFFEF5350),
            speakerKey: 'victory_cutscene_narrator',
            fallbackSpeaker: 'Royal Chronicler',
            titleKey: 'siege_deserter_cutscene_p2_title',
            fallbackTitle: 'The City Is Destroyed',
            bodyKey: 'siege_deserter_cutscene_p2_body',
            fallbackBody:
                'With no defender left in the sanctuary, the Metal Wizard and his troop storm the Sacred Temple and burn the city to ashes.',
          ),
          _VictoryPanelData(
            icon: Icons.history_edu_rounded,
            accentColor: Color(0xFFAB47BC),
            speakerKey: 'victory_cutscene_narrator',
            fallbackSpeaker: 'Royal Chronicler',
            titleKey: 'siege_deserter_cutscene_p3_title',
            fallbackTitle: 'Ending: The Deserter',
            bodyKey: 'siege_deserter_cutscene_p3_body',
            fallbackBody:
                'Your shameful flight is recorded in the Royal Library as The Deserter ending. Time rewinds to Week 0 for a chance at redemption.',
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.controller.localization;
    final palette = AppPalette.of(context);
    final panels = _panels;
    final panel = panels[_index];
    final isFirst = _index == 0;
    final isLast = _index == panels.length - 1;

    final String cutsceneBanner;
    switch (widget.type) {
      case VictoryCutsceneType.secretWeek1:
        cutsceneBanner = loc.t(
          'secret_cutscene_header',
          fallback: 'SECRET WEEK-0 VICTORY',
        );
        break;
      case VictoryCutsceneType.standardVictory:
        cutsceneBanner = loc.t(
          'standard_cutscene_header',
          fallback: 'CAMPAIGN VICTORY',
        );
        break;
      case VictoryCutsceneType.sacredSacrifice:
        cutsceneBanner = loc.t(
          'sacrifice_cutscene_header',
          fallback: 'THE SACRED SACRIFICE',
        );
        break;
      case VictoryCutsceneType.theDeserter:
      case VictoryCutsceneType.templeSiegeDeserter:
        cutsceneBanner = loc.t(
          'deserter_cutscene_header',
          fallback: 'THE DESERTER',
        );
        break;
      case VictoryCutsceneType.templeSiegeVictory:
        cutsceneBanner = loc.t(
          'siege_victory_cutscene_header',
          fallback: 'TEMPLE SIEGE VICTORY',
        );
        break;
    }

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Material(
              key: const ValueKey('victory_cutscene_dialog'),
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: palette.dialogSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: panel.accentColor.withValues(alpha: 0.75),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: panel.accentColor.withValues(alpha: 0.22),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header badge + skip button
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: panel.accentColor.withValues(
                                      alpha: palette.isDark ? 0.18 : 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: panel.accentColor.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    cutsceneBanner,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                      color: palette.isDark
                                          ? panel.accentColor
                                          : palette.primaryText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            key: const ValueKey('victory_cutscene_skip_button'),
                            onPressed: () {
                              widget.controller.audio.playTapVibrate();
                              Navigator.of(context).pop();
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
                      const SizedBox(height: 12),

                      // Illustrated Emblem Panel with 9:16 Robot Mage Cliff Cutscene Backdrop
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: panel.accentColor.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/images/story/robot_mage_cliff.webp',
                                  key: const ValueKey('victory_cutscene_bg_image'),
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
                                      colors: palette.isDark
                                          ? [
                                              panel.accentColor.withValues(
                                                alpha: 0.22,
                                              ),
                                              const Color(0xFF151A24).withValues(
                                                alpha: 0.72,
                                              ),
                                            ]
                                          : [
                                              panel.accentColor.withValues(
                                                alpha: 0.18,
                                              ),
                                              palette.sandCardSurface.withValues(
                                                alpha: 0.78,
                                              ),
                                            ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 26,
                                  horizontal: 16,
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: palette.isDark
                                            ? const Color(0xFF151A24).withValues(
                                                alpha: 0.72,
                                              )
                                            : palette.dialogSurface.withValues(
                                                alpha: 0.85,
                                              ),
                                        border: Border.all(
                                          color: panel.accentColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: panel.iconWidget ??
                                          Icon(
                                            panel.icon,
                                            size: 42,
                                            color: panel.accentColor,
                                          ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      loc.t(
                                        panel.speakerKey,
                                        fallback: panel.fallbackSpeaker,
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.9,
                                        color: palette.amberText,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      loc.t(
                                        panel.titleKey,
                                        fallback: panel.fallbackTitle,
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

                      // Narrative text box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: palette.dialogCardSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: palette.amberBorder.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          loc.t(panel.bodyKey, fallback: panel.fallbackBody),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: palette.primaryText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Pagination dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(panels.length, (i) {
                          final active = i == _index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: active
                                  ? panel.accentColor
                                  : palette.mutedText.withValues(alpha: 0.35),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Action row
                      Row(
                        children: [
                          if (!isFirst)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  widget.controller.audio.playTapVibrate();
                                  setState(() => _index--);
                                },
                                child: Text(
                                  loc.t('story_prev', fallback: 'Back'),
                                ),
                              ),
                            ),
                          if (!isFirst) const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              key: ValueKey(
                                isLast
                                    ? 'victory_cutscene_finish_button'
                                    : 'victory_cutscene_next_button',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: panel.accentColor,
                                foregroundColor: const Color(0xFF10141D),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                widget.controller.audio.playTapVibrate();
                                if (isLast) {
                                  Navigator.of(context).pop();
                                } else {
                                  setState(() => _index++);
                                }
                              },
                              child: Text(
                                isLast
                                    ? loc.t(
                                        'victory_return_kingdom',
                                        fallback: 'Return to Kingdom',
                                      )
                                    : loc.t('story_next', fallback: 'Next'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
