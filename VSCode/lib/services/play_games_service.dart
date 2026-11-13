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
  final int diamonds;
  final int userScore;
  final int pcScore;
  final int total;

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
  final bool unlockedCrystalBall;
  final bool unlockedCrystalBallPlus;

  // Feature Active Toggles
  final bool showReset;
  final bool showPredictability;
  final bool showRandom;
  final bool showAlgorithm;
  final bool showNewHands;
  final bool showYourPrediction;
  final bool showNextMove;
  final bool showSuggestion;
  final bool showCrystalBall;
  final bool showCrystalBallPlus;
  final bool crystalBallPlusSavedState;

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
  final int updatedAtMillis;

  const CloudSaveData({
    this.diamonds = 0,
    this.userScore = 0,
    this.pcScore = 0,
    this.total = 0,
    this.unlockedReset = false,
    this.unlockedPredictability = false,
    this.unlockedRandom = false,
    this.unlockedAlgorithm = false,
    this.unlockedNewHands = false,
    this.unlockedYourPrediction = false,
    this.unlockedNextMove = false,
    this.unlockedSuggestion = false,
    this.unlockedAds = false,
    this.unlockedCrystalBall = false,
    this.unlockedCrystalBallPlus = false,
    this.showReset = false,
    this.showPredictability = false,
    this.showRandom = false,
    this.showAlgorithm = false,
    this.showNewHands = false,
    this.showYourPrediction = false,
    this.showNextMove = false,
    this.showSuggestion = false,
    this.showCrystalBall = false,
    this.showCrystalBallPlus = false,
    this.crystalBallPlusSavedState = false,
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
    this.updatedAtMillis = 0,
  });

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
    if (unlockedCrystalBall) count++;
    if (unlockedCrystalBallPlus) count++;
    return count;
  }

  /// Total diamond value of all unlocked shop items in this snapshot.
  int get unlockedShopValue {
    int value = 0;
    if (unlockedReset) value += 100;
    if (unlockedPredictability) value += 150;
    if (unlockedRandom) value += 300;
    if (unlockedAlgorithm) value += 500;
    if (unlockedNewHands) value += 100;
    if (unlockedYourPrediction) value += 1000;
    if (unlockedNextMove) value += 3000;
    if (unlockedSuggestion) value += 5000;
    if (unlockedAds) value += 10000;
    if (unlockedCrystalBall) value += 20000;
    if (unlockedCrystalBallPlus) value += 50000;
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
  /// diamond count than [local].
  bool hasHigherProgressionOrDiamondsThan(CloudSaveData local) {
    if (diamonds > local.diamonds) return true;
    if (unlockedCount > local.unlockedCount) return true;
    if (unlockedShopValue > local.unlockedShopValue) return true;
    if (unlockedCount == local.unlockedCount &&
        diamonds == local.diamonds &&
        (total > local.total ||
            userScore > local.userScore ||
            markovTransitionsCount > local.markovTransitionsCount)) {
      return true;
    }
    return false;
  }

  /// Merges [this] cloud save over [local] when cloud has higher progression or diamonds,
  /// preserving any locally unlocked items or seen story chapters.
  CloudSaveData mergeOverLocal(CloudSaveData local) {
    return CloudSaveData(
      diamonds: diamonds >= local.diamonds ? diamonds : diamonds,
      userScore: userScore,
      pcScore: pcScore,
      total: total,
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
      unlockedCrystalBall: unlockedCrystalBall || local.unlockedCrystalBall,
      unlockedCrystalBallPlus:
          unlockedCrystalBallPlus || local.unlockedCrystalBallPlus,
      showReset: showReset,
      showPredictability: showPredictability,
      showRandom: showRandom,
      showAlgorithm: showAlgorithm,
      showNewHands: showNewHands,
      showYourPrediction: showYourPrediction,
      showNextMove: showNextMove,
      showSuggestion: showSuggestion,
      showCrystalBall: showCrystalBall,
      showCrystalBallPlus: showCrystalBallPlus,
      crystalBallPlusSavedState: crystalBallPlusSavedState,
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
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory CloudSaveData.fromStorage(StorageService storage) {
    return CloudSaveData(
      diamonds: storage.diamonds,
      userScore: storage.userScore,
      pcScore: storage.pcScore,
      total: storage.total,
      unlockedReset: storage.unlockedReset,
      unlockedPredictability: storage.unlockedPredictability,
      unlockedRandom: storage.unlockedRandom,
      unlockedAlgorithm: storage.unlockedAlgorithm,
      unlockedNewHands: storage.unlockedNewHands,
      unlockedYourPrediction: storage.unlockedYourPrediction,
      unlockedNextMove: storage.unlockedNextMove,
      unlockedSuggestion: storage.unlockedSuggestion,
      unlockedAds: storage.unlockedAds,
      unlockedCrystalBall: storage.unlockedCrystalBall,
      unlockedCrystalBallPlus: storage.unlockedCrystalBallPlus,
      showReset: storage.showReset,
      showPredictability: storage.showPredictability,
      showRandom: storage.showRandom,
      showAlgorithm: storage.showAlgorithm,
      showNewHands: storage.showNewHands,
      showYourPrediction: storage.showYourPrediction,
      showNextMove: storage.showNextMove,
      showSuggestion: storage.showSuggestion,
      showCrystalBall: storage.showCrystalBall,
      showCrystalBallPlus: storage.showCrystalBallPlus,
      crystalBallPlusSavedState: storage.crystalBallPlusSavedState,
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
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> applyToStorage(StorageService storage) async {
    await storage.setDiamonds(diamonds);
    await storage.setUserScore(userScore);
    await storage.setPcScore(pcScore);
    await storage.setTotal(total);

    await storage.setUnlockedReset(unlockedReset);
    await storage.setUnlockedPredictability(unlockedPredictability);
    await storage.setUnlockedRandom(unlockedRandom);
    await storage.setUnlockedAlgorithm(unlockedAlgorithm);
    await storage.setUnlockedNewHands(unlockedNewHands);
    await storage.setUnlockedYourPrediction(unlockedYourPrediction);
    await storage.setUnlockedNextMove(unlockedNextMove);
    await storage.setUnlockedSuggestion(unlockedSuggestion);
    await storage.setUnlockedAds(unlockedAds);
    await storage.setUnlockedCrystalBall(unlockedCrystalBall);
    await storage.setUnlockedCrystalBallPlus(unlockedCrystalBallPlus);

    await storage.setShowReset(showReset);
    await storage.setShowPredictability(showPredictability);
    await storage.setShowRandom(showRandom);
    await storage.setShowAlgorithm(showAlgorithm);
    await storage.setShowNewHands(showNewHands);
    await storage.setShowYourPrediction(showYourPrediction);
    await storage.setShowNextMove(showNextMove);
    await storage.setShowSuggestion(showSuggestion);
    await storage.setShowCrystalBall(showCrystalBall);
    await storage.setShowCrystalBallPlus(showCrystalBallPlus);
    await storage.setCrystalBallPlusSavedState(crystalBallPlusSavedState);

    if (hasSeenStoryIntro) {
      await storage.setHasSeenStoryIntro(true);
    }
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
      'version': 1,
      'diamonds': diamonds,
      'userScore': userScore,
      'pcScore': pcScore,
      'total': total,
      'unlockedReset': unlockedReset,
      'unlockedPredictability': unlockedPredictability,
      'unlockedRandom': unlockedRandom,
      'unlockedAlgorithm': unlockedAlgorithm,
      'unlockedNewHands': unlockedNewHands,
      'unlockedYourPrediction': unlockedYourPrediction,
      'unlockedNextMove': unlockedNextMove,
      'unlockedSuggestion': unlockedSuggestion,
      'unlockedAds': unlockedAds,
      'unlockedCrystalBall': unlockedCrystalBall,
      'unlockedCrystalBallPlus': unlockedCrystalBallPlus,
      'showReset': showReset,
      'showPredictability': showPredictability,
      'showRandom': showRandom,
      'showAlgorithm': showAlgorithm,
      'showNewHands': showNewHands,
      'showYourPrediction': showYourPrediction,
      'showNextMove': showNextMove,
      'showSuggestion': showSuggestion,
      'showCrystalBall': showCrystalBall,
      'showCrystalBallPlus': showCrystalBallPlus,
      'crystalBallPlusSavedState': crystalBallPlusSavedState,
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
    return CloudSaveData(
      diamonds: (map['diamonds'] as num?)?.toInt() ?? 0,
      userScore: (map['userScore'] as num?)?.toInt() ?? 0,
      pcScore: (map['pcScore'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      unlockedReset: map['unlockedReset'] as bool? ?? false,
      unlockedPredictability: map['unlockedPredictability'] as bool? ?? false,
      unlockedRandom: map['unlockedRandom'] as bool? ?? false,
      unlockedAlgorithm: map['unlockedAlgorithm'] as bool? ?? false,
      unlockedNewHands: map['unlockedNewHands'] as bool? ?? false,
      unlockedYourPrediction: map['unlockedYourPrediction'] as bool? ?? false,
      unlockedNextMove: map['unlockedNextMove'] as bool? ?? false,
      unlockedSuggestion: map['unlockedSuggestion'] as bool? ?? false,
      unlockedAds: map['unlockedAds'] as bool? ?? false,
      unlockedCrystalBall: map['unlockedCrystalBall'] as bool? ?? false,
      unlockedCrystalBallPlus: map['unlockedCrystalBallPlus'] as bool? ?? false,
      showReset: map['showReset'] as bool? ?? false,
      showPredictability: map['showPredictability'] as bool? ?? false,
      showRandom: map['showRandom'] as bool? ?? false,
      showAlgorithm: map['showAlgorithm'] as bool? ?? false,
      showNewHands: map['showNewHands'] as bool? ?? false,
      showYourPrediction: map['showYourPrediction'] as bool? ?? false,
      showNextMove: map['showNextMove'] as bool? ?? false,
      showSuggestion: map['showSuggestion'] as bool? ?? false,
      showCrystalBall: map['showCrystalBall'] as bool? ?? false,
      showCrystalBallPlus: map['showCrystalBallPlus'] as bool? ?? false,
      crystalBallPlusSavedState:
          map['crystalBallPlusSavedState'] as bool? ?? false,
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

  final StorageService storage;
  final PlayGamesClient _client;

  bool _isSignedIn = false;
  bool _isAuthenticating = false;
  String? _playerName;
  String? _playerID;
  String? _lastPlayerID;
  CloudSyncStatus _syncStatus = CloudSyncStatus.offline;
  VoidCallback? onCloudDataRestored;

  PlayGamesService({
    required this.storage,
    PlayGamesClient? client,
    this.onCloudDataRestored,
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
        await storage.clearGameplayProgress();
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
  /// When [isAccountSwitch] is true, local gameplay progress has already been
  /// wiped for the new playerID, so any existing cloud save for the new playerID
  /// is applied directly (or defaults to 0 if none exists).
  /// Otherwise, merges/restores cloud data over local data ONLY if the cloud save
  /// holds a higher progression state or diamond count; if local data has higher
  /// progression, pushes the local state to cloud.
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
            await storage.clearGameplayProgress();
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
          cloudData.hasHigherProgressionOrDiamondsThan(localData)) {
        final merged = cloudData.mergeOverLocal(localData);
        await merged.applyToStorage(storage);
        restoredFromCloud = true;
        onCloudDataRestored?.call();
      } else if (localData.hasHigherProgressionOrDiamondsThan(
            cloudData ?? const CloudSaveData(),
          )) {
        // Keep local progression and back it up to the cloud
        await _client.saveGame(
          data: localData.toJsonString(),
          name: saveSlotName,
        );
      }

      _syncStatus = CloudSyncStatus.synced;
      notifyListeners();
      return restoredFromCloud;
    } catch (_) {
      if (isAccountSwitch) {
        onCloudDataRestored?.call();
      }
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

