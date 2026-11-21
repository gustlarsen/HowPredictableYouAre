import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/observatory_dialog.dart';
import 'package:how_predictable/views/dialogs/watchtower_spyglass_dialog.dart';
import 'package:how_predictable/views/widgets/watch_tower_icon.dart';
import 'package:how_predictable/views/widgets/watchtower_cell_shader_view.dart';

Future<GameController> _createController({
  String language = 'en',
  bool animationsEnabled = false,
  bool darkMode = true,
}) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_story_intro': true,
    'darkMode': darkMode,
    'animationsEnabled': animationsEnabled,
    'musicEnabled': false,
    'soundEnabled': false,
    'language': language,
  });
  final storage = StorageService();
  await storage.init();
  final localization = LocalizationService();
  await localization.load();
  localization.setLanguage(language);
  final audio = AudioService();

  return GameController(
    storage: storage,
    localization: localization,
    audio: audio,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Watch Tower Spy on Dungeon & Spyglass Dialog Tests', () {
    testWidgets(
      'Spy on Dungeon button appears above Open Story Log in Watch Tower dialog and opens Spyglass view cleanly',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          language: 'en',
          animationsEnabled: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) =>
                            ObservatoryDialog(controller: controller),
                      );
                    },
                    child: const Text('Open Watch Tower'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Watch Tower'));
        await tester.pumpAndSettle();

        expect(find.byType(ObservatoryDialog), findsOneWidget);
        expect(find.text("Star-Gazer's Strategy Hints"), findsOneWidget);
        expect(find.text('Markov Insight'), findsOneWidget);

        final spyBtn = find.byKey(
          const ValueKey('observatory_spy_dungeon_button'),
        );
        final storyBtn = find.byKey(
          const ValueKey('observatory_story_log_button'),
        );
        expect(spyBtn, findsOneWidget);
        expect(storyBtn, findsOneWidget);
        expect(find.text('Spy on Dungeon'), findsOneWidget);

        // Leading WatchTowerIcon inside the Spy on Dungeon button
        expect(
          find.descendant(of: spyBtn, matching: find.byType(WatchTowerIcon)),
          findsOneWidget,
        );

        // Positioned right above Open Story Log button
        final spyRect = tester.getRect(spyBtn);
        final storyRect = tester.getRect(storyBtn);
        expect(spyRect.bottom, lessThanOrEqualTo(storyRect.top));

        // Tap Spy on Dungeon -> opens WatchtowerSpyglassDialog
        await tester.ensureVisible(spyBtn);
        await tester.pumpAndSettle();
        await tester.tap(spyBtn);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(WatchtowerSpyglassDialog), findsOneWidget);
        expect(find.byType(WatchtowerCellShaderView), findsOneWidget);
        expect(find.text('Dungeon Spyglass'), findsOneWidget);
        expect(
          find.text(
            'Through the Watch Tower lens, the captive Princess awaits rescue...',
          ),
          findsOneWidget,
        );

        final closeBtn = find.byKey(
          const ValueKey('watchtower_spyglass_close_button'),
        );
        expect(closeBtn, findsOneWidget);
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();

        expect(find.byType(WatchtowerSpyglassDialog), findsNothing);
        expect(find.byType(ObservatoryDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Spy on Dungeon button displays correct translations for en, pt, es, de',
      (WidgetTester tester) async {
        const expected = {
          'en': 'Spy on Dungeon',
          'pt': 'Espiar Masmorra',
          'es': 'Espiar Mazmorra',
          'de': 'Verlies ausspähen',
        };

        for (final entry in expected.entries) {
          final controller = await _createController(
            language: entry.key,
            animationsEnabled: false,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: ObservatoryDialog(controller: controller),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(entry.value), findsOneWidget);
        }
      },
    );

    testWidgets(
      'WatchtowerCellShaderView static CI fallback and animated mode render and dispose cleanly',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 320,
                child: WatchtowerCellShaderView(
                  animationsEnabled: false,
                  forceStaticFallback: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('watchtower_spyglass_fallback_stack')),
          findsOneWidget,
        );
        expect(find.byType(Image), findsNWidgets(2));
        expect(tester.takeException(), isNull);

        // Also test normal animated construction & disposal without crashing
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 320,
                child: WatchtowerCellShaderView(animationsEnabled: true),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(WatchtowerCellShaderView), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Unmount cleanly
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
