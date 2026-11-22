import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../models/move.dart';
import '../models/evaluation_tier.dart';
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
  static const int maxTreasuryPerElement = 50;
  static const int maxTreasuryTotal = 250;
  static const int maxWeeklyAdConsagrations = 3;
  static const int vitalityBlessingBonusHp = 15;
  static const int clairvoyanceBlessingMoves = 3;
  static const int allElementPackSmallBonus = 500;
  static const int allElementPackMediumBonus = 2500;
  static const int allElementPackLargeBonus = 10000;
  static const int singleElementBulkPackBonus = 1500;

  static ElementalCost maxHpUpgradeCostForLevel(int level) {
    final perOrb = 2 + (level ~/ 2);
    return ElementalCost(fire: perOrb, water: perOrb, wood: perOrb);
  }

  static ElementalCost maxManaUpgradeCostForLevel(int level) {
    final perOrb = 3 + (level ~/ 2);
    return ElementalCost(fire: perOrb, water: perOrb, wood: perOrb);
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

  // Overcharged Staff Tiered Upgrade Constants (Levels 1..4)
  static const int overchargedStaffMaxLevel = 4;
  static const List<int> overchargedStaffSpeedOptions = [1, 2, 5, 10];
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

  HandMove? currentUserMove;
  HandMove? currentComputerMove;
  HandMove? lastUserMove;

  HandMove? predictedUserMove;
  HandMove? pcNextMove;
  HandMove? suggestedMove;
  HandMove? crystalBallMove;

  /// Predicted upcoming PC move(s) revealed by Crystal Ball.
  List<HandMove> get crystalBallMoves =>
      crystalBallMove != null ? [crystalBallMove!] : const [];

  /// All active player elements that defeat the Crystal Ball's predicted PC
  /// element(s), derived directly from [crystalBallMoves].
  List<HandMove> get crystalBallPlusMoves {
    final predictedPcMoves = crystalBallMoves;
    if (predictedPcMoves.isEmpty) return const [];
    final counters = <HandMove>[];
    for (final pcMove in predictedPcMoves) {
      for (final playerMove in _engine.activeMoves) {
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
  int currentWeek = 1;

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

  int spoilsFireOrbs = 0;
  int spoilsWaterOrbs = 0;
  int spoilsWoodOrbs = 0;
  int spoilsEarthOrbs = 0;
  int spoilsMetalOrbs = 0;

  List<String> relicChamberStoredUpgrades = [];
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
  int? fastestVictoryWeek;
  int guardianRobotDefeatedCount = 0;
  int robotArchmageDefeatedCount = 0;
  int metalWizardDefeatedCount = 0;
  int babyMageRobotDefeatedCount = 0;

  List<String> activeDecreeIds =
      List<String>.from(RoyalDecreeType.defaultActiveIds);
  Set<String> completedCycleDecreeIds = {};
  int totalDecreesCompleted = 0;
  int decreeNoRepeatWinCount = 0;
  int decreeWinStreak = 0;
  Set<String> decreeDefeatedElements = {};

  GameController({
    required this.storage,
    required this.localization,
    required this.audio,
    PlayGamesService? playGames,
    AdService? adService,
    BillingService? billingService,
    UpdateService? updateService,
  }) {
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

  /// True when Remove Ads is both owned (`unlockedAds`) and actively enabled (`removeAdsEnabled`).
  bool get isRemoveAdsActive => unlockedAds && removeAdsEnabled;

  /// True when the bottom banner ad should be displayed on screen.
  bool get shouldShowBannerAd => !isRemoveAdsActive && adService.isBannerAdLoaded;

  /// True when the optional Rewarded Video ad (+50 Orbs) is preloaded and not on cooldown.
  bool get isRewardedAdReady =>
      adService.isRewardedAdReady && !isRewardedAdOnCooldown;

  /// True when a Rewarded Video ad is preloaded and ready for death revival
  /// (unaffected by the +50 Orbs anti-spam cooldown).
  bool get isReviveAdReady => adService.isRewardedAdReady;

  /// True when advancing +1 Week from the current campaign week exceeds [maxCampaignWeeks] (40)
  /// and enters [siegeInvasionWeek] (Week 41).
  bool get willNextWeekExceedLimit => currentWeek + 1 > maxCampaignWeeks;

  /// Highest week inspectable on the World Map timeline slider:
  /// ranges from Week 1 up to [currentWeek] (or [siegeInvasionWeek] = 41 once
  /// Ending 2 / Week 41 Siege has been experienced or reached).
  int get maxInspectableWorldMapWeek {
    if (currentWeek >= siegeInvasionWeek || timeoutDefeatCount > 0) {
      return siegeInvasionWeek;
    }
    return currentWeek.clamp(1, siegeInvasionWeek);
  }

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

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      audio.pauseMusic();
    } else if (state == AppLifecycleState.resumed) {
      audio.resumeMusic();
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

  bool get isWeekPhase2 => currentWeek >= phase2StartWeek;

  bool get isPhase2 => isWeekPhase2 || enemyStage >= 2;

  bool get enemyUses5Elements => enemyStage >= 2 || isWeekPhase2;

  bool get isGuardianBoss => enemyStage == 1;

  bool get isArchmageBoss => enemyStage == 2;

  bool get isMetalWizardBoss => enemyStage == 3;

  bool get isBabyMageBoss => enemyStage == 4;

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
    userScore = storage.userScore;
    pcScore = storage.pcScore;
    totalRounds = storage.total;
    currentWeek = storage.currentWeek;
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

    enemyPhase = storage.enemyPhase.clamp(1, 3);
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
    if (restartAudio && musicEnabled) {
      audio.startMusic();
    }

    _engine = MarkovEngine(
      enableExtendedHands: showNewHands,
      enableEnemyExtendedHands: enemyUses5Elements,
      enableElementalMode: isElementalMode,
    );
    final savedMatrix = storage.getMarkovMatrix(_engine.size);
    if (savedMatrix != null) {
      _engine.setMatrix(savedMatrix);
    }
    _engine.setLastTransitions(storage.shortTermTransitions);

    currentUserMove = storage.lastUserMove;
    currentComputerMove = storage.lastComputerMove;
    if (!showNewHands) {
      if (currentUserMove == HandMove.lizard ||
          currentUserMove == HandMove.spock) {
        currentUserMove = null;
      }
      if (!enemyUses5Elements &&
          (currentComputerMove == HandMove.lizard ||
              currentComputerMove == HandMove.spock)) {
        currentComputerMove = null;
      }
    }
    if (currentUserMove == null || currentComputerMove == null) {
      currentUserMove = null;
      currentComputerMove = null;
      lastWinner = null;
    } else {
      lastWinner = currentUserMove!.resolvesAgainst(
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

    spoilsFireOrbs = storage.spoilsFireOrbs;
    spoilsWaterOrbs = storage.spoilsWaterOrbs;
    spoilsWoodOrbs = storage.spoilsWoodOrbs;
    spoilsEarthOrbs = storage.spoilsEarthOrbs;
    spoilsMetalOrbs = storage.spoilsMetalOrbs;

    relicChamberStoredUpgrades = List<String>.from(storage.relicChamberUpgrades);
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
    fastestVictoryWeek = storage.fastestVictoryWeek;
    guardianRobotDefeatedCount = storage.guardianRobotDefeatedCount;
    robotArchmageDefeatedCount = storage.robotArchmageDefeatedCount;
    metalWizardDefeatedCount = storage.metalWizardDefeatedCount;
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

  bool get isAnyTreasuryElementFull =>
      treasuryFireOrbs >= maxTreasuryPerElement ||
      treasuryWaterOrbs >= maxTreasuryPerElement ||
      treasuryWoodOrbs >= maxTreasuryPerElement ||
      treasuryEarthOrbs >= maxTreasuryPerElement ||
      treasuryMetalOrbs >= maxTreasuryPerElement;

  bool get isTreasuryCompletelyFull =>
      treasuryFireOrbs >= maxTreasuryPerElement &&
      treasuryWaterOrbs >= maxTreasuryPerElement &&
      treasuryWoodOrbs >= maxTreasuryPerElement &&
      treasuryEarthOrbs >= maxTreasuryPerElement &&
      treasuryMetalOrbs >= maxTreasuryPerElement;

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

  List<ShopUpgradeArtifact> get availableRelicChamberArtifacts {
    final result = <ShopUpgradeArtifact>[];
    final seen = <ShopUpgradeArtifact>{};
    for (final id in relicChamberStoredUpgrades) {
      final artifact = ShopUpgradeArtifact.fromId(id);
      if (artifact == null || !seen.add(artifact)) continue;
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

  bool get hasRoyalCastleNotification =>
      isAnyTreasuryElementFull ||
      hasAvailableRelicChamberUpgrades ||
      hasSpoilsOfWarOrbs ||
      hasHallOfHeroesBlessings;

  bool isEndingUnlocked(NarrativeEnding ending) =>
      unlockedEndings.contains(ending.id);

  int get unlockedEndingsCount => NarrativeEnding.values
      .where((e) => unlockedEndings.contains(e.id))
      .length;

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

  void _depositTreasuryOrbForMove(HandMove move, int delta) {
    if (delta <= 0) return;
    switch (move) {
      case HandMove.rock:
        treasuryFireOrbs = math.min(
          maxTreasuryPerElement,
          treasuryFireOrbs + delta,
        );
        storage.setTreasuryFireOrbs(treasuryFireOrbs);
        break;
      case HandMove.paper:
        treasuryWaterOrbs = math.min(
          maxTreasuryPerElement,
          treasuryWaterOrbs + delta,
        );
        storage.setTreasuryWaterOrbs(treasuryWaterOrbs);
        break;
      case HandMove.scissors:
        treasuryWoodOrbs = math.min(
          maxTreasuryPerElement,
          treasuryWoodOrbs + delta,
        );
        storage.setTreasuryWoodOrbs(treasuryWoodOrbs);
        break;
      case HandMove.lizard:
        treasuryEarthOrbs = math.min(
          maxTreasuryPerElement,
          treasuryEarthOrbs + delta,
        );
        storage.setTreasuryEarthOrbs(treasuryEarthOrbs);
        break;
      case HandMove.spock:
        treasuryMetalOrbs = math.min(
          maxTreasuryPerElement,
          treasuryMetalOrbs + delta,
        );
        storage.setTreasuryMetalOrbs(treasuryMetalOrbs);
        break;
    }
  }

  void _depositTreasuryAllElements(int amountPerElement) {
    if (amountPerElement <= 0) return;
    treasuryFireOrbs = math.min(
      maxTreasuryPerElement,
      treasuryFireOrbs + amountPerElement,
    );
    treasuryWaterOrbs = math.min(
      maxTreasuryPerElement,
      treasuryWaterOrbs + amountPerElement,
    );
    treasuryWoodOrbs = math.min(
      maxTreasuryPerElement,
      treasuryWoodOrbs + amountPerElement,
    );
    treasuryEarthOrbs = math.min(
      maxTreasuryPerElement,
      treasuryEarthOrbs + amountPerElement,
    );
    treasuryMetalOrbs = math.min(
      maxTreasuryPerElement,
      treasuryMetalOrbs + amountPerElement,
    );
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

    _persistOrbsToStorage();
    _persistTurn0OrbsToStorage();
    _persistTreasuryOrbsToStorage();
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

  void _unlockArtifactWithoutCost(ShopUpgradeArtifact artifact) {
    switch (artifact) {
      case ShopUpgradeArtifact.predictability:
        unlockedPredictability = true;
        storage.setUnlockedPredictability(true);
        break;
      case ShopUpgradeArtifact.reset:
        unlockedReset = true;
        storage.setUnlockedReset(true);
        break;
      case ShopUpgradeArtifact.newHands:
        unlockedNewHands = true;
        storage.setUnlockedNewHands(true);
        break;
      case ShopUpgradeArtifact.random:
        unlockedRandom = true;
        storage.setUnlockedRandom(true);
        break;
      case ShopUpgradeArtifact.algorithm:
        unlockedAlgorithm = true;
        storage.setUnlockedAlgorithm(true);
        break;
      case ShopUpgradeArtifact.yourPrediction:
        unlockedYourPrediction = true;
        storage.setUnlockedYourPrediction(true);
        break;
      case ShopUpgradeArtifact.nextMove:
        unlockedNextMove = true;
        storage.setUnlockedNextMove(true);
        break;
      case ShopUpgradeArtifact.giftBox:
        giftBoxUnlocked = true;
        storage.setGiftBoxUnlocked(true);
        break;
      case ShopUpgradeArtifact.suggestion:
        unlockedSuggestion = true;
        storage.setUnlockedSuggestion(true);
        break;
      case ShopUpgradeArtifact.newSkin:
        unlockedNewSkin = true;
        storage.setUnlockedNewSkin(true);
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
        storage.setUnlockedCrystalBall(true);
        break;
      case ShopUpgradeArtifact.crystalBallPlus:
        unlockedCrystalBall = true;
        unlockedCrystalBallPlus = true;
        storage.setUnlockedCrystalBall(true);
        storage.setUnlockedCrystalBallPlus(true);
        break;
      case ShopUpgradeArtifact.markovRecalibrator:
        unlockedMarkovRecalibrator = true;
        storage.setUnlockedMarkovRecalibrator(true);
        break;
      case ShopUpgradeArtifact.overchargedStaff:
        final targetLevel = math
            .max(
              overchargedStaffLevel,
              math.max(1, storedRelicOverchargedStaffLevel),
            )
            .clamp(1, overchargedStaffMaxLevel);
        overchargedStaffLevel = targetLevel;
        overchargedStaffEnabled = true;
        overchargedStaffSelectedSpeed =
            overchargedStaffSpeedForLevel(targetLevel);
        storage.setOverchargedStaffLevel(overchargedStaffLevel);
        storage.setOverchargedStaffEnabled(true);
        storage.setOverchargedStaffSelectedSpeed(overchargedStaffSelectedSpeed);
        break;
    }
  }

  bool _restoreStoredRelics() {
    final toRestore = availableRelicChamberArtifacts;
    if (toRestore.isEmpty) {
      relicChamberStoredUpgrades = [];
      storage.setRelicChamberUpgrades(const []);
      notifyListeners();
      return false;
    }
    for (final artifact in toRestore) {
      _unlockArtifactWithoutCost(artifact);
    }
    relicChamberStoredUpgrades = [];
    storage.setRelicChamberUpgrades(const []);
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
    _engine.enableEnemyExtendedHands = enemyUses5Elements;
    final previousMove = lastUserMove;
    currentUserMove = userChoice;

    if (enemyStage == 1) {
      _markBestiaryEncountered(BestiaryCreature.guardianRobot);
    } else if (enemyStage == 2) {
      _markBestiaryEncountered(BestiaryCreature.archmageRobot);
    } else if (enemyStage == 3) {
      _markBestiaryEncountered(BestiaryCreature.metalWizard);
    } else if (enemyStage == 4) {
      _markBestiaryEncountered(BestiaryCreature.babyRobot);
    }

    // AI uses the move already pre-computed before the user chose their hand
    currentComputerMove =
        crystalBallMove ?? _chooseComputerMoveForCurrentPhase(previousMove);

    // Determine round outcome via HandMove.resolvesAgainst (supports 3-vs-5 Wu Xing)
    final roundOutcome = currentUserMove!.resolvesAgainst(
      currentComputerMove!,
      elemental: isElementalMode,
    );
    if (roundOutcome == RoundWinner.draw) {
      lastWinner = RoundWinner.draw;
      decreeWinStreak = 0;
      if (previousMove != null && userChoice == previousMove) {
        decreeNoRepeatWinCount = 0;
      }
      storage.setDecreeWinStreak(decreeWinStreak);
      storage.setDecreeNoRepeatWinCount(decreeNoRepeatWinCount);
      audio.playDraw(vibrate: !isRapidFire);
    } else if (roundOutcome == RoundWinner.user) {
      lastWinner = RoundWinner.user;
      userScore += 1;
      // Grant +1 (or 2x with Harvest blessing) Elemental Orb of the defeated AI/PC element
      final orbGain = isHarvestBlessingActive ? 2 : 1;
      _incrementOrbForMove(currentComputerMove!, orbGain);
      // Mirror +1 Elemental Orb into Royal Treasury Piggy Bank (capped at 50/element)
      _depositTreasuryOrbForMove(currentComputerMove!, 1);
      lastCollectedOrbMove = currentComputerMove;
      orbCollectionEventId += 1;
      computerHp = (computerHp - playerWinDamageToBoss).clamp(0, enemyMaxHp);
      storage.setUserScore(userScore);
      storage.setPcHp(computerHp);

      // Update Royal Decree trackers
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

      audio.playWin(vibrate: !isRapidFire);
    } else {
      lastWinner = RoundWinner.computer;
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
      audio.playDefeat(vibrate: !isRapidFire);
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
      if (percentPredict == 100) {
        _markEndingUnlocked(NarrativeEnding.perfectPredictor);
      } else if (percentPredict > 50) {
        _markEndingUnlocked(NarrativeEnding.triumphantStrategist);
      } else {
        _markEndingUnlocked(NarrativeEnding.outpredicted);
      }
    }

    if (lastWinner == RoundWinner.user ||
        computerHp <= 0 ||
        totalRounds >= playerMaxMana) {
      _triggerCloudSave();
    }

    _computeNextHints();
    notifyListeners();
  }

  HandMove _chooseComputerMoveForCurrentPhase(HandMove? previousMove) {
    if (enemyStage == 4) {
      // Stage 4 Baby Mage Robot: pure uniform random (1/5 per element).
      return _engine.getRandomEnemyMove();
    }
    if (enemyStage == 3) {
      // Stage 3 Metal Wizard: 100% pure Metal magic (bypasses Markov matrix).
      return HandMove.metal;
    }
    if (enemyStage == 2) {
      // Stage 2 Robot Archmage: 1-step short-term memory counter if available.
      if (_engine.hasShortTermPrediction(previousMove)) {
        return _engine.computeShortTermSmartChoice(previousMove);
      }
      return _engine.getRandomEnemyMove();
    }
    // Stage 1 Guardian Robot: standard cumulative Markov prediction.
    if (_engine.hasPrediction(previousMove)) {
      return _engine.computeSmartChoice(previousMove);
    }
    return _engine.getRandomEnemyMove();
  }

  void _recordFastestVictoryWeek(int week) {
    final effectiveWeek = week < 1 ? 1 : week;
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
      if (week == 1) {
        _markEndingUnlocked(NarrativeEnding.secretWeek1);
        secretVictoryCount += 1;
        totalCyclesCount += 1;
        storage.setSecretVictoryCount(secretVictoryCount);
        storage.setTotalCyclesCount(totalCyclesCount);
        _recordFastestVictoryWeek(1);
      } else {
        _markBestiaryEncountered(BestiaryCreature.babyRobot);
      }
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

  /// Advances the campaign state after the user confirms the Boss Defeated modal
  /// (and any ending cutscene). Returns `true` if the campaign cycle concluded
  /// (Secret Week-1 Ending on Stage 3 in Week 1, or Stage 4 Standard Victory Ending)
  /// so the caller can return to the World Map.
  bool advanceAfterBossVictory() {
    final defeatedStage = pendingBossVictoryStage ?? enemyStage;
    final week = pendingBossVictoryWeek ?? currentWeek;
    isBossVictoryPending = false;
    pendingBossVictoryStage = null;
    pendingBossVictoryWeek = null;

    final bool concludesCycle =
        (defeatedStage == 3 && week == 1) || defeatedStage == 4;
    if (concludesCycle) {
      enemyStage = 1;
      enemyMaxHp = pcMaxHp;
      currentWeek = 1;
      adConsagrationsThisWeek = 0;
      activeBattleBlessing = null;
      battleBonusTempHp = 0;
      storage.setEnemyStage(1);
      storage.setEnemyMaxHp(pcMaxHp);
      storage.setCurrentWeek(1);
      storage.setAdConsagrationsThisWeek(0);
      storage.setActiveBattleBlessing(null);
      storage.setBattleBonusTempHp(0);
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

  void _computeNextHints() {
    _engine.enableEnemyExtendedHands = enemyUses5Elements;
    crystalBallMove = _chooseComputerMoveForCurrentPhase(lastUserMove);

    if (enemyStage == 4) {
      // Pure uniform random 1/5 AI: Markov prediction hints are meaningless.
      predictedUserMoves = const [];
      pcNextMoves = const [];
      suggestedMoves = const [];
      predictedUserMove = null;
      pcNextMove = null;
      suggestedMove = null;
      return;
    }

    if (enemyStage == 3) {
      // Stage 3 Metal Wizard: conjures ONLY Metal (100%) every turn.
      predictedUserMoves = _engine.predictNextUserMoves(lastUserMove);
      pcNextMoves = const [HandMove.metal];
      suggestedMoves = _engine.computeSuggestions(pcNextMoves);
      predictedUserMove =
          predictedUserMoves.isNotEmpty ? predictedUserMoves.first : null;
      pcNextMove = HandMove.metal;
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
    lastUserMove = null;
    lastWinner = null;
    lastCollectedOrbMove = null;
    userHp = effectivePlayerMaxHp;
    enemyMaxHp = maxHpForEnemyStage(enemyStage);
    computerHp = enemyMaxHp;
    is100RoundsAlertPending = false;
    isDeathAlertPending = false;
    isBossVictoryPending = false;
    pendingBossVictoryStage = null;
    pendingBossVictoryWeek = null;
    _engine.enableEnemyExtendedHands = enemyUses5Elements;
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

  /// Advances the campaign calendar by +1 Week upon exiting a battle via
  /// battle completion or Teleport, persists locally, resets weekly ad
  /// consagrations and active battle blessings, resets the battle arena for
  /// the next encounter while keeping collected Elemental Orbs, and syncs Cloud Save.
  void completeBattleWeek() {
    currentWeek += 1;
    adConsagrationsThisWeek = 0;
    activeBattleBlessing = null;
    battleBonusTempHp = 0;
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
            : PermadeathCause.battleDefeat);

    final nextTotalCycles = totalCyclesCount + 1;
    final nextDeathDefeats = resolvedCause == PermadeathCause.battleDefeat
        ? deathDefeatCount + 1
        : deathDefeatCount;
    final nextTimeoutDefeats =
        resolvedCause == PermadeathCause.deadlineExceeded
            ? timeoutDefeatCount + 1
            : timeoutDefeatCount;

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

    // 2. Snapshot lost orb-bought upgrades into Relic Chamber (excluding paid IAPs)
    final lostUpgrades = _collectLostRelicIds(verifiedPaidIds);
    final nextRelicUpgrades = lostUpgrades.isNotEmpty
        ? lostUpgrades
        : List<String>.from(relicChamberStoredUpgrades);

    // 2b. Preserve independent all-time historical peaks and unlock Hall of Heroes claim for the next cycle
    final nextPeakHp = math.max(peakHpUpgradeLevel, hpUpgradeLevel);
    final nextPeakMana = math.max(peakManaUpgradeLevel, manaUpgradeLevel);
    final nextClaimAvailable = nextPeakHp > 0 || nextPeakMana > 0;

    // 3. Record Kingdom Fall ending
    final nextEndings = <String>{
      ...unlockedEndings,
      NarrativeEnding.kingdomFall.id,
    }.toList();

    await storage.clearGameplayProgress(
      includeSettings: false,
      includeCastleMeta: false,
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
    await storage.setPeakHpUpgradeLevel(nextPeakHp);
    await storage.setPeakManaUpgradeLevel(nextPeakMana);
    await storage.setHallOfHeroesClaimAvailable(nextClaimAvailable);
    await storage.setUnlockedEndings(nextEndings);
    await storage.setTotalCyclesCount(nextTotalCycles);
    await storage.setDeathDefeatCount(nextDeathDefeats);
    await storage.setTimeoutDefeatCount(nextTimeoutDefeats);
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

  List<String> _mergeRelicUpgradeIds(
    List<String> existing,
    List<String> incoming,
  ) {
    final merged = <String>{};
    int maxStaffLevel = 0;
    for (final raw in [...existing, ...incoming]) {
      final clean = raw.trim();
      if (clean.isEmpty) continue;
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
  /// & bestiary, Hall of Heroes records, Royal Treasury, verified real-money
  /// IAPs such as Remove Ads, and UI settings) and syncing with Cloud Save.
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

    // 1. Archive active Elemental Orbs into Spoils of War (Double-Reset Guard)
    final hasActiveOrbs = totalOrbs > 0;
    final updatedSpoilsFire = spoilsFireOrbs + fireOrbs;
    final updatedSpoilsWater = spoilsWaterOrbs + waterOrbs;
    final updatedSpoilsWood = spoilsWoodOrbs + woodOrbs;
    final updatedSpoilsEarth = spoilsEarthOrbs + earthOrbs;
    final updatedSpoilsMetal = spoilsMetalOrbs + metalOrbs;

    // 2. Archive owned shop artifacts & power-ups into Relic Chamber (excluding paid IAPs)
    //    (Double-Reset Guard: only update if active run has owned artifacts)
    final lostUpgrades = _collectLostRelicIds(verifiedPaidIds);
    final nextRelicUpgrades = lostUpgrades.isNotEmpty
        ? _mergeRelicUpgradeIds(relicChamberStoredUpgrades, lostUpgrades)
        : List<String>.from(relicChamberStoredUpgrades);

    // 3. Preserve independent all-time historical peaks and unlock Hall of Heroes claim
    final nextPeakHp = math.max(peakHpUpgradeLevel, hpUpgradeLevel);
    final nextPeakMana = math.max(peakManaUpgradeLevel, manaUpgradeLevel);
    final nextClaimAvailable = nextPeakHp > 0 || nextPeakMana > 0;

    // 4. Wipe active campaign & arena state while preserving global account data
    await storage.clearGameplayProgress(
      includeSettings: false,
      includeCastleMeta: false,
      preserveStoryFlags: true,
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
    }
    await storage.setPeakHpUpgradeLevel(nextPeakHp);
    await storage.setPeakManaUpgradeLevel(nextPeakMana);
    await storage.setHallOfHeroesClaimAvailable(nextClaimAvailable);
    await storage.setTotalCyclesCount(nextTotalCycles);
    await storage.setForfeitRunCount(nextForfeitRuns);
    await storage.setPurchasedIapProductIds(verifiedPaidIds);
    await storage.setCurrentWeek(0);

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

  /// Infinitely upgrades the Cleric's Max HP by +1 using only Fire, Water, and
  /// Wood orbs (`2 + hpUpgradeLevel ~/ 2` each), updating current HP if out of combat
  /// and tracking the all-time historical peak.
  bool upgradeMaxHp() {
    return purchaseWithOrbs(
      cost: nextMaxHpUpgradeCost,
      onUnlock: _applyMaxHpLevelGain,
    );
  }

  /// Infinitely upgrades the Cleric's Max Mana Pool by +1 using only Fire, Water,
  /// and Wood orbs (`3 + manaUpgradeLevel ~/ 2` each) and tracks the all-time peak.
  bool upgradeMaxMana() {
    return purchaseWithOrbs(
      cost: nextMaxManaUpgradeCost,
      onUnlock: _applyMaxManaLevelGain,
    );
  }

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
    return purchaseWithOrbs(
      cost: costRemoveAds,
      onUnlock: () {
        unlockedAds = true;
        removeAdsEnabled = true;
        storage.setUnlockedAds(true);
        storage.setRemoveAdsEnabled(true);
        adService.setAdsRemoved(true);
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
        unlockedAds = true;
        removeAdsEnabled = true;
        storage.setUnlockedAds(true);
        storage.setRemoveAdsEnabled(true);
        adService.setAdsRemoved(true);
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
      lastWinner = currentUserMove!.resolvesAgainst(
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
