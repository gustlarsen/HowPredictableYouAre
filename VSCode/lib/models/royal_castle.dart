import 'package:flutter/material.dart';

/// Canonical identifiers and UI metadata for all 13 Shop upgrades/artifacts
/// that can be preserved in and restored from the Castle's Relic Chamber.
enum ShopUpgradeArtifact {
  predictability(
    id: 'predictability',
    titleKey: 'string38',
    fallbackTitle: 'Predictability Score',
    icon: Icons.speed_outlined,
  ),
  reset(
    id: 'reset',
    titleKey: 'string37',
    fallbackTitle: 'Reset Button',
    icon: Icons.hourglass_bottom_outlined,
  ),
  newHands(
    id: 'new_hands',
    titleKey: 'string56',
    fallbackTitle: 'Unlock Earth & Metal',
    icon: Icons.pan_tool_outlined,
  ),
  random(
    id: 'random',
    titleKey: 'string39',
    fallbackTitle: 'Random Move Button',
    icon: Icons.casino_outlined,
  ),
  algorithm(
    id: 'algorithm',
    titleKey: 'string40',
    fallbackTitle: 'Show Markov Algorithm',
    icon: Icons.grid_on_outlined,
  ),
  yourPrediction(
    id: 'your_prediction',
    titleKey: 'string41',
    fallbackTitle: 'Your Prediction Hint',
    icon: Icons.psychology_outlined,
  ),
  nextMove(
    id: 'next_move',
    titleKey: 'string42',
    fallbackTitle: 'PC Next Move Reveal',
    icon: Icons.visibility_outlined,
  ),
  giftBox(
    id: 'gift_box',
    titleKey: 'gift_box',
    fallbackTitle: 'Gift Box',
    icon: Icons.card_giftcard_rounded,
  ),
  suggestion(
    id: 'suggestion',
    titleKey: 'string43',
    fallbackTitle: 'Optimal Suggestion',
    icon: Icons.tips_and_updates_outlined,
  ),
  newSkin(
    id: 'new_skin',
    titleKey: 'new_skin',
    fallbackTitle: 'New Skin',
    icon: Icons.palette_outlined,
  ),
  removeAds(
    id: 'remove_ads',
    titleKey: 'string44',
    fallbackTitle: 'Remove Ads',
    icon: Icons.block_rounded,
  ),
  crystalBall(
    id: 'crystal_ball',
    titleKey: 'string80',
    fallbackTitle: 'Crystal Ball',
    icon: Icons.auto_awesome_outlined,
  ),
  crystalBallPlus(
    id: 'crystal_ball_plus',
    titleKey: 'string82',
    fallbackTitle: 'Crystal Ball+',
    icon: Icons.flare_rounded,
  ),
  markovRecalibrator(
    id: 'markov_recalibrator',
    titleKey: 'markov_recalibrator_title',
    fallbackTitle: 'Markov Recalibrator',
    icon: Icons.tune_rounded,
  ),
  overchargedStaff(
    id: 'overcharged_staff',
    titleKey: 'overcharged_staff_title',
    fallbackTitle: 'Overcharged Staff',
    icon: Icons.bolt_rounded,
  );

  final String id;
  final String titleKey;
  final String fallbackTitle;
  final IconData icon;

  const ShopUpgradeArtifact({
    required this.id,
    required this.titleKey,
    required this.fallbackTitle,
    required this.icon,
  });

  static String overchargedStaffRelicId(int level) =>
      'overcharged_staff:${level.clamp(1, 6)}';

  static int? parseOverchargedStaffLevel(String id) {
    final trimmed = id.trim();
    if (trimmed == overchargedStaff.id) return 1;
    if (trimmed.startsWith('${overchargedStaff.id}:')) {
      final rawLevel = trimmed.substring(overchargedStaff.id.length + 1);
      final parsed = int.tryParse(rawLevel);
      if (parsed == null) return 1;
      return parsed.clamp(1, 6);
    }
    return null;
  }

  static ShopUpgradeArtifact? fromId(String id) {
    final trimmed = id.trim();
    if (trimmed == overchargedStaff.id ||
        trimmed.startsWith('${overchargedStaff.id}:')) {
      return overchargedStaff;
    }
    for (final item in ShopUpgradeArtifact.values) {
      if (item.id == trimmed) return item;
    }
    return null;
  }
}

/// Optional repeatable/rotational Royal Decrees displayed in the Throne Room.
enum RoyalDecreeType {
  noRepeatWin10(
    id: 'decree_no_repeat_10',
    titleKey: 'castle_decree_no_repeat_title',
    fallbackTitle: 'Unbroken Variety',
    descKey: 'castle_decree_no_repeat_desc',
    fallbackDesc:
        'Win 10 rounds in a battle without repeating consecutive elements',
    target: 10,
    rewardPerElement: 5,
    icon: Icons.shuffle_rounded,
  ),
  defeat15(
    id: 'decree_defeat_15',
    titleKey: 'castle_decree_defeat_15_title',
    fallbackTitle: 'Elemental Vanquisher',
    descKey: 'castle_decree_defeat_15_desc',
    fallbackDesc: 'Defeat 15 enemy elements in a single expedition',
    target: 15,
    rewardPerElement: 5,
    icon: Icons.bolt_rounded,
  ),
  predictAbove70(
    id: 'decree_predict_70',
    titleKey: 'castle_decree_predict_70_title',
    fallbackTitle: 'Master of Foresight',
    descKey: 'castle_decree_predict_70_desc',
    fallbackDesc:
        'Finish a 100-round battle with Predictability Gauge above 70%',
    target: 100,
    rewardPerElement: 10,
    icon: Icons.analytics_outlined,
  ),
  winStreak5(
    id: 'decree_win_streak_5',
    titleKey: 'castle_decree_streak_5_title',
    fallbackTitle: 'Relentless Surge',
    descKey: 'castle_decree_streak_5_desc',
    fallbackDesc: 'Win 5 rounds in a row during a single battle',
    target: 5,
    rewardPerElement: 4,
    icon: Icons.local_fire_department_rounded,
  ),
  endurance50(
    id: 'decree_play_50',
    titleKey: 'castle_decree_play_50_title',
    fallbackTitle: 'Endurance Duelist',
    descKey: 'castle_decree_play_50_desc',
    fallbackDesc: 'Complete 50 rounds in a single expedition',
    target: 50,
    rewardPerElement: 4,
    icon: Icons.shield_outlined,
  ),
  diverseWins3(
    id: 'decree_diverse_3',
    titleKey: 'castle_decree_diverse_3_title',
    fallbackTitle: 'Prismatic Triumph',
    descKey: 'castle_decree_diverse_3_desc',
    fallbackDesc:
        'Win rounds defeating 3 different enemy elements in one battle',
    target: 3,
    rewardPerElement: 5,
    icon: Icons.auto_awesome_rounded,
  );

  final String id;
  final String titleKey;
  final String fallbackTitle;
  final String descKey;
  final String fallbackDesc;
  final int target;
  final int rewardPerElement;
  final IconData icon;

  const RoyalDecreeType({
    required this.id,
    required this.titleKey,
    required this.fallbackTitle,
    required this.descKey,
    required this.fallbackDesc,
    required this.target,
    required this.rewardPerElement,
    required this.icon,
  });

  static const List<String> defaultActiveIds = [
    'decree_no_repeat_10',
    'decree_defeat_15',
    'decree_predict_70',
  ];

  static RoyalDecreeType? fromId(String id) {
    for (final d in RoyalDecreeType.values) {
      if (d.id == id) return d;
    }
    return null;
  }
}

/// Arcane Bestiary entries documenting the mathematical constructs fought in battle.
enum BestiaryCreature {
  guardianRobot(
    id: 'guardian_robot',
    nameKey: 'castle_bestiary_guardian_name',
    fallbackName: 'Guardian Robot',
    mathModelKey: 'castle_bestiary_guardian_model',
    fallbackMathModel: 'Cumulative Markov Matrix',
    loreKey: 'castle_bestiary_guardian_lore',
    fallbackLore:
        'Records every transition from your previous move to your next inside a cumulative Markov matrix, countering your most habitual follow-up.',
    hintKey: 'castle_bestiary_guardian_hint',
    fallbackHint: 'Play rounds in battle so the construct learns a transition.',
    icon: Icons.memory_rounded,
    accentColor: Color(0xFF4FC3F7),
    portraitAsset: 'assets/images/enemies/guardian_robot_idle.png',
  ),
  archmageRobot(
    id: 'archmage_robot',
    nameKey: 'castle_bestiary_archmage_name',
    fallbackName: 'Robot Archmage',
    mathModelKey: 'castle_bestiary_archmage_model',
    fallbackMathModel: '1-Step Short-Term Memory',
    loreKey: 'castle_bestiary_archmage_lore',
    fallbackLore:
        '200 HP • Conjugates all 5 elements. Ignores cumulative history and tracks only your single most recent transition from each state to counter your next move.',
    hintKey: 'castle_bestiary_archmage_hint',
    fallbackHint:
        'Defeat Guardian Robot at Week 10 or later to confront this construct.',
    icon: Icons.auto_fix_high_rounded,
    accentColor: Color(0xFFFF9800),
    portraitAsset: 'assets/images/enemies/robot_archmage_idle.png',
  ),
  metalWizard(
    id: 'metal_wizard',
    nameKey: 'castle_bestiary_metal_wizard_name',
    fallbackName: 'Metal Wizard',
    mathModelKey: 'castle_bestiary_metal_wizard_model',
    fallbackMathModel: 'Pure Metal Obsession (100%)',
    loreKey: 'castle_bestiary_metal_wizard_lore',
    fallbackLore:
        '300 HP • Pure Metal Obsession: Conjures exclusively Metal spells, testing the Cleric\'s endurance and Mana reserves.',
    hintKey: 'castle_bestiary_metal_wizard_hint',
    fallbackHint:
        'Defeat Guardian Robot in Weeks 1–9 or defeat Robot Archmage to confront the Metal Wizard.',
    icon: Icons.hardware_rounded,
    accentColor: Color(0xFF90A4AE),
    portraitAsset: 'assets/images/enemies/metal_wizard_idle.png',
  ),
  babyRobot(
    id: 'baby_robot',
    nameKey: 'castle_bestiary_baby_name',
    fallbackName: 'Baby Mage Robot',
    mathModelKey: 'castle_bestiary_baby_model',
    fallbackMathModel: 'Pure Uniform Random (1/5)',
    loreKey: 'castle_bestiary_baby_lore',
    fallbackLore:
        '400 HP • Pure Random Chaos: Ignores all Markov logic and strikes with pure uniform randomness across all 5 elements.',
    hintKey: 'castle_bestiary_baby_hint',
    fallbackHint:
        'Defeat the Metal Wizard in Week 2 or later to unleash his final automated contingency.',
    icon: Icons.casino_outlined,
    accentColor: Color(0xFFBA68C8),
    portraitAsset: 'assets/images/enemies/baby_robot_mage_idle.png',
  );

  final String id;
  final String nameKey;
  final String fallbackName;
  final String mathModelKey;
  final String fallbackMathModel;
  final String loreKey;
  final String fallbackLore;
  final String hintKey;
  final String fallbackHint;
  final IconData icon;
  final Color accentColor;
  final String? portraitAsset;

  const BestiaryCreature({
    required this.id,
    required this.nameKey,
    required this.fallbackName,
    required this.mathModelKey,
    required this.fallbackMathModel,
    required this.loreKey,
    required this.fallbackLore,
    required this.hintKey,
    required this.fallbackHint,
    required this.icon,
    required this.accentColor,
    this.portraitAsset,
  });
}

/// The narrative endings tracked in the Royal Library.
enum NarrativeEnding {
  secretWeek1(
    id: 'ending_secret_week1',
    titleKey: 'castle_ending_secret_w1_title',
    fallbackTitle: 'Swift Savior (Secret Week-1)',
    descKey: 'castle_ending_secret_w1_desc',
    fallbackDesc:
        'Defeated both the Guardian Robot and the Metal Wizard in Week 1 before backup constructs could be built, rescuing the princess untouched!',
    hintKey: 'castle_ending_secret_w1_hint',
    fallbackHint: 'Defeat the Guardian Robot and Metal Wizard in Week 1.',
    icon: Icons.auto_awesome_rounded,
    accentColor: Color(0xFF00E5FF),
  ),
  standardVictory(
    id: 'ending_standard_victory',
    titleKey: 'castle_ending_standard_victory_title',
    fallbackTitle: 'Metal Lair Liberated',
    descKey: 'castle_ending_standard_victory_desc',
    fallbackDesc:
        'Destroyed the Stage 4 Baby Mage Robot (400 HP) and vanquished the Metal Wizard\'s lair!',
    hintKey: 'castle_ending_standard_victory_hint',
    fallbackHint: 'Defeat the Stage 4 Baby Mage Robot (400 HP).',
    icon: Icons.emoji_events_rounded,
    accentColor: Color(0xFFFFD54F),
  ),
  perfectPredictor(
    id: 'ending_perfect',
    titleKey: 'castle_ending_perfect_title',
    fallbackTitle: 'Master of Chaos (100%)',
    descKey: 'castle_ending_perfect_desc',
    fallbackDesc:
        'Finished a 100-round battle with 100% score—completely outsmarting Master Hand.',
    hintKey: 'castle_ending_perfect_hint',
    fallbackHint: 'Win 100% of decisive rounds in a 100-round battle.',
    icon: Icons.workspace_premium_rounded,
    accentColor: Color(0xFFFFCA28),
  ),
  triumphantStrategist(
    id: 'ending_victor',
    titleKey: 'castle_ending_victor_title',
    fallbackTitle: 'Kingdom Defender (>50%)',
    descKey: 'castle_ending_victor_desc',
    fallbackDesc:
        'Completed 100 rounds victorious above 50%, holding back the Metal Wizard.',
    hintKey: 'castle_ending_victor_hint',
    fallbackHint: 'Finish 100 rounds with >50% and <100% predictability score.',
    icon: Icons.verified_rounded,
    accentColor: Color(0xFF66BB6A),
  ),
  outpredicted(
    id: 'ending_outsmarted',
    titleKey: 'castle_ending_outsmarted_title',
    fallbackTitle: 'Read Like a Scroll (≤50%)',
    descKey: 'castle_ending_outsmarted_desc',
    fallbackDesc:
        'Survived 100 rounds, yet Master Hand anticipated over half your moves.',
    hintKey: 'castle_ending_outsmarted_hint',
    fallbackHint: 'Finish 100 rounds with 50% or lower predictability score.',
    icon: Icons.menu_book_rounded,
    accentColor: Color(0xFF42A5F5),
  ),
  kingdomFall(
    id: 'ending_kingdom_fall',
    titleKey: 'castle_ending_fall_title',
    fallbackTitle: 'The Kingdom Has Fallen',
    descKey: 'castle_ending_fall_desc',
    fallbackDesc:
        'Fell to 0 HP or passed the Week 40 deadline—forcing the Kingdom to rise anew.',
    hintKey: 'castle_ending_fall_hint',
    fallbackHint: 'Suffer defeat at 0 HP or exceed the Week 40 deadline.',
    icon: Icons.whatshot_rounded,
    accentColor: Color(0xFFEF5350),
  );

  final String id;
  final String titleKey;
  final String fallbackTitle;
  final String descKey;
  final String fallbackDesc;
  final String hintKey;
  final String fallbackHint;
  final IconData icon;
  final Color accentColor;

  const NarrativeEnding({
    required this.id,
    required this.titleKey,
    required this.fallbackTitle,
    required this.descKey,
    required this.fallbackDesc,
    required this.hintKey,
    required this.fallbackHint,
    required this.icon,
    required this.accentColor,
  });
}
