import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
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

    controller.resetGame();

    expect(controller.userScore, 0);
    expect(controller.pcScore, 0);
    expect(controller.totalRounds, 0);
  });
}
