import 'package:flutter/foundation.dart';
import '../models/move.dart';
import '../models/evaluation_tier.dart';
import '../services/markov_engine.dart';
import '../services/storage_service.dart';
import '../services/localization_service.dart';
import '../services/audio_service.dart';

class GameController extends ChangeNotifier {
  final StorageService storage;
  final LocalizationService localization;
  final AudioService audio;

  late MarkovEngine _engine;

  HandMove? currentUserMove;
  HandMove? currentComputerMove;
  HandMove? lastUserMove;

  HandMove? predictedUserMove;
  HandMove? pcNextMove;
  HandMove? suggestedMove;

  RoundWinner? lastWinner;

  int diamonds = 0;
  int userScore = 0;
  int pcScore = 0;
  int totalRounds = 0;

  bool darkMode = true;
  bool soundEnabled = true;
  bool musicEnabled = true;
  bool vibrationEnabled = true;
  bool animationsEnabled = true;

  // Unlocks
  bool unlockedReset = false;
  bool unlockedPredictability = false;
  bool unlockedRandom = false;
  bool unlockedAlgorithm = false;
  bool unlockedNewHands = false;
  bool unlockedYourPrediction = false;
  bool unlockedNextMove = false;
  bool unlockedSuggestion = false;

  // Active toggles
  bool showReset = false;
  bool showPredictability = false;
  bool showRandom = false;
  bool showAlgorithm = false;
  bool showNewHands = false;
  bool showYourPrediction = false;
  bool showNextMove = false;
  bool showSuggestion = false;

  bool is100RoundsAlertPending = false;

  GameController({
    required this.storage,
    required this.localization,
    required this.audio,
  }) {
    _loadState();
  }

  void _loadState() {
    diamonds = storage.diamonds;
    userScore = storage.userScore;
    pcScore = storage.pcScore;
    totalRounds = storage.total;

    darkMode = storage.darkMode;
    soundEnabled = storage.soundEnabled;
    musicEnabled = storage.musicEnabled;
    vibrationEnabled = storage.vibrationEnabled;
    animationsEnabled = storage.animationsEnabled;

    unlockedReset = storage.unlockedReset;
    unlockedPredictability = storage.unlockedPredictability;
    unlockedRandom = storage.unlockedRandom;
    unlockedAlgorithm = storage.unlockedAlgorithm;
    unlockedNewHands = storage.unlockedNewHands;
    unlockedYourPrediction = storage.unlockedYourPrediction;
    unlockedNextMove = storage.unlockedNextMove;
    unlockedSuggestion = storage.unlockedSuggestion;

    showReset = storage.showReset;
    showPredictability = storage.showPredictability;
    showRandom = storage.showRandom;
    showAlgorithm = storage.showAlgorithm;
    showNewHands = storage.showNewHands;
    showYourPrediction = storage.showYourPrediction;
    showNextMove = storage.showNextMove;
    showSuggestion = storage.showSuggestion;

    audio.soundEnabled = soundEnabled;
    audio.musicEnabled = musicEnabled;
    audio.vibrationEnabled = vibrationEnabled;
    if (musicEnabled) {
      audio.startMusic();
    }

    _engine = MarkovEngine(enableExtendedHands: showNewHands);
    final savedMatrix = storage.getMarkovMatrix(_engine.size);
    if (savedMatrix != null) {
      _engine.setMatrix(savedMatrix);
    }

    _computeNextHints();
  }

  MarkovEngine get engine => _engine;

  double get percentPredict {
    if (totalRounds == 0) return 0.0;
    return (pcScore / totalRounds) * 100.0;
  }

  EvaluationTier get evaluationTier {
    return EvaluationTier.fromPercent(percentPredict, totalRounds);
  }

  void playTurn(HandMove userChoice) {
    currentUserMove = userChoice;

    // AI selects its move: if turn 1 or no data yet -> random, otherwise smart choice
    if (totalRounds == 0 || lastUserMove == null) {
      currentComputerMove = _engine.getRandomMove();
    } else {
      currentComputerMove = _engine.computeSmartChoice(lastUserMove);
    }

    // Determine round outcome
    if (currentUserMove == currentComputerMove) {
      lastWinner = RoundWinner.draw;
      audio.playDraw();
    } else if (currentUserMove!.beats(currentComputerMove!)) {
      lastWinner = RoundWinner.user;
      userScore += 1;
      diamonds += 1;
      storage.setUserScore(userScore);
      storage.setDiamonds(diamonds);
      audio.playWin();
    } else {
      lastWinner = RoundWinner.computer;
      pcScore += 1;
      storage.setPcScore(pcScore);
      audio.playDefeat();
    }

    totalRounds = userScore + pcScore;
    storage.setTotal(totalRounds);

    // Record transition into Markov matrix
    _engine.recordTransition(lastUserMove, currentUserMove!);
    storage.setMarkovMatrix(_engine.matrix);
    lastUserMove = currentUserMove;

    if (totalRounds == 100) {
      is100RoundsAlertPending = true;
    }

    _computeNextHints();
    notifyListeners();
  }

  void playRandom() {
    final randMove = _engine.getRandomMove();
    playTurn(randMove);
  }

  void _computeNextHints() {
    predictedUserMove = _engine.predictNextUserMove(lastUserMove);
    pcNextMove = _engine.computeSmartChoice(lastUserMove);
    if (pcNextMove != null) {
      suggestedMove = _engine.computeSuggestion(pcNextMove!);
    }
  }

  void resetGame() {
    userScore = 0;
    pcScore = 0;
    totalRounds = 0;
    currentUserMove = null;
    currentComputerMove = null;
    lastUserMove = null;
    lastWinner = null;
    _engine.reset();

    storage.clearGameStats();
    _computeNextHints();
    notifyListeners();
  }

  // Shop Purchases
  bool purchaseItem({required int cost, required VoidCallback onUnlock}) {
    if (diamonds < cost) {
      audio.playVibrate();
      return false;
    }

    diamonds -= cost;
    storage.setDiamonds(diamonds);
    onUnlock();
    notifyListeners();
    return true;
  }

  void unlockReset() {
    purchaseItem(
      cost: 100,
      onUnlock: () {
        unlockedReset = true;
        showReset = true;
        storage.setUnlockedReset(true);
        storage.setShowReset(true);
      },
    );
  }

  void unlockPredictability() {
    purchaseItem(
      cost: 150,
      onUnlock: () {
        unlockedPredictability = true;
        showPredictability = true;
        storage.setUnlockedPredictability(true);
        storage.setShowPredictability(true);
      },
    );
  }

  void unlockRandom() {
    purchaseItem(
      cost: 300,
      onUnlock: () {
        unlockedRandom = true;
        showRandom = true;
        storage.setUnlockedRandom(true);
        storage.setShowRandom(true);
      },
    );
  }

  void unlockAlgorithm() {
    purchaseItem(
      cost: 500,
      onUnlock: () {
        unlockedAlgorithm = true;
        showAlgorithm = true;
        storage.setUnlockedAlgorithm(true);
        storage.setShowAlgorithm(true);
      },
    );
  }

  void unlockNewHands() {
    purchaseItem(
      cost: 100,
      onUnlock: () {
        unlockedNewHands = true;
        showNewHands = true;
        storage.setUnlockedNewHands(true);
        storage.setShowNewHands(true);
        _engine = MarkovEngine(enableExtendedHands: true);
      },
    );
  }

  void unlockYourPrediction() {
    purchaseItem(
      cost: 1000,
      onUnlock: () {
        unlockedYourPrediction = true;
        showYourPrediction = true;
        storage.setUnlockedYourPrediction(true);
        storage.setShowYourPrediction(true);
      },
    );
  }

  void unlockNextMove() {
    purchaseItem(
      cost: 3000,
      onUnlock: () {
        unlockedNextMove = true;
        showNextMove = true;
        storage.setUnlockedNextMove(true);
        storage.setShowNextMove(true);
      },
    );
  }

  void unlockSuggestion() {
    purchaseItem(
      cost: 5000,
      onUnlock: () {
        unlockedSuggestion = true;
        showSuggestion = true;
        storage.setUnlockedSuggestion(true);
        storage.setShowSuggestion(true);
      },
    );
  }

  // Toggles for active unlocks
  void toggleShowReset(bool val) {
    showReset = val;
    storage.setShowReset(val);
    notifyListeners();
  }

  void toggleShowPredictability(bool val) {
    showPredictability = val;
    storage.setShowPredictability(val);
    notifyListeners();
  }

  void toggleShowRandom(bool val) {
    showRandom = val;
    storage.setShowRandom(val);
    notifyListeners();
  }

  void toggleShowAlgorithm(bool val) {
    showAlgorithm = val;
    storage.setShowAlgorithm(val);
    notifyListeners();
  }

  void toggleShowYourPrediction(bool val) {
    showYourPrediction = val;
    storage.setShowYourPrediction(val);
    notifyListeners();
  }

  void toggleShowNextMove(bool val) {
    showNextMove = val;
    storage.setShowNextMove(val);
    notifyListeners();
  }

  void toggleShowSuggestion(bool val) {
    showSuggestion = val;
    storage.setShowSuggestion(val);
    notifyListeners();
  }

  void toggleShowNewHands(bool val) {
    showNewHands = val;
    storage.setShowNewHands(val);
    _engine = MarkovEngine(enableExtendedHands: val);
    notifyListeners();
  }

  // Settings
  void toggleDarkMode(bool val) {
    darkMode = val;
    storage.setDarkMode(val);
    notifyListeners();
  }

  void toggleSound() {
    soundEnabled = !soundEnabled;
    storage.setSoundEnabled(soundEnabled);
    audio.soundEnabled = soundEnabled;
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
    notifyListeners();
  }

  void toggleVibration(bool val) {
    vibrationEnabled = val;
    storage.setVibrationEnabled(vibrationEnabled);
    audio.vibrationEnabled = vibrationEnabled;
    notifyListeners();
  }

  void toggleAnimations(bool val) {
    animationsEnabled = val;
    storage.setAnimationsEnabled(val);
    notifyListeners();
  }

  void setLanguage(String lang) {
    localization.setLanguage(lang);
    storage.setLanguage(lang);
    notifyListeners();
  }

  void addFreeDiamonds(int amount) {
    diamonds += amount;
    storage.setDiamonds(diamonds);
    notifyListeners();
  }
}
