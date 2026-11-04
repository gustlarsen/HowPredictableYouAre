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

    // Advance partway through the 6-second animation (e.g., 1500ms)
    await tester.pump(const Duration(milliseconds: 1500));

    // Tap ROCK again mid-animation: should immediately increment turnCount and restart animation
    await tester.tap(find.text('ROCK'));
    await tester.pump();
    expect(controller.turnCount, 2);

    // Let the 6-second animation complete
    await tester.pump(const Duration(milliseconds: 6100));
  });

  testWidgets('VersusArena animates 3s forward, then simultaneous 3s return and 3s 360 rotation', (WidgetTester tester) async {
    final localization = LocalizationService();

    // Case 1: User wins (left hand moves right for 3s, then moves back for 3s while right hand rotates clockwise)
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

    // At 1500ms (1.5s): winning left hand is halfway over, beaten right hand has not rotated yet (angle == 0)
    await tester.pump(const Duration(milliseconds: 1500));
    Transform userTranslateAt1500ms = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('user_card')),
        matching: find.byType(Transform),
      ),
    );
    final dxAt1500ms = userTranslateAt1500ms.transform.getTranslation().x;

    Transform pcRotateAt1500ms = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('pc_card')),
        matching: find.byType(Transform),
      ),
    );
    expect(pcRotateAt1500ms.transform.storage[0], closeTo(1.0, 1e-3));
    expect(pcRotateAt1500ms.transform.storage[1], closeTo(0.0, 1e-3));

    // At 3000ms (3.0s): winning left hand reaches right hand (full targetDistance), rotation is just starting (angle == 0)
    await tester.pump(const Duration(milliseconds: 1500));
    Transform userTranslateAt3000ms = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('user_card')),
        matching: find.byType(Transform),
      ),
    );
    final maxDx = userTranslateAt3000ms.transform.getTranslation().x;
    expect(maxDx, greaterThan(100.0));
    expect(dxAt1500ms, closeTo(maxDx * 0.5, 1e-2));

    // At 3750ms (3.75s = 25% into the 3s backward + rotation phase):
    // Right hand should be at +90 degrees (+pi/2 clockwise: cos=0, sin=+1)
    // Left hand should be at 75% of maxDx moving back
    await tester.pump(const Duration(milliseconds: 750));
    Transform userTranslateAt3750ms = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('user_card')),
        matching: find.byType(Transform),
      ),
    );
    expect(userTranslateAt3750ms.transform.getTranslation().x, closeTo(maxDx * 0.75, 1e-2));

    Transform pcRotateAt3750ms = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('pc_card')),
        matching: find.byType(Transform),
      ),
    );
    // For +pi/2 (clockwise), Matrix4.rotationZ(+pi/2) has storage[0] = cos(pi/2) = 0, storage[1] = sin(pi/2) = +1
    expect(pcRotateAt3750ms.transform.storage[0], closeTo(math.cos(math.pi / 2), 1e-2));
    expect(pcRotateAt3750ms.transform.storage[1], closeTo(math.sin(math.pi / 2), 1e-2));

    // Finish the 6000ms animation
    await tester.pump(const Duration(milliseconds: 2250));

    // Case 2: PC wins (right hand moves left for 3s, then moves back for 3s while left hand rotates anti-clockwise)
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

    // Advance to 3750ms (25% into the 3s backward + rotation phase):
    // Left hand is beaten and should be at -90 degrees (-pi/2 anti-clockwise: cos=0, sin=-1)
    await tester.pump(const Duration(milliseconds: 3750));
    Transform userRotateAt3750ms = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('user_card')),
        matching: find.byType(Transform),
      ),
    );
    expect(userRotateAt3750ms.transform.storage[0], closeTo(math.cos(-math.pi / 2), 1e-2));
    expect(userRotateAt3750ms.transform.storage[1], closeTo(math.sin(-math.pi / 2), 1e-2));

    await tester.pump(const Duration(milliseconds: 2250));
  });
}
