import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/localization_service.dart';
import '../services/markov_engine.dart';
import '../services/storage_service.dart';

enum ScreenViewMode {
  normal,
  settings,
  shoppingCart,
  achievements,
}

enum RoundOutcome {
  none,
  userWin,
  pcWin,
  draw,
}

class GameController extends ChangeNotifier {
  final StorageService storage;
  final LocalizationService localization;
  final MarkovEngine markovEngine;
  final AudioService audio;

  // Persistent state matching Tiny_DB1 variables in Screen1.bky
  int ads = 0;
  int algorithm = 0;
  int diamonds = 0;
  int newHands = 0;
  int nextMove = 0;
  int predictability = 0;
  int random = 0;
  int reset = 0;
  int sourceCode = 0;
  int sugestion = 0;
  int yourPrediction = 0;

  int total = 0;
  double percentPredict = 0.0;
  int pcScore = 0;
  int userScore = 0;

  String pcNextMove = 'Random';
  String yourPredictionValue = 'Random';
  String sugestionValue = 'Random';
  String winner = 'NONE';

  int currentComputerChoice = MarkovEngine.none; // 4
  int currentUserChoice = MarkovEngine.none; // 4
  int lastUserChoice = 0;

  int startup = 0;
  int darkMode = 1;
  String language = 'en';
  int music = 1;
  int vibration = 1;
  int animation = 1;

  // UI & Navigation state matching Screen1.scm
  ScreenViewMode viewMode = ScreenViewMode.normal;
  String backgroundImageAsset = 'assets/Splash.png';

  bool buttonSecretVisible = false;
  bool buttonGiftVisible = false;
  bool buttonHelpVisible = true;
  bool buttonAchievementsVisible = true;
  bool buttonShopVisible = true;
  bool buttonSettingsVisible = true;
  bool buttonSettingsBackVisible = false;

  // Google Play Games player info placeholders (Table_Arrangement3)
  String gamesName = '-';
  String gamesId = '-';
  String gamesLevel = '-';
  String gamesXp = '-';

  // Animation & Dialog triggers
  RoundOutcome lastRoundOutcome = RoundOutcome.none;
  int animationTick = 0;
  bool show100RoundDialog = false;
  String label100TurnText = 'You Lose!!!';
  String labelEmojiWinLoseText = '🙁';
  String? alertMessage;

  Timer? _giftTimer;

  static const List<String> imageUserChoices = [
    'assets/RockL.png',
    'assets/PaperL.png',
    'assets/ScissorL.png',
    'assets/RockL.png',
  ];

  static const List<String> imagePCChoices = [
    'assets/RockR.png',
    'assets/PaperR.png',
    'assets/ScissorR.png',
    'assets/RockR.png',
  ];

  static const List<String> emojis = ['👊', '🖐', '✌', '🦎', '🖖'];

  GameController({
    required this.storage,
    required this.localization,
    required this.markovEngine,
    required this.audio,
  });

  /// Helper to fetch localized string `_string<index>` for current `language`.
  String tr(int stringIndex, [String fallback = '']) {
    return localization.getString(language, stringIndex, fallback);
  }

  List<String> get choicesInWords => [
        tr(17, 'ROCK'),
        tr(18, 'PAPER'),
        tr(19, 'SCISSORS'),
        tr(20, 'NONE'),
      ];

  String choiceWord(int choiceOneBased) {
    final words = choicesInWords;
    if (choiceOneBased >= 1 && choiceOneBased <= words.length) {
      return words[choiceOneBased - 1];
    }
    return words[3];
  }

  String get userChoiceImageAsset {
    if (currentUserChoice >= 1 && currentUserChoice <= imageUserChoices.length) {
      return imageUserChoices[currentUserChoice - 1];
    }
    return imageUserChoices[3];
  }

  String get compChoiceImageAsset {
    if (currentComputerChoice >= 1 &&
        currentComputerChoice <= imagePCChoices.length) {
      return imagePCChoices[currentComputerChoice - 1];
    }
    return imagePCChoices[3];
  }

  String get userChoiceLabelText => choiceWord(currentUserChoice);
  String get compChoiceLabelText => choiceWord(currentComputerChoice);

  Color get textColor => darkMode == 1 ? Colors.white : Colors.black;
  Color get screenBackgroundColor =>
      darkMode == 1 ? Colors.black : Colors.white;

  bool get isLabel100RoundsVisible => total < 100;

  String get evaluationText {
    if (total < 100) {
      return tr(3, 'Under Evaluation');
    }
    if (percentPredict == 0) {
      return tr(21, 'Perfect Predictor');
    } else if (percentPredict < 5) {
      return tr(22, 'Very Good Predictor');
    } else if (percentPredict < 15) {
      return tr(23, 'Good Predictor');
    } else if (percentPredict < 25) {
      return tr(24, 'Bad Predictor');
    } else if (percentPredict < 35) {
      return tr(25, 'Are you trying to predict me ?');
    } else if (percentPredict < 45) {
      return tr(26, 'Unpredictable');
    } else if (percentPredict < 50) {
      return tr(27, 'Hardly Predictable');
    } else if (percentPredict < 60) {
      return tr(28, 'Slightly Predictable');
    } else if (percentPredict < 70) {
      return tr(29, 'Reasonably Predictable');
    } else if (percentPredict < 80) {
      return tr(30, 'Sometimes Predictable');
    } else if (percentPredict < 90) {
      return tr(31, 'Often Predictable');
    } else if (percentPredict < 95) {
      return tr(32, 'Very Predictable');
    } else {
      return tr(33, 'Totally Predictable');
    }
  }

  String get formattedPercentPredict {
    if (percentPredict == percentPredict.roundToDouble()) {
      return percentPredict.toInt().toString();
    }
    return percentPredict.toStringAsFixed(1);
  }

  String get spinnerLanguageSelection =>
      LocalizationService.languageToSpinnerSelection(language);

  /// Exact port of `Screen1.Initialize`
  Future<void> initialize({String? deviceLanguageOverride}) async {
    await localization.loadFromAsset();
    await storage.init();
    markovEngine.initializeMarkovMatrix();
    await readDb();
    await updateDarkMode(darkMode == 1);
    await updateLanguage(deviceLanguageOverride: deviceLanguageOverride);
    if (music == 1) {
      await audio.startBattleMusic();
    }
    notifyListeners();
  }

  /// Exact port of `ReadDb` in `Screen1.bky`
  Future<void> readDb() async {
    ads = storage.getInt('Ads', 0);
    algorithm = storage.getInt('Algorithm', 0);
    diamonds = storage.getInt('Diamonds', 0);
    newHands = storage.getInt('NewHands', 0);
    nextMove = storage.getInt('NextMove', 0);
    predictability = storage.getInt('Predictability', 0);
    random = storage.getInt('Random', 0);
    reset = storage.getInt('Reset', 0);
    sourceCode = storage.getInt('SourceCode', 0);
    sugestion = storage.getInt('Sugestion', 0);
    yourPrediction = storage.getInt('YourPrediction', 0);

    total = storage.getInt('Total', 0);
    percentPredict = storage.getDouble('PercentPredict', 0.0);
    pcScore = storage.getInt('PCScore', 0);
    userScore = storage.getInt('UserScore', 0);

    pcNextMove = storage.getString('PCNextMove', 'Random');
    markovEngine.setMatrix(storage.getMarkovMatrix());

    currentComputerChoice =
        storage.getInt('currentComputerChoice', MarkovEngine.none);
    currentUserChoice = storage.getInt('currentUserChoice', MarkovEngine.none);
    lastUserChoice = storage.getInt('lastUserChoice', 0);

    sugestionValue = storage.getString('SugestionValue', 'Random');
    yourPredictionValue = storage.getString('YourPredictionValue', 'Random');
    winner = storage.getString('Winner', 'NONE');

    startup = storage.getInt('startup', 0);
    darkMode = storage.getInt('DarkMode', 1);
    language = storage.getString('Language', 'en');
    music = storage.getInt('Music', 1);
    vibration = storage.getInt('Vibration', 1);
    animation = storage.getInt('Animation', 1);
    if (animation == 0) {
      backgroundImageAsset = '';
    }

    nextTurn();
    await updateAll(check100TurnModal: false);
  }

  /// Exact port of `nextTurn` in `Screen1.bky`
  void nextTurn() {
    if (total <= 1) {
      pcNextMove = tr(15, 'Random');
      yourPredictionValue = tr(15, 'Random');
      sugestionValue = tr(15, 'Random');
    } else {
      final smart = markovEngine.smartChoice(lastUserChoice);
      final predicted = markovEngine.findMostLikelyNextUserChoice(lastUserChoice);
      final suggested = markovEngine.suggestionForNextTurn(lastUserChoice);

      pcNextMove = choiceWord(smart);
      yourPredictionValue = choiceWord(predicted);
      sugestionValue = choiceWord(suggested);

      storage.storeString('PCNextMove', pcNextMove);
      storage.storeString('YourPredictionValue', yourPredictionValue);
      storage.storeString('SugestionValue', sugestionValue);
    }
  }

  /// Exact port of `updateWinnerScore` in `Screen1.bky`
  Future<void> updateWinnerScore() async {
    final compBeatsUser =
        currentComputerChoice == MarkovEngine.beatingChoiceFor(currentUserChoice);
    final userBeatsComp =
        currentUserChoice == MarkovEngine.beatingChoiceFor(currentComputerChoice);

    if (compBeatsUser) {
      pcScore += 1;
      winner = tr(50, 'PC');
      lastRoundOutcome = RoundOutcome.pcWin;
      if (animation == 1) {
        backgroundImageAsset = 'assets/BGRed.jpg';
        animationTick += 1;
      }
      if (music == 1) {
        await audio.playEffect('defeat.mid');
      }
      if (vibration == 1) {
        await audio.vibrate(500);
      }
    } else if (userBeatsComp) {
      userScore += 1;
      winner = tr(51, 'YOU');
      diamonds += 1;
      await storage.storeInt('Diamonds', diamonds);
      lastRoundOutcome = RoundOutcome.userWin;
      if (animation == 1) {
        backgroundImageAsset = 'assets/BGBlue.jpg';
        animationTick += 1;
      }
      if (music == 1) {
        await audio.playEffect('attack.mid');
      }
      if (vibration == 1) {
        await audio.vibrate(100);
      }
    } else {
      winner = tr(20, 'NONE');
      lastRoundOutcome = RoundOutcome.draw;
      if (animation == 1) {
        backgroundImageAsset = 'assets/BGDraw.jpg';
        animationTick += 1;
      }
      if (music == 1) {
        await audio.playEffect('draw.mid');
      }
      if (vibration == 1) {
        await audio.vibrate(250);
      }
    }
    await storage.storeString('Winner', winner);
  }

  /// Exact port of `updateMatrix` in `Screen1.bky`
  void updateMatrix() {
    if (total != 0) {
      markovEngine.updateMatrix(
        total: total,
        lastUserChoice: lastUserChoice,
        currentUserChoice: currentUserChoice,
      );
    }
  }

  /// Exact port of `Any Button.Click` (`None.Click` in `Screen1.bky`)
  /// `buttonChoiceIndex`: 1=Rock, 2=Paper, 3=Scissors, 4=Random, 5=Spock, 6=Lizard
  Future<void> playRound(int buttonChoiceIndex) async {
    if (total <= 1) {
      currentComputerChoice = markovEngine.randomChoice();
    } else {
      currentComputerChoice = markovEngine.smartChoice(lastUserChoice);
    }

    if (buttonChoiceIndex == 4 || buttonChoiceIndex > 3) {
      currentUserChoice = markovEngine.randomChoice();
    } else {
      currentUserChoice = buttonChoiceIndex;
    }

    await storage.storeInt('currentUserChoice', currentUserChoice);
    await storage.storeInt('currentComputerChoice', currentComputerChoice);
    await storage.storeString('Winner', winner);

    await updateWinnerScore();
    updateMatrix();

    lastUserChoice = currentUserChoice;
    total += 1;

    nextTurn();
    await updateAll(check100TurnModal: true);
    notifyListeners();
  }

  /// Exact port of `UpdateAll` in `Screen1.bky`
  Future<void> updateAll({bool check100TurnModal = false}) async {
    if (pcScore == 0 && userScore == 0) {
      percentPredict = 0.0;
    } else {
      percentPredict = (pcScore / (userScore + pcScore)) * 100.0;
    }

    if (total >= 100 && check100TurnModal && total == 100) {
      if (percentPredict == 0) {
        label100TurnText =
            '${tr(70, 'You Won!!!')}\n${tr(71, 'You are the Best Predictor Ever!!!')}';
        labelEmojiWinLoseText = '👑';
      } else if (percentPredict < 50) {
        label100TurnText =
            '${tr(72, 'Not so Bad!!!')}\n${tr(73, 'Now try to achieve 100%')}';
        labelEmojiWinLoseText = '🙂';
      } else {
        label100TurnText =
            '${tr(74, 'You Lose!!!')}\n${tr(75, 'Try harder next time...')}';
        labelEmojiWinLoseText = '🙁';
      }
      show100RoundDialog = true;
    }

    await storage.storeInt('Total', total);
    await storage.storeDouble('PercentPredict', percentPredict);
    await storage.storeInt('PCScore', pcScore);
    await storage.storeInt('UserScore', userScore);
    await storage.storeMarkovMatrix(markovEngine.matrix);
    await storage.storeInt('currentComputerChoice', currentComputerChoice);
    await storage.storeInt('currentUserChoice', currentUserChoice);
    await storage.storeInt('lastUserChoice', lastUserChoice);
    await storage.storeString('PCNextMove', pcNextMove);
    await storage.storeString('YourPredictionValue', yourPredictionValue);
    await storage.storeString('SugestionValue', sugestionValue);
    await storage.storeInt('Diamonds', diamonds);
    await updateDarkMode(darkMode == 1);
  }

  /// Exact port of `UpdateDarkMode` in `Screen1.bky`
  Future<void> updateDarkMode(bool isDark) async {
    darkMode = isDark ? 1 : 0;
    await storage.storeInt('DarkMode', darkMode);
    await storage.storeString(
      'textcolor',
      isDark ? '#ffffff' : '#000000',
    );
    notifyListeners();
  }

  /// Exact port of `UpdateLanguage` in `Screen1.bky`
  Future<void> updateLanguage({String? deviceLanguageOverride}) async {
    if (startup == 0) {
      final rawLocale = deviceLanguageOverride ??
          ui.PlatformDispatcher.instance.locale.languageCode;
      language = LocalizationService.normalizeDeviceLanguage(rawLocale);
      await storage.storeString('Language', language);
      startup = 1;
      await storage.storeInt('startup', startup);
    }

    if (currentComputerChoice == MarkovEngine.none) {
      winner = tr(20, 'NONE');
    } else if (currentComputerChoice ==
        MarkovEngine.beatingChoiceFor(currentUserChoice)) {
      winner = tr(50, 'PC');
    } else if (currentUserChoice ==
        MarkovEngine.beatingChoiceFor(currentComputerChoice)) {
      winner = tr(51, 'YOU');
    } else {
      winner = tr(20, 'NONE');
    }

    nextTurn();
    notifyListeners();
  }

  /// Exact port of `SpinnerLanguage.AfterSelecting`
  Future<void> selectLanguageFromSpinner(String selection) async {
    final mapped = LocalizationService.spinnerSelectionToLanguage(selection);
    if (mapped == null) {
      alertMessage = 'Language Error';
      notifyListeners();
      return;
    }
    language = mapped;
    await storage.storeString('Language', language);
    await updateLanguage();
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  /// Exact port of `ResetButton.Click` in `Screen1.bky`
  Future<void> resetGame() async {
    markovEngine.initializeMarkovMatrix();
    userScore = 0;
    pcScore = 0;
    total = 0;
    currentUserChoice = MarkovEngine.none;
    currentComputerChoice = MarkovEngine.none;
    winner = tr(20, 'NONE');
    lastUserChoice = MarkovEngine.rock;
    yourPredictionValue = tr(15, 'Random');
    pcNextMove = tr(15, 'Random');
    sugestionValue = tr(15, 'Random');
    show100RoundDialog = false;
    await updateAll(check100TurnModal: false);
    await updateLanguage();
    notifyListeners();
  }

  void dismiss100RoundDialog() {
    show100RoundDialog = false;
    notifyListeners();
  }

  Future<void> handle100RoundDialogSelection(String selection) async {
    show100RoundDialog = false;
    if (selection == tr(76, 'TRY AGAIN')) {
      await resetGame();
    } else {
      notifyListeners();
    }
  }

  String? consumeAlertMessage() {
    final msg = alertMessage;
    alertMessage = null;
    return msg;
  }

  void notEnoughDiamonds() {
    alertMessage = tr(79, 'Not enough Diamonds');
    notifyListeners();
  }

  // Shop Unlock Handlers (exact diamond costs from Screen1.bky)
  Future<bool> _unlockItem({
    required int cost,
    required String storageTag,
    required void Function(int) setter,
  }) async {
    if (diamonds >= cost) {
      diamonds -= cost;
      await storage.storeInt('Diamonds', diamonds);
      setter(1);
      await storage.storeInt(storageTag, 1);
      await updateAll(check100TurnModal: false);
      notifyListeners();
      return true;
    } else {
      notEnoughDiamonds();
      return false;
    }
  }

  Future<bool> unlockReset() => _unlockItem(
        cost: 100,
        storageTag: 'Reset',
        setter: (v) => reset = v,
      );

  Future<bool> unlockPredictability() => _unlockItem(
        cost: 150,
        storageTag: 'Predictability',
        setter: (v) => predictability = v,
      );

  Future<bool> unlockRandom() => _unlockItem(
        cost: 300,
        storageTag: 'Random',
        setter: (v) => random = v,
      );

  Future<bool> unlockAlgorithm() => _unlockItem(
        cost: 500,
        storageTag: 'Algorithm',
        setter: (v) => algorithm = v,
      );

  Future<bool> unlockNewHands() => _unlockItem(
        cost: 100,
        storageTag: 'NewHands',
        setter: (v) => newHands = v,
      );

  Future<bool> unlockYourPrediction() => _unlockItem(
        cost: 1000,
        storageTag: 'YourPrediction',
        setter: (v) => yourPrediction = v,
      );

  Future<bool> unlockNextMove() => _unlockItem(
        cost: 3000,
        storageTag: 'NextMove',
        setter: (v) => nextMove = v,
      );

  Future<bool> unlockSugestion() => _unlockItem(
        cost: 5000,
        storageTag: 'Sugestion',
        setter: (v) => sugestion = v,
      );

  Future<bool> unlockAds() => _unlockItem(
        cost: 10000,
        storageTag: 'Ads',
        setter: (v) => ads = v,
      );

  Future<bool> unlockSourceCode() => _unlockItem(
        cost: 100,
        storageTag: 'SourceCode',
        setter: (v) => sourceCode = v,
      );

  // Direct purchase buttons in Screen1.bky
  Future<void> purchaseAlgorithm() async {
    algorithm = 1;
    await storage.storeInt('Algorithm', 1);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  Future<void> purchaseNewHands() async {
    newHands = 1;
    await storage.storeInt('NewHands', 1);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  Future<void> purchaseYourPrediction() async {
    yourPrediction = 1;
    await storage.storeInt('YourPrediction', 1);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  Future<void> purchaseNextMove() async {
    nextMove = 1;
    await storage.storeInt('NextMove', 1);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  Future<void> purchaseSugestion() async {
    sugestion = 1;
    await storage.storeInt('Sugestion', 1);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  Future<void> purchaseAds() async {
    ads = 1;
    await storage.storeInt('Ads', 1);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  Future<void> purchaseSourceCode() async {
    sourceCode = 1;
    await storage.storeInt('SourceCode', 1);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  // Shop Checkbox Toggles (1 = Disabled, 2 = Enabled)
  Future<void> toggleResetCheckbox(bool checked) async {
    reset = checked ? 2 : 1;
    await storage.storeInt('Reset', reset);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  Future<void> togglePredictabilityCheckbox(bool checked) async {
    predictability = checked ? 2 : 1;
    await storage.storeInt('Predictability', predictability);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  Future<void> toggleRandomCheckbox(bool checked) async {
    random = checked ? 2 : 1;
    await storage.storeInt('Random', random);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  Future<void> toggleAlgorithmCheckbox(bool checked) async {
    algorithm = checked ? 2 : 1;
    await storage.storeInt('Algorithm', algorithm);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  Future<void> toggleNewHandsCheckbox(bool checked) async {
    newHands = checked ? 2 : 1;
    await storage.storeInt('NewHands', newHands);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  Future<void> toggleYourPredictionCheckbox(bool checked) async {
    yourPrediction = checked ? 2 : 1;
    await storage.storeInt('YourPrediction', yourPrediction);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  Future<void> toggleNextMoveCheckbox(bool checked) async {
    nextMove = checked ? 2 : 1;
    await storage.storeInt('NextMove', nextMove);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  Future<void> toggleSugestionCheckbox(bool checked) async {
    sugestion = checked ? 2 : 1;
    await storage.storeInt('Sugestion', sugestion);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  // Settings Toggles
  Future<void> toggleAnimations(bool checked) async {
    if (checked) {
      animation = 1;
      if (backgroundImageAsset.isEmpty) {
        backgroundImageAsset = 'assets/Splash.png';
      }
    } else {
      animation = 0;
      backgroundImageAsset = '';
    }
    await storage.storeInt('Animation', animation);
    await updateAll(check100TurnModal: false);
    notifyListeners();
  }

  Future<void> toggleMusic() async {
    if (music == 1) {
      music = 0;
      await storage.storeInt('Music', music);
      await audio.stopBattleMusic();
    } else {
      music = 1;
      await storage.storeInt('Music', music);
      await audio.startBattleMusic();
    }
    notifyListeners();
  }

  Future<void> toggleVibration() async {
    vibration = vibration == 1 ? 0 : 1;
    await storage.storeInt('Vibration', vibration);
    notifyListeners();
  }

  // ButtonGift & ButtonSecret
  Future<void> onButtonGiftClick() async {
    buttonGiftVisible = false;
    diamonds += 5;
    await storage.storeInt('Diamonds', diamonds);
    _giftTimer?.cancel();
    _giftTimer = Timer(const Duration(seconds: 60), () {
      buttonGiftVisible = true;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> onButtonSecretClick() async {
    diamonds += 1000;
    await storage.storeInt('Diamonds', diamonds);
    notifyListeners();
  }

  // Screen Navigation matching ButtonSettings, ButtonShop, ButtonAchievments, ButtonSettingsBack
  void openSettings() {
    buttonSettingsVisible = false;
    buttonSettingsBackVisible = true;
    buttonShopVisible = true;
    buttonAchievementsVisible = true;
    viewMode = ScreenViewMode.settings;
    notifyListeners();
  }

  void openShop() {
    buttonShopVisible = false;
    buttonSettingsBackVisible = true;
    buttonSettingsVisible = true;
    buttonAchievementsVisible = true;
    viewMode = ScreenViewMode.shoppingCart;
    notifyListeners();
  }

  void openAchievements() {
    buttonAchievementsVisible = false;
    buttonSettingsBackVisible = true;
    buttonSettingsVisible = true;
    buttonShopVisible = true;
    viewMode = ScreenViewMode.achievements;
    notifyListeners();
  }

  void navigateBackToNormal() {
    buttonSettingsVisible = true;
    buttonSettingsBackVisible = false;
    buttonShopVisible = true;
    buttonAchievementsVisible = true;
    viewMode = ScreenViewMode.normal;
    notifyListeners();
  }

  @override
  void dispose() {
    _giftTimer?.cancel();
    audio.dispose();
    super.dispose();
  }
}

