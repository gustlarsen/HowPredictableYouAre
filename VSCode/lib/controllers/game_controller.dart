import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../models/move.dart';
import '../models/evaluation_tier.dart';
import '../models/metal_wizard_ai_state.dart';
import '../models/royal_castle.dart';
import '../models/sacred_blessing.dart';
import '../models/story_chapter.dart';
import '../services/markov_engine.dart';
import '../services/storage_service.dart';
import '../services/localization_service.dart';
import '../services/audio_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/play_games_service.dart';
import '../services/ad_service.dart';
import '../services/billing_service.dart';
import '../services/update_service.dart';

/// Identifies why a campaign cycle ended via permadeath reset.
enum PermadeathCause {
  battleDefeat,
  deadlineExceeded,
  sacredSacrifice,
  deserter,
}

class GameController extends ChangeNotifier {
  static const int rewardedAdOrbBonus = 50;
  static const int periodicGiftOrbBonus = 5;
  static const Duration giftCooldownDuration = Duration(minutes: 1);
  static const int qaShortcutOrbBonus = 100000;
  static const Duration rewardedAdCooldownDuration = Duration(minutes: 2);
  static const String rewardedAdSnackBarMessage =
      '+50 Elemental Orbs earned!';
  static const String rewardedAdSnackBarMessageMain =
      '+50 Fire, Water & Wood Orbs earned!';
  static const String rewardedAdSnackBarMessageAll =
      '+50 Orbs of every element earned!';
  static const int baseMaxHp = 50;
  static const int baseMaxMana = 100;
  static const int maxHp = baseMaxHp;
  static const int maxMana = baseMaxMana;
  static const int pcMaxHp = 100;
  static const int maxCampaignWeeks = 40;
  static const int siegeInvasionWeek = 41;
  static const int phase2StartWeek = 10;
  static const int damagePerLoss = 1;
  static const int phase2BaseBossDamage = 2;
  static const int phase2BonusBossDamage = 4;
  static const int initialTreasuryCapacity =
      StorageService.defaultTreasuryMaxCapacity;
  static const int treasuryEarthMetalBonus = 100;
  static const int treasuryClaimCapacityBonus = 20;
  static const int maxWeeklyAdConsagrations = 3;
  static const int vitalityBlessingBonusHp = 15;
  static const int clairvoyanceBlessingMoves = 3;
  static const int allElementPackSmallBonus = 500;
  static const int allElementPackMediumBonus = 2500;
  static const int allElementPackLargeBonus = 10000;
  static const int singleElementBulkPackBonus = 1500;
  static const double offertoryBaseHourlyRatePerLevel = 12.0;
  static const double offertoryMilestoneBonusPer10Levels = 0.25;
  static const Duration offertoryMaxCapDuration = Duration(hours: 8);
  static const int offertoryMaxCapSeconds = 8 * 3600;
  static const Duration offertoryTitheBoostDuration = Duration(hours: 4);
  static const Duration offertoryTitheBoostMaxDuration = Duration(hours: 8);
  static const int offertoryTitheMinBalance = 50;
  static const double offertoryTithePercentage = 0.10;
  static const Duration offertoryFreeDoubleCooldown = Duration(hours: 4);

  /// First 520 digits of Pi (3.1415926535...) driving the Baby Mage Robot's
  /// deterministic dual-element harmonic sequence.
  static const String piDigitsSequence =
      '31415926535897932384626433832795028841971693993751'
      '05820974944592307816406286208998628034825342117067'
      '98214808651328230664709384460955058223172535940812'
      '84811174502841027019385211055596446229489549303819'
      '64428810975665933446128475648233786783165271201909'
      '14564856692346034861045432664821339360726024914127'
      '37245870066063155881748815209209628292540917153643'
      '67892590360011330530548820466521384146951941511609'
      '43305727036575959195309218611738193261179310511854'
      '80744623799627495673518857527248912279381830119491'
      '29833673362440656643';

  /// Returns the index-th digit of [piDigitsSequence] (0-indexed, wrapping modulo length).
  static int piDigitAt(int turnIndex) {
    final safeIdx =
        turnIndex < 0 ? 0 : (turnIndex % piDigitsSequence.length);
    return piDigitsSequence.codeUnitAt(safeIdx) - 48;
  }

  /// Maps a single digit of Pi (`0..9`) to its corresponding harmonic dual-element pair:
  /// - `0` or `1` -> `[Fire, Water]` (unique common weakness: Earth)
  /// - `2` or `3` -> `[Water, Earth]` (unique common weakness: Wood)
  /// - `4` or `5` -> `[Earth, Wood]` (unique common weakness: Metal)
  /// - `6` or `7` -> `[Wood, Metal]` (unique common weakness: Fire)
  /// - `8` or `9` -> `[Metal, Fire]` (unique common weakness: Water)
  static List<HandMove> dualElementsForPiDigit(int digit) {
    switch (digit) {
      case 0:
      case 1:
        return const [HandMove.fire, HandMove.water];
      case 2:
      case 3:
        return const [HandMove.water, HandMove.earth];
      case 4:
      case 5:
        return const [HandMove.earth, HandMove.wood];
      case 6:
      case 7:
        return const [HandMove.wood, HandMove.metal];
      case 8:
      case 9:
      default:
        return const [HandMove.metal, HandMove.fire];
    }
  }

  /// Computes the optimal counter move(s) from [activePlayerDeck] against a
  /// dual-element pair (`[spellA, spellB]`), prioritizing the unique common
  /// weakness that beats BOTH spells (score +4), then the safe win+tie counter
  /// that deals 1 HP without taking damage (score +2).
  static List<HandMove> optimalCountersForDualSpells(
    List<HandMove> dualSpells,
    List<HandMove> activePlayerDeck, {
    bool elemental = true,
  }) {
    if (dualSpells.isEmpty || activePlayerDeck.isEmpty) return const [];
    if (dualSpells.length == 1) {
      final single = dualSpells.first;
      return activePlayerDeck
          .where((m) => m.beats(single, elemental: elemental))
          .toList(growable: false);
    }
    final spellA = dualSpells[0];
    final spellB = dualSpells[1];
    int bestTierScore = -999;
    final bestMoves = <HandMove>[];

    for (final candidate in activePlayerDeck) {
      final res = DualSpellMatchupResult.evaluate(
        playerMove: candidate,
        spellA: spellA,
        spellB: spellB,
        elemental: elemental,
      );
      // Tier scoring:
      // 4 = Beats both spells (2 orbs, -1 boss HP, 0 player damage)
      // 3 = Beats 1 & Ties 1 (1 orb, -1 boss HP, 0 player damage)
      // 1 = Beats 1 & Loses 1 (1 orb, -1 boss HP, -1 player damage)
      // -1 = Ties 1 & Loses 1 (0 boss damage, -1 player damage)
      // -2 = Loses to both (0 boss damage, -2 player damage)
      final int tierScore;
      if (res.defeatedEnemySpells.length == 2 && res.playerDamage == 0) {
        tierScore = 4;
      } else if (res.bossDamage > 0 && res.playerDamage == 0) {
        tierScore = 3;
      } else if (res.bossDamage > 0 && res.playerDamage == 1) {
        tierScore = 1;
      } else if (res.playerDamage == 1) {
        tierScore = -1;
      } else {
        tierScore = -2;
      }

      if (tierScore > bestTierScore) {
        bestTierScore = tierScore;
        bestMoves
          ..clear()
          ..add(candidate);
      } else if (tierScore == bestTierScore) {
        bestMoves.add(candidate);
      }
    }
    return List.unmodifiable(bestMoves);
  }

  static ElementalCost maxHpUpgradeCostForLevel(int level) {
    final perOrb = 2 + (level ~/ 2);
    return ElementalCost(fire: perOrb, water: perOrb, wood: perOrb);
  }

  static ElementalCost maxManaUpgradeCostForLevel(int level) {
    final perOrb = 3 + (level ~/ 2);
    return ElementalCost(fire: perOrb, water: perOrb, wood: perOrb);
  }

  /// Safe iteration ceiling for `MAX` batch searches so zero-cost edge cases
  /// in tests can never spin indefinitely.
  static const int maxBatchSearchLimit = 100000;

  /// Sums exact level-by-level orb costs from [currentLevel] through
  /// `currentLevel + levels - 1` using [costForLevel].
  static ElementalCost calculateProgressiveUpgradeCost({
    required int currentLevel,
    required int levels,
    required ElementalCost Function(int level) costForLevel,
  }) {
    if (levels <= 0) return const ElementalCost();
    int fire = 0;
    int water = 0;
    int wood = 0;
    int earth = 0;
    int metal = 0;
    for (int i = 0; i < levels; i++) {
      final step = costForLevel(currentLevel + i);
      fire += step.fire;
      water += step.water;
      wood += step.wood;
      earth += step.earth;
      metal += step.metal;
    }
    return ElementalCost(
      fire: fire,
      water: water,
      wood: wood,
      earth: earth,
      metal: metal,
    );
  }

  static ElementalCost maxHpBatchCost({
    required int startLevel,
    required int levels,
  }) {
    return calculateProgressiveUpgradeCost(
      currentLevel: startLevel,
      levels: levels,
      costForLevel: maxHpUpgradeCostForLevel,
    );
  }

  static ElementalCost maxManaBatchCost({
    required int startLevel,
    required int levels,
  }) {
    return calculateProgressiveUpgradeCost(
      currentLevel: startLevel,
      levels: levels,
      costForLevel: maxManaUpgradeCostForLevel,
    );
  }

  // Shop Upgrade Elemental Orb Costs
  static const ElementalCost costPredictability = ElementalCost(
    fire: 15,
    water: 15,
    wood: 15,
  );
  static const ElementalCost costReset = ElementalCost(
    fire: 30,
    water: 30,
    wood: 30,
  );
  static const ElementalCost costNewHands = ElementalCost(
    earth: 50,
    metal: 50,
  );
  static const ElementalCost costRandom = ElementalCost(
    fire: 80,
    water: 80,
    wood: 80,
  );
  static const ElementalCost costAlgorithm = ElementalCost(
    fire: 120,
    water: 120,
    wood: 120,
    earth: 50,
    metal: 50,
  );
  static const ElementalCost costYourPrediction = ElementalCost(
    fire: 250,
    water: 250,
    wood: 250,
    earth: 100,
    metal: 100,
  );
  static const ElementalCost costNextMove = ElementalCost(
    fire: 600,
    water: 600,
    wood: 600,
    earth: 300,
    metal: 300,
  );
  static const ElementalCost costGiftBox = ElementalCost(
    fire: 500,
    water: 500,
    wood: 500,
    earth: 500,
    metal: 500,
  );
  static const ElementalCost costSuggestion = ElementalCost(
    fire: 1000,
    water: 1000,
    wood: 1000,
    earth: 500,
    metal: 500,
  );
  static const ElementalCost costNewSkin = ElementalCost(
    fire: 1500,
    water: 1500,
    wood: 1500,
    earth: 1000,
    metal: 1000,
  );
  static const ElementalCost costRemoveAds = ElementalCost(
    fire: 2000,
    water: 2000,
    wood: 2000,
    earth: 1500,
    metal: 1500,
  );
  static const ElementalCost costCrystalBall = ElementalCost(
    fire: 3500,
    water: 3500,
    wood: 3500,
    earth: 2500,
    metal: 2500,
  );
  static const ElementalCost costCrystalBallPlus = ElementalCost(
    fire: 5000,
    water: 5000,
    wood: 5000,
    earth: 5000,
    metal: 5000,
  );
  static const ElementalCost costMarkovRecalibrator = ElementalCost(
    fire: 1200,
    water: 1200,
    wood: 1200,
    earth: 1200,
    metal: 1200,
  );

  // Overcharged Staff Tiered Upgrade Constants (Levels 1..6)
  static const int overchargedStaffMaxLevel = 6;
  static const List<int> overchargedStaffSpeedOptions = [1, 2, 5, 10, 20, 30];
  static const int overchargedStaffHoldThresholdMs = 250;
  static const int overchargedStaffCriticalHpLimit = 5;

  static const ElementalCost costOverchargedStaffLv1 = ElementalCost(
    fire: 100,
    water: 100,
    wood: 100,
  );
  static const ElementalCost costOverchargedStaffLv2 = ElementalCost(
    fire: 250,
    water: 250,
    wood: 250,
  );
  static const ElementalCost costOverchargedStaffLv3 = ElementalCost(
    fire: 500,
    water: 500,
    wood: 500,
    earth: 200,
    metal: 200,
  );
  static const ElementalCost costOverchargedStaffLv4 = ElementalCost(
    fire: 1000,
    water: 1000,
    wood: 1000,
    earth: 500,
    metal: 500,
  );
  static const ElementalCost costOverchargedStaffLv5 = ElementalCost(
    fire: 2000,
    water: 2000,
    wood: 2000,
    earth: 1000,
    metal: 1000,
  );
  static const ElementalCost costOverchargedStaffLv6 = ElementalCost(
    fire: 3500,
    water: 3500,
    wood: 3500,
    earth: 2000,
    metal: 2000,
  );

  static ElementalCost overchargedStaffCostForLevel(int level) {
    switch (level) {
      case 1:
        return costOverchargedStaffLv1;
      case 2:
        return costOverchargedStaffLv2;
      case 3:
        return costOverchargedStaffLv3;
      case 4:
        return costOverchargedStaffLv4;
      case 5:
        return costOverchargedStaffLv5;
      case 6:
        return costOverchargedStaffLv6;
      default:
        return costOverchargedStaffLv1;
    }
  }

  static int overchargedStaffRequiredLevelForSpeed(int speed) {
    switch (speed) {
      case 1:
        return 1;
      case 2:
        return 2;
      case 5:
        return 3;
      case 10:
        return 4;
      case 20:
        return 5;
      case 30:
        return 6;
      default:
        return 1;
    }
  }

  static int overchargedStaffSpeedForLevel(int level) {
    switch (level) {
      case 1:
        return 1;
      case 2:
        return 2;
      case 3:
        return 5;
      case 4:
        return 10;
      case 5:
        return 20;
      case 6:
        return 30;
      default:
        return 1;
    }
  }

  static int overchargedStaffIntervalMsForSpeed(int speed) {
    switch (speed) {
      case 1:
        return 750;
      case 2:
        return 375;
      case 5:
        return 150;
      case 10:
        return 75;
      case 20:
        return 38;
      case 30:
        return 25;
      default:
        return 750;
    }
  }

  static int maxHpForEnemyStage(int stage) {
    switch (stage) {
      case 2:
        return 200;
      case 3:
        return 300;
      case 4:
        return 400;
      case 5:
        return 350;
      default:
        return pcMaxHp;
    }
  }

  static int maxHpForEnemyPhase(int phase) => maxHpForEnemyStage(phase);

  final StorageService storage;
  final LocalizationService localization;
  final AudioService audio;
  late final PlayGamesService playGames;
  late final AdService adService;
  late final BillingService billingService;
  late final UpdateService updateService;

  late MarkovEngine _engine;
  MetalWizardAiState _metalWizardAiState = MetalWizardAiState();
  MetalWizardAiState get metalWizardAiState => _metalWizardAiState;

  HandMove? currentUserMove;
  HandMove? currentComputerMove;
  HandMove? currentSecondaryComputerMove;
  HandMove? lastUserMove;

  HandMove? predictedUserMove;
  HandMove? pcNextMove;
  HandMove? suggestedMove;
  HandMove? _crystalBallMove;
  HandMove? crystalBallSecondaryMove;

  HandMove? get crystalBallMove => _crystalBallMove;
  set crystalBallMove(HandMove? value) {
    _crystalBallMove = value;
    crystalBallSecondaryMove = null;
  }

  /// Sets both primary and secondary Crystal Ball predicted moves simultaneously
  /// (used for Baby Mage Robot's dual-element spells).
  void setCrystalBallDualMoves(HandMove primary, HandMove secondary) {
    _crystalBallMove = primary;
    crystalBallSecondaryMove = secondary;
  }

  /// Active computer move(s) cast in the most recent turn (2 spells for Baby Mage Robot).
  List<HandMove> get currentComputerMoves => [
    ?currentComputerMove,
    ?currentSecondaryComputerMove,
  ];

  /// Predicted upcoming PC move(s) revealed by Crystal Ball (2 spells for Baby Mage Robot).
  List<HandMove> get crystalBallMoves => [
    ?_crystalBallMove,
    ?crystalBallSecondaryMove,
  ];

  /// All active player elements that optimally counter the Crystal Ball's
  /// predicted PC element(s), derived directly from [crystalBallMoves].
  List<HandMove> get crystalBallPlusMoves {
    final predictedPcMoves = crystalBallMoves;
    if (predictedPcMoves.isEmpty) return const [];
    if (predictedPcMoves.length >= 2) {
      return optimalCountersForDualSpells(
        predictedPcMoves,
        _engine.activeMoves,
        elemental: isElementalMode,
      );
    }
    final counters = <HandMove>[];
    for (final pcMove in predictedPcMoves) {
      for (final playerMove in _engine.activeMoves) {
        if (isMetalWizardBoss && playerMove == HandMove.metal) continue;
        if (playerMove.beats(pcMove, elemental: isElementalMode) &&
            !counters.contains(playerMove)) {
          counters.add(playerMove);
        }
      }
    }
    return List.unmodifiable(counters);
  }

  List<HandMove> predictedUserMoves = [];
  List<HandMove> pcNextMoves = [];
  List<HandMove> suggestedMoves = [];

  RoundWinner? lastWinner;
  DualSpellMatchupResult? lastDualSpellResult;
  bool lastRoundBlockedByAntiMetalShield = false;
  int lastRoundUserDamage = 0;
  int lastRoundComputerDamage = 0;
  List<HandMove> lastCollectedOrbMoves = const [];

  // 5 Elemental Energy Orbs Inventory
  int fireOrbs = 0;
  int waterOrbs = 0;
  int woodOrbs = 0;
  int earthOrbs = 0;
  int metalOrbs = 0;

  // Turn 0 Baseline Orb Snapshot (protected across battle rewind;
  // battle-win and periodic Gift Box orbs are reverted on Reset,
  // while Rewarded Video Ad +50 orbs are added here so they are preserved).
  int turn0FireOrbs = 0;
  int turn0WaterOrbs = 0;
  int turn0WoodOrbs = 0;
  int turn0EarthOrbs = 0;
  int turn0MetalOrbs = 0;

  int get totalOrbs =>
      fireOrbs + waterOrbs + woodOrbs + earthOrbs + metalOrbs;

  Map<HandMove, int> get elementalOrbs => {
    HandMove.rock: fireOrbs,
    HandMove.paper: waterOrbs,
    HandMove.scissors: woodOrbs,
    HandMove.lizard: earthOrbs,
    HandMove.spock: metalOrbs,
  };

  int orbsFor(HandMove move) {
    switch (move) {
      case HandMove.rock:
        return fireOrbs;
      case HandMove.paper:
        return waterOrbs;
      case HandMove.scissors:
        return woodOrbs;
      case HandMove.lizard:
        return earthOrbs;
      case HandMove.spock:
        return metalOrbs;
    }
  }

  int turn0OrbsFor(HandMove move) {
    switch (move) {
      case HandMove.rock:
        return turn0FireOrbs;
      case HandMove.paper:
        return turn0WaterOrbs;
      case HandMove.scissors:
        return turn0WoodOrbs;
      case HandMove.lizard:
        return turn0EarthOrbs;
      case HandMove.spock:
        return turn0MetalOrbs;
    }
  }

  /// Reversible [move] orbs gained during this battle that will be lost on Reset.
  int lostOrbsFor(HandMove move) =>
      math.max(0, orbsFor(move) - turn0OrbsFor(move));

  /// Per-element breakdown of reversible orbs that will be lost on Reset.
  Map<HandMove, int> get lostOrbsOnReset => {
    for (final move in HandMove.values) move: lostOrbsFor(move),
  };

  int get totalLostOrbsOnReset =>
      HandMove.values.fold(0, (sum, move) => sum + lostOrbsFor(move));

  // Flying Orb VFX tracking for round wins
  HandMove? lastCollectedOrbMove;
  int orbCollectionEventId = 0;

  // 7-tap QA shortcut counter on top-left Backpack icon
  int _backpackQaTapCount = 0;
  DateTime? _lastBackpackQaTapTime;

  int userScore = 0;
  int get playerScore => userScore;
  int pcScore = 0;
  int totalRounds = 0;
  int hpUpgradeLevel = 0;
  int manaUpgradeLevel = 0;
  int get playerMaxHp => baseMaxHp + hpUpgradeLevel;
  int get playerMaxMana => baseMaxMana + manaUpgradeLevel;
  ElementalCost get nextMaxHpUpgradeCost =>
      maxHpUpgradeCostForLevel(hpUpgradeLevel);
  ElementalCost get nextMaxManaUpgradeCost =>
      maxManaUpgradeCostForLevel(manaUpgradeLevel);
  int get remainingMana => (playerMaxMana - totalRounds).clamp(0, playerMaxMana);
  int turnCount = 0;
  int userHp = baseMaxHp;
  int computerHp = pcMaxHp;
  int enemyStage = 1;
  int get enemyPhase => enemyStage;
  set enemyPhase(int value) => enemyStage = value;
  int enemyMaxHp = pcMaxHp;
  int get enemyHp => computerHp;
  int currentWeek = 0;

  // Post-Week-0 Scream Warning Modal State (per-campaign)
  bool hasShownWeek0ScreamWarning = false;
  bool pendingWeek0ScreamWarning = false;
  bool hasInspectedPrincessCellAfterScream = false;

  bool get shouldShowWeek0ScreamWarning =>
      pendingWeek0ScreamWarning && !hasShownWeek0ScreamWarning;

  bool get shouldShowPrincessCellScreamBadge =>
      hasShownWeek0ScreamWarning && !hasInspectedPrincessCellAfterScream;

  bool get hasDungeonScreamOccurred =>
      hasShownWeek0ScreamWarning || pendingWeek0ScreamWarning;

  // Sacred Temple Consagration Weekly Ad Cap & Prayer Room Blessings
  int adConsagrationsThisWeek = 0;
  SacredBlessing? pendingBattleBlessing;
  SacredBlessing? activeBattleBlessing;
  int battleBonusTempHp = 0;
  String? lastFreeDailyPrayerDate;

  int get effectivePlayerMaxHp => playerMaxHp + battleBonusTempHp;
  int get remainingWeeklyAdConsagrations =>
      (maxWeeklyAdConsagrations - adConsagrationsThisWeek)
          .clamp(0, maxWeeklyAdConsagrations);
  bool get canWatchAdConsagration =>
      !isRemoveAdsActive &&
      adService.isRewardedAdReady &&
      remainingWeeklyAdConsagrations > 0;
  bool get isVitalityBlessingActive =>
      activeBattleBlessing == SacredBlessing.vitality && battleBonusTempHp > 0;
  bool get isClairvoyanceActive =>
      activeBattleBlessing == SacredBlessing.clairvoyance &&
      totalRounds < clairvoyanceBlessingMoves &&
      crystalBallMove != null;
  int get clairvoyanceMovesRemaining =>
      activeBattleBlessing == SacredBlessing.clairvoyance
          ? (clairvoyanceBlessingMoves - totalRounds)
              .clamp(0, clairvoyanceBlessingMoves)
          : 0;
  bool get isHarvestBlessingActive =>
      activeBattleBlessing == SacredBlessing.harvest;

  static String dateKeyFor(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  bool hasFreeDailyPrayerAvailable([DateTime? now]) =>
      lastFreeDailyPrayerDate != dateKeyFor(now ?? DateTime.now());

  bool canActivateSacredBlessingFree([DateTime? now]) =>
      pendingBattleBlessing == null &&
      (isRemoveAdsActive || hasFreeDailyPrayerAvailable(now));

  bool canActivateSacredBlessingWithAd() =>
      pendingBattleBlessing == null &&
      !isRemoveAdsActive &&
      adService.isRewardedAdReady;

  bool darkMode = true;
  bool soundEnabled = true;
  bool musicEnabled = true;
  bool vibrationEnabled = true;
  bool animationsEnabled = true;
  bool confirmBattleTeleport = true;

  bool get skipTeleportConfirm => !confirmBattleTeleport;

  // Unlocks
  bool unlockedReset = false;
  bool unlockedPredictability = false;
  bool unlockedRandom = false;
  bool unlockedAlgorithm = false;
  bool unlockedNewHands = false;
  bool unlockedYourPrediction = false;
  bool unlockedNextMove = false;
  bool unlockedSuggestion = false;
  bool unlockedAds = false;
  bool unlockedNewSkin = false;
  bool unlockedCrystalBall = false;
  bool unlockedCrystalBallPlus = false;
  bool unlockedMarkovRecalibrator = false;
  bool giftBoxUnlocked = false;
  int overchargedStaffLevel = 0;

  // Active toggles
  bool showReset = false;
  bool showPredictability = false;
  bool showRandom = false;
  bool showAlgorithm = false;
  bool showNewHands = false;
  bool showNewSkin = false;
  bool showYourPrediction = false;

  /// Whether the Elemental Theme is currently active.
  /// The starting skin is the Elemental Theme.
  /// Acquiring and enabling the "New Skin" item switches to the Hands Theme.
  bool get isElementalMode => !showNewSkin;
  bool get elementalMode => isElementalMode;
  bool get isHandsTheme => showNewSkin;
  bool showNextMove = false;
  bool showSuggestion = false;
  bool removeAdsEnabled = false;
  bool showCrystalBall = false;
  bool showCrystalBallPlus = false;
  bool crystalBallPlusSavedState = false;
  bool showMarkovRecalibrator = false;
  bool giftBoxEnabled = false;
  bool overchargedStaffEnabled = false;
  int overchargedStaffSelectedSpeed = 1;

  bool get isOverchargedStaffUnlocked => overchargedStaffLevel >= 1;
  bool get isOverchargedStaffActive =>
      overchargedStaffLevel >= 1 && overchargedStaffEnabled;
  int get overchargedStaffIntervalMs =>
      overchargedStaffIntervalMsForSpeed(overchargedStaffSelectedSpeed);
  Duration get overchargedStaffInterval =>
      Duration(milliseconds: overchargedStaffIntervalMs);
  ElementalCost? get nextOverchargedStaffUpgradeCost =>
      overchargedStaffLevel < overchargedStaffMaxLevel
          ? overchargedStaffCostForLevel(overchargedStaffLevel + 1)
          : null;

  bool get markovRecalibratorUnlocked => unlockedMarkovRecalibrator;
  bool get markovRecalibratorEnabled => showMarkovRecalibrator;
  bool get isMarkovRecalibratorActive =>
      unlockedMarkovRecalibrator && showMarkovRecalibrator;
  bool get isMarkovRecalibratorVisibleInShop =>
      unlockedMarkovRecalibrator ||
      enemyStage == 2 ||
      encounteredBestiary.contains(BestiaryCreature.archmageRobot.id);

  bool is100RoundsAlertPending = false;
  bool isDeathAlertPending = false;
  bool isBossVictoryPending = false;
  int? pendingBossVictoryStage;
  int? get pendingBossVictoryPhase => pendingBossVictoryStage;
  set pendingBossVictoryPhase(int? value) => pendingBossVictoryStage = value;
  int? pendingBossVictoryWeek;
  bool isGiftAvailable = true;
  Timer? _giftTimer;
  DateTime? _giftCooldownUntil;
  Duration _remainingGiftCooldown = Duration.zero;

  bool get isGiftBoxActive => giftBoxUnlocked && giftBoxEnabled;
  bool get shouldShowGiftBox => isGiftBoxActive && isGiftAvailable;
  bool get isGiftTimerActive => _giftTimer?.isActive ?? false;

  // Rewarded Ad 2-minute Anti-Spam Cooldown State
  bool isRewardedAdOnCooldown = false;
  DateTime? _rewardedAdCooldownUntil;
  Timer? _rewardedAdCooldownTimer;

  // QA Tester Bonus Persistence & Pending Notification
  bool hasClaimedQaBonus = false;
  String? pendingQaBonusSnackBar;

  // Google Play Flexible In-App Update Pending Notification
  bool pendingUpdateSnackBar = false;

  // Story Cutscene Persistence & Pending State
  bool hasSeenStoryIntro = false;
  bool hasSeenStoryReset = false;
  bool hasSeenStoryPredictability = false;
  bool hasSeenStoryRandom = false;
  bool hasSeenStoryAlgorithm = false;
  bool hasSeenStoryYourPrediction = false;
  bool hasSeenStoryPcNextMove = false;
  bool hasSeenStorySuggestion = false;
  bool hasSeenStoryCrystalBall = false;
  StoryChapter? pendingStoryChapter;

  // Royal Castle Hub State
  int treasuryFireOrbs = 0;
  int treasuryWaterOrbs = 0;
  int treasuryWoodOrbs = 0;
  int treasuryEarthOrbs = 0;
  int treasuryMetalOrbs = 0;
  int treasuryMaxCapacity = initialTreasuryCapacity;
  int treasuryVaultLevel = StorageService.defaultTreasuryVaultLevel;
  bool treasuryEarthMetalBonusGranted = false;

  int spoilsFireOrbs = 0;
  int spoilsWaterOrbs = 0;
  int spoilsWoodOrbs = 0;
  int spoilsEarthOrbs = 0;
  int spoilsMetalOrbs = 0;

  List<String> relicChamberStoredUpgrades = [];
  Map<String, bool> relicChamberStoredUpgradeStates = {};
  int? relicChamberStoredOverchargedStaffSpeed;
  int peakHpUpgradeLevel = 0;
  int peakManaUpgradeLevel = 0;
  bool hallOfHeroesClaimAvailable = false;
  Set<String> unlockedEndings = {};
  Set<String> encounteredBestiary = {};

  // Permanent Lifetime Account Chronicles & Run Statistics
  int totalCyclesCount = 0;
  int deathDefeatCount = 0;
  int timeoutDefeatCount = 0;
  int forfeitRunCount = 0;
  int standardVictoryCount = 0;
  int secretVictoryCount = 0;
  int sacredSacrificeCount = 0;
  int deserterCount = 0;
  int? fastestVictoryWeek;
  int guardianRobotDefeatedCount = 0;
  int robotArchmageDefeatedCount = 0;
  int metalWizardDefeatedCount = 0;
  int templeMasterDefeatedCount = 0;
  int babyMageRobotDefeatedCount = 0;

  List<String> activeDecreeIds =
      List<String>.from(RoyalDecreeType.defaultActiveIds);
  Set<String> completedCycleDecreeIds = {};
  int totalDecreesCompleted = 0;
  int decreeNoRepeatWinCount = 0;
  int decreeWinStreak = 0;
  Set<String> decreeDefeatedElements = {};

  // Sacred Temple Offertory Permanent Idle Orb Generator State
  final DateTime Function() _clock;
  int offertoryLevel = 0;
  int? offertoryLastCollectedAt;
  double offertoryPendingFraction = 0.0;
  int offertoryBankedOrbs = 0;
  double offertoryBankedSeconds = 0.0;
  int? offertoryBoostExpiresAt;
  int? offertoryFreeDoubleReadyAt;

  GameController({
    required this.storage,
    required this.localization,
    required this.audio,
    PlayGamesService? playGames,
    AdService? adService,
    BillingService? billingService,
    UpdateService? updateService,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    this.playGames = playGames ?? PlayGamesService(storage: storage);
    this.adService = adService ?? AdService();
    this.billingService = billingService ?? BillingService();
    this.updateService = updateService ?? UpdateService();
    this.playGames.onCloudDataRestored = _handleCloudDataRestored;
    this.playGames.onQaBonusGranted = _handleQaBonusGranted;
    this.playGames.addListener(_handlePlayGamesUpdate);
    this.adService.addListener(_handleAdServiceUpdate);
    this.billingService.onEntitlementGranted = _handleBillingEntitlementGranted;
    this.billingService.addListener(_handleBillingServiceUpdate);
    this.updateService.onUpdateDownloaded = _handleUpdateDownloaded;
    this.updateService.addListener(_handleUpdateServiceUpdate);
    if (this.updateService.isUpdateDownloaded) {
      pendingUpdateSnackBar = true;
    }
    _loadState();
  }

  void _handleAdServiceUpdate() {
    notifyListeners();
  }

  void _handleBillingServiceUpdate() {
    notifyListeners();
  }

  void _handleUpdateServiceUpdate() {
    notifyListeners();
  }

  void _handleUpdateDownloaded() {
    pendingUpdateSnackBar = true;
    notifyListeners();
  }

  bool get isUpdateDownloaded => updateService.isUpdateDownloaded;

  bool consumePendingUpdateSnackBar() {
    final pending = pendingUpdateSnackBar;
    pendingUpdateSnackBar = false;
    return pending;
  }

  /// Checks Google Play for an available flexible in-app update asynchronously.
  Future<void> checkForUpdate() => updateService.checkForUpdate();

  /// Manually checks Google Play for an available in-app update from Settings.
  Future<ManualUpdateCheckResult> checkForUpdateManually() =>
      updateService.checkForUpdateManually();

  /// Completes installation and restarts the app when a flexible update has
  /// finished downloading in the background.
  Future<bool> completeFlexibleUpdate() =>
      updateService.completeFlexibleUpdate();

  void _handleBillingEntitlementGranted(
    String productId,
    PurchaseStatus status,
  ) {
    unlockByProductId(productId);
  }

  /// True when the Remove Ads shop upgrade (`unlock_remove_ads` / `unlockedAds`) is owned.
  bool get unlockedRemoveAds => unlockedAds;
  bool get isRemoveAdsOwned => unlockedAds;
  bool get isRemoveAdsEnabled => removeAdsEnabled;

  /// True when Remove Ads is both owned (`unlockedAds`) and actively enabled (`removeAdsEnabled`).
  bool get isRemoveAdsActive => unlockedAds && removeAdsEnabled;

  /// True when the bottom banner ad should be displayed on screen.
  bool get shouldShowBannerAd => !isRemoveAdsActive && adService.isBannerAdLoaded;

  /// True when the optional Rewarded Video ad (+50 Orbs) is preloaded and not on cooldown.
  bool get isRewardedAdReady =>
      adService.isRewardedAdReady && !isRewardedAdOnCooldown;

  /// True when a Rewarded Video ad is preloaded and ready for death revival
  /// (unaffected by the +50 Orbs anti-spam cooldown, and muted when Vow of Silence is ON).
  bool get isReviveAdReady =>
      !isRemoveAdsActive && adService.isRewardedAdReady;

  /// True when advancing +1 Week from the current campaign week exceeds [maxCampaignWeeks] (40)
  /// and enters [siegeInvasionWeek] (Week 41).
  bool get willNextWeekExceedLimit => currentWeek + 1 > maxCampaignWeeks;

  /// Highest week inspectable on the World Map timeline slider:
  /// strictly clamped to [currentWeek] (`1..41`) with no future spoilers.
  int get maxInspectableWorldMapWeek =>
      currentWeek.clamp(1, siegeInvasionWeek);

  /// True when [productId] has been verified as a real-money Google Play IAP.
  bool isRealMoneyIapProduct(String productId) =>
      storage.purchasedIapProductIds.contains(productId) ||
      billingService.isVerifiedPurchased(productId);

  /// Remaining cooldown duration after watching a rewarded ad, or [Duration.zero].
  Duration get rewardedAdCooldownRemaining {
    if (!isRewardedAdOnCooldown || _rewardedAdCooldownUntil == null) {
      return Duration.zero;
    }
    final remaining = _rewardedAdCooldownUntil!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _handleCloudDataRestored() {
    _loadState(restartAudio: false);
    notifyListeners();
  }

  void _handleQaBonusGranted() {
    hasClaimedQaBonus = storage.hasClaimedQaBonus;
    _syncOrbsFromStorage();
    _syncTurn0OrbsFromStorage();
    pendingQaBonusSnackBar = PlayGamesService.qaBonusSnackBarMessage;
    notifyListeners();
  }

  void _syncOrbsFromStorage() {
    fireOrbs = storage.fireOrbs;
    waterOrbs = storage.waterOrbs;
    woodOrbs = storage.woodOrbs;
    earthOrbs = storage.earthOrbs;
    metalOrbs = storage.metalOrbs;
  }

  void _syncTurn0OrbsFromStorage() {
    turn0FireOrbs = storage.turn0FireOrbs;
    turn0WaterOrbs = storage.turn0WaterOrbs;
    turn0WoodOrbs = storage.turn0WoodOrbs;
    turn0EarthOrbs = storage.turn0EarthOrbs;
    turn0MetalOrbs = storage.turn0MetalOrbs;
  }

  void _persistOrbsToStorage() {
    storage.setAllOrbs(
      fire: fireOrbs,
      water: waterOrbs,
      wood: woodOrbs,
      earth: earthOrbs,
      metal: metalOrbs,
    );
  }

  void _persistTurn0OrbsToStorage() {
    storage.setTurn0Orbs(
      fire: turn0FireOrbs,
      water: turn0WaterOrbs,
      wood: turn0WoodOrbs,
      earth: turn0EarthOrbs,
      metal: turn0MetalOrbs,
    );
  }

  /// Records the player's current Elemental Orb balances as the Turn 0
  /// baseline snapshot and persists them to [StorageService].
  void recordTurn0OrbSnapshot() {
    turn0FireOrbs = fireOrbs;
    turn0WaterOrbs = waterOrbs;
    turn0WoodOrbs = woodOrbs;
    turn0EarthOrbs = earthOrbs;
    turn0MetalOrbs = metalOrbs;
    _persistTurn0OrbsToStorage();
  }

  /// Ensures a Turn 0 baseline snapshot exists when entering [GameScreen]
  /// before Turn 1 is played.
  void captureTurn0SnapshotOnBattleEntry() {
    if (!hasGameStarted && totalRounds == 0 && !storage.hasTurn0OrbSnapshot) {
      recordTurn0OrbSnapshot();
    }
  }

  void _incrementOrbForMove(HandMove move, int delta) {
    switch (move) {
      case HandMove.rock:
        fireOrbs += delta;
        storage.setFireOrbs(fireOrbs);
        break;
      case HandMove.paper:
        waterOrbs += delta;
        storage.setWaterOrbs(waterOrbs);
        break;
      case HandMove.scissors:
        woodOrbs += delta;
        storage.setWoodOrbs(woodOrbs);
        break;
      case HandMove.lizard:
        earthOrbs += delta;
        storage.setEarthOrbs(earthOrbs);
        break;
      case HandMove.spock:
        metalOrbs += delta;
        storage.setMetalOrbs(metalOrbs);
        break;
    }
  }

  String? consumePendingQaBonusSnackBar() {
    final msg = pendingQaBonusSnackBar;
    pendingQaBonusSnackBar = null;
    return msg;
  }

  void _handlePlayGamesUpdate() {
    notifyListeners();
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      updateService.setAppForeground(false);
    } else if (state == AppLifecycleState.resumed) {
      updateService.setAppForeground(true);
    }

    unawaited(audio.handleAppLifecycleState(state));

    if (state == AppLifecycleState.resumed) {
      unawaited(playGames.handleAppResumed());
      unawaited(updateService.handleAppResumed());
      unawaited(adService.handleAppResumed());
    }
  }

  /// Forwards display density / logical viewport size changes to [AdService]
  /// so native platform banner views refresh if metrics change after an update.
  void handleMetricsChanged({
    required double devicePixelRatio,
    required Size logicalSize,
  }) {
    adService.handleMetricsChanged(
      devicePixelRatio: devicePixelRatio,
      logicalSize: logicalSize,
    );
  }

  void _triggerCloudSave() {
    if (playGames.isSignedIn) {
      unawaited(playGames.saveCloudData());
    }
  }

  static const List<HandMove> basicElementPool = [
    HandMove.fire,
    HandMove.water,
    HandMove.wood,
  ];

  static const List<HandMove> allElementPool = [
    HandMove.fire,
    HandMove.water,
    HandMove.wood,
    HandMove.earth,
    HandMove.metal,
  ];

  bool get isWeekPhase2 => currentWeek >= phase2StartWeek;

  bool get isPhase2 => isWeekPhase2 || enemyStage >= 2;

  /// True only for bosses whose element pool spans all 5 elements
  /// (Stage 2 Robot Archmage, Stage 5 Temple High Master, & Stage 4 Baby Mage Robot).
  /// Stage 1 Guardian Robot strictly uses [Fire, Water, Wood] and
  /// Stage 3 Metal Wizard uses [Metal, Earth].
  bool get enemyUses5Elements =>
      enemyStage == 2 || enemyStage == 4 || enemyStage == 5;

  /// Player's currently active element pool (3 basic elements by default,
  /// or all 5 elements when Earth & Metal is unlocked and enabled).
  List<HandMove> get playerAllowedMoves =>
      showNewHands ? allElementPool : basicElementPool;

  /// Active boss's allowed element pool, strictly decoupled from the player's
  /// unlocked elements:
  /// - Stage 1 (Guardian Robot, 100 HP): [Fire, Water, Wood] ONLY.
  /// - Stage 2 (Robot Archmage, 200 HP): All 5 elements.
  /// - Stage 3 (Metal Wizard, 300 HP): [Metal, Earth].
  /// - Stage 5 (Temple High Master, 350 HP): All 5 elements (1/5 Pure Random).
  /// - Stage 4 (Baby Mage Robot, 400 HP): All 5 elements (Dual Harmonic Pi Sequence).
  List<HandMove> get bossAllowedMoves {
    switch (enemyStage) {
      case 2:
      case 4:
      case 5:
        return allElementPool;
      case 3:
        return const [HandMove.metal, HandMove.earth];
      default:
        return basicElementPool;
    }
  }

  void _syncEngineEnemyPool() {
    _engine.enableEnemyExtendedHands = enemyUses5Elements;
    _engine.enemyAllowedMoves = bossAllowedMoves;
  }

  bool get isGuardianBoss => enemyStage == 1;

  bool get isArchmageBoss => enemyStage == 2;

  bool get isMetalWizardBoss => enemyStage == 3;

  bool get isBabyMageBoss => enemyStage == 4;

  bool get isTempleMasterBoss => enemyStage == 5;

  /// True when fighting inside the Sacred Temple arena (`temple_arena_bg`),
  /// which applies to both the Temple High Master (`350 HP`) and the Baby Mage Robot (`400 HP`).
  bool get isSacredTempleArena => isTempleMasterBoss || isBabyMageBoss;

  String enemyNameForStage(int stage) {
    switch (stage) {
      case 2:
        return localization.t(
          'boss_name_archmage',
          fallback: 'Robot Archmage',
        );
      case 3:
        return localization.t(
          'boss_name_metal_wizard',
          fallback: 'Metal Wizard',
        );
      case 4:
        return localization.t(
          'boss_name_baby_mage',
          fallback: 'Baby Mage Robot',
        );
      case 5:
        return localization.t(
          'boss_name_temple_master',
          fallback: 'Temple High Master',
        );
      default:
        return localization.t(
          'boss_name_guardian',
          fallback: 'Guardian Robot',
        );
    }
  }

  String enemyNameForPhase(int phase) => enemyNameForStage(phase);

  String get currentEnemyName => enemyNameForStage(enemyStage);

  bool get isEarthAndMetalActive => unlockedNewHands && showNewHands;

  /// Whether Rewarded Video Ad and periodic Gift Box bonuses include Earth & Metal
  /// in addition to the 3 main elements (Fire, Water, Wood).
  bool get includesEarthAndMetalInBonuses => isPhase2 || unlockedNewHands;

  /// Active elements granted by Rewarded Video Ad and periodic Gift Box rewards.
  List<HandMove> get bonusOrbMoves => includesEarthAndMetalInBonuses
      ? HandMove.values
      : const [HandMove.rock, HandMove.paper, HandMove.scissors];

  String get rewardedAdDescription => includesEarthAndMetalInBonuses
      ? localization.t(
          'rewarded_ad_desc',
          fallback: 'Watch a video ad for +50 of every element',
        )
      : localization.t(
          'rewarded_ad_desc_main',
          fallback: 'Watch a video ad for +50 Fire, Water & Wood Orbs',
        );

  String get activeRewardedAdSnackBarMessage => includesEarthAndMetalInBonuses
      ? localization.t(
          'rewarded_ad_claimed_all',
          fallback: rewardedAdSnackBarMessageAll,
        )
      : localization.t(
          'rewarded_ad_claimed_main',
          fallback: rewardedAdSnackBarMessageMain,
        );

  String get giftBoxDescription => includesEarthAndMetalInBonuses
      ? localization.t(
          'gift_box_desc',
          fallback:
              'Unlocks a periodic 🎁 gift chest on the top bar granting +5 orbs of every element',
        )
      : localization.t(
          'gift_box_desc_main',
          fallback:
              'Unlocks a periodic 🎁 gift chest on the top bar granting +5 Fire, Water & Wood orbs',
        );

  String get giftTooltipMessage => includesEarthAndMetalInBonuses
      ? localization.t(
          'gift_tooltip',
          fallback: 'Claim Free +5 Orbs of Every Element Gift',
        )
      : localization.t(
          'gift_tooltip_main',
          fallback: 'Claim Free +5 Fire, Water & Wood Orbs Gift',
        );

  String get giftClaimedMessage => includesEarthAndMetalInBonuses
      ? localization.t(
          'gift_claimed_msg',
          fallback: '🎁 +5 Orbs of Every Element Claimed!',
        )
      : localization.t(
          'gift_claimed_msg_main',
          fallback: '🎁 +5 Fire, Water & Wood Orbs Claimed!',
        );

  int get playerWinDamageToBoss => damagePerLoss;

  int get bossWinDamageToPlayer => damagePerLoss;

  void _loadState({bool restartAudio = true}) {
    _syncOrbsFromStorage();
    if (storage.hasTurn0OrbSnapshot) {
      _syncTurn0OrbsFromStorage();
    } else {
      recordTurn0OrbSnapshot();
    }
    hasClaimedQaBonus = storage.hasClaimedQaBonus;
    hpUpgradeLevel = storage.hpUpgradeLevel;
    manaUpgradeLevel = storage.manaUpgradeLevel;
    adConsagrationsThisWeek = storage.adConsagrationsThisWeek;
    pendingBattleBlessing = SacredBlessing.fromId(storage.pendingBattleBlessing);
    activeBattleBlessing = SacredBlessing.fromId(storage.activeBattleBlessing);
    battleBonusTempHp = activeBattleBlessing == SacredBlessing.vitality
        ? (storage.battleBonusTempHp > 0
              ? storage.battleBonusTempHp
              : vitalityBlessingBonusHp)
        : 0;
    lastFreeDailyPrayerDate = storage.lastFreeDailyPrayerDate;
    offertoryLevel = storage.offertoryLevel;
    offertoryLastCollectedAt = storage.offertoryLastCollectedAt;
    offertoryPendingFraction = storage.offertoryPendingFraction;
    offertoryBankedOrbs = storage.offertoryBankedOrbs;
    offertoryBankedSeconds = storage.offertoryBankedSeconds;
    offertoryBoostExpiresAt = storage.offertoryBoostExpiresAt;
    offertoryFreeDoubleReadyAt = storage.offertoryFreeDoubleReadyAt;
    if (offertoryLevel > 0 && offertoryLastCollectedAt == null) {
      offertoryLastCollectedAt = _nowUtc().millisecondsSinceEpoch;
      storage.setOffertoryLastCollectedAt(offertoryLastCollectedAt);
    }
    userScore = storage.userScore;
    pcScore = storage.pcScore;
    totalRounds = storage.total;
    currentWeek = storage.currentWeek;
    hasShownWeek0ScreamWarning = storage.hasShownWeek0ScreamWarning;
    pendingWeek0ScreamWarning = storage.pendingWeek0ScreamWarning;
    hasInspectedPrincessCellAfterScream =
        storage.hasInspectedPrincessCellAfterScream;
    if (storage.userHpRaw != null) {
      userHp = storage.userHp.clamp(0, effectivePlayerMaxHp);
    } else {
      userHp = math.max(0, effectivePlayerMaxHp - pcScore * damagePerLoss);
    }

    darkMode = storage.darkMode;
    soundEnabled = storage.soundEnabled;
    musicEnabled = storage.musicEnabled;
    vibrationEnabled = storage.vibrationEnabled;
    animationsEnabled = storage.animationsEnabled;
    confirmBattleTeleport = storage.confirmBattleTeleport;
    localization.setLanguage(storage.language);

    unlockedReset = storage.unlockedReset;
    unlockedPredictability = storage.unlockedPredictability;
    unlockedRandom = storage.unlockedRandom;
    unlockedAlgorithm = storage.unlockedAlgorithm;
    unlockedNewHands = storage.unlockedNewHands;
    unlockedYourPrediction = storage.unlockedYourPrediction;
    unlockedNextMove = storage.unlockedNextMove;
    unlockedSuggestion = storage.unlockedSuggestion;
    unlockedAds = storage.unlockedAds;
    removeAdsEnabled = unlockedAds ? storage.removeAdsEnabled : false;
    adService.setAdsRemoved(isRemoveAdsActive);
    unlockedNewSkin = storage.unlockedNewSkin;
    unlockedCrystalBall = storage.unlockedCrystalBall;
    unlockedCrystalBallPlus = storage.unlockedCrystalBallPlus;
    unlockedMarkovRecalibrator = storage.unlockedMarkovRecalibrator;
    giftBoxUnlocked = storage.giftBoxUnlocked;
    overchargedStaffLevel = storage.overchargedStaffLevel.clamp(0, overchargedStaffMaxLevel);

    enemyPhase = storage.enemyPhase.clamp(1, 5);
    enemyMaxHp = storage.enemyMaxHpRaw ?? maxHpForEnemyPhase(enemyPhase);

    showReset = storage.showReset;
    showPredictability =
        unlockedPredictability ? storage.showPredictability : false;
    showRandom = storage.showRandom;
    showAlgorithm = storage.showAlgorithm;
    showNewHands = storage.showNewHands;
    showNewSkin = storage.showNewSkin;
    showYourPrediction = storage.showYourPrediction;
    showNextMove = storage.showNextMove;
    showSuggestion = storage.showSuggestion;
    showCrystalBall = storage.showCrystalBall;
    crystalBallPlusSavedState = storage.crystalBallPlusSavedState;
    showCrystalBallPlus =
        showCrystalBall ? storage.showCrystalBallPlus : false;
    showMarkovRecalibrator =
        unlockedMarkovRecalibrator ? storage.showMarkovRecalibrator : false;
    giftBoxEnabled = giftBoxUnlocked ? storage.giftBoxEnabled : false;
    overchargedStaffEnabled =
        overchargedStaffLevel >= 1 ? storage.overchargedStaffEnabled : false;
    final rawStaffSpeed = storage.overchargedStaffSelectedSpeed;
    if (overchargedStaffLevel >= 1 &&
        overchargedStaffSpeedOptions.contains(rawStaffSpeed) &&
        overchargedStaffRequiredLevelForSpeed(rawStaffSpeed) <=
            overchargedStaffLevel) {
      overchargedStaffSelectedSpeed = rawStaffSpeed;
    } else if (overchargedStaffLevel >= 1) {
      overchargedStaffSelectedSpeed =
          overchargedStaffSpeedForLevel(overchargedStaffLevel);
    } else {
      overchargedStaffSelectedSpeed = 1;
    }

    if (storage.pcHpRaw != null) {
      computerHp = storage.pcHp.clamp(0, enemyMaxHp);
    } else {
      computerHp =
          math.max(0, enemyMaxHp - userScore * playerWinDamageToBoss);
    }
    isDeathAlertPending = userHp <= 0;
    isBossVictoryPending = !isDeathAlertPending && computerHp <= 0;
    if (isBossVictoryPending) {
      pendingBossVictoryPhase = enemyPhase;
      pendingBossVictoryWeek = currentWeek;
    } else {
      pendingBossVictoryPhase = null;
      pendingBossVictoryWeek = null;
    }
    is100RoundsAlertPending = !isDeathAlertPending &&
        !isBossVictoryPending &&
        totalRounds >= playerMaxMana;
    if (totalRounds == 0 && storage.lastUserMove == null) {
      turnCount = 0;
    }

    if (!giftBoxUnlocked || !giftBoxEnabled) {
      _pauseGiftTimer();
      if (!giftBoxUnlocked) {
        isGiftAvailable = true;
        _remainingGiftCooldown = Duration.zero;
      }
    } else {
      _resumeGiftTimerIfNeeded();
    }

    hasSeenStoryIntro = storage.hasSeenStoryIntro;
    hasSeenStoryReset = storage.hasSeenStoryReset;
    hasSeenStoryPredictability = storage.hasSeenStoryPredictability;
    hasSeenStoryRandom = storage.hasSeenStoryRandom;
    hasSeenStoryAlgorithm = storage.hasSeenStoryAlgorithm;
    hasSeenStoryYourPrediction = storage.hasSeenStoryYourPrediction;
    hasSeenStoryPcNextMove = storage.hasSeenStoryPcNextMove;
    hasSeenStorySuggestion = storage.hasSeenStorySuggestion;
    hasSeenStoryCrystalBall = storage.hasSeenStoryCrystalBall;

    if (!hasSeenStoryIntro && totalRounds == 0) {
      pendingStoryChapter = StoryChapter.intro;
    } else {
      pendingStoryChapter = null;
    }

    audio.soundEnabled = soundEnabled;
    audio.musicEnabled = musicEnabled;
    audio.vibrationEnabled = vibrationEnabled;
    if (!musicEnabled) {
      unawaited(audio.stopMusic());
    } else if (restartAudio) {
      unawaited(audio.startMusic());
    }

    _engine = MarkovEngine(
      enableExtendedHands: showNewHands,
      enableEnemyExtendedHands: enemyUses5Elements,
      enemyAllowedMoves: bossAllowedMoves,
      enableElementalMode: isElementalMode,
    );
    final savedMatrix = storage.getMarkovMatrix(_engine.size);
    if (savedMatrix != null) {
      _engine.setMatrix(savedMatrix);
    }
    _engine.setLastTransitions(storage.shortTermTransitions);

    final savedWizardState = storage.metalWizardAiState;
    _metalWizardAiState = savedWizardState != null
        ? MetalWizardAiState.fromJson(savedWizardState)
        : MetalWizardAiState();

    currentUserMove = storage.lastUserMove;
    currentComputerMove = storage.lastComputerMove;
    if (!showNewHands) {
      if (currentUserMove == HandMove.lizard ||
          currentUserMove == HandMove.spock) {
        currentUserMove = null;
      }
    }
    if (currentComputerMove != null &&
        !bossAllowedMoves.contains(currentComputerMove)) {
      currentComputerMove = null;
    }
    if (currentUserMove == null || currentComputerMove == null) {
      currentUserMove = null;
      currentComputerMove = null;
      lastWinner = null;
      lastRoundBlockedByAntiMetalShield = false;
    } else {
      final antiMetalBlocked =
          enemyStage == 3 && currentUserMove == HandMove.metal;
      lastRoundBlockedByAntiMetalShield = antiMetalBlocked;
      lastWinner = antiMetalBlocked
          ? RoundWinner.draw
          : currentUserMove!.resolvesAgainst(
              currentComputerMove!,
              elemental: isElementalMode,
            );
    }
    lastUserMove = currentUserMove;

    _computeNextHints();

    treasuryFireOrbs = storage.treasuryFireOrbs;
    treasuryWaterOrbs = storage.treasuryWaterOrbs;
    treasuryWoodOrbs = storage.treasuryWoodOrbs;
    treasuryEarthOrbs = storage.treasuryEarthOrbs;
    treasuryMetalOrbs = storage.treasuryMetalOrbs;
    treasuryMaxCapacity = storage.treasuryMaxCapacity;
    treasuryVaultLevel = storage.treasuryVaultLevel;
    treasuryEarthMetalBonusGranted = storage.treasuryEarthMetalBonusGranted;
    if (unlockedNewHands && !treasuryEarthMetalBonusGranted) {
      treasuryMaxCapacity += treasuryEarthMetalBonus;
      treasuryEarthMetalBonusGranted = true;
      storage.setTreasuryMaxCapacity(treasuryMaxCapacity);
      storage.setTreasuryEarthMetalBonusGranted(true);
    }

    spoilsFireOrbs = storage.spoilsFireOrbs;
    spoilsWaterOrbs = storage.spoilsWaterOrbs;
    spoilsWoodOrbs = storage.spoilsWoodOrbs;
    spoilsEarthOrbs = storage.spoilsEarthOrbs;
    spoilsMetalOrbs = storage.spoilsMetalOrbs;

    relicChamberStoredUpgrades = List<String>.from(storage.relicChamberUpgrades);
    relicChamberStoredUpgradeStates = Map<String, bool>.from(
      storage.relicChamberUpgradeStates,
    );
    relicChamberStoredOverchargedStaffSpeed =
        storage.relicChamberOverchargedStaffSpeed;
    peakHpUpgradeLevel = math.max(storage.peakHpUpgradeLevel, hpUpgradeLevel);
    peakManaUpgradeLevel =
        math.max(storage.peakManaUpgradeLevel, manaUpgradeLevel);
    hallOfHeroesClaimAvailable = storage.hallOfHeroesClaimAvailable &&
        (peakHpUpgradeLevel > 0 || peakManaUpgradeLevel > 0);
    unlockedEndings = Set<String>.from(storage.unlockedEndings);
    encounteredBestiary = Set<String>.from(storage.encounteredBestiary);

    totalCyclesCount = storage.totalCyclesCount;
    deathDefeatCount = storage.deathDefeatCount;
    timeoutDefeatCount = storage.timeoutDefeatCount;
    forfeitRunCount = storage.forfeitRunCount;
    standardVictoryCount = storage.standardVictoryCount;
    secretVictoryCount = storage.secretVictoryCount;
    sacredSacrificeCount = storage.sacredSacrificeCount;
    deserterCount = storage.deserterCount;
    fastestVictoryWeek = storage.fastestVictoryWeek;
    guardianRobotDefeatedCount = storage.guardianRobotDefeatedCount;
    robotArchmageDefeatedCount = storage.robotArchmageDefeatedCount;
    metalWizardDefeatedCount = storage.metalWizardDefeatedCount;
    templeMasterDefeatedCount = storage.templeMasterDefeatedCount;
    babyMageRobotDefeatedCount = storage.babyMageRobotDefeatedCount;

    final storedDecrees = storage.activeDecreeIds;
    activeDecreeIds = (storedDecrees != null && storedDecrees.length == 3)
        ? List<String>.from(storedDecrees)
        : List<String>.from(RoyalDecreeType.defaultActiveIds);
    completedCycleDecreeIds = Set<String>.from(storage.completedCycleDecreeIds);
    totalDecreesCompleted = storage.totalDecreesCompleted;
    decreeNoRepeatWinCount = storage.decreeNoRepeatWinCount;
    decreeWinStreak = storage.decreeWinStreak;
    decreeDefeatedElements = Set<String>.from(storage.decreeDefeatedElements);
  }

  MarkovEngine get engine => _engine;

  bool get hasGameStarted =>
      turnCount > 0 ||
      totalRounds > 0 ||
      userScore > 0 ||
      pcScore > 0 ||
      currentUserMove != null ||
      lastUserMove != null ||
      _engine.matrix.any((row) => row.any((count) => count > 0));

  int get decisiveRounds => userScore + pcScore;

  double get percentPredict {
    if (decisiveRounds == 0) return 0.0;
    return (userScore / decisiveRounds) * 100.0;
  }

  /// True when the Predictability Score upgrade is both unlocked and toggled ON.
  bool get isPredictabilityEnabled =>
      unlockedPredictability && showPredictability;

  EvaluationTier get evaluationTier {
    final pcPredictPercent =
        decisiveRounds == 0 ? 0.0 : (pcScore / decisiveRounds) * 100.0;
    return EvaluationTier.fromPercent(pcPredictPercent, totalRounds);
  }

  // --- Royal Castle Hub Getters & Helpers ---

  int treasuryOrbsFor(HandMove move) {
    switch (move) {
      case HandMove.rock:
        return treasuryFireOrbs;
      case HandMove.paper:
        return treasuryWaterOrbs;
      case HandMove.scissors:
        return treasuryWoodOrbs;
      case HandMove.lizard:
        return treasuryEarthOrbs;
      case HandMove.spock:
        return treasuryMetalOrbs;
    }
  }

  int get totalTreasuryOrbs =>
      treasuryFireOrbs +
      treasuryWaterOrbs +
      treasuryWoodOrbs +
      treasuryEarthOrbs +
      treasuryMetalOrbs;

  bool get isTreasuryFull => totalTreasuryOrbs >= treasuryMaxCapacity;

  int spoilsOrbsFor(HandMove move) {
    switch (move) {
      case HandMove.rock:
        return spoilsFireOrbs;
      case HandMove.paper:
        return spoilsWaterOrbs;
      case HandMove.scissors:
        return spoilsWoodOrbs;
      case HandMove.lizard:
        return spoilsEarthOrbs;
      case HandMove.spock:
        return spoilsMetalOrbs;
    }
  }

  int get totalSpoilsOfWarOrbs =>
      spoilsFireOrbs +
      spoilsWaterOrbs +
      spoilsWoodOrbs +
      spoilsEarthOrbs +
      spoilsMetalOrbs;

  bool get hasSpoilsOfWarOrbs => totalSpoilsOfWarOrbs > 0;

  Map<HandMove, int> get spoilsOfWarOrbs => {
    HandMove.rock: spoilsFireOrbs,
    HandMove.paper: spoilsWaterOrbs,
    HandMove.scissors: spoilsWoodOrbs,
    HandMove.lizard: spoilsEarthOrbs,
    HandMove.spock: spoilsMetalOrbs,
  };

  bool isUpgradeArtifactUnlocked(ShopUpgradeArtifact artifact) {
    switch (artifact) {
      case ShopUpgradeArtifact.predictability:
        return unlockedPredictability;
      case ShopUpgradeArtifact.reset:
        return unlockedReset;
      case ShopUpgradeArtifact.newHands:
        return unlockedNewHands;
      case ShopUpgradeArtifact.random:
        return unlockedRandom;
      case ShopUpgradeArtifact.algorithm:
        return unlockedAlgorithm;
      case ShopUpgradeArtifact.yourPrediction:
        return unlockedYourPrediction;
      case ShopUpgradeArtifact.nextMove:
        return unlockedNextMove;
      case ShopUpgradeArtifact.giftBox:
        return giftBoxUnlocked;
      case ShopUpgradeArtifact.suggestion:
        return unlockedSuggestion;
      case ShopUpgradeArtifact.newSkin:
        return unlockedNewSkin;
      case ShopUpgradeArtifact.removeAds:
        return unlockedAds;
      case ShopUpgradeArtifact.crystalBall:
        return unlockedCrystalBall;
      case ShopUpgradeArtifact.crystalBallPlus:
        return unlockedCrystalBallPlus;
      case ShopUpgradeArtifact.markovRecalibrator:
        return unlockedMarkovRecalibrator;
      case ShopUpgradeArtifact.overchargedStaff:
        return overchargedStaffLevel >= 1;
    }
  }

  bool isUpgradeArtifactEnabled(ShopUpgradeArtifact artifact) {
    switch (artifact) {
      case ShopUpgradeArtifact.predictability:
        return showPredictability;
      case ShopUpgradeArtifact.reset:
        return showReset;
      case ShopUpgradeArtifact.newHands:
        return showNewHands;
      case ShopUpgradeArtifact.random:
        return showRandom;
      case ShopUpgradeArtifact.algorithm:
        return showAlgorithm;
      case ShopUpgradeArtifact.yourPrediction:
        return showYourPrediction;
      case ShopUpgradeArtifact.nextMove:
        return showNextMove;
      case ShopUpgradeArtifact.giftBox:
        return giftBoxEnabled;
      case ShopUpgradeArtifact.suggestion:
        return showSuggestion;
      case ShopUpgradeArtifact.newSkin:
        return showNewSkin;
      case ShopUpgradeArtifact.removeAds:
        return removeAdsEnabled;
      case ShopUpgradeArtifact.crystalBall:
        return showCrystalBall;
      case ShopUpgradeArtifact.crystalBallPlus:
        return showCrystalBallPlus;
      case ShopUpgradeArtifact.markovRecalibrator:
        return showMarkovRecalibrator;
      case ShopUpgradeArtifact.overchargedStaff:
        return overchargedStaffEnabled;
    }
  }

  /// Returns the saved pre-defeat toggle state for [artifact] in the Relic Chamber,
  /// defaulting to `true` for backward compatibility with older saves.
  bool isRelicStoredEnabled(ShopUpgradeArtifact artifact) {
    return relicChamberStoredUpgradeStates[artifact.id] ?? true;
  }

  String? _productIdForArtifact(ShopUpgradeArtifact artifact) {
    switch (artifact) {
      case ShopUpgradeArtifact.predictability:
        return BillingService.productPredictabilityScore;
      case ShopUpgradeArtifact.reset:
        return BillingService.productResetButton;
      case ShopUpgradeArtifact.newHands:
        return BillingService.productNewHands;
      case ShopUpgradeArtifact.random:
        return BillingService.productRandomButton;
      case ShopUpgradeArtifact.algorithm:
        return BillingService.productShowAlgorithm;
      case ShopUpgradeArtifact.yourPrediction:
        return BillingService.productYourPrediction;
      case ShopUpgradeArtifact.nextMove:
        return BillingService.productPcNextMove;
      case ShopUpgradeArtifact.suggestion:
        return BillingService.productSuggestion;
      case ShopUpgradeArtifact.removeAds:
        return BillingService.productRemoveAds;
      case ShopUpgradeArtifact.crystalBall:
        return BillingService.productCrystalBall;
      case ShopUpgradeArtifact.giftBox:
      case ShopUpgradeArtifact.newSkin:
      case ShopUpgradeArtifact.crystalBallPlus:
      case ShopUpgradeArtifact.markovRecalibrator:
      case ShopUpgradeArtifact.overchargedStaff:
        return null;
    }
  }

  int get storedRelicOverchargedStaffLevel {
    int maxLevel = 0;
    for (final id in relicChamberStoredUpgrades) {
      final parsed = ShopUpgradeArtifact.parseOverchargedStaffLevel(id);
      if (parsed != null && parsed > maxLevel) {
        maxLevel = parsed;
      }
    }
    return maxLevel;
  }

  int get storedRelicOverchargedStaffSpeed {
    final targetLevel = storedRelicOverchargedStaffLevel;
    if (targetLevel <= 0) return 1;
    final stored = relicChamberStoredOverchargedStaffSpeed;
    if (stored != null &&
        overchargedStaffSpeedOptions.contains(stored) &&
        overchargedStaffRequiredLevelForSpeed(stored) <= targetLevel) {
      return stored;
    }
    return overchargedStaffSpeedForLevel(targetLevel);
  }

  List<ShopUpgradeArtifact> get availableRelicChamberArtifacts {
    final result = <ShopUpgradeArtifact>[];
    final seen = <ShopUpgradeArtifact>{};
    for (final id in relicChamberStoredUpgrades) {
      final artifact = ShopUpgradeArtifact.fromId(id);
      if (artifact == null ||
          artifact == ShopUpgradeArtifact.removeAds ||
          !seen.add(artifact)) {
        continue;
      }
      if (artifact == ShopUpgradeArtifact.overchargedStaff) {
        if (storedRelicOverchargedStaffLevel > overchargedStaffLevel) {
          result.add(artifact);
        }
      } else if (!isUpgradeArtifactUnlocked(artifact)) {
        result.add(artifact);
      }
    }
    return result;
  }

  bool get hasAvailableRelicChamberUpgrades =>
      availableRelicChamberArtifacts.isNotEmpty;

  bool get hasHallOfHeroesBlessings =>
      hallOfHeroesClaimAvailable &&
      (peakHpUpgradeLevel > 0 || peakManaUpgradeLevel > 0);

  int get hallOfHeroesTargetMaxHp => baseMaxHp + peakHpUpgradeLevel;
  int get hallOfHeroesTargetMaxMana => baseMaxMana + peakManaUpgradeLevel;

  bool get isHpBelowUnclaimedHeroPeak =>
      hallOfHeroesClaimAvailable && hpUpgradeLevel < peakHpUpgradeLevel;

  bool get isManaBelowUnclaimedHeroPeak =>
      hallOfHeroesClaimAvailable && manaUpgradeLevel < peakManaUpgradeLevel;

  bool get hasUnclaimedHeroPeakWarning =>
      isHpBelowUnclaimedHeroPeak || isManaBelowUnclaimedHeroPeak;

  bool get hasRoyalCastleNotification =>
      isTreasuryFull ||
      hasAvailableRelicChamberUpgrades ||
      hasSpoilsOfWarOrbs ||
      hasHallOfHeroesBlessings;

  bool isEndingUnlocked(NarrativeEnding ending) =>
      unlockedEndings.contains(ending.id) ||
      ending.legacyIds.any(unlockedEndings.contains);

  int get unlockedEndingsCount =>
      NarrativeEnding.values.where(isEndingUnlocked).length;

  bool isBestiaryEncountered(BestiaryCreature creature) =>
      encounteredBestiary.contains(creature.id);

  List<RoyalDecreeType> get activeRoyalDecrees {
    final list = <RoyalDecreeType>[];
    for (final id in activeDecreeIds) {
      final decree = RoyalDecreeType.fromId(id);
      if (decree != null) list.add(decree);
    }
    if (list.isEmpty) {
      return const [
        RoyalDecreeType.noRepeatWin10,
        RoyalDecreeType.defeat15,
        RoyalDecreeType.predictAbove70,
      ];
    }
    return list;
  }

  bool isDecreeCompletedInCycle(RoyalDecreeType decree) =>
      completedCycleDecreeIds.contains(decree.id);

  int decreeProgressFor(RoyalDecreeType decree) {
    if (isDecreeCompletedInCycle(decree)) return decree.target;
    switch (decree) {
      case RoyalDecreeType.noRepeatWin10:
        return decreeNoRepeatWinCount.clamp(0, decree.target);
      case RoyalDecreeType.defeat15:
        return userScore.clamp(0, decree.target);
      case RoyalDecreeType.predictAbove70:
        return totalRounds.clamp(0, decree.target);
      case RoyalDecreeType.winStreak5:
        return decreeWinStreak.clamp(0, decree.target);
      case RoyalDecreeType.endurance50:
        return totalRounds.clamp(0, decree.target);
      case RoyalDecreeType.diverseWins3:
        return decreeDefeatedElements.length.clamp(0, decree.target);
    }
  }

  void _persistTreasuryOrbsToStorage() {
    storage.setAllTreasuryOrbs(
      fire: treasuryFireOrbs,
      water: treasuryWaterOrbs,
      wood: treasuryWoodOrbs,
      earth: treasuryEarthOrbs,
      metal: treasuryMetalOrbs,
    );
  }

  void _persistSpoilsOrbsToStorage() {
    storage.setAllSpoilsOrbs(
      fire: spoilsFireOrbs,
      water: spoilsWaterOrbs,
      wood: spoilsWoodOrbs,
      earth: spoilsEarthOrbs,
      metal: spoilsMetalOrbs,
    );
  }

  void _grantTreasuryEarthMetalBonusIfNeeded() {
    if (treasuryEarthMetalBonusGranted) return;
    treasuryMaxCapacity += treasuryEarthMetalBonus;
    treasuryEarthMetalBonusGranted = true;
    storage.setTreasuryMaxCapacity(treasuryMaxCapacity);
    storage.setTreasuryEarthMetalBonusGranted(true);
  }

  void _depositTreasuryOrbForMove(HandMove move, int delta) {
    if (delta <= 0) return;
    final remainingSpace = math.max(0, treasuryMaxCapacity - totalTreasuryOrbs);
    final toAdd = math.min(delta, remainingSpace);
    if (toAdd <= 0) return;
    switch (move) {
      case HandMove.rock:
        treasuryFireOrbs += toAdd;
        storage.setTreasuryFireOrbs(treasuryFireOrbs);
        break;
      case HandMove.paper:
        treasuryWaterOrbs += toAdd;
        storage.setTreasuryWaterOrbs(treasuryWaterOrbs);
        break;
      case HandMove.scissors:
        treasuryWoodOrbs += toAdd;
        storage.setTreasuryWoodOrbs(treasuryWoodOrbs);
        break;
      case HandMove.lizard:
        treasuryEarthOrbs += toAdd;
        storage.setTreasuryEarthOrbs(treasuryEarthOrbs);
        break;
      case HandMove.spock:
        treasuryMetalOrbs += toAdd;
        storage.setTreasuryMetalOrbs(treasuryMetalOrbs);
        break;
    }
  }

  void _depositTreasuryAllElements(int amountPerElement) {
    if (amountPerElement <= 0) return;
    int remainingSpace = math.max(0, treasuryMaxCapacity - totalTreasuryOrbs);
    if (remainingSpace <= 0) return;
    for (int round = 0; round < amountPerElement && remainingSpace > 0; round++) {
      if (remainingSpace > 0) {
        treasuryFireOrbs += 1;
        remainingSpace -= 1;
      }
      if (remainingSpace > 0) {
        treasuryWaterOrbs += 1;
        remainingSpace -= 1;
      }
      if (remainingSpace > 0) {
        treasuryWoodOrbs += 1;
        remainingSpace -= 1;
      }
      if (remainingSpace > 0) {
        treasuryEarthOrbs += 1;
        remainingSpace -= 1;
      }
      if (remainingSpace > 0) {
        treasuryMetalOrbs += 1;
        remainingSpace -= 1;
      }
    }
    _persistTreasuryOrbsToStorage();
  }

  void _markBestiaryEncountered(BestiaryCreature creature) {
    if (encounteredBestiary.add(creature.id)) {
      storage.setEncounteredBestiary(encounteredBestiary.toList());
    }
  }

  void _markEndingUnlocked(NarrativeEnding ending) {
    if (unlockedEndings.add(ending.id)) {
      storage.setUnlockedEndings(unlockedEndings.toList());
    }
  }

  void _evaluateRoyalDecrees() {
    bool anyCompleted = false;
    for (final decree in activeRoyalDecrees) {
      if (completedCycleDecreeIds.contains(decree.id)) continue;
      final bool isComplete;
      switch (decree) {
        case RoyalDecreeType.noRepeatWin10:
          isComplete = decreeNoRepeatWinCount >= decree.target;
          break;
        case RoyalDecreeType.defeat15:
          isComplete = userScore >= decree.target;
          break;
        case RoyalDecreeType.predictAbove70:
          isComplete = totalRounds >= 100 && percentPredict > 70.0;
          break;
        case RoyalDecreeType.winStreak5:
          isComplete = decreeWinStreak >= decree.target;
          break;
        case RoyalDecreeType.endurance50:
          isComplete = totalRounds >= decree.target;
          break;
        case RoyalDecreeType.diverseWins3:
          isComplete = decreeDefeatedElements.length >= decree.target;
          break;
      }
      if (isComplete) {
        completedCycleDecreeIds.add(decree.id);
        totalDecreesCompleted += 1;
        _depositTreasuryAllElements(decree.rewardPerElement);
        anyCompleted = true;
      }
    }
    if (anyCompleted) {
      storage.setCompletedCycleDecreeIds(completedCycleDecreeIds.toList());
      storage.setTotalDecreesCompleted(totalDecreesCompleted);
    }
  }

  void _refreshCompletedDecreesAndResetBattleTrackers() {
    if (completedCycleDecreeIds.isNotEmpty) {
      for (int i = 0; i < activeDecreeIds.length; i++) {
        if (completedCycleDecreeIds.contains(activeDecreeIds[i])) {
          activeDecreeIds[i] = _nextDecreeIdForSlot(activeDecreeIds[i]);
        }
      }
      completedCycleDecreeIds.clear();
      storage.setActiveDecreeIds(activeDecreeIds);
    }
    decreeNoRepeatWinCount = 0;
    decreeWinStreak = 0;
    decreeDefeatedElements.clear();
    storage.clearBattleDecreeProgress();
  }

  String _nextDecreeIdForSlot(String currentId) {
    final pool = RoyalDecreeType.values.map((d) => d.id).toList();
    final startIdx = pool.indexOf(currentId);
    for (int offset = 1; offset <= pool.length; offset++) {
      final candidate = pool[(startIdx + offset) % pool.length];
      if (!activeDecreeIds.contains(candidate)) {
        return candidate;
      }
    }
    return currentId;
  }

  /// Rotates or refreshes a completed Royal Decree in the Throne Room.
  void rotateCompletedDecree(RoyalDecreeType decree) {
    if (!completedCycleDecreeIds.contains(decree.id)) return;
    final idx = activeDecreeIds.indexOf(decree.id);
    if (idx != -1) {
      activeDecreeIds[idx] = _nextDecreeIdForSlot(decree.id);
      storage.setActiveDecreeIds(activeDecreeIds);
    }
    completedCycleDecreeIds.remove(decree.id);
    storage.setCompletedCycleDecreeIds(completedCycleDecreeIds.toList());
    _triggerCloudSave();
    notifyListeners();
  }

  bool _transferTreasuryToBackpack() {
    if (totalTreasuryOrbs <= 0) return false;
    fireOrbs += treasuryFireOrbs;
    waterOrbs += treasuryWaterOrbs;
    woodOrbs += treasuryWoodOrbs;
    earthOrbs += treasuryEarthOrbs;
    metalOrbs += treasuryMetalOrbs;

    turn0FireOrbs += treasuryFireOrbs;
    turn0WaterOrbs += treasuryWaterOrbs;
    turn0WoodOrbs += treasuryWoodOrbs;
    turn0EarthOrbs += treasuryEarthOrbs;
    turn0MetalOrbs += treasuryMetalOrbs;

    treasuryFireOrbs = 0;
    treasuryWaterOrbs = 0;
    treasuryWoodOrbs = 0;
    treasuryEarthOrbs = 0;
    treasuryMetalOrbs = 0;

    treasuryMaxCapacity += treasuryClaimCapacityBonus;
    treasuryVaultLevel += 1;

    _persistOrbsToStorage();
    _persistTurn0OrbsToStorage();
    _persistTreasuryOrbsToStorage();
    storage.setTreasuryMaxCapacity(treasuryMaxCapacity);
    storage.setTreasuryVaultLevel(treasuryVaultLevel);
    audio.playWinVibrate();
    _triggerCloudSave();
    notifyListeners();
    return true;
  }

  /// Directly claims all accumulated Royal Treasury orbs for Remove Ads users.
  bool claimTreasuryDirect() {
    if (!isRemoveAdsActive || totalTreasuryOrbs <= 0) return false;
    return _transferTreasuryToBackpack();
  }

  /// Shows a rewarded video ad and transfers all accumulated Royal Treasury orbs
  /// into the player's backpack inside `onUserEarnedReward`, resetting Treasury to 0.
  Future<bool> watchAdToClaimTreasury({VoidCallback? onClaimed}) async {
    if (totalTreasuryOrbs <= 0) return false;
    if (isRemoveAdsActive) {
      final ok = claimTreasuryDirect();
      if (ok) onClaimed?.call();
      return ok;
    }
    if (!adService.isRewardedAdReady) return false;
    bool earned = false;
    final shown = await adService.showRewardedAd(
      onUserEarnedReward: () {
        earned = true;
        _transferTreasuryToBackpack();
        onClaimed?.call();
      },
    );
    return shown && earned;
  }

  void _addOrbInMemory(HandMove move, int delta) {
    switch (move) {
      case HandMove.rock:
        fireOrbs += delta;
        break;
      case HandMove.paper:
        waterOrbs += delta;
        break;
      case HandMove.scissors:
        woodOrbs += delta;
        break;
      case HandMove.lizard:
        earthOrbs += delta;
        break;
      case HandMove.spock:
        metalOrbs += delta;
        break;
    }
  }

  /// Royal Alchemy: atomically transmutes `3 * batches` Elemental Orbs of
  /// [source] into `batches` Elemental Orbs of [target].
  bool transmuteOrbs(HandMove source, HandMove target, {int batches = 1}) {
    if (batches < 1 || source == target || batches > orbsFor(source) ~/ 3) {
      audio.playVibrate();
      return false;
    }

    final sourceCost = 3 * batches;
    final prevTurn0Source = turn0OrbsFor(source);
    final baselineBatches = math.min(prevTurn0Source, sourceCost) ~/ 3;

    _addOrbInMemory(source, -sourceCost);
    _addOrbInMemory(target, batches);

    if (prevTurn0Source >= sourceCost) {
      _adjustTurn0OrbForMove(source, -sourceCost);
    } else {
      _clampTurn0OrbToBalance(source);
    }
    if (baselineBatches > 0) {
      _adjustTurn0OrbForMove(target, baselineBatches);
    }

    _persistOrbsToStorage();
    _persistTurn0OrbsToStorage();
    unawaited(audio.playAlchemyTransmute());
    _triggerCloudSave();
    notifyListeners();
    return true;
  }

  void _adjustTurn0OrbForMove(HandMove move, int delta) {
    switch (move) {
      case HandMove.rock:
        turn0FireOrbs = math.max(0, turn0FireOrbs + delta);
        break;
      case HandMove.paper:
        turn0WaterOrbs = math.max(0, turn0WaterOrbs + delta);
        break;
      case HandMove.scissors:
        turn0WoodOrbs = math.max(0, turn0WoodOrbs + delta);
        break;
      case HandMove.lizard:
        turn0EarthOrbs = math.max(0, turn0EarthOrbs + delta);
        break;
      case HandMove.spock:
        turn0MetalOrbs = math.max(0, turn0MetalOrbs + delta);
        break;
    }
  }

  void _clampTurn0OrbToBalance(HandMove move) {
    switch (move) {
      case HandMove.rock:
        turn0FireOrbs = math.min(turn0FireOrbs, fireOrbs);
        break;
      case HandMove.paper:
        turn0WaterOrbs = math.min(turn0WaterOrbs, waterOrbs);
        break;
      case HandMove.scissors:
        turn0WoodOrbs = math.min(turn0WoodOrbs, woodOrbs);
        break;
      case HandMove.lizard:
        turn0EarthOrbs = math.min(turn0EarthOrbs, earthOrbs);
        break;
      case HandMove.spock:
        turn0MetalOrbs = math.min(turn0MetalOrbs, metalOrbs);
        break;
    }
  }

  void _unlockArtifactWithoutCost(
    ShopUpgradeArtifact artifact, {
    required bool enabled,
    int? staffSpeed,
  }) {
    switch (artifact) {
      case ShopUpgradeArtifact.predictability:
        unlockedPredictability = true;
        showPredictability = enabled;
        storage.setUnlockedPredictability(true);
        storage.setShowPredictability(enabled);
        break;
      case ShopUpgradeArtifact.reset:
        unlockedReset = true;
        showReset = enabled;
        storage.setUnlockedReset(true);
        storage.setShowReset(enabled);
        break;
      case ShopUpgradeArtifact.newHands:
        unlockedNewHands = true;
        showNewHands = enabled;
        storage.setUnlockedNewHands(true);
        storage.setShowNewHands(enabled);
        _grantTreasuryEarthMetalBonusIfNeeded();
        break;
      case ShopUpgradeArtifact.random:
        unlockedRandom = true;
        showRandom = enabled;
        storage.setUnlockedRandom(true);
        storage.setShowRandom(enabled);
        break;
      case ShopUpgradeArtifact.algorithm:
        unlockedAlgorithm = true;
        showAlgorithm = enabled;
        storage.setUnlockedAlgorithm(true);
        storage.setShowAlgorithm(enabled);
        break;
      case ShopUpgradeArtifact.yourPrediction:
        unlockedYourPrediction = true;
        showYourPrediction = enabled;
        storage.setUnlockedYourPrediction(true);
        storage.setShowYourPrediction(enabled);
        break;
      case ShopUpgradeArtifact.nextMove:
        unlockedNextMove = true;
        showNextMove = enabled;
        storage.setUnlockedNextMove(true);
        storage.setShowNextMove(enabled);
        break;
      case ShopUpgradeArtifact.giftBox:
        giftBoxUnlocked = true;
        giftBoxEnabled = enabled;
        storage.setGiftBoxUnlocked(true);
        storage.setGiftBoxEnabled(enabled);
        if (enabled) {
          _resumeGiftTimerIfNeeded();
        } else {
          _pauseGiftTimer();
        }
        break;
      case ShopUpgradeArtifact.suggestion:
        unlockedSuggestion = true;
        showSuggestion = enabled;
        storage.setUnlockedSuggestion(true);
        storage.setShowSuggestion(enabled);
        break;
      case ShopUpgradeArtifact.newSkin:
        unlockedNewSkin = true;
        showNewSkin = enabled;
        storage.setUnlockedNewSkin(true);
        storage.setShowNewSkin(enabled);
        break;
      case ShopUpgradeArtifact.removeAds:
        unlockedAds = true;
        removeAdsEnabled = true;
        storage.setUnlockedAds(true);
        storage.setRemoveAdsEnabled(true);
        adService.setAdsRemoved(true);
        break;
      case ShopUpgradeArtifact.crystalBall:
        unlockedCrystalBall = true;
        showCrystalBall = enabled;
        storage.setUnlockedCrystalBall(true);
        storage.setShowCrystalBall(enabled);
        if (!enabled) {
          showCrystalBallPlus = false;
          storage.setShowCrystalBallPlus(false);
        }
        break;
      case ShopUpgradeArtifact.crystalBallPlus:
        unlockedCrystalBall = true;
        unlockedCrystalBallPlus = true;
        crystalBallPlusSavedState = enabled;
        showCrystalBallPlus = showCrystalBall ? enabled : false;
        storage.setUnlockedCrystalBall(true);
        storage.setUnlockedCrystalBallPlus(true);
        storage.setCrystalBallPlusSavedState(crystalBallPlusSavedState);
        storage.setShowCrystalBallPlus(showCrystalBallPlus);
        break;
      case ShopUpgradeArtifact.markovRecalibrator:
        unlockedMarkovRecalibrator = true;
        showMarkovRecalibrator = enabled;
        storage.setUnlockedMarkovRecalibrator(true);
        storage.setShowMarkovRecalibrator(enabled);
        break;
      case ShopUpgradeArtifact.overchargedStaff:
        final targetLevel = math
            .max(
              overchargedStaffLevel,
              math.max(1, storedRelicOverchargedStaffLevel),
            )
            .clamp(1, overchargedStaffMaxLevel);
        overchargedStaffLevel = targetLevel;
        overchargedStaffEnabled = enabled;
        final resolvedSpeed = (staffSpeed != null &&
                overchargedStaffSpeedOptions.contains(staffSpeed) &&
                overchargedStaffRequiredLevelForSpeed(staffSpeed) <= targetLevel)
            ? staffSpeed
            : overchargedStaffSpeedForLevel(targetLevel);
        overchargedStaffSelectedSpeed = resolvedSpeed;
        storage.setOverchargedStaffLevel(overchargedStaffLevel);
        storage.setOverchargedStaffEnabled(overchargedStaffEnabled);
        storage.setOverchargedStaffSelectedSpeed(overchargedStaffSelectedSpeed);
        break;
    }
  }

  bool _restoreStoredRelics() {
    final toRestore = availableRelicChamberArtifacts.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (toRestore.isEmpty) {
      relicChamberStoredUpgrades = [];
      relicChamberStoredUpgradeStates = {};
      relicChamberStoredOverchargedStaffSpeed = null;
      storage.setRelicChamberUpgrades(const []);
      storage.setRelicChamberUpgradeStates(const {});
      storage.setRelicChamberOverchargedStaffSpeed(null);
      notifyListeners();
      return false;
    }

    final savedStates = <ShopUpgradeArtifact, bool>{
      for (final artifact in toRestore) artifact: isRelicStoredEnabled(artifact),
    };
    final savedStaffSpeed = storedRelicOverchargedStaffSpeed;

    for (final artifact in toRestore) {
      _unlockArtifactWithoutCost(
        artifact,
        enabled: savedStates[artifact] ?? true,
        staffSpeed: artifact == ShopUpgradeArtifact.overchargedStaff
            ? savedStaffSpeed
            : null,
      );
    }

    if (_engine.enableExtendedHands != showNewHands) {
      _engine = MarkovEngine(
        enableExtendedHands: showNewHands,
        enableEnemyExtendedHands: enemyUses5Elements,
        enemyAllowedMoves: bossAllowedMoves,
        enableElementalMode: isElementalMode,
      );
      _resetBattleState();
    } else {
      _engine.enableElementalMode = isElementalMode;
      _computeNextHints();
    }

    relicChamberStoredUpgrades = [];
    relicChamberStoredUpgradeStates = {};
    relicChamberStoredOverchargedStaffSpeed = null;
    storage.setRelicChamberUpgrades(const []);
    storage.setRelicChamberUpgradeStates(const {});
    storage.setRelicChamberOverchargedStaffSpeed(null);
    audio.playWinVibrate();
    _triggerCloudSave();
    notifyListeners();
    return true;
  }

  /// Directly restores stored Relic Chamber artifacts for Remove Ads users.
  bool restoreRelicsDirect() {
    if (!isRemoveAdsActive || !hasAvailableRelicChamberUpgrades) return false;
    return _restoreStoredRelics();
  }

  /// Shows a rewarded video ad and restores all Relic Chamber artifacts,
  /// immediately clearing `relicChamberStoredUpgrades` so they cannot be claimed twice.
  Future<bool> watchAdToRestoreRelics({VoidCallback? onRestored}) async {
    if (!hasAvailableRelicChamberUpgrades) return false;
    if (isRemoveAdsActive) {
      final ok = restoreRelicsDirect();
      if (ok) onRestored?.call();
      return ok;
    }
    if (!adService.isRewardedAdReady) return false;
    bool earned = false;
    final shown = await adService.showRewardedAd(
      onUserEarnedReward: () {
        earned = true;
        _restoreStoredRelics();
        onRestored?.call();
      },
    );
    return shown && earned;
  }

  bool _reclaimStoredSpoils() {
    if (totalSpoilsOfWarOrbs <= 0) return false;
    fireOrbs += spoilsFireOrbs;
    waterOrbs += spoilsWaterOrbs;
    woodOrbs += spoilsWoodOrbs;
    earthOrbs += spoilsEarthOrbs;
    metalOrbs += spoilsMetalOrbs;

    turn0FireOrbs += spoilsFireOrbs;
    turn0WaterOrbs += spoilsWaterOrbs;
    turn0WoodOrbs += spoilsWoodOrbs;
    turn0EarthOrbs += spoilsEarthOrbs;
    turn0MetalOrbs += spoilsMetalOrbs;

    spoilsFireOrbs = 0;
    spoilsWaterOrbs = 0;
    spoilsWoodOrbs = 0;
    spoilsEarthOrbs = 0;
    spoilsMetalOrbs = 0;

    _persistOrbsToStorage();
    _persistTurn0OrbsToStorage();
    _persistSpoilsOrbsToStorage();
    audio.playWinVibrate();
    _triggerCloudSave();
    notifyListeners();
    return true;
  }

  /// Directly reclaims all Spoils of War orbs for Remove Ads users.
  bool reclaimSpoilsDirect() {
    if (!isRemoveAdsActive || !hasSpoilsOfWarOrbs) return false;
    return _reclaimStoredSpoils();
  }

  /// Shows a rewarded video ad and reclaims all Spoils of War orbs back into
  /// the backpack (updating Turn 0 baseline and resetting Spoils to 0).
  Future<bool> watchAdToReclaimSpoils({VoidCallback? onReclaimed}) async {
    if (!hasSpoilsOfWarOrbs) return false;
    if (isRemoveAdsActive) {
      final ok = reclaimSpoilsDirect();
      if (ok) onReclaimed?.call();
      return ok;
    }
    if (!adService.isRewardedAdReady) return false;
    bool earned = false;
    final shown = await adService.showRewardedAd(
      onUserEarnedReward: () {
        earned = true;
        _reclaimStoredSpoils();
        onReclaimed?.call();
      },
    );
    return shown && earned;
  }

  bool _restoreHallOfHeroesBlessings() {
    if (!hasHallOfHeroesBlessings) return false;
    hpUpgradeLevel = math.max(hpUpgradeLevel, peakHpUpgradeLevel);
    manaUpgradeLevel = math.max(manaUpgradeLevel, peakManaUpgradeLevel);
    hallOfHeroesClaimAvailable = false;
    if (!hasGameStarted) {
      userHp = playerMaxHp;
      storage.setUserHp(userHp);
    }
    storage.setHpUpgradeLevel(hpUpgradeLevel);
    storage.setManaUpgradeLevel(manaUpgradeLevel);
    storage.setHallOfHeroesClaimAvailable(false);
    audio.playWinVibrate();
    _triggerCloudSave();
    notifyListeners();
    return true;
  }

  /// Directly restores fallen hero stat blessings for Remove Ads users.
  bool restoreHallOfHeroesDirect() {
    if (!isRemoveAdsActive || !hasHallOfHeroesBlessings) return false;
    return _restoreHallOfHeroesBlessings();
  }

  /// Shows a rewarded video ad and restores the Hall of Heroes HP & Mana
  /// blessings to the current Cleric, immediately clearing the Hall of Heroes
  /// vault to 0 so blessings cannot be duplicated across defeat loops.
  Future<bool> watchAdToRestoreHallOfHeroes({VoidCallback? onRestored}) async {
    if (!hasHallOfHeroesBlessings) return false;
    if (isRemoveAdsActive) {
      final ok = restoreHallOfHeroesDirect();
      if (ok) onRestored?.call();
      return ok;
    }
    if (!adService.isRewardedAdReady) return false;
    bool earned = false;
    final shown = await adService.showRewardedAd(
      onUserEarnedReward: () {
        earned = true;
        _restoreHallOfHeroesBlessings();
        onRestored?.call();
      },
    );
    return shown && earned;
  }

  /// Returns the current 0-indexed turn digit of Pi (`0..9`) used by the
  /// Stage 4 Baby Mage Robot for its upcoming turn (`totalRounds`).
  int get currentPiDigit => piDigitAt(totalRounds);

  /// Returns the dual-element pair (`[spellA, spellB]`) for the Baby Mage Robot's
  /// upcoming turn based on [currentPiDigit].
  List<HandMove> get currentBabyMageDualSpells =>
      dualElementsForPiDigit(currentPiDigit);

  void playTurn(HandMove userChoice, {bool isRapidFire = false}) {
    if (userHp <= 0) {
      isDeathAlertPending = true;
      is100RoundsAlertPending = false;
      audio.playVibrate();
      notifyListeners();
      return;
    }
    if (computerHp <= 0 || isBossVictoryPending) {
      isBossVictoryPending = true;
      is100RoundsAlertPending = false;
      pendingBossVictoryStage ??= enemyStage;
      pendingBossVictoryWeek ??= currentWeek;
      audio.playVibrate();
      notifyListeners();
      return;
    }
    if (totalRounds >= playerMaxMana) {
      is100RoundsAlertPending = true;
      audio.playVibrate();
      notifyListeners();
      return;
    }
    turnCount++;
    _syncEngineEnemyPool();
    final previousMove = lastUserMove;
    currentUserMove = userChoice;

    if (enemyStage == 1) {
      _markBestiaryEncountered(BestiaryCreature.guardianRobot);
    } else if (enemyStage == 2) {
      _markBestiaryEncountered(BestiaryCreature.archmageRobot);
    } else if (enemyStage == 3) {
      _markBestiaryEncountered(BestiaryCreature.metalWizard);
    } else if (enemyStage == 5) {
      _markBestiaryEncountered(BestiaryCreature.templeMaster);
    } else if (enemyStage == 4) {
      _markBestiaryEncountered(BestiaryCreature.babyRobot);
    }

    if (enemyStage == 4 && crystalBallSecondaryMove != null) {
      // Stage 4 Baby Mage Robot: Dual Combined Elemental Spells driven by Pi
      lastRoundBlockedByAntiMetalShield = false;
      currentComputerMove =
          crystalBallMove ?? currentBabyMageDualSpells.first;
      currentSecondaryComputerMove =
          crystalBallSecondaryMove ?? currentBabyMageDualSpells.last;

      final dualRes = DualSpellMatchupResult.evaluate(
        playerMove: currentUserMove!,
        spellA: currentComputerMove!,
        spellB: currentSecondaryComputerMove!,
        elemental: isElementalMode,
      );
      lastDualSpellResult = dualRes;
      lastRoundComputerDamage = dualRes.bossDamage * playerWinDamageToBoss;
      lastRoundUserDamage = dualRes.playerDamage * bossWinDamageToPlayer;

      final orbGain = isHarvestBlessingActive ? 2 : 1;
      for (final defeatedMove in dualRes.defeatedEnemySpells) {
        _incrementOrbForMove(defeatedMove, orbGain);
        _depositTreasuryOrbForMove(defeatedMove, 1);
        decreeDefeatedElements.add(defeatedMove.orbKey);
      }
      if (dualRes.defeatedEnemySpells.isNotEmpty) {
        lastCollectedOrbMoves = List.unmodifiable(dualRes.defeatedEnemySpells);
        lastCollectedOrbMove = dualRes.defeatedEnemySpells.first;
        orbCollectionEventId += 1;
      } else {
        lastCollectedOrbMoves = const [];
      }

      if (dualRes.bossDamage > 0) {
        userScore += 1;
        computerHp =
            (computerHp - lastRoundComputerDamage).clamp(0, enemyMaxHp);
        storage.setUserScore(userScore);
        storage.setPcHp(computerHp);
      }
      if (dualRes.playerDamage > 0) {
        pcScore += 1;
        userHp =
            (userHp - lastRoundUserDamage).clamp(0, effectivePlayerMaxHp);
        storage.setPcScore(pcScore);
        storage.setUserHp(userHp);
      }

      if (dualRes.bossDamage > 0 && dualRes.playerDamage == 0) {
        lastWinner = RoundWinner.user;
        if (previousMove != null && userChoice == previousMove) {
          decreeNoRepeatWinCount = 0;
        } else {
          decreeNoRepeatWinCount += 1;
        }
        decreeWinStreak += 1;
        audio.playWin(vibrate: !isRapidFire, throttleSfx: isRapidFire);
      } else if (dualRes.playerDamage > 0 && dualRes.bossDamage == 0) {
        lastWinner = RoundWinner.computer;
        decreeWinStreak = 0;
        if (previousMove != null && userChoice == previousMove) {
          decreeNoRepeatWinCount = 0;
        }
        audio.playDefeat(vibrate: !isRapidFire, throttleSfx: isRapidFire);
      } else {
        // Simultaneous clash (-1 HP both)
        lastWinner = RoundWinner.draw;
        decreeWinStreak = 0;
        if (previousMove != null && userChoice == previousMove) {
          decreeNoRepeatWinCount = 0;
        }
        audio.playDraw(vibrate: !isRapidFire, throttleSfx: isRapidFire);
      }
      storage.setDecreeNoRepeatWinCount(decreeNoRepeatWinCount);
      storage.setDecreeWinStreak(decreeWinStreak);
      storage.setDecreeDefeatedElements(decreeDefeatedElements.toList());
    } else {
      // Single-element combat (Stages 1, 2, 3, 5, or explicit single crystalBallMove override in tests)
      lastDualSpellResult = null;
      currentSecondaryComputerMove = null;
      currentComputerMove =
          crystalBallMove ?? _chooseComputerMoveForCurrentPhase(previousMove);

      final bool isAntiMetalBlocked =
          enemyStage == 3 && currentUserMove == HandMove.metal;
      lastRoundBlockedByAntiMetalShield = isAntiMetalBlocked;
      final roundOutcome = isAntiMetalBlocked
          ? RoundWinner.draw
          : currentUserMove!.resolvesAgainst(
              currentComputerMove!,
              elemental: isElementalMode,
            );
      if (roundOutcome == RoundWinner.draw) {
        lastWinner = RoundWinner.draw;
        lastRoundUserDamage = 0;
        lastRoundComputerDamage = 0;
        lastCollectedOrbMoves = const [];
        decreeWinStreak = 0;
        if (previousMove != null && userChoice == previousMove) {
          decreeNoRepeatWinCount = 0;
        }
        storage.setDecreeWinStreak(decreeWinStreak);
        storage.setDecreeNoRepeatWinCount(decreeNoRepeatWinCount);
        audio.playDraw(vibrate: !isRapidFire, throttleSfx: isRapidFire);
      } else if (roundOutcome == RoundWinner.user) {
        lastWinner = RoundWinner.user;
        lastRoundUserDamage = 0;
        lastRoundComputerDamage = playerWinDamageToBoss;
        userScore += 1;
        final orbGain = isHarvestBlessingActive ? 2 : 1;
        _incrementOrbForMove(currentComputerMove!, orbGain);
        _depositTreasuryOrbForMove(currentComputerMove!, 1);
        lastCollectedOrbMove = currentComputerMove;
        lastCollectedOrbMoves = [currentComputerMove!];
        orbCollectionEventId += 1;
        computerHp = (computerHp - playerWinDamageToBoss).clamp(0, enemyMaxHp);
        storage.setUserScore(userScore);
        storage.setPcHp(computerHp);

        if (previousMove != null && userChoice == previousMove) {
          decreeNoRepeatWinCount = 0;
        } else {
          decreeNoRepeatWinCount += 1;
        }
        decreeWinStreak += 1;
        decreeDefeatedElements.add(currentComputerMove!.orbKey);
        storage.setDecreeNoRepeatWinCount(decreeNoRepeatWinCount);
        storage.setDecreeWinStreak(decreeWinStreak);
        storage.setDecreeDefeatedElements(decreeDefeatedElements.toList());

        audio.playWin(vibrate: !isRapidFire, throttleSfx: isRapidFire);
      } else {
        lastWinner = RoundWinner.computer;
        lastRoundUserDamage = bossWinDamageToPlayer;
        lastRoundComputerDamage = 0;
        lastCollectedOrbMoves = const [];
        pcScore += 1;
        userHp = (userHp - bossWinDamageToPlayer).clamp(0, effectivePlayerMaxHp);
        storage.setPcScore(pcScore);
        storage.setUserHp(userHp);
        decreeWinStreak = 0;
        if (previousMove != null && userChoice == previousMove) {
          decreeNoRepeatWinCount = 0;
        }
        storage.setDecreeWinStreak(decreeWinStreak);
        storage.setDecreeNoRepeatWinCount(decreeNoRepeatWinCount);
        audio.playDefeat(vibrate: !isRapidFire, throttleSfx: isRapidFire);
      }

      if (enemyStage == 3) {
        _metalWizardAiState.resolveTurn(roundOutcome);
        storage.setMetalWizardAiState(_metalWizardAiState.toJson());
      }
    }

    if (isRapidFire) {
      audio.playRapidFireHaptic();
    }

    totalRounds += 1;
    storage.setTotal(totalRounds);

    // Record transition into cumulative Markov matrix and 1-step short-term map
    _engine.recordTransition(lastUserMove, currentUserMove!);
    storage.setMarkovMatrix(_engine.matrix);
    storage.setShortTermTransitions(_engine.serializedLastTransitions);
    lastUserMove = currentUserMove;
    storage.setLastUserMove(currentUserMove);
    storage.setLastComputerMove(currentComputerMove);

    _evaluateRoyalDecrees();

    if (userHp <= 0) {
      isDeathAlertPending = true;
      is100RoundsAlertPending = false;
      isBossVictoryPending = false;
    } else if (computerHp <= 0) {
      isBossVictoryPending = true;
      is100RoundsAlertPending = false;
      pendingBossVictoryStage = enemyStage;
      pendingBossVictoryWeek = currentWeek;
      _applyImmediateBossDefeatMetadata(enemyStage, currentWeek);
      audio.playWinVibrate();
      audio.playStoryChime();
    } else if (totalRounds >= playerMaxMana) {
      is100RoundsAlertPending = true;
    }

    if (lastWinner == RoundWinner.user ||
        lastRoundComputerDamage > 0 ||
        computerHp <= 0 ||
        totalRounds >= playerMaxMana) {
      _triggerCloudSave();
    }

    _computeNextHints();
    notifyListeners();
  }

  HandMove _chooseComputerMoveForCurrentPhase(HandMove? previousMove) {
    _syncEngineEnemyPool();
    if (enemyStage == 5) {
      // Stage 5 Temple High Master: pure uniform random (1/5 per element).
      return _engine.getRandomEnemyMove();
    }
    if (enemyStage == 4) {
      // Stage 4 Baby Mage Robot: deterministic Pi sequence dual spell (first spell).
      return currentBabyMageDualSpells.first;
    }
    if (enemyStage == 3) {
      // Stage 3 Metal Wizard: deterministic adaptive state machine using Metal & Earth.
      return _metalWizardAiState.currentMove;
    }
    if (enemyStage == 2) {
      // Stage 2 Robot Archmage: 1-step short-term memory counter if available.
      if (_engine.hasShortTermPrediction(previousMove)) {
        return _engine.computeShortTermSmartChoice(previousMove);
      }
      return _engine.getRandomEnemyMove();
    }
    // Stage 1 Guardian Robot: standard cumulative Markov prediction,
    // strictly restricted to [Fire, Water, Wood].
    if (_engine.hasPrediction(previousMove)) {
      return _engine.computeSmartChoice(previousMove);
    }
    return _engine.getRandomEnemyMove();
  }

  void _recordFastestVictoryWeek(int week) {
    final effectiveWeek = week < 0 ? 0 : week;
    fastestVictoryWeek = fastestVictoryWeek == null
        ? effectiveWeek
        : math.min(fastestVictoryWeek!, effectiveWeek);
    storage.setFastestVictoryWeek(fastestVictoryWeek);
  }

  void _applyImmediateBossDefeatMetadata(int defeatedStage, int week) {
    if (defeatedStage == 1) {
      guardianRobotDefeatedCount += 1;
      storage.setGuardianRobotDefeatedCount(guardianRobotDefeatedCount);
      if (week >= phase2StartWeek) {
        _markBestiaryEncountered(BestiaryCreature.archmageRobot);
      } else {
        _markBestiaryEncountered(BestiaryCreature.metalWizard);
      }
    } else if (defeatedStage == 2) {
      robotArchmageDefeatedCount += 1;
      storage.setRobotArchmageDefeatedCount(robotArchmageDefeatedCount);
      _markBestiaryEncountered(BestiaryCreature.metalWizard);
    } else if (defeatedStage == 3) {
      metalWizardDefeatedCount += 1;
      storage.setMetalWizardDefeatedCount(metalWizardDefeatedCount);
      if (week == 0) {
        _markEndingUnlocked(NarrativeEnding.secretWeek1);
        secretVictoryCount += 1;
        totalCyclesCount += 1;
        storage.setSecretVictoryCount(secretVictoryCount);
        storage.setTotalCyclesCount(totalCyclesCount);
        _recordFastestVictoryWeek(0);
      } else {
        _markBestiaryEncountered(BestiaryCreature.templeMaster);
      }
    } else if (defeatedStage == 5) {
      templeMasterDefeatedCount += 1;
      storage.setTempleMasterDefeatedCount(templeMasterDefeatedCount);
      _markBestiaryEncountered(BestiaryCreature.babyRobot);
    } else if (defeatedStage == 4) {
      babyMageRobotDefeatedCount += 1;
      storage.setBabyMageRobotDefeatedCount(babyMageRobotDefeatedCount);
      _markEndingUnlocked(NarrativeEnding.standardVictory);
      standardVictoryCount += 1;
      totalCyclesCount += 1;
      storage.setStandardVictoryCount(standardVictoryCount);
      storage.setTotalCyclesCount(totalCyclesCount);
      _recordFastestVictoryWeek(week);
    }
  }

  /// Accepts the Temple High Master's decree after defeating the Metal Wizard
  /// at `currentWeek >= 1`, unlocking **Ending: The Sacred Sacrifice** and
  /// resetting the campaign cycle via [applyPermadeathReset].
  Future<void> acceptSacredSacrifice() async {
    isBossVictoryPending = false;
    pendingBossVictoryStage = null;
    pendingBossVictoryWeek = null;
    await applyPermadeathReset(cause: PermadeathCause.sacredSacrifice);
  }

  /// Flees the Sacred Temple via Teleport during the Baby Mage Robot final battle,
  /// unlocking **Ending: The Deserter** and resetting the campaign cycle.
  Future<void> triggerDeserterEnding() async {
    isBossVictoryPending = false;
    pendingBossVictoryStage = null;
    pendingBossVictoryWeek = null;
    await applyPermadeathReset(cause: PermadeathCause.deserter);
  }

  /// Advances the campaign state after the user confirms the Boss Defeated modal
  /// (and any ending cutscene). Returns `true` if the campaign cycle concluded
  /// (Secret Week-0 Ending on Stage 3 in Week 0, or Stage 4 Standard Victory Ending)
  /// so the caller can return to the World Map.
  bool advanceAfterBossVictory() {
    final defeatedStage = pendingBossVictoryStage ?? enemyStage;
    final week = pendingBossVictoryWeek ?? currentWeek;
    isBossVictoryPending = false;
    pendingBossVictoryStage = null;
    pendingBossVictoryWeek = null;

    final bool concludesCycle =
        (defeatedStage == 3 && week == 0) || defeatedStage == 4;
    if (concludesCycle) {
      enemyStage = 1;
      enemyMaxHp = pcMaxHp;
      currentWeek = 0;
      adConsagrationsThisWeek = 0;
      activeBattleBlessing = null;
      battleBonusTempHp = 0;
      hasShownWeek0ScreamWarning = false;
      pendingWeek0ScreamWarning = false;
      hasInspectedPrincessCellAfterScream = false;
      storage.setEnemyStage(1);
      storage.setEnemyMaxHp(pcMaxHp);
      storage.setCurrentWeek(0);
      storage.setAdConsagrationsThisWeek(0);
      storage.setActiveBattleBlessing(null);
      storage.setBattleBonusTempHp(0);
      storage.setHasShownWeek0ScreamWarning(false);
      storage.setPendingWeek0ScreamWarning(false);
      storage.setHasInspectedPrincessCellAfterScream(false);
      _refreshCompletedDecreesAndResetBattleTrackers();
      _resetBattleState();
      recordTurn0OrbSnapshot();
      _triggerCloudSave();
      notifyListeners();
      return true;
    }

    if (defeatedStage == 1) {
      if (week >= phase2StartWeek) {
        enemyStage = 2;
        _markBestiaryEncountered(BestiaryCreature.archmageRobot);
      } else {
        enemyStage = 3;
        _markBestiaryEncountered(BestiaryCreature.metalWizard);
      }
    } else if (defeatedStage == 2) {
      enemyStage = 3;
      _markBestiaryEncountered(BestiaryCreature.metalWizard);
    } else if (defeatedStage == 3) {
      // Post-Week-0 Metal Wizard victory -> Refuse Sacrifice -> Stage 5 Temple High Master (350 HP)
      enemyStage = 5;
      _markBestiaryEncountered(BestiaryCreature.templeMaster);
    } else if (defeatedStage == 5) {
      // Defeating Temple High Master -> Sanctuary Altar restores HP & Mana to 100%,
      // and transitions to Stage 4 Baby Mage Robot (400 HP).
      enemyStage = 4;
      _markBestiaryEncountered(BestiaryCreature.babyRobot);
    } else {
      enemyStage = 4;
      _markBestiaryEncountered(BestiaryCreature.babyRobot);
    }
    enemyMaxHp = maxHpForEnemyStage(enemyStage);
    storage.setEnemyStage(enemyStage);
    storage.setEnemyMaxHp(enemyMaxHp);
    _refreshCompletedDecreesAndResetBattleTrackers();
    _resetBattleState();
    recordTurn0OrbSnapshot();
    _triggerCloudSave();
    notifyListeners();
    return false;
  }

  void playRandom({bool isRapidFire = false}) {
    final randMove = _engine.getRandomMove();
    playTurn(randMove, isRapidFire: isRapidFire);
  }

  List<HandMove> _computeMetalWizardCounters(HandMove upcomingMove) {
    final counters = <HandMove>[];
    for (final m in _engine.activeMoves) {
      if (m == HandMove.metal) continue;
      if (m.beats(upcomingMove, elemental: isElementalMode) &&
          !counters.contains(m)) {
        counters.add(m);
      }
    }
    return List.unmodifiable(counters);
  }

  void _computeNextHints() {
    _syncEngineEnemyPool();

    if (enemyStage == 5) {
      // Stage 5 Temple High Master: pure uniform random (1/5 per element).
      crystalBallMove = _chooseComputerMoveForCurrentPhase(lastUserMove);
      crystalBallSecondaryMove = null;
      predictedUserMoves = const [];
      pcNextMoves = const [];
      suggestedMoves = const [];
      predictedUserMove = null;
      pcNextMove = null;
      suggestedMove = null;
      return;
    }

    if (enemyStage == 4) {
      // Stage 4 Baby Mage Robot: deterministic Pi sequence dual elemental spells.
      final dualSpells = currentBabyMageDualSpells;
      _crystalBallMove = dualSpells.first;
      crystalBallSecondaryMove = dualSpells.last;
      predictedUserMoves = _engine.predictNextUserMoves(lastUserMove);
      pcNextMoves = List.unmodifiable(dualSpells);
      suggestedMoves = optimalCountersForDualSpells(
        dualSpells,
        _engine.activeMoves,
        elemental: isElementalMode,
      );
      predictedUserMove =
          predictedUserMoves.isNotEmpty ? predictedUserMoves.first : null;
      pcNextMove = dualSpells.first;
      suggestedMove = suggestedMoves.isNotEmpty ? suggestedMoves.first : null;
      return;
    }

    _crystalBallMove = _chooseComputerMoveForCurrentPhase(lastUserMove);
    crystalBallSecondaryMove = null;

    if (enemyStage == 3) {
      // Stage 3 Metal Wizard: exact upcoming move from MetalWizardAiState.
      final upcomingMove = _metalWizardAiState.currentMove;
      _crystalBallMove = upcomingMove;
      predictedUserMoves = _engine.predictNextUserMoves(lastUserMove);
      pcNextMoves = [upcomingMove];
      suggestedMoves = _computeMetalWizardCounters(upcomingMove);
      predictedUserMove =
          predictedUserMoves.isNotEmpty ? predictedUserMoves.first : null;
      pcNextMove = upcomingMove;
      suggestedMove = suggestedMoves.isNotEmpty ? suggestedMoves.first : null;
      return;
    }

    if (enemyStage == 2 && isMarkovRecalibratorActive) {
      predictedUserMoves =
          _engine.predictShortTermNextUserMoves(lastUserMove);
      pcNextMoves = _engine.computeShortTermSmartChoices(lastUserMove);
      suggestedMoves = _engine.computeSuggestions(pcNextMoves);
      predictedUserMove =
          predictedUserMoves.isNotEmpty ? predictedUserMoves.first : null;
      pcNextMove = crystalBallMove;
      suggestedMove = suggestedMoves.isNotEmpty ? suggestedMoves.first : null;
      return;
    }

    // Standard cumulative frequency hints (used for Stage 1 AND as the
    // deceptive un-recalibrated view during Stage 2 Robot Archmage).
    predictedUserMoves = _engine.predictNextUserMoves(lastUserMove);
    pcNextMoves = _engine.computeSmartChoices(lastUserMove);
    suggestedMoves = _engine.computeSuggestions(pcNextMoves);

    predictedUserMove =
        predictedUserMoves.isNotEmpty ? predictedUserMoves.first : null;
    pcNextMove = (enemyStage == 2)
        ? (pcNextMoves.isNotEmpty ? pcNextMoves.first : null)
        : crystalBallMove;
    suggestedMove = suggestedMoves.isNotEmpty ? suggestedMoves.first : null;
  }

  void _resetBattleState() {
    userScore = 0;
    pcScore = 0;
    totalRounds = 0;
    turnCount = 0;
    currentUserMove = null;
    currentComputerMove = null;
    currentSecondaryComputerMove = null;
    lastUserMove = null;
    lastWinner = null;
    lastDualSpellResult = null;
    lastRoundBlockedByAntiMetalShield = false;
    lastRoundUserDamage = 0;
    lastRoundComputerDamage = 0;
    lastCollectedOrbMove = null;
    lastCollectedOrbMoves = const [];
    userHp = effectivePlayerMaxHp;
    enemyMaxHp = maxHpForEnemyStage(enemyStage);
    computerHp = enemyMaxHp;
    is100RoundsAlertPending = false;
    isDeathAlertPending = false;
    isBossVictoryPending = false;
    pendingBossVictoryStage = null;
    pendingBossVictoryWeek = null;
    _metalWizardAiState.reset();
    _syncEngineEnemyPool();
    _engine.reset();

    storage.clearGameStats(
      userMaxHp: effectivePlayerMaxHp,
      pcMaxHp: enemyMaxHp,
    );
    storage.setEnemyStage(enemyStage);
    storage.setEnemyMaxHp(enemyMaxHp);
    storage.setUserHp(effectivePlayerMaxHp);
    storage.setPcHp(enemyMaxHp);
    _computeNextHints();
  }

  /// Rewinds the active battle back to Turn 0: restores HP (`effectivePlayerMaxHp`), Mana (`playerMaxMana`),
  /// scores (`0`), clears the Markov matrix and last-played hands, reverts
  /// Elemental Orbs back to the Turn 0 Orb Snapshot (recording the lost
  /// battle/gift orbs into Spoils of War while preserving Rewarded Ad `+50` orbs),
  /// and syncs with [StorageService] and [PlayGamesService].
  void resetGame() {
    final lostFire = lostOrbsFor(HandMove.rock);
    final lostWater = lostOrbsFor(HandMove.paper);
    final lostWood = lostOrbsFor(HandMove.scissors);
    final lostEarth = lostOrbsFor(HandMove.lizard);
    final lostMetal = lostOrbsFor(HandMove.spock);

    if (lostFire + lostWater + lostWood + lostEarth + lostMetal > 0) {
      spoilsFireOrbs += lostFire;
      spoilsWaterOrbs += lostWater;
      spoilsWoodOrbs += lostWood;
      spoilsEarthOrbs += lostEarth;
      spoilsMetalOrbs += lostMetal;
      _persistSpoilsOrbsToStorage();
    }

    fireOrbs = turn0FireOrbs;
    waterOrbs = turn0WaterOrbs;
    woodOrbs = turn0WoodOrbs;
    earthOrbs = turn0EarthOrbs;
    metalOrbs = turn0MetalOrbs;
    _persistOrbsToStorage();
    _persistTurn0OrbsToStorage();
    _refreshCompletedDecreesAndResetBattleTrackers();
    _resetBattleState();
    _triggerCloudSave();
    notifyListeners();
  }

  /// Starts a fresh battle ([playerMaxMana] Mana, [effectivePlayerMaxHp] HP) from the World Map while
  /// promoting any pending Sacred Blessing into the active expedition buff,
  /// preserving Elemental Orbs, shop unlocks, and campaign week progress,
  /// and recording the Turn 0 Orb Snapshot for the new battle.
  void startNewBattle() {
    activeBattleBlessing = pendingBattleBlessing;
    pendingBattleBlessing = null;
    battleBonusTempHp = activeBattleBlessing == SacredBlessing.vitality
        ? vitalityBlessingBonusHp
        : 0;
    storage.setActiveBattleBlessing(activeBattleBlessing?.id);
    storage.setPendingBattleBlessing(null);
    storage.setBattleBonusTempHp(battleBonusTempHp);
    _refreshCompletedDecreesAndResetBattleTrackers();
    _resetBattleState();
    recordTurn0OrbSnapshot();
    _triggerCloudSave();
    notifyListeners();
  }

  /// Consumes [pendingWeek0ScreamWarning] and marks [hasShownWeek0ScreamWarning]
  /// as `true` so the post-Week-0 Watch Tower alert carousel shows at most once
  /// per campaign cycle.
  bool consumePendingWeek0ScreamWarning() {
    if (!shouldShowWeek0ScreamWarning) return false;
    pendingWeek0ScreamWarning = false;
    hasShownWeek0ScreamWarning = true;
    storage.setPendingWeek0ScreamWarning(false);
    storage.setHasShownWeek0ScreamWarning(true);
    _triggerCloudSave();
    notifyListeners();
    return true;
  }

  /// Marks the Princess's Cell spyglass as inspected after the Week 0 scream
  /// warning has been shown, clearing the Watch Tower `"!"` alert badge for
  /// the remainder of the current run.
  void markPrincessCellInspectedAfterScream() {
    if (!hasShownWeek0ScreamWarning || hasInspectedPrincessCellAfterScream) {
      return;
    }
    hasInspectedPrincessCellAfterScream = true;
    storage.setHasInspectedPrincessCellAfterScream(true);
    _triggerCloudSave();
    notifyListeners();
  }

  /// Advances the campaign calendar by +1 Week upon exiting a battle via
  /// battle completion or Teleport, persists locally, resets weekly ad
  /// consagrations and active battle blessings, resets the battle arena for
  /// the next encounter while keeping collected Elemental Orbs, and syncs Cloud Save.
  void completeBattleWeek() {
    final wasWeek0 = currentWeek == 0;
    currentWeek += 1;
    adConsagrationsThisWeek = 0;
    activeBattleBlessing = null;
    battleBonusTempHp = 0;
    if (wasWeek0 && !hasShownWeek0ScreamWarning) {
      pendingWeek0ScreamWarning = true;
      storage.setPendingWeek0ScreamWarning(true);
    }
    storage.setCurrentWeek(currentWeek);
    storage.setAdConsagrationsThisWeek(0);
    storage.setActiveBattleBlessing(null);
    storage.setBattleBonusTempHp(0);
    _refreshCompletedDecreesAndResetBattleTrackers();
    _resetBattleState();
    recordTurn0OrbSnapshot();
    _triggerCloudSave();
    notifyListeners();
  }

  /// Teleports the cleric back to the World Map, preserving all collected
  /// Elemental Orbs, resetting the active battle ([playerMaxMana] Mana / [playerMaxHp] HP / 0 rounds),
  /// advancing +1 Week via [completeBattleWeek], and syncing local/cloud saves.
  void teleportToWorldMap() {
    completeBattleWeek();
  }

  /// Advances the campaign calendar into Week 41 ([siegeInvasionWeek]) when
  /// Week 40 expires, revealing the besieged Sacred Capital state before
  /// Ending 2 (Invasion) permadeath reset is confirmed.
  void enterSiegeInvasionWeek() {
    currentWeek = siegeInvasionWeek;
    unawaited(storage.setCurrentWeek(siegeInvasionWeek));
    notifyListeners();
  }

  /// Revives the Cleric after watching a rewarded video ad upon death:
  /// restores HP and battle Mana to [playerMaxHp] / [playerMaxMana], keeps all Elemental Orbs collected,
  /// preserves unlocks and current campaign week, persists & syncs to Cloud Save.
  void reviveAndRetreatToMap() {
    activeBattleBlessing = null;
    battleBonusTempHp = 0;
    storage.setActiveBattleBlessing(null);
    storage.setBattleBonusTempHp(0);
    _resetBattleState();
    recordTurn0OrbSnapshot();
    _triggerCloudSave();
    notifyListeners();
  }

  /// Displays the preloaded rewarded video ad when the player chooses to revive
  /// after reaching 0 HP. Restores HP/Mana and keeps earned orbs exclusively
  /// inside `onUserEarnedReward`, invoking [onRevived] upon completion.
  Future<bool> watchReviveRewardedAd({VoidCallback? onRevived}) async {
    if (!isReviveAdReady) return false;
    bool earned = false;
    final shown = await adService.showRewardedAd(
      onUserEarnedReward: () {
        earned = true;
        reviveAndRetreatToMap();
        onRevived?.call();
      },
    );
    return shown && earned;
  }

  /// Centralized permadeath hard reset used by both unrevived death (HP == 0)
  /// and Week > 40 Kingdom Fall defeat:
  /// 1. Snapshots lost orbs into Spoils of War, lost orb-bought upgrades into
  ///    Relic Chamber, accumulated HP/Mana stat levels into Hall of Heroes, and
  ///    records the Kingdom Fall narrative ending.
  /// 2. Resets campaign week to 0 (Week 0 / 40).
  /// 3. Wipes all 5 Elemental Orb balances & Turn 0 snapshots & turn stats to 0.
  /// 4. Locks all orb-bought upgrades & artifacts EXCEPT real-money Google Play
  ///    IAP purchases persisted in [StorageService] or verified by [BillingService].
  /// 5. Resets HP/Mana to base (50 HP / 100 Mana), clears the Markov matrix,
  ///    persists locally, and overwrites Cloud Save so old cloud data cannot revert
  ///    the Week 0 reset.
  Future<void> applyPermadeathReset({PermadeathCause? cause}) async {
    _giftTimer?.cancel();
    _giftTimer = null;
    _giftCooldownUntil = null;
    _remainingGiftCooldown = Duration.zero;
    isGiftAvailable = true;

    final resolvedCause = cause ??
        (currentWeek >= maxCampaignWeeks && userHp > 0
            ? PermadeathCause.deadlineExceeded
            : (enemyStage == 5
                ? PermadeathCause.sacredSacrifice
                : PermadeathCause.battleDefeat));

    final nextTotalCycles = totalCyclesCount + 1;
    final nextDeathDefeats = resolvedCause == PermadeathCause.battleDefeat
        ? deathDefeatCount + 1
        : deathDefeatCount;
    final nextTimeoutDefeats =
        resolvedCause == PermadeathCause.deadlineExceeded
            ? timeoutDefeatCount + 1
            : timeoutDefeatCount;
    final nextSacrifices = resolvedCause == PermadeathCause.sacredSacrifice
        ? sacredSacrificeCount + 1
        : sacredSacrificeCount;
    final nextDeserters = resolvedCause == PermadeathCause.deserter
        ? deserterCount + 1
        : deserterCount;

    final verifiedPaidIds = <String>{
      ...storage.purchasedIapProductIds,
      ...billingService.verifiedPurchasedProductIds,
    };
    final preservedHasSeenIntro =
        hasSeenStoryIntro || storage.hasSeenStoryIntro;

    // 1. Snapshot lost orbs into Spoils of War
    final updatedSpoilsFire = spoilsFireOrbs + fireOrbs;
    final updatedSpoilsWater = spoilsWaterOrbs + waterOrbs;
    final updatedSpoilsWood = spoilsWoodOrbs + woodOrbs;
    final updatedSpoilsEarth = spoilsEarthOrbs + earthOrbs;
    final updatedSpoilsMetal = spoilsMetalOrbs + metalOrbs;

    // 2. Snapshot lost orb-bought upgrades & active states into Relic Chamber (excluding paid IAPs)
    final lostUpgrades = _collectLostRelicIds(verifiedPaidIds);
    final lostUpgradeStates = _collectLostRelicStates(verifiedPaidIds);
    final nextRelicUpgrades = lostUpgrades.isNotEmpty
        ? _mergeRelicUpgradeIds(relicChamberStoredUpgrades, lostUpgrades)
        : List<String>.from(relicChamberStoredUpgrades);
    final nextRelicStates = lostUpgrades.isNotEmpty
        ? <String, bool>{
            ...relicChamberStoredUpgradeStates,
            ...lostUpgradeStates,
          }
        : Map<String, bool>.from(relicChamberStoredUpgradeStates);
    final int? nextRelicStaffSpeed;
    if (lostUpgrades.isEmpty) {
      nextRelicStaffSpeed = relicChamberStoredOverchargedStaffSpeed;
    } else if (lostUpgradeStates.containsKey(
      ShopUpgradeArtifact.overchargedStaff.id,
    )) {
      nextRelicStaffSpeed = overchargedStaffLevel >= storedRelicOverchargedStaffLevel
          ? overchargedStaffSelectedSpeed
          : relicChamberStoredOverchargedStaffSpeed;
    } else {
      nextRelicStaffSpeed = relicChamberStoredOverchargedStaffSpeed;
    }

    // 2b. Preserve independent all-time historical peaks and unlock Hall of Heroes claim for the next cycle
    final nextPeakHp = math.max(peakHpUpgradeLevel, hpUpgradeLevel);
    final nextPeakMana = math.max(peakManaUpgradeLevel, manaUpgradeLevel);
    final nextClaimAvailable = nextPeakHp > 0 || nextPeakMana > 0;

    // 3. Record corresponding narrative ending
    final NarrativeEnding unlockedEnding;
    switch (resolvedCause) {
      case PermadeathCause.sacredSacrifice:
        unlockedEnding = NarrativeEnding.sacredSacrifice;
        break;
      case PermadeathCause.deserter:
        unlockedEnding = NarrativeEnding.theDeserter;
        break;
      case PermadeathCause.deadlineExceeded:
        unlockedEnding = NarrativeEnding.invasionTimeout;
        break;
      case PermadeathCause.battleDefeat:
        unlockedEnding = NarrativeEnding.kingdomFall;
        break;
    }
    final nextEndings = <String>{
      ...unlockedEndings,
      unlockedEnding.id,
    }.toList();

    final preservedRemoveAdsOwned = unlockedAds || storage.unlockedAds;
    final preservedRemoveAdsEnabled = preservedRemoveAdsOwned
        ? (storage.hasRemoveAdsEnabledPreference
              ? storage.removeAdsEnabled
              : removeAdsEnabled)
        : false;
    final preservedHasExplicitRemoveAdsToggle =
        preservedRemoveAdsOwned || storage.hasRemoveAdsEnabledPreference;

    await storage.clearGameplayProgress(
      includeSettings: false,
      includeCastleMeta: false,
      preserveRemoveAds: true,
    );
    await storage.clearBattleDecreeProgress();
    await storage.setAllSpoilsOrbs(
      fire: updatedSpoilsFire,
      water: updatedSpoilsWater,
      wood: updatedSpoilsWood,
      earth: updatedSpoilsEarth,
      metal: updatedSpoilsMetal,
    );
    await storage.setRelicChamberUpgrades(nextRelicUpgrades);
    await storage.setRelicChamberUpgradeStates(nextRelicStates);
    await storage.setRelicChamberOverchargedStaffSpeed(nextRelicStaffSpeed);
    await storage.setPeakHpUpgradeLevel(nextPeakHp);
    await storage.setPeakManaUpgradeLevel(nextPeakMana);
    await storage.setHallOfHeroesClaimAvailable(nextClaimAvailable);
    await storage.setUnlockedEndings(nextEndings);
    await storage.setTotalCyclesCount(nextTotalCycles);
    await storage.setDeathDefeatCount(nextDeathDefeats);
    await storage.setTimeoutDefeatCount(nextTimeoutDefeats);
    await storage.setSacredSacrificeCount(nextSacrifices);
    await storage.setDeserterCount(nextDeserters);
    await storage.setTurn0Orbs(
      fire: 0,
      water: 0,
      wood: 0,
      earth: 0,
      metal: 0,
    );
    await storage.setPurchasedIapProductIds(verifiedPaidIds);
    await storage.setCurrentWeek(0);
    if (preservedHasSeenIntro) {
      await storage.setHasSeenStoryIntro(true);
    }
    if (preservedRemoveAdsOwned) {
      await storage.setUnlockedAds(true);
      if (preservedHasExplicitRemoveAdsToggle) {
        await storage.setRemoveAdsEnabled(preservedRemoveAdsEnabled);
      }
    }

    turnCount = 0;
    lastCollectedOrbMove = null;
    is100RoundsAlertPending = false;
    isDeathAlertPending = false;
    isBossVictoryPending = false;
    pendingBossVictoryPhase = null;
    pendingBossVictoryWeek = null;

    _loadState(restartAudio: false);

    for (final productId in verifiedPaidIds) {
      unlockByProductId(
        productId,
        recordAsIap: false,
        triggerStory: false,
        triggerCloudSave: false,
      );
    }

    notifyListeners();
    if (playGames.isSignedIn) {
      await playGames.saveCloudData();
    }
  }

  List<String> _collectLostRelicIds(Set<String> verifiedPaidIds) {
    final lostUpgrades = <String>[];
    for (final artifact in ShopUpgradeArtifact.values) {
      if (artifact == ShopUpgradeArtifact.removeAds) continue;
      if (!isUpgradeArtifactUnlocked(artifact)) continue;
      final productId = _productIdForArtifact(artifact);
      if (productId != null && verifiedPaidIds.contains(productId)) {
        continue;
      }
      if (artifact == ShopUpgradeArtifact.overchargedStaff) {
        lostUpgrades.add(
          ShopUpgradeArtifact.overchargedStaffRelicId(overchargedStaffLevel),
        );
      } else {
        lostUpgrades.add(artifact.id);
      }
    }
    return lostUpgrades;
  }

  Map<String, bool> _collectLostRelicStates(Set<String> verifiedPaidIds) {
    final states = <String, bool>{};
    for (final artifact in ShopUpgradeArtifact.values) {
      if (artifact == ShopUpgradeArtifact.removeAds) continue;
      if (!isUpgradeArtifactUnlocked(artifact)) continue;
      final productId = _productIdForArtifact(artifact);
      if (productId != null && verifiedPaidIds.contains(productId)) {
        continue;
      }
      states[artifact.id] = isUpgradeArtifactEnabled(artifact);
    }
    return states;
  }

  List<String> _mergeRelicUpgradeIds(
    List<String> existing,
    List<String> incoming,
  ) {
    final merged = <String>{};
    int maxStaffLevel = 0;
    for (final raw in [...existing, ...incoming]) {
      final clean = raw.trim();
      if (clean.isEmpty || clean == ShopUpgradeArtifact.removeAds.id) continue;
      final staffLvl = ShopUpgradeArtifact.parseOverchargedStaffLevel(clean);
      if (staffLvl != null) {
        if (staffLvl > maxStaffLevel) maxStaffLevel = staffLvl;
      } else {
        merged.add(clean);
      }
    }
    if (maxStaffLevel > 0) {
      merged.add(ShopUpgradeArtifact.overchargedStaffRelicId(maxStaffLevel));
    }
    return merged.toList()..sort();
  }

  /// Archives the active run's lost artifacts/power-ups into the Royal Castle's
  /// Relic Chamber, active Elemental Orbs into Spoils of War, and all-time peak
  /// HP/Mana stat levels into the Hall of Heroes (never lowering a previously
  /// achieved peak), then resets the campaign back to Week 0 / Turn 0 while
  /// preserving global account data (unlocked story cutscenes, Library endings
  /// & bestiary, Hall of Heroes records, Royal Treasury, Vow of Silence /
  /// Remove Ads ownership & toggle state, verified real-money IAPs, and UI
  /// settings) and syncing with Cloud Save.
  Future<void> resetAllProgress() async {
    _giftTimer?.cancel();
    _giftTimer = null;
    _giftCooldownUntil = null;
    _remainingGiftCooldown = Duration.zero;
    isGiftAvailable = true;

    final nextTotalCycles = totalCyclesCount + 1;
    final nextForfeitRuns = forfeitRunCount + 1;

    final verifiedPaidIds = <String>{
      ...storage.purchasedIapProductIds,
      ...billingService.verifiedPurchasedProductIds,
    };
    final preservedRemoveAdsOwned = unlockedAds || storage.unlockedAds;
    final preservedRemoveAdsEnabled = preservedRemoveAdsOwned
        ? (storage.hasRemoveAdsEnabledPreference
              ? storage.removeAdsEnabled
              : removeAdsEnabled)
        : false;
    final preservedHasExplicitRemoveAdsToggle =
        preservedRemoveAdsOwned || storage.hasRemoveAdsEnabledPreference;

    // 1. Archive active Elemental Orbs into Spoils of War (Double-Reset Guard)
    final hasActiveOrbs = totalOrbs > 0;
    final updatedSpoilsFire = spoilsFireOrbs + fireOrbs;
    final updatedSpoilsWater = spoilsWaterOrbs + waterOrbs;
    final updatedSpoilsWood = spoilsWoodOrbs + woodOrbs;
    final updatedSpoilsEarth = spoilsEarthOrbs + earthOrbs;
    final updatedSpoilsMetal = spoilsMetalOrbs + metalOrbs;

    // 2. Archive owned shop artifacts & power-ups (and active states) into Relic Chamber (excluding paid IAPs & Remove Ads)
    //    (Double-Reset Guard: only update if active run has owned artifacts)
    final lostUpgrades = _collectLostRelicIds(verifiedPaidIds);
    final lostUpgradeStates = _collectLostRelicStates(verifiedPaidIds);
    final nextRelicUpgrades = lostUpgrades.isNotEmpty
        ? _mergeRelicUpgradeIds(relicChamberStoredUpgrades, lostUpgrades)
        : List<String>.from(relicChamberStoredUpgrades);
    final nextRelicStates = lostUpgrades.isNotEmpty
        ? <String, bool>{
            ...relicChamberStoredUpgradeStates,
            ...lostUpgradeStates,
          }
        : Map<String, bool>.from(relicChamberStoredUpgradeStates);
    final int? nextRelicStaffSpeed;
    if (lostUpgrades.isEmpty) {
      nextRelicStaffSpeed = relicChamberStoredOverchargedStaffSpeed;
    } else if (lostUpgradeStates.containsKey(
      ShopUpgradeArtifact.overchargedStaff.id,
    )) {
      nextRelicStaffSpeed = overchargedStaffLevel >= storedRelicOverchargedStaffLevel
          ? overchargedStaffSelectedSpeed
          : relicChamberStoredOverchargedStaffSpeed;
    } else {
      nextRelicStaffSpeed = relicChamberStoredOverchargedStaffSpeed;
    }

    // 3. Preserve independent all-time historical peaks and unlock Hall of Heroes claim
    final nextPeakHp = math.max(peakHpUpgradeLevel, hpUpgradeLevel);
    final nextPeakMana = math.max(peakManaUpgradeLevel, manaUpgradeLevel);
    final nextClaimAvailable = nextPeakHp > 0 || nextPeakMana > 0;

    // 4. Wipe active campaign & arena state while preserving global account data
    await storage.clearGameplayProgress(
      includeSettings: false,
      includeCastleMeta: false,
      preserveStoryFlags: true,
      preserveRemoveAds: true,
    );
    await storage.clearBattleDecreeProgress();

    if (hasActiveOrbs) {
      await storage.setAllSpoilsOrbs(
        fire: updatedSpoilsFire,
        water: updatedSpoilsWater,
        wood: updatedSpoilsWood,
        earth: updatedSpoilsEarth,
        metal: updatedSpoilsMetal,
      );
    }
    if (lostUpgrades.isNotEmpty) {
      await storage.setRelicChamberUpgrades(nextRelicUpgrades);
      await storage.setRelicChamberUpgradeStates(nextRelicStates);
      await storage.setRelicChamberOverchargedStaffSpeed(nextRelicStaffSpeed);
    }
    await storage.setPeakHpUpgradeLevel(nextPeakHp);
    await storage.setPeakManaUpgradeLevel(nextPeakMana);
    await storage.setHallOfHeroesClaimAvailable(nextClaimAvailable);
    await storage.setTotalCyclesCount(nextTotalCycles);
    await storage.setForfeitRunCount(nextForfeitRuns);
    await storage.setPurchasedIapProductIds(verifiedPaidIds);
    await storage.setCurrentWeek(0);
    if (preservedRemoveAdsOwned) {
      await storage.setUnlockedAds(true);
      if (preservedHasExplicitRemoveAdsToggle) {
        await storage.setRemoveAdsEnabled(preservedRemoveAdsEnabled);
      }
    }

    turnCount = 0;
    lastCollectedOrbMove = null;
    is100RoundsAlertPending = false;
    isDeathAlertPending = false;
    isBossVictoryPending = false;
    pendingBossVictoryPhase = null;
    pendingBossVictoryWeek = null;

    _loadState(restartAudio: false);

    for (final productId in verifiedPaidIds) {
      unlockByProductId(
        productId,
        recordAsIap: false,
        triggerStory: false,
        triggerCloudSave: false,
      );
    }

    notifyListeners();
    if (playGames.isSignedIn) {
      await playGames.saveCloudData();
      await playGames.checkAndGrantQaBonusIfEligible();
    }
  }

  // Shop Purchases (Elemental Orbs)
  bool canAfford(ElementalCost cost) {
    return fireOrbs >= cost.fire &&
        waterOrbs >= cost.water &&
        woodOrbs >= cost.wood &&
        earthOrbs >= cost.earth &&
        metalOrbs >= cost.metal;
  }

  bool purchaseWithOrbs({
    required ElementalCost cost,
    required VoidCallback onUnlock,
  }) {
    if (!canAfford(cost)) {
      audio.playVibrate();
      return false;
    }

    fireOrbs -= cost.fire;
    waterOrbs -= cost.water;
    woodOrbs -= cost.wood;
    earthOrbs -= cost.earth;
    metalOrbs -= cost.metal;
    turn0FireOrbs = math.max(0, turn0FireOrbs - cost.fire);
    turn0WaterOrbs = math.max(0, turn0WaterOrbs - cost.water);
    turn0WoodOrbs = math.max(0, turn0WoodOrbs - cost.wood);
    turn0EarthOrbs = math.max(0, turn0EarthOrbs - cost.earth);
    turn0MetalOrbs = math.max(0, turn0MetalOrbs - cost.metal);
    _persistOrbsToStorage();
    _persistTurn0OrbsToStorage();
    onUnlock();
    _triggerCloudSave();
    notifyListeners();
    return true;
  }

  bool get hasSeenIntro => hasSeenStoryIntro;

  List<StoryChapter> get artifactStoryChapters => StoryChapter.values
      .where((c) => c != StoryChapter.intro)
      .toList(growable: false);

  int get totalStoryMemoriesCount => StoryChapter.values.length;

  int get unlockedStoryMemoriesCount =>
      StoryChapter.values.where(isStoryChapterUnlocked).length;

  void completeIntroStory() {
    final shouldSave =
        !hasSeenStoryIntro || pendingStoryChapter == StoryChapter.intro;
    hasSeenStoryIntro = true;
    storage.setHasSeenStoryIntro(true);
    if (pendingStoryChapter == StoryChapter.intro) {
      pendingStoryChapter = null;
    }
    if (shouldSave) {
      _triggerCloudSave();
      notifyListeners();
    }
  }

  bool hasSeenStory(StoryChapter chapter) {
    switch (chapter) {
      case StoryChapter.intro:
        return hasSeenStoryIntro;
      case StoryChapter.resetButton:
        return hasSeenStoryReset;
      case StoryChapter.predictabilityScore:
        return hasSeenStoryPredictability;
      case StoryChapter.randomButton:
        return hasSeenStoryRandom;
      case StoryChapter.showAlgorithm:
        return hasSeenStoryAlgorithm;
      case StoryChapter.yourPrediction:
        return hasSeenStoryYourPrediction;
      case StoryChapter.pcNextMove:
        return hasSeenStoryPcNextMove;
      case StoryChapter.suggestion:
        return hasSeenStorySuggestion;
      case StoryChapter.crystalBall:
        return hasSeenStoryCrystalBall;
    }
  }

  bool isStoryChapterUnlocked(StoryChapter chapter) {
    switch (chapter) {
      case StoryChapter.intro:
        return true;
      case StoryChapter.resetButton:
        return unlockedReset || hasSeenStoryReset;
      case StoryChapter.predictabilityScore:
        return unlockedPredictability || hasSeenStoryPredictability;
      case StoryChapter.randomButton:
        return unlockedRandom || hasSeenStoryRandom;
      case StoryChapter.showAlgorithm:
        return unlockedAlgorithm || hasSeenStoryAlgorithm;
      case StoryChapter.yourPrediction:
        return unlockedYourPrediction || hasSeenStoryYourPrediction;
      case StoryChapter.pcNextMove:
        return unlockedNextMove || hasSeenStoryPcNextMove;
      case StoryChapter.suggestion:
        return unlockedSuggestion || hasSeenStorySuggestion;
      case StoryChapter.crystalBall:
        return unlockedCrystalBall || hasSeenStoryCrystalBall;
    }
  }

  void markStorySeen(StoryChapter chapter) {
    switch (chapter) {
      case StoryChapter.intro:
        hasSeenStoryIntro = true;
        storage.setHasSeenStoryIntro(true);
        _triggerCloudSave();
        break;
      case StoryChapter.resetButton:
        hasSeenStoryReset = true;
        storage.setHasSeenStoryReset(true);
        break;
      case StoryChapter.predictabilityScore:
        hasSeenStoryPredictability = true;
        storage.setHasSeenStoryPredictability(true);
        break;
      case StoryChapter.randomButton:
        hasSeenStoryRandom = true;
        storage.setHasSeenStoryRandom(true);
        break;
      case StoryChapter.showAlgorithm:
        hasSeenStoryAlgorithm = true;
        storage.setHasSeenStoryAlgorithm(true);
        break;
      case StoryChapter.yourPrediction:
        hasSeenStoryYourPrediction = true;
        storage.setHasSeenStoryYourPrediction(true);
        break;
      case StoryChapter.pcNextMove:
        hasSeenStoryPcNextMove = true;
        storage.setHasSeenStoryPcNextMove(true);
        break;
      case StoryChapter.suggestion:
        hasSeenStorySuggestion = true;
        storage.setHasSeenStorySuggestion(true);
        break;
      case StoryChapter.crystalBall:
        hasSeenStoryCrystalBall = true;
        storage.setHasSeenStoryCrystalBall(true);
        break;
    }
    if (pendingStoryChapter == chapter) {
      pendingStoryChapter = null;
    }
    notifyListeners();
  }

  StoryChapter? consumePendingStory([StoryChapter? expected]) {
    if (pendingStoryChapter == null) return null;
    if (expected != null && pendingStoryChapter != expected) return null;
    final chapter = pendingStoryChapter!;
    markStorySeen(chapter);
    return chapter;
  }

  void _triggerStoryOnFirstUnlock(StoryChapter chapter) {
    if (!hasSeenStory(chapter)) {
      markStorySeen(chapter);
      pendingStoryChapter = chapter;
    } else {
      pendingStoryChapter = null;
    }
  }

  void _applyMaxHpLevelGain() {
    hpUpgradeLevel += 1;
    storage.setHpUpgradeLevel(hpUpgradeLevel);
    if (hpUpgradeLevel > peakHpUpgradeLevel) {
      peakHpUpgradeLevel = hpUpgradeLevel;
      storage.setPeakHpUpgradeLevel(peakHpUpgradeLevel);
    }
    if (!hasGameStarted) {
      userHp = effectivePlayerMaxHp;
      storage.setUserHp(userHp);
    }
  }

  void _applyMaxManaLevelGain() {
    manaUpgradeLevel += 1;
    storage.setManaUpgradeLevel(manaUpgradeLevel);
    if (manaUpgradeLevel > peakManaUpgradeLevel) {
      peakManaUpgradeLevel = manaUpgradeLevel;
      storage.setPeakManaUpgradeLevel(peakManaUpgradeLevel);
    }
  }

  /// Returns the exact progressive orb cost to upgrade Max HP by [levels]
  /// starting from [fromLevel] (defaults to [hpUpgradeLevel]).
  ElementalCost costForMaxHpLevels(int levels, {int? fromLevel}) =>
      maxHpBatchCost(startLevel: fromLevel ?? hpUpgradeLevel, levels: levels);

  /// Returns the exact progressive orb cost to upgrade Max Mana by [levels]
  /// starting from [fromLevel] (defaults to [manaUpgradeLevel]).
  ElementalCost costForMaxManaLevels(int levels, {int? fromLevel}) =>
      maxManaBatchCost(
        startLevel: fromLevel ?? manaUpgradeLevel,
        levels: levels,
      );

  /// Iteratively computes the maximum affordable level count and exact summed
  /// orb cost starting at [currentLevel] without exceeding current orb balances
  /// (bounded by [maxBatchSearchLimit] against zero-cost edge cases).
  ({int levels, ElementalCost totalCost}) calculateMaxAffordableUpgrade({
    required int currentLevel,
    required ElementalCost Function(int level) costForLevel,
    int maxIterations = maxBatchSearchLimit,
  }) {
    int levels = 0;
    int sumFire = 0;
    int sumWater = 0;
    int sumWood = 0;
    int sumEarth = 0;
    int sumMetal = 0;

    final cap = maxIterations.clamp(0, maxBatchSearchLimit);
    for (int k = 0; k < cap; k++) {
      final step = costForLevel(currentLevel + k);
      if (sumFire + step.fire > fireOrbs ||
          sumWater + step.water > waterOrbs ||
          sumWood + step.wood > woodOrbs ||
          sumEarth + step.earth > earthOrbs ||
          sumMetal + step.metal > metalOrbs) {
        break;
      }
      sumFire += step.fire;
      sumWater += step.water;
      sumWood += step.wood;
      sumEarth += step.earth;
      sumMetal += step.metal;
      levels += 1;
    }

    return (
      levels: levels,
      totalCost: ElementalCost(
        fire: sumFire,
        water: sumWater,
        wood: sumWood,
        earth: sumEarth,
        metal: sumMetal,
      ),
    );
  }

  ({int levels, ElementalCost totalCost}) maxAffordableHpUpgrade() =>
      calculateMaxAffordableUpgrade(
        currentLevel: hpUpgradeLevel,
        costForLevel: maxHpUpgradeCostForLevel,
      );

  ({int levels, ElementalCost totalCost}) maxAffordableManaUpgrade() =>
      calculateMaxAffordableUpgrade(
        currentLevel: manaUpgradeLevel,
        costForLevel: maxManaUpgradeCostForLevel,
      );

  bool canAffordMaxHpLevels(int levels) =>
      levels > 0 && canAfford(costForMaxHpLevels(levels));

  bool canAffordMaxManaLevels(int levels) =>
      levels > 0 && canAfford(costForMaxManaLevels(levels));

  /// Atomically upgrades the Cleric's Max HP by [levels] using exact
  /// progressive level-by-level orb summation, updating peaks and persisting
  /// in a single write to [StorageService] and [PlayGamesService].
  bool upgradeMaxHpBatch(int levels) {
    if (levels <= 0) {
      audio.playVibrate();
      return false;
    }
    final totalCost = costForMaxHpLevels(levels);
    if (!canAfford(totalCost)) {
      audio.playVibrate();
      return false;
    }

    fireOrbs -= totalCost.fire;
    waterOrbs -= totalCost.water;
    woodOrbs -= totalCost.wood;
    earthOrbs -= totalCost.earth;
    metalOrbs -= totalCost.metal;
    turn0FireOrbs = math.max(0, turn0FireOrbs - totalCost.fire);
    turn0WaterOrbs = math.max(0, turn0WaterOrbs - totalCost.water);
    turn0WoodOrbs = math.max(0, turn0WoodOrbs - totalCost.wood);
    turn0EarthOrbs = math.max(0, turn0EarthOrbs - totalCost.earth);
    turn0MetalOrbs = math.max(0, turn0MetalOrbs - totalCost.metal);

    hpUpgradeLevel += levels;
    final int? updatedPeakHp;
    if (hpUpgradeLevel > peakHpUpgradeLevel) {
      peakHpUpgradeLevel = hpUpgradeLevel;
      updatedPeakHp = peakHpUpgradeLevel;
    } else {
      updatedPeakHp = null;
    }

    int? updatedUserHp;
    if (!hasGameStarted) {
      userHp = effectivePlayerMaxHp;
      updatedUserHp = userHp;
    }

    storage.persistStatUpgradeBatch(
      fire: fireOrbs,
      water: waterOrbs,
      wood: woodOrbs,
      earth: earthOrbs,
      metal: metalOrbs,
      turn0Fire: turn0FireOrbs,
      turn0Water: turn0WaterOrbs,
      turn0Wood: turn0WoodOrbs,
      turn0Earth: turn0EarthOrbs,
      turn0Metal: turn0MetalOrbs,
      hpUpgradeLevel: hpUpgradeLevel,
      peakHpUpgradeLevel: updatedPeakHp,
      userHp: updatedUserHp,
    );
    _triggerCloudSave();
    notifyListeners();
    return true;
  }

  /// Atomically upgrades the Cleric's Max Mana Pool by [levels] using exact
  /// progressive level-by-level orb summation, updating peaks and persisting
  /// in a single write to [StorageService] and [PlayGamesService].
  bool upgradeMaxManaBatch(int levels) {
    if (levels <= 0) {
      audio.playVibrate();
      return false;
    }
    final totalCost = costForMaxManaLevels(levels);
    if (!canAfford(totalCost)) {
      audio.playVibrate();
      return false;
    }

    fireOrbs -= totalCost.fire;
    waterOrbs -= totalCost.water;
    woodOrbs -= totalCost.wood;
    earthOrbs -= totalCost.earth;
    metalOrbs -= totalCost.metal;
    turn0FireOrbs = math.max(0, turn0FireOrbs - totalCost.fire);
    turn0WaterOrbs = math.max(0, turn0WaterOrbs - totalCost.water);
    turn0WoodOrbs = math.max(0, turn0WoodOrbs - totalCost.wood);
    turn0EarthOrbs = math.max(0, turn0EarthOrbs - totalCost.earth);
    turn0MetalOrbs = math.max(0, turn0MetalOrbs - totalCost.metal);

    manaUpgradeLevel += levels;
    final int? updatedPeakMana;
    if (manaUpgradeLevel > peakManaUpgradeLevel) {
      peakManaUpgradeLevel = manaUpgradeLevel;
      updatedPeakMana = peakManaUpgradeLevel;
    } else {
      updatedPeakMana = null;
    }
    if (totalRounds < playerMaxMana) {
      is100RoundsAlertPending = false;
    }

    storage.persistStatUpgradeBatch(
      fire: fireOrbs,
      water: waterOrbs,
      wood: woodOrbs,
      earth: earthOrbs,
      metal: metalOrbs,
      turn0Fire: turn0FireOrbs,
      turn0Water: turn0WaterOrbs,
      turn0Wood: turn0WoodOrbs,
      turn0Earth: turn0EarthOrbs,
      turn0Metal: turn0MetalOrbs,
      manaUpgradeLevel: manaUpgradeLevel,
      peakManaUpgradeLevel: updatedPeakMana,
    );
    _triggerCloudSave();
    notifyListeners();
    return true;
  }

  /// Infinitely upgrades the Cleric's Max HP by +1 using only Fire, Water, and
  /// Wood orbs (`2 + hpUpgradeLevel ~/ 2` each), updating current HP if out of combat
  /// and tracking the all-time historical peak.
  bool upgradeMaxHp() => upgradeMaxHpBatch(1);

  /// Infinitely upgrades the Cleric's Max Mana Pool by +1 using only Fire, Water,
  /// and Wood orbs (`3 + manaUpgradeLevel ~/ 2` each) and tracks the all-time peak.
  bool upgradeMaxMana() => upgradeMaxManaBatch(1);

  /// Displays a rewarded video ad to grant +1 permanent Max HP level for this
  /// campaign (capped at [maxWeeklyAdConsagrations] per campaign week).
  Future<bool> watchAdToUpgradeMaxHp({VoidCallback? onUpgraded}) async {
    if (!canWatchAdConsagration) return false;
    bool earned = false;
    final shown = await adService.showRewardedAd(
      onUserEarnedReward: () {
        earned = true;
        adConsagrationsThisWeek += 1;
        storage.setAdConsagrationsThisWeek(adConsagrationsThisWeek);
        _applyMaxHpLevelGain();
        audio.playWinVibrate();
        _triggerCloudSave();
        notifyListeners();
        onUpgraded?.call();
      },
    );
    return shown && earned;
  }

  /// Displays a rewarded video ad to grant +1 permanent Max Mana Pool level for
  /// this campaign (capped at [maxWeeklyAdConsagrations] per campaign week).
  Future<bool> watchAdToUpgradeMaxMana({VoidCallback? onUpgraded}) async {
    if (!canWatchAdConsagration) return false;
    bool earned = false;
    final shown = await adService.showRewardedAd(
      onUserEarnedReward: () {
        earned = true;
        adConsagrationsThisWeek += 1;
        storage.setAdConsagrationsThisWeek(adConsagrationsThisWeek);
        _applyMaxManaLevelGain();
        audio.playWinVibrate();
        _triggerCloudSave();
        notifyListeners();
        onUpgraded?.call();
      },
    );
    return shown && earned;
  }

  /// Activates a pre-battle [SacredBlessing] for the next battle expedition
  /// using either the player's 1 free daily prayer or the Remove Ads perk.
  bool activateSacredBlessingFree(SacredBlessing blessing, {DateTime? now}) {
    if (!canActivateSacredBlessingFree(now)) {
      audio.playVibrate();
      return false;
    }
    if (!isRemoveAdsActive) {
      final today = dateKeyFor(now ?? DateTime.now());
      lastFreeDailyPrayerDate = today;
      storage.setLastFreeDailyPrayerDate(today);
    }
    pendingBattleBlessing = blessing;
    storage.setPendingBattleBlessing(blessing.id);
    audio.playWinVibrate();
    _triggerCloudSave();
    notifyListeners();
    return true;
  }

  /// Displays a rewarded video ad to activate a temporary [SacredBlessing] for
  /// the Cleric's next battle expedition exclusively inside `onUserEarnedReward`.
  Future<bool> watchAdToActivateSacredBlessing(
    SacredBlessing blessing, {
    VoidCallback? onActivated,
  }) async {
    if (!canActivateSacredBlessingWithAd()) return false;
    bool earned = false;
    final shown = await adService.showRewardedAd(
      onUserEarnedReward: () {
        earned = true;
        pendingBattleBlessing = blessing;
        storage.setPendingBattleBlessing(blessing.id);
        audio.playWinVibrate();
        _triggerCloudSave();
        notifyListeners();
        onActivated?.call();
      },
    );
    return shown && earned;
  }

  // ---------------------------------------------------------------------------
  // SACRED TEMPLE WING 6: OFFERTORY (PERMANENT IDLE ORB GENERATOR)
  // ---------------------------------------------------------------------------

  DateTime _nowUtc([DateTime? override]) => (override ?? _clock()).toUtc();

  /// Elements charged and generated by the Sacred Offertory:
  /// - Phase 1 (before Phase 2 & before Earth & Metal unlocked): Fire, Water, Wood.
  /// - Phase 2+ (Phase 2 reached or Earth & Metal unlocked): all 5 elements.
  List<HandMove> get offertoryActiveElements => bonusOrbMoves;

  /// Per-element orb cost to upgrade to 1-indexed level [targetLevel] (`Nv = L + 1`):
  /// `floor(20 * 1.15^(Nv - 1))`.
  static int offertoryUnitCostForTargetLevel(int targetLevel) {
    if (targetLevel <= 1) return 20;
    final raw = 20.0 * math.pow(1.15, targetLevel - 1);
    if (raw.isNaN || raw.isInfinite || raw >= 9e15) {
      return 1 << 52;
    }
    return raw.floor();
  }

  /// Exact progressive level-by-level sum per active element for upgrading
  /// [levels] times starting from [fromLevel] (defaults to [offertoryLevel]).
  int offertoryUnitCostForLevels(int levels, {int? fromLevel}) {
    if (levels <= 0) return 0;
    final start = fromLevel ?? offertoryLevel;
    int sum = 0;
    for (int k = 1; k <= levels; k++) {
      final stepCost = offertoryUnitCostForTargetLevel(start + k);
      if (sum > (1 << 52) - stepCost) {
        return 1 << 52;
      }
      sum += stepCost;
    }
    return sum;
  }

  /// Full [ElementalCost] across currently active elements for upgrading
  /// [levels] times starting from [fromLevel].
  ElementalCost offertoryCostForLevels(int levels, {int? fromLevel}) {
    final unit = offertoryUnitCostForLevels(levels, fromLevel: fromLevel);
    if (includesEarthAndMetalInBonuses) {
      return ElementalCost(
        fire: unit,
        water: unit,
        wood: unit,
        earth: unit,
        metal: unit,
      );
    }
    return ElementalCost(fire: unit, water: unit, wood: unit);
  }

  ElementalCost get nextOffertoryUpgradeCost => offertoryCostForLevels(1);

  bool canAffordOffertoryLevels(int levels) {
    if (levels <= 0) return false;
    return canAfford(offertoryCostForLevels(levels));
  }

  /// Computes the maximum number of Offertory levels affordable right now and
  /// the exact cumulative [ElementalCost].
  ({int levels, ElementalCost totalCost}) maxAffordableOffertoryUpgrade() {
    final active = offertoryActiveElements;
    int minBalance = orbsFor(active.first);
    for (int i = 1; i < active.length; i++) {
      final bal = orbsFor(active[i]);
      if (bal < minBalance) minBalance = bal;
    }
    if (minBalance <= 0) {
      return (levels: 0, totalCost: const ElementalCost());
    }

    int bought = 0;
    int totalUnit = 0;
    while (bought < 5000) {
      final nextUnit = offertoryUnitCostForTargetLevel(
        offertoryLevel + bought + 1,
      );
      if (totalUnit + nextUnit > minBalance) {
        break;
      }
      totalUnit += nextUnit;
      bought += 1;
    }

    if (bought == 0) {
      return (levels: 0, totalCost: const ElementalCost());
    }
    final cost = includesEarthAndMetalInBonuses
        ? ElementalCost(
            fire: totalUnit,
            water: totalUnit,
            wood: totalUnit,
            earth: totalUnit,
            metal: totalUnit,
          )
        : ElementalCost(fire: totalUnit, water: totalUnit, wood: totalUnit);
    return (levels: bought, totalCost: cost);
  }

  /// Cumulative milestone multiplier: `+25%` (`+0.25x`) every 10 levels.
  static double offertoryMilestoneMultiplierForLevel(int level) {
    if (level <= 0) return 1.0;
    return 1.0 + offertoryMilestoneBonusPer10Levels * (level ~/ 10);
  }

  double get offertoryMilestoneMultiplier =>
      offertoryMilestoneMultiplierForLevel(offertoryLevel);

  int get offertoryMilestoneBonusPercent => (offertoryLevel ~/ 10) * 25;

  bool isOffertoryBoostActive([DateTime? now]) {
    final expMs = offertoryBoostExpiresAt;
    if (expMs == null || expMs <= 0) return false;
    return _nowUtc(now).isBefore(
      DateTime.fromMillisecondsSinceEpoch(expMs, isUtc: true),
    );
  }

  Duration offertoryBoostRemaining([DateTime? now]) {
    final expMs = offertoryBoostExpiresAt;
    if (expMs == null || expMs <= 0) return Duration.zero;
    final diffMs = expMs - _nowUtc(now).millisecondsSinceEpoch;
    return diffMs > 0 ? Duration(milliseconds: diffMs) : Duration.zero;
  }

  bool isOffertoryBoostAtMaxCap([DateTime? now]) =>
      offertoryBoostRemaining(now) >= offertoryTitheBoostMaxDuration;

  double offertoryBoostMultiplier([DateTime? now]) =>
      isOffertoryBoostActive(now) ? 2.0 : 1.0;

  /// Effective hourly generation rate per active element.
  double offertoryHourlyRate({int? level, DateTime? now, bool? boosted}) {
    final lv = level ?? offertoryLevel;
    if (lv <= 0) return 0.0;
    final milestone = offertoryMilestoneMultiplierForLevel(lv);
    final boost = (boosted ?? isOffertoryBoostActive(now)) ? 2.0 : 1.0;
    return offertoryBaseHourlyRatePerLevel * lv * milestone * boost;
  }

  double offertoryPerMinuteRate({int? level, DateTime? now, bool? boosted}) =>
      offertoryHourlyRate(level: level, now: now, boosted: boosted) / 60.0;

  double _rawUnbankedOffertorySeconds([DateTime? now]) {
    if (offertoryLevel <= 0) return 0.0;
    final startMs = offertoryLastCollectedAt;
    if (startMs == null || startMs <= 0) return 0.0;
    final nowMs = _nowUtc(now).millisecondsSinceEpoch;
    final remainingCap = (offertoryMaxCapSeconds - offertoryBankedSeconds)
        .clamp(0.0, offertoryMaxCapSeconds.toDouble());
    final rawElapsedSec = math.max(0.0, (nowMs - startMs) / 1000.0);
    return math.min(rawElapsedSec, remainingCap);
  }

  /// Total seconds accumulated toward the 8-hour storage cap (`[0, 28800]`).
  double offertoryElapsedSeconds([DateTime? now]) {
    if (offertoryLevel <= 0) return 0.0;
    return (offertoryBankedSeconds + _rawUnbankedOffertorySeconds(now)).clamp(
      0.0,
      offertoryMaxCapSeconds.toDouble(),
    );
  }

  Duration offertoryElapsedDuration([DateTime? now]) =>
      Duration(milliseconds: (offertoryElapsedSeconds(now) * 1000.0).round());

  double offertoryFillProgress([DateTime? now]) =>
      (offertoryElapsedSeconds(now) / offertoryMaxCapSeconds).clamp(0.0, 1.0);

  Duration offertoryTimeUntilFull([DateTime? now]) {
    if (offertoryLevel <= 0) return offertoryMaxCapDuration;
    final remainingSec =
        math.max(0.0, offertoryMaxCapSeconds - offertoryElapsedSeconds(now));
    return Duration(seconds: remainingSec.ceil());
  }

  bool isOffertoryFullAt([DateTime? now]) =>
      offertoryLevel > 0 && offertoryElapsedSeconds(now) >= offertoryMaxCapSeconds;

  bool get isOffertoryFull => isOffertoryFullAt();

  /// Drives the pulsing golden notification badge on the Sacred Temple landmark
  /// on [WorldMapScreen] whenever the Offertory reaches its 8-hour cap.
  bool get hasSacredTempleNotification => isOffertoryFull;

  /// Exact piecewise integration of unbanked orbs since [offertoryLastCollectedAt],
  /// accounting for a 2x Tithe Boost expiring mid-offline interval and clamped
  /// to the remaining 8-hour storage cap.
  double _computeUnbankedOffertoryFloat([DateTime? now]) {
    if (offertoryLevel <= 0) return 0.0;
    final startMs = offertoryLastCollectedAt;
    if (startMs == null || startMs <= 0) return 0.0;
    final cappedElapsedSec = _rawUnbankedOffertorySeconds(now);
    if (cappedElapsedSec <= 0.0) return 0.0;

    final baseHourly = offertoryBaseHourlyRatePerLevel *
        offertoryLevel *
        offertoryMilestoneMultiplierForLevel(offertoryLevel);
    final basePerSec = baseHourly / 3600.0;
    final effectiveEndMs = startMs + (cappedElapsedSec * 1000.0).round();

    final boostExpMs = offertoryBoostExpiresAt;
    if (boostExpMs != null && boostExpMs > startMs) {
      final boostedEndMs = math.min(effectiveEndMs, boostExpMs);
      final boostedSec = math.max(0.0, (boostedEndMs - startMs) / 1000.0);
      final normalSec = math.max(0.0, cappedElapsedSec - boostedSec);
      return boostedSec * (basePerSec * 2.0) + normalSec * basePerSec;
    }
    return cappedElapsedSec * basePerSec;
  }

  /// Total pending orbs (banked + fractional + live unbanked) per active element.
  double offertoryPendingTotalFloat([DateTime? now]) {
    if (offertoryLevel <= 0) return 0.0;
    return offertoryBankedOrbs +
        offertoryPendingFraction +
        _computeUnbankedOffertoryFloat(now);
  }

  /// Whole collectible orbs currently stored per active element.
  int offertoryStoredOrbs([DateTime? now]) {
    if (offertoryLevel <= 0) return 0;
    return offertoryPendingTotalFloat(now).floor();
  }

  bool canCollectOffertory([DateTime? now]) => offertoryStoredOrbs(now) >= 1;

  bool isOffertoryFreeDoubleReady([DateTime? now]) {
    final readyMs = offertoryFreeDoubleReadyAt;
    if (readyMs == null || readyMs <= 0) return true;
    return _nowUtc(now).millisecondsSinceEpoch >= readyMs;
  }

  Duration offertoryFreeDoubleRemaining([DateTime? now]) {
    final readyMs = offertoryFreeDoubleReadyAt;
    if (readyMs == null || readyMs <= 0) return Duration.zero;
    final diffMs = readyMs - _nowUtc(now).millisecondsSinceEpoch;
    return diffMs > 0 ? Duration(milliseconds: diffMs) : Duration.zero;
  }

  bool canWatchAdDoubleCollectOffertory([DateTime? now]) =>
      !isRemoveAdsActive &&
      adService.isRewardedAdReady &&
      offertoryStoredOrbs(now) >= 1;

  bool canClaimRemoveAdsDoubleCollectOffertory([DateTime? now]) =>
      isRemoveAdsActive &&
      isOffertoryFreeDoubleReady(now) &&
      offertoryStoredOrbs(now) >= 1;

  /// 10% tithe cost per active element (`floor(balance * 0.10)`).
  Map<HandMove, int> offertoryTitheCosts() {
    return {
      for (final move in offertoryActiveElements)
        move: (orbsFor(move) * offertoryTithePercentage).floor(),
    };
  }

  bool canInvokeOffertoryTitheBoost([DateTime? now]) {
    if (offertoryLevel <= 0) return false;
    if (isOffertoryBoostAtMaxCap(now)) return false;
    for (final move in offertoryActiveElements) {
      if (orbsFor(move) < offertoryTitheMinBalance) {
        return false;
      }
    }
    return true;
  }

  /// Banks all orbs earned up to [nowUtc] at the current level/boost rate so
  /// upgrading or activating 2x boost never distorts past accumulation retroactively.
  void _settleOffertoryUpTo(DateTime nowUtc) {
    final nowMs = nowUtc.millisecondsSinceEpoch;
    if (offertoryLevel <= 0) {
      offertoryLastCollectedAt = nowMs;
      offertoryBankedOrbs = 0;
      offertoryBankedSeconds = 0.0;
      offertoryPendingFraction = 0.0;
      return;
    }

    final cappedSec = _rawUnbankedOffertorySeconds(nowUtc);
    final unbankedFloat = _computeUnbankedOffertoryFloat(nowUtc);
    final combined = offertoryPendingFraction + unbankedFloat;
    final whole = combined.floor();
    final remainder = (combined - whole).clamp(0.0, 0.999999);

    offertoryBankedOrbs += whole;
    offertoryPendingFraction = remainder;
    offertoryBankedSeconds = (offertoryBankedSeconds + cappedSec).clamp(
      0.0,
      offertoryMaxCapSeconds.toDouble(),
    );
    offertoryLastCollectedAt = nowMs;
  }

  void _persistOffertoryState() {
    storage.setOffertoryLevel(offertoryLevel);
    storage.setOffertoryLastCollectedAt(offertoryLastCollectedAt);
    storage.setOffertoryPendingFraction(offertoryPendingFraction);
    storage.setOffertoryBankedOrbs(offertoryBankedOrbs);
    storage.setOffertoryBankedSeconds(offertoryBankedSeconds);
    storage.setOffertoryBoostExpiresAt(offertoryBoostExpiresAt);
    storage.setOffertoryFreeDoubleReadyAt(offertoryFreeDoubleReadyAt);
  }

  void _persistAllOrbsAndTurn0() {
    storage.setAllOrbs(
      fire: fireOrbs,
      water: waterOrbs,
      wood: woodOrbs,
      earth: earthOrbs,
      metal: metalOrbs,
    );
    storage.setTurn0Orbs(
      fire: turn0FireOrbs,
      water: turn0WaterOrbs,
      wood: turn0WoodOrbs,
      earth: turn0EarthOrbs,
      metal: turn0MetalOrbs,
    );
  }

  /// Consecrates Elemental Orbs to upgrade the permanent Offertory generator
  /// by [levels] levels using exact progressive level-by-level summation.
  bool upgradeOffertoryBatch(int levels, {DateTime? now}) {
    if (levels <= 0) return false;
    final totalCost = offertoryCostForLevels(levels);
    if (!canAfford(totalCost)) {
      audio.playVibrate();
      return false;
    }

    final nowUtc = _nowUtc(now);
    // Settle earned orbs up to this exact moment before raising the rate
    _settleOffertoryUpTo(nowUtc);

    fireOrbs -= totalCost.fire;
    waterOrbs -= totalCost.water;
    woodOrbs -= totalCost.wood;
    earthOrbs -= totalCost.earth;
    metalOrbs -= totalCost.metal;
    turn0FireOrbs = math.max(0, turn0FireOrbs - totalCost.fire);
    turn0WaterOrbs = math.max(0, turn0WaterOrbs - totalCost.water);
    turn0WoodOrbs = math.max(0, turn0WoodOrbs - totalCost.wood);
    turn0EarthOrbs = math.max(0, turn0EarthOrbs - totalCost.earth);
    turn0MetalOrbs = math.max(0, turn0MetalOrbs - totalCost.metal);

    offertoryLevel += levels;
    _persistAllOrbsAndTurn0();
    _persistOffertoryState();
    audio.playWinVibrate();
    _triggerCloudSave();
    notifyListeners();
    return true;
  }

  /// Claims accumulated whole orbs (`>= 1`) per active element multiplied by
  /// [multiplier] (`1` for standard collect, `2` for double harvest), preserving
  /// the fractional remainder `< 1.0` and resetting the 8-hour storage timer.
  /// Returns the number of orbs granted per active element (`0` if nothing to collect).
  int collectOffertoryOrbs({int multiplier = 1, DateTime? now}) {
    if (offertoryLevel <= 0 || multiplier < 1) return 0;
    final nowUtc = _nowUtc(now);
    final totalFloat = offertoryPendingTotalFloat(nowUtc);
    final whole = totalFloat.floor();
    if (whole < 1) {
      audio.playVibrate();
      return 0;
    }

    final granted = whole * multiplier;
    for (final move in offertoryActiveElements) {
      switch (move) {
        case HandMove.rock:
          fireOrbs += granted;
          turn0FireOrbs += granted;
          break;
        case HandMove.paper:
          waterOrbs += granted;
          turn0WaterOrbs += granted;
          break;
        case HandMove.scissors:
          woodOrbs += granted;
          turn0WoodOrbs += granted;
          break;
        case HandMove.lizard:
          earthOrbs += granted;
          turn0EarthOrbs += granted;
          break;
        case HandMove.spock:
          metalOrbs += granted;
          turn0MetalOrbs += granted;
          break;
      }
    }

    offertoryBankedOrbs = 0;
    offertoryBankedSeconds = 0.0;
    offertoryPendingFraction = (totalFloat - whole).clamp(0.0, 0.999999);
    offertoryLastCollectedAt = nowUtc.millisecondsSinceEpoch;

    _persistAllOrbsAndTurn0();
    _persistOffertoryState();
    audio.playWinVibrate();
    _triggerCloudSave();
    notifyListeners();
    return granted;
  }

  /// Displays an AdMob rewarded video ad and grants 2x accumulated Offertory orbs
  /// exclusively inside `onUserEarnedReward`.
  Future<int> watchAdToDoubleCollectOffertory({
    void Function(int grantedPerElement)? onCollected,
    DateTime? now,
  }) async {
    if (!canWatchAdDoubleCollectOffertory(now)) return 0;
    int granted = 0;
    final shown = await adService.showRewardedAd(
      onUserEarnedReward: () {
        granted = collectOffertoryOrbs(multiplier: 2, now: now);
        if (granted > 0) {
          onCollected?.call(granted);
        }
      },
    );
    return shown ? granted : 0;
  }

  /// Ad-free Sanctuary Grace double harvest for Remove Ads owners (4-hour cooldown).
  int claimRemoveAdsDoubleCollectOffertory({DateTime? now}) {
    if (!canClaimRemoveAdsDoubleCollectOffertory(now)) {
      audio.playVibrate();
      return 0;
    }
    final nowUtc = _nowUtc(now);
    final granted = collectOffertoryOrbs(multiplier: 2, now: nowUtc);
    if (granted > 0) {
      offertoryFreeDoubleReadyAt =
          nowUtc.millisecondsSinceEpoch + offertoryFreeDoubleCooldown.inMilliseconds;
      storage.setOffertoryFreeDoubleReadyAt(offertoryFreeDoubleReadyAt);
      _triggerCloudSave();
      notifyListeners();
    }
    return granted;
  }

  /// Sacrifices 10% (`floor(balance * 0.10)`, min balance 50 per active element)
  /// of each active element to invoke a 2x idle production speed blessing for
  /// 4 hours (extendable up to an 8-hour maximum cap).
  bool invokeOffertoryTitheBoost({DateTime? now}) {
    final nowUtc = _nowUtc(now);
    if (!canInvokeOffertoryTitheBoost(nowUtc)) {
      audio.playVibrate();
      return false;
    }

    // Bank past orbs before activating 2x speed so prior elapsed time is never retroactively doubled
    _settleOffertoryUpTo(nowUtc);

    final costs = offertoryTitheCosts();
    for (final entry in costs.entries) {
      final deduction = entry.value;
      switch (entry.key) {
        case HandMove.rock:
          fireOrbs = math.max(0, fireOrbs - deduction);
          turn0FireOrbs = math.max(0, turn0FireOrbs - deduction);
          break;
        case HandMove.paper:
          waterOrbs = math.max(0, waterOrbs - deduction);
          turn0WaterOrbs = math.max(0, turn0WaterOrbs - deduction);
          break;
        case HandMove.scissors:
          woodOrbs = math.max(0, woodOrbs - deduction);
          turn0WoodOrbs = math.max(0, turn0WoodOrbs - deduction);
          break;
        case HandMove.lizard:
          earthOrbs = math.max(0, earthOrbs - deduction);
          turn0EarthOrbs = math.max(0, turn0EarthOrbs - deduction);
          break;
        case HandMove.spock:
          metalOrbs = math.max(0, metalOrbs - deduction);
          turn0MetalOrbs = math.max(0, turn0MetalOrbs - deduction);
          break;
      }
    }

    final nowMs = nowUtc.millisecondsSinceEpoch;
    final currentExpMs = offertoryBoostExpiresAt;
    final baseMs =
        (currentExpMs != null && currentExpMs > nowMs) ? currentExpMs : nowMs;
    final maxAllowedMs =
        nowMs + offertoryTitheBoostMaxDuration.inMilliseconds;
    offertoryBoostExpiresAt = math.min(
      baseMs + offertoryTitheBoostDuration.inMilliseconds,
      maxAllowedMs,
    );

    _persistAllOrbsAndTurn0();
    _persistOffertoryState();
    audio.playWinVibrate();
    _triggerCloudSave();
    notifyListeners();
    return true;
  }

  bool unlockReset() {
    return purchaseWithOrbs(
      cost: costReset,
      onUnlock: () {
        unlockedReset = true;
        showReset = false;
        storage.setUnlockedReset(true);
        storage.setShowReset(false);
        _triggerStoryOnFirstUnlock(StoryChapter.resetButton);
      },
    );
  }

  bool unlockPredictability() {
    return purchaseWithOrbs(
      cost: costPredictability,
      onUnlock: () {
        unlockedPredictability = true;
        showPredictability = false;
        storage.setUnlockedPredictability(true);
        storage.setShowPredictability(false);
        _triggerStoryOnFirstUnlock(StoryChapter.predictabilityScore);
      },
    );
  }

  bool unlockRandom() {
    return purchaseWithOrbs(
      cost: costRandom,
      onUnlock: () {
        unlockedRandom = true;
        showRandom = false;
        storage.setUnlockedRandom(true);
        storage.setShowRandom(false);
        _triggerStoryOnFirstUnlock(StoryChapter.randomButton);
      },
    );
  }

  bool unlockAlgorithm() {
    return purchaseWithOrbs(
      cost: costAlgorithm,
      onUnlock: () {
        unlockedAlgorithm = true;
        showAlgorithm = false;
        storage.setUnlockedAlgorithm(true);
        storage.setShowAlgorithm(false);
        _triggerStoryOnFirstUnlock(StoryChapter.showAlgorithm);
      },
    );
  }

  bool unlockNewHands() {
    return purchaseWithOrbs(
      cost: costNewHands,
      onUnlock: () {
        unlockedNewHands = true;
        showNewHands = false;
        storage.setUnlockedNewHands(true);
        storage.setShowNewHands(false);
        _grantTreasuryEarthMetalBonusIfNeeded();
      },
    );
  }

  bool unlockYourPrediction() {
    return purchaseWithOrbs(
      cost: costYourPrediction,
      onUnlock: () {
        unlockedYourPrediction = true;
        showYourPrediction = false;
        storage.setUnlockedYourPrediction(true);
        storage.setShowYourPrediction(false);
        _triggerStoryOnFirstUnlock(StoryChapter.yourPrediction);
      },
    );
  }

  bool unlockNextMove() {
    return purchaseWithOrbs(
      cost: costNextMove,
      onUnlock: () {
        unlockedNextMove = true;
        showNextMove = false;
        storage.setUnlockedNextMove(true);
        storage.setShowNextMove(false);
        _triggerStoryOnFirstUnlock(StoryChapter.pcNextMove);
      },
    );
  }

  bool unlockSuggestion() {
    return purchaseWithOrbs(
      cost: costSuggestion,
      onUnlock: () {
        unlockedSuggestion = true;
        showSuggestion = false;
        storage.setUnlockedSuggestion(true);
        storage.setShowSuggestion(false);
        _triggerStoryOnFirstUnlock(StoryChapter.suggestion);
      },
    );
  }

  bool unlockAds() {
    if (unlockedAds) {
      audio.playVibrate();
      return false;
    }
    return purchaseWithOrbs(
      cost: costRemoveAds,
      onUnlock: () {
        unlockedAds = true;
        removeAdsEnabled = true;
        storage.setUnlockedAds(true);
        storage.setRemoveAdsEnabled(true);
        adService.setAdsRemoved(isRemoveAdsActive);
      },
    );
  }

  bool unlockRemoveAds() => unlockAds();

  bool unlockNewSkin() {
    return purchaseWithOrbs(
      cost: costNewSkin,
      onUnlock: () {
        unlockedNewSkin = true;
        showNewSkin = false;
        storage.setUnlockedNewSkin(true);
        storage.setShowNewSkin(false);
      },
    );
  }

  bool unlockGiftBox() {
    return purchaseWithOrbs(
      cost: costGiftBox,
      onUnlock: () {
        giftBoxUnlocked = true;
        giftBoxEnabled = false;
        storage.setGiftBoxUnlocked(true);
        storage.setGiftBoxEnabled(false);
        _pauseGiftTimer();
        isGiftAvailable = true;
        _remainingGiftCooldown = Duration.zero;
      },
    );
  }

  /// Grants +50 Elemental Orbs when the player finishes watching a rewarded ad
  /// (Fire, Water & Wood in Phase 1; all 5 elements in Phase 2+ or when
  /// Earth & Metal is unlocked), persists immediately to [SharedPreferences],
  /// triggers a [PlayGamesService] cloud save if signed in, and starts the
  /// 2-minute cooldown.
  void completeRewardedAd() {
    fireOrbs += rewardedAdOrbBonus;
    waterOrbs += rewardedAdOrbBonus;
    woodOrbs += rewardedAdOrbBonus;
    turn0FireOrbs += rewardedAdOrbBonus;
    turn0WaterOrbs += rewardedAdOrbBonus;
    turn0WoodOrbs += rewardedAdOrbBonus;
    if (includesEarthAndMetalInBonuses) {
      earthOrbs += rewardedAdOrbBonus;
      metalOrbs += rewardedAdOrbBonus;
      turn0EarthOrbs += rewardedAdOrbBonus;
      turn0MetalOrbs += rewardedAdOrbBonus;
    }
    _persistOrbsToStorage();
    _persistTurn0OrbsToStorage();
    isRewardedAdOnCooldown = true;
    _rewardedAdCooldownUntil = DateTime.now().add(rewardedAdCooldownDuration);
    _rewardedAdCooldownTimer?.cancel();
    _rewardedAdCooldownTimer = Timer(rewardedAdCooldownDuration, () {
      isRewardedAdOnCooldown = false;
      _rewardedAdCooldownUntil = null;
      notifyListeners();
    });
    _triggerCloudSave();
    notifyListeners();
  }

  /// Displays the preloaded rewarded video ad if ready, granting +50 of each
  /// Elemental Orb via [completeRewardedAd] exclusively inside `onUserEarnedReward`
  /// and invoking [onRewardEarned] upon completion.
  Future<bool> watchRewardedAd({VoidCallback? onRewardEarned}) async {
    if (!isRewardedAdReady) return false;
    bool earned = false;
    final shown = await adService.showRewardedAd(
      onUserEarnedReward: () {
        earned = true;
        completeRewardedAd();
        onRewardEarned?.call();
      },
    );
    return shown && earned;
  }

  bool unlockCrystalBall() {
    return purchaseWithOrbs(
      cost: costCrystalBall,
      onUnlock: () {
        unlockedCrystalBall = true;
        showCrystalBall = false;
        storage.setUnlockedCrystalBall(true);
        storage.setShowCrystalBall(false);
        _triggerStoryOnFirstUnlock(StoryChapter.crystalBall);
      },
    );
  }

  bool unlockCrystalBallPlus() {
    if (!unlockedCrystalBall) {
      audio.playVibrate();
      return false;
    }
    return purchaseWithOrbs(
      cost: costCrystalBallPlus,
      onUnlock: () {
        unlockedCrystalBallPlus = true;
        showCrystalBallPlus = false;
        crystalBallPlusSavedState = false;
        storage.setUnlockedCrystalBallPlus(true);
        storage.setShowCrystalBallPlus(false);
        storage.setCrystalBallPlusSavedState(false);
      },
    );
  }

  bool unlockMarkovRecalibrator() {
    if (!isMarkovRecalibratorVisibleInShop) {
      audio.playVibrate();
      return false;
    }
    return purchaseWithOrbs(
      cost: costMarkovRecalibrator,
      onUnlock: () {
        unlockedMarkovRecalibrator = true;
        showMarkovRecalibrator = true;
        storage.setUnlockedMarkovRecalibrator(true);
        storage.setShowMarkovRecalibrator(true);
        _computeNextHints();
      },
    );
  }

  /// Immediately unlocks the shop item mapped to [productId] upon a verified
  /// Google Play purchase ([PurchaseStatus.purchased]) or restore
  /// ([PurchaseStatus.restored]), persisting to [SharedPreferences] and
  /// triggering a [PlayGamesService] cloud save if signed in.
  bool unlockByProductId(
    String productId, {
    bool recordAsIap = true,
    bool triggerStory = true,
    bool triggerCloudSave = true,
  }) {
    switch (productId) {
      case BillingService.productResetButton:
        if (!unlockedReset) {
          showReset = false;
          storage.setShowReset(false);
        }
        unlockedReset = true;
        storage.setUnlockedReset(true);
        if (triggerStory) {
          _triggerStoryOnFirstUnlock(StoryChapter.resetButton);
        }
        break;
      case BillingService.productPredictabilityScore:
        if (!unlockedPredictability) {
          showPredictability = false;
          storage.setShowPredictability(false);
        }
        unlockedPredictability = true;
        storage.setUnlockedPredictability(true);
        if (triggerStory) {
          _triggerStoryOnFirstUnlock(StoryChapter.predictabilityScore);
        }
        break;
      case BillingService.productRandomButton:
        if (!unlockedRandom) {
          showRandom = false;
          storage.setShowRandom(false);
        }
        unlockedRandom = true;
        storage.setUnlockedRandom(true);
        if (triggerStory) {
          _triggerStoryOnFirstUnlock(StoryChapter.randomButton);
        }
        break;
      case BillingService.productShowAlgorithm:
        if (!unlockedAlgorithm) {
          showAlgorithm = false;
          storage.setShowAlgorithm(false);
        }
        unlockedAlgorithm = true;
        storage.setUnlockedAlgorithm(true);
        if (triggerStory) {
          _triggerStoryOnFirstUnlock(StoryChapter.showAlgorithm);
        }
        break;
      case BillingService.productNewHands:
        if (!unlockedNewHands) {
          showNewHands = false;
          storage.setShowNewHands(false);
        }
        unlockedNewHands = true;
        storage.setUnlockedNewHands(true);
        _grantTreasuryEarthMetalBonusIfNeeded();
        break;
      case BillingService.productYourPrediction:
        if (!unlockedYourPrediction) {
          showYourPrediction = false;
          storage.setShowYourPrediction(false);
        }
        unlockedYourPrediction = true;
        storage.setUnlockedYourPrediction(true);
        if (triggerStory) {
          _triggerStoryOnFirstUnlock(StoryChapter.yourPrediction);
        }
        break;
      case BillingService.productPcNextMove:
        if (!unlockedNextMove) {
          showNextMove = false;
          storage.setShowNextMove(false);
        }
        unlockedNextMove = true;
        storage.setUnlockedNextMove(true);
        if (triggerStory) {
          _triggerStoryOnFirstUnlock(StoryChapter.pcNextMove);
        }
        break;
      case BillingService.productSuggestion:
        if (!unlockedSuggestion) {
          showSuggestion = false;
          storage.setShowSuggestion(false);
        }
        unlockedSuggestion = true;
        storage.setUnlockedSuggestion(true);
        if (triggerStory) {
          _triggerStoryOnFirstUnlock(StoryChapter.suggestion);
        }
        break;
      case BillingService.productRemoveAds:
        final wasPreviouslyOwned = unlockedAds || storage.unlockedAds;
        unlockedAds = true;
        storage.setUnlockedAds(true);
        if (!wasPreviouslyOwned) {
          removeAdsEnabled = true;
          storage.setRemoveAdsEnabled(true);
        }
        adService.setAdsRemoved(isRemoveAdsActive);
        break;
      case BillingService.productCrystalBall:
        if (!unlockedCrystalBall) {
          showCrystalBall = false;
          storage.setShowCrystalBall(false);
        }
        unlockedCrystalBall = true;
        storage.setUnlockedCrystalBall(true);
        if (triggerStory) {
          _triggerStoryOnFirstUnlock(StoryChapter.crystalBall);
        }
        break;
      case BillingService.productConsumableSmall:
        addAllOrbs(allElementPackSmallBonus);
        return true;
      case BillingService.productConsumableMedium:
        addAllOrbs(allElementPackMediumBonus);
        return true;
      case BillingService.productConsumableLarge:
        addAllOrbs(allElementPackLargeBonus);
        return true;
      case BillingService.productConsumableFire1500:
        addOrbForMove(HandMove.rock, singleElementBulkPackBonus);
        return true;
      case BillingService.productConsumableWater1500:
        addOrbForMove(HandMove.paper, singleElementBulkPackBonus);
        return true;
      case BillingService.productConsumableWood1500:
        addOrbForMove(HandMove.scissors, singleElementBulkPackBonus);
        return true;
      case BillingService.productConsumableEarth1500:
        addOrbForMove(HandMove.lizard, singleElementBulkPackBonus);
        return true;
      case BillingService.productConsumableMetal1500:
        addOrbForMove(HandMove.spock, singleElementBulkPackBonus);
        return true;
      default:
        return false;
    }

    if (recordAsIap) {
      unawaited(storage.addPurchasedIapProductId(productId));
    }
    if (triggerCloudSave) {
      _triggerCloudSave();
    }
    notifyListeners();
    return true;
  }

  /// Returns true if the shop item corresponding to [productId] is unlocked.
  bool isProductUnlocked(String productId) {
    switch (productId) {
      case BillingService.productResetButton:
        return unlockedReset;
      case BillingService.productPredictabilityScore:
        return unlockedPredictability;
      case BillingService.productRandomButton:
        return unlockedRandom;
      case BillingService.productShowAlgorithm:
        return unlockedAlgorithm;
      case BillingService.productNewHands:
        return unlockedNewHands;
      case BillingService.productYourPrediction:
        return unlockedYourPrediction;
      case BillingService.productPcNextMove:
        return unlockedNextMove;
      case BillingService.productSuggestion:
        return unlockedSuggestion;
      case BillingService.productRemoveAds:
        return unlockedAds;
      case BillingService.productCrystalBall:
        return unlockedCrystalBall;
      default:
        return false;
    }
  }

  /// Initiates a Google Play Billing purchase for the non-consumable or
  /// repeatable consumable [productId].
  Future<bool> buyWithRealMoney(String productId) {
    if (BillingService.isConsumableProduct(productId)) {
      return billingService.buyConsumable(productId);
    }
    return billingService.buyNonConsumable(productId);
  }

  /// Restores previously purchased non-consumable items from Google Play.
  Future<bool> restorePurchases() {
    return billingService.restorePurchases();
  }

  /// Gift feature: periodic free +5 Elemental Orbs
  /// (Fire, Water & Wood in Phase 1; all 5 elements in Phase 2+ or when
  /// Earth & Metal is unlocked).
  void claimGift() {
    if (!giftBoxUnlocked || !giftBoxEnabled || !isGiftAvailable) return;
    fireOrbs += periodicGiftOrbBonus;
    waterOrbs += periodicGiftOrbBonus;
    woodOrbs += periodicGiftOrbBonus;
    if (includesEarthAndMetalInBonuses) {
      earthOrbs += periodicGiftOrbBonus;
      metalOrbs += periodicGiftOrbBonus;
    }
    _persistOrbsToStorage();
    isGiftAvailable = false;
    audio.playVibrate();
    _triggerCloudSave();
    _startGiftTimer(giftCooldownDuration);
    notifyListeners();
  }

  void _startGiftTimer(Duration duration) {
    _giftTimer?.cancel();
    if (!giftBoxUnlocked || !giftBoxEnabled) {
      _giftTimer = null;
      _giftCooldownUntil = null;
      return;
    }
    if (duration <= Duration.zero) {
      isGiftAvailable = true;
      _giftTimer = null;
      _giftCooldownUntil = null;
      _remainingGiftCooldown = Duration.zero;
      notifyListeners();
      return;
    }
    isGiftAvailable = false;
    _remainingGiftCooldown = duration;
    _giftCooldownUntil = DateTime.now().add(duration);
    _giftTimer = Timer(duration, () {
      _giftTimer = null;
      _giftCooldownUntil = null;
      _remainingGiftCooldown = Duration.zero;
      if (giftBoxUnlocked && giftBoxEnabled) {
        isGiftAvailable = true;
        notifyListeners();
      }
    });
  }

  void _pauseGiftTimer() {
    if (_giftTimer != null &&
        _giftTimer!.isActive &&
        _giftCooldownUntil != null) {
      final remaining = _giftCooldownUntil!.difference(DateTime.now());
      if (remaining.isNegative || remaining == Duration.zero) {
        _remainingGiftCooldown = Duration.zero;
      } else if (remaining > giftCooldownDuration) {
        _remainingGiftCooldown = giftCooldownDuration;
      } else {
        _remainingGiftCooldown = remaining;
      }
    }
    _giftTimer?.cancel();
    _giftTimer = null;
    _giftCooldownUntil = null;
  }

  void _resumeGiftTimerIfNeeded() {
    if (!giftBoxUnlocked || !giftBoxEnabled) return;
    if (isGiftAvailable || isGiftTimerActive) return;
    if (_remainingGiftCooldown <= Duration.zero) {
      isGiftAvailable = true;
    } else {
      _startGiftTimer(_remainingGiftCooldown);
    }
  }

  /// 7-tap QA shortcut on the top-left Backpack icon: grants +100,000 of each
  /// of the 5 Elemental Orbs on the 7th tap.
  bool registerBackpackQaTap() {
    final now = DateTime.now();
    if (_lastBackpackQaTapTime != null &&
        now.difference(_lastBackpackQaTapTime!) > const Duration(seconds: 3)) {
      _backpackQaTapCount = 0;
    }
    _lastBackpackQaTapTime = now;
    _backpackQaTapCount += 1;
    if (_backpackQaTapCount >= 7) {
      _backpackQaTapCount = 0;
      addAllOrbs(qaShortcutOrbBonus);
      return true;
    }
    return false;
  }

  // Toggles for active unlocks
  void toggleShowReset(bool val) {
    showReset = val;
    storage.setShowReset(val);
    _triggerCloudSave();
    notifyListeners();
  }

  void toggleShowPredictability(bool val) {
    showPredictability = val;
    storage.setShowPredictability(val);
    _triggerCloudSave();
    notifyListeners();
  }

  void toggleShowRandom(bool val) {
    showRandom = val;
    storage.setShowRandom(val);
    _triggerCloudSave();
    notifyListeners();
  }

  void toggleShowAlgorithm(bool val) {
    showAlgorithm = val;
    storage.setShowAlgorithm(val);
    _triggerCloudSave();
    notifyListeners();
  }

  void toggleShowYourPrediction(bool val) {
    showYourPrediction = val;
    storage.setShowYourPrediction(val);
    _triggerCloudSave();
    notifyListeners();
  }

  void toggleShowNextMove(bool val) {
    showNextMove = val;
    storage.setShowNextMove(val);
    _triggerCloudSave();
    notifyListeners();
  }

  void toggleShowSuggestion(bool val) {
    showSuggestion = val;
    storage.setShowSuggestion(val);
    _triggerCloudSave();
    notifyListeners();
  }

  void toggleRemoveAds(bool val) {
    if (!unlockedAds) return;
    removeAdsEnabled = val;
    storage.setRemoveAdsEnabled(val);
    adService.setAdsRemoved(isRemoveAdsActive);
    _triggerCloudSave();
    notifyListeners();
  }

  void toggleGiftBox(bool val) {
    if (!giftBoxUnlocked) return;
    giftBoxEnabled = val;
    storage.setGiftBoxEnabled(val);
    if (val) {
      _resumeGiftTimerIfNeeded();
    } else {
      _pauseGiftTimer();
    }
    _triggerCloudSave();
    notifyListeners();
  }

  void toggleShowCrystalBall(bool val) {
    if (!val) {
      if (showCrystalBall) {
        crystalBallPlusSavedState = showCrystalBallPlus;
        storage.setCrystalBallPlusSavedState(crystalBallPlusSavedState);
      }
      showCrystalBall = false;
      storage.setShowCrystalBall(false);
      showCrystalBallPlus = false;
      storage.setShowCrystalBallPlus(false);
    } else {
      showCrystalBall = true;
      storage.setShowCrystalBall(true);
      if (unlockedCrystalBallPlus) {
        showCrystalBallPlus = crystalBallPlusSavedState;
        storage.setShowCrystalBallPlus(showCrystalBallPlus);
      }
    }
    _triggerCloudSave();
    notifyListeners();
  }

  void toggleShowCrystalBallPlus(bool val) {
    if (val && !showCrystalBall) {
      return;
    }
    showCrystalBallPlus = val;
    storage.setShowCrystalBallPlus(val);
    if (showCrystalBall) {
      crystalBallPlusSavedState = val;
      storage.setCrystalBallPlusSavedState(val);
    }
    _triggerCloudSave();
    notifyListeners();
  }

  void toggleMarkovRecalibrator(bool val) {
    if (!unlockedMarkovRecalibrator) {
      return;
    }
    showMarkovRecalibrator = val;
    storage.setShowMarkovRecalibrator(val);
    _computeNextHints();
    _triggerCloudSave();
    notifyListeners();
  }

  bool unlockOrUpgradeOverchargedStaff() {
    if (overchargedStaffLevel >= overchargedStaffMaxLevel) {
      audio.playVibrate();
      return false;
    }
    final nextLevel = overchargedStaffLevel + 1;
    final cost = overchargedStaffCostForLevel(nextLevel);
    return purchaseWithOrbs(
      cost: cost,
      onUnlock: () {
        overchargedStaffLevel = nextLevel;
        if (nextLevel == 1) {
          overchargedStaffEnabled = true;
          overchargedStaffSelectedSpeed = 1;
        } else {
          overchargedStaffSelectedSpeed =
              overchargedStaffSpeedForLevel(nextLevel);
        }
        storage.setOverchargedStaffLevel(overchargedStaffLevel);
        storage.setOverchargedStaffEnabled(overchargedStaffEnabled);
        storage.setOverchargedStaffSelectedSpeed(
          overchargedStaffSelectedSpeed,
        );
      },
    );
  }

  void toggleOverchargedStaff(bool val) {
    if (overchargedStaffLevel < 1) return;
    overchargedStaffEnabled = val;
    storage.setOverchargedStaffEnabled(val);
    _triggerCloudSave();
    notifyListeners();
  }

  bool selectOverchargedStaffSpeed(int speed) {
    if (overchargedStaffLevel < 1 ||
        !overchargedStaffSpeedOptions.contains(speed)) {
      audio.playVibrate();
      return false;
    }
    final requiredLevel = overchargedStaffRequiredLevelForSpeed(speed);
    if (overchargedStaffLevel < requiredLevel) {
      audio.playVibrate();
      return false;
    }
    overchargedStaffSelectedSpeed = speed;
    storage.setOverchargedStaffSelectedSpeed(speed);
    _triggerCloudSave();
    notifyListeners();
    return true;
  }

  void toggleShowNewHands(bool val) {
    showNewHands = val;
    storage.setShowNewHands(val);
    _engine = MarkovEngine(
      enableExtendedHands: val,
      enableEnemyExtendedHands: enemyUses5Elements,
      enemyAllowedMoves: bossAllowedMoves,
      enableElementalMode: isElementalMode,
    );
    _resetBattleState();
    recordTurn0OrbSnapshot();
    _triggerCloudSave();
    notifyListeners();
  }

  /// Toggles the "New Skin" item ON or OFF seamlessly over the
  /// existing move indices without resetting the current match, scores, or
  /// Markov transition matrix.
  ///
  /// Starting skin is the Elemental Theme.
  /// Acquiring and enabling the "New Skin" item switches to the Hands Theme.
  void toggleShowNewSkin(bool val) {
    showNewSkin = val;
    storage.setShowNewSkin(val);
    _engine.enableElementalMode = isElementalMode;

    if (currentUserMove != null && currentComputerMove != null) {
      final antiMetalBlocked =
          enemyStage == 3 && currentUserMove == HandMove.metal;
      lastRoundBlockedByAntiMetalShield = antiMetalBlocked;
      lastWinner = antiMetalBlocked
          ? RoundWinner.draw
          : currentUserMove!.resolvesAgainst(
              currentComputerMove!,
              elemental: isElementalMode,
            );
    }

    _computeNextHints();
    _triggerCloudSave();
    notifyListeners();
  }

  // Settings
  void toggleDarkMode(bool val) {
    darkMode = val;
    storage.setDarkMode(val);
    _triggerCloudSave();
    notifyListeners();
  }

  void toggleSound() {
    soundEnabled = !soundEnabled;
    storage.setSoundEnabled(soundEnabled);
    audio.soundEnabled = soundEnabled;
    _triggerCloudSave();
    notifyListeners();
  }

  void toggleMusic(bool val) {
    musicEnabled = val;
    storage.setMusicEnabled(val);
    audio.musicEnabled = val;
    if (val) {
      audio.startMusic();
    } else {
      audio.stopMusic();
    }
    _triggerCloudSave();
    notifyListeners();
  }

  void toggleVibration(bool val) {
    vibrationEnabled = val;
    storage.setVibrationEnabled(vibrationEnabled);
    audio.vibrationEnabled = vibrationEnabled;
    _triggerCloudSave();
    notifyListeners();
  }

  void toggleAnimations(bool val) {
    animationsEnabled = val;
    storage.setAnimationsEnabled(val);
    _triggerCloudSave();
    notifyListeners();
  }

  void setConfirmBattleTeleport(bool val) {
    confirmBattleTeleport = val;
    storage.setConfirmBattleTeleport(val);
    _triggerCloudSave();
    notifyListeners();
  }

  void setLanguage(String lang) {
    localization.setLanguage(lang);
    storage.setLanguage(lang);
    _triggerCloudSave();
    notifyListeners();
  }

  /// Grants [amount] of each of the 5 Elemental Orbs.
  void addAllOrbs(int amount) {
    fireOrbs += amount;
    waterOrbs += amount;
    woodOrbs += amount;
    earthOrbs += amount;
    metalOrbs += amount;
    turn0FireOrbs += amount;
    turn0WaterOrbs += amount;
    turn0WoodOrbs += amount;
    turn0EarthOrbs += amount;
    turn0MetalOrbs += amount;
    _persistOrbsToStorage();
    _persistTurn0OrbsToStorage();
    _triggerCloudSave();
    notifyListeners();
  }

  /// Grants [amount] of a specific element's orb.
  void addOrbForMove(HandMove move, int amount) {
    _incrementOrbForMove(move, amount);
    switch (move) {
      case HandMove.rock:
        turn0FireOrbs += amount;
        storage.setTurn0FireOrbs(turn0FireOrbs);
        break;
      case HandMove.paper:
        turn0WaterOrbs += amount;
        storage.setTurn0WaterOrbs(turn0WaterOrbs);
        break;
      case HandMove.scissors:
        turn0WoodOrbs += amount;
        storage.setTurn0WoodOrbs(turn0WoodOrbs);
        break;
      case HandMove.lizard:
        turn0EarthOrbs += amount;
        storage.setTurn0EarthOrbs(turn0EarthOrbs);
        break;
      case HandMove.spock:
        turn0MetalOrbs += amount;
        storage.setTurn0MetalOrbs(turn0MetalOrbs);
        break;
    }
    _triggerCloudSave();
    notifyListeners();
  }

  void cancelPendingTimers() {
    _giftTimer?.cancel();
    _giftTimer = null;
    _giftCooldownUntil = null;
    _remainingGiftCooldown = Duration.zero;
    _rewardedAdCooldownTimer?.cancel();
    _rewardedAdCooldownTimer = null;
    playGames.cancelPendingRetries();
  }

  @override
  void dispose() {
    cancelPendingTimers();
    playGames.removeListener(_handlePlayGamesUpdate);
    adService.removeListener(_handleAdServiceUpdate);
    billingService.removeListener(_handleBillingServiceUpdate);
    updateService.removeListener(_handleUpdateServiceUpdate);
    super.dispose();
  }
}
