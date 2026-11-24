import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/metal_wizard_ai_state.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/models/royal_castle.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/royal_castle_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/widgets/elemental_symbol_icon.dart';
import 'package:how_predictable/views/widgets/hints_bar.dart';
import 'package:how_predictable/views/widgets/markov_matrix_view.dart';

Future<GameController> _createMetalWizardController({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'musicEnabled': false,
    'soundEnabled': false,
    'vibrationEnabled': false,
    'animationsEnabled': false,
    'hasSeenStoryIntro': true,
    'has_seen_story_intro': true,
    'current_week': 3,
    'enemy_stage': 3,
    'enemy_max_hp': 300,
    'pcHp': 300,
    'mana_upgrade_level': 200, // 300 Mana for multi-phase state tests
    'unlockedNewHands': true,
    'showNewHands': true,
    'unlockedNextMove': true,
    'showNextMove': true,
    'unlockedSuggestion': true,
    'showSuggestion': true,
    'unlockedCrystalBall': true,
    'showCrystalBall': true,
    'unlockedCrystalBallPlus': true,
    'showCrystalBallPlus': true,
    'unlockedAlgorithm': true,
    'showAlgorithm': true,
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

HandMove _counterMoveFor(HandMove wizardMove) {
  return wizardMove == HandMove.metal ? HandMove.fire : HandMove.wood;
}

HandMove _losingMoveFor(HandMove wizardMove) {
  // Wood loses to Metal; Fire/Water lose to Earth
  return wizardMove == HandMove.metal ? HandMove.wood : HandMove.fire;
}

HandMove _drawMoveFor(HandMove wizardMove) {
  // Earth draws Earth; Metal (player) triggers Anti-Metal Shield (draw)
  return wizardMove == HandMove.metal ? HandMove.metal : HandMove.earth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Metal Wizard Element Pool & Deterministic AI State Machine', () {
    test('Allowed element pool is [Metal, Earth] and Turn 1 starts with Metal, Win-Stay / Lose-Shift', () async {
      final controller = await _createMetalWizardController();
      addTearDown(controller.dispose);

      expect(
        controller.bossAllowedMoves,
        const [HandMove.metal, HandMove.earth],
      );
      expect(controller.engine.enemyMoves, const [HandMove.metal, HandMove.earth]);

      final ai = controller.metalWizardAiState;
      expect(ai.currentMove, HandMove.metal);
      expect(ai.strategyMode, MetalWizardStrategyMode.normal);
      expect(ai.consecutiveLosses, 0);
      expect(ai.scriptedQueue, isEmpty);
      expect(ai.nextMoveAfterScript, isNull);
      expect(ai.tenLossStage, 0);

      // Turn 1: Metal Wizard casts Metal; Wizard wins against Wood -> keeps Metal
      controller.playTurn(HandMove.wood); // Wood loses to Metal
      expect(controller.currentComputerMove, HandMove.metal);
      expect(controller.lastWinner, RoundWinner.computer);
      expect(ai.currentMove, HandMove.metal);
      expect(ai.consecutiveLosses, 0);

      // Turn 2: Draw (Metal blocked) -> stays Metal, streak 0
      controller.playTurn(HandMove.metal);
      expect(controller.currentComputerMove, HandMove.metal);
      expect(controller.lastWinner, RoundWinner.draw);
      expect(ai.currentMove, HandMove.metal);
      expect(ai.consecutiveLosses, 0);

      // Turn 3: Metal Wizard loses (Fire beats Metal) -> shifts Metal -> Earth
      controller.playTurn(HandMove.fire);
      expect(controller.currentComputerMove, HandMove.metal);
      expect(controller.lastWinner, RoundWinner.user);
      expect(ai.currentMove, HandMove.earth);
      expect(ai.consecutiveLosses, 1);

      // Turn 4: Metal Wizard wins (Earth beats Fire) -> resets losses to 0, keeps Earth
      controller.playTurn(HandMove.fire);
      expect(controller.currentComputerMove, HandMove.earth);
      expect(controller.lastWinner, RoundWinner.computer);
      expect(ai.currentMove, HandMove.earth);
      expect(ai.consecutiveLosses, 0);

      // Turn 5: Metal Wizard loses (Wood beats Earth) -> shifts Earth -> Metal
      controller.playTurn(HandMove.wood);
      expect(controller.currentComputerMove, HandMove.earth);
      expect(controller.lastWinner, RoundWinner.user);
      expect(ai.currentMove, HandMove.metal);
      expect(ai.consecutiveLosses, 1);
    });

    test('Losing 3 consecutive times toggles Initial <-> Inverse Strategy (Win-Shift / Lose-Stay)', () async {
      final controller = await _createMetalWizardController();
      addTearDown(controller.dispose);
      final ai = controller.metalWizardAiState;

      // Loss 1 (Metal -> Earth, normal)
      controller.playTurn(HandMove.fire);
      expect(ai.currentMove, HandMove.earth);
      expect(ai.consecutiveLosses, 1);
      expect(ai.strategyMode, MetalWizardStrategyMode.normal);

      // Loss 2 (Earth -> Metal, normal)
      controller.playTurn(HandMove.wood);
      expect(ai.currentMove, HandMove.metal);
      expect(ai.consecutiveLosses, 2);
      expect(ai.strategyMode, MetalWizardStrategyMode.normal);

      // Loss 3: shifts Metal -> Earth, then toggles normal -> inverse!
      controller.playTurn(HandMove.fire);
      expect(ai.currentMove, HandMove.earth);
      expect(ai.consecutiveLosses, 3);
      expect(ai.strategyMode, MetalWizardStrategyMode.inverse);

      // Loss 4 in Inverse mode: Lose-Stay -> stays Earth!
      controller.playTurn(HandMove.wood);
      expect(controller.currentComputerMove, HandMove.earth);
      expect(ai.currentMove, HandMove.earth);
      expect(ai.consecutiveLosses, 4);
      expect(ai.strategyMode, MetalWizardStrategyMode.inverse);

      // Loss 5 in Inverse mode: Lose-Stay -> stays Earth!
      controller.playTurn(HandMove.wood);
      expect(controller.currentComputerMove, HandMove.earth);
      expect(ai.currentMove, HandMove.earth);
      expect(ai.consecutiveLosses, 5);
      expect(ai.strategyMode, MetalWizardStrategyMode.inverse);

      // Loss 6 in Inverse mode: Lose-Stay (stays Earth), then 6 % 3 == 0 -> toggles inverse -> normal!
      controller.playTurn(HandMove.wood);
      expect(controller.currentComputerMove, HandMove.earth);
      expect(ai.currentMove, HandMove.earth);
      expect(ai.consecutiveLosses, 6);
      expect(ai.strategyMode, MetalWizardStrategyMode.normal);

      // Test Win-Shift in Inverse mode:
      // Get to Inverse mode again (lose 3 times from streak 0)
      controller.playTurn(_losingMoveFor(ai.currentMove)); // Win resets losses to 0
      expect(ai.consecutiveLosses, 0);
      expect(ai.strategyMode, MetalWizardStrategyMode.normal);

      // 3 losses -> switches back to Inverse
      for (int i = 0; i < 3; i++) {
        controller.playTurn(_counterMoveFor(ai.currentMove));
      }
      expect(ai.strategyMode, MetalWizardStrategyMode.inverse);
      final moveBeforeInverseWin = ai.currentMove;

      // Metal Wizard wins in Inverse mode -> resets losses to 0 AND shifts element!
      controller.playTurn(_losingMoveFor(moveBeforeInverseWin));
      expect(controller.lastWinner, RoundWinner.computer);
      expect(ai.consecutiveLosses, 0);
      expect(ai.strategyMode, MetalWizardStrategyMode.inverse);
      expect(
        ai.currentMove,
        moveBeforeInverseWin == HandMove.metal
            ? HandMove.earth
            : HandMove.metal,
      );
    });

    test('10-loss triggers Sequence A (10 alternating casts -> Earth) then Sequence B (5 Metal / 5 Earth -> Metal) and loops cleanly', () async {
      final controller = await _createMetalWizardController();
      addTearDown(controller.dispose);
      final ai = controller.metalWizardAiState;

      // Trigger first 10 consecutive losses
      for (int i = 0; i < 10; i++) {
        controller.playTurn(_counterMoveFor(ai.currentMove));
      }

      expect(ai.consecutiveLosses, 10);
      expect(ai.tenLossStage, 1);
      expect(ai.nextMoveAfterScript, HandMove.earth);
      expect(ai.scriptedQueue, MetalWizardAiState.alternatingSequence);
      expect(ai.currentMove, HandMove.metal);

      // Execute all 10 scripted moves, deliberately mixing wins, losses, and draws!
      final observedSeqA = <HandMove>[];
      for (int i = 0; i < 10; i++) {
        final expected = i.isEven ? HandMove.metal : HandMove.earth;
        expect(ai.currentMove, expected);
        expect(controller.pcNextMoves, [expected]);
        expect(controller.crystalBallMoves, [expected]);

        // Mix outcomes: draw on 0/5, win for wizard on 1/6, loss for wizard otherwise
        if (i % 5 == 0) {
          controller.playTurn(_drawMoveFor(expected));
        } else if (i % 5 == 1) {
          controller.playTurn(_losingMoveFor(expected));
        } else {
          controller.playTurn(_counterMoveFor(expected));
        }
        observedSeqA.add(controller.currentComputerMove!);
      }

      expect(observedSeqA, MetalWizardAiState.alternatingSequence);
      expect(ai.scriptedQueue, isEmpty);
      expect(ai.strategyMode, MetalWizardStrategyMode.normal);
      expect(ai.currentMove, HandMove.earth);
      expect(ai.consecutiveLosses, 0);
      expect(ai.tenLossStage, 1);

      // Trigger second 10 consecutive losses -> Sequence B (5 Metal, 5 Earth)
      for (int i = 0; i < 10; i++) {
        controller.playTurn(_counterMoveFor(ai.currentMove));
      }

      expect(ai.consecutiveLosses, 10);
      expect(ai.tenLossStage, 0);
      expect(ai.nextMoveAfterScript, HandMove.metal);
      expect(ai.scriptedQueue, MetalWizardAiState.fiveMetalFiveEarthSequence);
      expect(ai.currentMove, HandMove.metal);

      final observedSeqB = <HandMove>[];
      for (int i = 0; i < 10; i++) {
        final expected = i < 5 ? HandMove.metal : HandMove.earth;
        expect(ai.currentMove, expected);

        // Mix outcomes again to prove scripted queue cannot be interrupted
        if (i == 2 || i == 7) {
          controller.playTurn(_losingMoveFor(expected));
        } else if (i == 4) {
          controller.playTurn(HandMove.metal); // Anti-Metal Shield block
        } else {
          controller.playTurn(_counterMoveFor(expected));
        }
        observedSeqB.add(controller.currentComputerMove!);
      }

      expect(observedSeqB, MetalWizardAiState.fiveMetalFiveEarthSequence);
      expect(ai.scriptedQueue, isEmpty);
      expect(ai.strategyMode, MetalWizardStrategyMode.normal);
      expect(ai.currentMove, HandMove.metal);
      expect(ai.consecutiveLosses, 0);
      expect(ai.tenLossStage, 0);

      // Verify loop back: another 10 consecutive losses runs Sequence A again!
      for (int i = 0; i < 10; i++) {
        controller.playTurn(_counterMoveFor(ai.currentMove));
      }
      expect(ai.tenLossStage, 1);
      expect(ai.scriptedQueue, MetalWizardAiState.alternatingSequence);
      expect(ai.nextMoveAfterScript, HandMove.earth);
    });

    test('Time-Loop Reset to Turn 0 and startNewBattle reset MetalWizardAiState completely', () async {
      final controller = await _createMetalWizardController();
      addTearDown(controller.dispose);

      // Advance into inverse mode with 4 consecutive losses
      for (int i = 0; i < 4; i++) {
        controller.playTurn(_counterMoveFor(controller.metalWizardAiState.currentMove));
      }
      expect(controller.metalWizardAiState.consecutiveLosses, 4);
      expect(
        controller.metalWizardAiState.strategyMode,
        MetalWizardStrategyMode.inverse,
      );

      // Rewind to Turn 0
      controller.resetGame();
      expect(controller.metalWizardAiState.currentMove, HandMove.metal);
      expect(
        controller.metalWizardAiState.strategyMode,
        MetalWizardStrategyMode.normal,
      );
      expect(controller.metalWizardAiState.consecutiveLosses, 0);
      expect(controller.metalWizardAiState.scriptedQueue, isEmpty);
      expect(controller.metalWizardAiState.tenLossStage, 0);
    });
  });

  group('Anti-Metal Shield, HintsBar, Show Algorithm & Bestiary', () {
    testWidgets(
      'Anti-Metal Shield negates Metal vs Metal and Metal vs Earth (0 damage, 1 Mana, Draw, streak unchanged) and never recommends Metal',
      (WidgetTester tester) async {
        final controller = await _createMetalWizardController();
        addTearDown(controller.dispose);

        // Verify hints on Turn 1 (Metal Wizard upcoming = Metal):
        expect(controller.pcNextMoves, [HandMove.metal]);
        expect(controller.crystalBallMoves, [HandMove.metal]);
        expect(controller.crystalBallPlusMoves, [HandMove.fire, HandMove.water]);
        expect(controller.suggestedMoves, [HandMove.fire, HandMove.water]);
        expect(controller.crystalBallPlusMoves, isNot(contains(HandMove.metal)));
        expect(controller.suggestedMoves, isNot(contains(HandMove.metal)));

        // Cast Metal vs Metal Wizard's Metal -> Anti-Metal Shield blocks it
        final manaBefore1 = controller.remainingMana;
        controller.playTurn(HandMove.metal);
        expect(controller.currentComputerMove, HandMove.metal);
        expect(controller.lastWinner, RoundWinner.draw);
        expect(controller.lastRoundBlockedByAntiMetalShield, isTrue);
        expect(controller.computerHp, 300);
        expect(controller.userHp, 50);
        expect(controller.remainingMana, manaBefore1 - 1);
        expect(controller.metalWizardAiState.consecutiveLosses, 0);
        expect(controller.metalWizardAiState.currentMove, HandMove.metal);

        // Beat Turn 1 Metal with Fire -> Metal Wizard loses 1 HP, shifts to Earth!
        controller.playTurn(HandMove.fire);
        expect(controller.computerHp, 299);
        expect(controller.metalWizardAiState.consecutiveLosses, 1);
        expect(controller.metalWizardAiState.currentMove, HandMove.earth);

        // Verify hints when upcoming move is Earth (even with Earth & Metal unlocked!):
        // Metal is NEVER recommended despite Metal normally beating Earth!
        expect(controller.pcNextMoves, [HandMove.earth]);
        expect(controller.crystalBallMoves, [HandMove.earth]);
        expect(controller.crystalBallPlusMoves, [HandMove.wood]);
        expect(controller.suggestedMoves, [HandMove.wood]);
        expect(controller.crystalBallPlusMoves, isNot(contains(HandMove.metal)));
        expect(controller.suggestedMoves, isNot(contains(HandMove.metal)));

        // Cast Metal vs Metal Wizard's Earth -> Anti-Metal Shield blocks it completely (0 damage to Wizard!)
        final manaBefore2 = controller.remainingMana;
        controller.playTurn(HandMove.metal);
        expect(controller.currentComputerMove, HandMove.earth);
        expect(controller.lastWinner, RoundWinner.draw);
        expect(controller.lastRoundBlockedByAntiMetalShield, isTrue);
        expect(controller.computerHp, 299);
        expect(controller.userHp, 50);
        expect(controller.remainingMana, manaBefore2 - 1);
        expect(controller.metalWizardAiState.consecutiveLosses, 1);
        expect(controller.metalWizardAiState.currentMove, HandMove.earth);

        // Render GameScreen and verify VersusArena displays the Anti-Metal Shield message
        // and HintsBar shows Earth + Wood (never Metal)
        await tester.pumpWidget(
          ChangeNotifierProvider<GameController>.value(
            value: controller,
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: const GameScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Anti-Metal Shield blocks Metal!'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(HintsBar),
            matching: find.byWidgetPredicate(
              (w) => w is ElementalSymbolIcon && w.move == HandMove.earth,
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(HintsBar),
            matching: find.byWidgetPredicate(
              (w) => w is ElementalSymbolIcon && w.move == HandMove.wood,
            ),
          ),
          findsNWidgets(2),
        );
        expect(
          find.descendant(
            of: find.byType(HintsBar),
            matching: find.byWidgetPredicate(
              (w) => w is ElementalSymbolIcon && w.move == HandMove.metal,
            ),
          ),
          findsNothing,
        );

        // Verify Show Algorithm (MarkovMatrixView) displays Initial Strategy, streak 1, and shield note
        expect(
          find.byKey(const ValueKey('markov_metal_wizard_banner')),
          findsOneWidget,
        );
        expect(
          find.text('Initial Strategy: Win-Stay / Lose-Shift'),
          findsOneWidget,
        );
        expect(find.text('Consecutive Losses: 1'), findsOneWidget);
        expect(
          find.text('Anti-Metal Shield: Blocks all Metal attacks (0 damage).'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Show Algorithm modal dynamically displays Inverse Strategy, 10-Turn Alternating Protocol, and 5-Metal / 5-Earth Barrage',
      (WidgetTester tester) async {
        final controller = await _createMetalWizardController();
        addTearDown(controller.dispose);

        Future<void> pumpAlgorithmCard() async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MarkovMatrixView(
                    engine: controller.engine,
                    lastUserMove: controller.lastUserMove,
                    elementalMode: true,
                    localization: controller.localization,
                    isMetalWizardView: true,
                    metalWizardAiState: controller.metalWizardAiState,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        // 1. Inverse Strategy after 3 consecutive losses
        for (int i = 0; i < 3; i++) {
          controller.playTurn(
            _counterMoveFor(controller.metalWizardAiState.currentMove),
          );
        }
        await pumpAlgorithmCard();
        expect(
          find.text('Inverse Strategy: Win-Shift / Lose-Stay'),
          findsOneWidget,
        );
        expect(find.text('Consecutive Losses: 3'), findsOneWidget);

        // 2. 10-Turn Alternating Protocol after 10 consecutive losses
        for (int i = 3; i < 10; i++) {
          controller.playTurn(
            _counterMoveFor(controller.metalWizardAiState.currentMove),
          );
        }
        await pumpAlgorithmCard();
        expect(find.text('10-Turn Alternating Protocol'), findsOneWidget);
        expect(find.text('Protocol Turns Left: 10'), findsOneWidget);

        // Finish all 10 alternating casts, then 10 consecutive losses -> 5-Metal / 5-Earth Barrage
        for (int i = 0; i < 10; i++) {
          controller.playTurn(
            _counterMoveFor(controller.metalWizardAiState.currentMove),
          );
        }
        for (int i = 0; i < 10; i++) {
          controller.playTurn(
            _counterMoveFor(controller.metalWizardAiState.currentMove),
          );
        }
        await pumpAlgorithmCard();
        expect(find.text('5-Metal / 5-Earth Barrage'), findsOneWidget);
        expect(find.text('Protocol Turns Left: 10'), findsOneWidget);
      },
    );

    testWidgets(
      'Arcane Bestiary displays updated Metal Wizard lore & model across en, pt, es, de',
      (WidgetTester tester) async {
        final controller = await _createMetalWizardController(
          prefs: {
            'encountered_bestiary': [BestiaryCreature.metalWizard.id],
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: RoyalCastleDialog(
                controller: controller,
                initialWing: CastleWing.library,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Adaptive Metal & Earth • Anti-Metal Shield'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Wields both Metal and Earth'),
          findsOneWidget,
        );
        expect(find.textContaining('Anti-Metal Shield'), findsWidgets);

        for (final lang in ['en', 'pt', 'es', 'de']) {
          controller.localization.setLanguage(lang);
          final lore = controller.localization.t(
            'castle_bestiary_metal_wizard_lore',
            fallback: '',
          );
          final model = controller.localization.t(
            'castle_bestiary_metal_wizard_model',
            fallback: '',
          );
          expect(lore, isNotEmpty, reason: 'Missing lore for $lang');
          expect(model, isNotEmpty, reason: 'Missing model for $lang');
          expect(lore.toLowerCase(), isNot(contains('100%')));
        }
      },
    );
  });
}
