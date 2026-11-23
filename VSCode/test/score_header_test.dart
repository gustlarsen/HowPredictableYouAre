import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/widgets/score_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameController> createController() async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'animationsEnabled': false,
      'unlockedPredictability': true,
      'showPredictability': true,
    });
    final storage = StorageService();
    await storage.init();
    return GameController(
      storage: storage,
      localization: LocalizationService(),
      audio: AudioService(),
    );
  }

  group('ScoreHeader Neutral Gauge Placeholder Tests', () {
    testWidgets(
      'Displays Gauge: --% in neutral color at 0-0 and after draws, then transitions to 100.0% green on player win (Dark & Light modes)',
      (WidgetTester tester) async {
        for (final isDark in [true, false]) {
          final controller = await createController();
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey(isDark),
              theme: isDark
                  ? ThemeData.dark(useMaterial3: true)
                  : ThemeData.light(useMaterial3: true),
              home: Scaffold(
                body: ListenableBuilder(
                  listenable: controller,
                  builder: (_, _) => ScoreHeader(controller: controller),
                ),
              ),
            ),
          );

          final expectedNeutral = isDark
              ? ScoreHeader.neutralSilver
              : ScoreHeader.lightNeutralSlate;
          final expectedGreen = isDark
              ? ScoreHeader.emeraldGreen
              : ScoreHeader.lightEmeraldGreen;

          // At 0-0 start of match, displays Gauge: --% in neutral color
          expect(find.text('Gauge:'), findsOneWidget);
          expect(find.text('--%'), findsOneWidget);
          expect(find.text('0.0%'), findsNothing);
          expect(
            tester.widget<Text>(find.text('Gauge:')).style?.color,
            expectedNeutral,
          );
          expect(
            tester.widget<Text>(find.text('--%')).style?.color,
            expectedNeutral,
          );

          // Draw only keeps playerScore + pcScore == 0, so --% stays neutral
          controller.crystalBallMove = HandMove.rock;
          controller.playTurn(HandMove.rock);
          await tester.pump();

          expect(controller.totalRounds, 1);
          expect(controller.userScore, 0);
          expect(controller.pcScore, 0);
          expect(find.text('--%'), findsOneWidget);
          expect(
            tester.widget<Text>(find.text('--%')).style?.color,
            expectedNeutral,
          );

          // Decisive player win transitions immediately to 100.0% in emerald green
          controller.crystalBallMove = HandMove.scissors;
          controller.playTurn(HandMove.rock);
          await tester.pump();

          expect(controller.userScore, 1);
          expect(find.text('--%'), findsNothing);
          expect(find.text('100.0%'), findsOneWidget);
          expect(
            tester.widget<Text>(find.text('Gauge:')).style?.color,
            expectedGreen,
          );
          expect(
            tester.widget<Text>(find.text('100.0%')).style?.color,
            expectedGreen,
          );
        }
      },
    );

    testWidgets(
      'Transitions from Gauge: --% at 0-0 to Gauge: 0.0% crimson red when PC scores first decisive point',
      (WidgetTester tester) async {
        for (final isDark in [true, false]) {
          final controller = await createController();
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey(isDark),
              theme: isDark
                  ? ThemeData.dark(useMaterial3: true)
                  : ThemeData.light(useMaterial3: true),
              home: Scaffold(
                body: ListenableBuilder(
                  listenable: controller,
                  builder: (_, _) => ScoreHeader(controller: controller),
                ),
              ),
            ),
          );

          expect(find.text('--%'), findsOneWidget);

          // PC wins first decisive round (0-1) -> Gauge: 0.0% in crimson red
          controller.crystalBallMove = HandMove.paper;
          controller.playTurn(HandMove.rock);
          await tester.pump();

          final expectedRed = isDark
              ? ScoreHeader.crimsonRed
              : ScoreHeader.lightCrimsonRed;

          expect(controller.pcScore, 1);
          expect(find.text('--%'), findsNothing);
          expect(find.text('0.0%'), findsOneWidget);
          expect(
            tester.widget<Text>(find.text('Gauge:')).style?.color,
            expectedRed,
          );
          expect(
            tester.widget<Text>(find.text('0.0%')).style?.color,
            expectedRed,
          );
        }
      },
    );
  });
}
