import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/watch_tower_icon.dart';
import 'help_dialog.dart';
import 'story_gallery_dialog.dart';
import 'watchtower_spyglass_dialog.dart';
import 'world_map_war_dialog.dart';

/// Watch Tower landmark dialog: displays Star-Gazer strategy hints,
/// Markov Chain insights, and direct access to the Story Log & Help.
class ObservatoryDialog extends StatelessWidget {
  final GameController controller;

  const ObservatoryDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final loc = controller.localization;
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final unlockedStories = controller.unlockedStoryMemoriesCount;
    final totalStories = controller.totalStoryMemoriesCount;

    return Dialog(
      key: const ValueKey('observatory_dialog'),
      backgroundColor: palette.isDark ? null : palette.dialogSurface,
      surfaceTintColor: palette.isDark ? null : Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: palette.blueAccent.withValues(
                        alpha: palette.isDark ? 0.18 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.blueAccent.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const WatchTowerIcon(size: 26),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.t(
                            'observatory_title',
                            fallback: 'Watch Tower',
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: palette.primaryText,
                          ),
                        ),
                        Text(
                          loc.t(
                            'observatory_subtitle',
                            fallback:
                                'Strategy Hints, Markov Insight & Story Log',
                          ),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: palette.amberSubtitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Divider(
                height: 18,
                color: palette.isDark ? null : palette.divider,
              ),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Strategy Hints Card
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: palette.rewardedAdCardSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: palette.isDark
                                ? Colors.amber.withValues(alpha: 0.35)
                                : palette.rewardedAdCardBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.tips_and_updates_outlined,
                                  color: palette.amberIcon,
                                  size: 17,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    loc.t(
                                      'observatory_strategy_title',
                                      fallback: "Star-Gazer's Strategy Hints",
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: palette.amberText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              loc.t(
                                'observatory_strategy_body',
                                fallback:
                                    'Master Hand records every transition from your previous move to your next. Break streaks, vary your follow-ups, and study the live matrix to keep your predictability below 50%!',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: palette.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Markov Insight Card
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: palette.dialogCardSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: palette.blueAccent.withValues(
                              alpha: palette.isDark ? 0.35 : 0.45,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.grid_on_rounded,
                                  color: palette.blueAccent,
                                  size: 17,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    loc.t(
                                      'observatory_markov_title',
                                      fallback: 'Markov Insight',
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: palette.blueAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              loc.t(
                                'observatory_markov_body',
                                fallback:
                                    'A 1st-order Markov Chain builds a transition table T[last][next]. Whenever a row has a dominant choice, the AI plays its counter-element. Unlock Show Algorithm in the Sacred Temple to inspect it live!',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: palette.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Spy on Dungeon Button (RPG dark/cyan/gold theme)
                      ElevatedButton.icon(
                        key: const ValueKey('observatory_spy_dungeon_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.isDark
                              ? const Color(0xFF102432)
                              : const Color(0xFF173142),
                          foregroundColor: const Color(0xFFFFE082),
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 14,
                          ),
                          side: BorderSide(
                            color: const Color(0xFF00E5FF).withValues(
                              alpha: palette.isDark ? 0.65 : 0.78,
                            ),
                            width: 1.3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          controller.audio.playTapVibrate();
                          showDialog(
                            context: context,
                            builder: (_) =>
                                WatchtowerSpyglassDialog(controller: controller),
                          );
                        },
                        icon: const WatchTowerIcon(size: 20),
                        label: Text(
                          loc.t(
                            'observatory_spy_dungeon_btn',
                            fallback: 'Spy on Dungeon',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFE082),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // World Map Button (RPG dark slate / parchment & gold theme)
                      ElevatedButton.icon(
                        key: const ValueKey('observatory_world_map_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.isDark
                              ? const Color(0xFF1F2430)
                              : const Color(0xFFEBE1CD),
                          foregroundColor: palette.isDark
                              ? const Color(0xFFF5C22B)
                              : const Color(0xFF5A3E00),
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 14,
                          ),
                          side: BorderSide(
                            color: const Color(0xFFF5C22B).withValues(
                              alpha: palette.isDark ? 0.72 : 0.85,
                            ),
                            width: 1.3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          controller.audio.playTapVibrate();
                          showDialog(
                            context: context,
                            builder: (_) =>
                                WorldMapWarDialog(controller: controller),
                          );
                        },
                        icon: Icon(
                          Icons.map_rounded,
                          size: 19,
                          color: palette.isDark
                              ? const Color(0xFFF5C22B)
                              : const Color(0xFF7A4E00),
                        ),
                        label: Text(
                          loc.t(
                            'observatory_world_map_btn',
                            fallback: 'World Map',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: palette.isDark
                                ? const Color(0xFFF5C22B)
                                : const Color(0xFF5A3E00),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Story Log Button
                      ElevatedButton.icon(
                        key: const ValueKey('observatory_story_log_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: const Color(0xFF231F1A),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          controller.audio.playTapVibrate();
                          showDialog(
                            context: context,
                            builder: (_) =>
                                StoryGalleryDialog(controller: controller),
                          );
                        },
                        icon: const Icon(Icons.auto_stories_outlined, size: 18),
                        label: Text(
                          '${loc.t('observatory_story_log_btn', fallback: 'Open Story Log')} ($unlockedStories/$totalStories)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // How It Works Button
                      OutlinedButton.icon(
                        key: const ValueKey('observatory_help_button'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.blueAccent,
                          side: BorderSide(
                            color: palette.blueAccent.withValues(alpha: 0.55),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 9,
                            horizontal: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          controller.audio.playTapVibrate();
                          showDialog(
                            context: context,
                            builder: (_) =>
                                HelpDialog(localization: loc),
                          );
                        },
                        icon: const Icon(Icons.help_outline, size: 18),
                        label: Text(
                          loc.t('string35', fallback: 'Help'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('observatory_close_button'),
                  style: palette.isDark
                      ? null
                      : TextButton.styleFrom(foregroundColor: palette.amberText),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(loc.t('string36', fallback: 'Ok')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
