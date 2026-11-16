import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/views/widgets/rpg_hp_bar.dart';
import 'package:how_predictable/views/widgets/versus_arena.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RPG HP Bar & Battle Arena Visual Tests', () {
    testWidgets('RpgHpBar renders frame, numeric label, and tiny heart icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RpgHpBar(
                hp: 100,
                maxHp: 100,
              ),
            ),
          ),
        ),
      );

      // Verifies numeric label "HP 100" and heart icon
      expect(find.text('HP 100'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      // Frame has dark semi-transparent container with border
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(RpgHpBar),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(4.0));
      expect(decoration.border, isNotNull);
    });

    testWidgets('RpgHpBar triggers pulsing glow when in critical zone (< 30% HP)', (
      WidgetTester tester,
    ) async {
      // Normal HP (>= 30): No pulsing red glow
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RpgHpBar(
                hp: 75,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final normalContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(RpgHpBar),
          matching: find.byType(Container).first,
        ),
      );
      final normalDecor = normalContainer.decoration as BoxDecoration;
      final normalShadows = normalDecor.boxShadow!;
      expect(normalShadows.first.color, Colors.black54);

      // Critical HP (< 30): Red pulsing glow shadow is active
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RpgHpBar(
                hp: 25,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final critContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(RpgHpBar),
          matching: find.byType(Container).first,
        ),
      );
      final critDecor = critContainer.decoration as BoxDecoration;
      final critShadows = critDecor.boxShadow!;
      // Critical shadow uses red accent
      expect(critShadows.first.color.r, greaterThan(0.8));
    });

    testWidgets('VersusArena renders sleek HP bars below both user and computer hands', (
      WidgetTester tester,
    ) async {
      final localization = LocalizationService();

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
                animationsEnabled: false,
                roundId: 1,
                userHp: 100,
                computerHp: 95,
              ),
            ),
          ),
        ),
      );

      // Both user and computer HP bars are present with their designated keys
      expect(find.byKey(const ValueKey('user_hp_bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('pc_hp_bar')), findsOneWidget);

      expect(find.text('HP 100'), findsOneWidget);
      expect(find.text('HP 95'), findsOneWidget);
    });

    testWidgets('Damaged hand triggers micro-shake, flash, and floating damage indicator (-1)', (
      WidgetTester tester,
    ) async {
      final localization = LocalizationService();

      // Case: User wins (Computer takes damage)
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
                userHp: 100,
                computerHp: 99,
              ),
            ),
          ),
        ),
      );

      // At t = 0ms: Animation starts, winning punch travels
      await tester.pump();
      expect(find.byKey(const ValueKey('pc_damage_indicator')), findsNothing);

      // At t = 250ms: Still traveling to target
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('pc_damage_indicator')), findsNothing);

      // At t = 625ms (impact occurred at 500ms):
      // The floating damage indicator '-1' is visible and active on the beaten PC hand
      await tester.pump(const Duration(milliseconds: 375));
      expect(find.byKey(const ValueKey('pc_damage_indicator')), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);

      // Winning user hand did not take damage and does not have an indicator
      expect(find.byKey(const ValueKey('user_damage_indicator')), findsNothing);

      // Finish the 1000ms animation
      await tester.pump(const Duration(milliseconds: 375));
    });
  });
}
