import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/full_screen_spyglass_view.dart';
import 'package:how_predictable/views/dialogs/metal_wizard_spyglass_dialog.dart';
import 'package:how_predictable/views/dialogs/observatory_dialog.dart';
import 'package:how_predictable/views/dialogs/watchtower_spyglass_dialog.dart';
import 'package:how_predictable/views/widgets/watch_tower_icon.dart';
import 'package:how_predictable/views/widgets/watchtower_cell_shader_view.dart';
import 'package:how_predictable/views/widgets/watchtower_forge_view.dart';

Future<GameController> _createController({
  String language = 'en',
  bool animationsEnabled = false,
  bool darkMode = true,
  int currentWeek = 0,
  int enemyStage = 1,
  bool hasShownWeek0ScreamWarning = false,
  bool hasInspectedPrincessCellAfterScream = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_story_intro': true,
    'darkMode': darkMode,
    'animationsEnabled': animationsEnabled,
    'musicEnabled': false,
    'soundEnabled': false,
    'language': language,
    'current_week': currentWeek,
    'enemy_stage': enemyStage,
    'has_shown_week0_scream_warning': hasShownWeek0ScreamWarning,
    'has_inspected_princess_cell_after_scream':
        hasInspectedPrincessCellAfterScream,
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

  group('Watch Tower Dual Spyglass & Narrative Polish Tests', () {
    testWidgets(
      "Princess's Cell and Metal Wizard buttons render side-by-side above Open Story Log and open their respective spyglass dialogs",
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
        addTearDown(controller.dispose);

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
        expect(
          find.textContaining("The Metal Wizard's automaton"),
          findsOneWidget,
        );
        expect(find.textContaining('Master Hand'), findsNothing);
        expect(
          find.byKey(const ValueKey('observatory_markov_week10_note')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('observatory_close_button')),
            matching: find.text('Ok'),
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is OutlinedButton &&
                w.key == const ValueKey('observatory_close_button'),
          ),
          findsOneWidget,
        );

        final princessBtn = find.byKey(
          const ValueKey('observatory_spy_princess_button'),
        );
        final wizardBtn = find.byKey(
          const ValueKey('observatory_spy_wizard_button'),
        );
        final storyBtn = find.byKey(
          const ValueKey('observatory_story_log_button'),
        );
        expect(princessBtn, findsOneWidget);
        expect(wizardBtn, findsOneWidget);
        expect(storyBtn, findsOneWidget);
        expect(find.text("Princess's Cell"), findsOneWidget);
        expect(find.text('Metal Wizard'), findsOneWidget);
        expect(find.text('Spy on Dungeon'), findsNothing);

        // Leading WatchTowerIcon inside Princess's Cell button
        expect(
          find.descendant(
            of: princessBtn,
            matching: find.byType(WatchTowerIcon),
          ),
          findsOneWidget,
        );

        // Side-by-side equal-width Row positioned above Open Story Log
        final princessRect = tester.getRect(princessBtn);
        final wizardRect = tester.getRect(wizardBtn);
        final storyRect = tester.getRect(storyBtn);
        expect(princessRect.right, lessThan(wizardRect.left));
        expect(
          (princessRect.top - wizardRect.top).abs(),
          lessThanOrEqualTo(1.0),
        );
        expect(
          (princessRect.width - wizardRect.width).abs(),
          lessThanOrEqualTo(2.0),
        );
        expect(princessRect.bottom, lessThanOrEqualTo(storyRect.top));

        // 1. Tap Princess's Cell -> opens WatchtowerSpyglassDialog
        await tester.ensureVisible(princessBtn);
        await tester.pumpAndSettle();
        await tester.tap(princessBtn);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(WatchtowerSpyglassDialog), findsOneWidget);
        expect(find.byType(WatchtowerCellShaderView), findsOneWidget);
        expect(find.text('Dungeon Spyglass'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('watchtower_spyglass_expand_badge')),
          findsOneWidget,
        );
        expect(find.text('Tap lens to inspect full screen'), findsOneWidget);
        expect(
          find.text(
            'Through the Watch Tower lens, the captive Princess awaits rescue...',
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('watchtower_spyglass_close_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(WatchtowerSpyglassDialog), findsNothing);

        // 2. Tap Metal Wizard -> opens MetalWizardSpyglassDialog
        await tester.tap(wizardBtn);
        await tester.pumpAndSettle();

        expect(find.byType(MetalWizardSpyglassDialog), findsOneWidget);
        expect(find.byType(WatchtowerForgeView), findsOneWidget);
        expect(find.text("Metal Wizard's Forge"), findsOneWidget);
        expect(
          find.byKey(const ValueKey('metal_wizard_spyglass_expand_badge')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('metal_wizard_spyglass_lore_box')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('metal_wizard_spyglass_close_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MetalWizardSpyglassDialog), findsNothing);
        expect(find.byType(ObservatoryDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Metal Wizard spyglass displays dynamic captions for Week 0-9, Week 10-39, and Week 40+ / defeated; Observatory shows Week 10+ Markov tactical note',
      (WidgetTester tester) async {
        // Week 0-9
        final earlyController = await _createController(
          currentWeek: 4,
          animationsEnabled: false,
        );
        addTearDown(earlyController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: MetalWizardSpyglassDialog(controller: earlyController),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Robot Archmage before Week 10'), findsOneWidget);

        // Week 10-39
        final midController = await _createController(
          currentWeek: 10,
          animationsEnabled: false,
        );
        addTearDown(midController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ObservatoryDialog(controller: midController),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('observatory_markov_week10_note')),
          findsOneWidget,
        );
        expect(
          find.textContaining('ignores older history'),
          findsOneWidget,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: MetalWizardSpyglassDialog(controller: midController),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Baby Mage Robot prototype'),
          findsOneWidget,
        );

        // Week 40+
        final lateController = await _createController(
          currentWeek: 40,
          animationsEnabled: false,
        );
        addTearDown(lateController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: MetalWizardSpyglassDialog(controller: lateController),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('forge cools with dying embers'),
          findsOneWidget,
        );

        // Metal Wizard defeated (enemyStage == 4) even before Week 40
        final defeatedController = await _createController(
          currentWeek: 14,
          enemyStage: 4,
          animationsEnabled: false,
        );
        addTearDown(defeatedController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: MetalWizardSpyglassDialog(controller: defeatedController),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('forge cools with dying embers'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '"!" scream alert badge appears on Princess\'s Cell when hasShownWeek0ScreamWarning is active and clears upon inspection',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 1. Before Week 0 scream warning: badge is absent
        final beforeController = await _createController(
          hasShownWeek0ScreamWarning: false,
          hasInspectedPrincessCellAfterScream: false,
        );
        addTearDown(beforeController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ObservatoryDialog(controller: beforeController),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('observatory_princess_scream_badge')),
          findsNothing,
        );

        // 2. After Week 0 scream warning and before inspection: badge is visible
        final activeController = await _createController(
          currentWeek: 1,
          hasShownWeek0ScreamWarning: true,
          hasInspectedPrincessCellAfterScream: false,
        );
        addTearDown(activeController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ObservatoryDialog(controller: activeController),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final badgeFinder = find.byKey(
          const ValueKey('observatory_princess_scream_badge'),
        );
        expect(badgeFinder, findsOneWidget);
        expect(
          find.descendant(of: badgeFinder, matching: find.text('!')),
          findsOneWidget,
        );

        // 3. Tapping Princess's Cell opens spyglass, sets flag, and clears badge
        await tester.tap(
          find.byKey(const ValueKey('observatory_spy_princess_button')),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        expect(activeController.hasInspectedPrincessCellAfterScream, isTrue);
        expect(
          activeController.storage.hasInspectedPrincessCellAfterScream,
          isTrue,
        );
        expect(activeController.shouldShowPrincessCellScreamBadge, isFalse);

        // Close spyglass and confirm badge is gone
        await tester.tap(
          find.byKey(const ValueKey('watchtower_spyglass_close_button')),
        );
        await tester.pumpAndSettle();
        expect(badgeFinder, findsNothing);

        // 4. Forfeit / new run resets both scream warning and inspection flags
        await activeController.resetAllProgress();
        expect(activeController.hasShownWeek0ScreamWarning, isFalse);
        expect(activeController.hasInspectedPrincessCellAfterScream, isFalse);
        expect(activeController.shouldShowPrincessCellScreamBadge, isFalse);
      },
    );

    testWidgets(
      'Tapping circular Princess Cell spyglass lens opens FullScreenSpyglassView with InteractiveViewer, double-tap zoom, reset button, and closes cleanly',
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
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: WatchtowerSpyglassDialog(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final lensTap = find.byKey(
          const ValueKey('watchtower_spyglass_lens_tap'),
        );
        expect(lensTap, findsOneWidget);

        await tester.tap(lensTap);
        await tester.pumpAndSettle();

        expect(find.byType(FullScreenSpyglassView), findsOneWidget);
        final viewerFinder = find.byKey(
          const ValueKey('full_screen_spyglass_interactive_viewer'),
        );
        expect(viewerFinder, findsOneWidget);

        final viewer = tester.widget<InteractiveViewer>(viewerFinder);
        expect(viewer.minScale, 1.0);
        expect(viewer.maxScale, 4.0);
        expect(viewer.panEnabled, isTrue);
        expect(viewer.scaleEnabled, isTrue);

        // Full-screen shader view uses isFullScreen: true
        final fullShaderFinder = find.descendant(
          of: viewerFinder,
          matching: find.byType(WatchtowerCellShaderView),
        );
        expect(fullShaderFinder, findsOneWidget);
        expect(
          tester.widget<WatchtowerCellShaderView>(fullShaderFinder).isFullScreen,
          isTrue,
        );

        // Reset Zoom button is hidden at 1.0x
        final resetBtnFinder = find.byKey(
          const ValueKey('full_screen_spyglass_reset_zoom_button'),
        );
        expect(resetBtnFinder, findsNothing);

        // Double-tap center of InteractiveViewer -> zooms in to 2.2x and reveals Reset Zoom
        final center = tester.getCenter(viewerFinder);
        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(center);
        await tester.pumpAndSettle();

        expect(resetBtnFinder, findsOneWidget);

        // Tap Reset Zoom -> animates back to 1.0x and hides Reset Zoom button
        await tester.tap(resetBtnFinder);
        await tester.pumpAndSettle();
        expect(resetBtnFinder, findsNothing);

        // Close full-screen view -> returns cleanly to WatchtowerSpyglassDialog
        final fullCloseBtn = find.byKey(
          const ValueKey('full_screen_spyglass_close_button'),
        );
        expect(fullCloseBtn, findsOneWidget);
        await tester.tap(fullCloseBtn);
        await tester.pumpAndSettle();

        expect(find.byType(FullScreenSpyglassView), findsNothing);
        expect(find.byType(WatchtowerSpyglassDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Tapping circular Metal Wizard spyglass lens opens FullScreenSpyglassView with InteractiveViewer, double-tap zoom, bottom RPG lore box, and animated forge embers',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          language: 'en',
          currentWeek: 12,
          animationsEnabled: false,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: MetalWizardSpyglassDialog(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final lensTap = find.byKey(
          const ValueKey('metal_wizard_spyglass_lens_tap'),
        );
        expect(lensTap, findsOneWidget);

        await tester.tap(lensTap);
        await tester.pumpAndSettle();

        expect(find.byType(FullScreenSpyglassView), findsOneWidget);
        final viewerFinder = find.byKey(
          const ValueKey('full_screen_spyglass_interactive_viewer'),
        );
        expect(viewerFinder, findsOneWidget);

        final fullForgeFinder = find.descendant(
          of: viewerFinder,
          matching: find.byType(WatchtowerForgeView),
        );
        expect(fullForgeFinder, findsOneWidget);
        expect(
          tester.widget<WatchtowerForgeView>(fullForgeFinder).isFullScreen,
          isTrue,
        );
        expect(
          find.byKey(const ValueKey('full_screen_metal_wizard_lore_box')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Baby Mage Robot prototype'),
          findsOneWidget,
        );

        // Double-tap zoom toggles 1.0x -> 2.2x and reveals Reset Zoom
        final resetBtnFinder = find.byKey(
          const ValueKey('full_screen_spyglass_reset_zoom_button'),
        );
        expect(resetBtnFinder, findsNothing);

        final center = tester.getCenter(viewerFinder);
        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(center);
        await tester.pumpAndSettle();
        expect(resetBtnFinder, findsOneWidget);

        await tester.tap(resetBtnFinder);
        await tester.pumpAndSettle();
        expect(resetBtnFinder, findsNothing);

        await tester.tap(
          find.byKey(const ValueKey('full_screen_spyglass_close_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FullScreenSpyglassView), findsNothing);
        expect(find.byType(MetalWizardSpyglassDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      "Princess's Cell, Metal Wizard, strategy hint, Week 10+ Markov note, and forge captions display correct translations for en, pt, es, de",
      (WidgetTester tester) async {
        const expectedPrincessButtons = {
          'en': "Princess's Cell",
          'pt': 'Cela da Princesa',
          'es': 'Celda de la Princesa',
          'de': 'Zelle der Prinzessin',
        };
        const expectedWizardButtons = {
          'en': 'Metal Wizard',
          'pt': 'Mago de Metal',
          'es': 'Mago de Metal',
          'de': 'Metallmagier',
        };
        const expectedHints = {
          'en': 'Tap lens to inspect full screen',
          'pt': 'Toque na lente para explorar em tela cheia',
          'es': 'Toca la lente para explorar en pantalla completa',
          'de': 'Linse antippen für Vollbild-Ansicht',
        };

        for (final lang in ['en', 'pt', 'es', 'de']) {
          final controller = await _createController(
            language: lang,
            currentWeek: 10,
            animationsEnabled: false,
          );
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: ObservatoryDialog(controller: controller),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(expectedPrincessButtons[lang]!), findsOneWidget);
          expect(find.text(expectedWizardButtons[lang]!), findsOneWidget);
          expect(
            find.byKey(const ValueKey('observatory_markov_week10_note')),
            findsOneWidget,
          );
          expect(find.textContaining('Master Hand'), findsNothing);

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: WatchtowerSpyglassDialog(controller: controller),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(expectedHints[lang]!), findsOneWidget);

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: MetalWizardSpyglassDialog(controller: controller),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(expectedHints[lang]!), findsOneWidget);
          expect(
            find.byKey(const ValueKey('metal_wizard_spyglass_lore_box')),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets(
      'WatchtowerCellShaderView and WatchtowerForgeView render and dispose cleanly in animated and static modes',
      (WidgetTester tester) async {
        for (final fullScreen in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 320,
                  height: 320,
                  child: WatchtowerCellShaderView(
                    animationsEnabled: false,
                    forceStaticFallback: true,
                    isFullScreen: fullScreen,
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

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 320,
                  height: 320,
                  child: WatchtowerForgeView(
                    animationsEnabled: true,
                    isFullScreen: fullScreen,
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            find.byKey(const ValueKey('watchtower_forge_vfx_paint')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }

        // Also test normal animated shader construction & disposal without crashing
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
