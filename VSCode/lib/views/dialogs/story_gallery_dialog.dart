import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/story_chapter.dart';
import '../../theme/app_theme.dart';
import '../screens/intro_story_screen.dart';
import 'story_dialog.dart';

class StoryGalleryDialog extends StatelessWidget {
  final GameController controller;

  const StoryGalleryDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final loc = controller.localization;
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final totalCount = controller.totalStoryMemoriesCount;
    final unlockedCount = controller.unlockedStoryMemoriesCount;

    final title = loc.t('story_gallery_title', fallback: 'Story Memories');
    final subtitle = loc.t(
      'story_gallery_subtitle',
      fallback: 'Re-read unlocked comic chapters & lore',
    );

    return Dialog(
      backgroundColor: palette.isDark ? null : palette.dialogSurface,
      surfaceTintColor: palette.isDark ? null : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_stories_outlined,
                          color: palette.amberIcon,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: palette.primaryText,
                                ),
                              ),
                              Text(
                                subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: palette.isDark
                                      ? theme.colorScheme.onSurfaceVariant
                                      : palette.secondaryText,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: palette.isDark
                          ? Colors.amber.withValues(alpha: 0.16)
                          : palette.rewardedAdCardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.isDark
                            ? Colors.amber.withValues(alpha: 0.4)
                            : palette.rewardedAdCardBorder,
                      ),
                    ),
                    child: Text(
                      '$unlockedCount / $totalCount',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: palette.amberText,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(
                height: 24,
                color: palette.isDark ? null : palette.divider,
              ),

              // Chapters List
              Expanded(
                child: StoryMemoriesSection(controller: controller),
              ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: palette.isDark
                      ? null
                      : TextButton.styleFrom(
                          foregroundColor: palette.amberText,
                        ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(loc.t('string36', fallback: 'Close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable Story Memories comic chapter gallery list used by both
/// [StoryGalleryDialog] and the Royal Castle Hub's Library wing.
class StoryMemoriesSection extends StatelessWidget {
  final GameController controller;
  final bool shrinkWrap;

  const StoryMemoriesSection({
    super.key,
    required this.controller,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final loc = controller.localization;
    final artifactChapters = controller.artifactStoryChapters;
    final totalItems = 1 + artifactChapters.length;

    final lockedTitle = loc.t('story_locked_title', fallback: 'Locked Chapter');
    final lockedHint = loc.t(
      'story_locked_hint',
      fallback: 'Unlock this item in the Shop to reveal its story!',
    );
    final replayLabel = loc.t('story_replay', fallback: 'Read Comic');
    final introBadgeLabel = loc.t(
      'story_intro_pages_badge',
      fallback: '4 Scenes',
    );

    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: totalItems,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          const introChapter = StoryChapter.intro;
          final introTitle = loc.t(
            introChapter.titleKey,
            fallback: introChapter.fallbackTitle,
          );
          final introSummary = loc.t(
            introChapter.itemNameKey,
            fallback: introChapter.fallbackItemName,
          );

          return StoryChapterCard(
            key: ValueKey('story_gallery_item_${introChapter.id}'),
            memoryId: introChapter.id,
            assetPath: introChapter.assetPath,
            icon: introChapter.icon,
            chapterNumber: 1,
            isUnlocked: true,
            chapterTitle: introTitle,
            subtitle: introSummary,
            badgeLabel: introBadgeLabel,
            replayLabel: replayLabel,
            onTap: () {
              controller.audio.playTapVibrate();
              IntroStoryScreen.showReplay(context);
            },
          );
        }

        final chapter = artifactChapters[index - 1];
        final isUnlocked = controller.isStoryChapterUnlocked(chapter);
        final chapterTitle = loc.t(
          chapter.titleKey,
          fallback: chapter.fallbackTitle,
        );
        final itemName = loc.t(
          chapter.itemNameKey,
          fallback: chapter.fallbackItemName,
        );

        return StoryChapterCard(
          key: ValueKey(
            isUnlocked
                ? 'story_gallery_item_${chapter.id}'
                : 'story_gallery_locked_${chapter.id}',
          ),
          memoryId: chapter.id,
          assetPath: chapter.assetPath,
          icon: chapter.icon,
          chapterNumber: index + 1,
          isUnlocked: isUnlocked,
          chapterTitle: isUnlocked ? chapterTitle : lockedTitle,
          subtitle: isUnlocked ? itemName : '$itemName • $lockedHint',
          replayLabel: replayLabel,
          onTap: () {
            controller.audio.playTapVibrate();
            if (isUnlocked) {
              StoryDialog.show(
                context,
                chapter: chapter,
                controller: controller,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$itemName: $lockedHint'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        );
      },
    );
  }
}

class StoryChapterCard extends StatelessWidget {
  final String memoryId;
  final String assetPath;
  final IconData icon;
  final int chapterNumber;
  final bool isUnlocked;
  final String chapterTitle;
  final String subtitle;
  final String? badgeLabel;
  final String replayLabel;
  final VoidCallback onTap;

  const StoryChapterCard({
    super.key,
    required this.memoryId,
    required this.assetPath,
    required this.icon,
    required this.chapterNumber,
    required this.isUnlocked,
    required this.chapterTitle,
    required this.subtitle,
    this.badgeLabel,
    required this.replayLabel,
    required this.onTap,
  });

  // Mysterious dark silhouette color matrix for locked chapters
  static const ColorFilter _silhouetteFilter = ColorFilter.matrix(<double>[
    0.08, 0.08, 0.08, 0, 0,
    0.08, 0.08, 0.08, 0, 0,
    0.12, 0.12, 0.16, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: isUnlocked ? 0.45 : 0.22,
              )
            : (isUnlocked
                  ? palette.dialogCardSurface
                  : palette.sandCardSurface.withValues(alpha: 0.72)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? palette.amberBorder.withValues(
                  alpha: palette.isDark ? 0.45 : 0.65,
                )
              : (palette.isDark
                    ? theme.colorScheme.outline.withValues(alpha: 0.2)
                    : palette.sandCardBorder),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chapter Details above the thumbnail and read button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? (palette.isDark
                                  ? Colors.amber.withValues(alpha: 0.2)
                                  : palette.rewardedAdCardSurface)
                            : (palette.isDark
                                  ? Colors.white10
                                  : palette.sandCardSurface),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$chapterNumber',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked
                              ? palette.amberText
                              : (palette.isDark
                                    ? Colors.white54
                                    : palette.secondaryText),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isUnlocked ? icon : Icons.help_outline,
                      size: 15,
                      color: isUnlocked ? palette.amberIcon : palette.mutedText,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        chapterTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: isUnlocked
                              ? palette.primaryText
                              : palette.primaryText.withValues(
                                  alpha: palette.isDark ? 0.55 : 0.65,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isUnlocked
                        ? (palette.isDark
                              ? Colors.amber.shade300
                              : palette.amberSubtitle)
                        : (palette.isDark
                              ? theme.colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.65,
                                )
                              : palette.secondaryText),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),

                // Thumbnail and Read Button in the same line
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Thumbnail or Mysterious Silhouette
                    ClipRRect(
                      key: ValueKey('story_gallery_thumb_$memoryId'),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 64,
                        height: 76,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColorFiltered(
                              colorFilter: isUnlocked
                                  ? const ColorFilter.mode(
                                      Colors.transparent,
                                      BlendMode.dst,
                                    )
                                  : _silhouetteFilter,
                              child: Image.asset(
                                assetPath,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: const Color(0xFF1A1D26),
                                  child: Icon(
                                    icon,
                                    color: isUnlocked
                                        ? Colors.amber
                                        : Colors.white24,
                                  ),
                                ),
                              ),
                            ),
                            if (!isUnlocked)
                              Container(
                                color: Colors.black.withValues(alpha: 0.55),
                                child: const Center(
                                  child: Icon(
                                    Icons.lock_outline_rounded,
                                    color: Colors.white54,
                                    size: 26,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Optional sequence badge + Action Icon / Button
                    if (isUnlocked)
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (badgeLabel != null) ...[
                              Flexible(
                                child: Container(
                                  key: ValueKey('story_gallery_badge_$memoryId'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.isDark
                                        ? Colors.amber.withValues(alpha: 0.12)
                                        : palette.sandCardSurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: palette.amberBorder.withValues(
                                        alpha: palette.isDark ? 0.40 : 0.65,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_stories_outlined,
                                        size: 13,
                                        color: palette.amberText,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          badgeLabel!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: palette.amberText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              key: ValueKey('story_gallery_read_btn_$memoryId'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: palette.isDark
                                    ? Colors.amber.withValues(alpha: 0.16)
                                    : palette.rewardedAdCardSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: palette.isDark
                                    ? null
                                    : Border.all(
                                        color: palette.rewardedAdCardBorder
                                            .withValues(alpha: 0.65),
                                      ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.menu_book_rounded,
                                    size: 16,
                                    color: palette.amberText,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    replayLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: palette.amberText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        key: ValueKey('story_gallery_lock_icon_$memoryId'),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.lock_rounded,
                          color: palette.mutedText,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

