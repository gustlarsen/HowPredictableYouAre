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
import 'package:how_predictable/views/widgets/hints_bar.dart';
import 'package:how_predictable/views/widgets/score_header.dart';
import 'package:how_predictable/views/widgets/versus_arena.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test loads GameScreen and displays diamonds in AppBar', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
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

    expect(find.text('How Predictable You Are'), findsNothing);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('0')), findsOneWidget);
    expect(find.text('ROCK'), findsOneWidget);
    expect(find.text('PAPER'), findsOneWidget);
    expect(find.text('SCISSORS'), findsOneWidget);

    final controller = tester.element(find.text('ROCK')).read<GameController>();
    expect(controller.turnCount, 0);

    // Tap ROCK and verify immediate response without waiting for button animation
    await tester.tap(find.text('ROCK').last);
    await tester.pump();
    expect(controller.turnCount, 1);

    // Advance partway through the 1000ms animation (e.g., 250ms)
    await tester.pump(const Duration(milliseconds: 250));

    // Tap ROCK again mid-animation: should immediately increment turnCount and restart animation
    await tester.tap(find.text('ROCK').last);
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

    // Verify updated labels and single AppBar reset button
    expect(find.text('You will Chose:'), findsOneWidget);
    expect(find.text('PC will Chose:'), findsOneWidget);
    expect(find.text('PC Chose'), findsOneWidget);
    expect(find.text('The winner of this round:'), findsOneWidget);
    expect(find.text('The winner of this round::'), findsNothing);
    expect(find.byIcon(Icons.restart_alt), findsOneWidget);
    expect(find.byKey(const ValueKey('appbar_story_gallery_button')), findsNothing);

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
      'has_seen_story_intro': true,
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

    // Scroll down further to reveal the newly added Crystal Ball+ tile in the ListView
    await tester.drag(find.byType(ListView), const Offset(0, -300));
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

  testWidgets('Attempting to purchase an item without enough diamonds only shows notification and gives no free diamonds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'diamonds': 20,
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

    // Attempt to unlock the first item (Reset Button, cost: 100) with only 20 diamonds
    await tester.tap(find.text('Unlock').first);
    await tester.pump();

    expect(find.text('Not enough Diamonds'), findsOneWidget);
    expect(find.text('+50 💎'), findsNothing);
    expect(find.byType(SnackBarAction), findsNothing);
    expect(controller.diamonds, 20);
    expect(controller.unlockedReset, isFalse);
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

  testWidgets('Unlocking an item in ShopDialog triggers its comic cutscene once and Story Gallery allows re-reading unlocked chapters', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'diamonds': 1000,
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

    // Open ShopDialog and unlock Reset Button (first item)
    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unlock').first);
    await tester.pumpAndSettle();

    // Reset Button comic cutscene should open immediately
    expect(find.text('Chapter I: The Hourglass of Oblivion'), findsOneWidget);
    expect(storage.hasSeenStoryReset, isTrue);

    // Skip the cutscene
    await tester.tap(find.byKey(const ValueKey('story_skip_button')));
    await tester.pumpAndSettle();
    expect(find.text('Chapter I: The Hourglass of Oblivion'), findsNothing);

    // Toggling the Reset switch off and on in the shop should NOT re-trigger the comic
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('Chapter I: The Hourglass of Oblivion'), findsNothing);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('Chapter I: The Hourglass of Oblivion'), findsNothing);

    // Close ShopDialog
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Open SettingsDialog and open Story Memories gallery
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings_story_memories_button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings_story_memories_button')));
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

  testWidgets('ScoreHeader displays Gauge column inside scoreboard card with red-yellow-green heatmap color', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'unlockedPredictability': true,
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
        child: const HowPredictableApp(),
      ),
    );

    // When disabled, Gauge column is not shown
    expect(find.descendant(of: find.byType(ScoreHeader), matching: find.text('Gauge')), findsNothing);

    // Enable predictability gauge
    controller.toggleShowPredictability(true);
    await tester.pump();

    // Gauge column is inside the ScoreHeader Card alongside You, PC, Total
    final scoreCardFinder = find.descendant(
      of: find.byType(ScoreHeader),
      matching: find.byType(Card),
    );
    expect(scoreCardFinder, findsOneWidget);
    expect(find.descendant(of: scoreCardFinder, matching: find.text('You')), findsOneWidget);
    expect(find.descendant(of: scoreCardFinder, matching: find.text('PC')), findsOneWidget);
    expect(find.descendant(of: scoreCardFinder, matching: find.text('Total')), findsOneWidget);
    expect(find.descendant(of: scoreCardFinder, matching: find.text('Gauge')), findsOneWidget);
    expect(find.descendant(of: scoreCardFinder, matching: find.text('0.0%')), findsOneWidget);

    // Verify heatmap color progression:
    // 1. User has no wins (0% score, bad result) -> Pure Red
    controller.userScore = 0;
    controller.pcScore = 10;
    controller.totalRounds = 10;
    controller.notifyListeners();
    await tester.pump();

    Text gaugeValueText = tester.widget<Text>(
      find.descendant(of: scoreCardFinder, matching: find.text('0.0%')),
    );
    expect(gaugeValueText.style?.color, equals(Colors.red));

    // 2. PC has more wins (25% score) -> Between Red and Yellow
    controller.userScore = 1;
    controller.pcScore = 3;
    controller.totalRounds = 4;
    controller.notifyListeners();
    await tester.pump();

    gaugeValueText = tester.widget<Text>(
      find.descendant(of: scoreCardFinder, matching: find.text('25.0%')),
    );
    expect(
      gaugeValueText.style?.color,
      equals(Color.lerp(Colors.red, Colors.yellow, 0.5)),
    );

    // 3. Draw (50% score) -> Yellow in the middle
    controller.userScore = 5;
    controller.pcScore = 5;
    controller.totalRounds = 10;
    controller.notifyListeners();
    await tester.pump();

    gaugeValueText = tester.widget<Text>(
      find.descendant(of: scoreCardFinder, matching: find.text('50.0%')),
    );
    expect(gaugeValueText.style?.color, equals(Colors.yellow));

    // 4. User has more wins (75% score) -> Between Yellow and Green
    controller.userScore = 3;
    controller.pcScore = 1;
    controller.totalRounds = 4;
    controller.notifyListeners();
    await tester.pump();

    gaugeValueText = tester.widget<Text>(
      find.descendant(of: scoreCardFinder, matching: find.text('75.0%')),
    );
    expect(
      gaugeValueText.style?.color,
      equals(Color.lerp(Colors.yellow, Colors.green, 0.5)),
    );

    // 5. User has all wins (100% score, good result) -> Pure Green
    controller.userScore = 10;
    controller.pcScore = 0;
    controller.totalRounds = 10;
    controller.notifyListeners();
    await tester.pump();

    gaugeValueText = tester.widget<Text>(
      find.descendant(of: scoreCardFinder, matching: find.text('100.0%')),
    );
    expect(gaugeValueText.style?.color, equals(Colors.green));
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
        child: const HowPredictableApp(),
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

    // Activate New Hands (5 hands total)
    expect(controller.unlockNewHands(), isTrue);
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

    // Deactivate New Hands -> 3 classic hands restore their exact old size
    controller.toggleShowNewHands(false);
    await tester.pump();

    expect(lizardFinder, findsNothing);
    expect(spockFinder, findsNothing);
    expect(tester.getSize(rockFinder), equals(classicRockSize));
    expect(tester.getSize(paperFinder), equals(classicPaperSize));
    expect(tester.getSize(scissorsFinder), equals(classicScissorsSize));
  });

  testWidgets('Enabling/disabling New Hands prompts to reset game only when a hand has been chosen, supporting cancel and confirm', (WidgetTester tester) async {
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
        child: const HowPredictableApp(),
      ),
    );

    // 1. At the beginning of the game (no hand chosen yet):
    // Toggling New Hands in ShopDialog does NOT ask to reset the game
    expect(controller.hasGameStarted, isFalse);
    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Hands (Lizard & Spock)'));
    await tester.pumpAndSettle();

    // No RESET confirmation dialog should appear; New Hands is enabled immediately
    expect(find.text('This will clear your scores and prediction history.'), findsNothing);
    expect(controller.showNewHands, isTrue);

    // Disabling New Hands while still at the beginning also does NOT ask to reset
    await tester.tap(find.text('New Hands (Lizard & Spock)'));
    await tester.pumpAndSettle();
    expect(find.text('This will clear your scores and prediction history.'), findsNothing);
    expect(controller.showNewHands, isFalse);

    // Close ShopDialog and play a hand so the game is no longer at the beginning
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ROCK'));
    await tester.pumpAndSettle();
    expect(controller.turnCount, 1);
    expect(controller.hasGameStarted, isTrue);

    // 2. Open ShopDialog and press New Hands to enable it while game is in progress
    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Hands (Lizard & Spock)'));
    await tester.pumpAndSettle();

    // Reset confirmation dialog must appear
    expect(find.text('This will clear your scores and prediction history.'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('RESET'), findsOneWidget);

    // 3. Cancel the dialog -> keeps the current game and keeps 3 hands (showNewHands == false)
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.showNewHands, isFalse);
    expect(controller.turnCount, 1);
    expect(controller.currentUserMove, HandMove.rock);
    expect(controller.hasGameStarted, isTrue);

    // 4. Press New Hands again and confirm RESET -> enables 5 hands AND resets the game
    await tester.tap(find.text('New Hands (Lizard & Spock)'));
    await tester.pumpAndSettle();
    expect(find.text('This will clear your scores and prediction history.'), findsOneWidget);

    await tester.tap(find.text('RESET'));
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
    // disabling New Hands now does NOT ask to reset the game
    await tester.tap(find.text('New Hands (Lizard & Spock)'));
    await tester.pumpAndSettle();
    expect(find.text('This will clear your scores and prediction history.'), findsNothing);
    expect(controller.showNewHands, isFalse);
  });
}
