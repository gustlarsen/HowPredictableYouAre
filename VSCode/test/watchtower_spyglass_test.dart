import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      'Tapping circular Princess Cell spyglass lens opens FullScreenSpyglassView with InteractiveViewer, double-tap zoom/reset, no Reset Zoom button, and closes cleanly',
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
        expect(
          viewer.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(1.0, 1e-3),
        );

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

        // Reset Zoom button is completely removed at 1.0x and when zoomed in
        final resetBtnFinder = find.byKey(
          const ValueKey('full_screen_spyglass_reset_zoom_button'),
        );
        expect(resetBtnFinder, findsNothing);
        expect(find.text('Reset Zoom'), findsNothing);
        expect(find.byIcon(Icons.center_focus_strong_rounded), findsNothing);

        // Double-tap center of InteractiveViewer -> zooms in to 2.2x without showing Reset Zoom
        final center = tester.getCenter(viewerFinder);
        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(center);
        await tester.pumpAndSettle();

        expect(
          viewer.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(2.2, 1e-3),
        );
        expect(resetBtnFinder, findsNothing);
        expect(find.text('Reset Zoom'), findsNothing);
        expect(find.byIcon(Icons.center_focus_strong_rounded), findsNothing);

        // Panning across the zoomed illustration shifts translation
        final beforePanTx =
            viewer.transformationController!.value.getTranslation().x;
        await tester.dragFrom(center, const Offset(40, 0));
        await tester.pumpAndSettle();
        final afterPanTx =
            viewer.transformationController!.value.getTranslation().x;
        expect(afterPanTx, isNot(closeTo(beforePanTx, 0.5)));

        // Double-tap again -> animates smoothly back to 1.0x
        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(center);
        await tester.pumpAndSettle();
        expect(
          viewer.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(1.0, 1e-3),
        );

        // Close (X) button remains anchored in top-right and exits cleanly
        final fullCloseBtn = find.byKey(
          const ValueKey('full_screen_spyglass_close_button'),
        );
        expect(fullCloseBtn, findsOneWidget);
        final closeRect = tester.getRect(fullCloseBtn);
        expect(closeRect.top, lessThan(80));
        expect(closeRect.right, greaterThan(340));
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

        // Double-tap zoom toggles 1.0x -> 2.2x -> 1.0x without any Reset Zoom button
        final viewer = tester.widget<InteractiveViewer>(viewerFinder);
        final resetBtnFinder = find.byKey(
          const ValueKey('full_screen_spyglass_reset_zoom_button'),
        );
        expect(resetBtnFinder, findsNothing);
        expect(find.text('Reset Zoom'), findsNothing);
        expect(
          viewer.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(1.0, 1e-3),
        );

        final center = tester.getCenter(viewerFinder);
        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(center);
        await tester.pumpAndSettle();
        expect(
          viewer.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(2.2, 1e-3),
        );
        expect(resetBtnFinder, findsNothing);
        expect(find.text('Reset Zoom'), findsNothing);

        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(center);
        await tester.pumpAndSettle();
        expect(
          viewer.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(1.0, 1e-3),
        );

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
      'Post-Week-0 scream switches WatchtowerSpyglassDialog and FullScreenSpyglassView to crying pose while preserving zoom/pan/double-tap controls',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 1. Pre-scream (Week 0): standing pose (isCrying: false)
        final controller = await _createController(
          currentWeek: 0,
          animationsEnabled: false,
          hasShownWeek0ScreamWarning: false,
        );
        addTearDown(controller.dispose);

        expect(controller.hasDungeonScreamOccurred, isFalse);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: WatchtowerSpyglassDialog(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<WatchtowerCellShaderView>(
                find.byType(WatchtowerCellShaderView),
              )
              .isCrying,
          isFalse,
        );

        // 2. Trigger Week 0 scream via completeBattleWeek() (pending scream)
        controller.completeBattleWeek();
        await tester.pumpAndSettle();
        expect(controller.pendingWeek0ScreamWarning, isTrue);
        expect(controller.hasDungeonScreamOccurred, isTrue);
        expect(
          tester
              .widget<WatchtowerCellShaderView>(
                find.byType(WatchtowerCellShaderView),
              )
              .isCrying,
          isTrue,
        );

        // 3. Consume warning & mark cell inspected -> princess stays crying for rest of run
        expect(controller.consumePendingWeek0ScreamWarning(), isTrue);
        controller.markPrincessCellInspectedAfterScream();
        await tester.pumpAndSettle();
        expect(controller.hasDungeonScreamOccurred, isTrue);
        expect(
          tester
              .widget<WatchtowerCellShaderView>(
                find.byType(WatchtowerCellShaderView),
              )
              .isCrying,
          isTrue,
        );

        // 4. Open FullScreenSpyglassView -> isCrying: true, isFullScreen: true, zoom/pan active
        await tester.tap(
          find.byKey(const ValueKey('watchtower_spyglass_lens_tap')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FullScreenSpyglassView), findsOneWidget);
        final viewerFinder = find.byKey(
          const ValueKey('full_screen_spyglass_interactive_viewer'),
        );
        final fullShader = tester.widget<WatchtowerCellShaderView>(
          find.descendant(
            of: viewerFinder,
            matching: find.byType(WatchtowerCellShaderView),
          ),
        );
        expect(fullShader.isFullScreen, isTrue);
        expect(fullShader.isCrying, isTrue);

        final viewer = tester.widget<InteractiveViewer>(viewerFinder);
        expect(viewer.minScale, 1.0);
        expect(viewer.maxScale, 4.0);
        expect(viewer.panEnabled, isTrue);
        expect(viewer.scaleEnabled, isTrue);

        // Double-tap zoom in & reset still work cleanly in crying state without Reset Zoom button
        final resetBtnFinder = find.byKey(
          const ValueKey('full_screen_spyglass_reset_zoom_button'),
        );
        expect(resetBtnFinder, findsNothing);
        expect(find.text('Reset Zoom'), findsNothing);
        final center = tester.getCenter(viewerFinder);
        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(center);
        await tester.pumpAndSettle();
        expect(
          viewer.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(2.2, 1e-3),
        );
        expect(resetBtnFinder, findsNothing);

        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(center);
        await tester.pumpAndSettle();
        expect(
          viewer.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(1.0, 1e-3),
        );

        await tester.tap(
          find.byKey(const ValueKey('full_screen_spyglass_close_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FullScreenSpyglassView), findsNothing);

        // 5. Reset campaign -> reverts back to pre-scream standing state
        await controller.resetAllProgress();
        await tester.pumpAndSettle();
        expect(controller.hasDungeonScreamOccurred, isFalse);
        expect(
          tester
              .widget<WatchtowerCellShaderView>(
                find.byType(WatchtowerCellShaderView),
              )
              .isCrying,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'WatchtowerCellShaderView and WatchtowerForgeView render and dispose cleanly in animated and static modes (standing & crying)',
      (WidgetTester tester) async {
        for (final fullScreen in [false, true]) {
          for (final crying in [false, true]) {
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
                      isCrying: crying,
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
            expect(
              find.byKey(
                ValueKey(
                  crying
                      ? 'watchtower_spyglass_princess_crying_image'
                      : 'watchtower_spyglass_princess_standing_image',
                ),
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }

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

        // Also test normal animated shader construction & state transition without crashing
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 320,
                child: WatchtowerCellShaderView(
                  animationsEnabled: true,
                  isCrying: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 320,
                child: WatchtowerCellShaderView(
                  animationsEnabled: true,
                  isCrying: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(WatchtowerCellShaderView), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Unmount cleanly
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Piecewise 5-keyframe Princess week progression (Week 0 -> Week 1 -> Week 2..40) selects adjacent stage textures, uStageBlend, blink, and renders cleanly in modal, full-screen, and fallback modes',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 0. Verify all 5 progressive stage PNGs and the blink PNG are registered and loadable
        for (final stageAsset in WatchtowerCellShaderView.cryingStageAssets) {
          final bytes = await rootBundle.load(stageAsset);
          expect(bytes.lengthInBytes, greaterThan(1000));
        }
        final blinkBytes = await rootBundle.load(
          WatchtowerCellShaderView.cryingBlinkAsset,
        );
        expect(blinkBytes.lengthInBytes, greaterThan(1000));

        final stages = WatchtowerCellShaderView.cryingStageAssets;

        // 1. Direct WatchtowerCellShaderView unit/widget checks across Week 0, 1, 2, 10, 11, 20, 21, 31, 40, and clamped >40
        final cases = <({
          int week,
          int expectedClamped,
          WatchtowerPrincessStage expectedStage,
          double expectedProgress,
          int expectedFromIndex,
          int expectedToIndex,
          double expectedStageBlend,
          bool expectedBlinkEnabled,
          String expectedPrimaryAsset,
          String? expectedSecondaryAsset,
          String expectedFallbackAsset,
          String expectedImageKey,
        })>[
          (
            week: 0,
            expectedClamped: 0,
            expectedStage: WatchtowerPrincessStage.standing,
            expectedProgress: 0.0,
            expectedFromIndex: 0,
            expectedToIndex: 0,
            expectedStageBlend: 0.0,
            expectedBlinkEnabled: false,
            expectedPrimaryAsset: WatchtowerCellShaderView.standingAsset,
            expectedSecondaryAsset: null,
            expectedFallbackAsset: WatchtowerCellShaderView.standingAsset,
            expectedImageKey: 'watchtower_spyglass_princess_standing_image',
          ),
          (
            week: 1,
            expectedClamped: 1,
            expectedStage: WatchtowerPrincessStage.cryingWeek1,
            expectedProgress: 0.0,
            expectedFromIndex: 0,
            expectedToIndex: 0,
            expectedStageBlend: 0.0,
            expectedBlinkEnabled: true,
            expectedPrimaryAsset: stages[0],
            expectedSecondaryAsset: null,
            expectedFallbackAsset: stages[0],
            expectedImageKey: 'watchtower_spyglass_princess_crying_image',
          ),
          (
            week: 2,
            expectedClamped: 2,
            expectedStage: WatchtowerPrincessStage.cryingPregnant,
            expectedProgress: 1.0 / 39.0,
            expectedFromIndex: 0,
            expectedToIndex: 1,
            expectedStageBlend: 4.0 / 39.0,
            expectedBlinkEnabled: true,
            expectedPrimaryAsset: stages[0],
            expectedSecondaryAsset: stages[1],
            expectedFallbackAsset: stages[0],
            expectedImageKey: 'watchtower_spyglass_princess_crying_stage_0',
          ),
          (
            week: 10,
            expectedClamped: 10,
            expectedStage: WatchtowerPrincessStage.cryingPregnant,
            expectedProgress: 9.0 / 39.0,
            expectedFromIndex: 0,
            expectedToIndex: 1,
            expectedStageBlend: 36.0 / 39.0,
            expectedBlinkEnabled: true,
            expectedPrimaryAsset: stages[0],
            expectedSecondaryAsset: stages[1],
            expectedFallbackAsset: stages[1],
            expectedImageKey: 'watchtower_spyglass_princess_crying_stage_1',
          ),
          (
            week: 11,
            expectedClamped: 11,
            expectedStage: WatchtowerPrincessStage.cryingPregnant,
            expectedProgress: 10.0 / 39.0,
            expectedFromIndex: 1,
            expectedToIndex: 2,
            expectedStageBlend: 1.0 / 39.0,
            expectedBlinkEnabled: false,
            expectedPrimaryAsset: stages[1],
            expectedSecondaryAsset: stages[2],
            expectedFallbackAsset: stages[1],
            expectedImageKey: 'watchtower_spyglass_princess_crying_stage_1',
          ),
          (
            week: 20,
            expectedClamped: 20,
            expectedStage: WatchtowerPrincessStage.cryingPregnant,
            expectedProgress: 19.0 / 39.0,
            expectedFromIndex: 1,
            expectedToIndex: 2,
            expectedStageBlend: 37.0 / 39.0,
            expectedBlinkEnabled: false,
            expectedPrimaryAsset: stages[1],
            expectedSecondaryAsset: stages[2],
            expectedFallbackAsset: stages[2],
            expectedImageKey: 'watchtower_spyglass_princess_crying_stage_2',
          ),
          (
            week: 21,
            expectedClamped: 21,
            expectedStage: WatchtowerPrincessStage.cryingPregnant,
            expectedProgress: 20.0 / 39.0,
            expectedFromIndex: 2,
            expectedToIndex: 3,
            expectedStageBlend: 2.0 / 39.0,
            expectedBlinkEnabled: false,
            expectedPrimaryAsset: stages[2],
            expectedSecondaryAsset: stages[3],
            expectedFallbackAsset: stages[2],
            expectedImageKey: 'watchtower_spyglass_princess_crying_stage_2',
          ),
          (
            week: 31,
            expectedClamped: 31,
            expectedStage: WatchtowerPrincessStage.cryingPregnant,
            expectedProgress: 30.0 / 39.0,
            expectedFromIndex: 3,
            expectedToIndex: 4,
            expectedStageBlend: 3.0 / 39.0,
            expectedBlinkEnabled: false,
            expectedPrimaryAsset: stages[3],
            expectedSecondaryAsset: stages[4],
            expectedFallbackAsset: stages[3],
            expectedImageKey: 'watchtower_spyglass_princess_crying_stage_3',
          ),
          (
            week: 40,
            expectedClamped: 40,
            expectedStage: WatchtowerPrincessStage.cryingPregnant,
            expectedProgress: 1.0,
            expectedFromIndex: 3,
            expectedToIndex: 4,
            expectedStageBlend: 1.0,
            expectedBlinkEnabled: false,
            expectedPrimaryAsset: stages[3],
            expectedSecondaryAsset: stages[4],
            expectedFallbackAsset: stages[4],
            expectedImageKey: 'watchtower_spyglass_princess_crying_stage_4',
          ),
          (
            week: 41,
            expectedClamped: 40,
            expectedStage: WatchtowerPrincessStage.cryingPregnant,
            expectedProgress: 1.0,
            expectedFromIndex: 3,
            expectedToIndex: 4,
            expectedStageBlend: 1.0,
            expectedBlinkEnabled: false,
            expectedPrimaryAsset: stages[3],
            expectedSecondaryAsset: stages[4],
            expectedFallbackAsset: stages[4],
            expectedImageKey: 'watchtower_spyglass_princess_crying_stage_4',
          ),
        ];

        for (final c in cases) {
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
                      currentWeek: c.week,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final view = tester.widget<WatchtowerCellShaderView>(
              find.byType(WatchtowerCellShaderView),
            );
            expect(view.clampedWeek, c.expectedClamped);
            expect(view.princessStage, c.expectedStage);
            expect(view.bellyProgress, closeTo(c.expectedProgress, 1e-6));
            expect(view.abdomenGrowth, closeTo(c.expectedProgress, 1e-6));
            expect(view.stageFromIndex, c.expectedFromIndex);
            expect(view.stageToIndex, c.expectedToIndex);
            expect(view.stageBlend, closeTo(c.expectedStageBlend, 1e-6));
            expect(view.blinkEnabled, c.expectedBlinkEnabled);
            expect(view.primaryPrincessAsset, c.expectedPrimaryAsset);
            expect(view.secondaryPrincessAsset, c.expectedSecondaryAsset);
            expect(view.fallbackPrincessAsset, c.expectedFallbackAsset);
            expect(
              find.byKey(const ValueKey('watchtower_spyglass_fallback_stack')),
              findsOneWidget,
            );
            final imgFinder = find.byKey(ValueKey(c.expectedImageKey));
            expect(imgFinder, findsOneWidget);
            final img = tester.widget<Image>(imgFinder);
            expect(
              (img.image as AssetImage).assetName,
              c.expectedFallbackAsset,
            );
            expect(tester.takeException(), isNull);
          }
        }

        // 2. Animated piecewise shader lifecycle transitioning across all 4 intervals (Week 0..40)
        for (final week in [0, 1, 2, 10, 11, 20, 21, 31, 40]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 320,
                  height: 320,
                  child: WatchtowerCellShaderView(
                    animationsEnabled: true,
                    currentWeek: week,
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 60));
          expect(find.byType(WatchtowerCellShaderView), findsOneWidget);
          expect(tester.takeException(), isNull);
        }

        // Direct mount at Week 40 (initial double-texture load path) and clean dispose
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 320,
                child: WatchtowerCellShaderView(
                  animationsEnabled: true,
                  currentWeek: 40,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 60));
        expect(find.byType(WatchtowerCellShaderView), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 3. End-to-end GameController -> WatchtowerSpyglassDialog -> FullScreenSpyglassView
        //    verifying Week 0, Week 1, Week 2, and Week 40 with zoom controls preserved
        final controller = await _createController(
          currentWeek: 0,
          animationsEnabled: false,
          hasShownWeek0ScreamWarning: false,
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

        WatchtowerCellShaderView readDialogShader() =>
            tester.widget<WatchtowerCellShaderView>(
              find.byType(WatchtowerCellShaderView),
            );

        // Week 0: Standing, 0% belly growth
        expect(readDialogShader().princessStage, WatchtowerPrincessStage.standing);
        expect(readDialogShader().bellyProgress, 0.0);

        // Week 1: Crying (right hand on lap), 0% belly growth
        controller.completeBattleWeek();
        await tester.pumpAndSettle();
        expect(controller.currentWeek, 1);
        expect(
          readDialogShader().princessStage,
          WatchtowerPrincessStage.cryingWeek1,
        );
        expect(readDialogShader().bellyProgress, 0.0);

        // Week 2: Piecewise blending stage_0 -> stage_1 (progress 1/39)
        controller.completeBattleWeek();
        await tester.pumpAndSettle();
        expect(controller.currentWeek, 2);
        expect(
          readDialogShader().princessStage,
          WatchtowerPrincessStage.cryingPregnant,
        );
        expect(readDialogShader().bellyProgress, closeTo(1.0 / 39.0, 1e-6));
        expect(readDialogShader().primaryPrincessAsset, stages[0]);
        expect(readDialogShader().secondaryPrincessAsset, stages[1]);

        // Week 20 (mid-campaign): Piecewise blending stage_1 -> stage_2
        controller.currentWeek = 20;
        controller.notifyListeners();
        await tester.pumpAndSettle();
        expect(
          readDialogShader().princessStage,
          WatchtowerPrincessStage.cryingPregnant,
        );
        expect(readDialogShader().bellyProgress, closeTo(19.0 / 39.0, 1e-6));
        expect(readDialogShader().primaryPrincessAsset, stages[1]);
        expect(readDialogShader().secondaryPrincessAsset, stages[2]);
        expect(readDialogShader().stageBlend, closeTo(37.0 / 39.0, 1e-6));

        // Week 40: Full 9-month belly growth (1.0, stage_3 -> stage_4 at blend 1.0)
        controller.currentWeek = 40;
        controller.notifyListeners();
        await tester.pumpAndSettle();
        expect(
          readDialogShader().princessStage,
          WatchtowerPrincessStage.cryingPregnant,
        );
        expect(readDialogShader().bellyProgress, 1.0);
        expect(readDialogShader().primaryPrincessAsset, stages[3]);
        expect(readDialogShader().secondaryPrincessAsset, stages[4]);
        expect(readDialogShader().stageBlend, 1.0);

        // Open FullScreenSpyglassView at Week 40 and verify 1.0x..4.0x InteractiveViewer & double-tap zoom
        await tester.tap(
          find.byKey(const ValueKey('watchtower_spyglass_lens_tap')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FullScreenSpyglassView), findsOneWidget);
        final viewerFinder = find.byKey(
          const ValueKey('full_screen_spyglass_interactive_viewer'),
        );
        final fullView = tester.widget<WatchtowerCellShaderView>(
          find.descendant(
            of: viewerFinder,
            matching: find.byType(WatchtowerCellShaderView),
          ),
        );
        expect(fullView.isFullScreen, isTrue);
        expect(fullView.clampedWeek, 40);
        expect(fullView.princessStage, WatchtowerPrincessStage.cryingPregnant);
        expect(fullView.bellyProgress, 1.0);

        final viewer = tester.widget<InteractiveViewer>(viewerFinder);
        expect(viewer.minScale, 1.0);
        expect(viewer.maxScale, 4.0);
        expect(viewer.panEnabled, isTrue);
        expect(viewer.scaleEnabled, isTrue);

        final center = tester.getCenter(viewerFinder);
        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(center);
        await tester.pumpAndSettle();
        expect(
          viewer.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(2.2, 1e-3),
        );
        expect(
          find.byKey(const ValueKey('full_screen_spyglass_reset_zoom_button')),
          findsNothing,
        );
        expect(find.text('Reset Zoom'), findsNothing);

        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(center);
        await tester.pumpAndSettle();
        expect(
          viewer.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(1.0, 1e-3),
        );

        await tester.tap(
          find.byKey(const ValueKey('full_screen_spyglass_close_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FullScreenSpyglassView), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

