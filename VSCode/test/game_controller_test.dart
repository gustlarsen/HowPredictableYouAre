import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/models/story_chapter.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';

class _FakeAdMobClient implements AdMobClient {
  int bannerDisposeCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isPrivacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptionsForm({
    OnConsentFormDismissedListener? onDismissed,
  }) async {
    onDismissed?.call(null);
  }

  @override
  Future<void> loadBanner({
    required String adUnitId,
    required AdSize size,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    onLoaded();
  }

  @override
  Widget? buildBannerWidget() => const SizedBox(width: 320, height: 50);

  @override
  void disposeBanner() {
    bannerDisposeCount++;
  }

  @override
  Future<void> loadRewarded({
    required String adUnitId,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    onLoaded();
  }

  @override
  Future<bool> showRewarded({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onDismissed,
    required VoidCallback onFailedToShow,
  }) async {
    onUserEarnedReward();
    onDismissed();
    return true;
  }

  @override
  void disposeRewarded() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late AudioService audio;
  late GameController controller;

  Future<void> createController({bool resetPreferences = false}) async {
    if (resetPreferences) {
      SharedPreferences.setMockInitialValues({
        'diamonds': 0,
        'musicEnabled': false,
      });
    }
    storage = StorageService();
    await storage.init();
    audio = AudioService();
    controller = GameController(
      storage: storage,
      localization: LocalizationService(),
      audio: audio,
    );
  }

  test('Game starts with 0 diamonds by default', () async {
    SharedPreferences.setMockInitialValues({
      'musicEnabled': false,
    });
    await createController();

    expect(storage.diamonds, 0);
    expect(controller.diamonds, 0);
  });

  test('Reset purchase unlocks the reset action without automatically enabling it', () async {
    SharedPreferences.setMockInitialValues({
      'diamonds': 100,
      'musicEnabled': false,
    });
    await createController();

    controller.unlockReset();

    expect(controller.diamonds, 0);
    expect(controller.unlockedReset, isTrue);
    expect(controller.showReset, isFalse);
    expect(storage.unlockedReset, isTrue);
    expect(storage.showReset, isFalse);

    controller.toggleShowReset(true);
    expect(controller.showReset, isTrue);
    expect(storage.showReset, isTrue);
  });

  test(
    'Shop activation changes persist independently from ownership',
    () async {
      SharedPreferences.setMockInitialValues({
        'diamonds': 100,
        'musicEnabled': false,
      });
      await createController();

      controller.unlockReset();
      expect(controller.unlockedReset, isTrue);
      expect(controller.showReset, isFalse);

      controller.toggleShowReset(true);
      expect(controller.showReset, isTrue);
      expect(storage.showReset, isTrue);

      await createController();
      expect(controller.unlockedReset, isTrue);
      expect(controller.showReset, isTrue);

      controller.toggleShowReset(false);

      expect(controller.unlockedReset, isTrue);
      expect(controller.showReset, isFalse);
      expect(storage.showReset, isFalse);

      await createController();

      expect(controller.unlockedReset, isTrue);
      expect(controller.showReset, isFalse);
    },
  );

  test(
    'Vibration is enabled by default, invokes native vibrator channel with Kodular durations, and respects disabled setting',
    () async {
      final recordedDurations = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AudioService.vibratorChannel, (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'vibrate') {
              final args = methodCall.arguments as Map<dynamic, dynamic>;
              recordedDurations.add(args['duration'] as int);
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AudioService.vibratorChannel, null);
      });

      await createController(resetPreferences: true);

      expect(controller.vibrationEnabled, isTrue);
      expect(audio.vibrationEnabled, isTrue);

      await audio.vibrate(durationMs: AudioService.winVibrationDurationMs);
      await audio.vibrate(durationMs: AudioService.drawVibrationDurationMs);
      await audio.vibrate(durationMs: AudioService.defeatVibrationDurationMs);
      expect(recordedDurations, [100, 250, 500]);

      recordedDurations.clear();
      controller.toggleVibration(false);
      expect(controller.vibrationEnabled, isFalse);
      expect(audio.vibrationEnabled, isFalse);

      await audio.vibrate(durationMs: AudioService.defeatVibrationDurationMs);
      expect(recordedDurations, isEmpty);
    },
  );

  test('Insufficient diamonds prevents unlock', () async {
    SharedPreferences.setMockInitialValues({
      'diamonds': 50,
      'musicEnabled': false,
    });
    await createController();

    final result = controller.unlockReset();

    expect(result, isFalse);
    expect(controller.diamonds, 50);
    expect(controller.unlockedReset, isFalse);
    expect(controller.showReset, isFalse);
  });

  test('Periodic gift claims 5 diamonds', () async {
    await createController(resetPreferences: true);
    expect(controller.isGiftAvailable, isTrue);
    expect(controller.diamonds, 0);

    controller.claimGift();

    expect(controller.diamonds, 5);
    expect(controller.isGiftAvailable, isFalse);
  });

  test('Reset game clears scores and round stats', () async {
    await createController(resetPreferences: true);
    controller.userScore = 10;
    controller.pcScore = 5;
    controller.totalRounds = 15;
    controller.turnCount = 20;

    controller.resetGame();

    expect(controller.userScore, 0);
    expect(controller.pcScore, 0);
    expect(controller.totalRounds, 0);
    expect(controller.turnCount, 0);
  });

  test('turnCount increments with each played turn even on draws', () async {
    await createController(resetPreferences: true);
    expect(controller.turnCount, 0);

    controller.playTurn(HandMove.rock);
    expect(controller.turnCount, 1);

    controller.playTurn(HandMove.rock);
    expect(controller.turnCount, 2);
  });

  test('Crystal Ball purchase costs 20000 diamonds, starts disabled, and can be toggled', () async {
    SharedPreferences.setMockInitialValues({
      'diamonds': 100000,
      'musicEnabled': false,
    });
    await createController();

    expect(controller.unlockedCrystalBall, isFalse);
    expect(controller.showCrystalBall, isFalse);

    final ok = controller.unlockCrystalBall();
    expect(ok, isTrue);
    expect(controller.diamonds, 80000);
    expect(controller.unlockedCrystalBall, isTrue);
    expect(controller.showCrystalBall, isFalse);
    expect(storage.unlockedCrystalBall, isTrue);
    expect(storage.showCrystalBall, isFalse);

    controller.toggleShowCrystalBall(true);
    expect(controller.showCrystalBall, isTrue);
    expect(storage.showCrystalBall, isTrue);

    controller.toggleShowCrystalBall(false);
    expect(controller.showCrystalBall, isFalse);
    expect(storage.showCrystalBall, isFalse);
  });

  test('Intro story flag triggers on first launch and persists so it only appears once', () async {
    SharedPreferences.setMockInitialValues({
      'musicEnabled': false,
    });
    await createController();

    expect(storage.hasSeenStoryIntro, isFalse);
    expect(controller.hasSeenStoryIntro, isFalse);
    expect(controller.pendingStoryChapter, StoryChapter.intro);

    final consumed = controller.consumePendingStory(StoryChapter.intro);
    expect(consumed, StoryChapter.intro);
    expect(controller.hasSeenStoryIntro, isTrue);
    expect(storage.hasSeenStoryIntro, isTrue);
    expect(controller.pendingStoryChapter, isNull);

    // Subsequent app launch should not re-trigger intro story
    await createController();
    expect(controller.hasSeenStoryIntro, isTrue);
    expect(controller.pendingStoryChapter, isNull);
  });

  test('resetAllProgress resets intro story flag and sets pendingStoryChapter to intro as if opened for first time', () async {
    SharedPreferences.setMockInitialValues({
      'musicEnabled': false,
      'has_seen_story_intro': true,
      'diamonds': 500,
      'total': 10,
    });
    await createController();

    expect(storage.hasSeenStoryIntro, isTrue);
    expect(controller.hasSeenStoryIntro, isTrue);
    expect(controller.pendingStoryChapter, isNull);

    await controller.resetAllProgress();

    expect(storage.hasSeenStoryIntro, isFalse);
    expect(controller.hasSeenStoryIntro, isFalse);
    expect(controller.pendingStoryChapter, StoryChapter.intro);

    final consumed = controller.consumePendingStory(StoryChapter.intro);
    expect(consumed, StoryChapter.intro);
    expect(controller.hasSeenStoryIntro, isTrue);
    expect(storage.hasSeenStoryIntro, isTrue);
    expect(controller.pendingStoryChapter, isNull);
  });

  test('All 8 shop story chapters trigger on first unlock, persist flags, and do not re-trigger on toggle', () async {
    SharedPreferences.setMockInitialValues({
      'diamonds': 100000,
      'musicEnabled': false,
      'has_seen_story_intro': true,
    });
    await createController();

    expect(controller.pendingStoryChapter, isNull);

    // 1. Reset Button
    expect(storage.hasSeenStoryReset, isFalse);
    expect(controller.isStoryChapterUnlocked(StoryChapter.resetButton), isFalse);
    expect(controller.unlockReset(), isTrue);
    expect(storage.hasSeenStoryReset, isTrue);
    expect(controller.isStoryChapterUnlocked(StoryChapter.resetButton), isTrue);
    expect(controller.consumePendingStory(), StoryChapter.resetButton);
    controller.toggleShowReset(false);
    controller.toggleShowReset(true);
    expect(controller.pendingStoryChapter, isNull);

    // 2. Predictability Score
    expect(storage.hasSeenStoryPredictability, isFalse);
    expect(controller.unlockPredictability(), isTrue);
    expect(storage.hasSeenStoryPredictability, isTrue);
    expect(controller.consumePendingStory(), StoryChapter.predictabilityScore);
    controller.toggleShowPredictability(false);
    controller.toggleShowPredictability(true);
    expect(controller.pendingStoryChapter, isNull);

    // 3. Random Button
    expect(storage.hasSeenStoryRandom, isFalse);
    expect(controller.unlockRandom(), isTrue);
    expect(storage.hasSeenStoryRandom, isTrue);
    expect(controller.consumePendingStory(), StoryChapter.randomButton);
    controller.toggleShowRandom(false);
    controller.toggleShowRandom(true);
    expect(controller.pendingStoryChapter, isNull);

    // 4. Show Algorithm
    expect(storage.hasSeenStoryAlgorithm, isFalse);
    expect(controller.unlockAlgorithm(), isTrue);
    expect(storage.hasSeenStoryAlgorithm, isTrue);
    expect(controller.consumePendingStory(), StoryChapter.showAlgorithm);
    controller.toggleShowAlgorithm(false);
    controller.toggleShowAlgorithm(true);
    expect(controller.pendingStoryChapter, isNull);

    // 5. Your Prediction
    expect(storage.hasSeenStoryYourPrediction, isFalse);
    expect(controller.unlockYourPrediction(), isTrue);
    expect(storage.hasSeenStoryYourPrediction, isTrue);
    expect(controller.consumePendingStory(), StoryChapter.yourPrediction);
    controller.toggleShowYourPrediction(false);
    controller.toggleShowYourPrediction(true);
    expect(controller.pendingStoryChapter, isNull);

    // 6. PC Next Move
    expect(storage.hasSeenStoryPcNextMove, isFalse);
    expect(controller.unlockNextMove(), isTrue);
    expect(storage.hasSeenStoryPcNextMove, isTrue);
    expect(controller.consumePendingStory(), StoryChapter.pcNextMove);
    controller.toggleShowNextMove(false);
    controller.toggleShowNextMove(true);
    expect(controller.pendingStoryChapter, isNull);

    // 7. Suggestion
    expect(storage.hasSeenStorySuggestion, isFalse);
    expect(controller.unlockSuggestion(), isTrue);
    expect(storage.hasSeenStorySuggestion, isTrue);
    expect(controller.consumePendingStory(), StoryChapter.suggestion);
    controller.toggleShowSuggestion(false);
    controller.toggleShowSuggestion(true);
    expect(controller.pendingStoryChapter, isNull);

    // 8. Crystal Ball
    expect(storage.hasSeenStoryCrystalBall, isFalse);
    expect(controller.unlockCrystalBall(), isTrue);
    expect(storage.hasSeenStoryCrystalBall, isTrue);
    expect(controller.consumePendingStory(), StoryChapter.crystalBall);
    controller.toggleShowCrystalBall(false);
    controller.toggleShowCrystalBall(true);
    expect(controller.pendingStoryChapter, isNull);
  });

  test('PC move is pre-selected before user plays turn and matches crystalBallMove', () async {
    await createController(resetPreferences: true);

    for (final userChoice in [
      HandMove.rock,
      HandMove.paper,
      HandMove.scissors,
      HandMove.rock,
      HandMove.paper,
    ]) {
      final preselectedPcMove = controller.crystalBallMove;
      expect(preselectedPcMove, isNotNull);

      controller.playTurn(userChoice);

      expect(controller.currentComputerMove, equals(preselectedPcMove));
    }
  });

  test('hasGameStarted reflects whether any hand has been chosen and resets on toggleShowNewHands', () async {
    SharedPreferences.setMockInitialValues({
      'diamonds': 500,
      'musicEnabled': false,
    });
    await createController();

    expect(controller.hasGameStarted, isFalse);

    controller.playTurn(HandMove.rock);
    expect(controller.hasGameStarted, isTrue);

    // Purchasing New Hands does NOT automatically enable it or reset the game
    expect(controller.unlockNewHands(), isTrue);
    expect(controller.unlockedNewHands, isTrue);
    expect(controller.showNewHands, isFalse);
    expect(controller.hasGameStarted, isTrue);
    expect(controller.turnCount, 1);

    // Enabling New Hands activates 5 hands and resets the game
    controller.toggleShowNewHands(true);
    expect(controller.showNewHands, isTrue);
    expect(controller.hasGameStarted, isFalse);
    expect(controller.turnCount, 0);
    expect(controller.totalRounds, 0);
    expect(controller.currentUserMove, isNull);
    expect(controller.lastUserMove, isNull);

    controller.playTurn(HandMove.lizard);
    expect(controller.hasGameStarted, isTrue);

    controller.toggleShowNewHands(false);
    expect(controller.showNewHands, isFalse);
    expect(controller.hasGameStarted, isFalse);
    expect(controller.turnCount, 0);
    expect(controller.totalRounds, 0);
    expect(controller.currentUserMove, isNull);
    expect(controller.lastUserMove, isNull);
  });

  test('Purchasing any store item leaves it disabled until the user explicitly enables it', () async {
    SharedPreferences.setMockInitialValues({
      'diamonds': 200000,
      'musicEnabled': false,
    });
    await createController();

    expect(controller.unlockReset(), isTrue);
    expect(controller.unlockedReset, isTrue);
    expect(controller.showReset, isFalse);

    expect(controller.unlockPredictability(), isTrue);
    expect(controller.unlockedPredictability, isTrue);
    expect(controller.showPredictability, isFalse);

    expect(controller.unlockRandom(), isTrue);
    expect(controller.unlockedRandom, isTrue);
    expect(controller.showRandom, isFalse);

    expect(controller.unlockAlgorithm(), isTrue);
    expect(controller.unlockedAlgorithm, isTrue);
    expect(controller.showAlgorithm, isFalse);

    expect(controller.unlockNewHands(), isTrue);
    expect(controller.unlockedNewHands, isTrue);
    expect(controller.showNewHands, isFalse);

    expect(controller.unlockYourPrediction(), isTrue);
    expect(controller.unlockedYourPrediction, isTrue);
    expect(controller.showYourPrediction, isFalse);

    expect(controller.unlockNextMove(), isTrue);
    expect(controller.unlockedNextMove, isTrue);
    expect(controller.showNextMove, isFalse);

    expect(controller.unlockSuggestion(), isTrue);
    expect(controller.unlockedSuggestion, isTrue);
    expect(controller.showSuggestion, isFalse);

    expect(controller.unlockCrystalBall(), isTrue);
    expect(controller.unlockedCrystalBall, isTrue);
    expect(controller.showCrystalBall, isFalse);

    expect(controller.unlockCrystalBallPlus(), isTrue);
    expect(controller.unlockedCrystalBallPlus, isTrue);
    expect(controller.showCrystalBallPlus, isFalse);

    expect(controller.unlockNewSkin(), isTrue);
    expect(controller.unlockedNewSkin, isTrue);
    expect(controller.showNewSkin, isFalse);
  });

  test('New Skin purchase costs 10000 diamonds, starts disabled, and toggling ON/OFF applies seamlessly without resetting match, scores, or Markov matrix', () async {
    SharedPreferences.setMockInitialValues({
      'diamonds': 25000,
      'musicEnabled': false,
    });
    await createController();

    // Play a few turns first so we have active scores, turnCount, and Markov transitions
    controller.playTurn(HandMove.rock);
    controller.playTurn(HandMove.paper);
    controller.playTurn(HandMove.rock);

    final savedTurnCount = controller.turnCount;
    final savedTotalRounds = controller.totalRounds;
    final savedUserScore = controller.userScore;
    final savedPcScore = controller.pcScore;
    final savedMatrix01 = controller.engine.matrix[0][1];
    final savedMatrix10 = controller.engine.matrix[1][0];
    expect(savedTurnCount, 3);
    expect(savedMatrix01, 1);
    expect(savedMatrix10, 1);

    // Purchase New Skin (10,000 diamonds): unlocks without enabling or resetting
    final diamondsBefore = controller.diamonds;
    expect(controller.unlockNewSkin(), isTrue);
    expect(controller.diamonds, diamondsBefore - 10000);
    expect(controller.unlockedNewSkin, isTrue);
    expect(controller.showNewSkin, isFalse);
    expect(storage.unlockedNewSkin, isTrue);
    expect(storage.showNewSkin, isFalse);

    // Toggle New Skin ON: must NOT reset match, scores, or Markov matrix
    controller.toggleShowNewSkin(true);
    expect(controller.showNewSkin, isTrue);
    expect(storage.showNewSkin, isTrue);
    expect(controller.turnCount, savedTurnCount);
    expect(controller.totalRounds, savedTotalRounds);
    expect(controller.userScore, savedUserScore);
    expect(controller.pcScore, savedPcScore);
    expect(controller.engine.matrix[0][1], savedMatrix01);
    expect(controller.engine.matrix[1][0], savedMatrix10);

    // Toggle New Skin OFF: must also preserve match, scores, and Markov matrix
    controller.toggleShowNewSkin(false);
    expect(controller.showNewSkin, isFalse);
    expect(storage.showNewSkin, isFalse);
    expect(controller.turnCount, savedTurnCount);
    expect(controller.totalRounds, savedTotalRounds);
    expect(controller.userScore, savedUserScore);
    expect(controller.pcScore, savedPcScore);
    expect(controller.engine.matrix[0][1], savedMatrix01);
    expect(controller.engine.matrix[1][0], savedMatrix10);

    // Rejects New Skin purchase when player has fewer than 10,000 diamonds
    SharedPreferences.setMockInitialValues({
      'diamonds': 9999,
      'musicEnabled': false,
    });
    await createController();
    expect(controller.unlockNewSkin(), isFalse);
    expect(controller.diamonds, 9999);
    expect(controller.unlockedNewSkin, isFalse);
    expect(controller.showNewSkin, isFalse);
  });

  test('Wu Xing 3-element and 5-element win/loss/tie resolution in GameController and dynamic lastWinner update on skin toggle', () async {
    SharedPreferences.setMockInitialValues({
      'diamonds': 30000,
      'unlockedNewHands': true,
      'showNewHands': true,
      'unlockedNewSkin': true,
      'showNewSkin': false,
      'musicEnabled': false,
    });
    await createController();

    // Force deterministic PC move (Lizard / Earth) and play Rock (Fire) in Classic 5-hand mode
    controller.crystalBallMove = HandMove.lizard;
    controller.playTurn(HandMove.rock);

    // In Classic RPSLS: Rock crushes Lizard -> User wins
    expect(controller.lastWinner, RoundWinner.user);
    expect(controller.userScore, 1);
    expect(controller.pcScore, 0);

    // Toggle New Skin ON mid-match -> Earth (lizard) smothers Fire (rock), so lastWinner re-evaluates to computer without resetting scores
    controller.toggleShowNewSkin(true);
    expect(controller.showNewSkin, isTrue);
    expect(controller.lastWinner, RoundWinner.computer);
    expect(controller.userScore, 1);
    expect(controller.pcScore, 0);
    expect(controller.turnCount, 1);

    // Play a round in 5-element Wu Xing mode: Fire (rock) vs Metal (spock) -> Fire melts Metal (User wins!)
    controller.crystalBallMove = HandMove.spock;
    controller.playTurn(HandMove.rock);
    expect(controller.lastWinner, RoundWinner.user);
    expect(controller.userScore, 2);
    expect(controller.pcScore, 0);

    // Play a round in 5-element Wu Xing mode: Fire (rock) vs Earth (lizard) -> Earth smothers Fire (Computer wins!)
    controller.crystalBallMove = HandMove.lizard;
    controller.playTurn(HandMove.rock);
    expect(controller.lastWinner, RoundWinner.computer);
    expect(controller.userScore, 2);
    expect(controller.pcScore, 1);

    // Play a tie round in 5-element Wu Xing mode: Metal (spock) vs Metal (spock) -> Draw
    controller.crystalBallMove = HandMove.spock;
    controller.playTurn(HandMove.spock);
    expect(controller.lastWinner, RoundWinner.draw);
    expect(controller.userScore, 2);
    expect(controller.pcScore, 1);
  });

  test('Last played hands are saved on playTurn, restored on app reopen, and cleared on resetGame', () async {
    await createController(resetPreferences: true);

    expect(controller.currentUserMove, isNull);
    expect(controller.currentComputerMove, isNull);
    expect(controller.lastUserMove, isNull);
    expect(controller.lastWinner, isNull);
    expect(storage.lastUserMove, isNull);
    expect(storage.lastComputerMove, isNull);

    controller.playTurn(HandMove.paper);
    final savedPcMove = controller.currentComputerMove;
    final savedWinner = controller.lastWinner;

    expect(controller.currentUserMove, HandMove.paper);
    expect(savedPcMove, isNotNull);
    expect(savedWinner, isNotNull);
    expect(storage.lastUserMove, HandMove.paper);
    expect(storage.lastComputerMove, savedPcMove);

    // Reopen app (new controller instance loading from persisted storage)
    await createController();

    expect(controller.currentUserMove, HandMove.paper);
    expect(controller.currentComputerMove, savedPcMove);
    expect(controller.lastUserMove, HandMove.paper);
    expect(controller.lastWinner, savedWinner);

    // Resetting the game clears the saved hands
    controller.resetGame();
    expect(controller.currentUserMove, isNull);
    expect(controller.currentComputerMove, isNull);
    expect(controller.lastUserMove, isNull);
    expect(controller.lastWinner, isNull);
    expect(storage.lastUserMove, isNull);
    expect(storage.lastComputerMove, isNull);

    // Reopening after reset keeps hands empty
    await createController();
    expect(controller.currentUserMove, isNull);
    expect(controller.currentComputerMove, isNull);
    expect(controller.lastUserMove, isNull);
    expect(controller.lastWinner, isNull);
  });

  test('Completing a rewarded ad increments diamonds by 50, persists to SharedPreferences, and activates 2-minute cooldown', () async {
    SharedPreferences.setMockInitialValues({
      'diamonds': 25,
      'musicEnabled': false,
    });
    storage = StorageService();
    await storage.init();
    audio = AudioService();
    final fakeAdClient = _FakeAdMobClient();
    final adService = AdService(client: fakeAdClient);
    await adService.initialize();

    controller = GameController(
      storage: storage,
      localization: LocalizationService(),
      audio: audio,
      adService: adService,
    );
    addTearDown(() => controller.dispose());

    expect(controller.diamonds, 25);
    expect(controller.isRewardedAdReady, isTrue);

    bool rewardCallbackTriggered = false;
    final rewarded = await controller.watchRewardedAd(
      onRewardEarned: () {
        rewardCallbackTriggered = true;
      },
    );

    expect(rewarded, isTrue);
    expect(rewardCallbackTriggered, isTrue);
    expect(controller.diamonds, 75);
    expect(storage.diamonds, 75);
    expect(controller.isRewardedAdOnCooldown, isTrue);
    expect(controller.isRewardedAdReady, isFalse);
  });

  test('Unlocking Remove Ads disables banner display and disposes banner while keeping rewarded ad available', () async {
    SharedPreferences.setMockInitialValues({
      'diamonds': 15000,
      'musicEnabled': false,
    });
    storage = StorageService();
    await storage.init();
    audio = AudioService();
    final fakeAdClient = _FakeAdMobClient();
    final adService = AdService(client: fakeAdClient);
    await adService.initialize();

    controller = GameController(
      storage: storage,
      localization: LocalizationService(),
      audio: audio,
      adService: adService,
    );
    addTearDown(() => controller.dispose());

    expect(controller.unlockedAds, isFalse);
    expect(controller.shouldShowBannerAd, isTrue);
    expect(adService.isBannerAdLoaded, isTrue);
    expect(adService.bannerHeight, 50.0);

    final unlocked = controller.unlockAds();
    expect(unlocked, isTrue);
    expect(controller.diamonds, 5000);
    expect(controller.unlockedAds, isTrue);
    expect(controller.unlockedRemoveAds, isTrue);
    expect(storage.unlockedAds, isTrue);
    expect(controller.shouldShowBannerAd, isFalse);
    expect(adService.isBannerAdLoaded, isFalse);
    expect(adService.bannerHeight, 0.0);
    expect(fakeAdClient.bannerDisposeCount, greaterThanOrEqualTo(1));

    // Voluntary Rewarded Video ad remains available even when Remove Ads is unlocked
    expect(controller.isRewardedAdReady, isTrue);
  });

  test('HP mechanics: starts at 100, reduces on loss, persists to storage, and resets back to 100', () async {
    await createController(resetPreferences: true);

    expect(controller.userHp, 100);
    expect(controller.computerHp, 100);
    expect(storage.userHp, 100);
    expect(storage.pcHp, 100);

    // Play rounds until user and pc both experience outcomes
    // Play with predictable moves against empty engine
    controller.playTurn(HandMove.rock);
    expect(controller.userHp, inInclusiveRange(0, 100));
    expect(controller.computerHp, inInclusiveRange(0, 100));

    if (controller.lastWinner == RoundWinner.user) {
      expect(controller.userHp, 100);
      expect(controller.computerHp, 99);
      expect(storage.pcHp, 99);
    } else if (controller.lastWinner == RoundWinner.computer) {
      expect(controller.userHp, 99);
      expect(controller.computerHp, 100);
      expect(storage.userHp, 99);
    } else {
      expect(controller.userHp, 100);
      expect(controller.computerHp, 100);
    }

    // Persist and reopen
    final prevUserHp = controller.userHp;
    final prevPcHp = controller.computerHp;
    await createController();
    expect(controller.userHp, prevUserHp);
    expect(controller.computerHp, prevPcHp);

    // Resetting game restores both back to 100
    controller.resetGame();
    expect(controller.userHp, 100);
    expect(controller.computerHp, 100);
    expect(storage.userHp, 100);
    expect(storage.pcHp, 100);

    // Resetting all progress restores both back to 100
    await controller.resetAllProgress();
    expect(controller.userHp, 100);
    expect(controller.computerHp, 100);
    expect(storage.userHp, 100);
    expect(storage.pcHp, 100);
  });
}
