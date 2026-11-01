import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Currency & Scores
  int get diamonds => _prefs.getInt('diamonds') ?? 0;
  Future<void> setDiamonds(int val) => _prefs.setInt('diamonds', val);

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

  bool get unlockedSourceCode => _prefs.getBool('unlockedSourceCode') ?? false;
  Future<void> setUnlockedSourceCode(bool val) =>
      _prefs.setBool('unlockedSourceCode', val);

  // Feature Active Toggles
  bool get showPredictability =>
      _prefs.getBool('showPredictability') ?? unlockedPredictability;
  Future<void> setShowPredictability(bool val) =>
      _prefs.setBool('showPredictability', val);

  bool get showAlgorithm =>
      _prefs.getBool('showAlgorithm') ?? unlockedAlgorithm;
  Future<void> setShowAlgorithm(bool val) =>
      _prefs.setBool('showAlgorithm', val);

  bool get showYourPrediction =>
      _prefs.getBool('showYourPrediction') ?? unlockedYourPrediction;
  Future<void> setShowYourPrediction(bool val) =>
      _prefs.setBool('showYourPrediction', val);

  bool get showNextMove => _prefs.getBool('showNextMove') ?? unlockedNextMove;
  Future<void> setShowNextMove(bool val) => _prefs.setBool('showNextMove', val);

  bool get showSuggestion =>
      _prefs.getBool('showSuggestion') ?? unlockedSuggestion;
  Future<void> setShowSuggestion(bool val) =>
      _prefs.setBool('showSuggestion', val);

  bool get showNewHands => _prefs.getBool('showNewHands') ?? unlockedNewHands;
  Future<void> setShowNewHands(bool val) => _prefs.setBool('showNewHands', val);

  bool get showRandom => _prefs.getBool('showRandom') ?? unlockedRandom;
  Future<void> setShowRandom(bool val) => _prefs.setBool('showRandom', val);

  bool get showReset => _prefs.getBool('showReset') ?? unlockedReset;
  Future<void> setShowReset(bool val) => _prefs.setBool('showReset', val);

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

  Future<void> clearGameStats() async {
    await setUserScore(0);
    await setPcScore(0);
    await setTotal(0);
    await _prefs.remove('markov_matrix_3');
    await _prefs.remove('markov_matrix_5');
  }
}
