import 'dart:async';
import 'dart:convert';
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
  final String? message;

  const PlayGamesAuthResult({
    required this.success,
    this.playerName,
    this.playerID,
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
class DefaultPlayGamesClient implements PlayGamesClient {
  const DefaultPlayGamesClient();

  @override
  Future<String?> signIn() => GamesServices.signIn();

  @override
  Future<String?> getPlayerName() async {
    try {
      return await GamesServices.getPlayerName().timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getPlayerID() async {
    try {
      return await GamesServices.getPlayerID().timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> saveGame({required String data, required String name}) =>
      GamesServices.saveGame(data: data, name: name);

  @override
  Future<String?> loadGame({required String name}) =>
      GamesServices.loadGame(name: name);
}

/// Serializable snapshot of the player's full progression state for
/// Google Play Saved Games cloud synchronization.
class CloudSaveData {
  final int fireOrbs;
  final int waterOrbs;
  final int woodOrbs;
  final int earthOrbs;
  final int metalOrbs;
  final bool hasClaimedQaBonus;
  final int userScore;
  final int pcScore;
  final int total;
  final int userHp;
  final int pcHp;

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
  final bool giftBoxUnlocked;

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
  final bool giftBoxEnabled;

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

  // Per-Account Settings
  final String language;
  final bool darkMode;
  final bool soundEnabled;
  final bool musicEnabled;
  final bool vibrationEnabled;
  final bool animationsEnabled;

  final int updatedAtMillis;

  const CloudSaveData({
    this.fireOrbs = 0,
    this.waterOrbs = 0,
    this.woodOrbs = 0,
    this.earthOrbs = 0,
    this.metalOrbs = 0,
    this.hasClaimedQaBonus = false,
    this.userScore = 0,
    this.pcScore = 0,
    this.total = 0,
    this.userHp = 100,
    this.pcHp = 100,
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
    this.giftBoxUnlocked = false,
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
    this.giftBoxEnabled = false,
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
    this.language = 'en',
    this.darkMode = true,
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.vibrationEnabled = true,
    this.animationsEnabled = true,
    this.updatedAtMillis = 0,
  }) : removeAdsEnabled = removeAdsEnabled ?? unlockedAds;

  /// Total sum of all 5 Elemental Orbs in this snapshot.
  int get totalOrbs =>
      fireOrbs + waterOrbs + woodOrbs + earthOrbs + metalOrbs;

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
    if (giftBoxUnlocked) count++;
    return count;
  }

  /// Total Elemental Orb value of all unlocked shop items in this snapshot.
  int get unlockedShopValue {
    int value = 0;
    if (unlockedPredictability) value += 45;
    if (unlockedReset) value += 90;
    if (unlockedNewHands) value += 120;
    if (unlockedRandom) value += 240;
    if (unlockedAlgorithm) value += 460;
    if (unlockedYourPrediction) value += 950;
    if (unlockedNextMove) value += 2400;
    if (giftBoxUnlocked) value += 2500;
    if (unlockedSuggestion) value += 4000;
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
        (total > local.total ||
            userScore > local.userScore ||
            markovTransitionsCount > local.markovTransitionsCount)) {
      return true;
    }
    return false;
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
      hasClaimedQaBonus: hasClaimedQaBonus || local.hasClaimedQaBonus,
      userScore: userScore,
      pcScore: pcScore,
      total: total,
      userHp: userHp,
      pcHp: pcHp,
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
      giftBoxUnlocked: giftBoxUnlocked || local.giftBoxUnlocked,
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
      giftBoxEnabled: giftBoxEnabled,
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
      language: language,
      darkMode: darkMode,
      soundEnabled: soundEnabled,
      musicEnabled: musicEnabled,
      vibrationEnabled: vibrationEnabled,
      animationsEnabled: animationsEnabled,
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
      hasClaimedQaBonus: storage.hasClaimedQaBonus,
      userScore: storage.userScore,
      pcScore: storage.pcScore,
      total: storage.total,
      userHp: storage.userHp,
      pcHp: storage.pcHp,
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
      giftBoxUnlocked: storage.giftBoxUnlocked,
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
      giftBoxEnabled: storage.giftBoxEnabled,
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
      language: storage.language,
      darkMode: storage.darkMode,
      soundEnabled: storage.soundEnabled,
      musicEnabled: storage.musicEnabled,
      vibrationEnabled: storage.vibrationEnabled,
      animationsEnabled: storage.animationsEnabled,
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
    await storage.clearLegacyDiamonds();
    await storage.setHasClaimedQaBonus(hasClaimedQaBonus);
    await storage.setUserScore(userScore);
    await storage.setPcScore(pcScore);
    await storage.setTotal(total);
    await storage.setUserHp(userHp);
    await storage.setPcHp(pcHp);

    await storage.setLanguage(language);
    await storage.setDarkMode(darkMode);
    await storage.setSoundEnabled(soundEnabled);
    await storage.setMusicEnabled(musicEnabled);
    await storage.setVibrationEnabled(vibrationEnabled);
    await storage.setAnimationsEnabled(animationsEnabled);

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
    await storage.setGiftBoxUnlocked(giftBoxUnlocked);

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
    await storage.setGiftBoxEnabled(giftBoxUnlocked ? giftBoxEnabled : false);

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
      'hasClaimedQaBonus': hasClaimedQaBonus,
      'userScore': userScore,
      'pcScore': pcScore,
      'total': total,
      'userHp': userHp,
      'pcHp': pcHp,
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
      'giftBoxUnlocked': giftBoxUnlocked,
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
      'giftBoxEnabled': giftBoxEnabled,
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
      'language': language,
      'darkMode': darkMode,
      'soundEnabled': soundEnabled,
      'musicEnabled': musicEnabled,
      'vibrationEnabled': vibrationEnabled,
      'animationsEnabled': animationsEnabled,
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

    return CloudSaveData(
      fireOrbs: fire,
      waterOrbs: water,
      woodOrbs: wood,
      earthOrbs: earth,
      metalOrbs: metal,
      hasClaimedQaBonus: map['hasClaimedQaBonus'] as bool? ?? false,
      userScore: (map['userScore'] as num?)?.toInt() ?? 0,
      pcScore: (map['pcScore'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      userHp: (map['userHp'] as num?)?.toInt() ?? 100,
      pcHp: (map['pcHp'] as num?)?.toInt() ?? 100,
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
      giftBoxUnlocked: map['giftBoxUnlocked'] as bool? ?? false,
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
      giftBoxEnabled: map['giftBoxEnabled'] as bool? ?? false,
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
      language: (map['language'] as String?) ?? 'en',
      darkMode: map['darkMode'] as bool? ?? true,
      soundEnabled: map['soundEnabled'] as bool? ?? true,
      musicEnabled: map['musicEnabled'] as bool? ?? true,
      vibrationEnabled: map['vibrationEnabled'] as bool? ?? true,
      animationsEnabled: map['animationsEnabled'] as bool? ?? true,
      updatedAtMillis: (map['updatedAtMillis'] as num?)?.toInt() ?? 0,
    );
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
  static const int qaBonusOrbs = 100000;
  static const String qaBonusSnackBarMessage =
      'Tester Bonus: +100,000 Elemental Orbs';

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

  bool _isSignedIn = false;
  bool _isAuthenticating = false;
  String? _playerName;
  String? _playerID;
  String? _lastPlayerID;
  CloudSyncStatus _syncStatus = CloudSyncStatus.offline;
  VoidCallback? onCloudDataRestored;
  VoidCallback? onQaBonusGranted;

  PlayGamesService({
    required this.storage,
    PlayGamesClient? client,
    this.onCloudDataRestored,
    this.onQaBonusGranted,
  }) : _client = client ?? const DefaultPlayGamesClient();

  bool get isSignedIn => _isSignedIn;
  bool get isAuthenticating => _isAuthenticating;
  String? get playerName => _playerName;
  String? get playerID => _playerID;
  String? get lastPlayerID => _lastPlayerID ?? storage.lastPlayerId;
  CloudSyncStatus get syncStatus => _syncStatus;

  /// Attempts silent sign-in on app startup and merges cloud progression if
  /// the cloud save holds a higher progression state or diamond count.
  /// Gracefully falls back to offline `SharedPreferences` cache if declined or offline.
  Future<bool> initialize() async {
    return signIn(silent: true);
  }

  /// Re-checks the active Google Play Games player session when the app resumes
  /// from the background (`AppLifecycleState.resumed`), detecting any OS-level
  /// account switch or sign-out performed in the Google Play Games app.
  Future<bool> handleAppResumed() {
    return signIn(silent: true);
  }

  /// Handles app lifecycle state transitions, refreshing the active player
  /// session whenever [state] is [AppLifecycleState.resumed].
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(handleAppResumed());
    }
  }

  /// Signs in with Google Play Games Services (`GamesServices.signIn()`).
  /// When [silent] is true, errors are silently ignored and the game continues
  /// in offline mode.
  Future<bool> signIn({bool silent = false}) async {
    if (_isAuthenticating) return _isSignedIn;

    _isAuthenticating = true;
    notifyListeners();

    try {
      final result = await _client.signIn();
      if (result == null) {
        _setDisconnectedState();
        return false;
      }

      final fetchedName = await _client.getPlayerName();
      final fetchedId = await _client.getPlayerID();

      final resolvedName = (fetchedName != null && fetchedName.trim().isNotEmpty)
          ? fetchedName.trim()
          : 'Play Games Player';
      final resolvedId = (fetchedId != null && fetchedId.trim().isNotEmpty)
          ? fetchedId.trim()
          : 'GPG-PLAYER';

      final previousPlayerId = _lastPlayerID ?? storage.lastPlayerId;
      final bool playerChanged =
          previousPlayerId != null && previousPlayerId != resolvedId;

      _isSignedIn = true;
      _playerName = resolvedName;
      _playerID = resolvedId;
      _lastPlayerID = resolvedId;
      await storage.setLastPlayerId(resolvedId);
      _isAuthenticating = false;
      notifyListeners();

      if (playerChanged) {
        await storage.clearGameplayProgress(includeSettings: true);
        onCloudDataRestored?.call();
        await loadAndResolveCloudSave(isAccountSwitch: true);
      } else {
        await loadAndResolveCloudSave();
      }
      return true;
    } catch (_) {
      _setDisconnectedState();
      return false;
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
    if (!_isSignedIn) {
      _syncStatus = CloudSyncStatus.offline;
      notifyListeners();
      return false;
    }

    _syncStatus = CloudSyncStatus.syncing;
    notifyListeners();

    try {
      if (!isAccountSwitch) {
        final fetchedId = await _client.getPlayerID();
        if (fetchedId != null && fetchedId.trim().isNotEmpty) {
          final resolvedId = fetchedId.trim();
          final previousPlayerId = _lastPlayerID ?? storage.lastPlayerId;
          if (previousPlayerId != null && previousPlayerId != resolvedId) {
            isAccountSwitch = true;
            _playerID = resolvedId;
            _lastPlayerID = resolvedId;
            await storage.setLastPlayerId(resolvedId);
            final fetchedName = await _client.getPlayerName();
            if (fetchedName != null && fetchedName.trim().isNotEmpty) {
              _playerName = fetchedName.trim();
            }
            await storage.clearGameplayProgress(includeSettings: true);
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
        if (cloudData != null &&
            cloudData.hasClaimedQaBonus &&
            !storage.hasClaimedQaBonus) {
          await storage.setHasClaimedQaBonus(true);
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

      _syncStatus = CloudSyncStatus.synced;
      notifyListeners();
      return restoredFromCloud;
    } catch (_) {
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
        _syncStatus =
            saveRes != null ? CloudSyncStatus.synced : CloudSyncStatus.offline;
      } catch (_) {
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
    if (!_isSignedIn) return false;
    if (!isQaTester(playerId: _playerID, playerName: _playerName)) {
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

    await storage.setAllOrbs(
      fire: storage.fireOrbs + qaBonusOrbs,
      water: storage.waterOrbs + qaBonusOrbs,
      wood: storage.woodOrbs + qaBonusOrbs,
      earth: storage.earthOrbs + qaBonusOrbs,
      metal: storage.metalOrbs + qaBonusOrbs,
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
    if (!_isSignedIn) {
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
      if (result != null) {
        _syncStatus = CloudSyncStatus.synced;
        notifyListeners();
        return true;
      } else {
        _syncStatus = CloudSyncStatus.offline;
        notifyListeners();
        return false;
      }
    } catch (_) {
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

