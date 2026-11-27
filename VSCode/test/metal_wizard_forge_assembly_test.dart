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
      'All 22 generated watchtower bare-metal chassis, stage, part, and workbench pile assets are bundled and loadable',
      () async {
        final expectedAssets = <String>[
          WatchtowerForgeView.nakedFrameAsset,
          ...WatchtowerForgeView.stageAssets,
          ...WatchtowerForgeView.partAssets,
          for (int w = 0; w <= 6; w++)
            WatchtowerForgeView.pileAssetForWeek(w)!,
        ];
        expect(expectedAssets.length, 22);

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
      'Metal Wizard spyglass renders distinct progressive assembly stages across Week 0, 1, 4, 7, 8 (eye off), 9 (eye on), 10+ (Baby Robot), and 40+ (cooling) in both circular and full-screen views',
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
          bool expectBabyRobot,
          bool expectCooling,
        })>[
          (
            week: 0,
            enemyStage: 1,
            expectedPhase: ForgeAssemblyPhase.week0EmptyRig,
            expectedRigAsset: null,
            expectedPileAsset:
                'assets/images/watchtower/archmage_pile_week_0.png',
            expectBlueprint: true,
            expectDormantMask: false,
            expectPoweredVfx: false,
            expectBabyRobot: false,
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
            expectBabyRobot: false,
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
            expectBabyRobot: false,
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
            expectBabyRobot: false,
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
            expectBabyRobot: false,
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
            expectBabyRobot: false,
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
            expectBabyRobot: false,
            expectCooling: false,
          ),
          (
            week: 10,
            enemyStage: 2,
            expectedPhase: ForgeAssemblyPhase.babyRobotForging,
            expectedRigAsset: WatchtowerForgeView.babyRobotMageAsset,
            expectedPileAsset: null,
            expectBlueprint: false,
            expectDormantMask: false,
            expectPoweredVfx: false,
            expectBabyRobot: true,
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
            expectBabyRobot: false,
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
            find.byKey(const ValueKey('watchtower_forge_baby_robot_image')),
            c.expectBabyRobot ? findsOneWidget : findsNothing,
          );
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
  });
}
