import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/views/dialogs/inventory_dialog.dart';
import 'package:how_predictable/views/dialogs/settings_dialog.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';
import 'package:how_predictable/views/widgets/hints_bar.dart';
import 'package:how_predictable/views/widgets/markov_matrix_view.dart';
import 'package:how_predictable/views/widgets/score_header.dart';
import 'package:how_predictable/views/widgets/versus_arena.dart';
import 'package:how_predictable/views/widgets/rpg_backpack_icon.dart';
import 'package:how_predictable/views/widgets/rpg_teleport_portal_icon.dart';
import 'package:how_predictable/views/widgets/adaptive_rewarded_ad_button.dart';
import 'package:how_predictable/views/screens/game_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test launches onto WorldMapScreen with bottom-left HUD and enters GameScreen via Metal Wizard\'s Lair', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'animationsEnabled': false,
    });
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
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('world_map_screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('world_map_bottom_left_hud')), findsOneWidget);
    expect(find.byKey(const ValueKey('week_counter_badge')), findsOneWidget);
    expect(find.text('Week 1 / 40'), findsOneWidget);
    expect(find.byKey(const ValueKey('backpack_inventory_button')), findsOneWidget);

    // Enter 100-round battle by tapping Metal Wizard's Lair
    await tester.tap(find.byKey(const ValueKey('landmark_metal_wizard_lair')));
    await tester.pumpAndSettle();

    expect(find.text('How Predictable You Are'), findsNothing);
    expect(find.byKey(const ValueKey('game_retreat_button')), findsNothing);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byKey(const ValueKey('teleport_portal_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('backpack_inventory_button')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(RpgBackpackIcon),
      ),
      findsOneWidget,
    );
    expect(find.text('FIRE'), findsOneWidget);
    expect(find.text('WATER'), findsOneWidget);
    expect(find.text('WOOD'), findsOneWidget);

    final controller = tester.element(find.byKey(const ValueKey('hand_button_rock'))).read<GameController>();
    expect(controller.turnCount, 0);

    // Tap FIRE and verify immediate response without waiting for button animation
    await tester.tap(find.text('FIRE').last);
    await tester.pump();
    expect(controller.turnCount, 1);

    // Advance partway through the 1000ms animation (e.g., 250ms)
    await tester.pump(const Duration(milliseconds: 250));

    // Tap FIRE again mid-animation: should immediately increment turnCount and restart animation
    await tester.tap(find.text('FIRE').last);
    await tester.pump();
    expect(controller.turnCount, 2);

    // Let the 1000ms animation complete
    await tester.pump(const Duration(milliseconds: 1100));
  });

  testWidgets('100-round alert dialog offers Return to Map option, advances week, and resets battle', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'userScore': 50,
      'pcScore': 20,
      'total': 100,
      'animationsEnabled': false,
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
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('battle_return_to_map_button')),
      findsOneWidget,
    );
    expect(find.text('Return to Map'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsNothing);
    expect(find.text('CONTINUE'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('battle_return_to_map_button')));
    await tester.pumpAndSettle();

    final controller = tester.element(find.byKey(const ValueKey('hand_button_rock'))).read<GameController>();
    expect(controller.totalRounds, 0);
    expect(controller.userScore, 0);
    expect(controller.pcScore, 0);
    expect(controller.currentWeek, 2);
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

  testWidgets('VersusArena maintains fixed height and displays outcome text across Idle, Win, Loss, and Draw states', (WidgetTester tester) async {
    final localization = LocalizationService();
    await localization.load();

    Future<double> pumpAndMeasureArena({
      required HandMove? userMove,
      required HandMove? computerMove,
      required RoundWinner? winner,
      required int roundId,
      required bool elementalMode,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: VersusArena(
                userMove: userMove,
                computerMove: computerMove,
                winner: winner,
                localization: localization,
                animationsEnabled: false,
                roundId: roundId,
                elementalMode: elementalMode,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final renderBox = tester.renderObject(find.byType(VersusArena)) as RenderBox;
      return renderBox.size.height;
    }

    // 1. Elemental Mode tests
    // Idle state
    final idleHeight = await pumpAndMeasureArena(
      userMove: null,
      computerMove: null,
      winner: null,
      roundId: 0,
      elementalMode: true,
    );
    expect(find.byKey(const ValueKey('battle_outcome_description')), findsOneWidget);
    expect(find.text('Choose an element to attack!'), findsOneWidget);

    // Win state
    final winHeight = await pumpAndMeasureArena(
      userMove: HandMove.rock,
      computerMove: HandMove.scissors,
      winner: RoundWinner.user,
      roundId: 1,
      elementalMode: true,
    );
    expect(find.text('Fire burns Wood'), findsOneWidget);

    // Loss state
    final lossHeight = await pumpAndMeasureArena(
      userMove: HandMove.scissors,
      computerMove: HandMove.rock,
      winner: RoundWinner.computer,
      roundId: 2,
      elementalMode: true,
    );
    expect(find.text('Fire burns Wood'), findsOneWidget);

    // Draw state
    final drawHeight = await pumpAndMeasureArena(
      userMove: HandMove.rock,
      computerMove: HandMove.rock,
      winner: RoundWinner.draw,
      roundId: 3,
      elementalMode: true,
    );
    expect(find.text("It's a Draw! Elements neutralized."), findsOneWidget);

    // Exact height equality across all elemental states
    expect(winHeight, equals(idleHeight));
    expect(lossHeight, equals(idleHeight));
    expect(drawHeight, equals(idleHeight));

    // 2. Classic Mode tests
    final classicIdleHeight = await pumpAndMeasureArena(
      userMove: null,
      computerMove: null,
      winner: null,
      roundId: 0,
      elementalMode: false,
    );
    expect(find.text('Choose a move to battle!'), findsOneWidget);

    final classicWinHeight = await pumpAndMeasureArena(
      userMove: HandMove.rock,
      computerMove: HandMove.scissors,
      winner: RoundWinner.user,
      roundId: 1,
      elementalMode: false,
    );
    expect(find.text('Rock crushes Scissors'), findsOneWidget);

    final classicDrawHeight = await pumpAndMeasureArena(
      userMove: HandMove.paper,
      computerMove: HandMove.paper,
      winner: RoundWinner.draw,
      roundId: 2,
      elementalMode: false,
    );
    expect(find.text("It's a Draw! Moves neutralized."), findsOneWidget);

    // Exact height equality in classic mode and matches elemental mode
    expect(classicWinHeight, equals(classicIdleHeight));
    expect(classicDrawHeight, equals(classicIdleHeight));
    expect(classicIdleHeight, equals(idleHeight));

    // 3. Multi-language Draw and Idle outcome text tests
    // Portuguese
    localization.setLanguage('pt');
    await pumpAndMeasureArena(
      userMove: HandMove.rock,
      computerMove: HandMove.rock,
      winner: RoundWinner.draw,
      roundId: 4,
      elementalMode: true,
    );
    expect(find.text('É um Empate! Elementos neutralizados.'), findsOneWidget);

    await pumpAndMeasureArena(
      userMove: null,
      computerMove: null,
      winner: null,
      roundId: 0,
      elementalMode: true,
    );
    expect(find.text('Escolha um elemento para atacar!'), findsOneWidget);

    // Spanish
    localization.setLanguage('es');
    await pumpAndMeasureArena(
      userMove: HandMove.rock,
      computerMove: HandMove.rock,
      winner: RoundWinner.draw,
      roundId: 5,
      elementalMode: true,
    );
    expect(find.text('¡Es un Empate! Elementos neutralizados.'), findsOneWidget);

    await pumpAndMeasureArena(
      userMove: null,
      computerMove: null,
      winner: null,
      roundId: 0,
      elementalMode: true,
    );
    expect(find.text('¡Elige un elemento para atacar!'), findsOneWidget);

    // German
    localization.setLanguage('de');
    await pumpAndMeasureArena(
      userMove: HandMove.rock,
      computerMove: HandMove.rock,
      winner: RoundWinner.draw,
      roundId: 6,
      elementalMode: true,
    );
    expect(find.text('Unentschieden! Elemente neutralisiert.'), findsOneWidget);

    await pumpAndMeasureArena(
      userMove: null,
      computerMove: null,
      winner: null,
      roundId: 0,
      elementalMode: true,
    );
    expect(find.text('Wähle ein Element zum Angriff!'), findsOneWidget);
  });

  testWidgets('HintsBar displays ? when Markov row is empty and shows all tied moves on tie', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'unlockedReset': true,
      'showReset': true,
      'unlockedYourPrediction': true,
      'unlockedNextMove': true,
      'unlockedSuggestion': true,
      'showYourPrediction': true,
      'showNextMove': true,
      'showSuggestion': true,
      'unlockedNewSkin': true,
      'showNewSkin': true,
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
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );

    // Verify updated labels and single AppBar reset button
    expect(find.text('Your Choice:'), findsOneWidget);
    expect(find.text("PC's Choice:"), findsOneWidget);
    expect(find.text('Suggestion:'), findsOneWidget);
    expect(find.text('You will Chose:'), findsNothing);
    expect(find.text('PC will Chose:'), findsNothing);
    expect(find.text('Sugestion:'), findsNothing);
    expect(find.text('PC Chose:'), findsOneWidget);
    expect(find.text('PC Chose'), findsNothing);
    expect(find.text('The winner of this round:'), findsNothing);
    expect(find.text('The winner of this round::'), findsNothing);
    expect(find.byIcon(Icons.restart_alt), findsOneWidget);
    expect(find.byKey(const ValueKey('appbar_story_gallery_button')), findsNothing);

    // Verify that "Your Choice:" and "PC's Choice:" are rendered side-by-side on a single row
    final yourChoiceY = tester.getTopLeft(find.text('Your Choice:')).dy;
    final pcChoiceY = tester.getTopLeft(find.text("PC's Choice:")).dy;
    final suggestionY = tester.getTopLeft(find.text('Suggestion:')).dy;
    expect(yourChoiceY, equals(pcChoiceY));
    expect(suggestionY, greaterThan(yourChoiceY));

    // Initially, Markov matrix is empty -> all three hint chips show '?'
    expect(
      find.descendant(of: find.byType(HintsBar), matching: find.text('?')),
      findsNWidgets(3),
    );

    // After 1st turn (Rock), no transition recorded yet -> still '?'
    controller.playTurn(HandMove.rock);
    await tester.pump();
    expect(
      find.descendant(of: find.byType(HintsBar), matching: find.text('?')),
      findsNWidgets(3),
    );

    // 2nd turn: Rock -> Paper recorded; lastUserMove is now Paper (row for Paper is still empty -> '?')
    controller.playTurn(HandMove.paper);
    await tester.pump();
    expect(
      find.descendant(of: find.byType(HintsBar), matching: find.text('?')),
      findsNWidgets(3),
    );

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

    // 6th turn: Rock -> Rock recorded; now all 3 hands are tied for Rock (Rock=1, Paper=1, Scissors=1)
    // HintsBar must substitute '?' instead of showing all 3 hands
    controller.playTurn(HandMove.rock);
    await tester.pump();

    expect(controller.predictedUserMoves, isEmpty);
    expect(controller.pcNextMoves, isEmpty);
    expect(controller.suggestedMoves, isEmpty);
    expect(
      find.descendant(of: find.byType(HintsBar), matching: find.text('?')),
      findsNWidgets(3),
    );
  });

  testWidgets('Crystal Ball displays exact pre-selected PC move even when Markov table is empty (Random)', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
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
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );

    // Before first move, Markov table is empty, yet Crystal Ball already predicts the exact random PC move
    final predictedBeforeTurn = controller.crystalBallMove;
    expect(predictedBeforeTurn, isNotNull);
    expect(find.text('Crystal Ball:'), findsOneWidget);
    // Helpers display only symbols (icons) and no element name texts
    expect(
      find.descendant(
        of: find.byType(HintsBar),
        matching: find.text(predictedBeforeTurn!.displayLabel(elemental: true, localization: localization)),
      ),
      findsNothing,
    );
    expect(find.byIcon(predictedBeforeTurn.elementalIcon), findsWidgets);

    // When the user plays a hand, the PC plays the exact move shown in the Crystal Ball
    await tester.tap(find.byKey(const ValueKey('hand_button_rock')));
    await tester.pump();
    expect(controller.currentComputerMove, equals(predictedBeforeTurn));
  });

  testWidgets('Crystal Ball+ store visibility, costs, activation dependency, state restoration, and single main screen display', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'orbs_fire': 100000,
      'orbs_water': 100000,
      'orbs_wood': 100000,
      'orbs_earth': 100000,
      'orbs_metal': 100000,
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
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );

    // Open Shop dialog
    await tester.tap(find.byKey(const ValueKey('backpack_inventory_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory_open_shop_button')));
    await tester.pumpAndSettle();

    // Scroll down in Shop list to Crystal Ball
    final shopScrollable = find.descendant(
      of: find.byType(ShopDialog),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Crystal Ball'),
      250,
      scrollable: shopScrollable,
    );
    await tester.pumpAndSettle();

    // Before acquiring Crystal Ball: Crystal Ball costs 3500 Fire/Water/Wood + 2500 Earth/Metal and Crystal Ball+ is not shown
    expect(find.text('Crystal Ball'), findsOneWidget);
    expect(find.text('3500'), findsNWidgets(3));
    expect(find.text('2500'), findsNWidgets(2));
    expect(find.text('Crystal Ball+'), findsNothing);

    // Unlock Crystal Ball; remains disabled on purchase
    expect(controller.unlockCrystalBall(), isTrue);
    expect(controller.fireOrbs, 96500);
    expect(controller.earthOrbs, 97500);
    expect(controller.unlockedCrystalBall, isTrue);
    expect(controller.showCrystalBall, isFalse);
    await tester.pumpAndSettle();

    // User enables Crystal Ball
    controller.toggleShowCrystalBall(true);
    expect(controller.showCrystalBall, isTrue);
    await tester.pumpAndSettle();

    // Scroll down further to reveal the newly added Crystal Ball+ tile in the ListView
    await tester.scrollUntilVisible(
      find.text('Crystal Ball+'),
      250,
      scrollable: shopScrollable,
    );
    await tester.pumpAndSettle();

    // After acquiring Crystal Ball: Crystal Ball+ is displayed in the store
    expect(find.text('Crystal Ball+'), findsOneWidget);
    expect(find.text('5000'), findsNWidgets(5));

    // Unlock Crystal Ball+; remains disabled on purchase
    expect(controller.unlockCrystalBallPlus(), isTrue);
    expect(controller.fireOrbs, 91500);
    expect(controller.earthOrbs, 92500);
    expect(controller.unlockedCrystalBallPlus, isTrue);
    expect(controller.showCrystalBallPlus, isFalse);
    await tester.pumpAndSettle();

    // User enables Crystal Ball+
    controller.toggleShowCrystalBallPlus(true);
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

  testWidgets('Attempting to purchase an item without enough Elemental Orbs only shows notification and gives no free orbs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'orbs_fire': 10,
      'orbs_water': 10,
      'orbs_wood': 10,
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
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );

    // Open Shop dialog
    await tester.tap(find.byKey(const ValueKey('backpack_inventory_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory_open_shop_button')));
    await tester.pumpAndSettle();

    // Attempt to unlock Predictability Score (cost: 15 Fire + 15 Water + 15 Wood) with only 10 of each
    final predUnlockBtn = find.byKey(
      const ValueKey('diamond_unlock_unlock_predictability_score'),
    );
    final shopScrollable = find.descendant(
      of: find.byType(ShopDialog),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      predUnlockBtn,
      120,
      scrollable: shopScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(predUnlockBtn);
    await tester.pump();

    expect(find.text('Not enough Elemental Orbs'), findsOneWidget);
    expect(find.byType(SnackBarAction), findsNothing);
    expect(controller.fireOrbs, 10);
    expect(controller.unlockedPredictability, isFalse);
  });

  testWidgets('Intro comic cutscene opens automatically on first launch, advances panels, and persists has_seen_story_intro', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
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
    await tester.pumpAndSettle();

    // Intro comic cutscene should be open automatically
    expect(find.text("Prologue: The Master Hand's Shadow"), findsOneWidget);
    expect(find.text('Panel 1 / 4'), findsOneWidget);
    expect(storage.hasSeenStoryIntro, isTrue);

    // No speech bubbles over the comic image; only the dialogue text box below
    expect(find.byKey(const ValueKey('comic_bubble_0')), findsNothing);
    expect(find.byKey(const ValueKey('story_active_dialogue_text')), findsOneWidget);

    // Back button with left arrow is at the left side of the Next button
    final backBtnFinder = find.byKey(const ValueKey('story_back_button'));
    final nextBtnFinder = find.byKey(const ValueKey('story_next_button'));
    expect(backBtnFinder, findsOneWidget);
    expect(nextBtnFinder, findsOneWidget);
    expect(
      find.descendant(of: backBtnFinder, matching: find.byIcon(Icons.arrow_back_rounded)),
      findsOneWidget,
    );
    expect(
      tester.getCenter(backBtnFinder).dx,
      lessThan(tester.getCenter(nextBtnFinder).dx),
    );

    // Slide finger to the left on dialogue box -> moves forward to Panel 2
    await tester.drag(find.byKey(const ValueKey('story_dialogue_box')), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(find.text('Panel 2 / 4'), findsOneWidget);

    // Slide finger to the right on dialogue box -> rewinds to Panel 1
    await tester.drag(find.byKey(const ValueKey('story_dialogue_box')), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(find.text('Panel 1 / 4'), findsOneWidget);

    // Tap Next to Panel 2, then tap Back button -> rewinds to Panel 1
    await tester.tap(nextBtnFinder);
    await tester.pumpAndSettle();
    expect(find.text('Panel 2 / 4'), findsOneWidget);

    await tester.tap(backBtnFinder);
    await tester.pumpAndSettle();
    expect(find.text('Panel 1 / 4'), findsOneWidget);

    // Tap Next through panels 2, 3, 4
    await tester.tap(nextBtnFinder);
    await tester.pumpAndSettle();
    expect(find.text('Panel 2 / 4'), findsOneWidget);

    await tester.tap(nextBtnFinder);
    await tester.pumpAndSettle();
    expect(find.text('Panel 3 / 4'), findsOneWidget);

    await tester.tap(nextBtnFinder);
    await tester.pumpAndSettle();
    expect(find.text('Panel 4 / 4'), findsOneWidget);

    // Final tap on Continue closes the cutscene
    await tester.tap(nextBtnFinder);
    await tester.pumpAndSettle();
    expect(find.text("Prologue: The Master Hand's Shadow"), findsNothing);
  });

  testWidgets('Resetting all progress from SettingsDialog closes settings, archives orbs to Spoils of War, resets to Week 0, and triggers Castle badge', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'orbs_fire': 500,
      'total': 15,
      'current_week': 4,
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
    await tester.pumpAndSettle();

    expect(controller.fireOrbs, 500);
    expect(find.text('Week 4 / 40'), findsOneWidget);

    // Open SettingsDialog
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    final resetBtn = find.byKey(
      const ValueKey('settings_reset_progress_button'),
    );
    await tester.ensureVisible(resetBtn);
    await tester.tap(resetBtn);
    await tester.pumpAndSettle();

    // Confirmation dialog appears with updated Castle recovery explanation
    expect(find.text('Reset All Progress?'), findsOneWidget);
    expect(find.textContaining('Week 0'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Royal Castle'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm_reset_progress_button')),
    );
    await tester.pumpAndSettle();

    // Settings dialog is dismissed, hero returns to Week 0 on WorldMapScreen with archived Spoils
    expect(find.byType(SettingsDialog), findsNothing);
    expect(controller.totalOrbs, 0);
    expect(controller.totalRounds, 0);
    expect(controller.currentWeek, 0);
    expect(controller.spoilsFireOrbs, 500);
    expect(controller.hasRoyalCastleNotification, isTrue);
    expect(storage.hasSeenStoryIntro, isTrue);
    expect(find.text('Week 0 / 40'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('royal_castle_notification_badge')),
      findsOneWidget,
    );
    expect(find.text("Prologue: The Master Hand's Shadow"), findsNothing);
  });

  testWidgets('Unlocking an item in ShopDialog triggers its comic cutscene once and Story Gallery allows re-reading unlocked chapters', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'orbs_fire': 1000,
      'orbs_water': 1000,
      'orbs_wood': 1000,
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
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );

    // Open ShopDialog and unlock Reset Button
    await tester.tap(find.byKey(const ValueKey('backpack_inventory_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory_open_shop_button')));
    await tester.pumpAndSettle();

    final resetUnlockBtn = find.byKey(
      const ValueKey('diamond_unlock_unlock_reset_button'),
    );
    final shopScrollable = find.descendant(
      of: find.byType(ShopDialog),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      resetUnlockBtn,
      140,
      scrollable: shopScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(resetUnlockBtn);
    await tester.pumpAndSettle();

    // Reset Button comic cutscene should open immediately
    expect(find.text('Chapter I: The Hourglass of Oblivion'), findsOneWidget);
    expect(storage.hasSeenStoryReset, isTrue);

    // Skip the cutscene
    await tester.tap(find.byKey(const ValueKey('story_skip_button')));
    await tester.pumpAndSettle();
    expect(find.text('Chapter I: The Hourglass of Oblivion'), findsNothing);

    // Toggling the Reset switch off and on in the shop should NOT re-trigger the comic
    final resetSwitch = find.byType(Switch).first;
    await tester.ensureVisible(resetSwitch);
    await tester.pumpAndSettle();
    await tester.tap(resetSwitch);
    await tester.pumpAndSettle();
    expect(find.text('Chapter I: The Hourglass of Oblivion'), findsNothing);

    await tester.tap(resetSwitch);
    await tester.pumpAndSettle();
    expect(find.text('Chapter I: The Hourglass of Oblivion'), findsNothing);

    // Close ShopDialog
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Open SettingsDialog and open Story Memories gallery
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    final storyMemoriesBtn = find.byKey(
      const ValueKey('settings_story_memories_button'),
    );
    expect(storyMemoriesBtn, findsOneWidget);
    await tester.ensureVisible(storyMemoriesBtn);
    await tester.pumpAndSettle();
    await tester.tap(storyMemoriesBtn);
    await tester.pumpAndSettle();

    // Prologue and Reset Button chapters are unlocked (2 / 9), while Predictability Score is still locked
    expect(find.text('2 / 9'), findsOneWidget);
    expect(find.byKey(const ValueKey('story_gallery_item_intro')), findsOneWidget);
    expect(find.byKey(const ValueKey('story_gallery_item_reset')), findsOneWidget);
    expect(find.byKey(const ValueKey('story_gallery_locked_predictability')), findsOneWidget);

    // Verify Story Memories layout: chapter name is above thumbnail and read button,
    // and thumbnail and read button are in the same horizontal line
    final introTitleFinder = find.text("Prologue: The Master Hand's Shadow");
    final introThumbFinder = find.byKey(const ValueKey('story_gallery_thumb_intro'));
    final introReadBtnFinder = find.byKey(const ValueKey('story_gallery_read_btn_intro'));
    expect(
      tester.getBottomLeft(introTitleFinder).dy,
      lessThan(tester.getTopLeft(introThumbFinder).dy),
    );
    expect(
      tester.getCenter(introThumbFinder).dy,
      equals(tester.getCenter(introReadBtnFinder).dy),
    );

    // Tap the unlocked Reset chapter in Story Gallery to replay its comic
    await tester.tap(find.byKey(const ValueKey('story_gallery_item_reset')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('story_skip_button')), findsOneWidget);
    expect(find.text('Panel 1 / 4'), findsOneWidget);
  });

  testWidgets('ScoreHeader is completely hidden by default and when disabled, and reveals all 4 metrics with semantic RPG gauge colors when unlocked and enabled', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'unlockedPredictability': false,
      'showPredictability': false,
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
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );

    // 1. Default / Locked State: Entire ScoreHeader is hidden (no You, PC, Total, or Gauge)
    expect(find.byType(ScoreHeader), findsNothing);
    expect(find.text('You'), findsNothing);
    expect(find.text('Your Score:'), findsNothing);
    expect(find.text('Total'), findsNothing);
    expect(find.text('Total:'), findsNothing);
    expect(find.text('Gauge'), findsNothing);

    // Background tracking continues while hidden
    controller.crystalBallMove = HandMove.scissors;
    controller.playTurn(HandMove.rock); // User win (1-0)
    await tester.pump();
    expect(controller.userScore, 1);
    expect(controller.totalRounds, 1);
    expect(find.byType(ScoreHeader), findsNothing);

    // 2. Unlocked but Disabled State: Entire ScoreHeader remains hidden
    controller.addAllOrbs(50);
    expect(controller.unlockPredictability(), isTrue);
    expect(controller.unlockedPredictability, isTrue);
    expect(controller.showPredictability, isFalse);
    await tester.pump();
    expect(find.byType(ScoreHeader), findsNothing);
    expect(find.text('You'), findsNothing);
    expect(find.text('Total'), findsNothing);
    expect(find.text('Gauge'), findsNothing);

    // 3. Unlocked AND Enabled State: Entire ScoreHeader appears with all 4 metrics side-by-side
    controller.toggleShowPredictability(true);
    await tester.pump();

    final scoreCardFinder = find.descendant(
      of: find.byType(ScoreHeader),
      matching: find.byType(Card),
    );
    expect(scoreCardFinder, findsOneWidget);
    expect(find.descendant(of: scoreCardFinder, matching: find.text('You')), findsOneWidget);
    expect(find.descendant(of: scoreCardFinder, matching: find.text('PC')), findsOneWidget);
    expect(find.descendant(of: scoreCardFinder, matching: find.text('Total')), findsOneWidget);
    expect(find.descendant(of: scoreCardFinder, matching: find.text('Gauge')), findsOneWidget);
    // Background-tracked stats (1 win, 0 losses, 1 total, 100.0%) are immediately shown
    expect(find.descendant(of: scoreCardFinder, matching: find.text('100.0%')), findsOneWidget);

    // Verify dynamic semantic RPG gauge colors:
    // 1. Low percentages (< 30%, e.g. 0.0% and 25.0%) -> Crimson Red (0xFFE74C3C)
    controller.userScore = 0;
    controller.pcScore = 10;
    controller.totalRounds = 10;
    controller.notifyListeners();
    await tester.pump();

    Text gaugeValueText = tester.widget<Text>(
      find.descendant(of: scoreCardFinder, matching: find.text('0.0%')),
    );
    expect(gaugeValueText.style?.color, equals(ScoreHeader.crimsonRed));

    controller.userScore = 1;
    controller.pcScore = 3;
    controller.totalRounds = 4;
    controller.notifyListeners();
    await tester.pump();

    gaugeValueText = tester.widget<Text>(
      find.descendant(of: scoreCardFinder, matching: find.text('25.0%')),
    );
    expect(gaugeValueText.style?.color, equals(ScoreHeader.crimsonRed));

    // 2. Moderate percentages (30%–59%, e.g. 30.0%, 40.0%, 50.0%, 59.0%) -> Amber/Gold (0xFFFFB300)
    controller.userScore = 3;
    controller.pcScore = 7;
    controller.totalRounds = 10;
    controller.notifyListeners();
    await tester.pump();

    gaugeValueText = tester.widget<Text>(
      find.descendant(of: scoreCardFinder, matching: find.text('30.0%')),
    );
    expect(gaugeValueText.style?.color, equals(ScoreHeader.amberGold));

    controller.userScore = 4;
    controller.pcScore = 6;
    controller.totalRounds = 10;
    controller.notifyListeners();
    await tester.pump();

    gaugeValueText = tester.widget<Text>(
      find.descendant(of: scoreCardFinder, matching: find.text('40.0%')),
    );
    expect(gaugeValueText.style?.color, equals(ScoreHeader.amberGold));

    controller.userScore = 5;
    controller.pcScore = 5;
    controller.totalRounds = 10;
    controller.notifyListeners();
    await tester.pump();

    gaugeValueText = tester.widget<Text>(
      find.descendant(of: scoreCardFinder, matching: find.text('50.0%')),
    );
    expect(gaugeValueText.style?.color, equals(ScoreHeader.amberGold));

    controller.userScore = 59;
    controller.pcScore = 41;
    controller.totalRounds = 100;
    controller.notifyListeners();
    await tester.pump();

    gaugeValueText = tester.widget<Text>(
      find.descendant(of: scoreCardFinder, matching: find.text('59.0%')),
    );
    expect(gaugeValueText.style?.color, equals(ScoreHeader.amberGold));

    // 3. High percentages (>= 60%, e.g. 60.0%, 75.0%, and 100.0%) -> Emerald Green (0xFF2ECC71)
    controller.userScore = 6;
    controller.pcScore = 4;
    controller.totalRounds = 10;
    controller.notifyListeners();
    await tester.pump();

    gaugeValueText = tester.widget<Text>(
      find.descendant(of: scoreCardFinder, matching: find.text('60.0%')),
    );
    expect(gaugeValueText.style?.color, equals(ScoreHeader.emeraldGreen));

    controller.userScore = 3;
    controller.pcScore = 1;
    controller.totalRounds = 4;
    controller.notifyListeners();
    await tester.pump();

    gaugeValueText = tester.widget<Text>(
      find.descendant(of: scoreCardFinder, matching: find.text('75.0%')),
    );
    expect(gaugeValueText.style?.color, equals(ScoreHeader.emeraldGreen));

    controller.userScore = 10;
    controller.pcScore = 0;
    controller.totalRounds = 10;
    controller.notifyListeners();
    await tester.pump();

    gaugeValueText = tester.widget<Text>(
      find.descendant(of: scoreCardFinder, matching: find.text('100.0%')),
    );
    expect(gaugeValueText.style?.color, equals(ScoreHeader.emeraldGreen));

    // Toggling OFF hides the entire ScoreHeader again
    controller.toggleShowPredictability(false);
    await tester.pumpAndSettle();
    expect(find.byType(ScoreHeader), findsNothing);
    expect(find.text('Gauge'), findsNothing);
  });

  testWidgets('Predictability Score costs 15 Fire + 15 Water + 15 Wood, renders at #1 position in ShopDialog ahead of Reset Button and Unlock Earth & Metal, and displays localized description across en, pt, es, and de', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'has_seen_story_predictability': true,
      'orbs_fire': 15,
      'orbs_water': 15,
      'orbs_wood': 15,
      'animationsEnabled': false,
      'musicEnabled': false,
    });
    final storage = StorageService();
    await storage.init();
    final localization = LocalizationService();
    await localization.load();
    final audio = AudioService();

    final controller = GameController(
      storage: storage,
      localization: localization,
      audio: audio,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Open ShopDialog
    await tester.tap(find.byKey(const ValueKey('backpack_inventory_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory_open_shop_button')));
    await tester.pumpAndSettle();

    final shopScrollable = find.descendant(
      of: find.byType(ShopDialog),
      matching: find.byType(Scrollable),
    );

    // Verify Predictability Score is ahead of Reset Button and Unlock Earth & Metal and costs 15 Fire + 15 Water + 15 Wood
    final predTitle = find.text('Predictability Score');
    final resetTitle = find.text('Reset Button');
    final newHandsTitle = find.text('Unlock Earth & Metal');
    final scrollState = tester.state<ScrollableState>(shopScrollable);

    await tester.scrollUntilVisible(
      predTitle,
      100,
      scrollable: shopScrollable,
    );
    await tester.pumpAndSettle();
    expect(predTitle, findsOneWidget);
    final predY = scrollState.position.pixels + tester.getTopLeft(predTitle).dy;

    await tester.scrollUntilVisible(
      resetTitle,
      100,
      scrollable: shopScrollable,
    );
    await tester.pumpAndSettle();
    expect(resetTitle, findsOneWidget);
    final initialResetY =
        scrollState.position.pixels + tester.getTopLeft(resetTitle).dy;
    expect(predY, lessThan(initialResetY));

    await tester.scrollUntilVisible(
      newHandsTitle,
      120,
      scrollable: shopScrollable,
    );
    await tester.pumpAndSettle();
    expect(newHandsTitle, findsOneWidget);
    final newHandsY =
        scrollState.position.pixels + tester.getTopLeft(newHandsTitle).dy;
    expect(initialResetY, lessThan(newHandsY));

    // Scroll back up so Predictability Score card is fully visible
    final predUnlockBtn = find.byKey(
      const ValueKey('diamond_unlock_unlock_predictability_score'),
    );
    await tester.scrollUntilVisible(
      predUnlockBtn,
      -120,
      scrollable: shopScrollable,
    );
    await tester.pumpAndSettle();
    expect(predUnlockBtn, findsOneWidget);
    expect(
      find.descendant(of: predUnlockBtn, matching: find.text('15')),
      findsNWidgets(3),
    );

    // Verify localized subtitle in English (en)
    expect(
      find.text(
        'Unlocks Match Scoreboard (Your Score, PC Score, Total) & Predictability Gauge %',
      ),
      findsOneWidget,
    );

    // Unlock Predictability Score with 15 Fire + 15 Water + 15 Wood
    await tester.ensureVisible(predUnlockBtn);
    await tester.pumpAndSettle();
    await tester.tap(predUnlockBtn);
    await tester.pumpAndSettle();
    expect(controller.unlockedPredictability, isTrue);
    expect(controller.totalOrbs, 0);

    // Verify localized subtitle in Portuguese (pt), Spanish (es), and German (de)
    controller.setLanguage('pt');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Desbloqueia o Placar da Partida (Sua pontuação, Pontuação PC, Total) e o Medidor de Previsibilidade %',
      ),
      findsOneWidget,
    );

    controller.setLanguage('es');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Desbloquea el Marcador de la Partida (Tu Puntuación, Puntuación PC, Total) y el Medidor de Previsibilidad %',
      ),
      findsOneWidget,
    );

    controller.setLanguage('de');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Schaltet die Spiel-Punktetafel (Ihre Punktzahl, PC Score, Gesamt) & Vorhersagbarkeits-Anzeige % frei',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Enabling new hands keeps all 5 hand buttons on the same line with reduced size, and disabling restores classic 3-hand size', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
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
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );

    final rockFinder = find.byKey(const ValueKey('hand_button_rock'));
    final paperFinder = find.byKey(const ValueKey('hand_button_paper'));
    final scissorsFinder = find.byKey(const ValueKey('hand_button_scissors'));
    final lizardFinder = find.byKey(const ValueKey('hand_button_lizard'));
    final spockFinder = find.byKey(const ValueKey('hand_button_spock'));

    // Initially, only 3 classic hands are shown on the same line
    expect(rockFinder, findsOneWidget);
    expect(paperFinder, findsOneWidget);
    expect(scissorsFinder, findsOneWidget);
    expect(lizardFinder, findsNothing);
    expect(spockFinder, findsNothing);

    final classicRockSize = tester.getSize(rockFinder);
    final classicPaperSize = tester.getSize(paperFinder);
    final classicScissorsSize = tester.getSize(scissorsFinder);
    final classicCenterY = tester.getCenter(rockFinder).dy;
    expect(tester.getCenter(paperFinder).dy, equals(classicCenterY));
    expect(tester.getCenter(scissorsFinder).dy, equals(classicCenterY));

    // Purchase Unlock Earth & Metal (50 Earth + 50 Metal) -> remains disabled until user enables it
    controller.addOrbForMove(HandMove.lizard, 50);
    controller.addOrbForMove(HandMove.spock, 50);
    expect(controller.unlockNewHands(), isTrue);
    expect(controller.earthOrbs, 0);
    expect(controller.metalOrbs, 0);
    expect(controller.showNewHands, isFalse);
    await tester.pump();
    expect(lizardFinder, findsNothing);
    expect(spockFinder, findsNothing);

    // Enable Unlock Earth & Metal (5 hands total)
    controller.toggleShowNewHands(true);
    await tester.pump();

    expect(rockFinder, findsOneWidget);
    expect(paperFinder, findsOneWidget);
    expect(scissorsFinder, findsOneWidget);
    expect(lizardFinder, findsOneWidget);
    expect(spockFinder, findsOneWidget);

    // All 5 hand buttons must stay on the same horizontal line (identical center Y)
    final fiveHandsCenterY = tester.getCenter(rockFinder).dy;
    expect(tester.getCenter(paperFinder).dy, equals(fiveHandsCenterY));
    expect(tester.getCenter(scissorsFinder).dy, equals(fiveHandsCenterY));
    expect(tester.getCenter(lizardFinder).dy, equals(fiveHandsCenterY));
    expect(tester.getCenter(spockFinder).dy, equals(fiveHandsCenterY));

    // All 5 hand buttons are reduced in size compared to the classic 3-hand size
    final compactRockSize = tester.getSize(rockFinder);
    final compactPaperSize = tester.getSize(paperFinder);
    final compactScissorsSize = tester.getSize(scissorsFinder);
    expect(compactRockSize.width, lessThan(classicRockSize.width));
    expect(compactRockSize.height, lessThan(classicRockSize.height));
    expect(compactPaperSize.width, lessThan(classicPaperSize.width));
    expect(compactPaperSize.height, lessThan(classicPaperSize.height));
    expect(compactScissorsSize.width, lessThan(classicScissorsSize.width));
    expect(compactScissorsSize.height, lessThan(classicScissorsSize.height));

    // Deactivate Unlock Earth & Metal -> 3 classic hands restore their exact old size
    controller.toggleShowNewHands(false);
    await tester.pump();

    expect(lizardFinder, findsNothing);
    expect(spockFinder, findsNothing);
    expect(tester.getSize(rockFinder), equals(classicRockSize));
    expect(tester.getSize(paperFinder), equals(classicPaperSize));
    expect(tester.getSize(scissorsFinder), equals(classicScissorsSize));
  });

  testWidgets('Enabling/disabling Unlock Earth & Metal prompts to reset game only when a hand has been chosen, supporting cancel and confirm', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'unlockedNewHands': true,
      'showNewHands': false,
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
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );

    // 1. At the beginning of the game (no hand chosen yet):
    // Toggling Unlock Earth & Metal in ShopDialog does NOT ask to reset the game
    expect(controller.hasGameStarted, isFalse);
    await tester.tap(find.byKey(const ValueKey('backpack_inventory_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory_open_shop_button')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Unlock Earth & Metal'),
      140,
      scrollable: find.descendant(
        of: find.byType(ShopDialog),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlock Earth & Metal'));
    await tester.pumpAndSettle();

    // No RESET confirmation dialog should appear; Unlock Earth & Metal is enabled immediately
    expect(find.text('This will clear your scores and prediction history.'), findsNothing);
    expect(controller.showNewHands, isTrue);

    // Disabling Unlock Earth & Metal while still at the beginning also does NOT ask to reset
    await tester.tap(find.text('Unlock Earth & Metal'));
    await tester.pumpAndSettle();
    expect(find.text('This will clear your scores and prediction history.'), findsNothing);
    expect(controller.showNewHands, isFalse);

    // Close ShopDialog and play a hand so the game is no longer at the beginning
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('hand_button_rock')));
    await tester.pumpAndSettle();
    expect(controller.turnCount, 1);
    expect(controller.hasGameStarted, isTrue);

    // 2. Open ShopDialog and press Unlock Earth & Metal to enable it while game is in progress
    await tester.tap(find.byKey(const ValueKey('backpack_inventory_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory_open_shop_button')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Unlock Earth & Metal'),
      140,
      scrollable: find.descendant(
        of: find.byType(ShopDialog),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlock Earth & Metal'));
    await tester.pumpAndSettle();

    // Reset confirmation dialog must appear
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('This will clear your scores and prediction history.'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('RESET'), findsNWidgets(2));
    expect(find.widgetWithText(ElevatedButton, 'RESET'), findsOneWidget);

    // 3. Cancel the dialog -> keeps the current game and keeps 3 hands (showNewHands == false)
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.showNewHands, isFalse);
    expect(controller.turnCount, 1);
    expect(controller.currentUserMove, HandMove.rock);
    expect(controller.hasGameStarted, isTrue);

    // 4. Press Unlock Earth & Metal again and confirm RESET -> enables 5 hands AND resets the game
    await tester.tap(find.text('Unlock Earth & Metal'));
    await tester.pumpAndSettle();
    expect(find.text('This will clear your scores and prediction history.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'RESET'));
    await tester.pumpAndSettle();

    expect(controller.showNewHands, isTrue);
    expect(controller.turnCount, 0);
    expect(controller.totalRounds, 0);
    expect(controller.userScore, 0);
    expect(controller.pcScore, 0);
    expect(controller.currentUserMove, isNull);
    expect(controller.lastUserMove, isNull);
    expect(controller.hasGameStarted, isFalse);

    // 5. Since the game was just reset and no hand has been chosen yet,
    // disabling Unlock Earth & Metal now does NOT ask to reset the game
    await tester.tap(find.text('Unlock Earth & Metal'));
    await tester.pumpAndSettle();
    expect(find.text('This will clear your scores and prediction history.'), findsNothing);
    expect(controller.showNewHands, isFalse);
  });

  testWidgets('Last played hands are displayed in VersusArena when reopening the app', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'animationsEnabled': false,
    });
    final storage = StorageService();
    await storage.init();
    final localization = LocalizationService();
    final audio = AudioService();

    final firstController = GameController(
      storage: storage,
      localization: localization,
      audio: audio,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: firstController,
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );

    // Play a hand (Paper)
    await tester.tap(find.byKey(const ValueKey('hand_button_paper')));
    await tester.pumpAndSettle();

    final playedPcMove = firstController.currentComputerMove!;
    expect(firstController.currentUserMove, HandMove.paper);

    // Simulate reopening the app with a fresh GameController reading from storage
    final reopenedStorage = StorageService();
    await reopenedStorage.init();
    final reopenedController = GameController(
      storage: reopenedStorage,
      localization: localization,
      audio: audio,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: reopenedController,
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(reopenedController.currentUserMove, HandMove.paper);
    expect(reopenedController.currentComputerMove, playedPcMove);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('user_card')),
        matching: find.text('WATER'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pc_card')),
        matching: find.text(playedPcMove.displayLabel(elemental: true).toUpperCase()),
      ),
      findsOneWidget,
    );
  });

  testWidgets('New Skin (Elemental Theme) transforms move buttons, VersusArena Energy Orbs, MarkovMatrixView, and HintsBar with vector icons and localized element names without resetting match', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'orbs_fire': 1500,
      'orbs_water': 1500,
      'orbs_wood': 1500,
      'orbs_earth': 1000,
      'orbs_metal': 1000,
      'unlockedAlgorithm': true,
      'showAlgorithm': true,
      'unlockedYourPrediction': true,
      'showYourPrediction': true,
      'unlockedNextMove': true,
      'showNextMove': true,
      'unlockedSuggestion': true,
      'showSuggestion': true,
      'unlockedNewHands': true,
      'showNewHands': false,
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
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );

    // 1. Play 3 turns in starting Elemental mode so Markov transitions and scores are populated
    controller.playTurn(HandMove.rock);
    controller.playTurn(HandMove.paper);
    controller.playTurn(HandMove.rock);
    await tester.pump();

    expect(controller.turnCount, 3);
    expect(find.text('FIRE'), findsWidgets);
    expect(find.text('WATER'), findsWidgets);
    expect(find.text('WOOD'), findsWidgets);
    expect(find.byKey(const ValueKey('hand_orb_rock')), findsOneWidget);
    expect(find.byKey(const ValueKey('user_orb_container')), findsOneWidget);
    expect(find.byKey(const ValueKey('pc_orb_container')), findsOneWidget);

    // 2. Unlock New Skin (1500 Fire/Water/Wood + 1000 Earth/Metal) -> stays disabled on unlock
    final fireBeforeUnlock = controller.fireOrbs;
    expect(controller.unlockNewSkin(), isTrue);
    expect(controller.fireOrbs, fireBeforeUnlock - 1500);
    expect(controller.unlockedNewSkin, isTrue);
    expect(controller.showNewSkin, isFalse);
    await tester.pump();
    expect(find.text('FIRE'), findsWidgets);

    // 3. Toggle New Skin ON -> transforms from Elemental to Hands theme (ROCK, PAPER, SCISSORS) without resetting turnCount or matrix
    controller.toggleShowNewSkin(true);
    await tester.pump();

    expect(controller.turnCount, 3);
    expect(controller.engine.matrix[0][1], 1);
    expect(find.text('ROCK'), findsWidgets);
    expect(find.text('PAPER'), findsWidgets);
    expect(find.text('SCISSORS'), findsWidgets);

    // 4. Enable New Hands as well -> expands to 5 hands in Hands theme (adding LIZARD & SPOCK)
    controller.toggleShowNewHands(true);
    await tester.pump();

    expect(find.text('ROCK'), findsWidgets);
    expect(find.text('PAPER'), findsWidgets);
    expect(find.text('SCISSORS'), findsWidgets);
    expect(find.text('LIZARD'), findsWidgets);
    expect(find.text('SPOCK'), findsWidgets);

    // 5. Disable New Skin -> cleanly reverts to Elemental theme (FIRE, WATER, WOOD, EARTH, METAL)
    controller.toggleShowNewSkin(false);
    await tester.pump();

    expect(find.text('FIRE'), findsWidgets);
    expect(find.text('WATER'), findsWidgets);
    expect(find.text('WOOD'), findsWidgets);
    expect(find.text('EARTH'), findsWidgets);
    expect(find.text('METAL'), findsWidgets);
  });

  testWidgets('Purchasing and toggling New Skin inside ShopDialog deducts Elemental Orbs, starts off by default, switches visuals immediately without reset confirmation, and reverts when disabled', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'orbs_fire': 2000,
      'orbs_water': 2000,
      'orbs_wood': 2000,
      'orbs_earth': 1500,
      'orbs_metal': 1500,
      'unlockedAds': true,
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
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );

    // Play 2 turns so an ongoing match is active
    await tester.tap(find.byKey(const ValueKey('hand_button_rock')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hand_button_paper')));
    await tester.pumpAndSettle();

    final ongoingTurnCount = controller.turnCount;
    final ongoingTotalRounds = controller.totalRounds;
    expect(ongoingTurnCount, 2);
    expect(controller.hasGameStarted, isTrue);

    // Open ShopDialog and scroll to New Skin
    await tester.tap(find.byKey(const ValueKey('backpack_inventory_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory_open_shop_button')));
    await tester.pumpAndSettle();

    final shopScrollable = find.descendant(
      of: find.byType(ShopDialog),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('New Skin'),
      250,
      scrollable: shopScrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('New Skin'), findsOneWidget);
    expect(find.text('Hands Theme (Rock, Paper, Scissors)'), findsOneWidget);

    // Purchase New Skin via the shop button
    final fireBeforePurchase = controller.fireOrbs;
    final earthBeforePurchase = controller.earthOrbs;
    await tester.tap(find.byKey(const ValueKey('diamond_unlock_New Skin')));
    await tester.pumpAndSettle();

    expect(controller.unlockedNewSkin, isTrue);
    expect(controller.showNewSkin, isFalse);
    expect(controller.fireOrbs, fireBeforePurchase - 1500);
    expect(controller.earthOrbs, earthBeforePurchase - 1000);

    // Tap New Skin tile in ShopDialog to toggle ON -> must NOT show any reset dialog even though match is in progress
    await tester.tap(find.text('New Skin'));
    await tester.pumpAndSettle();

    expect(find.text('This will clear your scores and prediction history.'), findsNothing);
    expect(controller.showNewSkin, isTrue);
    expect(controller.turnCount, ongoingTurnCount);
    expect(controller.totalRounds, ongoingTotalRounds);

    // Close ShopDialog and verify immediate visual switch to Hands Theme
    await tester.tap(find.byKey(const ValueKey('shop_close_button')));
    await tester.pumpAndSettle();

    expect(find.text('ROCK'), findsWidgets);
    expect(find.text('PAPER'), findsWidgets);
    expect(find.text('SCISSORS'), findsWidgets);
    expect(find.text('FIRE'), findsNothing);
    expect(find.text('WATER'), findsNothing);
    expect(find.text('WOOD'), findsNothing);
    expect(find.byIcon(HandMove.rock.elementalIcon), findsNothing);
    expect(find.byIcon(HandMove.paper.elementalIcon), findsNothing);
    expect(find.byIcon(HandMove.scissors.elementalIcon), findsNothing);

    // Reopen ShopDialog and toggle New Skin OFF -> reverts to Elemental Theme without resetting match
    await tester.tap(find.byKey(const ValueKey('backpack_inventory_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory_open_shop_button')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('New Skin'),
      250,
      scrollable: shopScrollable,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Skin'));
    await tester.pumpAndSettle();

    expect(controller.showNewSkin, isFalse);
    expect(controller.turnCount, ongoingTurnCount);
    expect(controller.totalRounds, ongoingTotalRounds);

    await tester.tap(find.byKey(const ValueKey('shop_close_button')));
    await tester.pumpAndSettle();

    expect(find.text('FIRE'), findsWidgets);
    expect(find.text('WATER'), findsWidgets);
    expect(find.text('WOOD'), findsWidgets);
    expect(find.byIcon(HandMove.rock.elementalIcon), findsWidgets);
    expect(find.byIcon(HandMove.paper.elementalIcon), findsWidgets);
    expect(find.byIcon(HandMove.scissors.elementalIcon), findsWidgets);
    expect(find.byKey(const ValueKey('hand_orb_rock')), findsOneWidget);
    expect(find.byKey(const ValueKey('user_orb_container')), findsOneWidget);
    expect(find.byKey(const ValueKey('pc_orb_container')), findsOneWidget);
  });

  testWidgets('Help button is moved from AppBar into SettingsDialog and opens HelpDialog', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
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
    await tester.pumpAndSettle();

    // Help icon button is no longer in the top AppBar
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.help_outline),
      ),
      findsNothing,
    );

    // Open SettingsDialog -> Help button is present inside Settings
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    final helpBtn = find.byKey(const ValueKey('settings_help_button'));
    expect(helpBtn, findsOneWidget);
    await tester.ensureVisible(helpBtn);
    await tester.tap(helpBtn);
    await tester.pumpAndSettle();

    // HelpDialog is displayed
    expect(find.text('How It Works'), findsOneWidget);
    expect(find.text('💡 Pro Tip: The Markov Model'), findsOneWidget);
  });

  testWidgets('ShopDialog renders titles without mid-word breaks and displays Rewarded Ad text horizontally on narrow mobile screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'orbs_fire': 200024,
      'orbs_water': 200024,
      'orbs_wood': 200024,
      'orbs_earth': 200024,
      'orbs_metal': 200024,
      'animationsEnabled': false,
      'musicEnabled': false,
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
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: ShopDialog(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. "Predictability" in "Predictability Score" must never split mid-word on narrow mobile screens
    final listViewFinder = find.descendant(
      of: find.byType(ShopDialog),
      matching: find.byType(ListView),
    );
    final shopScrollable = find.descendant(
      of: find.byType(ShopDialog),
      matching: find.byType(Scrollable),
    );
    final predTitleFinder = find.text('Predictability Score');
    await tester.scrollUntilVisible(
      predTitleFinder,
      120,
      scrollable: shopScrollable,
    );
    await tester.pumpAndSettle();
    expect(predTitleFinder, findsOneWidget);
    final predParagraph =
        tester.renderObject<RenderParagraph>(predTitleFinder);
    expect(predParagraph.text.toPlainText(), 'Predictability Score');
    final predictabilityWordBoxes = predParagraph.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: 'Predictability'.length,
      ),
    );
    final predictabilityLineTops =
        predictabilityWordBoxes.map((b) => b.top.round()).toSet();
    expect(predictabilityLineTops.length, 1);

    tester.state<ScrollableState>(shopScrollable).position.jumpTo(0);
    await tester.pumpAndSettle();

    // 2. Pinned Rewarded Ad card is immediately visible below the balance bar and above the ListView without scrolling
    final balanceBarFinder = find.byKey(const ValueKey('shop_orb_summary_bar'));
    final adCardFinder = find.byKey(const ValueKey('shop_rewarded_ad_card'));
    expect(balanceBarFinder, findsOneWidget);
    expect(adCardFinder, findsOneWidget);
    expect(listViewFinder, findsOneWidget);
    expect(
      find.descendant(of: listViewFinder, matching: adCardFinder),
      findsNothing,
    );
    expect(
      tester.getRect(adCardFinder).top,
      greaterThan(tester.getRect(balanceBarFinder).bottom),
    );
    expect(
      tester.getRect(adCardFinder).bottom,
      lessThanOrEqualTo(tester.getRect(listViewFinder).top),
    );

    final freeOrbsFinder = find.text('Free Elemental Orbs');
    final subtitleFinder =
        find.text('Watch a video ad for +50 Fire, Water & Wood Orbs');
    final watchAdBtnFinder =
        find.byKey(const ValueKey('shop_watch_rewarded_ad_button'));

    expect(freeOrbsFinder, findsOneWidget);
    expect(subtitleFinder, findsOneWidget);
    expect(watchAdBtnFinder, findsOneWidget);

    final freeOrbsRect = tester.getRect(freeOrbsFinder);
    final subtitleRect = tester.getRect(subtitleFinder);
    final watchAdBtnRect = tester.getRect(watchAdBtnFinder);

    expect(freeOrbsRect.width, greaterThan(150));
    expect(freeOrbsRect.height, lessThan(30));
    expect(subtitleRect.width, greaterThan(180));
    expect(subtitleRect.height, lessThanOrEqualTo(50));
    expect(freeOrbsRect.bottom, lessThanOrEqualTo(subtitleRect.top + 4));
    expect(subtitleRect.bottom, lessThan(watchAdBtnRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ShopDialog pins Free Elemental Orbs card below balance bar while scrolling and collapses smoothly when Remove Ads is enabled', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'orbs_fire': 5000,
      'orbs_water': 5000,
      'orbs_wood': 5000,
      'orbs_earth': 5000,
      'orbs_metal': 5000,
      'animationsEnabled': false,
      'musicEnabled': false,
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
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: ShopDialog(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final balanceBarFinder = find.byKey(const ValueKey('shop_orb_summary_bar'));
    final adCardFinder = find.byKey(const ValueKey('shop_rewarded_ad_card'));
    final listViewFinder = find.descendant(
      of: find.byType(ShopDialog),
      matching: find.byType(ListView),
    );

    expect(adCardFinder, findsOneWidget);
    final initialAdRect = tester.getRect(adCardFinder);
    expect(
      initialAdRect.top,
      greaterThan(tester.getRect(balanceBarFinder).bottom),
    );
    expect(
      initialAdRect.bottom,
      lessThanOrEqualTo(tester.getRect(listViewFinder).top),
    );

    // Scroll upgrades list down to Crystal Ball -> pinned ad card remains stationary
    await tester.scrollUntilVisible(
      find.text('Crystal Ball'),
      250,
      scrollable: find.descendant(
        of: listViewFinder,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Crystal Ball'), findsOneWidget);
    expect(adCardFinder, findsOneWidget);
    expect(tester.getRect(adCardFinder), equals(initialAdRect));

    // Unlock Remove Ads while inside ShopDialog -> card smoothly collapses and hides
    expect(controller.unlockAds(), isTrue);
    await tester.pumpAndSettle();
    expect(adCardFinder, findsNothing);

    // Toggle Remove Ads OFF -> card expands back into pinned top position
    controller.toggleRemoveAds(false);
    await tester.pumpAndSettle();
    expect(adCardFinder, findsOneWidget);
    expect(tester.getRect(adCardFinder), equals(initialAdRect));
  });

  testWidgets('7-tap QA shortcut on Backpack icon grants +100,000 of each Elemental Orb in UI', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'animationsEnabled': false,
      'musicEnabled': false,
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
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const HowPredictableApp(),
      ),
    );
    await tester.pump();

    expect(controller.totalOrbs, 0);

    // 1st tap on top-left Backpack button opens InventoryDialog (count = 1)
    await tester.tap(find.byKey(const ValueKey('backpack_inventory_button')));
    await tester.pumpAndSettle();
    expect(find.byType(InventoryDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('inventory_header_backpack_icon')),
        matching: find.byType(RpgBackpackIcon),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.backpack_rounded), findsNothing);
    expect(controller.totalOrbs, 0);

    // Next 6 taps on the Backpack icon inside InventoryDialog reach 7 taps total
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const ValueKey('inventory_header_backpack_icon')));
    }
    await tester.pump();

    expect(controller.fireOrbs, 100000);
    expect(controller.waterOrbs, 100000);
    expect(controller.woodOrbs, 100000);
    expect(controller.earthOrbs, 100000);
    expect(controller.metalOrbs, 100000);
    expect(find.text(PlayGamesService.qaBonusSnackBarMessage), findsOneWidget);
  });

  testWidgets('Top-left Backpack button opens InventoryDialog showing all 5 orb counts, locked/active combat states, Open Shop / Altar navigation, and Flying Orb VFX on round win', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'orbs_fire': 12,
      'orbs_water': 34,
      'orbs_wood': 56,
      'orbs_earth': 7,
      'orbs_metal': 8,
      'unlockedNewHands': true,
      'showNewHands': false,
      'animationsEnabled': true,
      'musicEnabled': false,
    });
    final storage = StorageService();
    await storage.init();
    final localization = LocalizationService();
    await localization.load();
    final audio = AudioService();

    final controller = GameController(
      storage: storage,
      localization: localization,
      audio: audio,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );
    await tester.pump();

    // 1. Win a round against AI Fire (HandMove.rock) using Water (HandMove.paper)
    controller.crystalBallMove = HandMove.rock;
    await tester.tap(find.byKey(const ValueKey('hand_button_paper')));
    await tester.pump();

    // Fire Orbs incremented by +1 (12 -> 13)
    expect(controller.fireOrbs, 13);

    // Phase 1 — Launch (0ms -> <300ms): Collectible orb has not spawned yet before Mid-Arena Clash
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('flying_orb_vfx_overlay')), findsNothing);

    // Phase 2 — Mid-Arena Clash (~300ms): Collectible orb spawns at exact center of VersusArena (VS clash point)
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('flying_orb_vfx_overlay')), findsOneWidget);
    final flyingOrbFinder = find.byKey(const ValueKey('flying_orb_fire'));
    expect(flyingOrbFinder, findsOneWidget);

    final clashCenter = tester.getCenter(find.byKey(const ValueKey('vs_badge')));
    final pcOrbCenter = tester.getCenter(find.byKey(const ValueKey('pc_orb_container')));
    final backpackCenter = tester.getCenter(find.byType(RpgBackpackIcon));
    final spawnOrbCenter = tester.getCenter(flyingOrbFinder);

    expect(spawnOrbCenter.dx, closeTo(clashCenter.dx, 1.0));
    expect(spawnOrbCenter.dy, closeTo(clashCenter.dy, 1.0));
    expect((spawnOrbCenter.dx - pcOrbCenter.dx).abs(), greaterThan(50.0));

    // Mid-flight (at 300ms + 325ms = 625ms, halfway through the 650ms curve):
    // Orb preserves right-to-left momentum (already well to the left of horizontal midpoint)
    // while staying lower vertically before sweeping steeply upward into the top-left Backpack
    await tester.pump(const Duration(milliseconds: 325));
    expect(find.byKey(const ValueKey('flying_orb_vfx_overlay')), findsOneWidget);
    final midFlightCenter = tester.getCenter(flyingOrbFinder);
    final horizontalMidpoint = (spawnOrbCenter.dx + backpackCenter.dx) * 0.5;
    final verticalMidpoint = (spawnOrbCenter.dy + backpackCenter.dy) * 0.5;
    expect(midFlightCenter.dx, lessThan(horizontalMidpoint));
    expect(midFlightCenter.dy, greaterThan(verticalMidpoint));
    expect(midFlightCenter.dx, greaterThan(backpackCenter.dx));
    expect(midFlightCenter.dy, lessThan(spawnOrbCenter.dy));

    // Near end of flight (at 300ms + 550ms = 850ms): sweeping steeply upward toward Backpack
    await tester.pump(const Duration(milliseconds: 225));
    final lateFlightCenter = tester.getCenter(flyingOrbFinder);
    expect(lateFlightCenter.dx, lessThan(midFlightCenter.dx));
    expect(lateFlightCenter.dy, lessThan(midFlightCenter.dy));

    // Complete 650ms flight (at 950ms) -> triggers Backpack scale bounce & elemental glow pulse
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('flying_orb_vfx_overlay')), findsNothing);
    await tester.pump(const Duration(milliseconds: 140));
    final pulsingBackpack = tester.widget<RpgBackpackIcon>(
      find.byType(RpgBackpackIcon),
    );
    expect(pulsingBackpack.glowStrength, greaterThan(0.0));
    expect(pulsingBackpack.pulseColor, equals(HandMove.rock.elementalPrimaryColor));

    // Finish Backpack pulse animation
    await tester.pump(const Duration(milliseconds: 200));

    // 2. Tap top-left Backpack icon -> opens InventoryDialog showing all 5 orb counts
    final backpackBtn = find.byKey(const ValueKey('backpack_inventory_button'));
    expect(backpackBtn, findsOneWidget);
    await tester.tap(backpackBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(InventoryDialog), findsOneWidget);
    expect(find.text("Cleric's Backpack"), findsOneWidget);
    expect(find.byIcon(Icons.backpack_rounded), findsNothing);
    final headerBackpack = tester.widget<RpgBackpackIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('inventory_header_backpack_icon')),
        matching: find.byType(RpgBackpackIcon),
      ),
    );
    expect(headerBackpack.size, inInclusiveRange(80.0, 90.0));
    expect(headerBackpack.isOpen, isTrue);
    expect(headerBackpack.ownedOrbs, equals(HandMove.values.toSet()));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('inventory_orb_count_fire')),
        matching: find.text('13'),
      ),
      findsNothing, // inventory_orb_count_fire IS the Text widget itself
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('inventory_orb_count_fire'))).data,
      '13',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('inventory_orb_count_water'))).data,
      '34',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('inventory_orb_count_wood'))).data,
      '56',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('inventory_orb_count_earth'))).data,
      '7',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('inventory_orb_count_metal'))).data,
      '8',
    );

    // Earth and Metal show simplified Locked status while showNewHands is false
    expect(
      find.text('Locked (Unlock Earth & Metal)'),
      findsNWidgets(2),
    );
    expect(find.text('Active'), findsNWidgets(3));
    expect(find.textContaining('in combat'), findsNothing);

    // Clean orb names without parenthesized element codes & 3D spheres without combat icons
    for (final move in HandMove.values) {
      expect(
        find.byKey(ValueKey('inventory_orb_sphere_${move.orbKey}')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(InventoryDialog),
          matching: find.byIcon(move.elementalIcon),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(InventoryDialog),
          matching: find.textContaining('(${move.elementalLabel})'),
        ),
        findsNothing,
      );
    }

    // 3. Tap "Open Shop / Altar" button in InventoryDialog -> jumps straight to ShopDialog
    await tester.tap(find.byKey(const ValueKey('inventory_open_shop_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(InventoryDialog), findsNothing);
    expect(find.byType(ShopDialog), findsOneWidget);
    expect(find.byKey(const ValueKey('shop_orb_summary_bar')), findsOneWidget);
  });

  testWidgets('SettingsDialog displays dynamic release version, copyable Player ID with SnackBar, toggle spacing/contrast, and outlined Ok button', (WidgetTester tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'How Predictable',
      packageName: 'com.gustlarsen.howpredictable',
      version: '1.0.68',
      buildNumber: '168',
      buildSignature: '',
    );

    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedText = args['text'] as String?;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'vibrationEnabled': false,
      'animationsEnabled': false,
      'musicEnabled': false,
    });
    final storage = StorageService();
    await storage.init();
    final localization = LocalizationService();
    final audio = AudioService();
    final playGames = PlayGamesService(
      storage: storage,
      client: _SettingsTestPlayGamesClient(),
    );
    await playGames.signIn();

    final controller = GameController(
      storage: storage,
      localization: localization,
      audio: audio,
      playGames: playGames,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const HowPredictableApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Open SettingsDialog
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // 1. Dynamic Release Version Display in bottom footer
    final versionFinder = find.byKey(const ValueKey('settings_version_label'));
    expect(versionFinder, findsOneWidget);
    expect(find.text('Version 1.0.68 (168)'), findsOneWidget);

    // Verify clean fallback helper when version is empty
    expect(
      SettingsDialog.formatVersionLabel('', ''),
      SettingsDialog.fallbackVersionLabel,
    );

    // 2. Copyable Player ID button right next to ID text
    final idFinder = find.byKey(const ValueKey('play_games_player_id'));
    final copyBtnFinder = find.byKey(const ValueKey('play_games_copy_id_button'));
    expect(idFinder, findsOneWidget);
    expect(copyBtnFinder, findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

    await tester.tap(copyBtnFinder);
    await tester.pump();
    expect(copiedText, 'a_2116013489197419559');
    expect(find.text('Player ID copied'), findsOneWidget);

    // 3. Toggle Spacing (8-12px vertical gap) & OFF state contrast
    final darkTile = find.byKey(const ValueKey('settings_dark_mode_tile'));
    final soundTile = find.byKey(const ValueKey('settings_sound_effects_tile'));
    final musicTile = find.byKey(const ValueKey('settings_background_music_tile'));
    final vibrationTile = find.byKey(const ValueKey('settings_vibration_tile'));
    final animationsTile = find.byKey(const ValueKey('settings_animations_tile'));

    expect(
      tester.getTopLeft(soundTile).dy - tester.getBottomLeft(darkTile).dy,
      closeTo(10.0, 0.1),
    );
    expect(
      tester.getTopLeft(musicTile).dy - tester.getBottomLeft(soundTile).dy,
      closeTo(10.0, 0.1),
    );
    expect(
      tester.getTopLeft(vibrationTile).dy - tester.getBottomLeft(musicTile).dy,
      closeTo(10.0, 0.1),
    );
    expect(
      tester.getTopLeft(animationsTile).dy - tester.getBottomLeft(vibrationTile).dy,
      closeTo(10.0, 0.1),
    );

    // 4. Scroll view & Outlined Ok button in bottom-right opposite version label
    expect(find.byKey(const ValueKey('settings_scroll_view')), findsOneWidget);
    final okBtnFinder = find.byKey(const ValueKey('settings_ok_button'));
    expect(okBtnFinder, findsOneWidget);
    expect(tester.widget(okBtnFinder), isA<OutlinedButton>());
    expect(
      tester.getCenter(versionFinder).dx,
      lessThan(tester.getCenter(okBtnFinder).dx),
    );

    await tester.tap(okBtnFinder);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsDialog), findsNothing);
  });

  testWidgets('Move buttons and RANDOM button remain visible and stationary at the bottom above the banner ad both in minimal start UI and when MarkovTransitionMatrix is scrolled', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'unlockedRandom': true,
      'showRandom': true,
      'unlockedPredictability': false,
      'showPredictability': false,
      'unlockedYourPrediction': false,
      'showYourPrediction': false,
      'unlockedNextMove': false,
      'showNextMove': false,
      'unlockedSuggestion': false,
      'showSuggestion': false,
      'unlockedAlgorithm': false,
      'showAlgorithm': false,
      'animationsEnabled': false,
      'musicEnabled': false,
    });
    final storage = StorageService();
    await storage.init();
    final localization = LocalizationService();
    final audio = AudioService();
    final adService = AdService(client: _LayoutTestAdMobClient());
    await adService.initialize();

    final controller = GameController(
      storage: storage,
      localization: localization,
      audio: audio,
      adService: adService,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final scrollViewFinder = find.byKey(const ValueKey('game_upper_scroll_view'));
    final moveCardFinder = find.byKey(const ValueKey('move_selection_card'));
    final bannerContainerFinder = find.byKey(const ValueKey('bottom_banner_ad_container'));
    final rockBtnFinder = find.byKey(const ValueKey('hand_button_rock'));
    final paperBtnFinder = find.byKey(const ValueKey('hand_button_paper'));
    final scissorsBtnFinder = find.byKey(const ValueKey('hand_button_scissors'));
    final randomBtnFinder = find.byKey(const ValueKey('random_move_button'));

    // 1. Minimal Start Screen UI (ScoreHeader, HintsBar, and MarkovMatrixView hidden):
    expect(find.byType(ScoreHeader), findsNothing);
    expect(find.byType(MarkovMatrixView), findsNothing);
    expect(scrollViewFinder, findsOneWidget);
    expect(moveCardFinder, findsOneWidget);
    expect(bannerContainerFinder, findsOneWidget);
    expect(rockBtnFinder, findsOneWidget);
    expect(paperBtnFinder, findsOneWidget);
    expect(scissorsBtnFinder, findsOneWidget);
    expect(randomBtnFinder, findsOneWidget);

    // Move selection card is outside the SingleChildScrollView, while VersusArena is inside it
    expect(
      find.descendant(of: scrollViewFinder, matching: find.byType(VersusArena)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: scrollViewFinder, matching: moveCardFinder),
      findsNothing,
    );

    // Visual separation: move selection card has subtle border and upward BoxShadow
    final moveCardContainer = tester.widget<Container>(moveCardFinder);
    final moveCardDecoration = moveCardContainer.decoration! as BoxDecoration;
    expect(moveCardDecoration.border, isNotNull);
    expect(moveCardDecoration.boxShadow, isNotNull);
    expect(moveCardDecoration.boxShadow!.first.offset.dy, lessThan(0));

    // Safe Ad Spacing: 8px-12px vertical padding between bottom of move-selection card and top of banner ad
    final minimalCardRect = tester.getRect(moveCardFinder);
    final minimalBannerRect = tester.getRect(bannerContainerFinder);
    final adGap = minimalBannerRect.top - minimalCardRect.bottom;
    expect(adGap, greaterThanOrEqualTo(8.0));
    expect(adGap, lessThanOrEqualTo(12.0));

    // VersusArena is cleanly centered inside the upper scrollable viewport in minimal UI
    final scrollViewportRect = tester.getRect(scrollViewFinder);
    final minimalArenaRect = tester.getRect(find.byType(VersusArena));
    expect(
      minimalArenaRect.center.dy,
      closeTo(scrollViewportRect.center.dy, 16.0),
    );

    final minimalRockRect = tester.getRect(rockBtnFinder);
    final minimalPaperRect = tester.getRect(paperBtnFinder);
    final minimalScissorsRect = tester.getRect(scissorsBtnFinder);
    final minimalRandomRect = tester.getRect(randomBtnFinder);

    // 2. Enable ScoreHeader, HintsBar, and MarkovTransitionMatrix:
    controller.unlockedPredictability = true;
    controller.showPredictability = true;
    controller.unlockedYourPrediction = true;
    controller.showYourPrediction = true;
    controller.unlockedNextMove = true;
    controller.showNextMove = true;
    controller.unlockedSuggestion = true;
    controller.showSuggestion = true;
    controller.unlockedAlgorithm = true;
    controller.showAlgorithm = true;
    controller.notifyListeners();
    await tester.pumpAndSettle();

    expect(find.byType(ScoreHeader), findsOneWidget);
    expect(find.byType(HintsBar), findsOneWidget);
    expect(find.byType(VersusArena), findsOneWidget);
    expect(find.byType(MarkovMatrixView), findsOneWidget);

    // Move selection card and buttons remain anchored at the exact same bottom coordinates as in minimal UI
    expect(tester.getRect(moveCardFinder), equals(minimalCardRect));
    expect(tester.getRect(rockBtnFinder), equals(minimalRockRect));
    expect(tester.getRect(paperBtnFinder), equals(minimalPaperRect));
    expect(tester.getRect(scissorsBtnFinder), equals(minimalScissorsRect));
    expect(tester.getRect(randomBtnFinder), equals(minimalRandomRect));
    expect(tester.getRect(bannerContainerFinder), equals(minimalBannerRect));

    // ScoreHeader, HintsBar, and VersusArena are comfortably visible above the pinned move card before scrolling
    expect(tester.getRect(find.byType(ScoreHeader)).top, greaterThanOrEqualTo(scrollViewportRect.top));
    expect(tester.getRect(find.byType(VersusArena)).bottom, lessThanOrEqualTo(minimalCardRect.top));

    // 3. Enable New Hands (5 elements: FIRE, WATER, WOOD, EARTH, METAL) and scroll MarkovTransitionMatrix:
    controller.unlockedNewHands = true;
    controller.toggleShowNewHands(true);
    await tester.pumpAndSettle();

    final lizardBtnFinder = find.byKey(const ValueKey('hand_button_lizard'));
    final spockBtnFinder = find.byKey(const ValueKey('hand_button_spock'));
    expect(lizardBtnFinder, findsOneWidget);
    expect(spockBtnFinder, findsOneWidget);

    final cardRectBeforeScroll = tester.getRect(moveCardFinder);
    final rockRectBeforeScroll = tester.getRect(rockBtnFinder);
    final paperRectBeforeScroll = tester.getRect(paperBtnFinder);
    final scissorsRectBeforeScroll = tester.getRect(scissorsBtnFinder);
    final lizardRectBeforeScroll = tester.getRect(lizardBtnFinder);
    final spockRectBeforeScroll = tester.getRect(spockBtnFinder);
    final randomRectBeforeScroll = tester.getRect(randomBtnFinder);
    final bannerRectBeforeScroll = tester.getRect(bannerContainerFinder);
    final matrixTopBeforeScroll = tester.getTopLeft(find.byType(MarkovMatrixView)).dy;
    final arenaTopBeforeScroll = tester.getTopLeft(find.byType(VersusArena)).dy;

    // Scroll the upper SingleChildScrollView upward to bring MarkovTransitionMatrix up
    await tester.drag(scrollViewFinder, const Offset(0, -220));
    await tester.pumpAndSettle();

    // Upper informational sections (VersusArena and MarkovMatrixView) scrolled upward
    expect(
      tester.getTopLeft(find.byType(MarkovMatrixView)).dy,
      lessThan(matrixTopBeforeScroll),
    );
    expect(
      tester.getTopLeft(find.byType(VersusArena)).dy,
      lessThan(arenaTopBeforeScroll),
    );

    // Pinned bottom move-selection card, all 5 element buttons, RANDOM button, and banner ad remain completely stationary
    expect(tester.getRect(moveCardFinder), equals(cardRectBeforeScroll));
    expect(tester.getRect(rockBtnFinder), equals(rockRectBeforeScroll));
    expect(tester.getRect(paperBtnFinder), equals(paperRectBeforeScroll));
    expect(tester.getRect(scissorsBtnFinder), equals(scissorsRectBeforeScroll));
    expect(tester.getRect(lizardBtnFinder), equals(lizardRectBeforeScroll));
    expect(tester.getRect(spockBtnFinder), equals(spockRectBeforeScroll));
    expect(tester.getRect(randomBtnFinder), equals(randomRectBeforeScroll));
    expect(tester.getRect(bannerContainerFinder), equals(bannerRectBeforeScroll));
  });

  testWidgets('Backpack button maintains strict fixed size (36x36 with 28px icon) and does not shrink when all top bar icons are active on narrow screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'animationsEnabled': false,
    });
    final storage = StorageService();
    await storage.init();
    final adMobClient = _LayoutTestAdMobClient();
    final adService = AdService(client: adMobClient);
    final audio = AudioService();
    final playGames = PlayGamesService(
      storage: storage,
      client: _SettingsTestPlayGamesClient(),
    );
    final localization = LocalizationService();
    final controller = GameController(
      storage: storage,
      localization: localization,
      audio: audio,
      playGames: playGames,
      adService: adService,
    );

    // Initial top bar with minimal icons (no Reset unlocked)
    await tester.pumpWidget(
      ChangeNotifierProvider<GameController>.value(
        value: controller,
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final backpackFinder =
        find.byKey(const ValueKey('backpack_inventory_button'));
    expect(backpackFinder, findsOneWidget);
    final initialSize = tester.getSize(backpackFinder);
    expect(initialSize, equals(const Size(36.0, 36.0)));

    final backpackIconFinder = find.byType(RpgBackpackIcon);
    expect(backpackIconFinder, findsOneWidget);
    final initialIconSize = tester.getSize(backpackIconFinder);
    expect(initialIconSize, equals(const Size(28.0, 28.0)));

    final teleportFinder = find.byKey(const ValueKey('teleport_portal_button'));
    final teleportIconFinder = find.byType(RpgTeleportPortalIcon);
    expect(teleportFinder, findsOneWidget);
    expect(teleportIconFinder, findsOneWidget);
    expect(tester.getSize(teleportFinder), equals(const Size(36.0, 36.0)));
    expect(tester.getSize(teleportIconFinder), equals(const Size(28.0, 28.0)));
    expect(find.byIcon(Icons.shopping_cart_outlined), findsNothing);

    // Gift Box starts locked and hidden from the AppBar
    expect(find.text('🎁'), findsNothing);

    // Activate ALL top bar icons: Rewarded Ad, Gift, Reset, Teleport, Settings
    controller.showReset = true;
    controller.unlockedReset = true;
    controller.giftBoxUnlocked = true;
    controller.giftBoxEnabled = true;
    await controller.adService.loadRewardedAd();
    controller.notifyListeners();
    await tester.pumpAndSettle();

    // Verify all action buttons / items are active and Shopping Cart is absent
    expect(find.byKey(const ValueKey('backpack_inventory_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('watch_rewarded_ad_button')), findsOneWidget);
    expect(find.text('🎁'), findsOneWidget);
    expect(find.byIcon(Icons.restart_alt), findsOneWidget);
    expect(find.byIcon(Icons.shopping_cart_outlined), findsNothing);
    expect(teleportFinder, findsOneWidget);
    expect(teleportIconFinder, findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    // Both Backpack and Teleport Portal buttons maintain strict fixed size outside any Flexible wrapper
    final crowdedSize = tester.getSize(backpackFinder);
    expect(crowdedSize, equals(const Size(36.0, 36.0)));
    expect(crowdedSize, equals(initialSize));

    final crowdedIconSize = tester.getSize(backpackIconFinder);
    expect(crowdedIconSize, equals(const Size(28.0, 28.0)));
    expect(crowdedIconSize, equals(initialIconSize));

    expect(tester.getSize(teleportFinder), equals(const Size(36.0, 36.0)));
    expect(tester.getSize(teleportIconFinder), equals(const Size(28.0, 28.0)));
  });

  testWidgets('Rewarded Ad button switches cleanly between full label and compact video icon +50 based on available horizontal space', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'animationsEnabled': false,
    });
    final storage = StorageService();
    await storage.init();
    final adMobClient = _LayoutTestAdMobClient();
    final adService = AdService(client: adMobClient);
    final audio = AudioService();
    final playGames = PlayGamesService(
      storage: storage,
      client: _SettingsTestPlayGamesClient(),
    );
    final localization = LocalizationService();
    final controller = GameController(
      storage: storage,
      localization: localization,
      audio: audio,
      playGames: playGames,
      adService: adService,
    );

    await controller.adService.loadRewardedAd();
    controller.showReset = true;
    controller.unlockedReset = true;
    controller.giftBoxUnlocked = true;
    controller.giftBoxEnabled = true;

    await tester.pumpWidget(
      ChangeNotifierProvider<GameController>.value(
        value: controller,
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Ample horizontal space (width 800): renders full pill label
    expect(find.byKey(const ValueKey('watch_rewarded_ad_button')), findsOneWidget);
    expect(find.text(AdService.rewardedAdButtonLabel), findsOneWidget);
    expect(find.byIcon(Icons.ondemand_video_rounded), findsNothing);

    // 2. Crowded narrow screen (width 360 with Backpack, Ad, Gift, Reset, Cart, Settings):
    // LayoutBuilder automatically switches to compact video-icon +50 pill
    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('watch_rewarded_ad_button')), findsOneWidget);
    expect(find.text(AdService.rewardedAdButtonLabel), findsNothing);
    expect(find.byIcon(Icons.ondemand_video_rounded), findsOneWidget);
    expect(find.text('+50'), findsOneWidget);

    // 3. As soon as icons are hidden/removed and horizontal space opens up:
    // User claims periodic gift -> Gift icon disappears
    controller.showReset = false;
    await tester.tap(find.text('🎁'));
    await tester.pumpAndSettle();

    expect(find.text('🎁'), findsNothing);
    expect(find.byIcon(Icons.restart_alt), findsNothing);

    // Space opens up -> automatically switches back to full "Watch Ad +50 Orbs" text pill
    expect(find.byIcon(Icons.ondemand_video_rounded), findsNothing);
    expect(find.text(AdService.rewardedAdButtonLabel), findsOneWidget);

    // Tap rewarded ad in full mode -> grants +50 elemental orbs and enters cooldown
    await tester.tap(find.byKey(const ValueKey('watch_rewarded_ad_button')));
    await tester.pump();

    // 5 periodic gift orbs + 50 rewarded ad orbs = 55
    expect(controller.fireOrbs, equals(55));
    expect(controller.waterOrbs, equals(55));
    expect(find.byKey(const ValueKey('watch_rewarded_ad_button')), findsNothing);
  });

  testWidgets('AdaptiveRewardedAdButton switches between full label and compact video icon +50 based on maxWidth constraints', (WidgetTester tester) async {
    bool tapped = false;

    // Ample space (width = 250)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 250,
              child: AdaptiveRewardedAdButton(
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text(AdService.rewardedAdButtonLabel), findsOneWidget);
    expect(find.byIcon(Icons.ondemand_video_rounded), findsNothing);
    expect(find.text('+50'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('watch_rewarded_ad_button')));
    expect(tapped, isTrue);

    tapped = false;
    // Constrained space (width = 90)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 90,
              child: AdaptiveRewardedAdButton(
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text(AdService.rewardedAdButtonLabel), findsNothing);
    expect(find.byIcon(Icons.ondemand_video_rounded), findsOneWidget);
    expect(find.text('+50'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('watch_rewarded_ad_button')));
    expect(tapped, isTrue);
  });

  testWidgets('RpgBackpackIcon renders rich brown leather adventurer backpack with custom painter and handles pulse glow', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: RpgBackpackIcon(
              size: 28.0,
              pulseColor: Colors.deepOrange,
              glowStrength: 0.8,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(RpgBackpackIcon), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    final size = tester.getSize(find.byType(RpgBackpackIcon));
    expect(size, equals(const Size(28.0, 28.0)));
  });

  testWidgets("InventoryDialog header displays large overlapping open RpgBackpackIcon (80px-90px) without square box, animates opening/glow, and reflects owned orbs", (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'orbs_fire': 5,
      'orbs_water': 0,
      'orbs_wood': 2,
      'orbs_earth': 0,
      'orbs_metal': 1,
      'animationsEnabled': true,
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
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InventoryDialog(controller: controller),
        ),
      ),
    );

    expect(find.byType(InventoryDialog), findsOneWidget);
    expect(find.byIcon(Icons.backpack_rounded), findsNothing);

    final headerBackpackContainerFinder =
        find.byKey(const ValueKey('inventory_header_backpack_icon'));
    final headerBackpackFinder = find.descendant(
      of: headerBackpackContainerFinder,
      matching: find.byType(RpgBackpackIcon),
    );
    expect(headerBackpackFinder, findsOneWidget);

    // No square golden Container box wrapping the backpack icon
    expect(
      find.descendant(
        of: headerBackpackContainerFinder,
        matching: find.byType(Container),
      ),
      findsNothing,
    );

    // Early in the ~300ms entrance/open transition
    await tester.pump(const Duration(milliseconds: 100));
    final earlyBackpack = tester.widget<RpgBackpackIcon>(headerBackpackFinder);
    expect(earlyBackpack.size, inInclusiveRange(80.0, 90.0));
    expect(earlyBackpack.isOpen, isTrue);
    expect(earlyBackpack.openProgress, lessThan(1.0));
    expect(
      earlyBackpack.ownedOrbs,
      equals({HandMove.rock, HandMove.scissors, HandMove.spock}),
    );

    // Finish the ~300ms entrance/open animation
    await tester.pump(const Duration(milliseconds: 250));
    final openBackpack = tester.widget<RpgBackpackIcon>(headerBackpackFinder);
    expect(openBackpack.openProgress, closeTo(1.0, 1e-4));

    // Backpack overlaps/extends above the top edge of the dialog card and stays clear of title text
    final backpackRect = tester.getRect(headerBackpackFinder);
    final cardRect =
        tester.getRect(find.byKey(const ValueKey('inventory_dialog_card')));
    final titleRect = tester.getRect(find.text("Cleric's Backpack"));
    expect(backpackRect.top, lessThan(cardRect.top));
    expect(backpackRect.right, lessThanOrEqualTo(titleRect.left));

    // Gentle looping radial glow phase continues advancing over time
    final phaseBefore = openBackpack.ambientGlowPhase;
    await tester.pump(const Duration(milliseconds: 400));
    final laterBackpack = tester.widget<RpgBackpackIcon>(headerBackpackFinder);
    expect(laterBackpack.ambientGlowPhase, isNot(equals(phaseBefore)));

    // Dynamically reflects inventory changes (e.g., acquiring Water & Earth orbs)
    controller.waterOrbs = 3;
    controller.earthOrbs = 4;
    controller.notifyListeners();
    await tester.pump();
    final updatedBackpack = tester.widget<RpgBackpackIcon>(headerBackpackFinder);
    expect(updatedBackpack.ownedOrbs, equals(HandMove.values.toSet()));

    // All-zero inventory shows empty ownedOrbs set inside open bag
    controller.fireOrbs = 0;
    controller.waterOrbs = 0;
    controller.woodOrbs = 0;
    controller.earthOrbs = 0;
    controller.metalOrbs = 0;
    controller.notifyListeners();
    await tester.pump();
    final emptyBackpack = tester.widget<RpgBackpackIcon>(headerBackpackFinder);
    expect(emptyBackpack.ownedOrbs, isEmpty);
  });

  testWidgets('RpgBackpackIcon open mode renders cleanly across 0 to 5 owned orbs', (WidgetTester tester) async {
    for (int count = 0; count <= HandMove.values.length; count++) {
      final subset = HandMove.values.take(count).toSet();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RpgBackpackIcon(
                size: 86.0,
                isOpen: true,
                openProgress: 1.0,
                ambientGlowPhase: 0.4,
                ownedOrbs: subset,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(RpgBackpackIcon), findsOneWidget);
      expect(tester.getSize(find.byType(RpgBackpackIcon)), equals(const Size(86.0, 86.0)));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('InventoryDialog rows render 3D energy spheres without flat icons, clean titles, localized Active/Locked status across en/pt/es/de, and adapt to Dark and Light modes', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'orbs_fire': 47,
      'orbs_water': 8,
      'orbs_wood': 39,
      'orbs_earth': 0,
      'orbs_metal': 0,
      'showNewHands': false,
      'animationsEnabled': false,
    });
    final storage = StorageService();
    await storage.init();
    final localization = LocalizationService();
    await tester.runAsync(() => localization.load());
    final audio = AudioService();
    final controller = GameController(
      storage: storage,
      localization: localization,
      audio: audio,
    );
    addTearDown(controller.dispose);

    // 1. Dark Mode verification + English strings
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: InventoryDialog(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Clean titles without parenthesized element codes, 3D spheres without combat icons
    expect(find.text('Fire Orb'), findsOneWidget);
    expect(find.text('Water Orb'), findsOneWidget);
    expect(find.text('Wood Orb'), findsOneWidget);
    expect(find.text('Earth Orb'), findsOneWidget);
    expect(find.text('Metal Orb'), findsOneWidget);
    expect(find.textContaining('('), findsNWidgets(2)); // Only the 2 Locked hints use parentheses

    for (final move in HandMove.values) {
      final sphereFinder = find.byKey(ValueKey('inventory_orb_sphere_${move.orbKey}'));
      expect(sphereFinder, findsOneWidget);
      expect(tester.getSize(sphereFinder), equals(const Size(38.0, 38.0)));
      expect(
        find.descendant(
          of: find.byType(InventoryDialog),
          matching: find.byIcon(move.elementalIcon),
        ),
        findsNothing,
      );
    }

    expect(find.text('Active'), findsNWidgets(3));
    expect(find.text('Locked (Unlock Earth & Metal)'), findsNWidgets(2));
    expect(find.textContaining('in combat'), findsNothing);

    final darkCard = tester.widget<Container>(
      find.byKey(const ValueKey('inventory_dialog_card')),
    );
    final darkCardDecor = darkCard.decoration! as BoxDecoration;
    expect(darkCardDecor.color, equals(const Color(0xFF14161D)));

    // 2. Light Mode verification + localized strings across pt, es, de
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
          body: InventoryDialog(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lightCard = tester.widget<Container>(
      find.byKey(const ValueKey('inventory_dialog_card')),
    );
    final lightCardDecor = lightCard.decoration! as BoxDecoration;
    expect(lightCardDecor.color, equals(const Color(0xFFFAF6EE)));
    expect(
      tester.widget<Text>(find.text("Cleric's Backpack")).style?.color,
      equals(const Color(0xFF231F1A)),
    );

    const expectedByLang = <String, (String, String)>{
      'pt': ('Ativo', 'Bloqueado (Desbloquear Terra e Metal)'),
      'es': ('Activo', 'Bloqueado (Desbloquear Tierra y Metal)'),
      'de': ('Aktiv', 'Gesperrt (Erde & Metall freischalten)'),
    };

    for (final entry in expectedByLang.entries) {
      controller.setLanguage(entry.key);
      await tester.pumpAndSettle();
      final (expectedActive, expectedLocked) = entry.value;
      expect(find.text(expectedActive), findsNWidgets(3));
      expect(find.text(expectedLocked), findsNWidgets(2));
      expect(find.textContaining('combate'), findsNothing);
      expect(find.textContaining('Kampf'), findsNothing);
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('Gift Box Shop unlock, toggle ON/OFF, AppBar visibility, cooldown pause/resume, and localization', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'orbs_fire': 600,
      'orbs_water': 600,
      'orbs_wood': 600,
      'orbs_earth': 600,
      'orbs_metal': 600,
      'animationsEnabled': false,
      'musicEnabled': false,
    });
    final storage = StorageService();
    await storage.init();
    final localization = LocalizationService();
    await localization.load();
    final audio = AudioService();
    final controller = GameController(
      storage: storage,
      localization: localization,
      audio: audio,
    );

    // Verify all 4 localizations exist for Gift Box title and description
    for (final lang in ['en', 'pt', 'es', 'de']) {
      localization.setLanguage(lang);
      expect(localization.t('gift_box'), isNot('gift_box'));
      expect(localization.t('gift_box_desc'), isNot('gift_box_desc'));
      expect(localization.t('gift_box_desc'), contains('+5'));
    }
    localization.setLanguage('en');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const HowPredictableApp(home: GameScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Gift Box starts locked and hidden from AppBar
    expect(controller.giftBoxUnlocked, isFalse);
    expect(controller.giftBoxEnabled, isFalse);
    expect(find.byKey(const ValueKey('gift_box_button')), findsNothing);
    expect(find.text('🎁'), findsNothing);

    // 2. Open Shop and scroll to Gift Box
    await tester.tap(find.byKey(const ValueKey('backpack_inventory_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory_open_shop_button')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Gift Box'),
      200,
      scrollable: find.descendant(
        of: find.byType(ShopDialog),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.text('Gift Box'));
    await tester.pumpAndSettle();

    expect(find.text('Gift Box'), findsOneWidget);
    expect(
      find.textContaining('periodic 🎁 gift chest'),
      findsOneWidget,
    );
    // Gift Box costs 500 of each of the 5 elements
    final giftBoxTile = find.ancestor(
      of: find.text('Gift Box'),
      matching: find.byType(InkWell),
    );
    expect(
      find.descendant(of: giftBoxTile, matching: find.text('500')),
      findsNWidgets(5),
    );

    // 3. Purchase Gift Box in Shop -> deducts 500 of each element, starts disabled
    await tester.tap(find.text('Gift Box'));
    await tester.pumpAndSettle();

    expect(controller.giftBoxUnlocked, isTrue);
    expect(controller.giftBoxEnabled, isFalse);
    expect(controller.fireOrbs, 100);
    expect(controller.waterOrbs, 100);
    expect(controller.woodOrbs, 100);
    expect(controller.earthOrbs, 100);
    expect(controller.metalOrbs, 100);
    expect(find.byKey(const ValueKey('gift_box_button')), findsNothing);

    // 4. Toggle Gift Box ON in Shop
    await tester.tap(find.text('Gift Box'));
    await tester.pumpAndSettle();
    expect(controller.giftBoxEnabled, isTrue);

    // Close Shop -> Gift Box appears in AppBar
    await tester.tap(find.byKey(const ValueKey('shop_close_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gift_box_button')), findsOneWidget);
    expect(find.text('🎁'), findsOneWidget);

    // 5. Claim periodic gift in Phase 1 -> +5 Fire/Water/Wood (0 Earth/Metal), enters cooldown, hides button
    await tester.tap(find.byKey(const ValueKey('gift_box_button')));
    await tester.pump();
    expect(controller.fireOrbs, 105);
    expect(controller.waterOrbs, 105);
    expect(controller.woodOrbs, 105);
    expect(controller.earthOrbs, 100);
    expect(controller.metalOrbs, 100);
    expect(controller.isGiftAvailable, isFalse);
    expect(controller.isGiftTimerActive, isTrue);
    expect(find.byKey(const ValueKey('gift_box_button')), findsNothing);

    // 6. Toggle Gift Box OFF in Shop -> stops background timer cleanly
    await tester.tap(find.byKey(const ValueKey('backpack_inventory_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory_open_shop_button')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Gift Box'),
      200,
      scrollable: find.descendant(
        of: find.byType(ShopDialog),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.text('Gift Box'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gift Box'));
    await tester.pumpAndSettle();
    expect(controller.giftBoxEnabled, isFalse);
    expect(controller.isGiftTimerActive, isFalse);

    // Even after 1 minute passes while OFF, Gift Box stays disabled and hidden
    await tester.pump(const Duration(minutes: 1));
    expect(controller.isGiftAvailable, isFalse);
    expect(find.byKey(const ValueKey('gift_box_button')), findsNothing);

    // 7. Toggle back ON -> resumes periodic timer and makes 🎁 appear once ready
    await tester.tap(find.text('Gift Box'));
    await tester.pumpAndSettle();
    expect(controller.giftBoxEnabled, isTrue);
    expect(controller.isGiftTimerActive, isTrue);

    await tester.tap(find.byKey(const ValueKey('shop_close_button')));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(controller.isGiftAvailable, isTrue);
    expect(find.byKey(const ValueKey('gift_box_button')), findsOneWidget);
  });

  testWidgets(
    'ManaPoolOrb inside VersusArena counts down 100->99->98 in GameScreen, preserves pinned bottom buttons & ScoreHeader Total, and resets to 100',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        'unlockedPredictability': true,
        'showPredictability': true,
        'unlockedReset': true,
        'showReset': true,
        'musicEnabled': false,
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
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const HowPredictableApp(home: GameScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Pinned bottom move deck & VersusArena coordinates before any rounds
      final arenaFinder = find.byType(VersusArena);
      final moveCardFinder = find.byKey(const ValueKey('move_selection_card'));
      final rockBtnFinder = find.byKey(const ValueKey('hand_button_rock'));
      final initialArenaHeight = tester.getSize(arenaFinder).height;
      final initialMoveCardRect = tester.getRect(moveCardFinder);
      final initialRockRect = tester.getRect(rockBtnFinder);

      // Mana Pool Orb sits inside VersusArena directly above VS badge, starting at 100
      final manaOrbFinder = find.byKey(const ValueKey('mana_pool_orb'));
      final vsBadgeFinder = find.byKey(const ValueKey('vs_badge'));
      expect(
        find.descendant(of: arenaFinder, matching: manaOrbFinder),
        findsOneWidget,
      );
      expect(
        tester.getRect(manaOrbFinder).bottom,
        lessThanOrEqualTo(tester.getRect(vsBadgeFinder).top),
      );
      expect(
        find.descendant(of: manaOrbFinder, matching: find.text('100')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(ScoreHeader), matching: find.text('0')),
        findsWidgets,
      );

      // Round 1 (Win): Mana decrements 100 -> 99, ScoreHeader Total increments 0 -> 1
      controller.crystalBallMove = HandMove.scissors;
      await tester.tap(rockBtnFinder);
      await tester.pumpAndSettle();
      expect(controller.remainingMana, 99);
      expect(controller.totalRounds, 1);
      expect(
        find.descendant(of: manaOrbFinder, matching: find.text('99')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(ScoreHeader), matching: find.text('1')),
        findsWidgets,
      );

      // Round 2 (Loss): Mana decrements 99 -> 98, ScoreHeader Total increments 1 -> 2
      controller.crystalBallMove = HandMove.paper;
      await tester.tap(rockBtnFinder);
      await tester.pumpAndSettle();
      expect(controller.remainingMana, 98);
      expect(controller.totalRounds, 2);
      expect(
        find.descendant(of: manaOrbFinder, matching: find.text('98')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(ScoreHeader), matching: find.text('2')),
        findsOneWidget,
      );

      // VersusArena fixed height and pinned bottom move deck remain completely unaffected
      expect(tester.getSize(arenaFinder).height, equals(initialArenaHeight));
      expect(
        tester.getRect(moveCardFinder).bottom,
        equals(initialMoveCardRect.bottom),
      );

      // Trigger AppBar Reset -> shows -1 Wood loss, Mana Pool resets back to 100 and woodOrbs reverts to 0
      expect(controller.woodOrbs, 1);
      await tester.tap(find.byIcon(Icons.restart_alt));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reset_confirm_dialog')), findsOneWidget);
      expect(find.text('-1 Wood'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'RESET'));
      await tester.pumpAndSettle();

      expect(controller.remainingMana, 100);
      expect(controller.totalRounds, 0);
      expect(controller.woodOrbs, 0);
      expect(controller.userHp, 50);
      expect(controller.computerHp, 100);
      expect(
        find.descendant(of: manaOrbFinder, matching: find.text('100')),
        findsOneWidget,
      );
      expect(tester.getSize(arenaFinder).height, equals(initialArenaHeight));
      expect(tester.getRect(moveCardFinder), equals(initialMoveCardRect));
      expect(tester.getRect(rockBtnFinder), equals(initialRockRect));
    },
  );

  testWidgets(
    'Draw consumes 1 Mana (100 -> 99) with -1 indicator and 0 HP damage, keeps ScoreHeader Gauge fair, and reaches 0 at 100 total rounds',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        'unlockedPredictability': true,
        'showPredictability': true,
        'musicEnabled': false,
        'animationsEnabled': true,
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
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const HowPredictableApp(home: GameScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final manaOrbFinder = find.byKey(const ValueKey('mana_pool_orb'));
      final rockBtnFinder = find.byKey(const ValueKey('hand_button_rock'));

      // Round 1 (Draw): Mana decrements 100 -> 99, floating -1 indicator appears, Player HP stays 50, Gauge = 0.0%
      controller.crystalBallMove = HandMove.rock;
      await tester.tap(rockBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(controller.lastWinner, RoundWinner.draw);
      expect(controller.remainingMana, 99);
      expect(controller.totalRounds, 1);
      expect(controller.userHp, 50);
      expect(controller.computerHp, 100);
      expect(
        find.descendant(of: manaOrbFinder, matching: find.text('99')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: manaOrbFinder,
          matching: find.byKey(const ValueKey('mana_drain_indicator')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: manaOrbFinder, matching: find.text('-1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(ScoreHeader), matching: find.text('0.0%')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 650));

      // Round 2 (Win): Mana decrements 99 -> 98, Gauge = 100.0%
      controller.crystalBallMove = HandMove.scissors;
      await tester.tap(rockBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(controller.remainingMana, 98);
      expect(controller.totalRounds, 2);
      expect(controller.userHp, 50);
      expect(controller.computerHp, 99);
      expect(
        find.descendant(of: find.byType(ScoreHeader), matching: find.text('100.0%')),
        findsOneWidget,
      );

      // Round 3 (Draw): Mana decrements 98 -> 97, floating -1 shows, HP unchanged, Gauge stays 100.0% (not penalized)
      controller.crystalBallMove = HandMove.rock;
      await tester.tap(rockBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(controller.remainingMana, 97);
      expect(controller.totalRounds, 3);
      expect(controller.userHp, 50);
      expect(controller.computerHp, 99);
      expect(
        find.descendant(of: manaOrbFinder, matching: find.text('97')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: manaOrbFinder,
          matching: find.byKey(const ValueKey('mana_drain_indicator')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(ScoreHeader), matching: find.text('100.0%')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 650));

      // Advance to 99 total rounds (60 wins, 20 losses, 19 draws) and play a Draw on turn 100
      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        'unlockedPredictability': true,
        'showPredictability': true,
        'userScore': 60,
        'pcScore': 20,
        'total': 99,
        'musicEnabled': false,
        'animationsEnabled': false,
      });
      final storageAt99 = StorageService();
      await storageAt99.init();
      final controllerAt99 = GameController(
        storage: storageAt99,
        localization: LocalizationService(),
        audio: AudioService(),
      );
      addTearDown(controllerAt99.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controllerAt99,
          child: const HowPredictableApp(home: GameScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(controllerAt99.remainingMana, 1);
      controllerAt99.crystalBallMove = HandMove.rock;
      await tester.tap(find.byKey(const ValueKey('hand_button_rock')));
      await tester.pumpAndSettle();

      expect(controllerAt99.lastWinner, RoundWinner.draw);
      expect(controllerAt99.totalRounds, 100);
      expect(controllerAt99.remainingMana, 0);
      expect(
        find.descendant(of: manaOrbFinder, matching: find.text('0')),
        findsOneWidget,
      );
      // 100-round completion dialog fires with fair decisive win rate (60 / 80 = 75.0%)
      expect(
        find.byKey(const ValueKey('battle_return_to_map_button')),
        findsOneWidget,
      );
      expect(find.text('Return to Map'), findsOneWidget);
      expect(find.textContaining('75.0%'), findsWidgets);
    },
  );
}

class _SettingsTestPlayGamesClient implements PlayGamesClient {
  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'gustlarsentester';

  @override
  Future<String?> getPlayerID() async => 'a_2116013489197419559';

  @override
  Future<String?> saveGame({required String data, required String name}) async =>
      'success';

  @override
  Future<String?> loadGame({required String name}) async => null;
}

class _LayoutTestAdMobClient extends AdMobClient {
  @override
  Future<void> initialize() async {}

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
  Widget? buildBannerWidget() {
    return const SizedBox(
      key: ValueKey('test_banner_ad_widget'),
      width: 320,
      height: 50,
    );
  }

  @override
  void disposeBanner() {}

  @override
  Future<void> loadRewarded({
    required String adUnitId,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    onLoaded();
  }

  @override
  Future<bool> showRewarded({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onDismissed,
    required VoidCallback onFailedToShow,
  }) async {
    onUserEarnedReward();
    onDismissed();
    return true;
  }

  @override
  void disposeRewarded() {}
}
