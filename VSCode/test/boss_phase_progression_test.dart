import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/models/royal_castle.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/widgets/markov_matrix_view.dart';
import 'package:how_predictable/views/widgets/rpg_hp_bar.dart';
import 'package:how_predictable/views/widgets/versus_arena.dart';

Future<GameController> _createController({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'musicEnabled': false,
    'soundEnabled': false,
    'vibrationEnabled': false,
    'animationsEnabled': false,
    'hasSeenStoryIntro': true,
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

Widget _wrapScreen(GameController controller, {Widget? child}) {
  return ChangeNotifierProvider<GameController>.value(
    value: controller,
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: child ?? const GameScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Boss Phase Progression, Immediate 0 HP Victory & Markov Recalibrator', () {
    testWidgets(
      'Immediate 0 HP victory ends battle without depleting Mana Pool and Secret Week-1 Ending triggers cutscene',
      (WidgetTester tester) async {
        final controller = await _createController(
          prefs: {
            'current_week': 1,
            'enemy_phase': 1,
            'enemy_max_hp': 100,
            'pcHp': 1,
            'total_rounds': 0,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_wrapScreen(controller));
        await tester.pumpAndSettle();

        // Force Turn 1 winning counter against Guardian Robot at 1 HP in Week 1.
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);

        expect(controller.computerHp, 0);
        expect(controller.remainingMana, 99);
        expect(controller.isBossVictoryPending, isTrue);
        expect(controller.is100RoundsAlertPending, isFalse);
        expect(
          controller.isEndingUnlocked(NarrativeEnding.secretWeek1),
          isTrue,
        );

        // Further inputs are blocked while victory is pending.
        controller.playTurn(HandMove.rock);
        expect(controller.totalRounds, 1);

        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('boss_victory_modal')), findsOneWidget);
        expect(find.text('Guardian Robot Destroyed!'), findsOneWidget);
        expect(find.text('Week 1 Lightning Victory!'), findsOneWidget);

        // Confirm modal -> opens Secret Week-1 Victory Cutscene.
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('victory_cutscene_dialog')),
          findsOneWidget,
        );
        expect(find.text('SECRET WEEK-1 VICTORY'), findsOneWidget);
        expect(find.text('A Week-One Miracle!'), findsOneWidget);

        // Advance through panels cleanly.
        await tester.tap(
          find.byKey(const ValueKey('victory_cutscene_next_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Rescued Intact'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('victory_cutscene_next_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Secret Ending Unlocked'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('victory_cutscene_finish_button')),
        );
        await tester.pumpAndSettle();

        // Cycle concludes cleanly back to Week 1 Phase 1.
        expect(controller.isBossVictoryPending, isFalse);
        expect(controller.enemyPhase, 1);
        expect(controller.enemyMaxHp, 100);
        expect(controller.currentWeek, 1);
      },
    );

    testWidgets(
      'Defeating Phase 1 in Weeks 2..9 spawns Phase 3 Baby Mage Robot (400 HP, 5 elements, pure uniform random AI)',
      (WidgetTester tester) async {
        final controller = await _createController(
          prefs: {
            'current_week': 5,
            'enemy_phase': 1,
            'enemy_max_hp': 100,
            'pcHp': 1,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_wrapScreen(controller));
        await tester.pumpAndSettle();

        controller.crystalBallMove = HandMove.scissors;
        controller.playTurn(HandMove.rock);
        expect(controller.computerHp, 0);
        expect(controller.isBossVictoryPending, isTrue);

        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('boss_victory_modal')), findsOneWidget);
        expect(
          find.text('Panicked Metal Wizard Unleashes Prototype!'),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.enemyPhase, 3);
        expect(controller.enemyMaxHp, 400);
        expect(controller.computerHp, 400);
        expect(controller.engine.enemySize, 5);
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.babyRobot),
          isTrue,
        );
        expect(find.byKey(const ValueKey('boss_phase_pill_3')), findsOneWidget);
        expect(find.text('HP 400'), findsOneWidget);

        // Verify Baby Mage Robot ignores heavy cumulative history and chooses all 5 elements roughly uniformly.
        for (int i = 0; i < 40; i++) {
          controller.engine.recordTransition(HandMove.rock, HandMove.rock);
        }
        final seenMoves = <HandMove, int>{
          for (final m in HandMove.values) m: 0,
        };
        for (int i = 0; i < 150; i++) {
          controller.userHp = controller.playerMaxHp;
          controller.totalRounds = 0;
          controller.playTurn(HandMove.rock);
          seenMoves[controller.currentComputerMove!] =
              seenMoves[controller.currentComputerMove!]! + 1;
        }
        // In pure uniform random 1/5 across 150 turns, all 5 elements appear (unlike Water-only counter).
        for (final m in HandMove.values) {
          expect(
            seenMoves[m]!,
            greaterThan(5),
            reason: 'Baby Mage Robot should pick $m randomly regardless of bias',
          );
        }
      },
    );

    testWidgets(
      'Defeating Phase 1 at Week >= 10 spawns Phase 2 Robot Archmage (200 HP), unlocks Bestiary & Shop item, then advances to Phase 3 -> Standard Victory',
      (WidgetTester tester) async {
        final controller = await _createController(
          prefs: {
            'current_week': 10,
            'enemy_phase': 1,
            'enemy_max_hp': 100,
            'pcHp': 2,
          },
        );
        addTearDown(controller.dispose);

        // Hidden before encountering Robot Archmage
        expect(controller.isMarkovRecalibratorVisibleInShop, isFalse);

        await tester.pumpWidget(_wrapScreen(controller));
        await tester.pumpAndSettle();

        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        expect(controller.computerHp, 0);
        expect(controller.isBossVictoryPending, isTrue);
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.archmageRobot),
          isTrue,
        );
        expect(controller.isMarkovRecalibratorVisibleInShop, isTrue);

        await tester.pumpAndSettle();
        expect(
          find.text('Phase 2: Robot Archmage Approaches!'),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        // Now fighting Phase 2 Robot Archmage (200 HP, 5 elements)
        expect(controller.enemyPhase, 2);
        expect(controller.enemyMaxHp, 200);
        expect(controller.computerHp, 200);
        expect(controller.engine.enemySize, 5);
        expect(find.byKey(const ValueKey('boss_phase_pill_2')), findsOneWidget);
        expect(find.text('HP 200'), findsOneWidget);

        // Defeat Phase 2 Robot Archmage -> strictly transitions to Phase 3 Baby Mage Robot (400 HP)
        controller.computerHp = 2;
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        expect(controller.computerHp, 0);
        expect(controller.isBossVictoryPending, isTrue);

        await tester.pumpAndSettle();
        expect(find.text('Robot Archmage Destroyed!'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.enemyPhase, 3);
        expect(controller.enemyMaxHp, 400);
        expect(controller.computerHp, 400);
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.babyRobot),
          isTrue,
        );

        // Defeat Phase 3 Baby Mage Robot -> unlocks Standard Victory Ending & triggers campaign cutscene
        controller.computerHp = 2;
        controller.crystalBallMove = HandMove.scissors;
        controller.playTurn(HandMove.rock);
        expect(controller.computerHp, 0);
        expect(
          controller.isEndingUnlocked(NarrativeEnding.standardVictory),
          isTrue,
        );

        await tester.pumpAndSettle();
        expect(find.text('Baby Mage Robot Destroyed!'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('victory_cutscene_dialog')),
          findsOneWidget,
        );
        expect(find.text('CAMPAIGN VICTORY'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('victory_cutscene_skip_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.enemyPhase, 1);
        expect(controller.enemyMaxHp, 100);
        expect(controller.currentWeek, 1);
      },
    );

    test(
      'Robot Archmage uses single latest transition (Fire->Water x10 overridden by Fire->Fire x1) while hints stay deceptive until Recalibrator is bought & enabled',
      () async {
        final controller = await _createController(
          prefs: {
            'current_week': 10,
            'enemy_phase': 2,
            'enemy_max_hp': 200,
            'pcHp': 200,
            'unlockedYourPrediction': true,
            'showYourPrediction': true,
            'unlockedNextMove': true,
            'showNextMove': true,
            'unlockedSuggestion': true,
            'showSuggestion': true,
            'unlockedAlgorithm': true,
            'showAlgorithm': true,
            'orbs_fire': 1300,
            'orbs_water': 1300,
            'orbs_wood': 1300,
            'orbs_earth': 1300,
            'orbs_metal': 1300,
          },
        );
        addTearDown(controller.dispose);

        // Seed 10 cumulative Fire -> Water transitions
        for (int i = 0; i < 10; i++) {
          controller.playTurn(HandMove.rock); // Fire
          controller.userHp = controller.playerMaxHp;
          controller.computerHp = 200;
          controller.playTurn(HandMove.paper); // Water
        }
        // Now play Fire -> Fire once, ending with lastUserMove = Fire
        controller.playTurn(HandMove.rock); // Fire
        controller.playTurn(HandMove.rock); // Fire -> Fire recorded, lastUserMove = Fire

        // Cumulative matrix still heavily favors Fire -> Water
        expect(controller.engine.matrix[0][1], greaterThanOrEqualTo(10));
        expect(controller.engine.lastTransitionFor(HandMove.rock), HandMove.rock);

        // Before Markov Recalibrator: predictions display deceptive cumulative Fire -> Water!
        expect(controller.isMarkovRecalibratorActive, isFalse);
        expect(controller.predictedUserMoves, [HandMove.paper]);

        // Meanwhile, Robot Archmage actually counters Fire (lastTransitionFrom[Fire] = Fire)
        // with Water (paper) or Earth (lizard)!
        expect(
          [HandMove.paper, HandMove.lizard].contains(controller.crystalBallMove),
          isTrue,
        );

        // Attempt purchase of Markov Recalibrator (costs 1,200 of all 5 orbs)
        expect(
          GameController.costMarkovRecalibrator,
          const ElementalCost(
            fire: 1200,
            water: 1200,
            wood: 1200,
            earth: 1200,
            metal: 1200,
          ),
        );
        final fireBeforeBuy = controller.fireOrbs;
        final waterBeforeBuy = controller.waterOrbs;
        final woodBeforeBuy = controller.woodOrbs;
        final earthBeforeBuy = controller.earthOrbs;
        final metalBeforeBuy = controller.metalOrbs;
        expect(controller.unlockMarkovRecalibrator(), isTrue);
        expect(controller.markovRecalibratorUnlocked, isTrue);
        expect(controller.markovRecalibratorEnabled, isTrue);
        expect(controller.fireOrbs, fireBeforeBuy - 1200);
        expect(controller.waterOrbs, waterBeforeBuy - 1200);
        expect(controller.woodOrbs, woodBeforeBuy - 1200);
        expect(controller.earthOrbs, earthBeforeBuy - 1200);
        expect(controller.metalOrbs, metalBeforeBuy - 1200);

        // After Markov Recalibrator is enabled: hints expose true 1-step Fire -> Fire prediction!
        expect(controller.predictedUserMoves, [HandMove.rock]);
        expect(
          controller.pcNextMoves,
          containsAll([HandMove.paper, HandMove.lizard]),
        );

        // Toggling Recalibrator OFF reverts hints back to cumulative deceptive view
        controller.toggleMarkovRecalibrator(false);
        expect(controller.isMarkovRecalibratorActive, isFalse);
        expect(controller.predictedUserMoves, [HandMove.paper]);

        // Toggling ON re-exposes short-term prediction
        controller.toggleMarkovRecalibrator(true);
        expect(controller.isMarkovRecalibratorActive, isTrue);
        expect(controller.predictedUserMoves, [HandMove.rock]);
      },
    );

    testWidgets(
      'ShopDialog hides Markov Recalibrator before Archmage, reveals at 1,200x5 after Archmage, and MarkovMatrixView switches between cumulative and recalibrated modes',
      (WidgetTester tester) async {
        final preController = await _createController(
          prefs: {'current_week': 10, 'enemy_phase': 1},
        );
        addTearDown(preController.dispose);

        await tester.pumpWidget(
          _wrapScreen(
            preController,
            child: Scaffold(
              body: ShopDialog(controller: preController),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Markov Recalibrator'), findsNothing);

        final archController = await _createController(
          prefs: {
            'current_week': 10,
            'enemy_phase': 2,
            'enemy_max_hp': 200,
            'pcHp': 200,
            'orbs_fire': 1500,
            'orbs_water': 1500,
            'orbs_wood': 1500,
            'orbs_earth': 1500,
            'orbs_metal': 1500,
          },
        );
        addTearDown(archController.dispose);

        for (int i = 0; i < 6; i++) {
          archController.engine.recordTransition(HandMove.rock, HandMove.paper);
        }
        archController.engine.recordTransition(HandMove.rock, HandMove.rock);
        archController.lastUserMove = HandMove.rock;

        // 1. Before Recalibrator: MarkovMatrixView displays cumulative count 6 without banner
        await tester.pumpWidget(
          _wrapScreen(
            archController,
            child: Scaffold(
              body: SingleChildScrollView(
                child: MarkovMatrixView(
                  engine: archController.engine,
                  lastUserMove: archController.lastUserMove,
                  elementalMode: true,
                  localization: archController.localization,
                  isArchmageShortTermView:
                      archController.isArchmageBoss &&
                      archController.isMarkovRecalibratorActive,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('markov_archmage_short_term_banner')),
          findsNothing,
        );
        expect(find.text('6'), findsOneWidget);

        // 2. ShopDialog reveals Markov Recalibrator (1,200 of all 5 orbs)
        await tester.pumpWidget(
          _wrapScreen(
            archController,
            child: Scaffold(
              body: ShopDialog(controller: archController),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final shopScrollable = find.descendant(
          of: find.byType(ShopDialog),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('Markov Recalibrator'),
          250,
          scrollable: shopScrollable.first,
        );
        expect(find.text('Markov Recalibrator'), findsOneWidget);
        expect(find.text('1200'), findsAtLeastNWidgets(5));

        // 3. Unlock Markov Recalibrator and re-pump MarkovMatrixView -> banner & 100% single transition
        expect(archController.unlockMarkovRecalibrator(), isTrue);
        await tester.pumpWidget(
          _wrapScreen(
            archController,
            child: Scaffold(
              body: SingleChildScrollView(
                child: MarkovMatrixView(
                  engine: archController.engine,
                  lastUserMove: archController.lastUserMove,
                  elementalMode: true,
                  localization: archController.localization,
                  isArchmageShortTermView: archController.isArchmageBoss &&
                      archController.isMarkovRecalibratorActive,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('markov_archmage_short_term_banner')),
          findsOneWidget,
        );
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('6'), findsNothing);
      },
    );

    testWidgets(
      'VersusArena opponent HP bar scales smoothly to 200 and 400 max HP with green -> amber -> red colors',
      (WidgetTester tester) async {
        Future<Color> pumpEnemyHp(int hp, int maxHp) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: VersusArena(
                  userMove: null,
                  computerMove: null,
                  winner: null,
                  localization: LocalizationService(),
                  animationsEnabled: false,
                  roundId: 0,
                  userHp: 50,
                  playerMaxHp: 50,
                  computerHp: hp,
                  computerMaxHp: maxHp,
                  remainingMana: 100,
                  maxMana: 100,
                  isPhase2: true,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final pcHpBarFinder = find.byWidgetPredicate(
            (w) => w is RpgHpBar && w.maxHp == maxHp,
          );
          final pcHpBar = tester.widget<RpgHpBar>(pcHpBarFinder);
          expect(pcHpBar.hp, hp);
          expect(find.text('HP $hp'), findsOneWidget);
          final fractionBox = tester.widget<FractionallySizedBox>(
            find.descendant(
              of: pcHpBarFinder,
              matching: find.byType(FractionallySizedBox),
            ),
          );
          expect(fractionBox.widthFactor, closeTo(hp / maxHp, 0.01));
          final fillContainer = tester.widget<Container>(
            find.descendant(
              of: find.descendant(
                of: pcHpBarFinder,
                matching: find.byType(FractionallySizedBox),
              ),
              matching: find.byType(Container),
            ),
          );
          final gradient =
              (fillContainer.decoration! as BoxDecoration).gradient!
                  as LinearGradient;
          return gradient.colors.first;
        }

        // Phase 2 Archmage (200 HP)
        final archGreen = await pumpEnemyHp(200, 200);
        final archAmber = await pumpEnemyHp(100, 200); // 50%
        final archRed = await pumpEnemyHp(40, 200); // 20%
        expect(archGreen, isNot(equals(archAmber)));
        expect(archAmber, isNot(equals(archRed)));

        // Phase 3 Baby Mage (400 HP)
        final babyGreen = await pumpEnemyHp(400, 400);
        final babyAmber = await pumpEnemyHp(160, 400); // 40%
        final babyRed = await pumpEnemyHp(80, 400); // 20%
        expect(babyGreen, archGreen);
        expect(babyAmber, archAmber);
        expect(babyRed, archRed);
      },
    );

    test(
      'CloudSaveData round-trip and en/pt/es/de localizations are complete',
      () async {
        final controller = await _createController(
          prefs: {
            'current_week': 10,
            'enemy_phase': 2,
            'enemy_max_hp': 200,
            'pcHp': 150,
            'unlockedMarkovRecalibrator': true,
            'showMarkovRecalibrator': true,
          },
        );
        addTearDown(controller.dispose);

        controller.engine.recordTransition(HandMove.rock, HandMove.scissors);
        controller.storage.setShortTermTransitions(
          controller.engine.serializedLastTransitions,
        );

        final snapshot = CloudSaveData.fromStorage(controller.storage);
        final decoded = CloudSaveData.tryParse(json.encode(snapshot.toJson()))!;
        expect(decoded.enemyPhase, 2);
        expect(decoded.enemyMaxHp, 200);
        expect(decoded.pcHp, 150);
        expect(decoded.unlockedMarkovRecalibrator, isTrue);
        expect(decoded.showMarkovRecalibrator, isTrue);
        expect(decoded.shortTermTransitions, {HandMove.rock.id: HandMove.scissors.id});

        const requiredKeys = [
          'boss_name_guardian',
          'boss_name_archmage',
          'boss_name_baby_mage',
          'castle_ending_secret_w1_title',
          'castle_ending_standard_victory_title',
          'markov_recalibrator_title',
          'markov_recalibrator_desc',
          'markov_recalibrator_archmage_banner',
          'boss_victory_p1_title',
          'boss_victory_p2_defeated_title',
          'boss_victory_p3_defeated_title',
          'secret_cutscene_header',
          'standard_cutscene_header',
        ];
        for (final lang in ['en', 'pt', 'es', 'de']) {
          controller.localization.setLanguage(lang);
          for (final key in requiredKeys) {
            final value = controller.localization.t(key, fallback: '__MISSING__');
            expect(
              value,
              isNot('__MISSING__'),
              reason: 'Missing $lang translation for $key',
            );
            expect(value.trim(), isNotEmpty);
          }
        }
      },
    );
  });
}
