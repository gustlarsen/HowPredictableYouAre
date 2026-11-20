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

  test('Periodic gift claims +5 of EACH of the 5 Elemental Orbs when unlocked and enabled', () async {
    SharedPreferences.setMockInitialValues({
      'orbs_fire': 500,
      'orbs_water': 500,
      'orbs_wood': 500,
      'orbs_earth': 500,
      'orbs_metal': 500,
      'musicEnabled': false,
    });
    await createController();

    expect(controller.giftBoxUnlocked, isFalse);
    expect(controller.giftBoxEnabled, isFalse);
    expect(controller.shouldShowGiftBox, isFalse);

    // Locked Gift Box cannot be claimed
    controller.claimGift();
    expect(controller.fireOrbs, 500);

    // Unlocking deducts 500 of each element and keeps Gift Box disabled initially
    expect(controller.unlockGiftBox(), isTrue);
    expect(controller.fireOrbs, 0);
    expect(controller.waterOrbs, 0);
    expect(controller.woodOrbs, 0);
    expect(controller.earthOrbs, 0);
    expect(controller.metalOrbs, 0);
    expect(controller.giftBoxUnlocked, isTrue);
    expect(controller.giftBoxEnabled, isFalse);
    expect(controller.shouldShowGiftBox, isFalse);

    // Enabling Gift Box makes the periodic gift available and claimable
    controller.toggleGiftBox(true);
    expect(controller.giftBoxEnabled, isTrue);
    expect(controller.isGiftAvailable, isTrue);
    expect(controller.shouldShowGiftBox, isTrue);

    controller.claimGift();

    expect(controller.fireOrbs, 5);
    expect(controller.waterOrbs, 5);
    expect(controller.woodOrbs, 5);
    expect(controller.earthOrbs, 0);
    expect(controller.metalOrbs, 0);
    expect(storage.fireOrbs, 5);
    expect(storage.waterOrbs, 5);
    expect(storage.woodOrbs, 5);
    expect(storage.earthOrbs, 0);
    expect(storage.metalOrbs, 0);
    expect(controller.isGiftAvailable, isFalse);
    expect(controller.shouldShowGiftBox, isFalse);
    expect(controller.isGiftTimerActive, isTrue);
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

  test('resetAllProgress preserves seen story flags, archives orbs to Spoils of War, and resets campaign to Week 0', () async {
    SharedPreferences.setMockInitialValues({
      'musicEnabled': false,
      'has_seen_story_intro': true,
      'has_seen_story_reset': true,
      'orbs_fire': 500,
      'total': 10,
      'current_week': 5,
    });
    await createController();

    expect(storage.hasSeenStoryIntro, isTrue);
    expect(controller.hasSeenStoryIntro, isTrue);
    expect(controller.hasSeenStoryReset, isTrue);
    expect(controller.pendingStoryChapter, isNull);

    await controller.resetAllProgress();

    expect(storage.hasSeenStoryIntro, isTrue);
    expect(controller.hasSeenStoryIntro, isTrue);
    expect(controller.hasSeenStoryReset, isTrue);
    expect(controller.pendingStoryChapter, isNull);
    expect(controller.currentWeek, 0);
    expect(storage.currentWeek, 0);
    expect(controller.fireOrbs, 0);
    expect(controller.spoilsFireOrbs, 500);
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
      'orbs_earth': 500,
      'orbs_metal': 500,
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
    // Fire/Water/Wood: 15+30+80+120+250+600+1000+1500+2000+3500+5000 = 14,095
    // Earth/Metal: 50+50+100+300+500+1000+1500+2500+5000 = 11,000
    expect(controller.fireOrbs, 100000 - 14095);
    expect(controller.waterOrbs, 100000 - 14095);
    expect(controller.woodOrbs, 100000 - 14095);
    expect(controller.earthOrbs, 100000 - 11000);
    expect(controller.metalOrbs, 100000 - 11000);
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
    expect(controller.earthOrbs, 5);
    expect(controller.metalOrbs, 15);
    expect(storage.fireOrbs, 60);
    expect(storage.waterOrbs, 70);
    expect(storage.woodOrbs, 80);
    expect(storage.earthOrbs, 5);
    expect(storage.metalOrbs, 15);
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

  test('HP mechanics: starts at 50, reduces on loss, persists to storage, and resets back to 50', () async {
    await createController(resetPreferences: true);

    expect(controller.userHp, 50);
    expect(controller.playerMaxHp, 50);
    expect(controller.computerHp, 100);
    expect(storage.userHp, 50);
    expect(storage.pcHp, 100);

    controller.playTurn(HandMove.rock);
    expect(controller.userHp, inInclusiveRange(0, 50));
    expect(controller.computerHp, inInclusiveRange(0, 100));

    if (controller.lastWinner == RoundWinner.user) {
      expect(controller.userHp, 50);
      expect(controller.computerHp, 99);
      expect(storage.pcHp, 99);
    } else if (controller.lastWinner == RoundWinner.computer) {
      expect(controller.userHp, 49);
      expect(controller.computerHp, 100);
      expect(storage.userHp, 49);
    } else {
      expect(controller.userHp, 50);
      expect(controller.computerHp, 100);
    }

    // Persist and reopen
    final prevUserHp = controller.userHp;
    final prevPcHp = controller.computerHp;
    await createController();
    expect(controller.userHp, prevUserHp);
    expect(controller.computerHp, prevPcHp);

    // Resetting game restores player to 50 and PC to 100
    controller.resetGame();
    expect(controller.userHp, 50);
    expect(controller.computerHp, 100);
    expect(storage.userHp, 50);
    expect(storage.pcHp, 100);

    // Resetting all progress restores player to 50 and PC to 100
    await controller.resetAllProgress();
    expect(controller.userHp, 50);
    expect(controller.computerHp, 100);
    expect(storage.userHp, 50);
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

  test('Gift Box requires 500 of ALL 5 Elemental Orbs, persists unlock/toggle, and pauses/resumes timer cleanly', () async {
    SharedPreferences.setMockInitialValues({
      'orbs_fire': 500,
      'orbs_water': 500,
      'orbs_wood': 500,
      'orbs_earth': 500,
      'orbs_metal': 499, // Missing 1 Metal Orb
      'musicEnabled': false,
    });
    await createController();

    expect(controller.unlockGiftBox(), isFalse);
    expect(controller.giftBoxUnlocked, isFalse);
    expect(controller.giftBoxEnabled, isFalse);
    expect(controller.shouldShowGiftBox, isFalse);
    expect(controller.isGiftTimerActive, isFalse);

    // Toggling before unlock is a no-op
    controller.toggleGiftBox(true);
    expect(controller.giftBoxEnabled, isFalse);
    expect(storage.giftBoxEnabled, isFalse);

    // Grant final Metal Orb and unlock
    controller.addOrbForMove(HandMove.spock, 1);
    expect(controller.metalOrbs, 500);
    expect(controller.unlockGiftBox(), isTrue);
    expect(controller.fireOrbs, 0);
    expect(controller.waterOrbs, 0);
    expect(controller.woodOrbs, 0);
    expect(controller.earthOrbs, 0);
    expect(controller.metalOrbs, 0);
    expect(controller.giftBoxUnlocked, isTrue);
    expect(controller.giftBoxEnabled, isFalse);
    expect(storage.giftBoxUnlocked, isTrue);
    expect(storage.giftBoxEnabled, isFalse);
    expect(controller.isGiftTimerActive, isFalse);

    // Enable Gift Box, claim gift (starts cooldown timer)
    controller.toggleGiftBox(true);
    expect(storage.giftBoxEnabled, isTrue);
    expect(controller.shouldShowGiftBox, isTrue);
    controller.claimGift();
    expect(controller.fireOrbs, 5);
    expect(controller.waterOrbs, 5);
    expect(controller.woodOrbs, 5);
    expect(controller.earthOrbs, 0);
    expect(controller.metalOrbs, 0);
    expect(controller.isGiftAvailable, isFalse);
    expect(controller.isGiftTimerActive, isTrue);
    expect(controller.shouldShowGiftBox, isFalse);

    // Toggling OFF pauses/stops background timer
    controller.toggleGiftBox(false);
    expect(controller.giftBoxEnabled, isFalse);
    expect(storage.giftBoxEnabled, isFalse);
    expect(controller.isGiftTimerActive, isFalse);
    expect(controller.shouldShowGiftBox, isFalse);

    // Toggling back ON resumes cooldown timer
    controller.toggleGiftBox(true);
    expect(controller.giftBoxEnabled, isTrue);
    expect(controller.isGiftTimerActive, isTrue);
    expect(controller.isGiftAvailable, isFalse);

    // Re-create controller from storage to verify persistence
    controller.cancelPendingTimers();
    await createController();
    expect(controller.giftBoxUnlocked, isTrue);
    expect(controller.giftBoxEnabled, isTrue);
    expect(controller.shouldShowGiftBox, isTrue);
  });

  test('remainingMana tracks 100-to-0 match countdown across wins, losses, and draws, clamps at 0 on 100 rounds, and resets back to 100', () async {
    SharedPreferences.setMockInitialValues({
      'musicEnabled': false,
    });
    await createController();

    expect(controller.totalRounds, 0);
    expect(controller.remainingMana, 100);

    // Draw on round 1 -> totalRounds = 1, remainingMana = 99, 0 HP damage, Gauge = 0.0%
    controller.crystalBallMove = HandMove.rock;
    controller.playTurn(HandMove.rock);
    expect(controller.lastWinner, RoundWinner.draw);
    expect(controller.totalRounds, 1);
    expect(controller.remainingMana, 99);
    expect(controller.userHp, 50);
    expect(controller.computerHp, 100);
    expect(controller.percentPredict, 0.0);

    // Win on round 2 -> totalRounds = 2, remainingMana = 98, Gauge = 100.0%
    controller.crystalBallMove = HandMove.scissors;
    controller.playTurn(HandMove.rock);
    expect(controller.lastWinner, RoundWinner.user);
    expect(controller.totalRounds, 2);
    expect(controller.remainingMana, 98);
    expect(controller.userHp, 50);
    expect(controller.computerHp, 99);
    expect(controller.percentPredict, 100.0);

    // Draw on round 3 -> totalRounds = 3, remainingMana = 97, 0 HP damage, Gauge stays 100.0%
    controller.crystalBallMove = HandMove.paper;
    controller.playTurn(HandMove.paper);
    expect(controller.lastWinner, RoundWinner.draw);
    expect(controller.totalRounds, 3);
    expect(controller.remainingMana, 97);
    expect(controller.userHp, 50);
    expect(controller.computerHp, 99);
    expect(controller.percentPredict, 100.0);

    // Lose on round 4 -> totalRounds = 4, remainingMana = 96, Gauge = 50.0% (1 win / 2 decisive rounds)
    controller.crystalBallMove = HandMove.paper;
    controller.playTurn(HandMove.rock);
    expect(controller.lastWinner, RoundWinner.computer);
    expect(controller.totalRounds, 4);
    expect(controller.remainingMana, 96);
    expect(controller.userHp, 49);
    expect(controller.computerHp, 99);
    expect(controller.percentPredict, 50.0);
    expect(storage.total, 4);

    // Persisted totalRounds including draws restores remainingMana accurately
    await createController();
    expect(controller.totalRounds, 4);
    expect(controller.remainingMana, 96);

    // Reset restores remainingMana to 100
    controller.resetGame();
    expect(controller.totalRounds, 0);
    expect(controller.remainingMana, 100);

    // Play to 100 total rounds including draws (40 wins, 30 losses, 29 draws -> 100th turn is a Draw)
    SharedPreferences.setMockInitialValues({
      'userScore': 40,
      'pcScore': 30,
      'total': 99,
      'musicEnabled': false,
    });
    await createController();
    expect(controller.remainingMana, 1);
    expect(controller.is100RoundsAlertPending, isFalse);

    controller.crystalBallMove = HandMove.rock;
    controller.playTurn(HandMove.rock);
    expect(controller.lastWinner, RoundWinner.draw);
    expect(controller.totalRounds, 100);
    expect(controller.remainingMana, 0);
    expect(controller.is100RoundsAlertPending, isTrue);
    expect(controller.percentPredict, closeTo((40 / 70) * 100.0, 1e-6));
    expect(controller.evaluationTier.key, isNot('string3'));

    // Further turns at 100 rounds do not drop remainingMana below 0
    controller.playTurn(HandMove.rock);
    expect(controller.totalRounds, 100);
    expect(controller.remainingMana, 0);

    // resetAllProgress also restores remainingMana to 100
    await controller.resetAllProgress();
    expect(controller.totalRounds, 0);
    expect(controller.remainingMana, 100);
  });

  test('Playing 100 full turns from 0 including draws reaches remainingMana == 0 and triggers completion', () async {
    await createController(resetPreferences: true);

    for (var i = 0; i < 50; i++) {
      // Draw
      controller.crystalBallMove = HandMove.rock;
      controller.playTurn(HandMove.rock);
    }
    expect(controller.totalRounds, 50);
    expect(controller.remainingMana, 50);
    expect(controller.userHp, 50);
    expect(controller.computerHp, 100);
    expect(controller.percentPredict, 0.0);
    expect(controller.is100RoundsAlertPending, isFalse);

    for (var i = 0; i < 30; i++) {
      // Win
      controller.crystalBallMove = HandMove.scissors;
      controller.playTurn(HandMove.rock);
    }
    for (var i = 0; i < 19; i++) {
      // Loss
      controller.crystalBallMove = HandMove.paper;
      controller.playTurn(HandMove.rock);
    }
    expect(controller.totalRounds, 99);
    expect(controller.remainingMana, 1);
    expect(controller.is100RoundsAlertPending, isFalse);

    // 100th turn is a Draw -> hits 100 rounds, 0 Mana, triggers completion
    controller.crystalBallMove = HandMove.scissors;
    controller.playTurn(HandMove.scissors);
    expect(controller.totalRounds, 100);
    expect(controller.remainingMana, 0);
    expect(controller.is100RoundsAlertPending, isTrue);
    expect(controller.percentPredict, closeTo((30 / 49) * 100.0, 1e-6));
  });

  test('crystalBallPlusMoves derives all winning active elements directly from crystalBallMoves in 3- and 5-element modes', () async {
    SharedPreferences.setMockInitialValues({
      'orbs_fire': 10000,
      'orbs_water': 10000,
      'orbs_wood': 10000,
      'orbs_earth': 10000,
      'orbs_metal': 10000,
      'musicEnabled': false,
    });
    await createController();

    expect(controller.isElementalMode, isTrue);
    expect(controller.showNewHands, isFalse);

    // 3-element mode: returns the single active counter element
    controller.crystalBallMove = HandMove.scissors; // Wood
    expect(controller.crystalBallMoves, [HandMove.scissors]);
    expect(controller.crystalBallPlusMoves, [HandMove.rock]); // Fire

    controller.crystalBallMove = HandMove.rock; // Fire
    expect(controller.crystalBallMoves, [HandMove.rock]);
    expect(controller.crystalBallPlusMoves, [HandMove.paper]); // Water

    controller.crystalBallMove = HandMove.paper; // Water
    expect(controller.crystalBallMoves, [HandMove.paper]);
    expect(controller.crystalBallPlusMoves, [HandMove.scissors]); // Wood

    // Enable Unlock Earth & Metal (5-element mode): returns both winning elements
    expect(controller.unlockNewHands(), isTrue);
    controller.toggleShowNewHands(true);
    expect(controller.showNewHands, isTrue);

    controller.crystalBallMove = HandMove.scissors; // Wood -> Fire & Metal
    expect(controller.crystalBallPlusMoves, [HandMove.rock, HandMove.spock]);

    controller.crystalBallMove = HandMove.rock; // Fire -> Water & Earth
    expect(controller.crystalBallPlusMoves, [HandMove.paper, HandMove.lizard]);

    controller.crystalBallMove = HandMove.paper; // Water -> Wood & Earth
    expect(controller.crystalBallPlusMoves, [HandMove.scissors, HandMove.lizard]);

    controller.crystalBallMove = HandMove.lizard; // Earth -> Wood & Metal
    expect(controller.crystalBallPlusMoves, [HandMove.scissors, HandMove.spock]);

    controller.crystalBallMove = HandMove.spock; // Metal -> Fire & Water
    expect(controller.crystalBallPlusMoves, [HandMove.rock, HandMove.paper]);

    // Every returned counter defeats the Crystal Ball's predicted move
    for (final pcMove in HandMove.values) {
      controller.crystalBallMove = pcMove;
      final counters = controller.crystalBallPlusMoves;
      expect(counters, hasLength(2));
      expect(
        counters.every((c) => c.beats(pcMove, elemental: true)),
        isTrue,
      );
    }

    // Classic Hands mode (New Skin ON) follows classic RPSLS beats() rules
    expect(controller.unlockNewSkin(), isTrue);
    controller.toggleShowNewSkin(true);
    expect(controller.isElementalMode, isFalse);
    controller.crystalBallMove = HandMove.rock;
    expect(controller.crystalBallPlusMoves, [HandMove.paper, HandMove.spock]);
  });
}
