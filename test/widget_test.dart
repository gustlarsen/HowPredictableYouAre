import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howpredictable/controllers/game_controller.dart';
import 'package:howpredictable/main.dart';
import 'package:howpredictable/services/audio_service.dart';
import 'package:howpredictable/services/localization_service.dart';
import 'package:howpredictable/services/markov_engine.dart';
import 'package:howpredictable/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Screen1 renders gameplay, shop, settings, and achievements views',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = GameController(
      storage: StorageService(),
      localization: LocalizationService(),
      markovEngine: MarkovEngine(random: Random(7)),
      audio: AudioService(enabledInEnvironment: false),
    );
    await controller.initialize(deviceLanguageOverride: 'en');

    await tester.pumpWidget(HowPredictableApp(controller: controller));
    await tester.pump();

    expect(find.byKey(const Key('Vertical_ArrNormal')), findsOneWidget);
    expect(find.byKey(const Key('RockButton')), findsOneWidget);
    expect(find.byKey(const Key('PaperButton')), findsOneWidget);
    expect(find.byKey(const Key('ScissorsButton')), findsOneWidget);

    // Play a round by tapping ROCK
    await tester.tap(find.byKey(const Key('RockButton')));
    await tester.pump();
    expect(controller.total, 1);

    // Navigate to Shop
    await tester.tap(find.byKey(const Key('ButtonShop')));
    await tester.pump();
    expect(find.byKey(const Key('Vertical_ArrShoppingCart')), findsOneWidget);

    // Navigate to Settings
    await tester.tap(find.byKey(const Key('ButtonSettings')));
    await tester.pump();
    expect(find.byKey(const Key('Vertical_ArrSettings')), findsOneWidget);

    // Navigate back to Normal view
    await tester.tap(find.byKey(const Key('ButtonSettingsBack')));
    await tester.pump();
    expect(find.byKey(const Key('Vertical_ArrNormal')), findsOneWidget);

    // Complete pending round animation timer
    await tester.pump(const Duration(milliseconds: 2600));
    controller.dispose();
  });
}
