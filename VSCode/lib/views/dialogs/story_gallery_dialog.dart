import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/story_chapter.dart';
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
    final chapters = StoryChapter.values;
    final unlockedCount =
        chapters.where((c) => controller.isStoryChapterUnlocked(c)).length;

    final title = loc.t('story_gallery_title', fallback: 'Story Memories');
    final subtitle = loc.t(
      'story_gallery_subtitle',
      fallback: 'Re-read unlocked comic chapters & lore',
    );
    final lockedTitle = loc.t('story_locked_title', fallback: 'Locked Chapter');
    final lockedHint = loc.t(
      'story_locked_hint',
      fallback: 'Unlock this item in the Shop to reveal its story!',
    );
    final replayLabel = loc.t('story_replay', fallback: 'Read Comic');

    return Dialog(
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
                        const Icon(
                          Icons.auto_stories_outlined,
                          color: Colors.amber,
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
                                ),
                              ),
                              Text(
                                subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
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
                      color: Colors.amber.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '$unlockedCount / ${chapters.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Chapters List
              Expanded(
                child: ListView.separated(
                  itemCount: chapters.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    final isUnlocked =
                        controller.isStoryChapterUnlocked(chapter);
                    final chapterTitle = loc.t(
                      chapter.titleKey,
                      fallback: chapter.fallbackTitle,
                    );
                    final itemName = loc.t(
                      chapter.itemNameKey,
                      fallback: chapter.fallbackItemName,
                    );

                    return _StoryChapterCard(
                      key: ValueKey(
                        isUnlocked
                            ? 'story_gallery_item_${chapter.id}'
                            : 'story_gallery_locked_${chapter.id}',
                      ),
                      chapter: chapter,
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
                ),
              ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
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

class _StoryChapterCard extends StatelessWidget {
  final StoryChapter chapter;
  final int chapterNumber;
  final bool isUnlocked;
  final String chapterTitle;
  final String subtitle;
  final String replayLabel;
  final VoidCallback onTap;

  const _StoryChapterCard({
    super.key,
    required this.chapter,
    required this.chapterNumber,
    required this.isUnlocked,
    required this.chapterTitle,
    required this.subtitle,
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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: isUnlocked ? 0.45 : 0.22,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? Colors.amber.withValues(alpha: 0.45)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
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
                            ? Colors.amber.withValues(alpha: 0.2)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$chapterNumber',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? Colors.amber : Colors.white54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isUnlocked ? chapter.icon : Icons.help_outline,
                      size: 15,
                      color: isUnlocked ? Colors.amber : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        chapterTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: isUnlocked
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.55,
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
                        ? Colors.amber.shade300
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.65,
                          ),
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
                      key: ValueKey('story_gallery_thumb_${chapter.id}'),
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
                                chapter.assetPath,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: const Color(0xFF1A1D26),
                                  child: Icon(
                                    chapter.icon,
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

                    // Action Icon / Button
                    if (isUnlocked)
                      Container(
                        key: ValueKey('story_gallery_read_btn_${chapter.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.menu_book_rounded,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              replayLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        key: ValueKey('story_gallery_lock_icon_${chapter.id}'),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.grey,
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

