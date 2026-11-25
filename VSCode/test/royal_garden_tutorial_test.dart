import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/controllers/royal_garden_tutorial_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/models/royal_castle.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/settings_dialog.dart';
import 'package:how_predictable/views/screens/intro_story_screen.dart';
import 'package:how_predictable/views/screens/world_map_screen.dart';
import 'package:how_predictable/views/widgets/royal_garden_tutorial_battle.dart';
import 'package:how_predictable/views/widgets/rpg_teleport_portal_icon.dart';

class _FakePlayGamesClient implements PlayGamesClient {
  String? savedPayload;
  int saveCount = 0;

  @override
  Future<String?> signIn() async => 'signed_in';

  @override
  Future<String?> getPlayerName() async => 'GardenTester';

  @override
  Future<String?> getPlayerID() async => 'garden_tester_1';

  @override
  Future<String?> saveGame({required String data, required String name}) async {
    savedPayload = data;
    saveCount++;
    return 'saved';
  }

  @override
  Future<String?> loadGame({required String name}) async => savedPayload;
}

Future<({
  StorageService storage,
  LocalizationService localization,
  GameController controller,
  _FakePlayGamesClient playGamesClient,
})> _createHarness({
  Map<String, Object> prefs = const {},
  bool signInPlayGames = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'musicEnabled': false,
    'soundEnabled': false,
    'animationsEnabled': false,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();

  final localization = LocalizationService();
  await localization.load();
  localization.setLanguage(storage.language);

  final playGamesClient = _FakePlayGamesClient();
  final playGames = PlayGamesService(storage: storage, client: playGamesClient);
  if (signInPlayGames) {
    await playGames.signIn();
  }

  final controller = GameController(
    storage: storage,
    localization: localization,
    audio: AudioService(),
    playGames: playGames,
  );

  return (
    storage: storage,
    localization: localization,
    controller: controller,
    playGamesClient: playGamesClient,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Royal Garden Prologue Visual Assets & 4-Language Localization', () {
    test('Royal Garden background and all 3 mage PNG assets exist on disk and are non-empty PNGs', () {
      const assets = [
        'assets/images/royal_garden_arena_bg.png',
        'assets/images/enemies/mage_fire_idle.png',
        'assets/images/enemies/mage_water_idle.png',
        'assets/images/enemies/mage_wood_idle.png',
      ];
      for (final path in assets) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'Missing $path');
        final bytes = file.readAsBytesSync();
        expect(bytes.length, greaterThan(10000), reason: '$path too small');
        // PNG magic header: 89 50 4E 47
        expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      }
    });

    test('All tutorial strings, Skip, Replay, Prologue #1, and Guardian Robot Bestiary lore localize cleanly in en, pt, es, de', () async {
      final loc = LocalizationService();
      await loc.load();

      const keys = [
        'story_skip',
        'story_replay_intro',
        'story_intro_summary',
        'castle_bestiary_guardian_lore',
        'tutorial_arena_title',
        'tutorial_act1_badge',
        'tutorial_act2_badge',
        'tutorial_tip_fire_beats_wood',
        'tutorial_tip_water_beats_fire',
        'tutorial_tip_wood_beats_water',
        'tutorial_robot_preparing',
        'tutorial_markov_online',
        'tutorial_mage_knocked_out',
        'tutorial_mage_ko_badge',
        'tutorial_mage_fire_name',
        'tutorial_mage_water_name',
        'tutorial_mage_wood_name',
        'tutorial_overdrive_strike',
        'tutorial_mages_fallen',
      ];

      for (final lang in ['en', 'pt', 'es', 'de']) {
        loc.setLanguage(lang);
        for (final key in keys) {
          final value = loc.t(key);
          expect(value, isNot(key), reason: 'Missing ${lang}_$key');
          expect(value.trim(), isNotEmpty, reason: 'Empty ${lang}_$key');
        }
        // Guardian Robot Bestiary lore must reference the Royal Garden / 3 mages
        final lore = loc.t(BestiaryCreature.guardianRobot.loreKey).toLowerCase();
        expect(
          lore.contains('garden') ||
              lore.contains('jardim') ||
              lore.contains('jardín') ||
              lore.contains('garten'),
          isTrue,
          reason: '$lang Guardian Robot lore should mention the Royal Garden',
        );
      }
    });
  });

  group('RoyalGardenTutorialController Unit Tests', () {
    test('Starts with 3 mages (5 HP / 100 Mana each) and Guardian Robot (100 HP)', () {
      final tutorial = RoyalGardenTutorialController(random: math.Random(42));
      expect(tutorial.robotHp, 100);
      expect(tutorial.robotMaxHp, 100);
      expect(tutorial.mages.length, 3);
      for (final mage in tutorial.mages) {
        expect(mage.hp, 5);
        expect(mage.maxHp, 5);
        expect(mage.mana, 100);
        expect(mage.maxMana, 100);
        expect(mage.isKnockedOut, isFalse);
      }
    });

    test('Act 1 guides Turns 1-3 (Fire -> Water -> Wood), blocks non-highlighted moves, and awards 1 Fire, 1 Water, 1 Wood orb', () {
      final tutorial = RoyalGardenTutorialController(random: math.Random(42));

      // Turn 1: Robot prepares Wood -> only Fire enabled
      expect(tutorial.isAct1, isTrue);
      expect(tutorial.act1TelegraphedRobotMove, HandMove.wood);
      expect(tutorial.act1RequiredPlayerMove, HandMove.fire);
      expect(tutorial.isElementButtonHighlighted(HandMove.fire), isTrue);
      expect(tutorial.isElementButtonDimmedForGuide(HandMove.water), isTrue);
      expect(tutorial.isElementButtonDimmedForGuide(HandMove.wood), isTrue);
      expect(tutorial.playTurn(HandMove.water), isFalse);
      expect(tutorial.playTurn(HandMove.wood), isFalse);

      expect(tutorial.playTurn(HandMove.fire), isTrue);
      expect(tutorial.robotHp, 99);
      expect(tutorial.mageFor(HandMove.fire).mana, 99);
      expect(tutorial.collectedWoodOrbs, 1);
      expect(tutorial.collectedFireOrbs, 0);
      expect(tutorial.collectedWaterOrbs, 0);

      // Turn 2: Robot prepares Fire -> only Water enabled
      expect(tutorial.act1TelegraphedRobotMove, HandMove.fire);
      expect(tutorial.act1RequiredPlayerMove, HandMove.water);
      expect(tutorial.playTurn(HandMove.fire), isFalse);
      expect(tutorial.playTurn(HandMove.water), isTrue);
      expect(tutorial.robotHp, 98);
      expect(tutorial.mageFor(HandMove.water).mana, 99);
      expect(tutorial.collectedFireOrbs, 1);
      expect(tutorial.collectedWoodOrbs, 1);

      // Turn 3: Robot prepares Water -> only Wood enabled
      expect(tutorial.act1TelegraphedRobotMove, HandMove.water);
      expect(tutorial.act1RequiredPlayerMove, HandMove.wood);
      expect(tutorial.playTurn(HandMove.wood), isTrue);
      expect(tutorial.robotHp, 97);
      expect(tutorial.mageFor(HandMove.wood).mana, 99);
      expect(tutorial.collectedWaterOrbs, 1);
      expect(tutorial.collectedFireOrbs, 1);
      expect(tutorial.collectedWoodOrbs, 1);
      expect(tutorial.totalCollectedOrbs, 3);

      // Turn 4 enters Act 2: Markov Matrix online and all 3 buttons unlocked
      expect(tutorial.isAct1, isFalse);
      expect(tutorial.isAct2, isTrue);
      expect(tutorial.justEnteredAct2, isTrue);
      expect(tutorial.isElementButtonEnabled(HandMove.fire), isTrue);
      expect(tutorial.isElementButtonEnabled(HandMove.water), isTrue);
      expect(tutorial.isElementButtonEnabled(HandMove.wood), isTrue);
    });

    test('Act 2 uses cumulative 3-element Markov Matrix, knocks out individual mages at 0 HP, and finishes when all 3 fall', () {
      final tutorial = RoyalGardenTutorialController(random: math.Random(7));

      // Complete Act 1
      expect(tutorial.playTurn(HandMove.fire), isTrue);
      expect(tutorial.playTurn(HandMove.water), isTrue);
      expect(tutorial.playTurn(HandMove.wood), isTrue);

      // Repeatedly cast Fire -> Markov learns Fire->Fire and counters with Water until Fire Mage hits 0 HP
      int safety = 0;
      while (!tutorial.mageFor(HandMove.fire).isKnockedOut && safety < 25) {
        tutorial.playTurn(HandMove.fire);
        safety++;
      }
      expect(tutorial.mageFor(HandMove.fire).hp, 0);
      expect(tutorial.mageFor(HandMove.fire).isKnockedOut, isTrue);
      expect(tutorial.isElementButtonEnabled(HandMove.fire), isFalse);
      expect(tutorial.isElementButtonKnockedOut(HandMove.fire), isTrue);
      expect(tutorial.playTurn(HandMove.fire), isFalse);
      expect(tutorial.isBattleFinished, isFalse);

      // Repeatedly cast Water until Water Mage hits 0 HP
      safety = 0;
      while (!tutorial.mageFor(HandMove.water).isKnockedOut && safety < 25) {
        tutorial.playTurn(HandMove.water);
        safety++;
      }
      expect(tutorial.mageFor(HandMove.water).hp, 0);
      expect(tutorial.isElementButtonKnockedOut(HandMove.water), isTrue);
      expect(tutorial.isBattleFinished, isFalse);

      // Repeatedly cast Wood until Wood Mage hits 0 HP -> battle finishes
      safety = 0;
      while (!tutorial.isBattleFinished && safety < 25) {
        tutorial.playTurn(HandMove.wood);
        safety++;
      }
      expect(tutorial.mageFor(HandMove.wood).hp, 0);
      expect(tutorial.allMagesKnockedOut, isTrue);
      expect(tutorial.isBattleFinished, isTrue);
      // Total collected orbs remains strictly 1 Fire, 1 Water, 1 Wood
      expect(tutorial.collectedFireOrbs, 1);
      expect(tutorial.collectedWaterOrbs, 1);
      expect(tutorial.collectedWoodOrbs, 1);
    });

    test('Failsafe Overdrive Strike triggers if all surviving mages run out of 100 Mana', () {
      final tutorial = RoyalGardenTutorialController(random: math.Random(1));
      tutorial.playTurn(HandMove.fire);
      tutorial.playTurn(HandMove.water);
      tutorial.playTurn(HandMove.wood);

      // Simulate surviving mages down to their final Mana point
      tutorial.mageFor(HandMove.fire).hp = 0;
      tutorial.mageFor(HandMove.water).hp = 0;
      tutorial.mageFor(HandMove.wood).hp = 5;
      tutorial.mageFor(HandMove.wood).mana = 1;

      tutorial.playTurn(HandMove.wood);

      expect(tutorial.triggeredOverdriveFailsafe, isTrue);
      expect(tutorial.isBattleFinished, isTrue);
      expect(tutorial.allMagesKnockedOut, isTrue);
    });
  });

  group('Royal Garden Prologue Tutorial Widget & Campaign Integration Tests', () {
    testWidgets(
      'First launch runs Card 1 -> Playable 3-Mage Tutorial (no Teleport, yes Skip, Act 1 tips, Act 2 Markov & grayscale KO) -> Closing Cards -> Week 0 with 3 inherited orbs',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createHarness(signInPlayGames: true);
        final controller = harness.controller;
        final storage = harness.storage;
        final fakeClient = harness.playGamesClient;
        addTearDown(controller.dispose);

        final deterministicTutorial = RoyalGardenTutorialController(
          random: math.Random(11),
        );

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: HowPredictableApp(
              home: IntroStoryScreen(
                tutorialController: deterministicTutorial,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Card 1 -> tap Next -> transitions into Playable Royal Garden Tutorial Battle
        expect(find.text('1 / 4'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();

        expect(find.byType(RoyalGardenTutorialBattle), findsOneWidget);
        expect(
          find.byKey(const ValueKey('royal_garden_arena_bg_image')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('royal_garden_atmosphere_paint')),
          findsOneWidget,
        );

        // Top bar has Skip button and NO Teleport button
        expect(find.byKey(const ValueKey('intro_skip_button')), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.byType(RpgTeleportPortalIcon), findsNothing);

        // All 3 mages start at 5/5 HP and 100/100 Mana; Guardian Robot at 100 / 100 HP
        for (final key in const ['fire', 'water', 'wood']) {
          expect(
            tester.widget<Text>(find.byKey(ValueKey('tutorial_mage_hp_$key'))).data,
            '5/5',
          );
          expect(
            tester.widget<Text>(find.byKey(ValueKey('tutorial_mage_mana_$key'))).data,
            '100/100',
          );
        }
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('tutorial_robot_hp'))).data,
          '100 / 100',
        );

        // Act 1 Turn 1: Fire burns Wood!
        expect(find.text('Fire burns Wood!'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('tutorial_move_highlight_fire')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('tutorial_move_dimmed_water')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('tutorial_move_dimmed_wood')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_fire')));
        await tester.pump();
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('tutorial_robot_hp'))).data,
          '99 / 100',
        );
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('tutorial_mage_mana_fire'))).data,
          '99/100',
        );

        // Act 1 Turn 2: Water extinguishes Fire!
        expect(find.text('Water extinguishes Fire!'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_water')));
        await tester.pump();
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('tutorial_robot_hp'))).data,
          '98 / 100',
        );

        // Act 1 Turn 3: Wood absorbs Water!
        expect(find.text('Wood absorbs Water!'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_wood')));
        await tester.pump();
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('tutorial_robot_hp'))).data,
          '97 / 100',
        );

        // Act 2 Turn 4: Markov Matrix online banner appears
        expect(
          find.text('Markov Matrix online — analyzing patterns...'),
          findsOneWidget,
        );

        // Knock out Fire Mage first and verify clean grayscale disabled button (no cracks/chains)
        while (!deterministicTutorial.mageFor(HandMove.fire).isKnockedOut) {
          await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_fire')));
          await tester.pump();
        }
        expect(
          find.byKey(const ValueKey('tutorial_mage_ko_fire')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('tutorial_move_grayscale_fire')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<InkWell>(find.byKey(const ValueKey('tutorial_move_btn_fire')))
              .onTap,
          isNull,
        );

        // Knock out Water Mage and Wood Mage
        while (!deterministicTutorial.mageFor(HandMove.water).isKnockedOut) {
          await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_water')));
          await tester.pump();
        }
        while (!deterministicTutorial.isBattleFinished) {
          await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_wood')));
          await tester.pump();
        }

        // Transitions smoothly into closing Intro slides (Card 2 -> Card 3 -> Card 4)
        await tester.pumpAndSettle();
        expect(find.byType(RoyalGardenTutorialBattle), findsNothing);
        expect(find.text('2 / 4'), findsOneWidget);
        expect(find.text('Ambush in the Royal Garden'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        expect(find.text('3 / 4'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        expect(find.text('4 / 4'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();

        // Lands on WorldMapScreen at Week 0 with 1 Fire, 1 Water, 1 Wood orb persisted locally & to Cloud Save
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(controller.currentWeek, 0);
        expect(controller.hasSeenIntro, isTrue);
        expect(controller.fireOrbs, 1);
        expect(controller.waterOrbs, 1);
        expect(controller.woodOrbs, 1);
        expect(storage.fireOrbs, 1);
        expect(storage.waterOrbs, 1);
        expect(storage.woodOrbs, 1);

        final cloud = CloudSaveData.tryParse(fakeClient.savedPayload)!;
        expect(cloud.fireOrbs, 1);
        expect(cloud.waterOrbs, 1);
        expect(cloud.woodOrbs, 1);
        expect(cloud.hasSeenStoryIntro, isTrue);
      },
    );

    testWidgets(
      'Skipping during the playable tutorial on first launch enters Week 0 with 0 tutorial bonus orbs',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createHarness();
        final controller = harness.controller;
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Advance from Card 1 into tutorial battle, play 1 turn, then tap Skip
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        expect(find.byType(RoyalGardenTutorialBattle), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_fire')));
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('intro_skip_button')));
        await tester.pumpAndSettle();

        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(controller.hasSeenIntro, isTrue);
        expect(controller.currentWeek, 0);
        expect(controller.fireOrbs, 0);
        expect(controller.waterOrbs, 0);
        expect(controller.woodOrbs, 0);
      },
    );

    testWidgets(
      'Settings Replay Intro / Tutorial launches playable prologue in isolated sandbox mode without altering campaign orbs, week, HP, or mana',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createHarness(
          prefs: {
            'has_seen_story_intro': true,
            'current_week': 7,
            'orbs_fire': 4,
            'orbs_water': 5,
            'orbs_wood': 6,
            'user_hp': 33,
          },
        );
        final controller = harness.controller;
        addTearDown(controller.dispose);

        final initialHp = controller.userHp;
        final initialMana = controller.remainingMana;

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: MaterialApp(
              home: Scaffold(
                body: SettingsDialog(controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final replayBtn = find.byKey(
          const ValueKey('settings_replay_intro_button'),
        );
        await tester.ensureVisible(replayBtn);
        await tester.pumpAndSettle();
        expect(replayBtn, findsOneWidget);
        expect(find.text('Replay Intro / Tutorial'), findsOneWidget);

        await tester.tap(replayBtn);
        await tester.pumpAndSettle();

        // Card 1 -> Tutorial Battle -> play until finish -> Cards 2-4 -> Begin Quest
        expect(find.byType(IntroStoryScreen), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();

        expect(find.byType(RoyalGardenTutorialBattle), findsOneWidget);
        expect(
          find.byKey(const ValueKey('tutorial_sandbox_badge')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_fire')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_water')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_wood')));
        await tester.pump();

        for (int i = 0; i < 60; i++) {
          if (find.byType(RoyalGardenTutorialBattle).evaluate().isEmpty) break;
          if (find.byKey(const ValueKey('tutorial_finish_continue_button')).evaluate().isNotEmpty) {
            await tester.tap(find.byKey(const ValueKey('tutorial_finish_continue_button')));
            await tester.pumpAndSettle();
            break;
          }
          for (final key in const [
            'tutorial_move_btn_fire',
            'tutorial_move_btn_water',
            'tutorial_move_btn_wood',
          ]) {
            final finder = find.byKey(ValueKey(key));
            if (finder.evaluate().isEmpty) continue;
            final inkWell = tester.widget<InkWell>(finder);
            if (inkWell.onTap != null) {
              await tester.tap(finder);
              await tester.pump();
              break;
            }
          }
        }
        await tester.pumpAndSettle();

        // Advance through closing slides 2 -> 3 -> 4 -> finish
        for (int s = 0; s < 3; s++) {
          await tester.tap(find.byKey(const ValueKey('intro_action_button')));
          await tester.pumpAndSettle();
        }

        // Back at Settings with zero mutations to campaign state
        expect(find.byType(SettingsDialog), findsOneWidget);
        expect(controller.currentWeek, 7);
        expect(controller.fireOrbs, 4);
        expect(controller.waterOrbs, 5);
        expect(controller.woodOrbs, 6);
        expect(controller.userHp, initialHp);
        expect(controller.remainingMana, initialMana);
      },
    );

    testWidgets(
      'RoyalGardenTutorialBattle renders cleanly without overflow in both Dark & Light modes across compact (360x640) and standard (390x844) viewports',
      (WidgetTester tester) async {
        for (final isDark in [true, false]) {
          for (final viewport in [
            const Size(360, 640),
            const Size(390, 844),
          ]) {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;

            final harness = await _createHarness(prefs: {'darkMode': isDark});
            final controller = harness.controller;

            await tester.pumpWidget(
              ChangeNotifierProvider.value(
                value: controller,
                child: MaterialApp(
                  theme: ThemeData.light(useMaterial3: true),
                  darkTheme: ThemeData.dark(useMaterial3: true),
                  themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                  home: RoyalGardenTutorialBattle(
                    gameController: controller,
                    onSkip: () {},
                    onBattleCompleted: ({
                      required int fireOrbs,
                      required int waterOrbs,
                      required int woodOrbs,
                    }) {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.byType(RoyalGardenTutorialBattle), findsOneWidget);
            expect(find.byType(RpgTeleportPortalIcon), findsNothing);
            expect(find.byKey(const ValueKey('intro_skip_button')), findsOneWidget);

            controller.dispose();
          }
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  });
}
