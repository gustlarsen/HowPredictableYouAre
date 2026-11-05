import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:howpredictable/controllers/game_controller.dart';
import 'package:howpredictable/services/audio_service.dart';
import 'package:howpredictable/services/localization_service.dart';
import 'package:howpredictable/services/markov_engine.dart';
import 'package:howpredictable/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameController & Persistence', () {
    late GameController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      controller = GameController(
        storage: StorageService(),
        localization: LocalizationService(),
        markovEngine: MarkovEngine(random: Random(1)),
        audio: AudioService(enabledInEnvironment: false),
      );
      await controller.initialize(deviceLanguageOverride: 'en');
    });

    tearDown(() {
      controller.dispose();
    });

    test('loads default state and persists gameplay scores and matrix to SharedPreferences', () async {
      expect(controller.total, 0);
      expect(controller.diamonds, 0);
      expect(controller.evaluationText, 'Under Evaluation');

      await controller.playRound(MarkovEngine.rock);
      await controller.playRound(MarkovEngine.paper);
      await controller.playRound(MarkovEngine.scissors);

      expect(controller.total, 3);

      // Re-instantiate controller to verify TinyDB / SharedPreferences persistence
      final restored = GameController(
        storage: StorageService(),
        localization: LocalizationService(),
        markovEngine: MarkovEngine(random: Random(1)),
        audio: AudioService(enabledInEnvironment: false),
      );
      await restored.initialize(deviceLanguageOverride: 'en');

      expect(restored.total, 3);
      expect(restored.userScore, controller.userScore);
      expect(restored.pcScore, controller.pcScore);
      expect(restored.markovEngine.matrix, controller.markovEngine.matrix);
      restored.dispose();
    });

    test('unlocks shop items with diamonds, toggles checkboxes, and rejects when insufficient', () async {
      // Insufficient diamonds for Reset (costs 100)
      final failedUnlock = await controller.unlockReset();
      expect(failedUnlock, isFalse);
      expect(controller.reset, 0);
      expect(controller.consumeAlertMessage(), 'Not enough Diamonds');

      // Add 1000 diamonds via secret button
      await controller.onButtonSecretClick();
      expect(controller.diamonds, 1000);

      // Unlock Reset (100), Predictability (150), Show Algorithm (500)
      expect(await controller.unlockReset(), isTrue);
      expect(controller.diamonds, 900);
      expect(controller.reset, 1); // Unlocked, Disabled initially

      await controller.toggleResetCheckbox(true);
      expect(controller.reset, 2); // Enabled

      expect(await controller.unlockPredictability(), isTrue);
      expect(controller.diamonds, 750);
      await controller.togglePredictabilityCheckbox(true);
      expect(controller.predictability, 2);

      expect(await controller.unlockAlgorithm(), isTrue);
      expect(controller.diamonds, 250);
      await controller.toggleAlgorithmCheckbox(true);
      expect(controller.algorithm, 2);
    });

    test('switches languages and updates evaluation tiers at 100 rounds', () async {
      await controller.selectLanguageFromSpinner('Português');
      expect(controller.language, 'pt');
      expect(controller.evaluationText, 'Sob avaliação');

      await controller.selectLanguageFromSpinner('English');
      expect(controller.language, 'en');

      // Simulate 99 rounds played with 0 PC wins
      controller.total = 99;
      controller.userScore = 99;
      controller.pcScore = 0;
      controller.lastUserChoice = MarkovEngine.rock;

      // Play 100th round -> triggers 100-round dialog
      await controller.playRound(MarkovEngine.scissors);
      expect(controller.total, 100);
      expect(controller.show100RoundDialog, isTrue);
      expect(controller.isLabel100RoundsVisible, isFalse);

      // Reset game via TRY AGAIN selection
      await controller.handle100RoundDialogSelection('TRY AGAIN');
      expect(controller.total, 0);
      expect(controller.userScore, 0);
      expect(controller.pcScore, 0);
    });
  });
}

