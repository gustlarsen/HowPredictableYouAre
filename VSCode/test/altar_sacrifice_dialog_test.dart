import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/models/royal_castle.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/billing_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/theme/app_theme.dart';
import 'package:how_predictable/views/dialogs/altar_sacrifice_dialog.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';
import 'package:how_predictable/views/dialogs/story_dialog.dart';
import 'package:how_predictable/views/widgets/elemental_energy_sphere.dart';

Future<GameController> _buildTestController({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_story_intro': true,
    'animationsEnabled': true,
    'musicEnabled': false,
    'soundEnabled': false,
    'orbs_fire': 30000,
    'orbs_water': 30000,
    'orbs_wood': 30000,
    'orbs_earth': 30000,
    'orbs_metal': 30000,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();
  final localization = LocalizationService();
  await localization.load();
  return GameController(
    storage: storage,
    localization: localization,
    audio: AudioService(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AltarSacrificeDialog Proportional Orb Scaling & 2x Pacing', () {
    test(
      'visualOrbCountForCost scales smoothly from ~3-5 at small costs (15-50) up to ~12-18 at 3,500-20,000',
      () {
        expect(AltarSacrificeDialog.visualOrbCountForCost(0), 0);

        final count15 = AltarSacrificeDialog.visualOrbCountForCost(15);
        final count30 = AltarSacrificeDialog.visualOrbCountForCost(30);
        final count50 = AltarSacrificeDialog.visualOrbCountForCost(50);
        final count250 = AltarSacrificeDialog.visualOrbCountForCost(250);
        final count1000 = AltarSacrificeDialog.visualOrbCountForCost(1000);
        final count3500 = AltarSacrificeDialog.visualOrbCountForCost(3500);
        final count5000 = AltarSacrificeDialog.visualOrbCountForCost(5000);
        final count20000 = AltarSacrificeDialog.visualOrbCountForCost(20000);

        expect(count15, inInclusiveRange(3, 5));
        expect(count30, inInclusiveRange(3, 5));
        expect(count50, inInclusiveRange(4, 6));
        expect(count3500, inInclusiveRange(12, 18));
        expect(count5000, inInclusiveRange(12, 18));
        expect(count20000, inInclusiveRange(12, 18));

        // Monotonically non-decreasing across the entire 15 -> 20,000 progression
        expect(count15, lessThanOrEqualTo(count30));
        expect(count30, lessThanOrEqualTo(count50));
        expect(count50, lessThan(count250));
        expect(count250, lessThan(count1000));
        expect(count1000, lessThan(count3500));
        expect(count3500, lessThanOrEqualTo(count5000));
        expect(count5000, lessThan(count20000));
      },
    );

    test(
      'totalDuration (~6.2s), skipUnlockDelay (~1.5s), and phaseForProgress match slower 2x ritual pacing',
      () {
        expect(
          AltarSacrificeDialog.totalDuration.inMilliseconds,
          inInclusiveRange(5600, 6800),
        );
        expect(
          AltarSacrificeDialog.skipUnlockDelay.inMilliseconds,
          inInclusiveRange(1400, 1600),
        );

        // Phase 1: 0.0s – 2.2s
        expect(
          AltarSacrificeDialog.phaseForProgress(0.0),
          AltarRitualPhase.offeringAndFlame,
        );
        expect(
          AltarSacrificeDialog.phaseForProgress(
            1.8 / AltarSacrificeDialog.totalDurationSeconds,
          ),
          AltarRitualPhase.offeringAndFlame,
        );

        // Phase 2: 2.2s – 4.0s
        expect(
          AltarSacrificeDialog.phaseForProgress(
            2.5 / AltarSacrificeDialog.totalDurationSeconds,
          ),
          AltarRitualPhase.descendingStarAndFlash,
        );
        expect(
          AltarSacrificeDialog.phaseForProgress(
            3.8 / AltarSacrificeDialog.totalDurationSeconds,
          ),
          AltarRitualPhase.descendingStarAndFlash,
        );

        // Phase 3: 4.0s – 6.2s
        expect(
          AltarSacrificeDialog.phaseForProgress(
            4.2 / AltarSacrificeDialog.totalDurationSeconds,
          ),
          AltarRitualPhase.itemReveal,
        );
        expect(
          AltarSacrificeDialog.phaseForProgress(1.0),
          AltarRitualPhase.itemReveal,
        );
      },
    );

    test(
      'buildVisualOrbClusters positions orbs cleanly inside the altar basin for 2, 3, and 5 elements up to 20,000',
      () {
        final smallClusters = AltarSacrificeDialog.buildVisualOrbClusters(
          GameController.costPredictability, // 15 Fire, 15 Water, 15 Wood
        );
        expect(smallClusters.length, 3);
        for (final cluster in smallClusters) {
          expect(cluster.exactCost, 15);
          expect(cluster.visualOrbCount, inInclusiveRange(3, 5));
          expect(cluster.orbs.length, cluster.visualOrbCount);
        }

        const maxSacrifice = ElementalCost(
          fire: 20000,
          water: 20000,
          wood: 20000,
          earth: 20000,
          metal: 20000,
        );
        final hugeClusters = AltarSacrificeDialog.buildVisualOrbClusters(
          maxSacrifice,
        );
        expect(hugeClusters.length, 5);
        for (final cluster in hugeClusters) {
          expect(cluster.exactCost, 20000);
          expect(cluster.visualOrbCount, inInclusiveRange(12, 18));
          expect(cluster.orbs.length, cluster.visualOrbCount);
          for (final orb in cluster.orbs) {
            expect(orb.normalizedAltarPos.dx, inInclusiveRange(0.28, 0.72));
            expect(orb.normalizedAltarPos.dy, inInclusiveRange(0.44, 0.55));
          }
        }

        final smallTotal = smallClusters.fold<int>(
          0,
          (sum, c) => sum + c.visualOrbCount,
        );
        final hugeTotal = hugeClusters.fold<int>(
          0,
          (sum, c) => sum + c.visualOrbCount,
        );
        expect(hugeTotal, greaterThan(smallTotal * 4));
      },
    );

    test(
      'Pre-sacrifice confirmation localization keys exist and are translated across en, pt, es, and de',
      () async {
        final localization = LocalizationService();
        await localization.load();

        const keys = [
          'altar_sacrifice_phase_confirm',
          'altar_sacrifice_confirm_prompt',
          'altar_sacrifice_confirm_btn',
          'altar_sacrifice_cancel_btn',
          'altar_offering_orbs_label',
        ];

        final enValues = <String, String>{};
        localization.setLanguage('en');
        for (final k in keys) {
          final v = localization.t(k);
          expect(v, isNotEmpty);
          expect(v, isNot(k));
          enValues[k] = v;
        }
        expect(enValues['altar_sacrifice_confirm_prompt'], contains('{item}'));

        for (final lang in ['pt', 'es', 'de']) {
          localization.setLanguage(lang);
          for (final k in keys) {
            final v = localization.t(k);
            expect(v, isNotEmpty, reason: 'Missing $lang $k');
            expect(v, isNot(k), reason: 'Fallback key for $lang $k');
            expect(v, isNot(enValues[k]), reason: 'Untranslated $lang $k');
          }
          expect(
            localization.t('altar_sacrifice_confirm_prompt'),
            contains('{item}'),
          );
        }
      },
    );
  });

  group('AltarSacrificeDialog Pre-Sacrifice Confirmation & Slower 2x Sequence', () {
    testWidgets(
      'Tapping an Offerings item opens Altar in awaitingConfirmation without deducting orbs; Cancel leaves balances & unlock untouched',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _buildTestController(
          prefs: {
            'orbs_fire': 100,
            'orbs_water': 100,
            'orbs_wood': 100,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: ShopDialog(
                controller: controller,
                initialWing: TempleWing.offerings,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final shopScrollable = find.descendant(
          of: find.byKey(const ValueKey('temple_wing_offerings')),
          matching: find.byType(Scrollable),
        );
        final resetUnlockBtn = find.byKey(
          const ValueKey('diamond_unlock_${BillingService.productResetButton}'),
        );
        await tester.scrollUntilVisible(
          resetUnlockBtn,
          140,
          scrollable: shopScrollable,
        );
        await tester.pumpAndSettle();

        // Tap Reset Button (cost: 30 Fire, 30 Water, 30 Wood)
        await tester.tap(resetUnlockBtn);
        await tester.pumpAndSettle();

        // Altar dialog opens in staging/confirmation mode BEFORE deducting any orbs
        expect(
          find.byKey(const ValueKey('altar_sacrifice_dialog')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('sacred_altar_artwork')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('altar_sacrifice_confirm_prompt_text')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Reset Button'),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.byKey(const ValueKey('altar_sacrifice_confirm_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('altar_sacrifice_cancel_button')),
          findsOneWidget,
        );
        // Skip button is not shown while awaiting confirmation
        expect(
          find.byKey(const ValueKey('altar_sacrifice_skip_button')),
          findsNothing,
        );

        // Painter is strictly in staging mode (resting orbs, progress 0.0, no flames)
        final paintWidget = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('altar_sacrifice_custom_paint')),
        );
        final painter = paintWidget.painter as AltarSacrificePainter;
        expect(painter.isStaging, isTrue);
        expect(painter.progress, 0.0);
        expect(painter.clusters.length, 3);

        // Exact numeric costs displayed on the altar confirmation card
        for (final move in const [
          HandMove.fire,
          HandMove.water,
          HandMove.wood,
        ]) {
          final pill = find.byKey(
            ValueKey('altar_sacrifice_cost_${move.orbKey}'),
          );
          expect(pill, findsOneWidget);
          expect(
            find.descendant(of: pill, matching: find.text('30')),
            findsOneWidget,
          );
        }

        // Orbs & unlock flag MUST remain untouched before confirmation
        expect(controller.unlockedReset, isFalse);
        expect(controller.fireOrbs, 100);
        expect(controller.waterOrbs, 100);
        expect(controller.woodOrbs, 100);

        // Tap Cancel -> closes Altar cleanly without deducting orbs or unlocking
        await tester.tap(
          find.byKey(const ValueKey('altar_sacrifice_cancel_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('altar_sacrifice_dialog')),
          findsNothing,
        );
        expect(controller.unlockedReset, isFalse);
        expect(controller.fireOrbs, 100);
        expect(controller.waterOrbs, 100);
        expect(controller.woodOrbs, 100);
        expect(tester.takeException(), isNull);
      },
    );

    for (final isDark in [true, false]) {
      testWidgets(
        'Confirming Reset Button deducts orbs and plays slower 6.2s Phase 1 (flame), Phase 2 (star & warm cream flash), and Phase 3 (emblem, title & description) in ${isDark ? "Dark" : "Light"} Mode',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final controller = await _buildTestController(
            prefs: {'darkMode': isDark},
          );
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            MaterialApp(
              theme: isDark
                  ? ThemeData.dark(useMaterial3: true)
                  : ThemeData.light(useMaterial3: true),
              home: Scaffold(
                body: ShopDialog(
                  controller: controller,
                  initialWing: TempleWing.offerings,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final shopScrollable = find.descendant(
            of: find.byKey(const ValueKey('temple_wing_offerings')),
            matching: find.byType(Scrollable),
          );
          final resetUnlockBtn = find.byKey(
            const ValueKey(
              'diamond_unlock_${BillingService.productResetButton}',
            ),
          );
          await tester.scrollUntilVisible(
            resetUnlockBtn,
            140,
            scrollable: shopScrollable,
          );
          await tester.pumpAndSettle();

          // 1. Open Pre-Sacrifice Altar Confirmation
          await tester.tap(resetUnlockBtn);
          await tester.pumpAndSettle();

          expect(find.byType(StoryDialog), findsNothing);
          expect(controller.unlockedReset, isFalse);
          expect(controller.fireOrbs, 30000);

          // 2. Tap Confirm Sacrifice -> deducts 30 Fire/Water/Wood and begins 6.2s ritual
          await tester.tap(
            find.byKey(const ValueKey('altar_sacrifice_confirm_button')),
          );
          await tester.pump();

          expect(controller.unlockedReset, isTrue);
          expect(controller.fireOrbs, 29970);
          expect(controller.waterOrbs, 29970);
          expect(controller.woodOrbs, 29970);

          // Advance 1.0s into Phase 1 (0.0s – 2.2s): confirmation controls gone, Skip still locked (< 1.5s)
          await tester.pump(const Duration(milliseconds: 1000));
          expect(
            find.byKey(const ValueKey('altar_sacrifice_confirm_button')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('altar_sacrifice_skip_button')),
            findsNothing,
          );

          final paintWidget1 = tester.widget<CustomPaint>(
            find.byKey(const ValueKey('altar_sacrifice_custom_paint')),
          );
          final painter1 = paintWidget1.painter as AltarSacrificePainter;
          expect(painter1.isStaging, isFalse);
          expect(
            AltarSacrificeDialog.phaseForProgress(painter1.progress),
            AltarRitualPhase.offeringAndFlame,
          );

          // Advance another 0.7s (1.7s total): still Phase 1, Skip button now unlocked (> 1.5s)
          await tester.pump(const Duration(milliseconds: 700));
          expect(
            find.byKey(const ValueKey('altar_sacrifice_skip_button')),
            findsOneWidget,
          );
          final paintWidget1b = tester.widget<CustomPaint>(
            find.byKey(const ValueKey('altar_sacrifice_custom_paint')),
          );
          expect(
            AltarSacrificeDialog.phaseForProgress(
              (paintWidget1b.painter as AltarSacrificePainter).progress,
            ),
            AltarRitualPhase.offeringAndFlame,
          );

          // Advance another 1.8s (3.5s total): Phase 2 Descending Star & Warm Cream/Gold Flash
          await tester.pump(const Duration(milliseconds: 1800));
          expect(
            find.byKey(const ValueKey('altar_luminous_flash_overlay')),
            findsOneWidget,
          );
          final flashBox = tester.widget<DecoratedBox>(
            find.byKey(const ValueKey('altar_luminous_flash_overlay')),
          );
          final gradient =
              (flashBox.decoration as BoxDecoration).gradient as RadialGradient;
          expect(
            gradient.colors.first.toARGB32() & 0x00FFFFFF,
            AltarSacrificeDialog.warmCreamFlash.toARGB32() & 0x00FFFFFF,
          );
          expect(
            gradient.colors[1].toARGB32() & 0x00FFFFFF,
            AltarSacrificeDialog.warmGoldFlash.toARGB32() & 0x00FFFFFF,
          );
          // Still hasn't switched to reveal yet at 3.5s (swaps at 3.88s)
          expect(
            find.byKey(const ValueKey('altar_item_reveal_stage')),
            findsNothing,
          );

          // Settle through the rest of the 6.2s ritual into Phase 3 Reveal
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('altar_item_reveal_stage')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('altar_reveal_item_emblem')),
            findsOneWidget,
          );
          final emblemImg = tester.widget<Image>(
            find.byKey(const ValueKey('altar_reveal_emblem_image_reset')),
          );
          expect(
            (emblemImg.image as AssetImage).assetName,
            'assets/images/offerings/reset_button.webp',
          );

          final titleText = tester.widget<Text>(
            find.byKey(const ValueKey('altar_reveal_item_title')),
          );
          expect(titleText.data, 'Reset Button');
          expect(
            titleText.style?.color,
            AppPalette(isDark: isDark).primaryText,
          );

          final descText = tester.widget<Text>(
            find.byKey(const ValueKey('altar_reveal_item_description')),
          );
          expect(
            descText.data,
            'Adds a Reset button to clear the current match and Markov matrix anytime',
          );

          // Tap Continue to close modal cleanly
          await tester.tap(
            find.byKey(const ValueKey('altar_reveal_collect_button')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('altar_sacrifice_dialog')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'Tap-to-skip stays locked before ~1.5s and fast-forwards directly to Phase 3 reveal after ~1.5s',
      (WidgetTester tester) async {
        final controller = await _buildTestController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: ShopDialog(
                controller: controller,
                initialWing: TempleWing.offerings,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(
            const ValueKey(
              'diamond_unlock_${BillingService.productPredictabilityScore}',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Confirm sacrifice to start animation
        await tester.tap(
          find.byKey(const ValueKey('altar_sacrifice_confirm_button')),
        );
        await tester.pump();

        // At 1.0s (< 1.5s), tapping stage does NOT skip
        await tester.pump(const Duration(milliseconds: 1000));
        expect(
          find.byKey(const ValueKey('altar_sacrifice_skip_button')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('altar_sacrifice_stage')));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('altar_item_reveal_stage')),
          findsNothing,
        );

        // At 1.7s (> 1.5s), Skip unlocks and tapping stage fast-forwards to Phase 3
        await tester.pump(const Duration(milliseconds: 700));
        expect(
          find.byKey(const ValueKey('altar_sacrifice_skip_button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('altar_sacrifice_stage')));
        await tester.pump();

        expect(
          find.byKey(const ValueKey('altar_item_reveal_stage')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey('altar_reveal_emblem_image_predictability'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '20,000 5-element sacrifice confirmation & reveal renders Fire, Water, Wood, bronze-brown Earth, and silver Metal orbs cleanly across languages without overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _buildTestController();
        addTearDown(controller.dispose);

        const maxFiveElementCost = ElementalCost(
          fire: 20000,
          water: 20000,
          wood: 20000,
          earth: 20000,
          metal: 20000,
        );
        bool confirmedCallbackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: AltarSacrificeDialog(
                controller: controller,
                artifact: ShopUpgradeArtifact.crystalBallPlus,
                itemTitle: controller.localization.t(
                  'string82',
                  fallback: 'Crystal Ball+',
                ),
                itemDescription: controller.localization.t(
                  'crystal_ball_plus_desc',
                ),
                sacrificedCost: maxFiveElementCost,
                emblemAssetPath: AltarSacrificeDialog.emblemAssetForArtifact(
                  ShopUpgradeArtifact.crystalBallPlus,
                ),
                fallbackIcon: ShopUpgradeArtifact.crystalBallPlus.icon,
                onConfirmSacrifice: () {
                  confirmedCallbackCalled = true;
                  return true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(confirmedCallbackCalled, isFalse);

        // Verify all 5 elemental spheres & exact "20,000" counters during pre-sacrifice confirmation
        final expectedColors = <HandMove, Color>{
          HandMove.fire: const Color(0xFFFF5722),
          HandMove.water: const Color(0xFF00B0FF),
          HandMove.wood: const Color(0xFF00E676),
          HandMove.earth: const Color(0xFFC47A38), // bronze-brown
          HandMove.metal: const Color(0xFFB0BEC5), // silver
        };

        for (final entry in expectedColors.entries) {
          final move = entry.key;
          final sphere = tester.widget<ElementalEnergySphere>(
            find.byKey(ValueKey('altar_sacrifice_orb_sphere_${move.orbKey}')),
          );
          expect(sphere.primaryColor, entry.value);

          final costRow = find.byKey(
            ValueKey('altar_sacrifice_cost_${move.orbKey}'),
          );
          expect(
            find.descendant(of: costRow, matching: find.text('20,000')),
            findsOneWidget,
          );
        }

        // Verify painter holds 5 staged clusters with 12-18 visual orbs each (zero UI freeze)
        final paintWidget = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('altar_sacrifice_custom_paint')),
        );
        final painter = paintWidget.painter as AltarSacrificePainter;
        expect(painter.isStaging, isTrue);
        expect(painter.clusters.length, 5);
        for (final cluster in painter.clusters) {
          expect(cluster.visualOrbCount, inInclusiveRange(12, 18));
        }

        // Switch language to Portuguese during confirmation and verify localized button & grouping
        controller.setLanguage('pt');
        await tester.pump();
        expect(find.text('Confirmar Sacrifício'), findsOneWidget);
        expect(find.text('Cancelar'), findsOneWidget);
        expect(find.text('20.000'), findsNWidgets(5));

        // Confirm sacrifice -> runs callback and settles to Phase 3 Crystal Ball+ reveal
        await tester.tap(
          find.byKey(const ValueKey('altar_sacrifice_confirm_button')),
        );
        await tester.pumpAndSettle();
        expect(confirmedCallbackCalled, isTrue);
        expect(
          find.byKey(
            const ValueKey('altar_reveal_emblem_image_crystal_ball_plus'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
