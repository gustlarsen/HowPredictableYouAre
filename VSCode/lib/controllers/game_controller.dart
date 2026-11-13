import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/move.dart';
import '../models/evaluation_tier.dart';
import '../models/story_chapter.dart';
import '../services/markov_engine.dart';
import '../services/storage_service.dart';
import '../services/localization_service.dart';
import '../services/audio_service.dart';
import '../services/play_games_service.dart';

class GameController extends ChangeNotifier {
  final StorageService storage;
  final LocalizationService localization;
  final AudioService audio;
  late final PlayGamesService playGames;

  late MarkovEngine _engine;

  HandMove? currentUserMove;
  HandMove? currentComputerMove;
  HandMove? lastUserMove;

  HandMove? predictedUserMove;
  HandMove? pcNextMove;
  HandMove? suggestedMove;
  HandMove? crystalBallMove;
  HandMove? crystalBallPlusMove;

  List<HandMove> predictedUserMoves = [];
  List<HandMove> pcNextMoves = [];
  List<HandMove> suggestedMoves = [];

  RoundWinner? lastWinner;

  int diamonds = 0;
  int userScore = 0;
  int pcScore = 0;
  int totalRounds = 0;
  int turnCount = 0;

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
  bool unlockedAds = false;
  bool unlockedCrystalBall = false;
  bool unlockedCrystalBallPlus = false;

  // Active toggles
  bool showReset = false;
  bool showPredictability = false;
  bool showRandom = false;
  bool showAlgorithm = false;
  bool showNewHands = false;
  bool showYourPrediction = false;
  bool showNextMove = false;
  bool showSuggestion = false;
  bool showCrystalBall = false;
  bool showCrystalBallPlus = false;
  bool crystalBallPlusSavedState = false;

  bool is100RoundsAlertPending = false;
  bool isGiftAvailable = true;
  Timer? _giftTimer;

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

  GameController({
    required this.storage,
    required this.localization,
    required this.audio,
    PlayGamesService? playGames,
  }) {
    this.playGames = playGames ?? PlayGamesService(storage: storage);
    this.playGames.onCloudDataRestored = _handleCloudDataRestored;
    this.playGames.addListener(_handlePlayGamesUpdate);
    _loadState();
  }

  void _handleCloudDataRestored() {
    _loadState(restartAudio: false);
    notifyListeners();
  }

  void _handlePlayGamesUpdate() {
    notifyListeners();
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      audio.pauseMusic();
    } else if (state == AppLifecycleState.resumed) {
      audio.resumeMusic();
      unawaited(playGames.handleAppResumed());
    }
  }

  void _triggerCloudSave() {
    if (playGames.isSignedIn) {
      unawaited(playGames.saveCloudData());
    }
  }

  void _loadState({bool restartAudio = true}) {
    diamonds = storage.diamonds;
    userScore = storage.userScore;
    pcScore = storage.pcScore;
    totalRounds = storage.total;
    is100RoundsAlertPending = totalRounds >= 100;
    if (totalRounds == 0 && storage.lastUserMove == null) {
      turnCount = 0;
    }

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
    unlockedAds = storage.unlockedAds;
    unlockedCrystalBall = storage.unlockedCrystalBall;
    unlockedCrystalBallPlus = storage.unlockedCrystalBallPlus;

    showReset = storage.showReset;
    showPredictability = storage.showPredictability;
    showRandom = storage.showRandom;
    showAlgorithm = storage.showAlgorithm;
    showNewHands = storage.showNewHands;
    showYourPrediction = storage.showYourPrediction;
    showNextMove = storage.showNextMove;
    showSuggestion = storage.showSuggestion;
    showCrystalBall = storage.showCrystalBall;
    crystalBallPlusSavedState = storage.crystalBallPlusSavedState;
    showCrystalBallPlus =
        showCrystalBall ? storage.showCrystalBallPlus : false;

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

    _engine = MarkovEngine(enableExtendedHands: showNewHands);
    final savedMatrix = storage.getMarkovMatrix(_engine.size);
    if (savedMatrix != null) {
      _engine.setMatrix(savedMatrix);
    }

    currentUserMove = storage.lastUserMove;
    currentComputerMove = storage.lastComputerMove;
    if (!showNewHands) {
      if (currentUserMove == HandMove.lizard ||
          currentUserMove == HandMove.spock) {
        currentUserMove = null;
      }
      if (currentComputerMove == HandMove.lizard ||
          currentComputerMove == HandMove.spock) {
        currentComputerMove = null;
      }
    }
    if (currentUserMove == null || currentComputerMove == null) {
      currentUserMove = null;
      currentComputerMove = null;
      lastWinner = null;
    } else if (currentUserMove == currentComputerMove) {
      lastWinner = RoundWinner.draw;
    } else if (currentUserMove!.beats(currentComputerMove!)) {
      lastWinner = RoundWinner.user;
    } else {
      lastWinner = RoundWinner.computer;
    }
    lastUserMove = currentUserMove;

    _computeNextHints();
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

  double get percentPredict {
    if (totalRounds == 0) return 0.0;
    return (userScore / totalRounds) * 100.0;
  }

  EvaluationTier get evaluationTier {
    final pcPredictPercent =
        totalRounds == 0 ? 0.0 : (pcScore / totalRounds) * 100.0;
    return EvaluationTier.fromPercent(pcPredictPercent, totalRounds);
  }

  void playTurn(HandMove userChoice) {
    if (totalRounds >= 100) {
      is100RoundsAlertPending = true;
      audio.playVibrate();
      notifyListeners();
      return;
    }
    turnCount++;
    currentUserMove = userChoice;

    // AI uses the move already pre-computed before the user chose their hand
    currentComputerMove = crystalBallMove ??
        (!_engine.hasPrediction(lastUserMove)
            ? _engine.getRandomMove()
            : _engine.computeSmartChoice(lastUserMove));

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
    storage.setLastUserMove(currentUserMove);
    storage.setLastComputerMove(currentComputerMove);

    if (lastWinner == RoundWinner.user) {
      _triggerCloudSave();
    }

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
    predictedUserMoves = _engine.predictNextUserMoves(lastUserMove);
    pcNextMoves = _engine.computeSmartChoices(lastUserMove);
    suggestedMoves = _engine.computeSuggestions(pcNextMoves);

    // Pre-decide the exact PC move (Markov counter or random fallback) before the user chooses a hand
    if (!_engine.hasPrediction(lastUserMove)) {
      crystalBallMove = _engine.getRandomMove();
    } else {
      crystalBallMove = _engine.computeSmartChoice(lastUserMove);
    }
    crystalBallPlusMove = _engine.computeSuggestion(crystalBallMove!);

    predictedUserMove = predictedUserMoves.isNotEmpty ? predictedUserMoves.first : null;
    pcNextMove = crystalBallMove;
    suggestedMove = suggestedMoves.isNotEmpty ? suggestedMoves.first : null;
  }

  void resetGame() {
    userScore = 0;
    pcScore = 0;
    totalRounds = 0;
    turnCount = 0;
    currentUserMove = null;
    currentComputerMove = null;
    lastUserMove = null;
    lastWinner = null;
    is100RoundsAlertPending = false;
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
    _triggerCloudSave();
    notifyListeners();
    return true;
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

  bool unlockReset() {
    return purchaseItem(
      cost: 100,
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
    return purchaseItem(
      cost: 150,
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
    return purchaseItem(
      cost: 300,
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
    return purchaseItem(
      cost: 500,
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
    return purchaseItem(
      cost: 100,
      onUnlock: () {
        unlockedNewHands = true;
        showNewHands = false;
        storage.setUnlockedNewHands(true);
        storage.setShowNewHands(false);
      },
    );
  }

  bool unlockYourPrediction() {
    return purchaseItem(
      cost: 1000,
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
    return purchaseItem(
      cost: 3000,
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
    return purchaseItem(
      cost: 5000,
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
    return purchaseItem(
      cost: 10000,
      onUnlock: () {
        unlockedAds = true;
        storage.setUnlockedAds(true);
      },
    );
  }

  bool unlockCrystalBall() {
    return purchaseItem(
      cost: 20000,
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
    return purchaseItem(
      cost: 50000,
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

  /// Gift feature: periodic free diamonds (matching Kodular ButtonGift / Clock1)
  void claimGift() {
    if (!isGiftAvailable) return;
    diamonds += 5;
    storage.setDiamonds(diamonds);
    isGiftAvailable = false;
    audio.playVibrate();
    _triggerCloudSave();
    notifyListeners();

    _giftTimer?.cancel();
    _giftTimer = Timer(const Duration(minutes: 1), () {
      isGiftAvailable = true;
      notifyListeners();
    });
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

  void toggleShowNewHands(bool val) {
    showNewHands = val;
    storage.setShowNewHands(val);
    _engine = MarkovEngine(enableExtendedHands: val);
    resetGame();
    _triggerCloudSave();
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
    _triggerCloudSave();
    notifyListeners();
  }

  @override
  void dispose() {
    _giftTimer?.cancel();
    playGames.removeListener(_handlePlayGamesUpdate);
    super.dispose();
  }
}
