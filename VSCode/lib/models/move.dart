import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../services/localization_service.dart';

enum HandMove {
  rock(
    1,
    'Rock',
    'Fire',
    'assets/images/RockL.png',
    'assets/images/RockR.png',
    '✊',
    Symbols.local_fire_department,
    Color(0xFFFF5722),
    Color(0xFFFF3D00),
  ),
  paper(
    2,
    'Paper',
    'Water',
    'assets/images/PaperL.png',
    'assets/images/PaperR.png',
    '✋',
    Symbols.water_drop,
    Color(0xFF00B0FF),
    Color(0xFF2979FF),
  ),
  scissors(
    3,
    'Scissors',
    'Wood',
    'assets/images/ScissorL.png',
    'assets/images/ScissorR.png',
    '✌',
    Symbols.forest,
    Color(0xFF00E676),
    Color(0xFF2E7D32),
  ),
  lizard(
    4,
    'Lizard',
    'Earth',
    '',
    '',
    '🦎',
    Symbols.landslide,
    Color(0xFFFFB300),
    Color(0xFFD87A16),
  ),
  spock(
    5,
    'Spock',
    'Metal',
    '',
    '',
    '🖖',
    Symbols.swords,
    Color(0xFFB0BEC5),
    Color(0xFF80D8FF),
  );

  final int id;
  final String label;
  final String elementalLabel;
  final String leftAsset;
  final String rightAsset;
  final String emoji;
  final IconData elementalIcon;
  final Color elementalPrimaryColor;
  final Color elementalSecondaryColor;

  const HandMove(
    this.id,
    this.label,
    this.elementalLabel,
    this.leftAsset,
    this.rightAsset,
    this.emoji,
    this.elementalIcon,
    this.elementalPrimaryColor,
    this.elementalSecondaryColor,
  );

  static HandMove fromId(int id) {
    return HandMove.values.firstWhere(
      (m) => m.id == id,
      orElse: () => HandMove.rock,
    );
  }

  /// Returns the display label based on whether the Elemental Theme ("New Skin") is active,
  /// optionally localized via [localization].
  String displayLabel({
    bool elemental = false,
    LocalizationService? localization,
  }) {
    if (elemental) {
      if (localization != null) {
        switch (this) {
          case HandMove.rock:
            return localization.t('element_fire', fallback: elementalLabel);
          case HandMove.paper:
            return localization.t('element_water', fallback: elementalLabel);
          case HandMove.scissors:
            return localization.t('element_wood', fallback: elementalLabel);
          case HandMove.lizard:
            return localization.t('element_earth', fallback: elementalLabel);
          case HandMove.spock:
            return localization.t('element_metal', fallback: elementalLabel);
        }
      }
      return elementalLabel;
    }

    if (localization != null) {
      switch (this) {
        case HandMove.rock:
          return localization.t('string17', fallback: label);
        case HandMove.paper:
          return localization.t('string18', fallback: label);
        case HandMove.scissors:
          return localization.t('string19', fallback: label);
        case HandMove.lizard:
          return localization.t('string68', fallback: label);
        case HandMove.spock:
          return localization.t('string69', fallback: label);
      }
    }
    return label;
  }

  /// Returns true if this move defeats [other].
  /// When [elemental] is false (Classic RPS / RPSLS):
  /// - Rock beats Scissors and Lizard
  /// - Paper beats Rock and Spock
  /// - Scissors beats Paper and Lizard
  /// - Lizard beats Spock and Paper
  /// - Spock beats Scissors and Rock
  ///
  /// When [elemental] is true (Wu Xing Elemental Cycle):
  /// - Fire (rock) beats Wood (scissors) and Metal (spock)
  /// - Water (paper) beats Fire (rock) and Metal (spock)
  /// - Wood (scissors) beats Water (paper) and Earth (lizard)
  /// - Earth (lizard) beats Fire (rock) and Water (paper)
  /// - Metal (spock) beats Earth (lizard) and Wood (scissors)
  bool beats(HandMove other, {bool elemental = false}) {
    if (elemental) {
      switch (this) {
        case HandMove.rock: // Fire
          return other == HandMove.scissors || other == HandMove.spock;
        case HandMove.paper: // Water
          return other == HandMove.rock || other == HandMove.spock;
        case HandMove.scissors: // Wood
          return other == HandMove.paper || other == HandMove.lizard;
        case HandMove.lizard: // Earth
          return other == HandMove.rock || other == HandMove.paper;
        case HandMove.spock: // Metal
          return other == HandMove.lizard || other == HandMove.scissors;
      }
    }

    switch (this) {
      case HandMove.rock:
        return other == HandMove.scissors || other == HandMove.lizard;
      case HandMove.paper:
        return other == HandMove.rock || other == HandMove.spock;
      case HandMove.scissors:
        return other == HandMove.paper || other == HandMove.lizard;
      case HandMove.lizard:
        return other == HandMove.spock || other == HandMove.paper;
      case HandMove.spock:
        return other == HandMove.scissors || other == HandMove.rock;
    }
  }

  /// Returns a localized or fallback battle outcome description when [this] defeats [loser].
  /// Returns null if [this] does not defeat [loser].
  String? battleDescriptionAgainst(
    HandMove loser, {
    bool elemental = false,
    LocalizationService? localization,
  }) {
    if (!beats(loser, elemental: elemental)) return null;

    if (elemental) {
      String key = '';
      String fallback = '';
      if (this == HandMove.rock && loser == HandMove.scissors) {
        key = 'battle_fire_wood';
        fallback = 'Fire burns Wood';
      } else if (this == HandMove.rock && loser == HandMove.spock) {
        key = 'battle_fire_metal';
        fallback = 'Fire melts Metal';
      } else if (this == HandMove.paper && loser == HandMove.rock) {
        key = 'battle_water_fire';
        fallback = 'Water extinguishes Fire';
      } else if (this == HandMove.paper && loser == HandMove.spock) {
        key = 'battle_water_metal';
        fallback = 'Water rusts Metal';
      } else if (this == HandMove.scissors && loser == HandMove.paper) {
        key = 'battle_wood_water';
        fallback = 'Wood absorbs Water';
      } else if (this == HandMove.scissors && loser == HandMove.lizard) {
        key = 'battle_wood_earth';
        fallback = 'Wood roots in Earth';
      } else if (this == HandMove.lizard && loser == HandMove.rock) {
        key = 'battle_earth_fire';
        fallback = 'Earth smothers Fire';
      } else if (this == HandMove.lizard && loser == HandMove.paper) {
        key = 'battle_earth_water';
        fallback = 'Earth dams Water';
      } else if (this == HandMove.spock && loser == HandMove.lizard) {
        key = 'battle_metal_earth';
        fallback = 'Metal carves Earth';
      } else if (this == HandMove.spock && loser == HandMove.scissors) {
        key = 'battle_metal_wood';
        fallback = 'Metal chops Wood';
      }
      return localization != null
          ? localization.t(key, fallback: fallback)
          : fallback;
    } else {
      String key = '';
      String fallback = '';
      if (this == HandMove.rock && loser == HandMove.scissors) {
        key = 'battle_rock_scissors';
        fallback = 'Rock crushes Scissors';
      } else if (this == HandMove.rock && loser == HandMove.lizard) {
        key = 'battle_rock_lizard';
        fallback = 'Rock crushes Lizard';
      } else if (this == HandMove.paper && loser == HandMove.rock) {
        key = 'battle_paper_rock';
        fallback = 'Paper covers Rock';
      } else if (this == HandMove.paper && loser == HandMove.spock) {
        key = 'battle_paper_spock';
        fallback = 'Paper disproves Spock';
      } else if (this == HandMove.scissors && loser == HandMove.paper) {
        key = 'battle_scissors_paper';
        fallback = 'Scissors cuts Paper';
      } else if (this == HandMove.scissors && loser == HandMove.lizard) {
        key = 'battle_scissors_lizard';
        fallback = 'Scissors decapitates Lizard';
      } else if (this == HandMove.lizard && loser == HandMove.spock) {
        key = 'battle_lizard_spock';
        fallback = 'Lizard poisons Spock';
      } else if (this == HandMove.lizard && loser == HandMove.paper) {
        key = 'battle_lizard_paper';
        fallback = 'Lizard eats Paper';
      } else if (this == HandMove.spock && loser == HandMove.scissors) {
        key = 'battle_spock_scissors';
        fallback = 'Spock smashes Scissors';
      } else if (this == HandMove.spock && loser == HandMove.rock) {
        key = 'battle_spock_rock';
        fallback = 'Spock vaporizes Rock';
      }
      return localization != null
          ? localization.t(key, fallback: fallback)
          : fallback;
    }
  }

  /// Returns the move that counters this move
  HandMove counterForMode({bool elemental = false}) {
    if (elemental) {
      switch (this) {
        case HandMove.rock: // Fire -> countered by Water
          return HandMove.paper;
        case HandMove.paper: // Water -> countered by Wood
          return HandMove.scissors;
        case HandMove.scissors: // Wood -> countered by Fire
          return HandMove.rock;
        case HandMove.lizard: // Earth -> countered by Wood
          return HandMove.scissors;
        case HandMove.spock: // Metal -> countered by Fire
          return HandMove.rock;
      }
    }
    return standardCounter;
  }

  /// Returns the move that counters this move (for standard RPS)
  HandMove get standardCounter {
    switch (this) {
      case HandMove.rock:
        return HandMove.paper;
      case HandMove.paper:
        return HandMove.scissors;
      case HandMove.scissors:
        return HandMove.rock;
      case HandMove.lizard:
        return HandMove.rock;
      case HandMove.spock:
        return HandMove.paper;
    }
  }

  /// Storage key identifier for this move's elemental orb balance.
  String get orbKey {
    switch (this) {
      case HandMove.rock:
        return 'fire';
      case HandMove.paper:
        return 'water';
      case HandMove.scissors:
        return 'wood';
      case HandMove.lizard:
        return 'earth';
      case HandMove.spock:
        return 'metal';
    }
  }

  /// Returns the localized Elemental Orb name (e.g., "Fire Orb" or "FIRE").
  String elementalOrbName(LocalizationService? localization) {
    if (localization != null) {
      switch (this) {
        case HandMove.rock:
          return localization.t('orb_fire', fallback: 'Fire Orb');
        case HandMove.paper:
          return localization.t('orb_water', fallback: 'Water Orb');
        case HandMove.scissors:
          return localization.t('orb_wood', fallback: 'Wood Orb');
        case HandMove.lizard:
          return localization.t('orb_earth', fallback: 'Earth Orb');
        case HandMove.spock:
          return localization.t('orb_metal', fallback: 'Metal Orb');
      }
    }
    return '$elementalLabel Orb';
  }
}

/// Structured Elemental Energy Orb cost for shop upgrades.
class ElementalCost {
  final int fire;
  final int water;
  final int wood;
  final int earth;
  final int metal;

  const ElementalCost({
    this.fire = 0,
    this.water = 0,
    this.wood = 0,
    this.earth = 0,
    this.metal = 0,
  });

  int get total => fire + water + wood + earth + metal;

  int forMove(HandMove move) {
    switch (move) {
      case HandMove.rock:
        return fire;
      case HandMove.paper:
        return water;
      case HandMove.scissors:
        return wood;
      case HandMove.lizard:
        return earth;
      case HandMove.spock:
        return metal;
    }
  }

  List<MapEntry<HandMove, int>> get nonZeroEntries => [
    if (fire > 0) MapEntry(HandMove.rock, fire),
    if (water > 0) MapEntry(HandMove.paper, water),
    if (wood > 0) MapEntry(HandMove.scissors, wood),
    if (earth > 0) MapEntry(HandMove.lizard, earth),
    if (metal > 0) MapEntry(HandMove.spock, metal),
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElementalCost &&
          fire == other.fire &&
          water == other.water &&
          wood == other.wood &&
          earth == other.earth &&
          metal == other.metal;

  @override
  int get hashCode => Object.hash(fire, water, wood, earth, metal);
}

enum RoundWinner {
  user,
  computer,
  draw;

  bool get isUser => this == RoundWinner.user;
  bool get isComputer => this == RoundWinner.computer;
  bool get isDraw => this == RoundWinner.draw;
}
