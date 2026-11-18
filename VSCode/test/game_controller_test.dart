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

  test('Game starts with 0 Elemental Orbs across all 5 elements by default', () async {
    SharedPreferences.setMockInitialValues({
      'musicEnabled': false,
    });
    await createController();

    expect(storage.fireOrbs, 0);
    expect(storage.waterOrbs, 0);
    expect(storage.woodOrbs, 0);
    expect(storage.earthOrbs, 0);
    expect(storage.metalOrbs, 0);
    expect(storage.totalOrbs, 0);
    expect(controller.fireOrbs, 0);
    expect(controller.waterOrbs, 0);
    expect(controller.woodOrbs, 0);
    expect(controller.earthOrbs, 0);
    expect(controller.metalOrbs, 0);
    expect(controller.totalOrbs, 0);
  });

  test('Legacy save migration converts legacy diamonds > 0 once into Elemental Orbs when orbs are 0', () async {
    SharedPreferences.setMockInitialValues({
      'diamonds': 125,
      'musicEnabled': false,
    });
    await createController();

    expect(controller.fireOrbs, 125);
    expect(controller.waterOrbs, 125);
    expect(controller.woodOrbs, 125);
    expect(controller.earthOrbs, 125);
    expect(controller.metalOrbs, 125);
    expect(storage.legacyDiamonds, 0);

    // Spend some Fire orbs and re-init -> does not re-migrate
    controller.unlockPredictability(); // costs 15 Fire + 15 Water + 15 Wood
    expect(controller.fireOrbs, 110);
    expect(controller.waterOrbs, 110);
    expect(controller.woodOrbs, 110);
    expect(controller.earthOrbs, 125);
    expect(controller.metalOrbs, 125);

    await createController();
    expect(controller.fireOrbs, 110);
    expect(controller.waterOrbs, 110);
    expect(controller.woodOrbs, 110);
    expect(controller.earthOrbs, 125);
    expect(controller.metalOrbs, 125);
  });

  test('Battle collection rule: winning a round grants +1 Elemental Orb of the defeated AI/PC element, while ties and losses grant 0 orbs', () async {
    SharedPreferences.setMockInitialValues({
      'unlockedNewHands': true,
      'showNewHands': true,
      'musicEnabled': false,
    });
    await createController();

    // 1. Defeat AI Fire (rock) with Water (paper) -> +1 Fire Orb
    controller.crystalBallMove = HandMove.rock;
    controller.playTurn(HandMove.paper);
    expect(controller.lastWinner, RoundWinner.user);
    expect(controller.fireOrbs, 1);
    expect(controller.waterOrbs, 0);
    expect(controller.woodOrbs, 0);
    expect(controller.earthOrbs, 0);
    expect(controller.metalOrbs, 0);
    expect(controller.lastCollectedOrbMove, HandMove.rock);
    expect(controller.orbCollectionEventId, 1);

    // 2. Defeat AI Water (paper) with Wood (scissors) -> +1 Water Orb
    controller.crystalBallMove = HandMove.paper;
    controller.playTurn(HandMove.scissors);
    expect(controller.lastWinner, RoundWinner.user);
    expect(controller.fireOrbs, 1);
    expect(controller.waterOrbs, 1);
    expect(controller.woodOrbs, 0);
    expect(controller.earthOrbs, 0);
    expect(controller.metalOrbs, 0);
    expect(controller.lastCollectedOrbMove, HandMove.paper);
    expect(controller.orbCollectionEventId, 2);

    // 3. Defeat AI Wood (scissors) with Fire (rock) -> +1 Wood Orb
    controller.crystalBallMove = HandMove.scissors;
    controller.playTurn(HandMove.rock);
    expect(controller.lastWinner, RoundWinner.user);
    expect(controller.fireOrbs, 1);
    expect(controller.waterOrbs, 1);
    expect(controller.woodOrbs, 1);
    expect(controller.earthOrbs, 0);
    expect(controller.metalOrbs, 0);
    expect(controller.lastCollectedOrbMove, HandMove.scissors);
    expect(controller.orbCollectionEventId, 3);

    // 4. Defeat AI Earth (lizard) with Wood (scissors) -> +1 Earth Orb
    controller.crystalBallMove = HandMove.lizard;
    controller.playTurn(HandMove.scissors);
    expect(controller.lastWinner, RoundWinner.user);
    expect(controller.earthOrbs, 1);
    expect(controller.lastCollectedOrbMove, HandMove.lizard);
    expect(controller.orbCollectionEventId, 4);

    // 5. Defeat AI Metal (spock) with Fire (rock) -> +1 Metal Orb
    controller.crystalBallMove = HandMove.spock;
    controller.playTurn(HandMove.rock);
    expect(controller.lastWinner, RoundWinner.user);
    expect(controller.metalOrbs, 1);
    expect(controller.lastCollectedOrbMove, HandMove.spock);
    expect(controller.orbCollectionEventId, 5);

    // 6. Tie round -> awards 0 orbs
    controller.crystalBallMove = HandMove.rock;
    controller.playTurn(HandMove.rock);
    expect(controller.lastWinner, RoundWinner.draw);
    expect(controller.totalOrbs, 5);
    expect(controller.orbCollectionEventId, 5);

    // 7. Loss round -> awards 0 orbs
    controller.crystalBallMove = HandMove.paper;
    controller.playTurn(HandMove.rock);
    expect(controller.lastWinner, RoundWinner.computer);
    expect(controller.totalOrbs, 5);
    expect(controller.orbCollectionEventId, 5);
  });

  test('Reset purchase deducts 30 Fire + 30 Water + 30 Wood and unlocks the reset action without automatically enabling it', () async {
    SharedPreferences.setMockInitialValues({
      'orbs_fire': 30,
      'orbs_water': 30,
      'orbs_wood': 30,
      'musicEnabled': false,
    });
    await createController();

    expect(controller.unlockReset(), isTrue);

    expect(controller.fireOrbs, 0);
    expect(controller.waterOrbs, 0);
    expect(controller.woodOrbs, 0);
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
        'orbs_fire': 30,
        'orbs_water': 30,
        'orbs_wood': 30,
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

  test('Insufficient Elemental Orbs in any required element prevents unlock', () async {
    SharedPreferences.setMockInitialValues({
      'orbs_fire': 30,
      'orbs_water': 30,
      'orbs_wood': 29, // Reset Button requires 30 Wood
      'musicEnabled': false,
    });
    await createController();

    final result = controller.unlockReset();

    expect(result, isFalse);
    expect(controller.fireOrbs, 30);
    expect(controller.waterOrbs, 30);
    expect(controller.woodOrbs, 29);
    expect(controller.unlockedReset, isFalse);
    expect(controller.showReset, isFalse);
  });

  test('Periodic gift claims +5 of EACH of the 5 Elemental Orbs', () async {
    await createController(resetPreferences: true);
    expect(controller.isGiftAvailable, isTrue);
    expect(controller.totalOrbs, 0);

    controller.claimGift();

    expect(controller.fireOrbs, 5);
    expect(controller.waterOrbs, 5);
    expect(controller.woodOrbs, 5);
    expect(controller.earthOrbs, 5);
    expect(controller.metalOrbs, 5);
    expect(storage.fireOrbs, 5);
    expect(storage.waterOrbs, 5);
    expect(storage.woodOrbs, 5);
    expect(storage.earthOrbs, 5);
    expect(storage.metalOrbs, 5);
    expect(controller.isGiftAvailable, isFalse);
    controller.cancelPendingTimers();
  });

  test('7-tap QA shortcut on Backpack icon grants +100,000 of each Elemental Orb on the 7th tap', () async {
    await createController(resetPreferences: true);
    expect(controller.totalOrbs, 0);

    for (var i = 1; i <= 6; i++) {
      expect(controller.registerBackpackQaTap(), isFalse);
      expect(controller.totalOrbs, 0);
    }

    expect(controller.registerBackpackQaTap(), isTrue);
    expect(controller.fireOrbs, 100000);
    expect(controller.waterOrbs, 100000);
    expect(controller.woodOrbs, 100000);
    expect(controller.earthOrbs, 100000);
    expect(controller.metalOrbs, 100000);
    expect(storage.fireOrbs, 100000);
    expect(storage.metalOrbs, 100000);
  });

  test('Reset game clears scores and round stats without altering Elemental Orbs or hasClaimedQaBonus', () async {
    await createController(resetPreferences: true);
    controller.addAllOrbs(250);
    controller.hasClaimedQaBonus = true;
    controller.userScore = 10;
    controller.pcScore = 5;
    controller.totalRounds = 15;
    controller.turnCount = 20;

    controller.resetGame();

    expect(controller.userScore, 0);
    expect(controller.pcScore, 0);
    expect(controller.totalRounds, 0);
    expect(controller.turnCount, 0);
    expect(controller.fireOrbs, 250);
    expect(controller.waterOrbs, 250);
    expect(controller.woodOrbs, 250);
    expect(controller.earthOrbs, 250);
    expect(controller.metalOrbs, 250);
    expect(controller.hasClaimedQaBonus, isTrue);
  });

  test('turnCount increments with each played turn even on draws', () async {
    await createController(resetPreferences: true);
    expect(controller.turnCount, 0);

    controller.playTurn(HandMove.rock);
    expect(controller.turnCount, 1);

    controller.playTurn(HandMove.rock);
    expect(controller.turnCount, 2);
  });

  test('Crystal Ball purchase costs 3500 Fire/Water/Wood + 2500 Earth/Metal, starts disabled, and can be toggled', () async {
    SharedPreferences.setMockInitialValues({
      'orbs_fire': 10000,
      'orbs_water': 10000,
      'orbs_wood': 10000,
      'orbs_earth': 10000,
      'orbs_metal': 10000,
      'musicEnabled': false,
    });
    await createController();

    expect(controller.unlockedCrystalBall, isFalse);
    expect(controller.showCrystalBall, isFalse);

    final ok = controller.unlockCrystalBall();
    expect(ok, isTrue);
    expect(controller.fireOrbs, 6500);
    expect(controller.waterOrbs, 6500);
    expect(controller.woodOrbs, 6500);
    expect(controller.earthOrbs, 7500);
    expect(controller.metalOrbs, 7500);
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
      'orbs_fire': 500,
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
      'orbs_fire': 100000,
      'orbs_water': 100000,
      'orbs_wood': 100000,
      'orbs_earth': 100000,
      'orbs_metal': 100000,
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
      'orbs_fire': 500,
      'orbs_water': 500,
      'orbs_wood': 500,
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

  test('Purchasing any store item deducts exact Elemental Orb costs and leaves item disabled until explicitly enabled', () async {
    SharedPreferences.setMockInitialValues({
      'orbs_fire': 100000,
      'orbs_water': 100000,
      'orbs_wood': 100000,
      'orbs_earth': 100000,
      'orbs_metal': 100000,
      'musicEnabled': false,
    });
    await createController();

    expect(controller.unlockPredictability(), isTrue);
    expect(controller.unlockedPredictability, isTrue);
    expect(controller.showPredictability, isFalse);

    expect(controller.unlockReset(), isTrue);
    expect(controller.unlockedReset, isTrue);
    expect(controller.showReset, isFalse);

    expect(controller.unlockNewHands(), isTrue);
    expect(controller.unlockedNewHands, isTrue);
    expect(controller.showNewHands, isFalse);

    expect(controller.unlockRandom(), isTrue);
    expect(controller.unlockedRandom, isTrue);
    expect(controller.showRandom, isFalse);

    expect(controller.unlockAlgorithm(), isTrue);
    expect(controller.unlockedAlgorithm, isTrue);
    expect(controller.showAlgorithm, isFalse);

    expect(controller.unlockYourPrediction(), isTrue);
    expect(controller.unlockedYourPrediction, isTrue);
    expect(controller.showYourPrediction, isFalse);

    expect(controller.unlockNextMove(), isTrue);
    expect(controller.unlockedNextMove, isTrue);
    expect(controller.showNextMove, isFalse);

    expect(controller.unlockSuggestion(), isTrue);
    expect(controller.unlockedSuggestion, isTrue);
    expect(controller.showSuggestion, isFalse);

    expect(controller.unlockNewSkin(), isTrue);
    expect(controller.unlockedNewSkin, isTrue);
    expect(controller.showNewSkin, isFalse);

    expect(controller.unlockAds(), isTrue);
    expect(controller.unlockedAds, isTrue);

    expect(controller.unlockCrystalBall(), isTrue);
    expect(controller.unlockedCrystalBall, isTrue);
    expect(controller.showCrystalBall, isFalse);

    expect(controller.unlockCrystalBallPlus(), isTrue);
    expect(controller.unlockedCrystalBallPlus, isTrue);
    expect(controller.showCrystalBallPlus, isFalse);

    // Total deducted for all 11 standard items + CrystalBall+:
    // Fire/Water/Wood: 15+30+40+80+120+250+600+1000+1500+2000+3500+5000 = 14,135
    // Earth/Metal: 50+100+300+500+1000+1500+2500+5000 = 10,950
    expect(controller.fireOrbs, 100000 - 14135);
    expect(controller.waterOrbs, 100000 - 14135);
    expect(controller.woodOrbs, 100000 - 14135);
    expect(controller.earthOrbs, 100000 - 10950);
    expect(controller.metalOrbs, 100000 - 10950);
  });

  test('New Skin purchase costs 1500 Fire/Water/Wood + 1000 Earth/Metal, starts disabled, and toggling ON/OFF applies seamlessly without resetting match, scores, or Markov matrix', () async {
    SharedPreferences.setMockInitialValues({
      'orbs_fire': 2000,
      'orbs_water': 2000,
      'orbs_wood': 2000,
      'orbs_earth': 1500,
      'orbs_metal': 1500,
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

    final fireBefore = controller.fireOrbs;
    final earthBefore = controller.earthOrbs;
    expect(controller.unlockNewSkin(), isTrue);
    expect(controller.fireOrbs, fireBefore - 1500);
    expect(controller.earthOrbs, earthBefore - 1000);
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

    // Rejects New Skin purchase when player lacks required Earth/Metal orbs
    SharedPreferences.setMockInitialValues({
      'orbs_fire': 1500,
      'orbs_water': 1500,
      'orbs_wood': 1500,
      'orbs_earth': 999,
      'orbs_metal': 1000,
      'musicEnabled': false,
    });
    await createController();
    expect(controller.unlockNewSkin(), isFalse);
    expect(controller.earthOrbs, 999);
    expect(controller.unlockedNewSkin, isFalse);
    expect(controller.showNewSkin, isFalse);
  });

  test('Wu Xing 3-element and 5-element win/loss/tie resolution in GameController and dynamic lastWinner update on skin toggle', () async {
    SharedPreferences.setMockInitialValues({
      'unlockedNewHands': true,
      'showNewHands': true,
      'unlockedNewSkin': true,
      'showNewSkin': false,
      'musicEnabled': false,
    });
    await createController();

    // Default starting skin is Elemental Mode (Wu Xing 5-element):
    // Force deterministic PC move (Earth / lizard) and play Fire (rock)
    controller.crystalBallMove = HandMove.lizard;
    controller.playTurn(HandMove.rock);

    // In Wu Xing cycle: Earth smothers Fire -> Computer wins
    expect(controller.lastWinner, RoundWinner.computer);
    expect(controller.userScore, 0);
    expect(controller.pcScore, 1);

    // Toggle New Skin ON mid-match -> Changes from Elemental to Hands theme (Classic RPSLS)
    // Rock crushes Lizard, so lastWinner re-evaluates to user without resetting scores
    controller.toggleShowNewSkin(true);
    expect(controller.showNewSkin, isTrue);
    expect(controller.isElementalMode, isFalse);
    expect(controller.lastWinner, RoundWinner.user);
    expect(controller.userScore, 0);
    expect(controller.pcScore, 1);
    expect(controller.turnCount, 1);

    // Play a round in Hands mode (RPSLS): Rock vs Scissors -> Rock crushes Scissors (User wins +1 Wood orb!)
    controller.crystalBallMove = HandMove.scissors;
    controller.playTurn(HandMove.rock);
    expect(controller.lastWinner, RoundWinner.user);
    expect(controller.userScore, 1);
    expect(controller.pcScore, 1);
    expect(controller.woodOrbs, 1);

    // Play a round in Hands mode: Rock vs Paper -> Paper covers Rock (Computer wins!)
    controller.crystalBallMove = HandMove.paper;
    controller.playTurn(HandMove.rock);
    expect(controller.lastWinner, RoundWinner.computer);
    expect(controller.userScore, 1);
    expect(controller.pcScore, 2);

    // Play a tie round in Hands mode: Spock vs Spock -> Draw
    controller.crystalBallMove = HandMove.spock;
    controller.playTurn(HandMove.spock);
    expect(controller.lastWinner, RoundWinner.draw);
    expect(controller.userScore, 1);
    expect(controller.pcScore, 2);
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

  test('Completing a rewarded ad increments all 5 Elemental Orbs by 50, persists to SharedPreferences, and activates 2-minute cooldown', () async {
    SharedPreferences.setMockInitialValues({
      'orbs_fire': 10,
      'orbs_water': 20,
      'orbs_wood': 30,
      'orbs_earth': 5,
      'orbs_metal': 15,
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

    expect(controller.isRewardedAdReady, isTrue);

    bool rewardCallbackTriggered = false;
    final rewarded = await controller.watchRewardedAd(
      onRewardEarned: () {
        rewardCallbackTriggered = true;
      },
    );

    expect(rewarded, isTrue);
    expect(rewardCallbackTriggered, isTrue);
    expect(controller.fireOrbs, 60);
    expect(controller.waterOrbs, 70);
    expect(controller.woodOrbs, 80);
    expect(controller.earthOrbs, 55);
    expect(controller.metalOrbs, 65);
    expect(storage.fireOrbs, 60);
    expect(storage.waterOrbs, 70);
    expect(storage.woodOrbs, 80);
    expect(storage.earthOrbs, 55);
    expect(storage.metalOrbs, 65);
    expect(controller.isRewardedAdOnCooldown, isTrue);
    expect(controller.isRewardedAdReady, isFalse);
  });

  test('Unlocking Remove Ads deducts 2000 Fire/Water/Wood + 1500 Earth/Metal, disables banner display, and keeps rewarded ad available', () async {
    SharedPreferences.setMockInitialValues({
      'orbs_fire': 2500,
      'orbs_water': 2500,
      'orbs_wood': 2500,
      'orbs_earth': 2000,
      'orbs_metal': 2000,
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
    expect(controller.fireOrbs, 500);
    expect(controller.waterOrbs, 500);
    expect(controller.woodOrbs, 500);
    expect(controller.earthOrbs, 500);
    expect(controller.metalOrbs, 500);
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

  test('Predictability Score costs 15 Fire + 15 Water + 15 Wood, starts disabled, and tracks live stats in background while hidden', () async {
    SharedPreferences.setMockInitialValues({
      'orbs_fire': 14,
      'orbs_water': 15,
      'orbs_wood': 15,
      'musicEnabled': false,
    });
    await createController();

    // 14 Fire Orbs is insufficient for Predictability Score (15 Fire + 15 Water + 15 Wood)
    expect(controller.unlockPredictability(), isFalse);
    expect(controller.fireOrbs, 14);
    expect(controller.unlockedPredictability, isFalse);
    expect(controller.showPredictability, isFalse);
    expect(controller.isPredictabilityEnabled, isFalse);

    // Defeat AI Fire (rock) with Water (paper) -> awards +1 Fire Orb (now 15 Fire Orbs!)
    controller.crystalBallMove = HandMove.rock;
    controller.playTurn(HandMove.paper); // User wins +1 Fire Orb
    controller.crystalBallMove = HandMove.paper;
    controller.playTurn(HandMove.rock); // PC wins

    expect(controller.userScore, 1);
    expect(controller.playerScore, 1);
    expect(controller.pcScore, 1);
    expect(controller.totalRounds, 2);
    expect(controller.percentPredict, 50.0);

    // User now has 15 Fire, 15 Water, 15 Wood -> unlocks Predictability Score
    expect(controller.fireOrbs, 15);
    expect(controller.unlockPredictability(), isTrue);
    expect(controller.fireOrbs, 0);
    expect(controller.waterOrbs, 0);
    expect(controller.woodOrbs, 0);
    expect(controller.unlockedPredictability, isTrue);
    expect(controller.showPredictability, isFalse);
    expect(controller.isPredictabilityEnabled, isFalse);
    expect(storage.unlockedPredictability, isTrue);
    expect(storage.showPredictability, isFalse);

    // Toggling Predictability Score ON enables it with live background-tracked stats intact
    controller.toggleShowPredictability(true);
    expect(controller.showPredictability, isTrue);
    expect(controller.isPredictabilityEnabled, isTrue);
    expect(storage.showPredictability, isTrue);
    expect(controller.userScore, 1);
    expect(controller.pcScore, 1);
    expect(controller.totalRounds, 2);
    expect(controller.percentPredict, 50.0);
  });
}
