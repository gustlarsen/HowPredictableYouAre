import 'package:flutter/material.dart';

class StoryPanelData {
  final int index;
  final String speakerKey;
  final String fallbackSpeaker;
  final String textKey;
  final String fallbackText;
  final Alignment bubbleAlignment;
  final bool tailOnLeft;

  const StoryPanelData({
    required this.index,
    required this.speakerKey,
    required this.fallbackSpeaker,
    required this.textKey,
    required this.fallbackText,
    this.bubbleAlignment = Alignment.bottomCenter,
    this.tailOnLeft = true,
  });
}

enum StoryChapter {
  intro,
  resetButton,
  predictabilityScore,
  randomButton,
  showAlgorithm,
  yourPrediction,
  pcNextMove,
  suggestion,
  crystalBall;

  String get id {
    switch (this) {
      case StoryChapter.intro:
        return 'intro';
      case StoryChapter.resetButton:
        return 'reset';
      case StoryChapter.predictabilityScore:
        return 'predictability';
      case StoryChapter.randomButton:
        return 'random';
      case StoryChapter.showAlgorithm:
        return 'algorithm';
      case StoryChapter.yourPrediction:
        return 'your_prediction';
      case StoryChapter.pcNextMove:
        return 'pc_next_move';
      case StoryChapter.suggestion:
        return 'suggestion';
      case StoryChapter.crystalBall:
        return 'crystal_ball';
    }
  }

  String get prefsKey {
    switch (this) {
      case StoryChapter.intro:
        return 'has_seen_story_intro';
      case StoryChapter.resetButton:
        return 'has_seen_story_reset';
      case StoryChapter.predictabilityScore:
        return 'has_seen_story_predictability';
      case StoryChapter.randomButton:
        return 'has_seen_story_random';
      case StoryChapter.showAlgorithm:
        return 'has_seen_story_algorithm';
      case StoryChapter.yourPrediction:
        return 'has_seen_story_your_prediction';
      case StoryChapter.pcNextMove:
        return 'has_seen_story_pc_next_move';
      case StoryChapter.suggestion:
        return 'has_seen_story_suggestion';
      case StoryChapter.crystalBall:
        return 'has_seen_story_crystal_ball';
    }
  }

  String get assetPath {
    switch (this) {
      case StoryChapter.intro:
        return 'assets/images/story/intro_comic.jpeg';
      case StoryChapter.resetButton:
        return 'assets/images/story/reset_button_comic.jpeg';
      case StoryChapter.predictabilityScore:
        return 'assets/images/story/predictability_score_comic.jpeg';
      case StoryChapter.randomButton:
        return 'assets/images/story/random_button_comic.jpeg';
      case StoryChapter.showAlgorithm:
        return 'assets/images/story/show_algorithm_comic.jpeg';
      case StoryChapter.yourPrediction:
        return 'assets/images/story/your_prediction_comic.jpeg';
      case StoryChapter.pcNextMove:
        return 'assets/images/story/pc_next_move_comic.jpeg';
      case StoryChapter.suggestion:
        return 'assets/images/story/suggestion_comic.jpeg';
      case StoryChapter.crystalBall:
        return 'assets/images/story/crystal_ball_comic.jpeg';
    }
  }

  double get imageAspectRatio {
    switch (this) {
      case StoryChapter.crystalBall:
        return 1792.0 / 2400.0;
      default:
        return 1536.0 / 2752.0;
    }
  }

  IconData get icon {
    switch (this) {
      case StoryChapter.intro:
        return Icons.castle_outlined;
      case StoryChapter.resetButton:
        return Icons.hourglass_bottom_outlined;
      case StoryChapter.predictabilityScore:
        return Icons.speed_outlined;
      case StoryChapter.randomButton:
        return Icons.casino_outlined;
      case StoryChapter.showAlgorithm:
        return Icons.grid_on_outlined;
      case StoryChapter.yourPrediction:
        return Icons.psychology_outlined;
      case StoryChapter.pcNextMove:
        return Icons.visibility_outlined;
      case StoryChapter.suggestion:
        return Icons.tips_and_updates_outlined;
      case StoryChapter.crystalBall:
        return Icons.auto_awesome_outlined;
    }
  }

  String get titleKey => 'story_${id}_title';

  String get fallbackTitle {
    switch (this) {
      case StoryChapter.intro:
        return "Prologue: The Master Hand's Shadow";
      case StoryChapter.resetButton:
        return 'Chapter I: The Hourglass of Oblivion';
      case StoryChapter.predictabilityScore:
        return 'Chapter II: The Chronometer of Predictability';
      case StoryChapter.randomButton:
        return 'Chapter III: The Gauntlet of Pure Chaos';
      case StoryChapter.showAlgorithm:
        return 'Chapter IV: The Scroll of the Algorithm';
      case StoryChapter.yourPrediction:
        return 'Chapter V: The Abacus of Self-Reflection';
      case StoryChapter.pcNextMove:
        return 'Chapter VI: The Spectacles of Foresight';
      case StoryChapter.suggestion:
        return "Chapter VII: The Oracle Parrot's Counsel";
      case StoryChapter.crystalBall:
        return 'Chapter VIII: The Orb of Omniscience';
    }
  }

  String get itemNameKey {
    switch (this) {
      case StoryChapter.intro:
        return 'story_intro_badge';
      case StoryChapter.resetButton:
        return 'string37';
      case StoryChapter.predictabilityScore:
        return 'string38';
      case StoryChapter.randomButton:
        return 'string39';
      case StoryChapter.showAlgorithm:
        return 'string40';
      case StoryChapter.yourPrediction:
        return 'string41';
      case StoryChapter.pcNextMove:
        return 'string42';
      case StoryChapter.suggestion:
        return 'string43';
      case StoryChapter.crystalBall:
        return 'string80';
    }
  }

  String get fallbackItemName {
    switch (this) {
      case StoryChapter.intro:
        return "The King's Quest";
      case StoryChapter.resetButton:
        return 'Reset Button';
      case StoryChapter.predictabilityScore:
        return 'Predictability Score';
      case StoryChapter.randomButton:
        return 'Random Button';
      case StoryChapter.showAlgorithm:
        return 'Show Algorithm';
      case StoryChapter.yourPrediction:
        return 'Your Prediction';
      case StoryChapter.pcNextMove:
        return 'PC Next Move';
      case StoryChapter.suggestion:
        return 'Suggestion';
      case StoryChapter.crystalBall:
        return 'Crystal Ball';
    }
  }

  List<StoryPanelData> get panels {
    switch (this) {
      case StoryChapter.intro:
        return const [
          StoryPanelData(
            index: 0,
            speakerKey: 'story_speaker_narrator',
            fallbackSpeaker: 'Narrator',
            textKey: 'story_intro_p1',
            fallbackText:
                'Peace reigned in the Kingdom as Rock, Paper, and Scissors journeyed together in harmony...',
            bubbleAlignment: Alignment.topLeft,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 1,
            speakerKey: 'story_speaker_narrator',
            fallbackSpeaker: 'Narrator',
            textKey: 'story_intro_p2',
            fallbackText:
                'Suddenly, the sinister Master Hand descended from the storm, capturing the sacred trio with its predictive mind!',
            bubbleAlignment: Alignment.topLeft,
            tailOnLeft: false,
          ),
          StoryPanelData(
            index: 2,
            speakerKey: 'story_speaker_king',
            fallbackSpeaker: 'The King',
            textKey: 'story_intro_p3',
            fallbackText:
                'Brave hero! Master Hand reads every pattern. Only someone truly unpredictable can defeat it!',
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 3,
            speakerKey: 'story_speaker_hero',
            fallbackSpeaker: 'Hero',
            textKey: 'story_intro_p4',
            fallbackText:
                "I will master the algorithm, gather the arcane artifacts, and shatter Master Hand's predictions!",
            bubbleAlignment: Alignment.bottomRight,
            tailOnLeft: true,
          ),
        ];
      case StoryChapter.resetButton:
        return const [
          StoryPanelData(
            index: 0,
            speakerKey: 'story_speaker_hero',
            fallbackSpeaker: 'Hero',
            textKey: 'story_reset_p1',
            fallbackText:
                'Wise Alchemist! Master Hand has memorized my habits. I brought diamonds for a fresh start!',
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 1,
            speakerKey: 'story_speaker_alchemist',
            fallbackSpeaker: 'Alchemist',
            textKey: 'story_reset_p2',
            fallbackText:
                "Let us distill these crystals into temporal sand that washes away the machine's memory...",
            bubbleAlignment: Alignment.topRight,
            tailOnLeft: false,
          ),
          StoryPanelData(
            index: 2,
            speakerKey: 'story_speaker_narrator',
            fallbackSpeaker: 'Narrator',
            textKey: 'story_reset_p3',
            fallbackText:
                'In a flash of azure light, the Hourglass of Reset was forged!',
            bubbleAlignment: Alignment.bottomCenter,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 3,
            speakerKey: 'story_speaker_alchemist',
            fallbackSpeaker: 'Alchemist',
            textKey: 'story_reset_p4',
            fallbackText:
                'Turn this hourglass whenever you wish to wipe the slate clean and erase all past patterns!',
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
        ];
      case StoryChapter.predictabilityScore:
        return const [
          StoryPanelData(
            index: 0,
            speakerKey: 'story_speaker_hero',
            fallbackSpeaker: 'Hero',
            textKey: 'story_predictability_p1',
            fallbackText:
                'How can I tell if Master Hand is reading my mind or if my strategy is working?',
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 1,
            speakerKey: 'story_speaker_alchemist',
            fallbackSpeaker: 'Alchemist',
            textKey: 'story_predictability_p2',
            fallbackText:
                'By calibrating these gems to the resonance of your choices, we can measure your predictability!',
            bubbleAlignment: Alignment.topRight,
            tailOnLeft: false,
          ),
          StoryPanelData(
            index: 2,
            speakerKey: 'story_speaker_narrator',
            fallbackSpeaker: 'Narrator',
            textKey: 'story_predictability_p3',
            fallbackText:
                'The Predictability Gauge gleamed to life, its needle poised between chaos and order!',
            bubbleAlignment: Alignment.bottomCenter,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 3,
            speakerKey: 'story_speaker_alchemist',
            fallbackSpeaker: 'Alchemist',
            textKey: 'story_predictability_p4',
            fallbackText:
                'Wear this gauge! Keep the score low to prove that your mind cannot be predicted!',
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
        ];
      case StoryChapter.randomButton:
        return const [
          StoryPanelData(
            index: 0,
            speakerKey: 'story_speaker_hero',
            fallbackSpeaker: 'Hero',
            textKey: 'story_random_p1',
            fallbackText:
                'Even when I try to be random, my human instincts betray me with hidden patterns!',
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 1,
            speakerKey: 'story_speaker_alchemist',
            fallbackSpeaker: 'Alchemist',
            textKey: 'story_random_p2',
            fallbackText:
                'Human minds love repetition. Let us weave pure elemental entropy into leather and rune!',
            bubbleAlignment: Alignment.topRight,
            tailOnLeft: false,
          ),
          StoryPanelData(
            index: 2,
            speakerKey: 'story_speaker_narrator',
            fallbackSpeaker: 'Narrator',
            textKey: 'story_random_p3',
            fallbackText:
                'Sparks of wild fortune danced as the Gauntlet of Randomness materialized!',
            bubbleAlignment: Alignment.bottomCenter,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 3,
            speakerKey: 'story_speaker_alchemist',
            fallbackSpeaker: 'Alchemist',
            textKey: 'story_random_p4',
            fallbackText:
                'With this gauntlet, strike without thought or pattern—let pure chance confound the enemy!',
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
        ];
      case StoryChapter.showAlgorithm:
        return const [
          StoryPanelData(
            index: 0,
            speakerKey: 'story_speaker_hero',
            fallbackSpeaker: 'Hero',
            textKey: 'story_algorithm_p1',
            fallbackText:
                "I want to see inside Master Hand's mind! How does it calculate its next move?",
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 1,
            speakerKey: 'story_speaker_alchemist',
            fallbackSpeaker: 'Alchemist',
            textKey: 'story_algorithm_p2',
            fallbackText:
                'Its secret is a Markov Transition Matrix—counting every move you make after your last!',
            bubbleAlignment: Alignment.topRight,
            tailOnLeft: false,
          ),
          StoryPanelData(
            index: 2,
            speakerKey: 'story_speaker_narrator',
            fallbackSpeaker: 'Narrator',
            textKey: 'story_algorithm_p3',
            fallbackText:
                'Sacred geometry etched itself onto parchment: the living Markov Algorithm Tablet!',
            bubbleAlignment: Alignment.bottomCenter,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 3,
            speakerKey: 'story_speaker_alchemist',
            fallbackSpeaker: 'Alchemist',
            textKey: 'story_algorithm_p4',
            fallbackText:
                "Study these numbers in battle! Now you can reverse-engineer Master Hand's every thought!",
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
        ];
      case StoryChapter.yourPrediction:
        return const [
          StoryPanelData(
            index: 0,
            speakerKey: 'story_speaker_hero',
            fallbackSpeaker: 'Hero',
            textKey: 'story_your_prediction_p1',
            fallbackText:
                "Reading the full matrix in the heat of battle is tough! Which move does it think I'll play next?",
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 1,
            speakerKey: 'story_speaker_alchemist',
            fallbackSpeaker: 'Alchemist',
            textKey: 'story_your_prediction_p2',
            fallbackText:
                'Let us enchant an arcane abacus that tallies your most frequent transition automatically!',
            bubbleAlignment: Alignment.topRight,
            tailOnLeft: false,
          ),
          StoryPanelData(
            index: 2,
            speakerKey: 'story_speaker_narrator',
            fallbackSpeaker: 'Narrator',
            textKey: 'story_your_prediction_p3',
            fallbackText:
                'Beads of ruby, emerald, and sapphire aligned as the Abacus of Prediction awoke!',
            bubbleAlignment: Alignment.bottomCenter,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 3,
            speakerKey: 'story_speaker_alchemist',
            fallbackSpeaker: 'Alchemist',
            textKey: 'story_your_prediction_p4',
            fallbackText:
                'This reveals what Master Hand expects you to choose—play anything else to catch it off guard!',
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
        ];
      case StoryChapter.pcNextMove:
        return const [
          StoryPanelData(
            index: 0,
            speakerKey: 'story_speaker_hero',
            fallbackSpeaker: 'Hero',
            textKey: 'story_pc_next_move_p1',
            fallbackText:
                'Knowing what it expects from me is great, but what move will Master Hand itself unleash?',
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 1,
            speakerKey: 'story_speaker_alchemist',
            fallbackSpeaker: 'Alchemist',
            textKey: 'story_pc_next_move_p2',
            fallbackText:
                'By grinding these seer-crystals into lenses, we can peer straight into its counter-attack!',
            bubbleAlignment: Alignment.topRight,
            tailOnLeft: false,
          ),
          StoryPanelData(
            index: 2,
            speakerKey: 'story_speaker_narrator',
            fallbackSpeaker: 'Narrator',
            textKey: 'story_pc_next_move_p3',
            fallbackText:
                'Golden runes of all-seeing vision blazed across the Spectacles of Foresight!',
            bubbleAlignment: Alignment.bottomCenter,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 3,
            speakerKey: 'story_speaker_alchemist',
            fallbackSpeaker: 'Alchemist',
            textKey: 'story_pc_next_move_p4',
            fallbackText:
                'Look through these lenses to see the exact counter-move the AI prepares against you!',
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
        ];
      case StoryChapter.suggestion:
        return const [
          StoryPanelData(
            index: 0,
            speakerKey: 'story_speaker_hero',
            fallbackSpeaker: 'Hero',
            textKey: 'story_suggestion_p1',
            fallbackText:
                'In fast battles, calculating the counter to the counter-move takes precious seconds!',
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 1,
            speakerKey: 'story_speaker_alchemist',
            fallbackSpeaker: 'Alchemist',
            textKey: 'story_suggestion_p2',
            fallbackText:
                'Then you need a sharp-witted familiar to whisper the winning move directly in your ear!',
            bubbleAlignment: Alignment.topRight,
            tailOnLeft: false,
          ),
          StoryPanelData(
            index: 2,
            speakerKey: 'story_speaker_narrator',
            fallbackSpeaker: 'Narrator',
            textKey: 'story_suggestion_p3',
            fallbackText:
                'Feathers of emerald and sapphire shimmered as the Oracle Parrot spread its wings!',
            bubbleAlignment: Alignment.bottomCenter,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 3,
            speakerKey: 'story_speaker_alchemist',
            fallbackSpeaker: 'Alchemist',
            textKey: 'story_suggestion_p4',
            fallbackText:
                'Listen to your feathered advisor—it will always suggest the optimal hand to strike down the foe!',
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
        ];
      case StoryChapter.crystalBall:
        return const [
          StoryPanelData(
            index: 0,
            speakerKey: 'story_speaker_hero',
            fallbackSpeaker: 'Hero',
            textKey: 'story_crystal_ball_p1',
            fallbackText:
                'Even when the AI has no pattern and plays at random, can we foresee its true choice?',
            bubbleAlignment: Alignment.bottomLeft,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 1,
            speakerKey: 'story_speaker_sage',
            fallbackSpeaker: 'Master Sage',
            textKey: 'story_crystal_ball_p2',
            fallbackText:
                'For that, we must fuse the rarest astral diamonds into an orb that bends fate itself...',
            bubbleAlignment: Alignment.topLeft,
            tailOnLeft: false,
          ),
          StoryPanelData(
            index: 2,
            speakerKey: 'story_speaker_narrator',
            fallbackSpeaker: 'Narrator',
            textKey: 'story_crystal_ball_p3',
            fallbackText:
                'Cosmic light swirled within glass as the legendary Crystal Ball of Omniscience awakened!',
            bubbleAlignment: Alignment.bottomCenter,
            tailOnLeft: true,
          ),
          StoryPanelData(
            index: 3,
            speakerKey: 'story_speaker_sage',
            fallbackSpeaker: 'Master Sage',
            textKey: 'story_crystal_ball_p4',
            fallbackText:
                "Behold the Crystal Ball! No longer a mere guess—it reveals Master Hand's exact move before you play!",
            bubbleAlignment: Alignment.bottomRight,
            tailOnLeft: false,
          ),
        ];
    }
  }
}

