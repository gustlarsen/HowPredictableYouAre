import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:games_services/games_services.dart';
import '../models/move.dart';
import 'storage_service.dart';

/// Represents the current Google Play Saved Games cloud synchronization state.
enum CloudSyncStatus {
  synced,
  syncing,
  offline,
}

/// Result of a sign-in attempt with Google Play Games Services.
class PlayGamesAuthResult {
  final bool success;
  final String? playerName;
  final String? playerID;
  final String? errorCode;
  final String? errorMessage;
  final String? message;

  const PlayGamesAuthResult({
    required this.success,
    this.playerName,
    this.playerID,
    this.errorCode,
    this.errorMessage,
    this.message,
  });
}

/// Abstraction over static [GamesServices] calls so that [PlayGamesService]
/// can be deterministically unit-tested and safely falls back when native
/// Google Play Games Services are unavailable (e.g., offline or desktop).
abstract class PlayGamesClient {
  Future<String?> signIn();
  Future<String?> getPlayerName();
  Future<String?> getPlayerID();
  Future<String?> saveGame({required String data, required String name});
  Future<String?> loadGame({required String name});
}

/// Default production implementation of [PlayGamesClient] backed by
/// the `games_services` plugin.
///
/// Important: `games_services` caches `PlayerData` on Dart's broadcast
/// `GamesServices.player` stream only while there is an active listener on the
/// `games_services.player` EventChannel. Keeping a persistent listener warmed up
/// before `GamesServices.signIn()` ensures the player event emitted during
/// native sign-in is captured immediately and never lost.
class DefaultPlayGamesClient implements PlayGamesClient {
  static const Duration defaultSignInTimeout = Duration(seconds: 15);
  static const Duration defaultProfileTimeout = Duration(seconds: 8);
  static const Duration defaultCloudTimeout = Duration(seconds: 12);

  static StreamSubscription<PlayerData?>? _playerSubscription;
  static PlayerData? _cachedPlayer;

  const DefaultPlayGamesClient();

  static void _ensurePlayerStreamSubscribed() {
    if (_playerSubscription != null) return;
    try {
      _playerSubscription = GamesServices.player.listen(
        (player) {
          if (player != null) {
            _cachedPlayer = player;
          }
        },
        onError: (Object error) {
          debugPrint('[PlayGamesService] player stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('[PlayGamesService] failed to subscribe player stream: $e');
    }
  }

  static Future<PlayerData?> _waitForPlayerData(Duration timeout) async {
    _ensurePlayerStreamSubscribed();
    final cached = _cachedPlayer;
    if (cached != null &&
        StorageService.isValidPlayerId(cached.playerID)) {
      return cached;
    }
    try {
      final player = await GamesServices.player
          .firstWhere(
            (data) =>
                data != null &&
                StorageService.isValidPlayerId(data.playerID),
          )
          .timeout(timeout);
      if (player != null) {
        _cachedPlayer = player;
      }
      return player;
    } catch (_) {
      return _cachedPlayer;
    }
  }

  @override
  Future<String?> signIn() async {
    _ensurePlayerStreamSubscribed();
    return await GamesServices.signIn().timeout(defaultSignInTimeout);
  }

  @override
  Future<String?> getPlayerName() async {
    _ensurePlayerStreamSubscribed();
    final cachedName = _cachedPlayer?.displayName;
    if (cachedName != null && cachedName.trim().isNotEmpty) {
      return cachedName.trim();
    }
    try {
      final name = await GamesServices.getPlayerName().timeout(
        defaultProfileTimeout,
      );
      if (name != null && name.trim().isNotEmpty) {
        return name.trim();
      }
    } catch (e) {
      debugPrint('[PlayGamesService] getPlayerName fallback: $e');
    }
    final player = await _waitForPlayerData(const Duration(seconds: 3));
    return player?.displayName;
  }

  @override
  Future<String?> getPlayerID() async {
    _ensurePlayerStreamSubscribed();
    final cachedId = _cachedPlayer?.playerID;
    if (StorageService.isValidPlayerId(cachedId)) {
      return cachedId!.trim();
    }
    try {
      final id = await GamesServices.getPlayerID().timeout(
        defaultProfileTimeout,
      );
      if (StorageService.isValidPlayerId(id)) {
        return id!.trim();
      }
    } catch (e) {
      debugPrint('[PlayGamesService] getPlayerID fallback: $e');
    }
    final player = await _waitForPlayerData(const Duration(seconds: 3));
    return player?.playerID;
  }

  @override
  Future<String?> saveGame({required String data, required String name}) async {
    try {
      return await GamesServices.saveGame(data: data, name: name).timeout(
        defaultCloudTimeout,
      );
    } catch (e) {
      debugPrint('[PlayGamesService] saveGame error: $e');
      return null;
    }
  }

  @override
  Future<String?> loadGame({required String name}) =>
      GamesServices.loadGame(name: name).timeout(defaultCloudTimeout);
}

/// Serializable snapshot of the player's full progression state for
/// Google Play Saved Games cloud synchronization.
class CloudSaveData {
  final int fireOrbs;
  final int waterOrbs;
  final int woodOrbs;
  final int earthOrbs;
  final int metalOrbs;
  final int? turn0FireOrbs;
  final int? turn0WaterOrbs;
  final int? turn0WoodOrbs;
  final int? turn0EarthOrbs;
  final int? turn0MetalOrbs;
  final bool hasClaimedQaBonus;
  final int userScore;
  final int pcScore;
  final int total;
  final int userHp;
  final int pcHp;
  final int enemyStage;
  int get enemyPhase => enemyStage;
  final int enemyMaxHp;
  final int currentWeek;

  // Unlocks (Purchased in shop)
  final bool unlockedReset;
  final bool unlockedPredictability;
  final bool unlockedRandom;
  final bool unlockedAlgorithm;
  final bool unlockedNewHands;
  final bool unlockedYourPrediction;
  final bool unlockedNextMove;
  final bool unlockedSuggestion;
  final bool unlockedAds;
  final bool unlockedNewSkin;
  final bool unlockedCrystalBall;
  final bool unlockedCrystalBallPlus;
  final bool unlockedMarkovRecalibrator;
  final bool giftBoxUnlocked;
  final int overchargedStaffLevel;

  // Feature Active Toggles
  final bool showReset;
  final bool showPredictability;
  final bool showRandom;
  final bool showAlgorithm;
  final bool showNewHands;
  final bool showNewSkin;
  final bool showYourPrediction;
  final bool showNextMove;
  final bool showSuggestion;
  final bool removeAdsEnabled;
  final bool showCrystalBall;
  final bool showCrystalBallPlus;
  final bool crystalBallPlusSavedState;
  final bool showMarkovRecalibrator;
  final bool giftBoxEnabled;
  final bool overchargedStaffEnabled;
  final int overchargedStaffSelectedSpeed;

  // Story Cutscene Persistence Flags
  final bool hasSeenStoryIntro;
  final bool hasSeenStoryReset;
  final bool hasSeenStoryPredictability;
  final bool hasSeenStoryRandom;
  final bool hasSeenStoryAlgorithm;
  final bool hasSeenStoryYourPrediction;
  final bool hasSeenStoryPcNextMove;
  final bool hasSeenStorySuggestion;
  final bool hasSeenStoryCrystalBall;

  // Last Played Hands & Markov Transition Matrices
  final int? lastUserMoveId;
  final int? lastComputerMoveId;
  final List<List<int>>? markovMatrix3;
  final List<List<int>>? markovMatrix5;
  final Map<int, int>? shortTermTransitions;

  // Per-Account Settings
  final String language;
  final bool darkMode;
  final bool soundEnabled;
  final bool musicEnabled;
  final bool vibrationEnabled;
  final bool animationsEnabled;
  final bool confirmBattleTeleport;

  final List<String> purchasedIapProductIds;

  // Royal Castle Hub State
  final int treasuryFireOrbs;
  final int treasuryWaterOrbs;
  final int treasuryWoodOrbs;
  final int treasuryEarthOrbs;
  final int treasuryMetalOrbs;
  final int spoilsFireOrbs;
  final int spoilsWaterOrbs;
  final int spoilsWoodOrbs;
  final int spoilsEarthOrbs;
  final int spoilsMetalOrbs;
  final List<String> relicChamberUpgrades;
  final int hpUpgradeLevel;
  final int manaUpgradeLevel;
  final int peakHpUpgradeLevel;
  final int peakManaUpgradeLevel;
  final bool hallOfHeroesClaimAvailable;
  final List<String> unlockedEndings;
  final List<String> encounteredBestiary;
  final List<String>? activeDecreeIds;
  final List<String> completedCycleDecreeIds;
  final int totalDecreesCompleted;

  // Lifetime Account Chronicles & Run Statistics
  final int totalCyclesCount;
  final int deathDefeatCount;
  final int timeoutDefeatCount;
  final int forfeitRunCount;
  final int standardVictoryCount;
  final int secretVictoryCount;
  final int? fastestVictoryWeek;
  final int guardianRobotDefeatedCount;
  final int robotArchmageDefeatedCount;
  final int metalWizardDefeatedCount;
  final int babyMageRobotDefeatedCount;

  // Sacred Temple Consagration & Blessings State
  final int adConsagrationsThisWeek;
  final String? pendingBattleBlessing;
  final String? activeBattleBlessing;
  final int battleBonusTempHp;
  final String? lastFreeDailyPrayerDate;

  final int updatedAtMillis;

  const CloudSaveData({
    this.fireOrbs = 0,
    this.waterOrbs = 0,
    this.woodOrbs = 0,
    this.earthOrbs = 0,
    this.metalOrbs = 0,
    this.turn0FireOrbs,
    this.turn0WaterOrbs,
    this.turn0WoodOrbs,
    this.turn0EarthOrbs,
    this.turn0MetalOrbs,
    this.hasClaimedQaBonus = false,
    this.userScore = 0,
    this.pcScore = 0,
    this.total = 0,
    this.userHp = 50,
    this.pcHp = 100,
    int? enemyStage,
    int enemyPhase = 1,
    this.enemyMaxHp = 100,
    this.currentWeek = 1,
    this.unlockedReset = false,
    this.unlockedPredictability = false,
    this.unlockedRandom = false,
    this.unlockedAlgorithm = false,
    this.unlockedNewHands = false,
    this.unlockedYourPrediction = false,
    this.unlockedNextMove = false,
    this.unlockedSuggestion = false,
    this.unlockedAds = false,
    this.unlockedNewSkin = false,
    this.unlockedCrystalBall = false,
    this.unlockedCrystalBallPlus = false,
    this.unlockedMarkovRecalibrator = false,
    this.giftBoxUnlocked = false,
    this.overchargedStaffLevel = 0,
    this.showReset = false,
    this.showPredictability = false,
    this.showRandom = false,
    this.showAlgorithm = false,
    this.showNewHands = false,
    this.showNewSkin = false,
    this.showYourPrediction = false,
    this.showNextMove = false,
    this.showSuggestion = false,
    bool? removeAdsEnabled,
    this.showCrystalBall = false,
    this.showCrystalBallPlus = false,
    this.crystalBallPlusSavedState = false,
    this.showMarkovRecalibrator = false,
    this.giftBoxEnabled = false,
    this.overchargedStaffEnabled = false,
    this.overchargedStaffSelectedSpeed = 1,
    this.hasSeenStoryIntro = false,
    this.hasSeenStoryReset = false,
    this.hasSeenStoryPredictability = false,
    this.hasSeenStoryRandom = false,
    this.hasSeenStoryAlgorithm = false,
    this.hasSeenStoryYourPrediction = false,
    this.hasSeenStoryPcNextMove = false,
    this.hasSeenStorySuggestion = false,
    this.hasSeenStoryCrystalBall = false,
    this.lastUserMoveId,
    this.lastComputerMoveId,
    this.markovMatrix3,
    this.markovMatrix5,
    this.shortTermTransitions,
    this.language = 'en',
    this.darkMode = true,
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.vibrationEnabled = true,
    this.animationsEnabled = true,
    this.confirmBattleTeleport = true,
    this.purchasedIapProductIds = const [],
    this.treasuryFireOrbs = 0,
    this.treasuryWaterOrbs = 0,
    this.treasuryWoodOrbs = 0,
    this.treasuryEarthOrbs = 0,
    this.treasuryMetalOrbs = 0,
    this.spoilsFireOrbs = 0,
    this.spoilsWaterOrbs = 0,
    this.spoilsWoodOrbs = 0,
    this.spoilsEarthOrbs = 0,
    this.spoilsMetalOrbs = 0,
    this.relicChamberUpgrades = const [],
    this.hpUpgradeLevel = 0,
    this.manaUpgradeLevel = 0,
    this.peakHpUpgradeLevel = 0,
    this.peakManaUpgradeLevel = 0,
    this.hallOfHeroesClaimAvailable = false,
    this.unlockedEndings = const [],
    this.encounteredBestiary = const [],
    this.activeDecreeIds,
    this.completedCycleDecreeIds = const [],
    this.totalDecreesCompleted = 0,
    this.totalCyclesCount = 0,
    this.deathDefeatCount = 0,
    this.timeoutDefeatCount = 0,
    this.forfeitRunCount = 0,
    this.standardVictoryCount = 0,
    this.secretVictoryCount = 0,
    this.fastestVictoryWeek,
    this.guardianRobotDefeatedCount = 0,
    this.robotArchmageDefeatedCount = 0,
    this.metalWizardDefeatedCount = 0,
    this.babyMageRobotDefeatedCount = 0,
    this.adConsagrationsThisWeek = 0,
    this.pendingBattleBlessing,
    this.activeBattleBlessing,
    this.battleBonusTempHp = 0,
    this.lastFreeDailyPrayerDate,
    this.updatedAtMillis = 0,
  }) : enemyStage = enemyStage ?? enemyPhase,
       removeAdsEnabled = removeAdsEnabled ?? unlockedAds;

  /// Total sum of all 5 Elemental Orbs in this snapshot.
  int get totalOrbs =>
      fireOrbs + waterOrbs + woodOrbs + earthOrbs + metalOrbs;

  int get totalTreasuryOrbs =>
      treasuryFireOrbs +
      treasuryWaterOrbs +
      treasuryWoodOrbs +
      treasuryEarthOrbs +
      treasuryMetalOrbs;

  int get totalSpoilsOrbs =>
      spoilsFireOrbs +
      spoilsWaterOrbs +
      spoilsWoodOrbs +
      spoilsEarthOrbs +
      spoilsMetalOrbs;

  /// Number of shop items unlocked in this save snapshot.
  int get unlockedCount {
    int count = 0;
    if (unlockedReset) count++;
    if (unlockedPredictability) count++;
    if (unlockedRandom) count++;
    if (unlockedAlgorithm) count++;
    if (unlockedNewHands) count++;
    if (unlockedYourPrediction) count++;
    if (unlockedNextMove) count++;
    if (unlockedSuggestion) count++;
    if (unlockedAds) count++;
    if (unlockedNewSkin) count++;
    if (unlockedCrystalBall) count++;
    if (unlockedCrystalBallPlus) count++;
    if (unlockedMarkovRecalibrator) count++;
    if (giftBoxUnlocked) count++;
    if (overchargedStaffLevel >= 1) count++;
    return count;
  }

  /// Total Elemental Orb value of all infinite stat upgrades in this snapshot.
  int get statUpgradeOrbValue {
    int sum = 0;
    for (int i = 0; i < hpUpgradeLevel; i++) {
      sum += 3 * (2 + (i ~/ 2));
    }
    for (int i = 0; i < manaUpgradeLevel; i++) {
      sum += 3 * (3 + (i ~/ 2));
    }
    return sum;
  }

  /// Total Elemental Orb value of all unlocked shop items and stat upgrades in this snapshot.
  int get unlockedShopValue {
    int value = statUpgradeOrbValue;
    if (unlockedPredictability) value += 45;
    if (unlockedReset) value += 90;
    if (unlockedNewHands) value += 100;
    if (unlockedRandom) value += 240;
    if (overchargedStaffLevel >= 1) value += 300;
    if (overchargedStaffLevel >= 2) value += 750;
    if (overchargedStaffLevel >= 3) value += 1900;
    if (overchargedStaffLevel >= 4) value += 4000;
    if (unlockedAlgorithm) value += 460;
    if (unlockedYourPrediction) value += 950;
    if (unlockedNextMove) value += 2400;
    if (giftBoxUnlocked) value += 2500;
    if (unlockedSuggestion) value += 4000;
    if (unlockedMarkovRecalibrator) value += 6000;
    if (unlockedNewSkin) value += 6500;
    if (unlockedAds) value += 9000;
    if (unlockedCrystalBall) value += 15500;
    if (unlockedCrystalBallPlus) value += 25000;
    return value;
  }

  /// Total sum of transitions recorded across both Markov matrices.
  int get markovTransitionsCount {
    int sum = 0;
    if (markovMatrix3 != null) {
      for (final row in markovMatrix3!) {
        for (final cell in row) {
          sum += cell;
        }
      }
    }
    if (markovMatrix5 != null) {
      for (final row in markovMatrix5!) {
        for (final cell in row) {
          sum += cell;
        }
      }
    }
    return sum;
  }

  /// Returns true if [this] cloud save holds a higher progression state or
  /// elemental orb count than [local].
  bool hasHigherProgressionOrOrbsThan(CloudSaveData local) {
    if (totalOrbs > local.totalOrbs) return true;
    if (unlockedCount > local.unlockedCount) return true;
    if (unlockedShopValue > local.unlockedShopValue) return true;
    if (unlockedCount == local.unlockedCount &&
        totalOrbs == local.totalOrbs &&
        (currentWeek > local.currentWeek ||
            enemyPhase > local.enemyPhase ||
            total > local.total ||
            userScore > local.userScore ||
            overchargedStaffLevel > local.overchargedStaffLevel ||
            markovTransitionsCount > local.markovTransitionsCount ||
            totalTreasuryOrbs > local.totalTreasuryOrbs ||
            totalSpoilsOrbs > local.totalSpoilsOrbs ||
            relicChamberUpgrades.length > local.relicChamberUpgrades.length ||
            hpUpgradeLevel > local.hpUpgradeLevel ||
            manaUpgradeLevel > local.manaUpgradeLevel ||
            peakHpUpgradeLevel > local.peakHpUpgradeLevel ||
            peakManaUpgradeLevel > local.peakManaUpgradeLevel ||
            (hallOfHeroesClaimAvailable && !local.hallOfHeroesClaimAvailable) ||
            unlockedEndings.length > local.unlockedEndings.length ||
            encounteredBestiary.length > local.encounteredBestiary.length ||
            totalDecreesCompleted > local.totalDecreesCompleted ||
            totalCyclesCount > local.totalCyclesCount ||
            deathDefeatCount > local.deathDefeatCount ||
            timeoutDefeatCount > local.timeoutDefeatCount ||
            forfeitRunCount > local.forfeitRunCount ||
            standardVictoryCount > local.standardVictoryCount ||
            secretVictoryCount > local.secretVictoryCount ||
            guardianRobotDefeatedCount > local.guardianRobotDefeatedCount ||
            robotArchmageDefeatedCount > local.robotArchmageDefeatedCount ||
            metalWizardDefeatedCount > local.metalWizardDefeatedCount ||
            babyMageRobotDefeatedCount > local.babyMageRobotDefeatedCount ||
            (fastestVictoryWeek != null &&
                fastestVictoryWeek! > 0 &&
                (local.fastestVictoryWeek == null ||
                    local.fastestVictoryWeek! <= 0 ||
                    fastestVictoryWeek! < local.fastestVictoryWeek!)))) {
      return true;
    }
    return false;
  }

  static int _maxInt(int a, int b) => a > b ? a : b;

  static int? _minNonZeroWeek(int? a, int? b) {
    final validA = (a != null && a > 0) ? a : null;
    final validB = (b != null && b > 0) ? b : null;
    if (validA == null) return validB;
    if (validB == null) return validA;
    return validA < validB ? validA : validB;
  }

  /// Merges [this] cloud save over [local] when cloud has higher progression or orbs,
  /// preserving any locally unlocked items or seen story chapters.
  CloudSaveData mergeOverLocal(CloudSaveData local) {
    return CloudSaveData(
      fireOrbs: fireOrbs,
      waterOrbs: waterOrbs,
      woodOrbs: woodOrbs,
      earthOrbs: earthOrbs,
      metalOrbs: metalOrbs,
      turn0FireOrbs: turn0FireOrbs ?? fireOrbs,
      turn0WaterOrbs: turn0WaterOrbs ?? waterOrbs,
      turn0WoodOrbs: turn0WoodOrbs ?? woodOrbs,
      turn0EarthOrbs: turn0EarthOrbs ?? earthOrbs,
      turn0MetalOrbs: turn0MetalOrbs ?? metalOrbs,
      hasClaimedQaBonus: hasClaimedQaBonus || local.hasClaimedQaBonus,
      userScore: userScore,
      pcScore: pcScore,
      total: total,
      userHp: userHp,
      pcHp: pcHp,
      enemyPhase: enemyPhase,
      enemyMaxHp: enemyMaxHp,
      currentWeek:
          currentWeek > local.currentWeek ? currentWeek : local.currentWeek,
      unlockedReset: unlockedReset || local.unlockedReset,
      unlockedPredictability:
          unlockedPredictability || local.unlockedPredictability,
      unlockedRandom: unlockedRandom || local.unlockedRandom,
      unlockedAlgorithm: unlockedAlgorithm || local.unlockedAlgorithm,
      unlockedNewHands: unlockedNewHands || local.unlockedNewHands,
      unlockedYourPrediction:
          unlockedYourPrediction || local.unlockedYourPrediction,
      unlockedNextMove: unlockedNextMove || local.unlockedNextMove,
      unlockedSuggestion: unlockedSuggestion || local.unlockedSuggestion,
      unlockedAds: unlockedAds || local.unlockedAds,
      unlockedNewSkin: unlockedNewSkin || local.unlockedNewSkin,
      unlockedCrystalBall: unlockedCrystalBall || local.unlockedCrystalBall,
      unlockedCrystalBallPlus:
          unlockedCrystalBallPlus || local.unlockedCrystalBallPlus,
      unlockedMarkovRecalibrator:
          unlockedMarkovRecalibrator || local.unlockedMarkovRecalibrator,
      giftBoxUnlocked: giftBoxUnlocked || local.giftBoxUnlocked,
      overchargedStaffLevel:
          _maxInt(overchargedStaffLevel, local.overchargedStaffLevel),
      showReset: showReset,
      showPredictability: showPredictability,
      showRandom: showRandom,
      showAlgorithm: showAlgorithm,
      showNewHands: showNewHands,
      showNewSkin: showNewSkin,
      showYourPrediction: showYourPrediction,
      showNextMove: showNextMove,
      showSuggestion: showSuggestion,
      removeAdsEnabled: removeAdsEnabled,
      showCrystalBall: showCrystalBall,
      showCrystalBallPlus: showCrystalBallPlus,
      crystalBallPlusSavedState: crystalBallPlusSavedState,
      showMarkovRecalibrator: showMarkovRecalibrator,
      giftBoxEnabled: giftBoxEnabled,
      overchargedStaffEnabled: overchargedStaffEnabled,
      overchargedStaffSelectedSpeed: overchargedStaffSelectedSpeed,
      hasSeenStoryIntro: hasSeenStoryIntro || local.hasSeenStoryIntro,
      hasSeenStoryReset: hasSeenStoryReset || local.hasSeenStoryReset,
      hasSeenStoryPredictability:
          hasSeenStoryPredictability || local.hasSeenStoryPredictability,
      hasSeenStoryRandom: hasSeenStoryRandom || local.hasSeenStoryRandom,
      hasSeenStoryAlgorithm:
          hasSeenStoryAlgorithm || local.hasSeenStoryAlgorithm,
      hasSeenStoryYourPrediction:
          hasSeenStoryYourPrediction || local.hasSeenStoryYourPrediction,
      hasSeenStoryPcNextMove:
          hasSeenStoryPcNextMove || local.hasSeenStoryPcNextMove,
      hasSeenStorySuggestion:
          hasSeenStorySuggestion || local.hasSeenStorySuggestion,
      hasSeenStoryCrystalBall:
          hasSeenStoryCrystalBall || local.hasSeenStoryCrystalBall,
      lastUserMoveId: lastUserMoveId ?? local.lastUserMoveId,
      lastComputerMoveId: lastComputerMoveId ?? local.lastComputerMoveId,
      markovMatrix3: markovMatrix3 ?? local.markovMatrix3,
      markovMatrix5: markovMatrix5 ?? local.markovMatrix5,
      shortTermTransitions: shortTermTransitions ?? local.shortTermTransitions,
      language: language,
      darkMode: darkMode,
      soundEnabled: soundEnabled,
      musicEnabled: musicEnabled,
      vibrationEnabled: vibrationEnabled,
      animationsEnabled: animationsEnabled,
      confirmBattleTeleport: confirmBattleTeleport,
      purchasedIapProductIds: (
        {...purchasedIapProductIds, ...local.purchasedIapProductIds}.toList()
          ..sort()
      ),
      treasuryFireOrbs: treasuryFireOrbs,
      treasuryWaterOrbs: treasuryWaterOrbs,
      treasuryWoodOrbs: treasuryWoodOrbs,
      treasuryEarthOrbs: treasuryEarthOrbs,
      treasuryMetalOrbs: treasuryMetalOrbs,
      spoilsFireOrbs: spoilsFireOrbs,
      spoilsWaterOrbs: spoilsWaterOrbs,
      spoilsWoodOrbs: spoilsWoodOrbs,
      spoilsEarthOrbs: spoilsEarthOrbs,
      spoilsMetalOrbs: spoilsMetalOrbs,
      relicChamberUpgrades: relicChamberUpgrades,
      hpUpgradeLevel: hpUpgradeLevel,
      manaUpgradeLevel: manaUpgradeLevel,
      peakHpUpgradeLevel: _maxInt(peakHpUpgradeLevel, local.peakHpUpgradeLevel),
      peakManaUpgradeLevel:
          _maxInt(peakManaUpgradeLevel, local.peakManaUpgradeLevel),
      hallOfHeroesClaimAvailable: hallOfHeroesClaimAvailable,
      unlockedEndings: (
        {...unlockedEndings, ...local.unlockedEndings}.toList()..sort()
      ),
      encounteredBestiary: (
        {...encounteredBestiary, ...local.encounteredBestiary}.toList()..sort()
      ),
      activeDecreeIds: activeDecreeIds ?? local.activeDecreeIds,
      completedCycleDecreeIds: completedCycleDecreeIds,
      totalDecreesCompleted:
          _maxInt(totalDecreesCompleted, local.totalDecreesCompleted),
      totalCyclesCount: _maxInt(totalCyclesCount, local.totalCyclesCount),
      deathDefeatCount: _maxInt(deathDefeatCount, local.deathDefeatCount),
      timeoutDefeatCount: _maxInt(timeoutDefeatCount, local.timeoutDefeatCount),
      forfeitRunCount: _maxInt(forfeitRunCount, local.forfeitRunCount),
      standardVictoryCount:
          _maxInt(standardVictoryCount, local.standardVictoryCount),
      secretVictoryCount: _maxInt(secretVictoryCount, local.secretVictoryCount),
      fastestVictoryWeek:
          _minNonZeroWeek(fastestVictoryWeek, local.fastestVictoryWeek),
      guardianRobotDefeatedCount:
          _maxInt(guardianRobotDefeatedCount, local.guardianRobotDefeatedCount),
      robotArchmageDefeatedCount:
          _maxInt(robotArchmageDefeatedCount, local.robotArchmageDefeatedCount),
      metalWizardDefeatedCount:
          _maxInt(metalWizardDefeatedCount, local.metalWizardDefeatedCount),
      babyMageRobotDefeatedCount:
          _maxInt(babyMageRobotDefeatedCount, local.babyMageRobotDefeatedCount),
      adConsagrationsThisWeek: adConsagrationsThisWeek,
      pendingBattleBlessing: pendingBattleBlessing ?? local.pendingBattleBlessing,
      activeBattleBlessing: activeBattleBlessing,
      battleBonusTempHp: battleBonusTempHp,
      lastFreeDailyPrayerDate:
          lastFreeDailyPrayerDate ?? local.lastFreeDailyPrayerDate,
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory CloudSaveData.fromStorage(StorageService storage) {
    return CloudSaveData(
      fireOrbs: storage.fireOrbs,
      waterOrbs: storage.waterOrbs,
      woodOrbs: storage.woodOrbs,
      earthOrbs: storage.earthOrbs,
      metalOrbs: storage.metalOrbs,
      turn0FireOrbs:
          storage.hasTurn0OrbSnapshot ? storage.turn0FireOrbs : storage.fireOrbs,
      turn0WaterOrbs:
          storage.hasTurn0OrbSnapshot ? storage.turn0WaterOrbs : storage.waterOrbs,
      turn0WoodOrbs:
          storage.hasTurn0OrbSnapshot ? storage.turn0WoodOrbs : storage.woodOrbs,
      turn0EarthOrbs:
          storage.hasTurn0OrbSnapshot ? storage.turn0EarthOrbs : storage.earthOrbs,
      turn0MetalOrbs:
          storage.hasTurn0OrbSnapshot ? storage.turn0MetalOrbs : storage.metalOrbs,
      hasClaimedQaBonus: storage.hasClaimedQaBonus,
      userScore: storage.userScore,
      pcScore: storage.pcScore,
      total: storage.total,
      userHp: storage.userHp,
      pcHp: storage.pcHp,
      enemyStage: storage.enemyStage,
      enemyMaxHp: storage.enemyMaxHp,
      currentWeek: storage.currentWeek,
      unlockedReset: storage.unlockedReset,
      unlockedPredictability: storage.unlockedPredictability,
      unlockedRandom: storage.unlockedRandom,
      unlockedAlgorithm: storage.unlockedAlgorithm,
      unlockedNewHands: storage.unlockedNewHands,
      unlockedYourPrediction: storage.unlockedYourPrediction,
      unlockedNextMove: storage.unlockedNextMove,
      unlockedSuggestion: storage.unlockedSuggestion,
      unlockedAds: storage.unlockedAds,
      unlockedNewSkin: storage.unlockedNewSkin,
      unlockedCrystalBall: storage.unlockedCrystalBall,
      unlockedCrystalBallPlus: storage.unlockedCrystalBallPlus,
      unlockedMarkovRecalibrator: storage.unlockedMarkovRecalibrator,
      giftBoxUnlocked: storage.giftBoxUnlocked,
      overchargedStaffLevel: storage.overchargedStaffLevel,
      showReset: storage.showReset,
      showPredictability: storage.showPredictability,
      showRandom: storage.showRandom,
      showAlgorithm: storage.showAlgorithm,
      showNewHands: storage.showNewHands,
      showNewSkin: storage.showNewSkin,
      showYourPrediction: storage.showYourPrediction,
      showNextMove: storage.showNextMove,
      showSuggestion: storage.showSuggestion,
      removeAdsEnabled: storage.removeAdsEnabled,
      showCrystalBall: storage.showCrystalBall,
      showCrystalBallPlus: storage.showCrystalBallPlus,
      crystalBallPlusSavedState: storage.crystalBallPlusSavedState,
      showMarkovRecalibrator: storage.showMarkovRecalibrator,
      giftBoxEnabled: storage.giftBoxEnabled,
      overchargedStaffEnabled: storage.overchargedStaffEnabled,
      overchargedStaffSelectedSpeed: storage.overchargedStaffSelectedSpeed,
      hasSeenStoryIntro: storage.hasSeenStoryIntro,
      hasSeenStoryReset: storage.hasSeenStoryReset,
      hasSeenStoryPredictability: storage.hasSeenStoryPredictability,
      hasSeenStoryRandom: storage.hasSeenStoryRandom,
      hasSeenStoryAlgorithm: storage.hasSeenStoryAlgorithm,
      hasSeenStoryYourPrediction: storage.hasSeenStoryYourPrediction,
      hasSeenStoryPcNextMove: storage.hasSeenStoryPcNextMove,
      hasSeenStorySuggestion: storage.hasSeenStorySuggestion,
      hasSeenStoryCrystalBall: storage.hasSeenStoryCrystalBall,
      lastUserMoveId: storage.lastUserMove?.id,
      lastComputerMoveId: storage.lastComputerMove?.id,
      markovMatrix3: storage.getMarkovMatrix(3),
      markovMatrix5: storage.getMarkovMatrix(5),
      shortTermTransitions: storage.shortTermTransitions,
      language: storage.language,
      darkMode: storage.darkMode,
      soundEnabled: storage.soundEnabled,
      musicEnabled: storage.musicEnabled,
      vibrationEnabled: storage.vibrationEnabled,
      animationsEnabled: storage.animationsEnabled,
      confirmBattleTeleport: storage.confirmBattleTeleport,
      purchasedIapProductIds: storage.purchasedIapProductIds.toList()..sort(),
      treasuryFireOrbs: storage.treasuryFireOrbs,
      treasuryWaterOrbs: storage.treasuryWaterOrbs,
      treasuryWoodOrbs: storage.treasuryWoodOrbs,
      treasuryEarthOrbs: storage.treasuryEarthOrbs,
      treasuryMetalOrbs: storage.treasuryMetalOrbs,
      spoilsFireOrbs: storage.spoilsFireOrbs,
      spoilsWaterOrbs: storage.spoilsWaterOrbs,
      spoilsWoodOrbs: storage.spoilsWoodOrbs,
      spoilsEarthOrbs: storage.spoilsEarthOrbs,
      spoilsMetalOrbs: storage.spoilsMetalOrbs,
      relicChamberUpgrades: storage.relicChamberUpgrades,
      hpUpgradeLevel: storage.hpUpgradeLevel,
      manaUpgradeLevel: storage.manaUpgradeLevel,
      peakHpUpgradeLevel: storage.peakHpUpgradeLevel,
      peakManaUpgradeLevel: storage.peakManaUpgradeLevel,
      hallOfHeroesClaimAvailable: storage.hallOfHeroesClaimAvailable,
      unlockedEndings: storage.unlockedEndings,
      encounteredBestiary: storage.encounteredBestiary,
      activeDecreeIds: storage.activeDecreeIds,
      completedCycleDecreeIds: storage.completedCycleDecreeIds,
      totalDecreesCompleted: storage.totalDecreesCompleted,
      totalCyclesCount: storage.totalCyclesCount,
      deathDefeatCount: storage.deathDefeatCount,
      timeoutDefeatCount: storage.timeoutDefeatCount,
      forfeitRunCount: storage.forfeitRunCount,
      standardVictoryCount: storage.standardVictoryCount,
      secretVictoryCount: storage.secretVictoryCount,
      fastestVictoryWeek: storage.fastestVictoryWeek,
      guardianRobotDefeatedCount: storage.guardianRobotDefeatedCount,
      robotArchmageDefeatedCount: storage.robotArchmageDefeatedCount,
      metalWizardDefeatedCount: storage.metalWizardDefeatedCount,
      babyMageRobotDefeatedCount: storage.babyMageRobotDefeatedCount,
      adConsagrationsThisWeek: storage.adConsagrationsThisWeek,
      pendingBattleBlessing: storage.pendingBattleBlessing,
      activeBattleBlessing: storage.activeBattleBlessing,
      battleBonusTempHp: storage.battleBonusTempHp,
      lastFreeDailyPrayerDate: storage.lastFreeDailyPrayerDate,
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> applyToStorage(StorageService storage) async {
    await storage.setAllOrbs(
      fire: fireOrbs,
      water: waterOrbs,
      wood: woodOrbs,
      earth: earthOrbs,
      metal: metalOrbs,
    );
    await storage.setTurn0Orbs(
      fire: turn0FireOrbs ?? fireOrbs,
      water: turn0WaterOrbs ?? waterOrbs,
      wood: turn0WoodOrbs ?? woodOrbs,
      earth: turn0EarthOrbs ?? earthOrbs,
      metal: turn0MetalOrbs ?? metalOrbs,
    );
    await storage.clearLegacyDiamonds();
    await storage.setHasClaimedQaBonus(hasClaimedQaBonus);
    await storage.setUserScore(userScore);
    await storage.setPcScore(pcScore);
    await storage.setTotal(total);
    await storage.setUserHp(userHp);
    await storage.setPcHp(pcHp);
    await storage.setEnemyStage(enemyStage);
    await storage.setEnemyMaxHp(enemyMaxHp);
    await storage.setCurrentWeek(currentWeek);
    await storage.setAdConsagrationsThisWeek(adConsagrationsThisWeek);
    await storage.setPendingBattleBlessing(pendingBattleBlessing);
    await storage.setActiveBattleBlessing(activeBattleBlessing);
    await storage.setBattleBonusTempHp(battleBonusTempHp);
    await storage.setLastFreeDailyPrayerDate(lastFreeDailyPrayerDate);
    if (purchasedIapProductIds.isNotEmpty) {
      await storage.setPurchasedIapProductIds({
        ...storage.purchasedIapProductIds,
        ...purchasedIapProductIds,
      });
    }

    await storage.setAllTreasuryOrbs(
      fire: treasuryFireOrbs,
      water: treasuryWaterOrbs,
      wood: treasuryWoodOrbs,
      earth: treasuryEarthOrbs,
      metal: treasuryMetalOrbs,
    );
    await storage.setAllSpoilsOrbs(
      fire: spoilsFireOrbs,
      water: spoilsWaterOrbs,
      wood: spoilsWoodOrbs,
      earth: spoilsEarthOrbs,
      metal: spoilsMetalOrbs,
    );
    await storage.setRelicChamberUpgrades(relicChamberUpgrades);
    await storage.setHpUpgradeLevel(hpUpgradeLevel);
    await storage.setManaUpgradeLevel(manaUpgradeLevel);
    await storage.setPeakHpUpgradeLevel(peakHpUpgradeLevel);
    await storage.setPeakManaUpgradeLevel(peakManaUpgradeLevel);
    await storage.setHallOfHeroesClaimAvailable(hallOfHeroesClaimAvailable);
    await storage.setUnlockedEndings(unlockedEndings);
    await storage.setEncounteredBestiary(encounteredBestiary);
    if (activeDecreeIds != null && activeDecreeIds!.isNotEmpty) {
      await storage.setActiveDecreeIds(activeDecreeIds!);
    }
    await storage.setCompletedCycleDecreeIds(completedCycleDecreeIds);
    await storage.setTotalDecreesCompleted(totalDecreesCompleted);
    await storage.setTotalCyclesCount(totalCyclesCount);
    await storage.setDeathDefeatCount(deathDefeatCount);
    await storage.setTimeoutDefeatCount(timeoutDefeatCount);
    await storage.setForfeitRunCount(forfeitRunCount);
    await storage.setStandardVictoryCount(standardVictoryCount);
    await storage.setSecretVictoryCount(secretVictoryCount);
    await storage.setFastestVictoryWeek(fastestVictoryWeek);
    await storage.setGuardianRobotDefeatedCount(guardianRobotDefeatedCount);
    await storage.setRobotArchmageDefeatedCount(robotArchmageDefeatedCount);
    await storage.setMetalWizardDefeatedCount(metalWizardDefeatedCount);
    await storage.setBabyMageRobotDefeatedCount(babyMageRobotDefeatedCount);

    await storage.setLanguage(language);
    await storage.setDarkMode(darkMode);
    await storage.setSoundEnabled(soundEnabled);
    await storage.setMusicEnabled(musicEnabled);
    await storage.setVibrationEnabled(vibrationEnabled);
    await storage.setAnimationsEnabled(animationsEnabled);
    await storage.setConfirmBattleTeleport(confirmBattleTeleport);

    await storage.setUnlockedReset(unlockedReset);
    await storage.setUnlockedPredictability(unlockedPredictability);
    await storage.setUnlockedRandom(unlockedRandom);
    await storage.setUnlockedAlgorithm(unlockedAlgorithm);
    await storage.setUnlockedNewHands(unlockedNewHands);
    await storage.setUnlockedYourPrediction(unlockedYourPrediction);
    await storage.setUnlockedNextMove(unlockedNextMove);
    await storage.setUnlockedSuggestion(unlockedSuggestion);
    await storage.setUnlockedAds(unlockedAds);
    await storage.setUnlockedNewSkin(unlockedNewSkin);
    await storage.setUnlockedCrystalBall(unlockedCrystalBall);
    await storage.setUnlockedCrystalBallPlus(unlockedCrystalBallPlus);
    await storage.setUnlockedMarkovRecalibrator(unlockedMarkovRecalibrator);
    await storage.setGiftBoxUnlocked(giftBoxUnlocked);
    await storage.setOverchargedStaffLevel(overchargedStaffLevel);

    await storage.setShowReset(showReset);
    await storage.setShowPredictability(showPredictability);
    await storage.setShowRandom(showRandom);
    await storage.setShowAlgorithm(showAlgorithm);
    await storage.setShowNewHands(showNewHands);
    await storage.setShowNewSkin(showNewSkin);
    await storage.setShowYourPrediction(showYourPrediction);
    await storage.setShowNextMove(showNextMove);
    await storage.setShowSuggestion(showSuggestion);
    await storage.setRemoveAdsEnabled(removeAdsEnabled);
    await storage.setShowCrystalBall(showCrystalBall);
    await storage.setShowCrystalBallPlus(showCrystalBallPlus);
    await storage.setCrystalBallPlusSavedState(crystalBallPlusSavedState);
    await storage.setShowMarkovRecalibrator(
        unlockedMarkovRecalibrator ? showMarkovRecalibrator : false);
    await storage.setGiftBoxEnabled(giftBoxUnlocked ? giftBoxEnabled : false);
    await storage.setOverchargedStaffEnabled(
        overchargedStaffLevel >= 1 ? overchargedStaffEnabled : false);
    await storage.setOverchargedStaffSelectedSpeed(
        overchargedStaffLevel >= 1 ? overchargedStaffSelectedSpeed : 1);

    await storage.setHasSeenStoryIntro(hasSeenStoryIntro);
    await storage.setHasSeenStoryReset(hasSeenStoryReset);
    await storage.setHasSeenStoryPredictability(hasSeenStoryPredictability);
    await storage.setHasSeenStoryRandom(hasSeenStoryRandom);
    await storage.setHasSeenStoryAlgorithm(hasSeenStoryAlgorithm);
    await storage.setHasSeenStoryYourPrediction(hasSeenStoryYourPrediction);
    await storage.setHasSeenStoryPcNextMove(hasSeenStoryPcNextMove);
    await storage.setHasSeenStorySuggestion(hasSeenStorySuggestion);
    await storage.setHasSeenStoryCrystalBall(hasSeenStoryCrystalBall);

    HandMove? findMove(int? id) {
      if (id == null) return null;
      for (final m in HandMove.values) {
        if (m.id == id) return m;
      }
      return null;
    }

    await storage.setLastUserMove(findMove(lastUserMoveId));
    await storage.setLastComputerMove(findMove(lastComputerMoveId));

    if (markovMatrix3 != null && markovMatrix3!.length == 3) {
      await storage.setMarkovMatrix(markovMatrix3!);
    } else {
      await storage.removeMarkovMatrix(3);
    }
    if (markovMatrix5 != null && markovMatrix5!.length == 5) {
      await storage.setMarkovMatrix(markovMatrix5!);
    } else {
      await storage.removeMarkovMatrix(5);
    }
    if (shortTermTransitions != null && shortTermTransitions!.isNotEmpty) {
      await storage.setShortTermTransitions(shortTermTransitions!);
    } else {
      await storage.removeShortTermTransitions();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 2,
      'orbs': {
        'fire': fireOrbs,
        'water': waterOrbs,
        'wood': woodOrbs,
        'earth': earthOrbs,
        'metal': metalOrbs,
      },
      'fireOrbs': fireOrbs,
      'waterOrbs': waterOrbs,
      'woodOrbs': woodOrbs,
      'earthOrbs': earthOrbs,
      'metalOrbs': metalOrbs,
      if (turn0FireOrbs != null ||
          turn0WaterOrbs != null ||
          turn0WoodOrbs != null ||
          turn0EarthOrbs != null ||
          turn0MetalOrbs != null)
        'turn0Orbs': {
          'fire': turn0FireOrbs ?? fireOrbs,
          'water': turn0WaterOrbs ?? waterOrbs,
          'wood': turn0WoodOrbs ?? woodOrbs,
          'earth': turn0EarthOrbs ?? earthOrbs,
          'metal': turn0MetalOrbs ?? metalOrbs,
        },
      'treasuryOrbs': {
        'fire': treasuryFireOrbs,
        'water': treasuryWaterOrbs,
        'wood': treasuryWoodOrbs,
        'earth': treasuryEarthOrbs,
        'metal': treasuryMetalOrbs,
      },
      'spoilsOfWarOrbs': {
        'fire': spoilsFireOrbs,
        'water': spoilsWaterOrbs,
        'wood': spoilsWoodOrbs,
        'earth': spoilsEarthOrbs,
        'metal': spoilsMetalOrbs,
      },
      'relicChamberUpgrades': relicChamberUpgrades,
      'hpUpgradeLevel': hpUpgradeLevel,
      'manaUpgradeLevel': manaUpgradeLevel,
      'peakHpUpgradeLevel': peakHpUpgradeLevel,
      'peakManaUpgradeLevel': peakManaUpgradeLevel,
      'hallOfHeroesClaimAvailable': hallOfHeroesClaimAvailable,
      'unlockedEndings': unlockedEndings,
      'encounteredBestiary': encounteredBestiary,
      if (activeDecreeIds != null) 'activeDecreeIds': activeDecreeIds,
      'completedCycleDecreeIds': completedCycleDecreeIds,
      'totalDecreesCompleted': totalDecreesCompleted,
      'totalCyclesCount': totalCyclesCount,
      'deathDefeatCount': deathDefeatCount,
      'timeoutDefeatCount': timeoutDefeatCount,
      'forfeitRunCount': forfeitRunCount,
      'standardVictoryCount': standardVictoryCount,
      'secretVictoryCount': secretVictoryCount,
      if (fastestVictoryWeek != null && fastestVictoryWeek! > 0)
        'fastestVictoryWeek': fastestVictoryWeek,
      'guardianRobotDefeatedCount': guardianRobotDefeatedCount,
      'robotArchmageDefeatedCount': robotArchmageDefeatedCount,
      'metalWizardDefeatedCount': metalWizardDefeatedCount,
      'babyMageRobotDefeatedCount': babyMageRobotDefeatedCount,
      'adConsagrationsThisWeek': adConsagrationsThisWeek,
      if (pendingBattleBlessing != null)
        'pendingBattleBlessing': pendingBattleBlessing,
      if (activeBattleBlessing != null)
        'activeBattleBlessing': activeBattleBlessing,
      'battleBonusTempHp': battleBonusTempHp,
      if (lastFreeDailyPrayerDate != null)
        'lastFreeDailyPrayerDate': lastFreeDailyPrayerDate,
      'hasClaimedQaBonus': hasClaimedQaBonus,
      'userScore': userScore,
      'pcScore': pcScore,
      'total': total,
      'userHp': userHp,
      'pcHp': pcHp,
      'enemyStage': enemyStage,
      'enemyPhase': enemyStage,
      'enemyMaxHp': enemyMaxHp,
      'currentWeek': currentWeek,
      'unlockedReset': unlockedReset,
      'unlockedPredictability': unlockedPredictability,
      'unlockedRandom': unlockedRandom,
      'unlockedAlgorithm': unlockedAlgorithm,
      'unlockedNewHands': unlockedNewHands,
      'unlockedYourPrediction': unlockedYourPrediction,
      'unlockedNextMove': unlockedNextMove,
      'unlockedSuggestion': unlockedSuggestion,
      'unlockedAds': unlockedAds,
      'unlockedNewSkin': unlockedNewSkin,
      'unlockedCrystalBall': unlockedCrystalBall,
      'unlockedCrystalBallPlus': unlockedCrystalBallPlus,
      'unlockedMarkovRecalibrator': unlockedMarkovRecalibrator,
      'giftBoxUnlocked': giftBoxUnlocked,
      'overchargedStaffLevel': overchargedStaffLevel,
      'showReset': showReset,
      'showPredictability': showPredictability,
      'showRandom': showRandom,
      'showAlgorithm': showAlgorithm,
      'showNewHands': showNewHands,
      'showNewSkin': showNewSkin,
      'showYourPrediction': showYourPrediction,
      'showNextMove': showNextMove,
      'showSuggestion': showSuggestion,
      'removeAdsEnabled': removeAdsEnabled,
      'showCrystalBall': showCrystalBall,
      'showCrystalBallPlus': showCrystalBallPlus,
      'crystalBallPlusSavedState': crystalBallPlusSavedState,
      'showMarkovRecalibrator': showMarkovRecalibrator,
      'giftBoxEnabled': giftBoxEnabled,
      'overchargedStaffEnabled': overchargedStaffEnabled,
      'overchargedStaffSelectedSpeed': overchargedStaffSelectedSpeed,
      'hasSeenStoryIntro': hasSeenStoryIntro,
      'hasSeenStoryReset': hasSeenStoryReset,
      'hasSeenStoryPredictability': hasSeenStoryPredictability,
      'hasSeenStoryRandom': hasSeenStoryRandom,
      'hasSeenStoryAlgorithm': hasSeenStoryAlgorithm,
      'hasSeenStoryYourPrediction': hasSeenStoryYourPrediction,
      'hasSeenStoryPcNextMove': hasSeenStoryPcNextMove,
      'hasSeenStorySuggestion': hasSeenStorySuggestion,
      'hasSeenStoryCrystalBall': hasSeenStoryCrystalBall,
      'lastUserMoveId': lastUserMoveId,
      'lastComputerMoveId': lastComputerMoveId,
      'markovMatrix3': markovMatrix3,
      'markovMatrix5': markovMatrix5,
      'shortTermTransitions': shortTermTransitions?.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'language': language,
      'darkMode': darkMode,
      'soundEnabled': soundEnabled,
      'musicEnabled': musicEnabled,
      'vibrationEnabled': vibrationEnabled,
      'animationsEnabled': animationsEnabled,
      'confirmBattleTeleport': confirmBattleTeleport,
      'purchasedIapProductIds': purchasedIapProductIds,
      'updatedAtMillis': updatedAtMillis,
    };
  }

  String toJsonString() => json.encode(toJson());

  static List<List<int>>? _parseMatrix(dynamic raw, int expectedSize) {
    if (raw is! List || raw.length != expectedSize) return null;
    try {
      final parsed = raw
          .map((row) => (row as List).map((v) => (v as num).toInt()).toList())
          .toList();
      if (parsed.any((row) => row.length != expectedSize)) return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  static int _parseNonNegativeInt(dynamic raw) {
    final val = (raw as num?)?.toInt() ?? 0;
    return val < 0 ? 0 : val;
  }

  /// Merges permanent lifetime chronicles & peak records from [this] into [storage]
  /// using max(local, cloud) for counters and min non-zero for fastestVictoryWeek.
  Future<void> mergeLifetimeChroniclesIntoStorage(StorageService storage) async {
    await storage.setPeakHpUpgradeLevel(
      _maxInt(storage.peakHpUpgradeLevel, peakHpUpgradeLevel),
    );
    await storage.setPeakManaUpgradeLevel(
      _maxInt(storage.peakManaUpgradeLevel, peakManaUpgradeLevel),
    );
    await storage.setTotalCyclesCount(
      _maxInt(storage.totalCyclesCount, totalCyclesCount),
    );
    await storage.setDeathDefeatCount(
      _maxInt(storage.deathDefeatCount, deathDefeatCount),
    );
    await storage.setTimeoutDefeatCount(
      _maxInt(storage.timeoutDefeatCount, timeoutDefeatCount),
    );
    await storage.setForfeitRunCount(
      _maxInt(storage.forfeitRunCount, forfeitRunCount),
    );
    await storage.setStandardVictoryCount(
      _maxInt(storage.standardVictoryCount, standardVictoryCount),
    );
    await storage.setSecretVictoryCount(
      _maxInt(storage.secretVictoryCount, secretVictoryCount),
    );
    await storage.setFastestVictoryWeek(
      _minNonZeroWeek(storage.fastestVictoryWeek, fastestVictoryWeek),
    );
    await storage.setGuardianRobotDefeatedCount(
      _maxInt(storage.guardianRobotDefeatedCount, guardianRobotDefeatedCount),
    );
    await storage.setRobotArchmageDefeatedCount(
      _maxInt(storage.robotArchmageDefeatedCount, robotArchmageDefeatedCount),
    );
    await storage.setMetalWizardDefeatedCount(
      _maxInt(storage.metalWizardDefeatedCount, metalWizardDefeatedCount),
    );
    await storage.setBabyMageRobotDefeatedCount(
      _maxInt(storage.babyMageRobotDefeatedCount, babyMageRobotDefeatedCount),
    );
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  factory CloudSaveData.fromJson(Map<String, dynamic> map) {
    final orbsMap = map['orbs'] is Map ? map['orbs'] as Map : null;
    int fire =
        (orbsMap?['fire'] as num?)?.toInt() ??
        (map['fireOrbs'] as num?)?.toInt() ??
        0;
    int water =
        (orbsMap?['water'] as num?)?.toInt() ??
        (map['waterOrbs'] as num?)?.toInt() ??
        0;
    int wood =
        (orbsMap?['wood'] as num?)?.toInt() ??
        (map['woodOrbs'] as num?)?.toInt() ??
        0;
    int earth =
        (orbsMap?['earth'] as num?)?.toInt() ??
        (map['earthOrbs'] as num?)?.toInt() ??
        0;
    int metal =
        (orbsMap?['metal'] as num?)?.toInt() ??
        (map['metalOrbs'] as num?)?.toInt() ??
        0;

    // One-time legacy diamond migration for v1 cloud saves
    final legacyDiamonds = (map['diamonds'] as num?)?.toInt() ?? 0;
    if (legacyDiamonds > 0 &&
        fire == 0 &&
        water == 0 &&
        wood == 0 &&
        earth == 0 &&
        metal == 0) {
      fire = legacyDiamonds;
      water = legacyDiamonds;
      wood = legacyDiamonds;
      earth = legacyDiamonds;
      metal = legacyDiamonds;
    }

    final turn0OrbsMap =
        map['turn0Orbs'] is Map ? map['turn0Orbs'] as Map : null;
    final treasuryMap =
        map['treasuryOrbs'] is Map ? map['treasuryOrbs'] as Map : null;
    final spoilsMap =
        map['spoilsOfWarOrbs'] is Map ? map['spoilsOfWarOrbs'] as Map : null;

    return CloudSaveData(
      fireOrbs: fire,
      waterOrbs: water,
      woodOrbs: wood,
      earthOrbs: earth,
      metalOrbs: metal,
      turn0FireOrbs: (turn0OrbsMap?['fire'] as num?)?.toInt(),
      turn0WaterOrbs: (turn0OrbsMap?['water'] as num?)?.toInt(),
      turn0WoodOrbs: (turn0OrbsMap?['wood'] as num?)?.toInt(),
      turn0EarthOrbs: (turn0OrbsMap?['earth'] as num?)?.toInt(),
      turn0MetalOrbs: (turn0OrbsMap?['metal'] as num?)?.toInt(),
      treasuryFireOrbs: (treasuryMap?['fire'] as num?)?.toInt() ?? 0,
      treasuryWaterOrbs: (treasuryMap?['water'] as num?)?.toInt() ?? 0,
      treasuryWoodOrbs: (treasuryMap?['wood'] as num?)?.toInt() ?? 0,
      treasuryEarthOrbs: (treasuryMap?['earth'] as num?)?.toInt() ?? 0,
      treasuryMetalOrbs: (treasuryMap?['metal'] as num?)?.toInt() ?? 0,
      spoilsFireOrbs: (spoilsMap?['fire'] as num?)?.toInt() ?? 0,
      spoilsWaterOrbs: (spoilsMap?['water'] as num?)?.toInt() ?? 0,
      spoilsWoodOrbs: (spoilsMap?['wood'] as num?)?.toInt() ?? 0,
      spoilsEarthOrbs: (spoilsMap?['earth'] as num?)?.toInt() ?? 0,
      spoilsMetalOrbs: (spoilsMap?['metal'] as num?)?.toInt() ?? 0,
      relicChamberUpgrades: _parseStringList(map['relicChamberUpgrades']),
      hpUpgradeLevel: (map['hpUpgradeLevel'] as num?)?.toInt() ?? 0,
      manaUpgradeLevel: (map['manaUpgradeLevel'] as num?)?.toInt() ?? 0,
      peakHpUpgradeLevel: (map['peakHpUpgradeLevel'] as num?)?.toInt() ??
          (map['hallOfHeroesHpBonus'] as num?)?.toInt() ??
          0,
      peakManaUpgradeLevel: (map['peakManaUpgradeLevel'] as num?)?.toInt() ??
          (map['hallOfHeroesManaBonus'] as num?)?.toInt() ??
          0,
      hallOfHeroesClaimAvailable: map['hallOfHeroesClaimAvailable'] as bool? ??
          (((map['hallOfHeroesHpBonus'] as num?)?.toInt() ?? 0) > 0 ||
              ((map['hallOfHeroesManaBonus'] as num?)?.toInt() ?? 0) > 0),
      unlockedEndings: _parseStringList(map['unlockedEndings']),
      encounteredBestiary: _parseStringList(map['encounteredBestiary']),
      activeDecreeIds: map['activeDecreeIds'] is List
          ? _parseStringList(map['activeDecreeIds'])
          : null,
      completedCycleDecreeIds: _parseStringList(map['completedCycleDecreeIds']),
      totalDecreesCompleted:
          (map['totalDecreesCompleted'] as num?)?.toInt() ?? 0,
      totalCyclesCount: _parseNonNegativeInt(map['totalCyclesCount']),
      deathDefeatCount: _parseNonNegativeInt(map['deathDefeatCount']),
      timeoutDefeatCount: _parseNonNegativeInt(map['timeoutDefeatCount']),
      forfeitRunCount: _parseNonNegativeInt(map['forfeitRunCount']),
      standardVictoryCount: _parseNonNegativeInt(map['standardVictoryCount']),
      secretVictoryCount: _parseNonNegativeInt(map['secretVictoryCount']),
      fastestVictoryWeek: (() {
        final raw = (map['fastestVictoryWeek'] as num?)?.toInt();
        return (raw != null && raw > 0) ? raw : null;
      })(),
      guardianRobotDefeatedCount:
          _parseNonNegativeInt(map['guardianRobotDefeatedCount']),
      robotArchmageDefeatedCount:
          _parseNonNegativeInt(map['robotArchmageDefeatedCount']),
      metalWizardDefeatedCount:
          _parseNonNegativeInt(map['metalWizardDefeatedCount']),
      babyMageRobotDefeatedCount:
          _parseNonNegativeInt(map['babyMageRobotDefeatedCount']),
      adConsagrationsThisWeek:
          ((map['adConsagrationsThisWeek'] as num?)?.toInt() ?? 0) < 0
              ? 0
              : ((map['adConsagrationsThisWeek'] as num?)?.toInt() ?? 0),
      pendingBattleBlessing: (map['pendingBattleBlessing'] as String?)?.trim(),
      activeBattleBlessing: (map['activeBattleBlessing'] as String?)?.trim(),
      battleBonusTempHp:
          ((map['battleBonusTempHp'] as num?)?.toInt() ?? 0) < 0
              ? 0
              : ((map['battleBonusTempHp'] as num?)?.toInt() ?? 0),
      lastFreeDailyPrayerDate:
          (map['lastFreeDailyPrayerDate'] as String?)?.trim(),
      hasClaimedQaBonus: map['hasClaimedQaBonus'] as bool? ?? false,
      userScore: (map['userScore'] as num?)?.toInt() ?? 0,
      pcScore: (map['pcScore'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      userHp: (map['userHp'] as num?)?.toInt() ?? 50,
      pcHp: (map['pcHp'] as num?)?.toInt() ?? 100,
      enemyStage: ((map['enemyStage'] ?? map['enemyPhase']) as num?)
              ?.toInt()
              .clamp(1, 4) ??
          1,
      enemyMaxHp: ((map['enemyMaxHp'] as num?)?.toInt() ??
              (() {
                final stage =
                    ((map['enemyStage'] ?? map['enemyPhase']) as num?)
                            ?.toInt()
                            .clamp(1, 4) ??
                        1;
                if (stage == 2) return 200;
                if (stage == 3) return 300;
                if (stage == 4) return 400;
                return 100;
              })())
          .clamp(100, 9999),
      currentWeek: ((map['currentWeek'] as num?)?.toInt() ?? 1) < 0
          ? 0
          : ((map['currentWeek'] as num?)?.toInt() ?? 1),
      unlockedReset: map['unlockedReset'] as bool? ?? false,
      unlockedPredictability: map['unlockedPredictability'] as bool? ?? false,
      unlockedRandom: map['unlockedRandom'] as bool? ?? false,
      unlockedAlgorithm: map['unlockedAlgorithm'] as bool? ?? false,
      unlockedNewHands: map['unlockedNewHands'] as bool? ?? false,
      unlockedYourPrediction: map['unlockedYourPrediction'] as bool? ?? false,
      unlockedNextMove: map['unlockedNextMove'] as bool? ?? false,
      unlockedSuggestion: map['unlockedSuggestion'] as bool? ?? false,
      unlockedAds: map['unlockedAds'] as bool? ?? false,
      unlockedNewSkin: map['unlockedNewSkin'] as bool? ?? false,
      unlockedCrystalBall: map['unlockedCrystalBall'] as bool? ?? false,
      unlockedCrystalBallPlus: map['unlockedCrystalBallPlus'] as bool? ?? false,
      unlockedMarkovRecalibrator:
          map['unlockedMarkovRecalibrator'] as bool? ?? false,
      giftBoxUnlocked: map['giftBoxUnlocked'] as bool? ?? false,
      overchargedStaffLevel:
          ((map['overchargedStaffLevel'] as num?)?.toInt() ?? 0).clamp(0, 4),
      showReset: map['showReset'] as bool? ?? false,
      showPredictability: map['showPredictability'] as bool? ?? false,
      showRandom: map['showRandom'] as bool? ?? false,
      showAlgorithm: map['showAlgorithm'] as bool? ?? false,
      showNewHands: map['showNewHands'] as bool? ?? false,
      showNewSkin: map['showNewSkin'] as bool? ?? false,
      showYourPrediction: map['showYourPrediction'] as bool? ?? false,
      showNextMove: map['showNextMove'] as bool? ?? false,
      showSuggestion: map['showSuggestion'] as bool? ?? false,
      removeAdsEnabled:
          map['removeAdsEnabled'] as bool? ?? (map['unlockedAds'] as bool? ?? false),
      showCrystalBall: map['showCrystalBall'] as bool? ?? false,
      showCrystalBallPlus: map['showCrystalBallPlus'] as bool? ?? false,
      crystalBallPlusSavedState:
          map['crystalBallPlusSavedState'] as bool? ?? false,
      showMarkovRecalibrator: map['showMarkovRecalibrator'] as bool? ?? false,
      giftBoxEnabled: map['giftBoxEnabled'] as bool? ?? false,
      overchargedStaffEnabled:
          map['overchargedStaffEnabled'] as bool? ?? false,
      overchargedStaffSelectedSpeed: (() {
        final raw = (map['overchargedStaffSelectedSpeed'] as num?)?.toInt() ?? 1;
        return (raw == 1 || raw == 2 || raw == 5 || raw == 10) ? raw : 1;
      })(),
      hasSeenStoryIntro: map['hasSeenStoryIntro'] as bool? ?? false,
      hasSeenStoryReset: map['hasSeenStoryReset'] as bool? ?? false,
      hasSeenStoryPredictability:
          map['hasSeenStoryPredictability'] as bool? ?? false,
      hasSeenStoryRandom: map['hasSeenStoryRandom'] as bool? ?? false,
      hasSeenStoryAlgorithm: map['hasSeenStoryAlgorithm'] as bool? ?? false,
      hasSeenStoryYourPrediction:
          map['hasSeenStoryYourPrediction'] as bool? ?? false,
      hasSeenStoryPcNextMove: map['hasSeenStoryPcNextMove'] as bool? ?? false,
      hasSeenStorySuggestion: map['hasSeenStorySuggestion'] as bool? ?? false,
      hasSeenStoryCrystalBall: map['hasSeenStoryCrystalBall'] as bool? ?? false,
      lastUserMoveId: (map['lastUserMoveId'] as num?)?.toInt(),
      lastComputerMoveId: (map['lastComputerMoveId'] as num?)?.toInt(),
      markovMatrix3: _parseMatrix(map['markovMatrix3'], 3),
      markovMatrix5: _parseMatrix(map['markovMatrix5'], 5),
      shortTermTransitions: _parseIntMap(map['shortTermTransitions']),
      language: (map['language'] as String?) ?? 'en',
      darkMode: map['darkMode'] as bool? ?? true,
      soundEnabled: map['soundEnabled'] as bool? ?? true,
      musicEnabled: map['musicEnabled'] as bool? ?? true,
      vibrationEnabled: map['vibrationEnabled'] as bool? ?? true,
      animationsEnabled: map['animationsEnabled'] as bool? ?? true,
      confirmBattleTeleport: map['confirmBattleTeleport'] as bool? ?? true,
      purchasedIapProductIds: (map['purchasedIapProductIds'] is List)
          ? (map['purchasedIapProductIds'] as List)
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList()
          : const [],
      updatedAtMillis: (map['updatedAtMillis'] as num?)?.toInt() ?? 0,
    );
  }

  static Map<int, int>? _parseIntMap(dynamic raw) {
    if (raw is! Map) return null;
    final parsed = <int, int>{};
    for (final entry in raw.entries) {
      final k = int.tryParse(entry.key.toString());
      final v = (entry.value as num?)?.toInt() ??
          int.tryParse(entry.value.toString());
      if (k != null && v != null && k >= 1 && k <= 5 && v >= 1 && v <= 5) {
        parsed[k] = v;
      }
    }
    return parsed.isEmpty ? null : parsed;
  }

  static CloudSaveData? tryParse(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) return null;
    try {
      final decoded = json.decode(rawJson);
      if (decoded is Map<String, dynamic>) {
        return CloudSaveData.fromJson(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Manages Google Play Games Services authentication, player profile state,
/// and Saved Games cloud synchronization with offline-first fallback.
class PlayGamesService extends ChangeNotifier {
  static const String saveSlotName = 'how_predictable_cloud_save';
  static const String placeholderPlayerId = StorageService.placeholderPlayerId;
  static const int qaBonusOrbs = 100000;
  static const String qaBonusSnackBarMessage =
      'Tester Bonus: +100,000 Elemental Orbs';

  /// Returns true only when [playerId] is a real, non-empty Google Play Games
  /// player ID and not the legacy placeholder (`GPG-PLAYER`).
  static bool isValidPlayerId(String? playerId) =>
      StorageService.isValidPlayerId(playerId);

  /// Authorized QA tester Google Play Games player IDs (primary check).
  static const Set<String> qaTesterIds = {
    'a_2116013489197419559',
    'g01804264806540615668',
  };

  /// Authorized QA tester Google Play Games player names (lowercase for case-insensitive fallback).
  static const Set<String> qaTesterNamesLower = {
    'gustlarsentester',
    'gustlarsen',
  };

  /// Returns true if [playerId] matches an authorized QA tester ID (primary check)
  /// or [playerName] matches an authorized QA tester name (case-insensitive fallback).
  static bool isQaTester({String? playerId, String? playerName}) {
    if (playerId != null && qaTesterIds.contains(playerId.trim())) {
      return true;
    }
    if (playerName != null &&
        qaTesterNamesLower.contains(playerName.trim().toLowerCase())) {
      return true;
    }
    return false;
  }

  final StorageService storage;
  final PlayGamesClient _client;
  final Duration _silentAuthTimeout;
  final Duration _retryBaseDelay;
  final Duration _profileRetryDelay;
  final int _maxAutoRetries;
  final int _maxProfileFetchAttempts;

  bool _isSignedIn = false;
  bool _isAuthenticating = false;
  bool _pendingManualSignIn = false;
  Completer<bool>? _activeSignInCompleter;
  String? _playerName;
  String? _playerID;
  String? _lastPlayerID;
  String? _lastErrorCode;
  String? _lastErrorMessage;
  CloudSyncStatus _syncStatus = CloudSyncStatus.offline;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  VoidCallback? onCloudDataRestored;
  VoidCallback? onQaBonusGranted;

  PlayGamesService({
    required this.storage,
    PlayGamesClient? client,
    Duration silentAuthTimeout = const Duration(seconds: 15),
    Duration retryBaseDelay = const Duration(seconds: 3),
    Duration profileRetryDelay = const Duration(milliseconds: 350),
    int maxAutoRetries = 3,
    int maxProfileFetchAttempts = 3,
    this.onCloudDataRestored,
    this.onQaBonusGranted,
  }) : _client = client ?? const DefaultPlayGamesClient(),
       _silentAuthTimeout = silentAuthTimeout,
       _retryBaseDelay = retryBaseDelay,
       _profileRetryDelay = profileRetryDelay,
       _maxAutoRetries = maxAutoRetries,
       _maxProfileFetchAttempts = maxProfileFetchAttempts;

  bool get isSignedIn => _isSignedIn && isValidPlayerId(_playerID);
  bool get isAuthenticating => _isAuthenticating;
  bool get isRetryScheduled => _retryTimer?.isActive ?? false;
  String? get playerName => isSignedIn ? _playerName : null;
  String? get playerID => isValidPlayerId(_playerID) ? _playerID : null;
  String? get lastPlayerID =>
      isValidPlayerId(_lastPlayerID) ? _lastPlayerID : storage.lastPlayerId;
  String? get lastErrorCode => _lastErrorCode;
  String? get lastErrorMessage => _lastErrorMessage;

  /// Human-readable diagnostic message for the most recent sign-in failure.
  /// Distinguishes genuine network/timeout issues from Google Play Games SDK
  /// or `PlatformException` authentication errors.
  String get signInDiagnosticMessage => formatSignInFailureMessage(
    errorCode: _lastErrorCode,
    errorMessage: _lastErrorMessage,
  );

  /// Formats a clear diagnostic message from a sign-in failure [errorCode] and
  /// [errorMessage], avoiding mislabeling SDK/auth errors as "Offline mode".
  static String formatSignInFailureMessage({
    String? errorCode,
    String? errorMessage,
  }) {
    final code = errorCode?.trim() ?? '';
    final msg = errorMessage?.trim() ?? '';
    final combinedLower = '$code $msg'.toLowerCase();

    final isNetworkOrOffline =
        code == 'network_error' ||
        code == 'sign_in_timeout' ||
        combinedLower.contains('network_error') ||
        combinedLower.contains('no internet') ||
        combinedLower.contains('offline') ||
        combinedLower.contains('socketexception') ||
        combinedLower.contains('unable to resolve host') ||
        combinedLower.contains('7:');

    if (isNetworkOrOffline) {
      if (msg.isNotEmpty) {
        return 'Could not connect to Google Play Games (Offline: $msg)';
      }
      return 'Could not connect to Google Play Games (Check internet connection)';
    }

    if (code.isNotEmpty && msg.isNotEmpty) {
      return 'Google Play Games sign-in failed [$code]: $msg';
    }
    if (code.isNotEmpty) {
      return 'Google Play Games sign-in failed [$code]';
    }
    if (msg.isNotEmpty) {
      return 'Google Play Games sign-in failed: $msg';
    }
    return 'Could not connect to Google Play Games (Offline mode)';
  }

  CloudSyncStatus get syncStatus =>
      isSignedIn ? _syncStatus : CloudSyncStatus.offline;

  /// Attempts silent sign-in on app startup and merges cloud progression if
  /// the cloud save holds a higher progression state or diamond count.
  /// Gracefully falls back to offline `SharedPreferences` cache if declined or offline.
  Future<bool> initialize() async {
    _retryAttempt = 0;
    return signIn(silent: true);
  }

  /// Re-checks the active Google Play Games player session when the app resumes
  /// from the background (`AppLifecycleState.resumed`), detecting any OS-level
  /// account switch or sign-out performed in the Google Play Games app.
  Future<bool> handleAppResumed() {
    _retryAttempt = 0;
    return signIn(silent: true);
  }

  /// Handles app lifecycle state transitions, refreshing the active player
  /// session whenever [state] is [AppLifecycleState.resumed].
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(handleAppResumed());
    }
  }

  /// Cancels any scheduled automatic background sign-in retry timer.
  void cancelPendingRetries() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
  }

  @override
  void dispose() {
    cancelPendingRetries();
    super.dispose();
  }

  void _scheduleRetryIfNeeded() {
    if (_retryAttempt >= _maxAutoRetries) return;
    if (_retryTimer != null && _retryTimer!.isActive) return;
    final delay = _retryBaseDelay * (1 << _retryAttempt);
    _retryAttempt++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (!isSignedIn && !_isAuthenticating) {
        unawaited(signIn(silent: true));
      }
    });
  }

  void _recordSignInError(Object error, [StackTrace? stackTrace]) {
    const fallbackCode = 'sign_in_error';
    if (error is PlatformException) {
      _lastErrorCode = error.code.trim().isNotEmpty
          ? error.code.trim()
          : fallbackCode;
      final detailsStr = error.details?.toString().trim() ?? '';
      final msgStr = error.message?.trim() ?? '';
      _lastErrorMessage = [
        if (msgStr.isNotEmpty) msgStr,
        if (detailsStr.isNotEmpty && detailsStr != msgStr) detailsStr,
      ].join(' - ');
    } else if (error is TimeoutException) {
      _lastErrorCode = 'sign_in_timeout';
      _lastErrorMessage = error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'Timed out waiting for Google Play Games';
    } else {
      _lastErrorCode = fallbackCode;
      _lastErrorMessage = error.toString().trim();
    }
    debugPrint(
      '[PlayGamesService] Sign-in failed (code=$_lastErrorCode): '
      '$_lastErrorMessage',
    );
    if (stackTrace != null) {
      debugPrint('[PlayGamesService] StackTrace: $stackTrace');
    }
  }

  /// Signs in with Google Play Games Services (`GamesServices.signIn()`).
  /// When [silent] is true, errors or slow timeouts fall back gracefully to
  /// offline mode without overwriting local user settings or triggering a false
  /// multi-account reset, and schedule bounded retries.
  /// When [silent] is false (manual user tap), if a silent sign-in is already
  /// in progress, awaits it and immediately triggers a fresh sign-in attempt if
  /// the silent attempt did not succeed.
  Future<bool> signIn({bool silent = false}) async {
    if (_isAuthenticating) {
      if (!silent) {
        _pendingManualSignIn = true;
      }
      final active = _activeSignInCompleter;
      if (active != null) {
        final currentResult = await active.future;
        if (currentResult || silent) {
          _pendingManualSignIn = false;
          return currentResult;
        }
        if (_pendingManualSignIn && !_isAuthenticating) {
          _pendingManualSignIn = false;
          return signIn(silent: false);
        }
      }
      return isSignedIn;
    }

    _retryTimer?.cancel();
    _retryTimer = null;
    if (!silent) {
      _retryAttempt = 0;
      _pendingManualSignIn = false;
    }

    final completer = Completer<bool>();
    _activeSignInCompleter = completer;
    _isAuthenticating = true;
    notifyListeners();

    Future<bool> finish(bool outcome) async {
      if (identical(_activeSignInCompleter, completer)) {
        _activeSignInCompleter = null;
      }
      if (!outcome && _pendingManualSignIn && !_isAuthenticating) {
        _pendingManualSignIn = false;
        final manualOutcome = await signIn(silent: false);
        if (!completer.isCompleted) {
          completer.complete(manualOutcome);
        }
        return manualOutcome;
      }
      _pendingManualSignIn = false;
      if (!completer.isCompleted) {
        completer.complete(outcome);
      }
      return outcome;
    }

    try {
      const sentinelTimeout = '__PLAY_GAMES_SIGN_IN_TIMEOUT__';
      final signInFuture = _client.signIn();
      final result = silent
          ? await signInFuture.timeout(
              _silentAuthTimeout,
              onTimeout: () => sentinelTimeout,
            )
          : await signInFuture;
      if (result == sentinelTimeout) {
        _recordSignInError(
          TimeoutException('Google Play Games sign-in timed out'),
        );
        _setDisconnectedState();
        if (silent) {
          _scheduleRetryIfNeeded();
        }
        return await finish(false);
      }
      if (result == null) {
        _lastErrorCode = 'sign_in_canceled_or_unavailable';
        _lastErrorMessage =
            'Google Play Games signIn() returned null (not authenticated)';
        debugPrint(
          '[PlayGamesService] Sign-in returned null: $_lastErrorMessage',
        );
        _setDisconnectedState();
        if (silent) {
          _scheduleRetryIfNeeded();
        }
        return await finish(false);
      }

      String? fetchedName;
      String? fetchedId;
      final attempts = _maxProfileFetchAttempts < 1
          ? 1
          : _maxProfileFetchAttempts;

      for (int attempt = 0; attempt < attempts; attempt++) {
        final nameFuture = _client.getPlayerName();
        final idFuture = _client.getPlayerID();
        fetchedName = silent
            ? await nameFuture.timeout(
                _silentAuthTimeout,
                onTimeout: () => null,
              )
            : await nameFuture;
        fetchedId = silent
            ? await idFuture.timeout(
                _silentAuthTimeout,
                onTimeout: () => null,
              )
            : await idFuture;

        if (isValidPlayerId(fetchedId)) {
          break;
        }
        if (attempt + 1 < attempts && _profileRetryDelay > Duration.zero) {
          await Future<void>.delayed(_profileRetryDelay);
        }
      }

      if (!isValidPlayerId(fetchedId)) {
        _lastErrorCode = 'invalid_player_id';
        _lastErrorMessage = fetchedId == null || fetchedId.trim().isEmpty
            ? 'Player ID unavailable while Play Games profile is initializing'
            : 'Rejected placeholder Player ID "${fetchedId.trim()}"';
        debugPrint(
          '[PlayGamesService] Rejecting unverified playerID: '
          '$_lastErrorMessage',
        );
        _setDisconnectedState();
        if (silent) {
          _scheduleRetryIfNeeded();
        }
        return await finish(false);
      }

      final resolvedId = fetchedId!.trim();
      final resolvedName = (fetchedName != null && fetchedName.trim().isNotEmpty)
          ? fetchedName.trim()
          : 'Play Games Player';

      final previousPlayerId = lastPlayerID;
      final bool playerChanged =
          previousPlayerId != null && previousPlayerId != resolvedId;

      _retryAttempt = 0;
      _lastErrorCode = null;
      _lastErrorMessage = null;
      _isSignedIn = true;
      _playerName = resolvedName;
      _playerID = resolvedId;
      _lastPlayerID = resolvedId;
      await storage.setLastPlayerId(resolvedId);
      _isAuthenticating = false;
      notifyListeners();

      if (playerChanged) {
        await storage.clearGameplayProgress(
          includeSettings: true,
          includeCastleMeta: true,
        );
        onCloudDataRestored?.call();
        await loadAndResolveCloudSave(isAccountSwitch: true);
      } else {
        await loadAndResolveCloudSave();
      }
      return await finish(true);
    } catch (error, stackTrace) {
      _recordSignInError(error, stackTrace);
      _setDisconnectedState();
      if (silent) {
        _scheduleRetryIfNeeded();
      }
      return await finish(false);
    }
  }

  /// Loads the saved game from Google Play Saved Games (`GamesServices.loadGame`).
  /// When [isAccountSwitch] is true, local gameplay progress and settings have
  /// already been reset for the new playerID, so any existing cloud save for the
  /// new playerID is applied directly (or defaults if none exists).
  /// Otherwise, merges/restores cloud data over local data if the cloud save
  /// holds a higher (or equal) progression state or diamond count; if local data
  /// has higher progression, pushes the local state to cloud.
  Future<bool> loadAndResolveCloudSave({bool isAccountSwitch = false}) async {
    if (!isSignedIn) {
      _syncStatus = CloudSyncStatus.offline;
      notifyListeners();
      return false;
    }

    _syncStatus = CloudSyncStatus.syncing;
    notifyListeners();

    try {
      if (!isAccountSwitch) {
        final fetchedId = await _client.getPlayerID();
        if (isValidPlayerId(fetchedId)) {
          final resolvedId = fetchedId!.trim();
          final previousPlayerId = lastPlayerID;
          if (previousPlayerId != null && previousPlayerId != resolvedId) {
            isAccountSwitch = true;
            _playerID = resolvedId;
            _lastPlayerID = resolvedId;
            await storage.setLastPlayerId(resolvedId);
            final fetchedName = await _client.getPlayerName();
            if (fetchedName != null && fetchedName.trim().isNotEmpty) {
              _playerName = fetchedName.trim();
            }
            await storage.clearGameplayProgress(
          includeSettings: true,
          includeCastleMeta: true,
        );
            onCloudDataRestored?.call();
          }
        }
      }

      final rawCloud = await _client.loadGame(name: saveSlotName);
      final cloudData = CloudSaveData.tryParse(rawCloud);
      final localData = CloudSaveData.fromStorage(storage);

      bool restoredFromCloud = false;
      if (isAccountSwitch) {
        if (cloudData != null) {
          await cloudData.applyToStorage(storage);
          restoredFromCloud = true;
        }
        onCloudDataRestored?.call();
      } else if (cloudData != null &&
          cloudData.hasHigherProgressionOrOrbsThan(localData)) {
        final merged = cloudData.mergeOverLocal(localData);
        await merged.applyToStorage(storage);
        restoredFromCloud = true;
        onCloudDataRestored?.call();
      } else if (localData.hasHigherProgressionOrOrbsThan(
            cloudData ?? const CloudSaveData(),
          )) {
        if (cloudData != null) {
          if (cloudData.hasClaimedQaBonus && !storage.hasClaimedQaBonus) {
            await storage.setHasClaimedQaBonus(true);
          }
          await cloudData.mergeLifetimeChroniclesIntoStorage(storage);
          onCloudDataRestored?.call();
        }
        // Keep local progression and back it up to the cloud
        final updatedLocal = CloudSaveData.fromStorage(storage);
        await _client.saveGame(
          data: updatedLocal.toJsonString(),
          name: saveSlotName,
        );
      } else if (cloudData != null) {
        // Equal progression/orbs: apply cloud save (including account settings)
        final merged = cloudData.mergeOverLocal(localData);
        await merged.applyToStorage(storage);
        restoredFromCloud = true;
        onCloudDataRestored?.call();
      }

      await checkAndGrantQaBonusIfEligible(cloudData: cloudData);

      _syncStatus = isSignedIn ? CloudSyncStatus.synced : CloudSyncStatus.offline;
      notifyListeners();
      return restoredFromCloud;
    } catch (error) {
      debugPrint('[PlayGamesService] loadAndResolveCloudSave error: $error');
      if (isAccountSwitch) {
        onCloudDataRestored?.call();
      }
      await checkAndGrantQaBonusIfEligible();
      // Cloud load failed (e.g., no existing snapshot or temporary network issue);
      // attempt to save current local state or fall back to offline status.
      try {
        final localData = CloudSaveData.fromStorage(storage);
        final saveRes = await _client.saveGame(
          data: localData.toJsonString(),
          name: saveSlotName,
        );
        _syncStatus = (isSignedIn && saveRes != null)
            ? CloudSyncStatus.synced
            : CloudSyncStatus.offline;
      } catch (saveError) {
        debugPrint('[PlayGamesService] fallback saveGame error: $saveError');
        _syncStatus = CloudSyncStatus.offline;
      }
      notifyListeners();
      return false;
    }
  }

  /// If the currently signed-in player is an authorized QA tester and
  /// `hasClaimedQaBonus` is false in both local storage and [cloudData],
  /// grants +100,000 of each Elemental Orb once, sets `hasClaimedQaBonus = true`,
  /// immediately saves to Google Play Saved Games, and notifies listeners.
  Future<bool> checkAndGrantQaBonusIfEligible({CloudSaveData? cloudData}) async {
    if (!isSignedIn) return false;
    if (!isQaTester(playerId: playerID, playerName: _playerName)) {
      return false;
    }

    final alreadyClaimed =
        storage.hasClaimedQaBonus || (cloudData?.hasClaimedQaBonus ?? false);
    if (alreadyClaimed) {
      if (!storage.hasClaimedQaBonus) {
        await storage.setHasClaimedQaBonus(true);
      }
      return false;
    }

    final baseTurn0Fire = storage.turn0FireOrbs;
    final baseTurn0Water = storage.turn0WaterOrbs;
    final baseTurn0Wood = storage.turn0WoodOrbs;
    final baseTurn0Earth = storage.turn0EarthOrbs;
    final baseTurn0Metal = storage.turn0MetalOrbs;

    await storage.setAllOrbs(
      fire: storage.fireOrbs + qaBonusOrbs,
      water: storage.waterOrbs + qaBonusOrbs,
      wood: storage.woodOrbs + qaBonusOrbs,
      earth: storage.earthOrbs + qaBonusOrbs,
      metal: storage.metalOrbs + qaBonusOrbs,
    );
    await storage.setTurn0Orbs(
      fire: baseTurn0Fire + qaBonusOrbs,
      water: baseTurn0Water + qaBonusOrbs,
      wood: baseTurn0Wood + qaBonusOrbs,
      earth: baseTurn0Earth + qaBonusOrbs,
      metal: baseTurn0Metal + qaBonusOrbs,
    );
    await storage.setHasClaimedQaBonus(true);
    onCloudDataRestored?.call();
    onQaBonusGranted?.call();

    final snapshot = CloudSaveData.fromStorage(storage);
    await _client.saveGame(
      data: snapshot.toJsonString(),
      name: saveSlotName,
    );
    return true;
  }

  /// Saves the player's current progression state from [storage] to
  /// Google Play Saved Games (`GamesServices.saveGame`).
  Future<bool> saveCloudData() async {
    if (!isSignedIn) {
      _syncStatus = CloudSyncStatus.offline;
      notifyListeners();
      return false;
    }

    _syncStatus = CloudSyncStatus.syncing;
    notifyListeners();

    try {
      final snapshot = CloudSaveData.fromStorage(storage);
      final result = await _client.saveGame(
        data: snapshot.toJsonString(),
        name: saveSlotName,
      );
      if (isSignedIn && result != null) {
        _syncStatus = CloudSyncStatus.synced;
        notifyListeners();
        return true;
      } else {
        _syncStatus = CloudSyncStatus.offline;
        notifyListeners();
        return false;
      }
    } catch (error) {
      debugPrint('[PlayGamesService] saveCloudData error: $error');
      _syncStatus = CloudSyncStatus.offline;
      notifyListeners();
      return false;
    }
  }

  void _setDisconnectedState() {
    _isSignedIn = false;
    _isAuthenticating = false;
    _playerName = null;
    _playerID = null;
    _syncStatus = CloudSyncStatus.offline;
    notifyListeners();
  }
}

