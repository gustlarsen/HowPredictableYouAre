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

    testWidgets(
      'Classic Hands mode (elementalMode: false) performs hand-lunge animation with zero projectiles launched',
      (WidgetTester tester) async {
        final localization = LocalizationService();
        int impactHapticCount = 0;

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
                  elementalMode: false,
                  onImpactHaptic: () => impactHapticCount++,
                ),
              ),
            ),
          ),
        );

        BattleVfxPainter getPainter() {
          final customPaint = tester.widget<CustomPaint>(
            find.byKey(const ValueKey('versus_battle_vfx_layer')),
          );
          return customPaint.painter! as BattleVfxPainter;
        }

        // Start at t = 0ms
        await tester.pump();
        expect(getPainter().isAnimating, isFalse);
        expect(getPainter().phase, BattleVfxPhase.idle);

        // At t = 250ms: winning hand lunges halfway across arena; zero projectiles launched
        await tester.pump(const Duration(milliseconds: 250));
        expect(getPainter().isAnimating, isFalse);
        expect(getPainter().phase, BattleVfxPhase.idle);
        expect(getPainter().leftProjectilePosition, isNull);
        expect(getPainter().rightProjectilePosition, isNull);

        final userTranslateAt250 = tester.widget<Transform>(
          find.descendant(
            of: find.byKey(const ValueKey('user_card')),
            matching: find.byType(Transform),
          ),
        );
        expect(userTranslateAt250.transform.getTranslation().x, greaterThan(50.0));

        // At t = 500ms: winning hand reaches full lunge distance over losing hand; still zero projectiles
        await tester.pump(const Duration(milliseconds: 250));
        expect(getPainter().isAnimating, isFalse);
        expect(getPainter().phase, BattleVfxPhase.idle);
        final userTranslateAt500 = tester.widget<Transform>(
          find.descendant(
            of: find.byKey(const ValueKey('user_card')),
            matching: find.byType(Transform),
          ),
        );
        expect(
          userTranslateAt500.transform.getTranslation().x,
          greaterThan(userTranslateAt250.transform.getTranslation().x),
        );

        // At t = 625ms: winning hand returns while beaten hand rotates and shows classic impact flash/shake/-1
        await tester.pump(const Duration(milliseconds: 125));
        expect(getPainter().isAnimating, isFalse);
        expect(find.byKey(const ValueKey('pc_damage_indicator')), findsOneWidget);
        expect(impactHapticCount, 0);

        // Finish 1000ms classic animation
        await tester.pump(const Duration(milliseconds: 375));
      },
    );

    testWidgets(
      'Elemental Orbs mode (elementalMode: true) keeps orbs completely stationary while projectiles progress through Launch (0-300ms), Clash/Surge (300-550ms), and Impact Explosion (550-750ms)',
      (WidgetTester tester) async {
        final localization = LocalizationService();
        int impactHapticCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: VersusArena(
                  userMove: HandMove.rock, // Fire
                  computerMove: HandMove.scissors, // Wood
                  winner: RoundWinner.user,
                  localization: localization,
                  animationsEnabled: true,
                  roundId: 1,
                  userHp: 100,
                  computerHp: 99,
                  elementalMode: true,
                  onImpactHaptic: () => impactHapticCount++,
                ),
              ),
            ),
          ),
        );

        BattleVfxPainter getPainter() {
          final customPaint = tester.widget<CustomPaint>(
            find.byKey(const ValueKey('versus_battle_vfx_layer')),
          );
          return customPaint.painter! as BattleVfxPainter;
        }

        final initialUserOrbCenter = tester.getCenter(
          find.byKey(const ValueKey('user_orb_container')),
        );
        final initialPcOrbCenter = tester.getCenter(
          find.byKey(const ValueKey('pc_orb_container')),
        );

        // Start frame at t = 0ms
        await tester.pump();

        // Phase 1 — Launch (at 150ms, halfway to center)
        await tester.pump(const Duration(milliseconds: 150));
        // Both orbs remain completely stationary in their base positions (no lunge Transform)
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('user_card')),
            matching: find.byType(Transform),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('pc_card')),
            matching: find.byType(Transform),
          ),
          findsNothing,
        );
        expect(
          tester.getCenter(find.byKey(const ValueKey('user_orb_container'))),
          equals(initialUserOrbCenter),
        );
        expect(
          tester.getCenter(find.byKey(const ValueKey('pc_orb_container'))),
          equals(initialPcOrbCenter),
        );

        final painterAt150 = getPainter();
        expect(painterAt150.isAnimating, isTrue);
        expect(painterAt150.phase, BattleVfxPhase.launch);
        expect(painterAt150.leftElement, BattleVfxElement.fire);
        expect(painterAt150.rightElement, BattleVfxElement.wood);
        expect(painterAt150.leftProjectilePosition, isNotNull);
        expect(painterAt150.rightProjectilePosition, isNotNull);
        expect(
          painterAt150.leftProjectilePosition!.dx,
          greaterThan(painterAt150.leftCenterX),
        );
        expect(
          painterAt150.leftProjectilePosition!.dx,
          lessThan(painterAt150.centerX),
        );
        expect(
          painterAt150.rightProjectilePosition!.dx,
          lessThan(painterAt150.rightCenterX),
        );
        expect(
          painterAt150.rightProjectilePosition!.dx,
          greaterThan(painterAt150.centerX),
        );
        expect(impactHapticCount, 0);

        // Phase 2 — Mid-Arena Clash & Winning Surge (at 425ms, between 300ms and 550ms)
        await tester.pump(const Duration(milliseconds: 275));
        final painterAt425 = getPainter();
        expect(painterAt425.phase, BattleVfxPhase.clash);
        // Winning left projectile surges past center toward right stationary orb; losing right projectile shattered
        expect(painterAt425.leftProjectilePosition, isNotNull);
        expect(
          painterAt425.leftProjectilePosition!.dx,
          greaterThan(painterAt425.centerX),
        );
        expect(
          painterAt425.leftProjectilePosition!.dx,
          lessThan(painterAt425.rightCenterX),
        );
        expect(painterAt425.rightProjectilePosition, isNull);
        expect(
          tester.getCenter(find.byKey(const ValueKey('user_orb_container'))),
          equals(initialUserOrbCenter),
        );
        expect(impactHapticCount, 0);

        // Phase 3 — Impact Explosion (at 600ms, between 550ms and 750ms)
        await tester.pump(const Duration(milliseconds: 175));
        final painterAt600 = getPainter();
        expect(painterAt600.phase, BattleVfxPhase.impact);
        expect(impactHapticCount, 1);
        expect(find.byKey(const ValueKey('pc_damage_indicator')), findsOneWidget);

        // At 750ms, VFX animation finishes cleanly
        await tester.pump(const Duration(milliseconds: 150));
        final painterAt750 = getPainter();
        expect(painterAt750.isAnimating, isFalse);
        expect(painterAt750.phase, BattleVfxPhase.idle);
      },
    );

    testWidgets(
      'Elemental Orbs tie round shatters both projectiles at center at 300ms while orbs stay stationary, and rapid taps across all 5 elements reset cleanly',
      (WidgetTester tester) async {
        final localization = LocalizationService();
        int hapticTriggers = 0;

        // 1. Tie round in Elemental Mode (elementalMode: true)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: VersusArena(
                  userMove: HandMove.paper, // Water
                  computerMove: HandMove.paper, // Water
                  winner: RoundWinner.draw,
                  localization: localization,
                  animationsEnabled: true,
                  roundId: 1,
                  elementalMode: true,
                  onImpactHaptic: () => hapticTriggers++,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Orbs do not rotate or lunge on a tie in Elemental Mode
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('user_card')),
            matching: find.byType(Transform),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('pc_card')),
            matching: find.byType(Transform),
          ),
          findsNothing,
        );

        final tiePainter = tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('versus_battle_vfx_layer')),
            )
            .painter! as BattleVfxPainter;
        expect(tiePainter.leftElement, BattleVfxElement.water);
        expect(tiePainter.rightElement, BattleVfxElement.water);
        // On a tie after 300ms, both projectiles have shattered at the center
        expect(tiePainter.leftProjectilePosition, isNull);
        expect(tiePainter.rightProjectilePosition, isNull);
        expect(hapticTriggers, 1);

        // 2. Rapidly trigger new rounds across all 5 Elemental moves (Earth vs Water, Metal vs Wood) mid-animation
        final matchups = <(HandMove, HandMove, RoundWinner)>[
          (HandMove.lizard, HandMove.paper, RoundWinner.user), // Earth beats Water
          (HandMove.scissors, HandMove.spock, RoundWinner.computer), // Metal beats Wood
        ];

        int roundId = 2;
        for (final (uMove, cMove, win) in matchups) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 320,
                  child: VersusArena(
                    userMove: uMove,
                    computerMove: cMove,
                    winner: win,
                    localization: localization,
                    animationsEnabled: true,
                    roundId: roundId++,
                    elementalMode: true,
                    onImpactHaptic: () => hapticTriggers++,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 120)); // Launch phase
          await tester.pump(const Duration(milliseconds: 280)); // Clash phase (400ms)
          await tester.pump(const Duration(milliseconds: 220)); // Impact phase (620ms)
        }

        // Let final round animation settle cleanly (ManaPoolOrb wave runs continuously)
        await tester.pump(const Duration(milliseconds: 800));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
