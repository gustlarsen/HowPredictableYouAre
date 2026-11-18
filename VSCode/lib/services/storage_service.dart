import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/move.dart';

class StorageService {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _migrateLegacyDiamondsIfNeeded();
  }

  /// Migrates legacy `diamonds` balance once into Elemental Orbs if the player
  /// had legacy diamonds > 0 and all 5 elemental orb counts are currently 0.
  Future<void> _migrateLegacyDiamondsIfNeeded() async {
    final legacy = _prefs.getInt('diamonds') ?? 0;
    if (legacy > 0 && totalOrbs == 0) {
      await setAllOrbs(
        fire: legacy,
        water: legacy,
        wood: legacy,
        earth: legacy,
        metal: legacy,
      );
      await _prefs.setInt('diamonds', 0);
      await _prefs.setBool('legacy_diamonds_migrated', true);
    }
  }

  // Elemental Orbs Inventory (Fire, Water, Wood, Earth, Metal)
  int get fireOrbs => _prefs.getInt('orbs_fire') ?? 0;
  Future<void> setFireOrbs(int val) => _prefs.setInt('orbs_fire', val);

  int get waterOrbs => _prefs.getInt('orbs_water') ?? 0;
  Future<void> setWaterOrbs(int val) => _prefs.setInt('orbs_water', val);

  int get woodOrbs => _prefs.getInt('orbs_wood') ?? 0;
  Future<void> setWoodOrbs(int val) => _prefs.setInt('orbs_wood', val);

  int get earthOrbs => _prefs.getInt('orbs_earth') ?? 0;
  Future<void> setEarthOrbs(int val) => _prefs.setInt('orbs_earth', val);

  int get metalOrbs => _prefs.getInt('orbs_metal') ?? 0;
  Future<void> setMetalOrbs(int val) => _prefs.setInt('orbs_metal', val);

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

  Future<void> setOrbsFor(HandMove move, int val) {
    switch (move) {
      case HandMove.rock:
        return setFireOrbs(val);
      case HandMove.paper:
        return setWaterOrbs(val);
      case HandMove.scissors:
        return setWoodOrbs(val);
      case HandMove.lizard:
        return setEarthOrbs(val);
      case HandMove.spock:
        return setMetalOrbs(val);
    }
  }

  Future<void> setAllOrbs({
    required int fire,
    required int water,
    required int wood,
    required int earth,
    required int metal,
  }) {
    return Future.wait([
      setFireOrbs(fire),
      setWaterOrbs(water),
      setWoodOrbs(wood),
      setEarthOrbs(earth),
      setMetalOrbs(metal),
    ]);
  }

  // Legacy diamond key accessor (used only for one-time legacy save migration)
  int get legacyDiamonds => _prefs.getInt('diamonds') ?? 0;
  Future<void> clearLegacyDiamonds() => _prefs.setInt('diamonds', 0);

  // QA Tester Bonus Persistence
  bool get hasClaimedQaBonus => _prefs.getBool('hasClaimedQaBonus') ?? false;
  Future<void> setHasClaimedQaBonus(bool val) =>
      _prefs.setBool('hasClaimedQaBonus', val);

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

  // RPG Hand HP (0 - 100)
  int get userHp => _prefs.getInt('userHp') ?? 100;
  int? get userHpRaw => _prefs.getInt('userHp');
  Future<void> setUserHp(int val) => _prefs.setInt('userHp', val);

  int get pcHp => _prefs.getInt('pcHp') ?? 100;
  int? get pcHpRaw => _prefs.getInt('pcHp');
  Future<void> setPcHp(int val) => _prefs.setInt('pcHp', val);

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

  bool get unlockedAds =>
      (_prefs.getBool('unlockedAds') ?? false) ||
      (_prefs.getBool('unlock_remove_ads') ?? false);
  Future<void> setUnlockedAds(bool val) async {
    await _prefs.setBool('unlockedAds', val);
    await _prefs.setBool('unlock_remove_ads', val);
  }

  bool get removeAdsEnabled =>
      _prefs.getBool('removeAdsEnabled') ?? unlockedAds;
  Future<void> setRemoveAdsEnabled(bool val) =>
      _prefs.setBool('removeAdsEnabled', val);

  bool get unlockedNewSkin => _prefs.getBool('unlockedNewSkin') ?? false;
  Future<void> setUnlockedNewSkin(bool val) =>
      _prefs.setBool('unlockedNewSkin', val);

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

  bool get showNewSkin => _prefs.getBool('showNewSkin') ?? false;
  Future<void> setShowNewSkin(bool val) => _prefs.setBool('showNewSkin', val);

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
      setUserHp(100),
      setPcHp(100),
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

  /// Wipes all local gameplay progression (elemental orbs, scores, shop unlocks,
  /// active toggles, story chapter flags, last moves, and Markov matrices).
  /// When [includeSettings] is true (e.g., on multi-account switch), also resets
  /// UI settings back to defaults so settings are isolated per account.
  Future<void> clearGameplayProgress({bool includeSettings = false}) {
    return Future.wait([
      if (includeSettings) resetSettingsToDefault(),
      setAllOrbs(fire: 0, water: 0, wood: 0, earth: 0, metal: 0),
      clearLegacyDiamonds(),
      setHasClaimedQaBonus(false),
      setUserScore(0),
      setPcScore(0),
      setTotal(0),
      setUserHp(100),
      setPcHp(100),
      setUnlockedReset(false),
      setUnlockedPredictability(false),
      setUnlockedRandom(false),
      setUnlockedAlgorithm(false),
      setUnlockedNewHands(false),
      setUnlockedYourPrediction(false),
      setUnlockedNextMove(false),
      setUnlockedSuggestion(false),
      setUnlockedAds(false),
      setRemoveAdsEnabled(false),
      setUnlockedNewSkin(false),
      setUnlockedCrystalBall(false),
      setUnlockedCrystalBallPlus(false),
      setShowReset(false),
      setShowPredictability(false),
      setShowRandom(false),
      setShowAlgorithm(false),
      setShowNewHands(false),
      setShowNewSkin(false),
      setShowYourPrediction(false),
      setShowNextMove(false),
      setShowSuggestion(false),
      setShowCrystalBall(false),
      setShowCrystalBallPlus(false),
      setCrystalBallPlusSavedState(false),
      setHasSeenStoryIntro(false),
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
