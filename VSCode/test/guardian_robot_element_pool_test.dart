import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/markov_engine.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/widgets/elemental_symbol_icon.dart';
import 'package:how_predictable/views/widgets/hints_bar.dart';

Future<GameController> _createController({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'musicEnabled': false,
    'soundEnabled': false,
    'vibrationEnabled': false,
    'animationsEnabled': false,
    'has_seen_story_intro': true,
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

  const basicThree = [HandMove.fire, HandMove.water, HandMove.wood];

  group('Phase 1 Guardian Robot Element Pool & Counter Constraints', () {
    test('MarkovEngine decouples enemyAllowedMoves from player enableExtendedHands', () {
      final engine = MarkovEngine(
        enableExtendedHands: true,
        enableEnemyExtendedHands: false,
        enemyAllowedMoves: basicThree,
        enableElementalMode: true,
        random: Random(123),
      );

      expect(engine.activeMoves, HandMove.values);
      expect(engine.size, 5);
      expect(engine.enemyMoves, basicThree);
      expect(engine.enemySize, 3);

      // Unseeded fallback random moves sample exclusively from [Fire, Water, Wood]
      final seenRandom = <HandMove>{};
      for (int i = 0; i < 60; i++) {
        final move = engine.getRandomEnemyMove();
        expect(basicThree.contains(move), isTrue);
        expect(move, isNot(HandMove.earth));
        expect(move, isNot(HandMove.metal));
        seenRandom.add(move);
      }
      expect(seenRandom, containsAll(basicThree));

      // Verify exact filtered counters for every predicted player move (Elemental Wu Xing)
      // 1. Predicted Fire -> Water (never Earth)
      engine.recordTransition(HandMove.fire, HandMove.fire);
      expect(engine.predictNextUserMoves(HandMove.fire), [HandMove.fire]);
      expect(engine.computeSmartChoices(HandMove.fire), [HandMove.water]);
      expect(engine.computeSmartChoice(HandMove.fire), HandMove.water);

      // 2. Predicted Water -> Wood (never Earth)
      engine.recordTransition(HandMove.water, HandMove.water);
      expect(engine.predictNextUserMoves(HandMove.water), [HandMove.water]);
      expect(engine.computeSmartChoices(HandMove.water), [HandMove.wood]);
      expect(engine.computeSmartChoice(HandMove.water), HandMove.wood);

      // 3. Predicted Wood -> Fire (never Metal)
      engine.recordTransition(HandMove.wood, HandMove.wood);
      expect(engine.predictNextUserMoves(HandMove.wood), [HandMove.wood]);
      expect(engine.computeSmartChoices(HandMove.wood), [HandMove.fire]);
      expect(engine.computeSmartChoice(HandMove.wood), HandMove.fire);

      // 4. Predicted Earth -> Wood (never Metal)
      engine.recordTransition(HandMove.earth, HandMove.earth);
      expect(engine.predictNextUserMoves(HandMove.earth), [HandMove.earth]);
      expect(engine.computeSmartChoices(HandMove.earth), [HandMove.wood]);
      expect(engine.computeSmartChoice(HandMove.earth), HandMove.wood);

      // 5. Predicted Metal -> Fire or Water (never Earth or Metal)
      engine.recordTransition(HandMove.metal, HandMove.metal);
      expect(engine.predictNextUserMoves(HandMove.metal), [HandMove.metal]);
      expect(
        engine.computeSmartChoices(HandMove.metal),
        unorderedEquals([HandMove.fire, HandMove.water]),
      );
      for (int i = 0; i < 30; i++) {
        final choice = engine.computeSmartChoice(HandMove.metal);
        expect([HandMove.fire, HandMove.water].contains(choice), isTrue);
      }

      // 6. Tie-breaking when Earth & Metal tie -> covers all 3 basic counters -> [] -> random in [Fire, Water, Wood]
      engine.reset();
      engine.recordTransition(HandMove.earth, HandMove.earth);
      engine.recordTransition(HandMove.earth, HandMove.metal);
      expect(engine.computeSmartChoices(HandMove.earth), isEmpty);
      for (int i = 0; i < 30; i++) {
        final fallback = engine.computeSmartChoice(HandMove.earth);
        expect(basicThree.contains(fallback), isTrue);
      }
    });

    test('GameController enforces boss-specific element pools across all 4 stages regardless of player unlocks or week', () async {
      // Stage 1: Guardian Robot in Week 1 AND Week 12 with Earth & Metal unlocked -> strictly [Fire, Water, Wood]
      for (final week in [1, 12]) {
        final guardianController = await _createController(
          prefs: {
            'current_week': week,
            'enemy_stage': 1,
            'unlockedNewHands': true,
            'showNewHands': true,
          },
        );
        expect(guardianController.playerAllowedMoves, HandMove.values);
        expect(guardianController.bossAllowedMoves, basicThree);
        expect(guardianController.engine.size, 5);
        expect(guardianController.engine.enemyMoves, basicThree);
        expect(guardianController.engine.enemySize, 3);
        guardianController.dispose();
      }

      // Stage 2: Robot Archmage even when player does NOT have Earth & Metal -> all 5 elements
      final archmageController = await _createController(
        prefs: {
          'current_week': 10,
          'enemy_stage': 2,
          'enemy_max_hp': 200,
          'pcHp': 200,
          'unlockedNewHands': false,
          'showNewHands': false,
        },
      );
      expect(archmageController.playerAllowedMoves, basicThree);
      expect(archmageController.bossAllowedMoves, HandMove.values);
      expect(archmageController.engine.size, 3);
      expect(archmageController.engine.enemyMoves, HandMove.values);
      expect(archmageController.engine.enemySize, 5);
      archmageController.dispose();

      // Stage 3: Metal Wizard -> [Metal, Earth]
      final wizardController = await _createController(
        prefs: {
          'current_week': 3,
          'enemy_stage': 3,
          'enemy_max_hp': 300,
          'pcHp': 300,
          'unlockedNewHands': true,
          'showNewHands': true,
        },
      );
      expect(wizardController.bossAllowedMoves, [HandMove.metal, HandMove.earth]);
      expect(wizardController.engine.enemyMoves, [HandMove.metal, HandMove.earth]);
      expect(wizardController.engine.enemySize, 2);
      wizardController.dispose();

      // Stage 4: Baby Mage Robot even when player does NOT have Earth & Metal -> all 5 elements
      final babyController = await _createController(
        prefs: {
          'current_week': 5,
          'enemy_stage': 4,
          'enemy_max_hp': 400,
          'pcHp': 400,
          'unlockedNewHands': false,
          'showNewHands': false,
        },
      );
      expect(babyController.bossAllowedMoves, HandMove.values);
      expect(babyController.engine.enemyMoves, HandMove.values);
      expect(babyController.engine.enemySize, 5);
      babyController.dispose();
    });

    test('150-round Phase 1 Guardian Robot simulation with Earth & Metal unlocked never plays or predicts Earth/Metal', () async {
      final controller = await _createController(
        prefs: {
          'current_week': 1,
          'enemy_stage': 1,
          'enemy_max_hp': 100,
          'pcHp': 100,
          'hp_upgrade_level': 200,
          'mana_upgrade_level': 200,
          'unlockedNewHands': true,
          'showNewHands': true,
          'unlockedYourPrediction': true,
          'showYourPrediction': true,
          'unlockedNextMove': true,
          'showNextMove': true,
          'unlockedSuggestion': true,
          'showSuggestion': true,
          'unlockedCrystalBall': true,
          'showCrystalBall': true,
          'unlockedCrystalBallPlus': true,
          'showCrystalBallPlus': true,
        },
      );
      addTearDown(controller.dispose);

      // Verify initial Turn 0 predictions are within basic 3
      expect(basicThree.contains(controller.crystalBallMove), isTrue);
      expect(
        controller.pcNextMoves.every(basicThree.contains),
        isTrue,
      );

      final seenGuardianMoves = <HandMove>{};
      final sequence = [
        HandMove.earth,
        HandMove.metal,
        HandMove.earth,
        HandMove.metal,
        HandMove.earth,
        HandMove.earth,
        HandMove.metal,
        HandMove.fire,
        HandMove.water,
        HandMove.wood,
      ];

      for (int i = 0; i < 150; i++) {
        // Keep battle alive across all 150 rounds without triggering end modals
        controller.userHp = controller.effectivePlayerMaxHp;
        controller.computerHp = controller.enemyMaxHp;
        controller.totalRounds = 0;

        final playerMove = sequence[i % sequence.length];
        controller.playTurn(playerMove);

        final aiMove = controller.currentComputerMove;
        expect(aiMove, isNotNull);
        expect(
          basicThree.contains(aiMove),
          isTrue,
          reason: 'Round $i: Guardian Robot played forbidden move $aiMove',
        );
        expect(aiMove, isNot(HandMove.earth));
        expect(aiMove, isNot(HandMove.metal));
        seenGuardianMoves.add(aiMove!);

        // Upcoming predictions must also stay strictly within [Fire, Water, Wood]
        expect(
          basicThree.contains(controller.crystalBallMove),
          isTrue,
          reason: 'Round $i: Crystal Ball predicted forbidden ${controller.crystalBallMove}',
        );
        for (final pcChoice in controller.pcNextMoves) {
          expect(
            basicThree.contains(pcChoice),
            isTrue,
            reason: 'Round $i: PC Choice contained forbidden $pcChoice',
          );
        }
        if (controller.pcNextMove != null) {
          expect(basicThree.contains(controller.pcNextMove), isTrue);
        }

        // Suggestion & Crystal Ball+ recommend all unlocked player elements that beat the predicted basic move
        for (final cbPlus in controller.crystalBallPlusMoves) {
          expect(
            cbPlus.beats(controller.crystalBallMove!, elemental: true),
            isTrue,
          );
        }
        if (controller.crystalBallMove == HandMove.fire) {
          expect(
            controller.crystalBallPlusMoves,
            unorderedEquals([HandMove.water, HandMove.earth]),
          );
        } else if (controller.crystalBallMove == HandMove.water) {
          expect(
            controller.crystalBallPlusMoves,
            unorderedEquals([HandMove.wood, HandMove.earth]),
          );
        } else if (controller.crystalBallMove == HandMove.wood) {
          expect(
            controller.crystalBallPlusMoves,
            unorderedEquals([HandMove.fire, HandMove.metal]),
          );
        }
      }

      // Guardian Robot used all 3 basic elements across the match
      expect(seenGuardianMoves, unorderedEquals(basicThree));
    });

    test('Phase 1 Suggestion & Crystal Ball+ include Earth/Metal counters against Guardian Robot basic moves', () async {
      final controller = await _createController(
        prefs: {
          'current_week': 2,
          'enemy_stage': 1,
          'unlockedNewHands': true,
          'showNewHands': true,
          'unlockedYourPrediction': true,
          'showYourPrediction': true,
          'unlockedNextMove': true,
          'showNextMove': true,
          'unlockedSuggestion': true,
          'showSuggestion': true,
          'unlockedCrystalBall': true,
          'showCrystalBall': true,
          'unlockedCrystalBallPlus': true,
          'showCrystalBallPlus': true,
        },
      );
      addTearDown(controller.dispose);

      // 1. Teach Earth -> Earth repeatedly so Guardian Robot predicts Earth and counters with Wood (never Metal)
      for (int i = 0; i < 6; i++) {
        controller.userHp = controller.effectivePlayerMaxHp;
        controller.computerHp = controller.enemyMaxHp;
        controller.playTurn(HandMove.earth);
      }
      expect(controller.predictedUserMoves, [HandMove.earth]);
      expect(controller.pcNextMoves, [HandMove.wood]);
      expect(controller.crystalBallMove, HandMove.wood);
      // Player suggestions & Crystal Ball+ recommend Fire AND Metal (both beat Wood!)
      expect(
        controller.suggestedMoves,
        unorderedEquals([HandMove.fire, HandMove.metal]),
      );
      expect(
        controller.crystalBallPlusMoves,
        unorderedEquals([HandMove.fire, HandMove.metal]),
      );

      // 2. Teach Metal -> Metal repeatedly so Guardian Robot predicts Metal and counters with [Fire, Water]
      for (int i = 0; i < 10; i++) {
        controller.userHp = controller.effectivePlayerMaxHp;
        controller.computerHp = controller.enemyMaxHp;
        controller.playTurn(HandMove.metal);
      }
      expect(controller.predictedUserMoves, [HandMove.metal]);
      expect(
        controller.pcNextMoves,
        unorderedEquals([HandMove.fire, HandMove.water]),
      );
      expect(
        [HandMove.fire, HandMove.water].contains(controller.crystalBallMove),
        isTrue,
      );
      // Earth beats BOTH Fire and Water -> Suggestion strictly recommends [Earth]!
      expect(controller.suggestedMoves, [HandMove.earth]);
    });

    testWidgets('HintsBar displays basic PC Choice / Crystal Ball while showing unlocked Earth/Metal in Your Choice, Suggestion & Crystal Ball+', (WidgetTester tester) async {
      final controller = await _createController(
        prefs: {
          'current_week': 1,
          'enemy_stage': 1,
          'unlockedNewHands': true,
          'showNewHands': true,
          'unlockedYourPrediction': true,
          'showYourPrediction': true,
          'unlockedNextMove': true,
          'showNextMove': true,
          'unlockedSuggestion': true,
          'showSuggestion': true,
          'unlockedCrystalBall': true,
          'showCrystalBall': true,
          'unlockedCrystalBallPlus': true,
          'showCrystalBallPlus': true,
        },
      );
      addTearDown(controller.dispose);

      // Seed Earth -> Earth so Guardian Robot predicts Earth -> Wood
      for (int i = 0; i < 5; i++) {
        controller.userHp = controller.effectivePlayerMaxHp;
        controller.computerHp = controller.enemyMaxHp;
        controller.playTurn(HandMove.earth);
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 380,
                child: HintsBar(controller: controller),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final pcChip = find.ancestor(
        of: find.text("PC's Choice:"),
        matching: find.byType(Container),
      ).first;
      // PC's Choice shows Wood, NEVER Earth or Metal
      expect(
        find.descendant(
          of: pcChip,
          matching: find.byWidgetPredicate(
            (w) => w is ElementalSymbolIcon && w.move == HandMove.wood,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: pcChip,
          matching: find.byWidgetPredicate(
            (w) =>
                w is ElementalSymbolIcon &&
                (w.move == HandMove.earth || w.move == HandMove.metal),
          ),
        ),
        findsNothing,
      );

      // Suggestion shows Fire + Metal (defeating Wood)
      final suggestionChip = find.ancestor(
        of: find.text('Suggestion:'),
        matching: find.byType(Container),
      ).first;
      expect(
        find.descendant(
          of: suggestionChip,
          matching: find.byWidgetPredicate(
            (w) => w is ElementalSymbolIcon && w.move == HandMove.fire,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: suggestionChip,
          matching: find.byWidgetPredicate(
            (w) => w is ElementalSymbolIcon && w.move == HandMove.metal,
          ),
        ),
        findsOneWidget,
      );

      // Crystal Ball+ shows Fire + Metal (defeating Wood)
      final cbPlusChip = find.ancestor(
        of: find.text('Crystal Ball+:'),
        matching: find.byType(Container),
      ).first;
      expect(
        find.descendant(
          of: cbPlusChip,
          matching: find.byWidgetPredicate(
            (w) => w is ElementalSymbolIcon && w.move == HandMove.fire,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cbPlusChip,
          matching: find.byWidgetPredicate(
            (w) => w is ElementalSymbolIcon && w.move == HandMove.metal,
          ),
        ),
        findsOneWidget,
      );
    });
  });
}
