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

  group('AltarSacrificeDialog Proportional Orb Scaling (15 to 20,000)', () {
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

        // Larger sacrifices produce visibly fuller piles on the altar basin
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
  });

  group('AltarSacrificeDialog Multi-Phase Sequence & ShopDialog Integration', () {
    for (final isDark in [true, false]) {
      testWidgets(
        'Purchasing Reset Button in Offerings runs Phase 1 (orbs & holocaust flame), Phase 2 (descending star & warm cream flash), and Phase 3 (emblem, title & description) in ${isDark ? "Dark" : "Light"} Mode',
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

          // Tap to purchase Reset Button (30 Fire, 30 Water, 30 Wood)
          await tester.tap(resetUnlockBtn);
          await tester.pump();
          // Advance past the 240ms dialog entrance transition into Phase 1 (~0.45s)
          await tester.pump(const Duration(milliseconds: 450));

          // Legacy comic StoryDialog must NOT appear
          expect(find.byType(StoryDialog), findsNothing);
          expect(
            find.byKey(const ValueKey('altar_sacrifice_dialog')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('sacred_altar_artwork')),
            findsOneWidget,
          );

          // Before 0.8s, Skip button is hidden
          expect(
            find.byKey(const ValueKey('altar_sacrifice_skip_button')),
            findsNothing,
          );

          // Verify Phase 1 CustomPainter and exact 30 Fire / Water / Wood counters
          final paintWidget = tester.widget<CustomPaint>(
            find.byKey(const ValueKey('altar_sacrifice_custom_paint')),
          );
          final painter = paintWidget.painter as AltarSacrificePainter;
          expect(
            AltarSacrificeDialog.phaseForProgress(painter.progress),
            AltarRitualPhase.offeringAndFlame,
          );
          expect(painter.clusters.length, 3);
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

          // Advance past 0.8s (~0.95s total): Skip button unlocks
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            find.byKey(const ValueKey('altar_sacrifice_skip_button')),
            findsOneWidget,
          );

          // Advance into Phase 2 (~1.75s total): Descending Star & Warm Cream/Gold Flash
          await tester.pump(const Duration(milliseconds: 800));
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

          // Settle into Phase 3 (~3.0s): Acquired Item Reveal + Description + Continue
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
          expect(titleText.style?.color, AppPalette(isDark: isDark).primaryText);

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
      'Tap-to-skip after ~0.8s fast-forwards directly to Phase 3 item reveal',
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 950));

        // Still in Phase 1, Skip is available after 0.8s
        expect(
          find.byKey(const ValueKey('altar_sacrifice_stage')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('altar_sacrifice_skip_button')),
          findsOneWidget,
        );

        // Tap stage to fast-forward immediately to Phase 3 reveal
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
      '20,000 5-element sacrifice renders signature Fire, Water, Wood, bronze-brown Earth, and silver Metal orbs with exact formatted counters and localized strings',
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
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        // Verify all 5 elemental spheres & exact "20,000" numeric counters in Phase 1
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

        // Verify painter holds 5 clusters with 12-18 visual orbs each (zero UI freeze)
        final paintWidget = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('altar_sacrifice_custom_paint')),
        );
        final painter = paintWidget.painter as AltarSacrificePainter;
        expect(painter.clusters.length, 5);
        for (final cluster in painter.clusters) {
          expect(cluster.visualOrbCount, inInclusiveRange(12, 18));
        }

        // Settle to Phase 3 and verify Portuguese grouping ("20.000") & Crystal Ball+ emblem
        await tester.pumpAndSettle();
        controller.setLanguage('pt');
        await tester.pump();
        expect(find.text('20.000'), findsNWidgets(5));
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
