import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/help_dialog.dart';
import 'package:how_predictable/views/dialogs/settings_dialog.dart';
import 'package:how_predictable/views/widgets/elemental_matchup_diagram.dart';
import 'package:how_predictable/views/widgets/elemental_symbol_icon.dart';

Future<GameController> _createController({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_story_intro': true,
    'animationsEnabled': false,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();
  final localization = LocalizationService();
  await localization.load();
  final audio = AudioService();
  final controller = GameController(
    storage: storage,
    localization: localization,
    audio: audio,
  );
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HelpDialog & ElementalMatchupDiagram', () {
    testWidgets(
      'SettingsDialog -> Help opens updated copy and defaults to 3 Elements when Earth & Metal is inactive',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          prefs: {
            'unlockedNewHands': false,
            'showNewHands': false,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => SettingsDialog(controller: controller),
                      );
                    },
                    child: const Text('Open Settings'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();

        final helpBtn = find.byKey(const ValueKey('settings_help_button'));
        await tester.ensureVisible(helpBtn);
        await tester.tap(helpBtn);
        await tester.pumpAndSettle();

        // Updated Help copy without legacy prototype strings
        expect(find.textContaining('Cleric'), findsOneWidget);
        expect(find.textContaining('Metal Wizard'), findsOneWidget);
        expect(find.textContaining('Altar of Offerings'), findsOneWidget);
        expect(find.text('💡 Pro Tip: The Markov Model'), findsOneWidget);
        expect(find.textContaining('wined'), findsNothing);
        expect(find.textContaining('Rock Paper Scissors'), findsNothing);
        expect(find.textContaining('Master Hand'), findsNothing);

        // Diagram defaults to 3 Elements
        expect(
          find.byKey(const ValueKey('elemental_matchup_diagram')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('matchup_orb_fire')), findsOneWidget);
        expect(find.byKey(const ValueKey('matchup_orb_water')), findsOneWidget);
        expect(find.byKey(const ValueKey('matchup_orb_wood')), findsOneWidget);
        expect(find.byKey(const ValueKey('matchup_orb_earth')), findsNothing);
        expect(find.byKey(const ValueKey('matchup_orb_metal')), findsNothing);
        expect(
          find.text('Tap an element to see matchups'),
          findsOneWidget,
        );

        // Tap Fire to inspect 3-element matchup
        await tester.tap(find.byKey(const ValueKey('matchup_orb_fire')));
        await tester.pumpAndSettle();
        expect(
          find.text('Fire defeats Wood • Loses to Water'),
          findsOneWidget,
        );

        // Tap Fire again to clear selection
        await tester.tap(find.byKey(const ValueKey('matchup_orb_fire')));
        await tester.pumpAndSettle();
        expect(
          find.text('Tap an element to see matchups'),
          findsOneWidget,
        );

        // Switch to 5 Elements -> Earth & Metal appear
        await tester.tap(find.byKey(const ValueKey('matchup_mode_5_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('matchup_orb_earth')), findsOneWidget);
        expect(find.byKey(const ValueKey('matchup_orb_metal')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('matchup_orb_fire')));
        await tester.pumpAndSettle();
        expect(
          find.text('Fire defeats Wood & Metal • Loses to Water & Earth'),
          findsOneWidget,
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'HelpDialog defaults to 5 Elements when Unlock Earth & Metal is enabled and supports tapping Earth/Metal and switching back to 3 Elements',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          prefs: {
            'unlockedNewHands': true,
            'showNewHands': true,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: Scaffold(
              body: Builder(
                builder: (context) => SettingsDialog(controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final helpBtn = find.byKey(const ValueKey('settings_help_button'));
        await tester.ensureVisible(helpBtn);
        await tester.tap(helpBtn);
        await tester.pumpAndSettle();

        // Defaults to 5 Elements
        expect(find.byKey(const ValueKey('matchup_orb_earth')), findsOneWidget);
        expect(find.byKey(const ValueKey('matchup_orb_metal')), findsOneWidget);

        // Tap Earth
        final earthOrb = find.byKey(const ValueKey('matchup_orb_earth'));
        await tester.ensureVisible(earthOrb);
        await tester.tap(earthOrb);
        await tester.pumpAndSettle();
        expect(
          find.text('Earth defeats Fire & Water • Loses to Wood & Metal'),
          findsOneWidget,
        );

        // Toggle back to 3 Elements resets Earth selection cleanly
        final mode3Btn = find.byKey(const ValueKey('matchup_mode_3_button'));
        await tester.ensureVisible(mode3Btn);
        await tester.tap(mode3Btn);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('matchup_orb_earth')), findsNothing);
        expect(find.byKey(const ValueKey('matchup_orb_metal')), findsNothing);
        expect(
          find.text('Tap an element to see matchups'),
          findsOneWidget,
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'HelpDialog and ElementalMatchupDiagram localize cleanly across en, pt, es, and de without legacy text',
      (WidgetTester tester) async {
        final expectedHelpFragments = {
          'en': ('Cleric', '3 Elements', '5 Elements', 'Fire defeats Wood & Metal • Loses to Water & Earth'),
          'pt': ('Clérigo', '3 Elementos', '5 Elementos', 'Fogo vence Madeira e Metal • Perde para Água e Terra'),
          'es': ('Clérigo', '3 Elementos', '5 Elementos', 'Fuego vence a Madera y Metal • Pierde ante Agua y Tierra'),
          'de': ('Kleriker', '3 Elemente', '5 Elemente', 'Feuer besiegt Holz & Metall • Verliert gegen Wasser & Erde'),
        };

        for (final lang in LocalizationService.supportedLanguages) {
          final loc = LocalizationService();
          await loc.load();
          loc.setLanguage(lang);

          final (clericWord, label3, label5, fireSummary) =
              expectedHelpFragments[lang]!;

          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('help_loc_app_$lang'),
              theme: ThemeData.dark(useMaterial3: true),
              home: Scaffold(
                body: HelpDialog(
                  localization: loc,
                  initialFiveElements: true,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.textContaining(clericWord), findsOneWidget);
          expect(find.text(label3), findsOneWidget);
          expect(find.text(label5), findsOneWidget);
          expect(find.textContaining('wined'), findsNothing);
          expect(find.textContaining('Rock Paper Scissors'), findsNothing);
          expect(find.textContaining('Master Hand'), findsNothing);
          expect(find.textContaining('Mão Mestre'), findsNothing);
          expect(find.textContaining('Mano Maestra'), findsNothing);
          expect(find.textContaining('Meister Hand'), findsNothing);

          final fireOrb = find.byKey(const ValueKey('matchup_orb_fire'));
          await tester.ensureVisible(fireOrb);
          await tester.tap(fireOrb);
          await tester.pumpAndSettle();
          expect(find.text(fireSummary), findsOneWidget);
        }
      },
    );

    testWidgets(
      'ElementalMatchupDiagram renders cleanly in Light and Dark mode at narrow 300px width',
      (WidgetTester tester) async {
        final loc = LocalizationService();
        await loc.load();

        for (final brightness in [Brightness.light, Brightness.dark]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness, useMaterial3: true),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 280,
                    child: ElementalMatchupDiagram(
                      localization: loc,
                      initialFiveElements: true,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'ElementalMatchupDiagram positions Fire label above top orb, Earth/Wood labels outward-left/right in 5-element mode, and bottom labels below orbs',
      (WidgetTester tester) async {
        final loc = LocalizationService();
        await loc.load();
        loc.setLanguage('en');

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: ElementalMatchupDiagram(
                    localization: loc,
                    initialFiveElements: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        Offset orbCenter(String orbKey) => tester.getCenter(
              find.descendant(
                of: find.byKey(ValueKey('matchup_orb_$orbKey')),
                matching: find.byType(ElementalSymbolIcon),
              ),
            );

        Offset labelCenter(String label) => tester.getCenter(find.text(label));

        // 5-Element Pentagon:
        // Fire label is ABOVE Fire orb
        expect(labelCenter('Fire').dy, lessThan(orbCenter('fire').dy));
        // Earth label is OUTER-LEFT & below Earth orb
        expect(labelCenter('Earth').dx, lessThan(orbCenter('earth').dx));
        expect(labelCenter('Earth').dy, greaterThan(orbCenter('earth').dy));
        // Wood label is OUTER-RIGHT & below Wood orb
        expect(labelCenter('Wood').dx, greaterThan(orbCenter('wood').dx));
        expect(labelCenter('Wood').dy, greaterThan(orbCenter('wood').dy));
        // Metal & Water labels are BELOW their orbs
        expect(labelCenter('Metal').dy, greaterThan(orbCenter('metal').dy));
        expect(labelCenter('Water').dy, greaterThan(orbCenter('water').dy));

        // Switch to 3-Element Triangle:
        await tester.tap(find.byKey(const ValueKey('matchup_mode_3_button')));
        await tester.pumpAndSettle();

        expect(labelCenter('Fire').dy, lessThan(orbCenter('fire').dy));
        expect(labelCenter('Water').dy, greaterThan(orbCenter('water').dy));
        expect(labelCenter('Wood').dy, greaterThan(orbCenter('wood').dy));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
