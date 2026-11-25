import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/move.dart';
import '../services/markov_engine.dart';

/// Per-mage combat state for the three Royal Guardian Mages defending the
/// Royal Garden during the playable prologue battle.
class RoyalGuardianMageState {
  final HandMove element;
  final String spriteAsset;
  final String nameKey;
  final String fallbackName;
  final int maxHp;
  final int maxMana;
  int hp;
  int mana;

  RoyalGuardianMageState({
    required this.element,
    required this.spriteAsset,
    required this.nameKey,
    required this.fallbackName,
    this.maxHp = RoyalGardenTutorialController.initialMageHp,
    this.maxMana = RoyalGardenTutorialController.initialMageMana,
    int? hp,
    int? mana,
  }) : hp = hp ?? maxHp,
       mana = mana ?? maxMana;

  bool get isKnockedOut => hp <= 0;
  bool get isOutOfMana => mana <= 0;
  bool get canCast => hp > 0 && mana > 0;
}

/// Isolated sandbox state controller for the playable Royal Garden Prologue
/// Tutorial Battle (`3 Royal Guardian Mages` vs. `Guardian Robot`).
///
/// Deliberately decoupled from [GameController] so replaying the prologue never
/// mutates campaign week, HP, mana, orbs, or the player's Markov matrix.
class RoyalGardenTutorialController extends ChangeNotifier {
  static const int initialMageHp = 5;
  static const int initialMageMana = 100;
  static const int initialRobotHp = 100;
  static const int act1TotalTurns = 3;

  static const List<HandMove> tutorialElements = [
    HandMove.fire,
    HandMove.water,
    HandMove.wood,
  ];

  final MarkovEngine markovEngine;
  final bool isSandboxReplay;

  late final Map<HandMove, RoyalGuardianMageState> _mages;

  int robotHp = initialRobotHp;
  final int robotMaxHp = initialRobotHp;

  int turnCount = 0;
  int roundId = 0;
  HandMove? lastPlayerMove;
  HandMove? lastRobotMove;
  RoundWinner? lastRoundWinner;
  HandMove? lastCollectedOrb;
  HandMove? lastKnockedOutMage;
  bool triggeredOverdriveFailsafe = false;
  bool isBattleFinished = false;

  int collectedFireOrbs = 0;
  int collectedWaterOrbs = 0;
  int collectedWoodOrbs = 0;

  RoyalGardenTutorialController({
    this.isSandboxReplay = false,
    math.Random? random,
  }) : markovEngine = MarkovEngine(
         enableExtendedHands: false,
         enableElementalMode: true,
         random: random,
       ) {
    _mages = {
      HandMove.fire: RoyalGuardianMageState(
        element: HandMove.fire,
        spriteAsset: 'assets/images/enemies/mage_fire_idle.png',
        nameKey: 'tutorial_mage_fire_name',
        fallbackName: 'Fire Mage',
      ),
      HandMove.water: RoyalGuardianMageState(
        element: HandMove.water,
        spriteAsset: 'assets/images/enemies/mage_water_idle.png',
        nameKey: 'tutorial_mage_water_name',
        fallbackName: 'Water Mage',
      ),
      HandMove.wood: RoyalGuardianMageState(
        element: HandMove.wood,
        spriteAsset: 'assets/images/enemies/mage_wood_idle.png',
        nameKey: 'tutorial_mage_wood_name',
        fallbackName: 'Wood Mage',
      ),
    };
  }

  RoyalGuardianMageState mageFor(HandMove element) {
    return _mages[element] ?? _mages[HandMove.fire]!;
  }

  List<RoyalGuardianMageState> get mages => [
    _mages[HandMove.fire]!,
    _mages[HandMove.water]!,
    _mages[HandMove.wood]!,
  ];

  bool get isAct1 => turnCount < act1TotalTurns;
  bool get isAct2 => turnCount >= act1TotalTurns;
  bool get justEnteredAct2 => turnCount == act1TotalTurns && !isBattleFinished;

  int get totalCollectedOrbs =>
      collectedFireOrbs + collectedWaterOrbs + collectedWoodOrbs;

  bool get allMagesKnockedOut => mages.every((m) => m.isKnockedOut);

  bool get hasAnyCastableMage => mages.any((m) => m.canCast);

  int get survivingMageCount => mages.where((m) => !m.isKnockedOut).length;

  /// During Act 1 (Turns 1–3), returns the exact winning element highlighted
  /// for the player (`Fire` -> `Water` -> `Wood`). Returns `null` in Act 2.
  HandMove? get act1RequiredPlayerMove {
    if (isBattleFinished) return null;
    switch (turnCount) {
      case 0:
        return HandMove.fire;
      case 1:
        return HandMove.water;
      case 2:
        return HandMove.wood;
      default:
        return null;
    }
  }

  /// During Act 1 (Turns 1–3), returns the element the Guardian Robot is
  /// visibly preparing (`Wood` -> `Fire` -> `Water`). Returns `null` in Act 2.
  HandMove? get act1TelegraphedRobotMove {
    if (isBattleFinished) return null;
    switch (turnCount) {
      case 0:
        return HandMove.wood;
      case 1:
        return HandMove.fire;
      case 2:
        return HandMove.water;
      default:
        return null;
    }
  }

  /// Localization key for the Act 1 concise 1-line elemental tip.
  String? get act1TipKey {
    switch (turnCount) {
      case 0:
        return 'tutorial_tip_fire_beats_wood';
      case 1:
        return 'tutorial_tip_water_beats_fire';
      case 2:
        return 'tutorial_tip_wood_beats_water';
      default:
        return null;
    }
  }

  String? get act1TipFallback {
    switch (turnCount) {
      case 0:
        return 'Fire burns Wood!';
      case 1:
        return 'Water extinguishes Fire!';
      case 2:
        return 'Wood absorbs Water!';
      default:
        return null;
    }
  }

  bool isElementButtonEnabled(HandMove element) {
    if (isBattleFinished) return false;
    final mage = _mages[element];
    if (mage == null || !mage.canCast) return false;
    if (isAct1) {
      return element == act1RequiredPlayerMove;
    }
    return true;
  }

  bool isElementButtonHighlighted(HandMove element) {
    return !isBattleFinished && isAct1 && element == act1RequiredPlayerMove;
  }

  bool isElementButtonDimmedForGuide(HandMove element) {
    return !isBattleFinished && isAct1 && element != act1RequiredPlayerMove;
  }

  bool isElementButtonKnockedOut(HandMove element) {
    final mage = _mages[element];
    return mage == null || mage.isKnockedOut;
  }

  /// Executes a single combat turn with the mage corresponding to [playerMove].
  /// Returns `true` if the turn was accepted and resolved.
  bool playTurn(HandMove playerMove) {
    if (!isElementButtonEnabled(playerMove)) return false;

    final mage = _mages[playerMove]!;
    final wasAct1 = isAct1;

    final HandMove robotMove = wasAct1
        ? act1TelegraphedRobotMove!
        : markovEngine.computeSmartChoice(lastPlayerMove);

    // Record player transition into the isolated 3-element cumulative Markov
    // matrix after the Robot locks in its choice (matching GameController).
    markovEngine.recordTransition(lastPlayerMove, playerMove);
    lastPlayerMove = playerMove;
    lastRobotMove = robotMove;
    lastCollectedOrb = null;
    lastKnockedOutMage = null;

    // Deduct 1 Mana from the casting mage's 100-Mana pool.
    mage.mana = math.max(0, mage.mana - 1);

    final winner = playerMove.resolvesAgainst(robotMove, elemental: true);
    lastRoundWinner = winner;

    if (winner == RoundWinner.user) {
      robotHp = math.max(0, robotHp - 1);
      if (wasAct1) {
        _awardAct1Orb(robotMove);
        lastCollectedOrb = robotMove;
      }
    } else if (winner == RoundWinner.computer) {
      mage.hp = math.max(0, mage.hp - 1);
      if (mage.isKnockedOut) {
        lastKnockedOutMage = playerMove;
      }
    }

    turnCount += 1;
    roundId += 1;

    if (allMagesKnockedOut) {
      isBattleFinished = true;
    } else if (!hasAnyCastableMage || robotHp <= 0) {
      // Failsafe: if all surviving mages ever run out of 100 Mana (or if the
      // Robot's HP somehow reaches 0), trigger a cinematic Overdrive strike
      // from the Guardian Robot to conclude the prologue canonically.
      triggeredOverdriveFailsafe = true;
      for (final m in mages) {
        m.hp = 0;
      }
      isBattleFinished = true;
    }

    notifyListeners();
    return true;
  }

  void _awardAct1Orb(HandMove defeatedRobotElement) {
    switch (defeatedRobotElement) {
      case HandMove.fire:
        collectedFireOrbs += 1;
        break;
      case HandMove.water:
        collectedWaterOrbs += 1;
        break;
      case HandMove.wood:
        collectedWoodOrbs += 1;
        break;
      default:
        break;
    }
  }
}
