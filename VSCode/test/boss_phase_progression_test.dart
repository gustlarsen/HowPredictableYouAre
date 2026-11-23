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
import 'package:how_predictable/views/widgets/elemental_symbol_icon.dart';
import 'package:how_predictable/views/widgets/hints_bar.dart';
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

  group('Uniform 1 HP Damage, 4-Stage Boss Progression & Markov Recalibrator', () {
    test(
      'Every winning attack deals strictly 1 HP across all 4 stages and element modes',
      () async {
        for (final stage in [1, 2, 3, 4]) {
          for (final unlockEarthMetal in [false, true]) {
            for (final elementalMode in [true, false]) {
              final maxHp = GameController.maxHpForEnemyStage(stage);
              final controller = await _createController(
                prefs: {
                  'current_week': stage >= 2 ? 10 : 1,
                  'enemy_stage': stage,
                  'enemy_max_hp': maxHp,
                  'pcHp': maxHp,
                  'unlockedNewHands': unlockEarthMetal,
                  'showNewHands': unlockEarthMetal,
                  'unlockedNewSkin': !elementalMode,
                  'showNewSkin': !elementalMode,
                },
              );

              expect(controller.playerWinDamageToBoss, 1);
              expect(controller.bossWinDamageToPlayer, 1);

              // Player wins -> boss loses exactly 1 HP
              final prevBossHp = controller.computerHp;
              controller.crystalBallMove = HandMove.scissors; // Wood
              controller.playTurn(HandMove.rock); // Fire beats Wood in both modes
              expect(controller.lastWinner, RoundWinner.user);
              expect(prevBossHp - controller.computerHp, 1);

              // PC wins -> Hero loses exactly 1 HP
              final prevHeroHp = controller.userHp;
              controller.crystalBallMove = HandMove.paper; // Water
              controller.playTurn(HandMove.rock); // Water beats Fire/Rock in both modes
              expect(controller.lastWinner, RoundWinner.computer);
              expect(prevHeroHp - controller.userHp, 1);

              // Tie -> 0 HP damage to both
              final bossHpBeforeTie = controller.computerHp;
              final heroHpBeforeTie = controller.userHp;
              controller.crystalBallMove = HandMove.rock;
              controller.playTurn(HandMove.rock);
              expect(controller.lastWinner, RoundWinner.draw);
              expect(controller.computerHp, bossHpBeforeTie);
              expect(controller.userHp, heroHpBeforeTie);

              controller.dispose();
            }
          }
        }
      },
    );

    testWidgets(
      'Week-1 Secret Route: Stage 1 (100 HP) -> Stage 3 Metal Wizard (300 HP, 100% Metal) -> Secret Week-1 Ending',
      (WidgetTester tester) async {
        final controller = await _createController(
          prefs: {
            'current_week': 1,
            'enemy_stage': 1,
            'enemy_max_hp': 100,
            'pcHp': 1,
            'mana_upgrade_level': 220, // 320 Mana so 300 HP Metal Wizard is beatable in 1 battle
            'unlockedNextMove': true,
            'showNextMove': true,
            'unlockedCrystalBall': true,
            'showCrystalBall': true,
            'unlockedCrystalBallPlus': true,
            'showCrystalBallPlus': true,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_wrapScreen(controller));
        await tester.pumpAndSettle();

        // Force Turn 1 winning counter against Guardian Robot at 1 HP in Week 1.
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);

        expect(controller.computerHp, 0);
        expect(controller.remainingMana, 319);
        expect(controller.isBossVictoryPending, isTrue);
        expect(controller.is100RoundsAlertPending, isFalse);
        expect(
          controller.isEndingUnlocked(NarrativeEnding.secretWeek1),
          isFalse,
          reason: 'Secret Week-1 ending must only unlock after defeating Metal Wizard in Week 1',
        );

        // Further inputs are blocked while victory is pending.
        controller.playTurn(HandMove.rock);
        expect(controller.totalRounds, 1);

        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('boss_victory_modal')), findsOneWidget);
        expect(find.text('Guardian Robot Destroyed!'), findsOneWidget);
        expect(find.text('The Metal Wizard Enters Battle!'), findsOneWidget);

        // Confirm modal -> advances to Stage 3 Metal Wizard (300 HP, Metal-only)
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.enemyStage, 3);
        expect(controller.enemyMaxHp, 300);
        expect(controller.computerHp, 300);
        expect(controller.currentWeek, 1);
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.metalWizard),
          isTrue,
        );
        expect(find.byKey(const ValueKey('boss_phase_pill_3')), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('versus_boss_sprite_stage_3')),
            matching: find.byKey(
              const ValueKey('assets/images/enemies/metal_wizard_idle.png'),
            ),
          ),
          findsOneWidget,
        );
        expect(find.text('METAL WIZARD'), findsOneWidget);
        expect(find.text('300 / 300'), findsOneWidget);

        // Verify Metal Wizard hints: PC Next Move & Crystal Ball = Metal, Crystal Ball+ = Fire & Water
        expect(controller.pcNextMoves, [HandMove.metal]);
        expect(controller.crystalBallMoves, [HandMove.metal]);
        expect(
          controller.crystalBallPlusMoves,
          containsAll([HandMove.rock, HandMove.paper]),
        );

        // Verify Metal Wizard chooses 100% Metal on every turn
        for (int i = 0; i < 10; i++) {
          controller.playTurn(HandMove.rock); // Fire melts Metal -> -1 HP, +1 Metal orb
          expect(controller.currentComputerMove, HandMove.metal);
          expect(controller.lastWinner, RoundWinner.user);
        }
        expect(controller.computerHp, 290);
        expect(controller.metalOrbs, 10);

        // Reduce Metal Wizard to 1 HP and finish him while still in Week 1
        controller.computerHp = 1;
        controller.playTurn(HandMove.paper); // Water rusts Metal -> 0 HP
        expect(controller.computerHp, 0);
        expect(controller.isBossVictoryPending, isTrue);
        expect(
          controller.isEndingUnlocked(NarrativeEnding.secretWeek1),
          isTrue,
        );

        await tester.pumpAndSettle();
        expect(find.text('Metal Wizard Defeated!'), findsOneWidget);
        expect(find.text('Week 1 Lightning Victory!'), findsOneWidget);

        // Confirm modal -> opens Secret Week-1 Victory Cutscene (skipping Stage 4).
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

        final nextBtnFinder = find.byKey(
          const ValueKey('victory_cutscene_next_button'),
        );
        await tester.ensureVisible(nextBtnFinder);
        await tester.tap(nextBtnFinder);
        await tester.pumpAndSettle();
        expect(find.text('Rescued Intact'), findsOneWidget);

        await tester.ensureVisible(nextBtnFinder);
        await tester.tap(nextBtnFinder);
        await tester.pumpAndSettle();
        expect(find.text('Secret Ending Unlocked'), findsOneWidget);

        final finishBtnFinder = find.byKey(
          const ValueKey('victory_cutscene_finish_button'),
        );
        await tester.ensureVisible(finishBtnFinder);
        await tester.tap(finishBtnFinder);
        await tester.pumpAndSettle();

        // Cycle concludes cleanly back to Week 1 Stage 1.
        expect(controller.isBossVictoryPending, isFalse);
        expect(controller.enemyStage, 1);
        expect(controller.enemyMaxHp, 100);
        expect(controller.currentWeek, 1);
      },
    );

    testWidgets(
      'Weeks 2-9 Route (and Week-1 Stage-1 beat followed by Week 2+): Stage 1 -> Stage 3 Metal Wizard (300 HP) -> Stage 4 Baby Mage Robot (400 HP, pure random AI) -> Standard Victory',
      (WidgetTester tester) async {
        final controller = await _createController(
          prefs: {
            'current_week': 5,
            'enemy_stage': 1,
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
        expect(find.text('Guardian Robot Destroyed!'), findsOneWidget);
        expect(find.text('The Metal Wizard Enters Battle!'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.enemyStage, 3);
        expect(controller.enemyMaxHp, 300);
        expect(controller.computerHp, 300);
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.metalWizard),
          isTrue,
        );

        // Defeat Stage 3 Metal Wizard in Week 5 -> transitions to Stage 4 Baby Mage Robot (400 HP)
        controller.computerHp = 1;
        controller.playTurn(HandMove.rock);
        expect(controller.computerHp, 0);
        expect(controller.isBossVictoryPending, isTrue);
        expect(
          controller.isEndingUnlocked(NarrativeEnding.secretWeek1),
          isFalse,
        );

        await tester.pumpAndSettle();
        expect(find.text('Metal Wizard Defeated!'), findsOneWidget);
        expect(
          find.text('Automated Contingency: Baby Mage Robot!'),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.enemyStage, 4);
        expect(controller.enemyMaxHp, 400);
        expect(controller.computerHp, 400);
        expect(controller.engine.enemySize, 5);
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.babyRobot),
          isTrue,
        );
        expect(find.byKey(const ValueKey('boss_phase_pill_4')), findsNothing);
        expect(find.text('BABY MAGE ROBOT'), findsOneWidget);
        expect(find.text('400 / 400'), findsOneWidget);

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
        for (final m in HandMove.values) {
          expect(
            seenMoves[m]!,
            greaterThan(5),
            reason: 'Baby Mage Robot should pick $m randomly regardless of bias',
          );
        }

        // Defeat Stage 4 Baby Mage Robot -> unlocks Standard Victory Ending
        controller.computerHp = 1;
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
      },
    );

    testWidgets(
      'Week 10+ Route: Stage 1 -> Stage 2 Robot Archmage (200 HP) -> Stage 3 Metal Wizard (300 HP) -> Stage 4 Baby Mage Robot (400 HP) -> Standard Victory',
      (WidgetTester tester) async {
        final controller = await _createController(
          prefs: {
            'current_week': 10,
            'enemy_stage': 1,
            'enemy_max_hp': 100,
            'pcHp': 1,
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
          find.text('Stage 2: Robot Archmage Approaches!'),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        // Now fighting Stage 2 Robot Archmage (200 HP, 5 elements)
        expect(controller.enemyStage, 2);
        expect(controller.enemyMaxHp, 200);
        expect(controller.computerHp, 200);
        expect(controller.engine.enemySize, 5);
        expect(find.byKey(const ValueKey('boss_phase_pill_2')), findsNothing);
        expect(find.text('ROBOT ARCHMAGE'), findsOneWidget);
        expect(find.text('200 / 200'), findsOneWidget);

        // Defeat Stage 2 Robot Archmage -> strictly transitions to Stage 3 Metal Wizard (300 HP)
        controller.computerHp = 1;
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        expect(controller.computerHp, 0);
        expect(controller.isBossVictoryPending, isTrue);

        await tester.pumpAndSettle();
        expect(find.text('Robot Archmage Destroyed!'), findsOneWidget);
        expect(find.text('Stage 3: The Metal Wizard Himself!'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.enemyStage, 3);
        expect(controller.enemyMaxHp, 300);
        expect(controller.computerHp, 300);
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.metalWizard),
          isTrue,
        );
        expect(find.byKey(const ValueKey('boss_phase_pill_3')), findsNothing);
        expect(find.text('METAL WIZARD'), findsOneWidget);
        expect(find.text('300 / 300'), findsOneWidget);

        // Defeat Stage 3 Metal Wizard -> transitions to Stage 4 Baby Mage Robot (400 HP)
        controller.computerHp = 1;
        controller.playTurn(HandMove.rock);
        expect(controller.computerHp, 0);
        expect(controller.isBossVictoryPending, isTrue);

        await tester.pumpAndSettle();
        expect(find.text('Metal Wizard Defeated!'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.enemyStage, 4);
        expect(controller.enemyMaxHp, 400);
        expect(controller.computerHp, 400);
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.babyRobot),
          isTrue,
        );
        expect(find.byKey(const ValueKey('boss_phase_pill_4')), findsNothing);
        expect(find.text('BABY MAGE ROBOT'), findsOneWidget);
        expect(find.text('400 / 400'), findsOneWidget);

        // Defeat Stage 4 Baby Mage Robot -> unlocks Standard Victory Ending & triggers campaign cutscene
        controller.computerHp = 1;
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

        expect(controller.enemyStage, 1);
        expect(controller.enemyMaxHp, 100);
        expect(controller.currentWeek, 1);
      },
    );

    test(
      'Stage 1 beaten in Week 1 followed by advancing to Week 2+ transitions Stage 3 Metal Wizard defeat into Stage 4 Baby Mage Robot (not Secret Ending)',
      () async {
        final controller = await _createController(
          prefs: {
            'current_week': 1,
            'enemy_stage': 3,
            'enemy_max_hp': 300,
            'pcHp': 300,
          },
        );
        addTearDown(controller.dispose);

        // Calendar advances to Week 2 before finishing the Metal Wizard
        controller.completeBattleWeek();
        expect(controller.currentWeek, 2);
        expect(controller.enemyStage, 3);

        controller.computerHp = 1;
        controller.playTurn(HandMove.rock);
        expect(controller.computerHp, 0);
        expect(controller.isBossVictoryPending, isTrue);
        expect(controller.isEndingUnlocked(NarrativeEnding.secretWeek1), isFalse);

        final concluded = controller.advanceAfterBossVictory();
        expect(concluded, isFalse);
        expect(controller.enemyStage, 4);
        expect(controller.enemyMaxHp, 400);
      },
    );

    test(
      'Robot Archmage uses single latest transition (Fire->Water x10 overridden by Fire->Fire x1) while hints stay deceptive until Recalibrator is bought & enabled',
      () async {
        final controller = await _createController(
          prefs: {
            'current_week': 10,
            'enemy_stage': 2,
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
          prefs: {'current_week': 10, 'enemy_stage': 1},
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
            'enemy_stage': 2,
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
      'Stage 3 Metal Wizard HintsBar shows Metal for PC Next Move & Crystal Ball, and Fire & Water for Crystal Ball+',
      (WidgetTester tester) async {
        final controller = await _createController(
          prefs: {
            'current_week': 3,
            'enemy_stage': 3,
            'enemy_max_hp': 300,
            'pcHp': 300,
            'unlockedNextMove': true,
            'showNextMove': true,
            'unlockedCrystalBall': true,
            'showCrystalBall': true,
            'unlockedCrystalBallPlus': true,
            'showCrystalBallPlus': true,
            'unlockedNewHands': true,
            'showNewHands': true,
          },
        );
        addTearDown(controller.dispose);

        expect(controller.pcNextMoves, [HandMove.metal]);
        expect(controller.crystalBallMoves, [HandMove.metal]);
        expect(
          controller.crystalBallPlusMoves,
          [HandMove.rock, HandMove.paper],
        );

        await tester.pumpWidget(
          _wrapScreen(
            controller,
            child: Scaffold(
              body: HintsBar(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (w) => w is ElementalSymbolIcon && w.move == HandMove.metal,
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is ElementalSymbolIcon && w.move == HandMove.rock,
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is ElementalSymbolIcon && w.move == HandMove.paper,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'VersusArena opponent HP bar scales smoothly to 100, 200, 300, and 400 max HP with green -> amber -> red colors',
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
          expect(find.text('$hp / $maxHp'), findsOneWidget);
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

        // Stage 2 Archmage (200 HP)
        final archGreen = await pumpEnemyHp(200, 200);
        final archAmber = await pumpEnemyHp(100, 200); // 50%
        final archRed = await pumpEnemyHp(40, 200); // 20%
        expect(archGreen, isNot(equals(archAmber)));
        expect(archAmber, isNot(equals(archRed)));

        // Stage 3 Metal Wizard (300 HP)
        final wizardGreen = await pumpEnemyHp(300, 300);
        final wizardAmber = await pumpEnemyHp(150, 300); // 50%
        final wizardRed = await pumpEnemyHp(60, 300); // 20%
        expect(wizardGreen, archGreen);
        expect(wizardAmber, archAmber);
        expect(wizardRed, archRed);

        // Stage 4 Baby Mage (400 HP)
        final babyGreen = await pumpEnemyHp(400, 400);
        final babyAmber = await pumpEnemyHp(160, 400); // 40%
        final babyRed = await pumpEnemyHp(80, 400); // 20%
        expect(babyGreen, archGreen);
        expect(babyAmber, archAmber);
        expect(babyRed, archRed);
      },
    );

    test(
      'CloudSaveData round-trip and en/pt/es/de localizations are complete for all 4 stages',
      () async {
        final controller = await _createController(
          prefs: {
            'current_week': 10,
            'enemy_stage': 3,
            'enemy_max_hp': 300,
            'pcHp': 245,
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
        expect(decoded.enemyStage, 3);
        expect(decoded.enemyPhase, 3);
        expect(decoded.enemyMaxHp, 300);
        expect(decoded.pcHp, 245);
        expect(decoded.unlockedMarkovRecalibrator, isTrue);
        expect(decoded.showMarkovRecalibrator, isTrue);
        expect(decoded.shortTermTransitions, {HandMove.rock.id: HandMove.scissors.id});

        const requiredKeys = [
          'boss_name_guardian',
          'boss_name_archmage',
          'boss_name_metal_wizard',
          'boss_name_baby_mage',
          'castle_bestiary_metal_wizard_name',
          'castle_bestiary_metal_wizard_model',
          'castle_bestiary_metal_wizard_lore',
          'castle_bestiary_metal_wizard_hint',
          'castle_ending_secret_w1_title',
          'castle_ending_standard_victory_title',
          'markov_recalibrator_title',
          'markov_recalibrator_desc',
          'markov_recalibrator_archmage_banner',
          'markov_metal_wizard_banner',
          'boss_victory_p1_title',
          'boss_victory_s1_to_s3_subtitle',
          'boss_victory_s1_to_s3_body',
          'boss_victory_p2_defeated_title',
          'boss_victory_s2_to_s3_subtitle',
          'boss_victory_s2_to_s3_body',
          'boss_victory_s3_defeated_title',
          'boss_victory_s3_to_s4_subtitle',
          'boss_victory_s3_to_s4_body',
          'boss_victory_p3_defeated_title',
          'boss_victory_face_metal_wizard_btn',
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
