import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/controllers/game_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test loads GameScreen and displays title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();

    final localization = LocalizationService();
    // No asset bundle in basic widget test, localization will use fallbacks

    final audio = AudioService();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GameController(
          storage: storage,
          localization: localization,
          audio: audio,
        ),
        child: const HowPredictableApp(),
      ),
    );

    expect(find.text('How Predictable You Are'), findsOneWidget);
    expect(find.text('ROCK'), findsOneWidget);
    expect(find.text('PAPER'), findsOneWidget);
    expect(find.text('SCISSORS'), findsOneWidget);

    final controller = tester.element(find.text('How Predictable You Are')).read<GameController>();
    expect(controller.turnCount, 0);

    // Tap ROCK and verify immediate response without waiting for button animation
    await tester.tap(find.text('ROCK'));
    await tester.pump();
    expect(controller.turnCount, 1);

    // Advance partway through the 2-second animation (e.g., 800ms)
    await tester.pump(const Duration(milliseconds: 800));

    // Tap ROCK again mid-animation: should immediately increment turnCount and restart animation
    await tester.tap(find.text('ROCK'));
    await tester.pump();
    expect(controller.turnCount, 2);

    // Let the 2-second animation complete
    await tester.pump(const Duration(milliseconds: 2100));
  });
}
