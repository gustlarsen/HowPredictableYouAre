import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';

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

  test('Game starts with 100000 diamonds by default', () async {
    SharedPreferences.setMockInitialValues({
      'musicEnabled': false,
    });
    await createController();

    expect(storage.diamonds, 100000);
    expect(controller.diamonds, 100000);
  });

  test('Reset purchase unlocks and shows the reset action', () async {
    SharedPreferences.setMockInitialValues({
      'diamonds': 100,
      'musicEnabled': false,
    });
    await createController();

    controller.unlockReset();

    expect(controller.diamonds, 0);
    expect(controller.unlockedReset, isTrue);
    expect(controller.showReset, isTrue);
    expect(storage.unlockedReset, isTrue);
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
    'Vibration is enabled by default and follows the saved setting',
    () async {
      await createController(resetPreferences: true);

      expect(controller.vibrationEnabled, isTrue);
      expect(audio.vibrationEnabled, isTrue);

      controller.toggleVibration(false);
      expect(controller.vibrationEnabled, isFalse);
      expect(audio.vibrationEnabled, isFalse);
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

  test('Crystal Ball purchase costs 100000 diamonds and can be toggled', () async {
    SharedPreferences.setMockInitialValues({
      'diamonds': 100000,
      'musicEnabled': false,
    });
    await createController();

    expect(controller.unlockedCrystalBall, isFalse);
    expect(controller.showCrystalBall, isFalse);

    final ok = controller.unlockCrystalBall();
    expect(ok, isTrue);
    expect(controller.diamonds, 0);
    expect(controller.unlockedCrystalBall, isTrue);
    expect(controller.showCrystalBall, isTrue);
    expect(storage.unlockedCrystalBall, isTrue);
    expect(storage.showCrystalBall, isTrue);

    controller.toggleShowCrystalBall(false);
    expect(controller.showCrystalBall, isFalse);
    expect(storage.showCrystalBall, isFalse);
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
}
