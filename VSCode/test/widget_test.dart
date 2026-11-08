import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/views/widgets/versus_arena.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test loads GameScreen and displays diamonds in AppBar', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();

    final localization = LocalizationService();
    // No asset bundle in basic widget test, localization will use fallbacks

    final audio = AudioService();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GameController(
          storage: storage,
          localization: localization,
          audio: audio,
        ),
        child: const HowPredictableApp(),
      ),
    );

    expect(find.text('How Predictable You Are'), findsNothing);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('100000')), findsOneWidget);
    expect(find.text('ROCK'), findsOneWidget);
    expect(find.text('PAPER'), findsOneWidget);
    expect(find.text('SCISSORS'), findsOneWidget);

    final controller = tester.element(find.text('ROCK')).read<GameController>();
    expect(controller.turnCount, 0);

    // Tap ROCK and verify immediate response without waiting for button animation
    await tester.tap(find.text('ROCK'));
    await tester.pump();
    expect(controller.turnCount, 1);

    // Advance partway through the 1000ms animation (e.g., 250ms)
    await tester.pump(const Duration(milliseconds: 250));

    // Tap ROCK again mid-animation: should immediately increment turnCount and restart animation
    await tester.tap(find.text('ROCK'));
    await tester.pump();
    expect(controller.turnCount, 2);

    // Let the 1000ms animation complete
    await tester.pump(const Duration(milliseconds: 1100));
  });

  testWidgets('100-round alert dialog only offers TRY AGAIN option and resets game', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'userScore': 50,
      'pcScore': 50,
      'total': 100,
    });
    final storage = StorageService();
    await storage.init();

    final localization = LocalizationService();
    final audio = AudioService();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GameController(
          storage: storage,
          localization: localization,
          audio: audio,
        ),
        child: const HowPredictableApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('TRY AGAIN'), findsOneWidget);
    expect(find.text('CONTINUE'), findsNothing);

    await tester.tap(find.text('TRY AGAIN'));
    await tester.pumpAndSettle();

    final controller = tester.element(find.text('ROCK')).read<GameController>();
    expect(controller.totalRounds, 0);
    expect(controller.userScore, 0);
    expect(controller.pcScore, 0);
  });

  testWidgets('VersusArena animates 500ms forward, then simultaneous 500ms return and 500ms 360 rotation', (WidgetTester tester) async {
    final localization = LocalizationService();

    // Case 1: User wins (left hand moves right for 500ms, then moves back for 500ms while right hand rotates clockwise)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: VersusArena(
              userMove: HandMove.rock,
              computerMove: HandMove.scissors,
              winner: RoundWinner.user,
              localization: localization,
              animationsEnabled: true,
              roundId: 1,
            ),
          ),
        ),
      ),
    );

    // Start ticker frame at t = 0ms
    await tester.pump();

    // At 250ms (halfway into the 500ms forward phase): winning left hand is halfway over, beaten right hand has not rotated yet (angle == 0)
    await tester.pump(const Duration(milliseconds: 250));
    Transform userTranslateAt250ms = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('user_card')),
        matching: find.byType(Transform),
      ),
    );
    final dxAt250ms = userTranslateAt250ms.transform.getTranslation().x;

    Transform pcRotateAt250ms = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('pc_card')),
        matching: find.byType(Transform),
      ),
    );
    expect(pcRotateAt250ms.transform.storage[0], closeTo(1.0, 1e-3));
    expect(pcRotateAt250ms.transform.storage[1], closeTo(0.0, 1e-3));

    // At 500ms: winning left hand reaches right hand (full targetDistance), rotation is just starting (angle == 0)
    await tester.pump(const Duration(milliseconds: 250));
    Transform userTranslateAt500ms = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('user_card')),
        matching: find.byType(Transform),
      ),
    );
    final maxDx = userTranslateAt500ms.transform.getTranslation().x;
    expect(maxDx, greaterThan(100.0));
    expect(dxAt250ms, closeTo(maxDx * 0.5, 1e-2));

    // At 625ms (125ms = 25% into the 500ms backward + rotation phase):
    // Right hand should be at +90 degrees (+pi/2 clockwise: cos=0, sin=+1)
    // Left hand should be at 75% of maxDx moving back
    await tester.pump(const Duration(milliseconds: 125));
    Transform userTranslateAt625ms = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('user_card')),
        matching: find.byType(Transform),
      ),
    );
    expect(userTranslateAt625ms.transform.getTranslation().x, closeTo(maxDx * 0.75, 1e-2));

    Transform pcRotateAt625ms = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('pc_card')),
        matching: find.byType(Transform),
      ),
    );
    // For +pi/2 (clockwise), Matrix4.rotationZ(+pi/2) has storage[0] = cos(pi/2) = 0, storage[1] = sin(pi/2) = +1
    expect(pcRotateAt625ms.transform.storage[0], closeTo(math.cos(math.pi / 2), 1e-2));
    expect(pcRotateAt625ms.transform.storage[1], closeTo(math.sin(math.pi / 2), 1e-2));

    // Finish the 1000ms animation
    await tester.pump(const Duration(milliseconds: 375));

    // Case 2: PC wins (right hand moves left for 500ms, then moves back for 500ms while left hand rotates anti-clockwise)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: VersusArena(
              userMove: HandMove.scissors,
              computerMove: HandMove.rock,
              winner: RoundWinner.computer,
              localization: localization,
              animationsEnabled: true,
              roundId: 2,
            ),
          ),
        ),
      ),
    );

    // Start ticker frame at t = 0ms
    await tester.pump();

    // Advance to 625ms (25% into the 500ms backward + rotation phase):
    // Left hand is beaten and should be at -90 degrees (-pi/2 anti-clockwise: cos=0, sin=-1)
    await tester.pump(const Duration(milliseconds: 625));
    Transform userRotateAt625ms = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('user_card')),
        matching: find.byType(Transform),
      ),
    );
    expect(userRotateAt625ms.transform.storage[0], closeTo(math.cos(-math.pi / 2), 1e-2));
    expect(userRotateAt625ms.transform.storage[1], closeTo(math.sin(-math.pi / 2), 1e-2));

    await tester.pump(const Duration(milliseconds: 375));
  });

  testWidgets('HintsBar displays Random when Markov row is empty and shows all tied moves on tie', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'unlockedYourPrediction': true,
      'unlockedNextMove': true,
      'unlockedSuggestion': true,
      'showYourPrediction': true,
      'showNextMove': true,
      'showSuggestion': true,
      'animationsEnabled': false,
    });
    final storage = StorageService();
    await storage.init();
    final localization = LocalizationService();
    final audio = AudioService();

    final controller = GameController(
      storage: storage,
      localization: localization,
      audio: audio,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const HowPredictableApp(),
      ),
    );

    // Initially, Markov matrix is empty -> all three hint chips show 'Random'
    expect(find.text('Random'), findsNWidgets(3));

    // After 1st turn (Rock), no transition recorded yet -> still 'Random'
    controller.playTurn(HandMove.rock);
    await tester.pump();
    expect(find.text('Random'), findsNWidgets(3));

    // 2nd turn: Rock -> Paper recorded; lastUserMove is now Paper (row for Paper is still empty -> 'Random')
    controller.playTurn(HandMove.paper);
    await tester.pump();
    expect(find.text('Random'), findsNWidgets(3));

    // 3rd turn: Paper -> Rock recorded; lastUserMove is now Rock (row for Rock has Paper=1)
    // Now HintsBar should show: Probably: ✋, PC: ✌, Suggestion: ✊
    controller.playTurn(HandMove.rock);
    await tester.pump();
    expect(controller.predictedUserMoves, [HandMove.paper]);
    expect(controller.pcNextMoves, [HandMove.scissors]);
    expect(controller.suggestedMoves, [HandMove.rock]);

    // 4th turn: Rock -> Scissors recorded; now Rock has a tie: Paper=1, Scissors=1
    // Play Rock again on 5th turn so lastUserMove is Rock with tied transitions
    controller.playTurn(HandMove.scissors);
    controller.playTurn(HandMove.rock);
    await tester.pump();

    expect(controller.predictedUserMoves, [HandMove.paper, HandMove.scissors]);
    expect(controller.pcNextMoves, [HandMove.scissors, HandMove.rock]);
    expect(controller.suggestedMoves, [HandMove.rock, HandMove.paper]);
    expect(find.text('✋ ✌'), findsOneWidget);
    expect(find.text('✌ ✊'), findsOneWidget);
    expect(find.text('✊ ✋'), findsOneWidget);
  });

  testWidgets('Crystal Ball displays exact pre-selected PC move even when Markov table is empty (Random)', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'unlockedCrystalBall': true,
      'showCrystalBall': true,
      'animationsEnabled': false,
    });
    final storage = StorageService();
    await storage.init();
    final localization = LocalizationService();
    final audio = AudioService();

    final controller = GameController(
      storage: storage,
      localization: localization,
      audio: audio,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const HowPredictableApp(),
      ),
    );

    // Before first move, Markov table is empty, yet Crystal Ball already predicts the exact random PC move
    final predictedBeforeTurn = controller.crystalBallMove;
    expect(predictedBeforeTurn, isNotNull);
    expect(find.text('Crystal Ball:'), findsOneWidget);
    expect(find.text(predictedBeforeTurn!.emoji), findsWidgets);

    // When the user plays a hand, the PC plays the exact move shown in the Crystal Ball
    await tester.tap(find.text('ROCK'));
    await tester.pump();
    expect(controller.currentComputerMove, equals(predictedBeforeTurn));
  });

  testWidgets('Crystal Ball+ store visibility, costs, activation dependency, state restoration, and single main screen display', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'diamonds': 100000,
      'animationsEnabled': false,
    });
    final storage = StorageService();
    await storage.init();
    final localization = LocalizationService();
    final audio = AudioService();

    final controller = GameController(
      storage: storage,
      localization: localization,
      audio: audio,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const HowPredictableApp(),
      ),
    );

    // Open Shop dialog
    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();

    // Scroll down in Shop list to Crystal Ball
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // Before acquiring Crystal Ball: Crystal Ball costs 20000 and Crystal Ball+ is not shown
    expect(find.text('Crystal Ball'), findsOneWidget);
    expect(find.text('20000 💎'), findsOneWidget);
    expect(find.text('Crystal Ball+'), findsNothing);

    // Unlock Crystal Ball (cost: 20000 -> diamonds: 80000)
    expect(controller.unlockCrystalBall(), isTrue);
    expect(controller.diamonds, 80000);
    expect(controller.unlockedCrystalBall, isTrue);
    expect(controller.showCrystalBall, isTrue);
    await tester.pumpAndSettle();

    // After acquiring Crystal Ball: Crystal Ball+ is displayed in the store with cost 50000
    expect(find.text('Crystal Ball+'), findsOneWidget);
    expect(find.text('50000 💎'), findsOneWidget);

    // Unlock Crystal Ball+ (cost: 50000 -> diamonds: 30000)
    expect(controller.unlockCrystalBallPlus(), isTrue);
    expect(controller.diamonds, 30000);
    expect(controller.unlockedCrystalBallPlus, isTrue);
    expect(controller.showCrystalBallPlus, isTrue);
    await tester.pumpAndSettle();

    // Close Shop dialog and verify main screen shows ONLY ONE crystal ball (Crystal Ball+ result)
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Crystal Ball:'), findsNothing);
    expect(find.text('Crystal Ball+:'), findsOneWidget);

    final winningMove = controller.crystalBallPlusMove!;
    final pcMove = controller.crystalBallMove!;
    expect(winningMove.beats(pcMove), isTrue);

    // Playing the hand shown by Crystal Ball+ beats the PC
    controller.playTurn(winningMove);
    await tester.pump();
    expect(controller.lastWinner, RoundWinner.user);

    // Disable Crystal Ball -> Crystal Ball+ is also deactivated
    controller.toggleShowCrystalBall(false);
    await tester.pump();
    expect(controller.showCrystalBall, isFalse);
    expect(controller.showCrystalBallPlus, isFalse);
    expect(find.text('Crystal Ball:'), findsNothing);
    expect(find.text('Crystal Ball+:'), findsNothing);

    // Crystal Ball+ cannot be activated while Crystal Ball is disabled
    controller.toggleShowCrystalBallPlus(true);
    await tester.pump();
    expect(controller.showCrystalBallPlus, isFalse);

    // Re-enabling Crystal Ball restores Crystal Ball+ to enabled (since it was enabled before)
    controller.toggleShowCrystalBall(true);
    await tester.pump();
    expect(controller.showCrystalBall, isTrue);
    expect(controller.showCrystalBallPlus, isTrue);
    expect(find.text('Crystal Ball+:'), findsOneWidget);
    expect(find.text('Crystal Ball:'), findsNothing);

    // Now disable Crystal Ball+ while Crystal Ball is enabled -> main screen shows Crystal Ball (PC next move)
    controller.toggleShowCrystalBallPlus(false);
    await tester.pump();
    expect(controller.showCrystalBall, isTrue);
    expect(controller.showCrystalBallPlus, isFalse);
    expect(find.text('Crystal Ball:'), findsOneWidget);
    expect(find.text('Crystal Ball+:'), findsNothing);

    // Disable Crystal Ball and then re-enable it -> Crystal Ball+ remains disabled
    controller.toggleShowCrystalBall(false);
    expect(controller.showCrystalBall, isFalse);
    expect(controller.showCrystalBallPlus, isFalse);

    controller.toggleShowCrystalBall(true);
    await tester.pump();
    expect(controller.showCrystalBall, isTrue);
    expect(controller.showCrystalBallPlus, isFalse);
    expect(find.text('Crystal Ball:'), findsOneWidget);
    expect(find.text('Crystal Ball+:'), findsNothing);
  });
}
