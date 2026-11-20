import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../theme/app_theme.dart';

enum VictoryCutsceneType {
  secretWeek1,
  standardVictory,
}

class _VictoryPanelData {
  final IconData icon;
  final Color accentColor;
  final String speakerKey;
  final String fallbackSpeaker;
  final String titleKey;
  final String fallbackTitle;
  final String bodyKey;
  final String fallbackBody;

  const _VictoryPanelData({
    required this.icon,
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
            fallbackTitle: 'A Week-One Miracle!',
            bodyKey: 'secret_cutscene_p1_body',
            fallbackBody:
                'On the very first week of the siege, your decisive counters shatter the Guardian Robot before the Metal Wizard can forge a single backup construct!',
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
                'With the citadel vault unsealed, you rescue the Princess completely unharmed. The Metal Wizard flees into the mist before his dark foundry can even awaken.',
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
                'Peace returns in record time! The Secret Week-1 Ending has been inscribed in the Royal Library as you prepare for the next cycle.',
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
                'Despite its chaotic 400 HP shield and unpredictable pure random attacks, the Baby Mage Robot overloads and collapses in a shower of elemental sparks!',
          ),
          _VictoryPanelData(
            icon: Icons.fort_rounded,
            accentColor: Color(0xFFFFCA28),
            speakerKey: 'victory_cutscene_princess',
            fallbackSpeaker: 'Princess Aria',
            titleKey: 'standard_cutscene_p2_title',
            fallbackTitle: "Metal Wizard's Lair Defeated",
            bodyKey: 'standard_cutscene_p2_body',
            fallbackBody:
                'The dark citadel\'s Markov engines power down forever. Free from the tower, the Princess thanks you for outlasting and conquering every construct in your path.',
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
                'The kingdom celebrates your triumph! The Standard Victory Ending is recorded in the Royal Library as a new cycle dawns.',
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

    final cutsceneBanner = widget.type == VictoryCutsceneType.secretWeek1
        ? loc.t('secret_cutscene_header', fallback: 'SECRET WEEK-1 VICTORY')
        : loc.t('standard_cutscene_header', fallback: 'CAMPAIGN VICTORY');

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
                          Container(
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
                                color: panel.accentColor.withValues(alpha: 0.65),
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
                          const Spacer(),
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

                      // Illustrated Emblem Panel
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 26,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: palette.isDark
                                ? [
                                    panel.accentColor.withValues(alpha: 0.24),
                                    const Color(0xFF151A24),
                                  ]
                                : [
                                    panel.accentColor.withValues(alpha: 0.18),
                                    palette.sandCardSurface,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: panel.accentColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: panel.accentColor.withValues(
                                  alpha: palette.isDark ? 0.22 : 0.18,
                                ),
                                border: Border.all(
                                  color: panel.accentColor,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
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
