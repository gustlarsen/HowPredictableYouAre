import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/observatory_dialog.dart';
import 'package:how_predictable/views/dialogs/world_map_war_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Watch Tower -> WorldMapWarDialog (Weeks 1–41 Progressive Conquest) Tests', () {
    test(
      'WorldRealmRegion coordinates, fall weeks, and ConquestFrontGeometry clip coverage match specification across Weeks 1..41',
      () {
        expect(
          WorldRealmRegion.metalWizardDominion.position,
          const Offset(0.78, 0.20),
        );
        expect(
          WorldRealmRegion.kingdomOfSolaria.position,
          const Offset(0.62, 0.45),
        );
        expect(
          WorldRealmRegion.stoneCitadel.position,
          const Offset(0.27, 0.22),
        );
        expect(
          WorldRealmRegion.verdantDuchy.position,
          const Offset(0.25, 0.48),
        );
        expect(
          WorldRealmRegion.crystalPort.position,
          const Offset(0.72, 0.73),
        );
        expect(
          WorldRealmRegion.clericSacredCapital.position,
          const Offset(0.28, 0.78),
        );

        // Status transitions per week
        expect(
          WorldRealmRegion.metalWizardDominion.statusForWeek(1),
          RealmWarStatus.originDominion,
        );
        expect(
          WorldRealmRegion.kingdomOfSolaria.statusForWeek(9),
          RealmWarStatus.free,
        );
        expect(
          WorldRealmRegion.kingdomOfSolaria.statusForWeek(10),
          RealmWarStatus.conquered,
        );
        expect(
          WorldRealmRegion.stoneCitadel.statusForWeek(17),
          RealmWarStatus.free,
        );
        expect(
          WorldRealmRegion.stoneCitadel.statusForWeek(18),
          RealmWarStatus.conquered,
        );
        expect(
          WorldRealmRegion.verdantDuchy.statusForWeek(25),
          RealmWarStatus.free,
        );
        expect(
          WorldRealmRegion.verdantDuchy.statusForWeek(26),
          RealmWarStatus.conquered,
        );
        expect(
          WorldRealmRegion.crystalPort.statusForWeek(33),
          RealmWarStatus.free,
        );
        expect(
          WorldRealmRegion.crystalPort.statusForWeek(34),
          RealmWarStatus.conquered,
        );
        expect(
          WorldRealmRegion.clericSacredCapital.statusForWeek(34),
          RealmWarStatus.free,
        );
        expect(
          WorldRealmRegion.clericSacredCapital.statusForWeek(35),
          RealmWarStatus.underThreat,
        );
        expect(
          WorldRealmRegion.clericSacredCapital.statusForWeek(40),
          RealmWarStatus.underThreat,
        );
        expect(
          WorldRealmRegion.clericSacredCapital.statusForWeek(41),
          RealmWarStatus.besieged,
        );

        // Clip path geometry checks on a 300x400 (3:4) canvas
        const size = Size(300, 400);
        final capitalPt = Offset(0.28 * size.width, 0.78 * size.height);
        final solariaPt = Offset(0.62 * size.width, 0.45 * size.height);
        final citadelPt = Offset(0.27 * size.width, 0.22 * size.height);
        final duchyPt = Offset(0.25 * size.width, 0.48 * size.height);
        final portPt = Offset(0.72 * size.width, 0.73 * size.height);

        // Week 1: 0% conquered
        final w1Path = ConquestFrontGeometry.buildClipPath(1, size);
        expect(w1Path.getBounds().isEmpty, isTrue);

        // Week 10: Solaria engulfed, Citadel/Duchy/Port/Capital still outside conquered clip
        final w10Path = ConquestFrontGeometry.buildClipPath(10, size);
        expect(w10Path.contains(solariaPt), isTrue);
        expect(w10Path.contains(citadelPt), isFalse);
        expect(w10Path.contains(capitalPt), isFalse);

        // Week 18: Stone Citadel engulfed
        final w18Path = ConquestFrontGeometry.buildClipPath(18, size);
        expect(w18Path.contains(solariaPt), isTrue);
        expect(w18Path.contains(citadelPt), isTrue);
        expect(w18Path.contains(duchyPt), isFalse);
        expect(w18Path.contains(capitalPt), isFalse);

        // Week 26: Verdant Duchy engulfed
        final w26Path = ConquestFrontGeometry.buildClipPath(26, size);
        expect(w26Path.contains(duchyPt), isTrue);
        expect(w26Path.contains(portPt), isFalse);
        expect(w26Path.contains(capitalPt), isFalse);

        // Week 34: Crystal Port engulfed, Capital sanctuary still unconquered
        final w34Path = ConquestFrontGeometry.buildClipPath(34, size);
        expect(w34Path.contains(portPt), isTrue);
        expect(w34Path.contains(capitalPt), isFalse);

        // Weeks 35..40: All outer regions conquered, circular sanctuary protects Cleric's Capital
        final w37Path = ConquestFrontGeometry.buildClipPath(37, size);
        expect(w37Path.contains(solariaPt), isTrue);
        expect(w37Path.contains(citadelPt), isTrue);
        expect(w37Path.contains(duchyPt), isTrue);
        expect(w37Path.contains(portPt), isTrue);
        expect(w37Path.contains(capitalPt), isFalse);

        // Week 41: Sanctuary closes -> 100% conquered (including Cleric's Capital)
        final w41Path = ConquestFrontGeometry.buildClipPath(41, size);
        expect(w41Path.contains(capitalPt), isTrue);
      },
    );

    testWidgets(
      'Watch Tower displays localized World Map button across EN, PT, ES, DE and opens WorldMapWarDialog with 3:4 aspect ratio, interactive pins, and timeline slider',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
          'current_week': 36,
        });
        final storage = StorageService();
        await storage.init();

        final localization = LocalizationService();
        await tester.runAsync(() => localization.load());

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
          adService: AdService(),
        );
        addTearDown(controller.dispose);

        // Verify localized button labels across all 4 languages
        final expectedButtonLabels = {
          'en': 'World Map',
          'pt': 'Mapa Mundi',
          'es': 'Mapa Mundial',
          'de': 'Weltkarte',
        };
        for (final entry in expectedButtonLabels.entries) {
          localization.setLanguage(entry.key);
          expect(
            localization.t('observatory_world_map_btn'),
            equals(entry.value),
          );
        }
        localization.setLanguage('en');

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Watch Tower pin on WorldMapScreen
        await tester.tap(find.byKey(const ValueKey('landmark_telescope_tower')));
        await tester.pumpAndSettle();

        expect(find.byType(ObservatoryDialog), findsOneWidget);
        final worldMapBtn = find.byKey(
          const ValueKey('observatory_world_map_button'),
        );
        expect(worldMapBtn, findsOneWidget);
        expect(find.text('World Map'), findsOneWidget);

        // Open WorldMapWarDialog
        await tester.ensureVisible(worldMapBtn);
        await tester.pumpAndSettle();
        await tester.tap(worldMapBtn);
        await tester.pumpAndSettle();

        expect(find.byType(WorldMapWarDialog), findsOneWidget);
        expect(find.text('World Map — War Chronicle'), findsOneWidget);
        expect(find.text('Week 36 / 40'), findsWidgets);

        // Verify locked 3:4 viewport aspect ratio
        final viewportRect = tester.getRect(
          find.byKey(const ValueKey('world_map_war_aspect_viewport')),
        );
        expect(
          viewportRect.width / viewportRect.height,
          closeTo(3.0 / 4.0, 0.01),
        );

        // Week 36 is in Weeks 35–40 -> Border Alert banner & Cleric's Capital Under Threat
        expect(
          find.byKey(const ValueKey('world_map_border_alert_banner')),
          findsOneWidget,
        );
        expect(
          find.text('Border Alert — Siege Imminent!'),
          findsOneWidget,
        );
        expect(
          find.text('Under Threat — Border Alert'),
          findsOneWidget,
        );

        // Tap Kingdom of Solaria pin -> shows Conquered — Week 10
        await tester.tap(find.byKey(const ValueKey('world_map_pin_solaria')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('world_map_selected_realm_card')),
            matching: find.text('Kingdom of Solaria'),
          ),
          findsOneWidget,
        );
        expect(find.text('Conquered — Week 10'), findsOneWidget);

        // Tap Stone Citadel pin -> shows Conquered — Week 18
        await tester.tap(find.byKey(const ValueKey('world_map_pin_citadel')));
        await tester.pumpAndSettle();
        expect(find.text('Conquered — Week 18'), findsOneWidget);

        // Tap Verdant Duchy pin -> shows Conquered — Week 26
        await tester.tap(find.byKey(const ValueKey('world_map_pin_duchy')));
        await tester.pumpAndSettle();
        expect(find.text('Conquered — Week 26'), findsOneWidget);

        // Tap Crystal Port pin -> shows Conquered — Week 34
        await tester.tap(find.byKey(const ValueKey('world_map_pin_port')));
        await tester.pumpAndSettle();
        expect(find.text('Conquered — Week 34'), findsOneWidget);

        // Scrub timeline slider back to Week 1 (far left)
        final sliderFinder = find.byKey(
          const ValueKey('world_map_timeline_slider'),
        );
        expect(sliderFinder, findsOneWidget);
        final sliderTopLeft = tester.getTopLeft(sliderFinder);
        final sliderSize = tester.getSize(sliderFinder);
        await tester.tapAt(
          Offset(
            sliderTopLeft.dx + 4,
            sliderTopLeft.dy + sliderSize.height / 2,
          ),
        );
        await tester.pumpAndSettle();

        // At Week 1: 0% conquered layer & Crystal Port is Free
        expect(find.text('Week 1 / 40'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('world_map_conquered_clip_layer')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('world_map_border_alert_banner')),
          findsNothing,
        );
        expect(find.text('Free'), findsOneWidget);
      },
    );

    testWidgets(
      'Advancing past Week 40 triggers Week 41 Siege state, allows inspecting Week 41 in WorldMapWarDialog with Besieged status, and records Ending 2 (Invasion)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
          'current_week': 40,
          'darkMode': false,
        });
        final storage = StorageService();
        await storage.init();

        final localization = LocalizationService();
        await tester.runAsync(() => localization.load());

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
          adService: AdService(),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Enter battle at Week 40 and teleport out to advance to Week 41
        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('teleport_portal_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('teleport_confirm_button')));
        await tester.pumpAndSettle();

        // Kingdom Fall / Week 41 Siege modal is shown and currentWeek advanced to 41
        expect(
          find.byKey(const ValueKey('week40_kingdom_fall_dialog')),
          findsOneWidget,
        );
        expect(controller.currentWeek, GameController.siegeInvasionWeek);
        expect(
          find.byKey(const ValueKey('week41_siege_subtitle_badge')),
          findsOneWidget,
        );

        // Tap "World Map" inside the Week 41 Siege dialog to inspect Week 41
        await tester.tap(
          find.byKey(const ValueKey('week41_inspect_world_map_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(WorldMapWarDialog), findsOneWidget);
        expect(find.text('Week 41 / 40'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('world_map_siege_week41_banner')),
          findsOneWidget,
        );
        expect(find.text('Besieged — Week 41'), findsWidgets);

        // Close WorldMapWarDialog and confirm Kingdom Fall reset
        await tester.tap(
          find.byKey(const ValueKey('world_map_war_close_button')),
        );
        await tester.pumpAndSettle();

        // Before confirming reset, currentWeek == 41 -> maxInspectableWorldMapWeek == 41
        expect(controller.maxInspectableWorldMapWeek, 41);

        await tester.tap(
          find.byKey(const ValueKey('week40_kingdom_fall_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.timeoutDefeatCount, 1);
        // After reset to Week 0, maxInspectableWorldMapWeek clamps safely to 1 (no future spoilers)
        expect(controller.maxInspectableWorldMapWeek, 1);
      },
    );

    testWidgets(
      'World Map keeps identical rendered Size across Weeks 9, 10, and 39, fixed lore card height, and zero truncation or multi-line wrapping on header, 6 realm pins, and lore card header',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
          'current_week': 40,
        });
        final storage = StorageService();
        await storage.init();

        final localization = LocalizationService();
        await tester.runAsync(() => localization.load());

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
          adService: AdService(),
        );
        addTearDown(controller.dispose);

        Future<({Size mapSize, Size loreCardSize, Rect titleRect, double weekPillWidth})>
            pumpForWeek(int week) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: WorldMapWarDialog(
                    key: ValueKey('war_dialog_week_$week'),
                    controller: controller,
                    initialWeek: week,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final mapSize = tester.getSize(
            find.byKey(const ValueKey('world_map_war_aspect_viewport')),
          );
          final loreCardSize = tester.getSize(
            find.byKey(const ValueKey('world_map_selected_realm_card')),
          );
          final titleRect = tester.getRect(
            find.byKey(const ValueKey('world_map_modal_title_text')),
          );
          final weekPillWidth = tester
              .getSize(find.byKey(const ValueKey('world_map_week_pill')))
              .width;
          return (
            mapSize: mapSize,
            loreCardSize: loreCardSize,
            titleRect: titleRect,
            weekPillWidth: weekPillWidth,
          );
        }

        final w9 = await pumpForWeek(9);
        final w10 = await pumpForWeek(10);
        final w39 = await pumpForWeek(39);

        // Subtitle is completely removed from header
        expect(
          find.text(
            'Tap any realm pin or scrub the timeline to track the invasion',
          ),
          findsNothing,
        );

        // 1. Map dimensions stay 100% identical across Week 9, Week 10, and Week 39
        expect(w9.mapSize.width / w9.mapSize.height, closeTo(3.0 / 4.0, 0.005));
        expect(w10.mapSize, equals(w9.mapSize));
        expect(w39.mapSize, equals(w9.mapSize));

        // 2. Lore card keeps strict fixed height across weeks & pin selections
        expect(w10.loreCardSize, equals(w9.loreCardSize));
        expect(w39.loreCardSize, equals(w9.loreCardSize));

        // 3. Header title stays single-line & week pill keeps constant width (1-digit vs 2-digit)
        expect(w10.weekPillWidth, equals(w9.weekPillWidth));
        expect(w39.weekPillWidth, equals(w9.weekPillWidth));
        expect(w10.titleRect.width, equals(w9.titleRect.width));
        expect(w9.titleRect.height, lessThanOrEqualTo(24.0));
        final titleTextWidget = tester.widget<Text>(
          find.byKey(const ValueKey('world_map_modal_title_text')),
        );
        expect(titleTextWidget.maxLines, 1);
        expect(titleTextWidget.softWrap, isFalse);

        // 4. All 6 realm pin labels render completely on 1 single line without ellipsis truncation
        final mapRect = tester.getRect(
          find.byKey(const ValueKey('world_map_war_aspect_viewport')),
        );
        for (final region in WorldRealmRegion.values) {
          final pinFinder = find.byKey(ValueKey('world_map_pin_${region.id}'));
          expect(pinFinder, findsOneWidget);

          final pinTextFinder = find.descendant(
            of: pinFinder,
            matching: find.byType(Text),
          );
          final pinText = tester.widget<Text>(pinTextFinder);
          expect(pinText.maxLines, 1);
          expect(pinText.softWrap, isFalse);
          expect(pinText.overflow, isNull);

          final pinTextRect = tester.getRect(pinTextFinder);
          expect(pinTextRect.left, greaterThanOrEqualTo(mapRect.left));
          expect(pinTextRect.right, lessThanOrEqualTo(mapRect.right));

          // Tap each pin and verify lore card header name + status badge sit on separate rows without ellipsis
          await tester.tap(
            find.descendant(
              of: pinFinder,
              matching: find.byIcon(region.icon),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            tester.getSize(
              find.byKey(const ValueKey('world_map_selected_realm_card')),
            ),
            equals(w39.loreCardSize),
          );

          final realmNameFinder = find.byKey(
            const ValueKey('world_map_selected_realm_name'),
          );
          final statusBadgeFinder = find.byKey(
            const ValueKey('world_map_selected_realm_status_badge'),
          );
          final realmNameText = tester.widget<Text>(realmNameFinder);
          expect(realmNameText.maxLines, 1);
          expect(realmNameText.softWrap, isFalse);
          expect(realmNameText.overflow, isNull);

          final statusText = tester.widget<Text>(
            find.descendant(
              of: statusBadgeFinder,
              matching: find.byType(Text),
            ),
          );
          expect(statusText.maxLines, 1);
          expect(statusText.softWrap, isFalse);
          expect(statusText.overflow, isNull);

          final nameRect = tester.getRect(realmNameFinder);
          final badgeRect = tester.getRect(statusBadgeFinder);
          expect(badgeRect.top, greaterThanOrEqualTo(nameRect.bottom));
        }
      },
    );

    testWidgets(
      'Timeline slider restricts scrubbing strictly to Week 1..currentWeek (no future spoilers) and renders safely locked on Week 0 and Week 1',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Case A: Week 0 and Week 1 render locked Slider safely without divisions error
        for (final week in [0, 1]) {
          SharedPreferences.setMockInitialValues({
            'has_seen_story_intro': true,
            'animationsEnabled': false,
            'musicEnabled': false,
            'current_week': week,
            'timeout_defeat_count': 3, // Even after prior invasions, never spoil future weeks!
          });
          final storage = StorageService();
          await storage.init();

          final localization = LocalizationService();
          await tester.runAsync(() => localization.load());

          final controller = GameController(
            storage: storage,
            localization: localization,
            audio: AudioService(),
            adService: AdService(),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: WorldMapWarDialog(
                    key: ValueKey('locked_dialog_week_$week'),
                    controller: controller,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(
            find.text(
              'Tap any realm pin or scrub the timeline to track the invasion',
            ),
            findsNothing,
          );
          final rangeText = tester.widget<Text>(
            find.byKey(const ValueKey('world_map_timeline_range_label')),
          );
          expect(rangeText.data, 'Week 1');

          final slider = tester.widget<Slider>(
            find.byKey(const ValueKey('world_map_timeline_slider')),
          );
          expect(slider.min, 1.0);
          expect(slider.max, 1.0);
          expect(slider.value, 1.0);
          expect(slider.divisions, isNull);
          expect(slider.onChanged, isNull);

          controller.dispose();
        }

        // Case B: currentWeek == 2 allows scrubbing only between Week 1 and Week 2 (never Week 3+)
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
          'current_week': 2,
          'timeout_defeat_count': 2,
        });
        final storage = StorageService();
        await storage.init();
        final localization = LocalizationService();
        await tester.runAsync(() => localization.load());
        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
          adService: AdService(),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: WorldMapWarDialog(controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Week 2 / 40'), findsOneWidget);
        expect(find.text('Week 1 — Week 2'), findsOneWidget);

        final sliderFinder = find.byKey(
          const ValueKey('world_map_timeline_slider'),
        );
        final slider = tester.widget<Slider>(sliderFinder);
        expect(slider.min, 1.0);
        expect(slider.max, 2.0);
        expect(slider.divisions, 1);
        expect(slider.value, 2.0);
        expect(slider.onChanged, isNotNull);

        // Attempting to tap far right of slider stays capped at Week 2
        final topLeft = tester.getTopLeft(sliderFinder);
        final size = tester.getSize(sliderFinder);
        await tester.tapAt(
          Offset(topLeft.dx + size.width - 4, topLeft.dy + size.height / 2),
        );
        await tester.pumpAndSettle();
        expect(find.text('Week 2 / 40'), findsOneWidget);

        // Scrubbing left moves back to Week 1
        await tester.tapAt(
          Offset(topLeft.dx + 4, topLeft.dy + size.height / 2),
        );
        await tester.pumpAndSettle();
        expect(find.text('Week 1 / 40'), findsOneWidget);
      },
    );
  });
}

