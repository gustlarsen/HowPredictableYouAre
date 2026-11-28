import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/inventory_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/widgets/battle_orb_loot_bar.dart';
import 'package:how_predictable/views/widgets/elemental_energy_sphere.dart';
import 'package:how_predictable/views/widgets/elemental_symbol_icon.dart';
import 'package:how_predictable/views/widgets/hints_bar.dart';
import 'package:how_predictable/views/widgets/markov_matrix_view.dart';
import 'package:how_predictable/views/widgets/score_header.dart';
import 'package:how_predictable/views/widgets/versus_arena.dart';

class _StubBannerAdClient implements AdMobClient {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isPrivacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptionsForm({
    OnConsentFormDismissedListener? onDismissed,
  }) async {
    onDismissed?.call(null);
  }

  @override
  Future<void> loadBanner({
    required String adUnitId,
    required AdSize size,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    onLoaded();
  }

  @override
  Widget? buildBannerWidget() => const SizedBox(width: 320, height: 50);

  @override
  void disposeBanner() {}

  @override
  Future<void> loadRewarded({
    required String adUnitId,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {}

  @override
  Future<bool> showRewarded({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onDismissed,
    required VoidCallback onFailedToShow,
  }) async => false;

  @override
  void disposeRewarded() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameController> createController({
    Map<String, Object> prefs = const {},
    bool withBanner = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'animationsEnabled': false,
      'musicEnabled': false,
      'unlockedPredictability': true,
      'showPredictability': true,
      'unlockedReset': true,
      'showReset': true,
      ...prefs,
    });
    final storage = StorageService();
    await storage.init();
    AdService? adService;
    if (withBanner) {
      adService = AdService(client: _StubBannerAdClient());
      await adService.initialize();
    }
    return GameController(
      storage: storage,
      localization: LocalizationService(),
      audio: AudioService(),
      adService: adService,
    );
  }

  Widget wrapGameScreen(GameController controller, {bool isDark = true}) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        theme: isDark
            ? ThemeData.dark(useMaterial3: true)
            : ThemeData.light(useMaterial3: true),
        home: const GameScreen(),
      ),
    );
  }

  group('Current-Battle Orb Loot Bar Tests', () {
    testWidgets(
      'Renders directly between top HUD AppBar and ScoreHeader with 3D spheres, shows +0 at battle start despite existing permanent inventory, and adapts from 3 to 5 elements on narrow screens',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        for (final isDark in [true, false]) {
          final controller = await createController(
            prefs: {
              'darkMode': isDark,
              'orbs_fire': 42,
              'orbs_water': 18,
              'orbs_wood': 9,
              'orbs_earth': 5,
              'orbs_metal': 3,
              'unlockedNewHands': false,
              'showNewHands': false,
            },
          );
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            wrapGameScreen(controller, isDark: isDark),
          );
          await tester.pumpAndSettle();

          final topBarFinder = find.byKey(const ValueKey('battle_top_hud_bar'));
          final lootBarFinder = find.byKey(const ValueKey('battle_orb_loot_bar'));
          final scoreHeaderFinder = find.byType(ScoreHeader);

          expect(topBarFinder, findsOneWidget);
          expect(lootBarFinder, findsOneWidget);
          expect(scoreHeaderFinder, findsOneWidget);

          // Exact vertical order: Top AppBar -> BattleOrbLootBar -> ScoreHeader
          final topBarRect = tester.getRect(topBarFinder);
          final lootBarRect = tester.getRect(lootBarFinder);
          final scoreHeaderRect = tester.getRect(scoreHeaderFinder);

          expect(lootBarRect.top, greaterThanOrEqualTo(topBarRect.bottom));
          expect(lootBarRect.bottom, lessThanOrEqualTo(scoreHeaderRect.top));
          expect(lootBarRect.height, inInclusiveRange(28.0, 30.0));

          // Phase 1 (Earth & Metal locked): 3 glowing 3D spheres, no flat symbols, all +0
          expect(
            find.descendant(
              of: lootBarFinder,
              matching: find.byType(ElementalEnergySphere),
            ),
            findsNWidgets(3),
          );
          expect(
            find.descendant(
              of: lootBarFinder,
              matching: find.byType(ElementalSymbolIcon),
            ),
            findsNothing,
          );
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('battle_loot_count_fire')))
                .data,
            '+0',
          );
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('battle_loot_count_water')),
                )
                .data,
            '+0',
          );
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('battle_loot_count_wood')))
                .data,
            '+0',
          );
          expect(
            find.byKey(const ValueKey('battle_loot_slot_earth')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('battle_loot_slot_metal')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        }

        // Narrow phone screen (360px wide) with all 5 elements active: single row without overflow
        tester.view.physicalSize = const Size(360, 640);
        final narrowController = await createController(
          prefs: {
            'unlockedNewHands': true,
            'showNewHands': true,
            'orbs_fire': 100,
            'orbs_earth': 50,
            'orbs_metal': 25,
          },
        );
        addTearDown(narrowController.dispose);

        await tester.pumpWidget(wrapGameScreen(narrowController));
        await tester.pumpAndSettle();

        final lootBarFinder = find.byKey(const ValueKey('battle_orb_loot_bar'));
        expect(
          find.descendant(
            of: lootBarFinder,
            matching: find.byType(ElementalEnergySphere),
          ),
          findsNWidgets(5),
        );
        // All 5 slots sit on the same horizontal row
        final fireY =
            tester.getCenter(find.byKey(const ValueKey('battle_loot_slot_fire'))).dy;
        final metalY = tester
            .getCenter(find.byKey(const ValueKey('battle_loot_slot_metal')))
            .dy;
        expect(fireY, closeTo(metalY, 1.0));
        expect(tester.takeException(), isNull);

        // Standalone BattleOrbLootBar at ultra-narrow 220px width with +100 values scales cleanly via FittedBox
        narrowController.fireOrbs += 100;
        narrowController.waterOrbs += 100;
        narrowController.woodOrbs += 100;
        narrowController.earthOrbs += 100;
        narrowController.metalOrbs += 100;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 220,
                  child: BattleOrbLootBar(controller: narrowController),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('+100'), findsNWidgets(5));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Increments +N live on round wins and Gift Box / passive gains, resets to +0 on Turn 0 Reset and New Battle, and opens InventoryDialog on tap',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await createController(
          prefs: {
            'orbs_fire': 20,
            'orbs_water': 15,
            'orbs_wood': 10,
            'giftBoxUnlocked': true,
            'giftBoxEnabled': true,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(wrapGameScreen(controller));
        await tester.pumpAndSettle();

        // Starts at +0 despite existing permanent inventory (20 / 15 / 10)
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('battle_loot_count_fire')))
              .data,
          '+0',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('battle_loot_count_wood')))
              .data,
          '+0',
        );

        // Win round 1: Fire beats Wood -> +1 Wood
        controller.crystalBallMove = HandMove.scissors;
        await tester.tap(find.byKey(const ValueKey('hand_button_rock')));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('battle_loot_count_wood')))
              .data,
          '+1',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('battle_loot_count_fire')))
              .data,
          '+0',
        );

        // Win round 2 & 3: Water beats Fire -> +2 Fire
        controller.crystalBallMove = HandMove.rock;
        await tester.tap(find.byKey(const ValueKey('hand_button_paper')));
        await tester.pumpAndSettle();
        controller.crystalBallMove = HandMove.rock;
        await tester.tap(find.byKey(const ValueKey('hand_button_paper')));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('battle_loot_count_fire')))
              .data,
          '+2',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('battle_loot_count_wood')))
              .data,
          '+1',
        );

        // Tapping the loot bar opens InventoryDialog showing permanent totals (22 Fire, 15 Water, 11 Wood)
        await tester.tap(find.byKey(const ValueKey('battle_orb_loot_bar')));
        await tester.pumpAndSettle();
        expect(find.byType(InventoryDialog), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('inventory_orb_count_fire')))
              .data,
          '22',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('inventory_orb_count_wood')))
              .data,
          '11',
        );
        await tester.tap(find.byKey(const ValueKey('inventory_close_button')));
        await tester.pumpAndSettle();
        expect(find.byType(InventoryDialog), findsNothing);

        // Passive / Gift Box orb gain updates live (+5 each -> Fire +7, Water +5, Wood +6)
        controller.claimGift();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('battle_loot_count_fire')))
              .data,
          '+7',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('battle_loot_count_water')))
              .data,
          '+5',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('battle_loot_count_wood')))
              .data,
          '+6',
        );

        // Trigger Turn 0 Reset via AppBar Reset button -> all battle loot counters revert to +0
        await tester.tap(find.byKey(const ValueKey('battle_reset_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'RESET'));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('battle_loot_count_fire')))
              .data,
          '+0',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('battle_loot_count_water')))
              .data,
          '+0',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('battle_loot_count_wood')))
              .data,
          '+0',
        );

        // Earn an orb then start a fresh battle -> counters reset to +0
        controller.crystalBallMove = HandMove.scissors;
        controller.playTurn(HandMove.rock);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('battle_loot_count_wood')))
              .data,
          '+1',
        );

        controller.startNewBattle();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('battle_loot_count_wood')))
              .data,
          '+0',
        );
      },
    );

    testWidgets(
      'Synchronizes 1.0 -> 1.18 -> 1.0 scale pulse on collected elemental slot when parabolic flying orb lands in top-left backpack',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await createController(
          prefs: {
            'animationsEnabled': true,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(wrapGameScreen(controller));
        await tester.pump();

        // Win round defeating Wood -> launches parabolic flying Wood orb to backpack
        controller.crystalBallMove = HandMove.scissors;
        await tester.tap(find.byKey(const ValueKey('hand_button_rock')));
        await tester.pump();

        // Mid-flight: flying orb overlay is visible and Wood slot has not pulsed yet (scale == 1.0)
        await tester.pump(
          const Duration(milliseconds: GameScreen.orbSpawnDelayMs + 250),
        );
        expect(
          find.byKey(const ValueKey('flying_orb_vfx_overlay')),
          findsOneWidget,
        );
        final midFlightWoodTransform = tester.widget<Transform>(
          find.byKey(const ValueKey('battle_loot_slot_wood')),
        );
        expect(midFlightWoodTransform.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.01));

        // Peak of collection pulse upon backpack arrival: Wood slot scales to ~1.18, Fire stays 1.0
        const pulsePeakMs = GameScreen.orbSpawnDelayMs +
            GameScreen.orbFlightDurationMs +
            (GameScreen.backpackPulseDurationMs ~/ 2);
        await tester.pump(
          const Duration(
            milliseconds: pulsePeakMs - (GameScreen.orbSpawnDelayMs + 250),
          ),
        );

        final peakWoodTransform = tester.widget<Transform>(
          find.byKey(const ValueKey('battle_loot_slot_wood')),
        );
        final peakFireTransform = tester.widget<Transform>(
          find.byKey(const ValueKey('battle_loot_slot_fire')),
        );
        expect(
          peakWoodTransform.transform.getMaxScaleOnAxis(),
          closeTo(BattleOrbLootBar.pulsePeakScale, 0.03),
        );
        expect(
          peakFireTransform.transform.getMaxScaleOnAxis(),
          closeTo(1.0, 0.01),
        );

        // After sequence finishes, Wood slot returns cleanly to 1.0
        await tester.pump(
          const Duration(milliseconds: GameScreen.backpackPulseDurationMs + 100),
        );
        final settledWoodTransform = tester.widget<Transform>(
          find.byKey(const ValueKey('battle_loot_slot_wood')),
        );
        expect(
          settledWoodTransform.transform.getMaxScaleOnAxis(),
          closeTo(1.0, 0.01),
        );
      },
    );

    testWidgets(
      'Constrains expanded 5-element MarkovMatrixView inside its card so it never overlaps Cleric or Guardian Robot heads when all HUD items are active',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await createController(
          withBanner: true,
          prefs: {
            'unlockedPredictability': true,
            'showPredictability': true,
            'unlockedYourPrediction': true,
            'showYourPrediction': true,
            'unlockedNextMove': true,
            'showNextMove': true,
            'unlockedSuggestion': true,
            'showSuggestion': true,
            'unlockedCrystalBall': true,
            'showCrystalBall': true,
            'unlockedAlgorithm': true,
            'showAlgorithm': true,
            'unlockedNewHands': true,
            'showNewHands': true,
            'unlockedRandom': true,
            'showRandom': true,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(wrapGameScreen(controller));
        await tester.pumpAndSettle();

        expect(find.byType(BattleOrbLootBar), findsOneWidget);
        expect(find.byType(ScoreHeader), findsOneWidget);
        expect(find.byType(HintsBar), findsOneWidget);
        expect(find.byType(MarkovMatrixView), findsOneWidget);
        expect(find.byType(VersusArena), findsOneWidget);
        expect(
          find.byKey(const ValueKey('markov_matrix_body_scroll_view')),
          findsOneWidget,
        );

        final matrixRect = tester.getRect(find.byType(MarkovMatrixView));
        final upperScrollRect =
            tester.getRect(find.byKey(const ValueKey('game_upper_scroll_view')));
        final playerSpriteRect =
            tester.getRect(find.byKey(const ValueKey('versus_player_sprite')));
        final bossSpriteRect = tester.getRect(
          find.byKey(const ValueKey('versus_boss_sprite_stage_1')),
        );

        // Neither the upper HUD viewport nor MarkovMatrixView overlaps the Cleric or Guardian Robot heads
        expect(upperScrollRect.bottom, lessThanOrEqualTo(playerSpriteRect.top));
        expect(upperScrollRect.bottom, lessThanOrEqualTo(bossSpriteRect.top));
        expect(matrixRect.bottom, lessThanOrEqualTo(playerSpriteRect.top));
        expect(matrixRect.bottom, lessThanOrEqualTo(bossSpriteRect.top));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
