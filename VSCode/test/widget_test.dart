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

  testWidgets('App smoke test loads GameScreen and displays title', (WidgetTester tester) async {
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

    expect(find.text('How Predictable You Are'), findsOneWidget);
    expect(find.text('ROCK'), findsOneWidget);
    expect(find.text('PAPER'), findsOneWidget);
    expect(find.text('SCISSORS'), findsOneWidget);

    final controller = tester.element(find.text('How Predictable You Are')).read<GameController>();
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
}
