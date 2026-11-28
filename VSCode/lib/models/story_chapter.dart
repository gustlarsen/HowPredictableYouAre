import 'package:flutter/material.dart';

class IntroStoryCardData {
  final int index;
  final String id;
  final String assetPath;
  final String chapterKey;
  final String fallbackChapter;
  final String titleKey;
  final String fallbackTitle;
  final String captionKey;
  final String fallbackCaption;
  final IconData icon;

  const IntroStoryCardData({
    required this.index,
    required this.id,
    required this.assetPath,
    required this.chapterKey,
    required this.fallbackChapter,
    required this.titleKey,
    required this.fallbackTitle,
    required this.captionKey,
    required this.fallbackCaption,
    required this.icon,
  });

  static const List<IntroStoryCardData> cards = [
    IntroStoryCardData(
      index: 0,
      id: 'intro_1',
      assetPath: 'assets/images/story/intro_1.jpeg',
      chapterKey: 'story_intro_c1_chapter',
      fallbackChapter: 'Chapter I',
      titleKey: 'story_intro_c1_title',
      fallbackTitle: 'The Royal Garden',
      captionKey: 'story_intro_c1_caption',
      fallbackCaption:
          "In the peaceful royal garden, the Princess gathered roses under the watchful protection of the realm's three guardian mages.",
      icon: Icons.local_florist_outlined,
    ),
    IntroStoryCardData(
      index: 1,
      id: 'intro_2',
      assetPath: 'assets/images/story/intro_2.jpeg',
      chapterKey: 'story_intro_c2_chapter',
      fallbackChapter: 'Chapter II',
      titleKey: 'story_intro_c2_title',
      fallbackTitle: 'Ambush in the Royal Garden',
      captionKey: 'story_intro_c2_caption',
      fallbackCaption:
          'Suddenly, a ruthless Robot Mage forged from dark metal ambushed the garden, unleashing arcane lightning against the guardians!',
      icon: Icons.bolt_outlined,
    ),
    IntroStoryCardData(
      index: 2,
      id: 'intro_3',
      assetPath: 'assets/images/story/intro_3.jpeg',
      chapterKey: 'story_intro_c3_chapter',
      fallbackChapter: 'Chapter III',
      titleKey: 'story_intro_c3_title',
      fallbackTitle: 'The Princess Captured',
      captionKey: 'story_intro_c3_caption',
      fallbackCaption:
          'With the three guardian mages fallen in battle, the Robot Mage seized the helpless Princess and carried her toward the dark fortress.',
      icon: Icons.warning_amber_rounded,
    ),
    IntroStoryCardData(
      index: 3,
      id: 'intro_4',
      assetPath: 'assets/images/story/intro_4.jpeg',
      chapterKey: 'story_intro_c4_chapter',
      fallbackChapter: 'Chapter IV',
      titleKey: 'story_intro_c4_title',
      fallbackTitle: "The King's Summons",
      captionKey: 'story_intro_c4_caption',
      fallbackCaption:
          'Desperate to save his daughter, the King hurried to the Sacred Temple and pleaded for aid, calling upon a young Cleric.',
      icon: Icons.castle_outlined,
    ),
    IntroStoryCardData(
      index: 4,
      id: 'intro_5',
      assetPath: 'assets/images/story/intro_5.jpeg',
      chapterKey: 'story_intro_c5_chapter',
      fallbackChapter: 'Chapter V',
      titleKey: 'story_intro_c5_title',
      fallbackTitle: 'The Quest Begins',
      captionKey: 'story_intro_c5_caption',
      fallbackCaption:
          "Armed with your blessed Staff, your adventure begins! Before marching into battle, check the Watch Tower to spy on the Princess's cell and see what the Metal Wizard is planning.",
      icon: Icons.explore_outlined,
    ),
  ];
}

enum StoryChapter {
  intro;

  String get id {
    switch (this) {
      case StoryChapter.intro:
        return 'intro';
    }
  }

  String get prefsKey {
    switch (this) {
      case StoryChapter.intro:
        return 'has_seen_story_intro';
    }
  }

  String get assetPath {
    switch (this) {
      case StoryChapter.intro:
        return 'assets/images/story/intro_3.jpeg';
    }
  }

  double get imageAspectRatio {
    switch (this) {
      case StoryChapter.intro:
        return 1024.0 / 571.0;
    }
  }

  IconData get icon {
    switch (this) {
      case StoryChapter.intro:
        return Icons.castle_outlined;
    }
  }

  String get titleKey => 'story_${id}_title';

  String get fallbackTitle {
    switch (this) {
      case StoryChapter.intro:
        return "Prologue: The Metal Wizard's Plot";
    }
  }

  String get itemNameKey {
    switch (this) {
      case StoryChapter.intro:
        return 'story_intro_summary';
    }
  }

  String get fallbackItemName {
    switch (this) {
      case StoryChapter.intro:
        return "Witness the Robot Mage's ambush in the Royal Garden, stand with the three guardian mages, and answer the King's summons at the Sacred Temple.";
    }
  }
}

