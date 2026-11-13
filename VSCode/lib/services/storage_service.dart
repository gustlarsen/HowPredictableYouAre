import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/move.dart';

class StorageService {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Currency & Scores
  int get diamonds => _prefs.getInt('diamonds') ?? 0;
  Future<void> setDiamonds(int val) => _prefs.setInt('diamonds', val);

  // Last Signed-In Google Play Games Player ID
  String? get lastPlayerId => _prefs.getString('last_player_id');
  Future<void> setLastPlayerId(String? id) {
    if (id == null) {
      return _prefs.remove('last_player_id');
    }
    return _prefs.setString('last_player_id', id);
  }

  int get userScore => _prefs.getInt('userScore') ?? 0;
  Future<void> setUserScore(int val) => _prefs.setInt('userScore', val);

  int get pcScore => _prefs.getInt('pcScore') ?? 0;
  Future<void> setPcScore(int val) => _prefs.setInt('pcScore', val);

  int get total => _prefs.getInt('total') ?? 0;
  Future<void> setTotal(int val) => _prefs.setInt('total', val);

  // Settings
  bool get darkMode => _prefs.getBool('darkMode') ?? true;
  Future<void> setDarkMode(bool val) => _prefs.setBool('darkMode', val);

  bool get soundEnabled => _prefs.getBool('soundEnabled') ?? true;
  Future<void> setSoundEnabled(bool val) => _prefs.setBool('soundEnabled', val);

  bool get musicEnabled => _prefs.getBool('musicEnabled') ?? true;
  Future<void> setMusicEnabled(bool val) => _prefs.setBool('musicEnabled', val);

  bool get vibrationEnabled => _prefs.getBool('vibrationEnabled') ?? true;
  Future<void> setVibrationEnabled(bool val) =>
      _prefs.setBool('vibrationEnabled', val);

  bool get animationsEnabled => _prefs.getBool('animationsEnabled') ?? true;
  Future<void> setAnimationsEnabled(bool val) =>
      _prefs.setBool('animationsEnabled', val);

  String get language => _prefs.getString('language') ?? 'en';
  Future<void> setLanguage(String val) => _prefs.setString('language', val);

  // Unlocks (Purchased in shop)
  bool get unlockedReset => _prefs.getBool('unlockedReset') ?? false;
  Future<void> setUnlockedReset(bool val) =>
      _prefs.setBool('unlockedReset', val);

  bool get unlockedPredictability =>
      _prefs.getBool('unlockedPredictability') ?? false;
  Future<void> setUnlockedPredictability(bool val) =>
      _prefs.setBool('unlockedPredictability', val);

  bool get unlockedRandom => _prefs.getBool('unlockedRandom') ?? false;
  Future<void> setUnlockedRandom(bool val) =>
      _prefs.setBool('unlockedRandom', val);

  bool get unlockedAlgorithm => _prefs.getBool('unlockedAlgorithm') ?? false;
  Future<void> setUnlockedAlgorithm(bool val) =>
      _prefs.setBool('unlockedAlgorithm', val);

  bool get unlockedNewHands => _prefs.getBool('unlockedNewHands') ?? false;
  Future<void> setUnlockedNewHands(bool val) =>
      _prefs.setBool('unlockedNewHands', val);

  bool get unlockedYourPrediction =>
      _prefs.getBool('unlockedYourPrediction') ?? false;
  Future<void> setUnlockedYourPrediction(bool val) =>
      _prefs.setBool('unlockedYourPrediction', val);

  bool get unlockedNextMove => _prefs.getBool('unlockedNextMove') ?? false;
  Future<void> setUnlockedNextMove(bool val) =>
      _prefs.setBool('unlockedNextMove', val);

  bool get unlockedSuggestion => _prefs.getBool('unlockedSuggestion') ?? false;
  Future<void> setUnlockedSuggestion(bool val) =>
      _prefs.setBool('unlockedSuggestion', val);

  bool get unlockedAds => _prefs.getBool('unlockedAds') ?? false;
  Future<void> setUnlockedAds(bool val) => _prefs.setBool('unlockedAds', val);

  bool get unlockedCrystalBall =>
      _prefs.getBool('unlockedCrystalBall') ?? false;
  Future<void> setUnlockedCrystalBall(bool val) =>
      _prefs.setBool('unlockedCrystalBall', val);

  bool get unlockedCrystalBallPlus =>
      _prefs.getBool('unlockedCrystalBallPlus') ?? false;
  Future<void> setUnlockedCrystalBallPlus(bool val) =>
      _prefs.setBool('unlockedCrystalBallPlus', val);

  // Feature Active Toggles
  bool get showCrystalBall => _prefs.getBool('showCrystalBall') ?? false;
  Future<void> setShowCrystalBall(bool val) =>
      _prefs.setBool('showCrystalBall', val);

  bool get showCrystalBallPlus =>
      _prefs.getBool('showCrystalBallPlus') ?? false;
  Future<void> setShowCrystalBallPlus(bool val) =>
      _prefs.setBool('showCrystalBallPlus', val);

  bool get crystalBallPlusSavedState =>
      _prefs.getBool('crystalBallPlusSavedState') ?? showCrystalBallPlus;
  Future<void> setCrystalBallPlusSavedState(bool val) =>
      _prefs.setBool('crystalBallPlusSavedState', val);
  bool get showPredictability =>
      _prefs.getBool('showPredictability') ?? false;
  Future<void> setShowPredictability(bool val) =>
      _prefs.setBool('showPredictability', val);

  bool get showAlgorithm => _prefs.getBool('showAlgorithm') ?? false;
  Future<void> setShowAlgorithm(bool val) =>
      _prefs.setBool('showAlgorithm', val);

  bool get showYourPrediction =>
      _prefs.getBool('showYourPrediction') ?? false;
  Future<void> setShowYourPrediction(bool val) =>
      _prefs.setBool('showYourPrediction', val);

  bool get showNextMove => _prefs.getBool('showNextMove') ?? false;
  Future<void> setShowNextMove(bool val) => _prefs.setBool('showNextMove', val);

  bool get showSuggestion => _prefs.getBool('showSuggestion') ?? false;
  Future<void> setShowSuggestion(bool val) =>
      _prefs.setBool('showSuggestion', val);

  bool get showNewHands => _prefs.getBool('showNewHands') ?? false;
  Future<void> setShowNewHands(bool val) => _prefs.setBool('showNewHands', val);

  bool get showRandom => _prefs.getBool('showRandom') ?? false;
  Future<void> setShowRandom(bool val) => _prefs.setBool('showRandom', val);

  bool get showReset => _prefs.getBool('showReset') ?? false;
  Future<void> setShowReset(bool val) => _prefs.setBool('showReset', val);

  // Story Cutscene Persistence Flags
  bool get hasSeenStoryIntro =>
      _prefs.getBool('has_seen_story_intro') ?? false;
  Future<void> setHasSeenStoryIntro(bool val) =>
      _prefs.setBool('has_seen_story_intro', val);

  bool get hasSeenStoryReset =>
      _prefs.getBool('has_seen_story_reset') ?? false;
  Future<void> setHasSeenStoryReset(bool val) =>
      _prefs.setBool('has_seen_story_reset', val);

  bool get hasSeenStoryPredictability =>
      _prefs.getBool('has_seen_story_predictability') ?? false;
  Future<void> setHasSeenStoryPredictability(bool val) =>
      _prefs.setBool('has_seen_story_predictability', val);

  bool get hasSeenStoryRandom =>
      _prefs.getBool('has_seen_story_random') ?? false;
  Future<void> setHasSeenStoryRandom(bool val) =>
      _prefs.setBool('has_seen_story_random', val);

  bool get hasSeenStoryAlgorithm =>
      _prefs.getBool('has_seen_story_algorithm') ?? false;
  Future<void> setHasSeenStoryAlgorithm(bool val) =>
      _prefs.setBool('has_seen_story_algorithm', val);

  bool get hasSeenStoryYourPrediction =>
      _prefs.getBool('has_seen_story_your_prediction') ?? false;
  Future<void> setHasSeenStoryYourPrediction(bool val) =>
      _prefs.setBool('has_seen_story_your_prediction', val);

  bool get hasSeenStoryPcNextMove =>
      _prefs.getBool('has_seen_story_pc_next_move') ?? false;
  Future<void> setHasSeenStoryPcNextMove(bool val) =>
      _prefs.setBool('has_seen_story_pc_next_move', val);

  bool get hasSeenStorySuggestion =>
      _prefs.getBool('has_seen_story_suggestion') ?? false;
  Future<void> setHasSeenStorySuggestion(bool val) =>
      _prefs.setBool('has_seen_story_suggestion', val);

  bool get hasSeenStoryCrystalBall =>
      _prefs.getBool('has_seen_story_crystal_ball') ?? false;
  Future<void> setHasSeenStoryCrystalBall(bool val) =>
      _prefs.setBool('has_seen_story_crystal_ball', val);

  bool hasSeenStory(String prefsKey) => _prefs.getBool(prefsKey) ?? false;
  Future<void> setHasSeenStory(String prefsKey, bool val) =>
      _prefs.setBool(prefsKey, val);

  // Last Played Hands Persistence
  HandMove? get lastUserMove {
    final id = _prefs.getInt('last_user_move');
    if (id == null) return null;
    for (final move in HandMove.values) {
      if (move.id == id) return move;
    }
    return null;
  }

  Future<void> setLastUserMove(HandMove? move) {
    if (move == null) {
      return _prefs.remove('last_user_move');
    }
    return _prefs.setInt('last_user_move', move.id);
  }

  HandMove? get lastComputerMove {
    final id = _prefs.getInt('last_computer_move');
    if (id == null) return null;
    for (final move in HandMove.values) {
      if (move.id == id) return move;
    }
    return null;
  }

  Future<void> setLastComputerMove(HandMove? move) {
    if (move == null) {
      return _prefs.remove('last_computer_move');
    }
    return _prefs.setInt('last_computer_move', move.id);
  }

  // Markov Matrix Persistence
  List<List<int>>? getMarkovMatrix(int size) {
    final str = _prefs.getString('markov_matrix_$size');
    if (str == null) return null;
    try {
      final List<dynamic> decoded = json.decode(str);
      return decoded
          .map((row) => (row as List).map((v) => v as int).toList())
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> setMarkovMatrix(List<List<int>> matrix) {
    final size = matrix.length;
    return _prefs.setString('markov_matrix_$size', json.encode(matrix));
  }

  Future<void> removeMarkovMatrix(int size) {
    return _prefs.remove('markov_matrix_$size');
  }

  Future<void> clearGameStats() {
    return Future.wait([
      setUserScore(0),
      setPcScore(0),
      setTotal(0),
      _prefs.remove('last_user_move'),
      _prefs.remove('last_computer_move'),
      _prefs.remove('markov_matrix_3'),
      _prefs.remove('markov_matrix_5'),
    ]);
  }

  /// Resets UI settings (language, dark mode, sound, music, vibration, animations)
  /// back to their default values.
  Future<void> resetSettingsToDefault() {
    return Future.wait([
      setLanguage('en'),
      setDarkMode(true),
      setSoundEnabled(true),
      setMusicEnabled(true),
      setVibrationEnabled(true),
      setAnimationsEnabled(true),
    ]);
  }

  /// Wipes all local gameplay progression (diamonds, scores, shop unlocks,
  /// active toggles, story chapter flags, last moves, and Markov matrices).
  /// When [includeSettings] is true (e.g., on multi-account switch), also resets
  /// UI settings back to defaults so settings are isolated per account.
  Future<void> clearGameplayProgress({bool includeSettings = false}) {
    return Future.wait([
      if (includeSettings) resetSettingsToDefault(),
      setDiamonds(0),
      setUserScore(0),
      setPcScore(0),
      setTotal(0),
      setUnlockedReset(false),
      setUnlockedPredictability(false),
      setUnlockedRandom(false),
      setUnlockedAlgorithm(false),
      setUnlockedNewHands(false),
      setUnlockedYourPrediction(false),
      setUnlockedNextMove(false),
      setUnlockedSuggestion(false),
      setUnlockedAds(false),
      setUnlockedCrystalBall(false),
      setUnlockedCrystalBallPlus(false),
      setShowReset(false),
      setShowPredictability(false),
      setShowRandom(false),
      setShowAlgorithm(false),
      setShowNewHands(false),
      setShowYourPrediction(false),
      setShowNextMove(false),
      setShowSuggestion(false),
      setShowCrystalBall(false),
      setShowCrystalBallPlus(false),
      setCrystalBallPlusSavedState(false),
      setHasSeenStoryReset(false),
      setHasSeenStoryPredictability(false),
      setHasSeenStoryRandom(false),
      setHasSeenStoryAlgorithm(false),
      setHasSeenStoryYourPrediction(false),
      setHasSeenStoryPcNextMove(false),
      setHasSeenStorySuggestion(false),
      setHasSeenStoryCrystalBall(false),
      _prefs.remove('last_user_move'),
      _prefs.remove('last_computer_move'),
      _prefs.remove('markov_matrix_3'),
      _prefs.remove('markov_matrix_5'),
    ]);
  }
}
