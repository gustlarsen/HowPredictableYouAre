import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/full_screen_spyglass_view.dart';
import 'package:how_predictable/views/dialogs/metal_wizard_spyglass_dialog.dart';
import 'package:how_predictable/views/dialogs/observatory_dialog.dart';
import 'package:how_predictable/views/widgets/watchtower_forge_view.dart';

Future<GameController> _createController({
  String language = 'en',
  bool animationsEnabled = false,
  int currentWeek = 0,
  int enemyStage = 1,
  int lastSeenMetalWizardForgeWeek = -1,
  bool hasShownWeek0ScreamWarning = true,
  bool hasShownWeek10ArchmageWarning = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_story_intro': true,
    'darkMode': true,
    'animationsEnabled': animationsEnabled,
    'musicEnabled': false,
    'soundEnabled': false,
    'vibrationEnabled': false,
    'language': language,
    'current_week': currentWeek,
    'enemy_stage': enemyStage,
    'last_seen_metal_wizard_forge_week': lastSeenMetalWizardForgeWeek,
    'has_shown_week0_scream_warning': hasShownWeek0ScreamWarning,
    'has_shown_week10_archmage_warning': hasShownWeek10ArchmageWarning,
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

  group('Robot Archmage Progressive Forge Assembly & Week 10 Awakening Tests', () {
    test(
      'All 22 generated watchtower assets plus Titanium Robot Egg sprite are bundled and loadable',
      () async {
        final expectedAssets = <String>[
          WatchtowerForgeView.babyRobotEggAsset,
          WatchtowerForgeView.nakedFrameAsset,
          ...WatchtowerForgeView.stageAssets,
          ...WatchtowerForgeView.partAssets,
          for (int w = 0; w <= 6; w++)
            WatchtowerForgeView.pileAssetForWeek(w)!,
        ];
        expect(expectedAssets.length, 23);

        for (final asset in expectedAssets) {
          final bytes = await rootBundle.load(asset);
          expect(
            bytes.lengthInBytes,
            greaterThan(1000),
            reason: 'Asset $asset should be bundled and non-empty',
          );
        }

        // Targeted joint coordinates exist for Weeks 1..8 and are null outside
        expect(WatchtowerForgeView.weldingJointNormalizedForWeek(0), isNull);
        for (int w = 1; w <= 8; w++) {
          final pt = WatchtowerForgeView.weldingJointNormalizedForWeek(w);
          expect(pt, isNotNull);
          expect(pt!.dx, inInclusiveRange(0.2, 0.8));
          expect(pt.dy, inInclusiveRange(0.1, 0.8));
        }
        expect(WatchtowerForgeView.weldingJointNormalizedForWeek(9), isNull);
      },
    );

    testWidgets(
      'Metal Wizard spyglass renders Week 0 Titanium Robot Egg enchantment, Weeks 1-9 progressive Archmage assembly, Weeks 10-39 Overcharged Egg, and Week 40+ cooling in both circular and full-screen views',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final cases = <({
          int week,
          int enemyStage,
          ForgeAssemblyPhase expectedPhase,
          String? expectedRigAsset,
          String? expectedPileAsset,
          bool expectBlueprint,
          bool expectDormantMask,
          bool expectPoweredVfx,
          bool expectEgg,
          bool expectEggOvercharged,
          bool expectCooling,
        })>[
          (
            week: 0,
            enemyStage: 1,
            expectedPhase: ForgeAssemblyPhase.week0EggEnchantment,
            expectedRigAsset: WatchtowerForgeView.babyRobotEggAsset,
            expectedPileAsset: null,
            expectBlueprint: false,
            expectDormantMask: false,
            expectPoweredVfx: false,
            expectEgg: true,
            expectEggOvercharged: false,
            expectCooling: false,
          ),
          (
            week: 1,
            enemyStage: 1,
            expectedPhase: ForgeAssemblyPhase.bareMetalAssembly,
            expectedRigAsset:
                'assets/images/watchtower/archmage_stage_1_leg1.png',
            expectedPileAsset:
                'assets/images/watchtower/archmage_pile_week_1.png',
            expectBlueprint: true,
            expectDormantMask: false,
            expectPoweredVfx: false,
            expectEgg: false,
            expectEggOvercharged: false,
            expectCooling: false,
          ),
          (
            week: 4,
            enemyStage: 1,
            expectedPhase: ForgeAssemblyPhase.bareMetalAssembly,
            expectedRigAsset:
                'assets/images/watchtower/archmage_stage_4_torso.png',
            expectedPileAsset:
                'assets/images/watchtower/archmage_pile_week_4.png',
            expectBlueprint: true,
            expectDormantMask: false,
            expectPoweredVfx: false,
            expectEgg: false,
            expectEggOvercharged: false,
            expectCooling: false,
          ),
          (
            week: 6,
            enemyStage: 1,
            expectedPhase: ForgeAssemblyPhase.bareMetalAssembly,
            expectedRigAsset:
                'assets/images/watchtower/archmage_stage_6_arms.png',
            expectedPileAsset:
                'assets/images/watchtower/archmage_pile_week_6.png',
            expectBlueprint: true,
            expectDormantMask: false,
            expectPoweredVfx: false,
            expectEgg: false,
            expectEggOvercharged: false,
            expectCooling: false,
          ),
          (
            week: 7,
            enemyStage: 1,
            expectedPhase: ForgeAssemblyPhase.bareMetalAssembly,
            expectedRigAsset:
                'assets/images/watchtower/archmage_stage_7_head.png',
            expectedPileAsset: null,
            expectBlueprint: true,
            expectDormantMask: false,
            expectPoweredVfx: false,
            expectEgg: false,
            expectEggOvercharged: false,
            expectCooling: false,
          ),
          (
            week: 8,
            enemyStage: 1,
            expectedPhase: ForgeAssemblyPhase.archmageDormant,
            expectedRigAsset: WatchtowerForgeView.robotArchmageAsset,
            expectedPileAsset: null,
            expectBlueprint: false,
            expectDormantMask: true,
            expectPoweredVfx: false,
            expectEgg: false,
            expectEggOvercharged: false,
            expectCooling: false,
          ),
          (
            week: 9,
            enemyStage: 1,
            expectedPhase: ForgeAssemblyPhase.archmagePowered,
            expectedRigAsset: WatchtowerForgeView.robotArchmageAsset,
            expectedPileAsset: null,
            expectBlueprint: false,
            expectDormantMask: false,
            expectPoweredVfx: true,
            expectEgg: false,
            expectEggOvercharged: false,
            expectCooling: false,
          ),
          (
            week: 10,
            enemyStage: 2,
            expectedPhase: ForgeAssemblyPhase.eggOvercharged,
            expectedRigAsset: WatchtowerForgeView.babyRobotEggAsset,
            expectedPileAsset: null,
            expectBlueprint: false,
            expectDormantMask: false,
            expectPoweredVfx: false,
            expectEgg: true,
            expectEggOvercharged: true,
            expectCooling: false,
          ),
          (
            week: 40,
            enemyStage: 2,
            expectedPhase: ForgeAssemblyPhase.coolingDown,
            expectedRigAsset: null,
            expectedPileAsset: null,
            expectBlueprint: false,
            expectDormantMask: false,
            expectPoweredVfx: false,
            expectEgg: false,
            expectEggOvercharged: false,
            expectCooling: true,
          ),
        ];

        for (final c in cases) {
          final controller = await _createController(
            currentWeek: c.week,
            enemyStage: c.enemyStage,
            animationsEnabled: false,
          );
          addTearDown(controller.dispose);

          // 1. Circular Watch Tower Spyglass Modal
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: MetalWizardSpyglassDialog(controller: controller),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final view = tester.widget<WatchtowerForgeView>(
            find.byType(WatchtowerForgeView),
          );
          expect(view.currentWeek, c.week);
          expect(view.assemblyPhase, c.expectedPhase);
          expect(view.activeRigSpriteAsset, c.expectedRigAsset);
          expect(view.activePileAsset, c.expectedPileAsset);
          expect(view.isArchmageEyePoweredOff, c.expectDormantMask);
          expect(view.isArchmageEyePoweredOn, c.expectPoweredVfx);
          expect(view.isEggOnPedestal, c.expectEgg);
          expect(view.isEggOvercharged, c.expectEggOvercharged);

          expect(
            find.byKey(const ValueKey('watchtower_forge_blueprint_hologram')),
            c.expectBlueprint ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey('watchtower_forge_parts_pile_image')),
            c.expectedPileAsset != null ? findsOneWidget : findsNothing,
          );
          if (c.expectedPileAsset != null) {
            final pileImg = tester.widget<Image>(
              find.byKey(const ValueKey('watchtower_forge_parts_pile_image')),
            );
            expect(
              (pileImg.image as AssetImage).assetName,
              c.expectedPileAsset,
            );
          }
          expect(
            find.byKey(const ValueKey('watchtower_forge_archmage_dormant_mask')),
            c.expectDormantMask ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey('watchtower_forge_archmage_powered_vfx')),
            c.expectPoweredVfx ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey('watchtower_forge_egg_image')),
            c.expectEgg ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(
              const ValueKey('watchtower_forge_egg_enchantment_painter'),
            ),
            c.expectEgg ? findsOneWidget : findsNothing,
          );
          if (c.expectEgg) {
            final eggImg = tester.widget<Image>(
              find.byKey(const ValueKey('watchtower_forge_egg_image')),
            );
            expect(
              (eggImg.image as AssetImage).assetName,
              WatchtowerForgeView.babyRobotEggAsset,
            );
            final eggPaint = tester.widget<CustomPaint>(
              find.byKey(
                const ValueKey('watchtower_forge_egg_enchantment_painter'),
              ),
            );
            expect(eggPaint.painter, isA<EggEnchantmentPainter>());
            expect(
              (eggPaint.painter as EggEnchantmentPainter).isOvercharged,
              c.expectEggOvercharged,
            );
          }
          expect(
            find.byKey(const ValueKey('watchtower_forge_metal_wizard_image')),
            c.expectCooling ? findsNothing : findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('watchtower_forge_cooling_state')),
            c.expectCooling ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);

          // 2. FullScreenSpyglassView (pinch-zoom/pan viewport) at same week
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: FullScreenSpyglassView(
                controller: controller,
                target: SpyglassTarget.metalWizard,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final fullView = tester.widget<WatchtowerForgeView>(
            find.byType(WatchtowerForgeView),
          );
          expect(fullView.isFullScreen, isTrue);
          expect(fullView.assemblyPhase, c.expectedPhase);
          expect(fullView.activeRigSpriteAsset, c.expectedRigAsset);
          expect(
            find.byKey(
              const ValueKey('watchtower_forge_egg_enchantment_painter'),
            ),
            c.expectEgg ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'First-visit new-week snap-in micro-animation triggers once per week (Weeks 1..9) and resets cleanly on campaign reset',
      (WidgetTester tester) async {
        final controller = await _createController(
          currentWeek: 4,
          animationsEnabled: true,
          lastSeenMetalWizardForgeWeek: 3,
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

        // First open at Week 4 consumes snap-in and animates the newly added torso part
        expect(controller.lastSeenMetalWizardForgeWeek, 4);
        expect(controller.storage.lastSeenMetalWizardForgeWeek, 4);
        await tester.pump(const Duration(milliseconds: 220));
        expect(
          find.byKey(const ValueKey('watchtower_forge_snap_in_part_image')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        // After 1150ms snap-in finishes, switches cleanly to assembled Stage 4 sprite
        await tester.pump(const Duration(milliseconds: 1100));
        expect(
          find.byKey(const ValueKey('watchtower_forge_snap_in_part_image')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('watchtower_forge_stage_4_image')),
          findsOneWidget,
        );

        // Second open at Week 4 does NOT re-trigger snap-in
        expect(controller.consumeMetalWizardForgeSnapIn(), isFalse);

        // Resetting campaign clears lastSeenMetalWizardForgeWeek
        await controller.resetAllProgress();
        expect(controller.lastSeenMetalWizardForgeWeek, -1);
        expect(controller.storage.lastSeenMetalWizardForgeWeek, -1);

        // Unmount cleanly
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Reaching Week 10 triggers the one-time localized Robot Archmage awakening notice with Inspect Watch Tower quick action',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          language: 'en',
          currentWeek: 9,
          enemyStage: 1,
          animationsEnabled: false,
        );
        addTearDown(controller.dispose);

        // Verify en, pt, es, de localizations for awakening quote & Inspect Watch Tower button
        final loc = controller.localization;
        for (final lang in ['en', 'pt', 'es', 'de']) {
          loc.setLanguage(lang);
          expect(
            loc.t('week10_archmage_awakening_quote', fallback: '__MISSING__'),
            isNot('__MISSING__'),
          );
          expect(
            loc.t(
              'week10_archmage_inspect_watchtower_btn',
              fallback: '__MISSING__',
            ),
            isNot('__MISSING__'),
          );
        }
        loc.setLanguage('pt');
        expect(
          loc.t('week10_archmage_awakening_quote'),
          contains('forja subterrânea cessaram'),
        );
        loc.setLanguage('en');

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Week 9: Awakening notice not shown yet
        expect(
          find.byKey(const ValueKey('week10_archmage_warning_dialog')),
          findsNothing,
        );

        // Advance Week 9 -> Week 10
        controller.completeBattleWeek();
        await tester.pumpAndSettle();

        expect(controller.currentWeek, 10);
        expect(
          find.byKey(const ValueKey('week10_archmage_warning_dialog')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('week10_archmage_awakening_quote')),
          findsOneWidget,
        );
        expect(
          find.textContaining('hammering in the underground forge has stopped'),
          findsOneWidget,
        );

        // Tap "Inspect Watch Tower" quick action -> closes alert & opens Watch Tower
        final inspectBtn = find.byKey(
          const ValueKey('week10_archmage_inspect_watchtower_button'),
        );
        expect(inspectBtn, findsOneWidget);
        await tester.tap(inspectBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('week10_archmage_warning_dialog')),
          findsNothing,
        );
        expect(find.byType(ObservatoryDialog), findsOneWidget);
        expect(controller.hasShownWeek10ArchmageWarning, isTrue);
        expect(controller.storage.hasShownWeek10ArchmageWarning, isTrue);

        // Close Watch Tower and advance to Week 11 -> alert does NOT re-trigger
        await tester.tap(
          find.byKey(const ValueKey('observatory_close_button')),
        );
        await tester.pumpAndSettle();

        controller.completeBattleWeek();
        await tester.pumpAndSettle();
        expect(controller.currentWeek, 11);
        expect(
          find.byKey(const ValueKey('week10_archmage_warning_dialog')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Metal Wizard sprite remains completely stationary across animated frames in both circular spyglass modal and full-screen view',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          currentWeek: 6,
          animationsEnabled: true,
          lastSeenMetalWizardForgeWeek: 5,
        );
        addTearDown(controller.dispose);

        final wizardFinder = find.byKey(
          const ValueKey('watchtower_forge_metal_wizard_image'),
        );

        // 1. Circular MetalWizardSpyglassDialog with animationsEnabled: true (including snap-in window)
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: MetalWizardSpyglassDialog(controller: controller),
            ),
          ),
        );
        await tester.pump();
        expect(wizardFinder, findsOneWidget);
        expect(
          find.byKey(const ValueKey('watchtower_forge_vfx_paint')),
          findsOneWidget,
        );

        final initialModalRect = tester.getRect(wizardFinder);
        for (final step in const [
          Duration(milliseconds: 250),
          Duration(milliseconds: 500),
          Duration(milliseconds: 700),
          Duration(milliseconds: 1200),
          Duration(milliseconds: 1500),
          Duration(milliseconds: 2000),
        ]) {
          await tester.pump(step);
          final currentRect = tester.getRect(wizardFinder);
          expect(currentRect.top, closeTo(initialModalRect.top, 1e-6));
          expect(currentRect.bottom, closeTo(initialModalRect.bottom, 1e-6));
          expect(currentRect.left, closeTo(initialModalRect.left, 1e-6));
          expect(currentRect.right, closeTo(initialModalRect.right, 1e-6));
        }

        // 2. FullScreenSpyglassView with animationsEnabled: true
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: FullScreenSpyglassView(
              controller: controller,
              target: SpyglassTarget.metalWizard,
            ),
          ),
        );
        await tester.pump();
        expect(wizardFinder, findsOneWidget);
        expect(
          find.byKey(const ValueKey('watchtower_forge_vfx_paint')),
          findsOneWidget,
        );

        final initialFullRect = tester.getRect(wizardFinder);
        for (final step in const [
          Duration(milliseconds: 300),
          Duration(milliseconds: 800),
          Duration(milliseconds: 1600),
          Duration(milliseconds: 2500),
        ]) {
          await tester.pump(step);
          final currentRect = tester.getRect(wizardFinder);
          expect(currentRect.top, closeTo(initialFullRect.top, 1e-6));
          expect(currentRect.bottom, closeTo(initialFullRect.bottom, 1e-6));
          expect(currentRect.left, closeTo(initialFullRect.left, 1e-6));
          expect(currentRect.right, closeTo(initialFullRect.right, 1e-6));
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Week 0 renders Titanium Robot Egg enchantment with localized captions (en, pt, es, de) and transitions cleanly to Weeks 1-9 Archmage assembly and Weeks 10-39 overcharged egg',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const expectedWeek0Captions = {
          'en':
              'Deep beneath his lair, the Metal Wizard channels forbidden crimson energy into a mysterious titanium egg—forging a terrifying contingency before he even begins assembling his Archmage...',
          'pt':
              'Nas profundezas de seu covil, o Mago de Metal canaliza energia carmesim proibida em um misterioso ovo de titânio — forjando uma contingência aterrorizante antes mesmo de começar a montar seu Arquimago...',
          'es':
              'En lo profundo de su guarida, el Mago de Metal canaliza energía carmesí prohibida en un misterioso huevo de titanio, forjando una contingencia aterradora antes siquiera de ensamblar su Archimago...',
          'de':
              'Tief in seinem Versteck leitet der Metallmagier verbotene karmesinrote Energie in ein geheimnisvolles Titan-Ei – eine schreckliche Geheimwaffe, noch bevor er mit dem Bau seines Erzmagiers beginnt...',
        };

        for (final entry in expectedWeek0Captions.entries) {
          final controller = await _createController(
            language: entry.key,
            currentWeek: 0,
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

          expect(find.text(entry.value), findsOneWidget);
          expect(
            find.byKey(const ValueKey('watchtower_forge_egg_image')),
            findsOneWidget,
          );
          expect(
            find.byKey(
              const ValueKey('watchtower_forge_egg_enchantment_painter'),
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('watchtower_forge_blueprint_hologram')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('watchtower_forge_parts_pile_image')),
            findsNothing,
          );
        }

        // Dynamic live transition: Week 0 (Egg) -> Week 1..9 (Archmage) -> Week 10 (Overcharged Egg)
        final liveController = await _createController(
          language: 'en',
          currentWeek: 0,
          animationsEnabled: false,
        );
        addTearDown(liveController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: MetalWizardSpyglassDialog(controller: liveController),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(expectedWeek0Captions['en']!), findsOneWidget);
        expect(
          find.byKey(const ValueKey('watchtower_forge_egg_image')),
          findsOneWidget,
        );

        // Advance Week 0 -> Week 1: transitions cleanly to Robot Archmage assembly & early caption
        liveController.currentWeek = 1;
        liveController.notifyListeners();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('watchtower_forge_egg_image')),
          findsNothing,
        );
        expect(
          find.byKey(
            const ValueKey('watchtower_forge_egg_enchantment_painter'),
          ),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('watchtower_forge_stage_1_image')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('watchtower_forge_blueprint_hologram')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('watchtower_forge_parts_pile_image')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Robot Archmage before Week 10'),
          findsOneWidget,
        );

        // Advance to Week 9: powered Archmage on rig
        liveController.currentWeek = 9;
        liveController.notifyListeners();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('watchtower_forge_archmage_powered_vfx')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('watchtower_forge_egg_image')),
          findsNothing,
        );

        // Advance to Week 10: Titanium Robot Egg returns in Overcharged / Awakening state
        liveController.currentWeek = 10;
        liveController.notifyListeners();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('watchtower_forge_egg_image')),
          findsOneWidget,
        );
        final eggPaint = tester.widget<CustomPaint>(
          find.byKey(
            const ValueKey('watchtower_forge_egg_enchantment_painter'),
          ),
        );
        expect(
          (eggPaint.painter as EggEnchantmentPainter).isOvercharged,
          isTrue,
        );
        expect(
          find.textContaining('Baby Mage Robot prototype'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Tapping the Titanium Robot Egg triggers Tap-to-Resonate shockwave & visor flare while keeping Metal Wizard stationary and lens tap opening full screen',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          currentWeek: 0,
          animationsEnabled: true,
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
        await tester.pump();

        final wizardFinder = find.byKey(
          const ValueKey('watchtower_forge_metal_wizard_image'),
        );
        final eggTapFinder = find.byKey(
          const ValueKey('watchtower_forge_egg_tap_target'),
        );
        final eggPainterFinder = find.byKey(
          const ValueKey('watchtower_forge_egg_enchantment_painter'),
        );

        expect(wizardFinder, findsOneWidget);
        expect(eggTapFinder, findsOneWidget);
        expect(eggPainterFinder, findsOneWidget);

        final initialWizardRect = tester.getRect(wizardFinder);

        EggEnchantmentPainter readPainter() =>
            tester.widget<CustomPaint>(eggPainterFinder).painter
                as EggEnchantmentPainter;

        // Idle resonance before tapping
        expect(readPainter().resonanceProgress, 0.0);
        expect(readPainter().isOvercharged, isFalse);

        // Tap directly on the Titanium Robot Egg -> triggers ~450ms shockwave & visor flare
        await tester.tap(eggTapFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(readPainter().resonanceProgress, greaterThan(0.05));
        expect(readPainter().resonanceProgress, lessThan(0.95));
        // Still inside modal (did not navigate away when tapping egg directly)
        expect(find.byType(FullScreenSpyglassView), findsNothing);

        // Metal Wizard stays 100% static throughout animation & resonance burst
        for (final step in const [
          Duration(milliseconds: 150),
          Duration(milliseconds: 250),
          Duration(milliseconds: 600),
        ]) {
          await tester.pump(step);
          final currentRect = tester.getRect(wizardFinder);
          expect(currentRect.top, closeTo(initialWizardRect.top, 1e-6));
          expect(currentRect.bottom, closeTo(initialWizardRect.bottom, 1e-6));
          expect(currentRect.left, closeTo(initialWizardRect.left, 1e-6));
          expect(currentRect.right, closeTo(initialWizardRect.right, 1e-6));
        }

        // Resonance finishes cleanly after 450ms
        expect(readPainter().resonanceProgress, 0.0);

        // Tapping the circular spyglass lens center opens FullScreenSpyglassView
        await tester.tap(
          find.byKey(const ValueKey('metal_wizard_spyglass_lens_tap')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(FullScreenSpyglassView), findsOneWidget);

        // Tapping the egg in full-screen view also triggers resonance cleanly
        // (waits past double-tap disambiguation timeout from outer zoom detector)
        final fullEggTapFinder = find.byKey(
          const ValueKey('watchtower_forge_egg_tap_target'),
        );
        final fullEggPainterFinder = find.byKey(
          const ValueKey('watchtower_forge_egg_enchantment_painter'),
        );
        expect(fullEggTapFinder, findsOneWidget);
        await tester.tap(fullEggTapFinder);
        await tester.pump(const Duration(milliseconds: 320));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 140));
        final fullPainter = tester
            .widget<CustomPaint>(fullEggPainterFinder)
            .painter as EggEnchantmentPainter;
        expect(fullPainter.resonanceProgress, greaterThan(0.05));
        expect(fullPainter.resonanceProgress, lessThan(0.95));

        // Switch to Week 10 (Overcharged) -> egg tremors while Metal Wizard stays stationary
        controller.currentWeek = 10;
        controller.notifyListeners();
        await tester.pump();
        final fullWizardRect = tester.getRect(wizardFinder);
        for (final step in const [
          Duration(milliseconds: 180),
          Duration(milliseconds: 420),
          Duration(milliseconds: 700),
        ]) {
          await tester.pump(step);
          final r = tester.getRect(wizardFinder);
          expect(r.top, closeTo(fullWizardRect.top, 1e-6));
          expect(r.bottom, closeTo(fullWizardRect.bottom, 1e-6));
          expect(r.left, closeTo(fullWizardRect.left, 1e-6));
          expect(r.right, closeTo(fullWizardRect.right, 1e-6));
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Titanium Robot Egg is scaled down to match Metal Wizard head height and uses Back (π..2π) -> Pedestal -> Egg -> Front (0..π) Z-order layering in both circular and full-screen views',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        for (final week in [0, 10]) {
          final controller = await _createController(
            currentWeek: week,
            enemyStage: week >= 10 ? 2 : 1,
            animationsEnabled: false,
          );
          addTearDown(controller.dispose);

          for (final isFullScreen in [false, true]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData.dark(),
                home: isFullScreen
                    ? FullScreenSpyglassView(
                        controller: controller,
                        target: SpyglassTarget.metalWizard,
                      )
                    : Scaffold(
                        body: MetalWizardSpyglassDialog(controller: controller),
                      ),
              ),
            );
            await tester.pumpAndSettle();

            final wizardRect = tester.getRect(
              find.byKey(const ValueKey('watchtower_forge_metal_wizard_image')),
            );
            final eggRect = tester.getRect(
              find.byKey(const ValueKey('watchtower_forge_egg_image')),
            );

            // Egg box height is ~27.8% of wizard box height -> visible egg height (~88.9% of box)
            // is ~24% of wizard height, matching the Metal Wizard's hooded head height
            final heightRatio = eggRect.height / wizardRect.height;
            expect(heightRatio, inInclusiveRange(0.24, 0.30));

            // Verify both Back (π..2π) and Front (0..π) EggEnchantmentPainter layers exist
            final backPaint = tester.widget<CustomPaint>(
              find.byKey(
                const ValueKey('watchtower_forge_egg_enchantment_back_painter'),
              ),
            );
            final frontPaint = tester.widget<CustomPaint>(
              find.byKey(
                const ValueKey('watchtower_forge_egg_enchantment_painter'),
              ),
            );
            final backPainter = backPaint.painter as EggEnchantmentPainter;
            final frontPainter = frontPaint.painter as EggEnchantmentPainter;
            expect(backPainter.layer, EggEnchantmentLayer.back);
            expect(frontPainter.layer, EggEnchantmentLayer.front);

            // Rotating elliptical rune ring center sits strictly below the egg's lower rim
            // so the front (0..π) arc wraps in front of the pedestal base without crossing the egg
            expect(
              frontPainter.pedestalCenter.dy,
              greaterThan(frontPainter.eggRect.bottom),
            );

            // Verify exact Stack child Z-order: Back Layer < Pedestal < Egg Sprite < Front Layer
            final stack = tester.widget<Stack>(
              find.byKey(const ValueKey('watchtower_forge_view_stack')),
            );
            int indexOfKey(String keyName) {
              return stack.children.indexWhere((child) {
                bool matches(Widget w) {
                  if (w.key == ValueKey(keyName)) return true;
                  if (w is SingleChildRenderObjectWidget && w.child != null) {
                    return matches(w.child!);
                  }
                  if (w is ProxyWidget) return matches(w.child);
                  return false;
                }

                return matches(child);
              });
            }

            final backIdx =
                indexOfKey('watchtower_forge_egg_enchantment_back_painter');
            final pedestalIdx = indexOfKey('watchtower_forge_rig_backdrop');
            final eggIdx = indexOfKey('watchtower_forge_egg_image');
            final frontIdx =
                indexOfKey('watchtower_forge_egg_enchantment_painter');

            expect(backIdx, greaterThan(0));
            expect(pedestalIdx, greaterThan(backIdx));
            expect(eggIdx, greaterThan(pedestalIdx));
            expect(frontIdx, greaterThan(eggIdx));
            expect(tester.takeException(), isNull);
          }
        }
      },
    );
  });
}
