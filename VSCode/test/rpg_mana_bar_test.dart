import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/views/widgets/mana_pool_orb.dart';
import 'package:how_predictable/views/widgets/rpg_mana_bar.dart';
import 'package:how_predictable/views/widgets/versus_arena.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RpgManaBar & VersusArena Integration Tests', () {
    testWidgets(
      'RpgManaBar renders horizontal crystal vial with rippling sine-wave liquid edge, micro-bubbles, glass sheen, crystal accent, and numeric readout',
      (WidgetTester tester) async {
        Future<void> pumpBar({
          required int remainingMana,
          int maxMana = 100,
          bool animationsEnabled = false,
        }) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: RpgManaBar(
                    remainingMana: remainingMana,
                    maxMana: maxMana,
                    animationsEnabled: animationsEnabled,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
        }

        RpgManaLiquidPainter readLiquidPainter() {
          final paint = tester.widget<CustomPaint>(
            find.byKey(const ValueKey('rpg_mana_liquid_paint')),
          );
          return paint.painter! as RpgManaLiquidPainter;
        }

        // Full mana (100 / 100)
        await pumpBar(remainingMana: 100);
        final rect = tester.getRect(find.byType(RpgManaBar));
        expect(rect.width, inInclusiveRange(100.0, 110.0));
        expect(rect.height, inInclusiveRange(16.0, 18.0));
        expect(find.text('100 / 100'), findsOneWidget);
        expect(find.byKey(const ValueKey('rpg_mana_crystal_icon')), findsOneWidget);
        expect(find.byKey(const ValueKey('rpg_mana_glass_paint')), findsOneWidget);

        final fullLiquid = readLiquidPainter();
        expect(fullLiquid.fillRatio, closeTo(1.0, 1e-4));
        expect(fullLiquid.hasLiquid, isTrue);
        expect(fullLiquid.hasMeniscus, isTrue);
        expect(
          fullLiquid.computeVisibleBubbles(const Size(102, 15)).length,
          inInclusiveRange(3, 4),
        );

        // Mid mana (50 / 100): vertical right edge follows a sine wave rather than a flat cut
        await pumpBar(remainingMana: 50);
        expect(find.text('50 / 100'), findsOneWidget);
        final halfLiquid = readLiquidPainter();
        expect(halfLiquid.fillRatio, closeTo(0.5, 1e-4));
        expect(halfLiquid.hasMeniscus, isTrue);
        final xTop = halfLiquid.waveEdgeXAt(2.0, const Size(102, 15));
        final xMid = halfLiquid.waveEdgeXAt(7.5, const Size(102, 15));
        expect(xTop, isNot(equals(xMid)));

        // Empty mana (0 / 100): no liquid, no meniscus, no bubbles
        await pumpBar(remainingMana: 0);
        expect(find.text('0 / 100'), findsOneWidget);
        final emptyLiquid = readLiquidPainter();
        expect(emptyLiquid.fillRatio, closeTo(0.0, 1e-4));
        expect(emptyLiquid.hasLiquid, isFalse);
        expect(emptyLiquid.hasMeniscus, isFalse);
        expect(emptyLiquid.computeVisibleBubbles(const Size(102, 15)), isEmpty);
      },
    );

    testWidgets(
      'RpgManaBar smoothly animates liquid fill over 300ms and continuously advances wavePhase',
      (WidgetTester tester) async {
        RpgManaLiquidPainter readLiquidPainter() {
          final paint = tester.widget<CustomPaint>(
            find.byKey(const ValueKey('rpg_mana_liquid_paint')),
          );
          return paint.painter! as RpgManaLiquidPainter;
        }

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: RpgManaBar(
                  remainingMana: 100,
                  maxMana: 100,
                  animationsEnabled: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final initialPhase = readLiquidPainter().wavePhase;

        await tester.pump(const Duration(milliseconds: 200));
        expect(readLiquidPainter().wavePhase, isNot(equals(initialPhase)));

        // Drain from 100 -> 80
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: RpgManaBar(
                  remainingMana: 80,
                  maxMana: 100,
                  animationsEnabled: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Halfway through 300ms ease-out tween
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('80 / 100'), findsOneWidget);
        final midRatio = readLiquidPainter().fillRatio;
        expect(midRatio, greaterThan(0.80));
        expect(midRatio, lessThan(1.0));

        // Settled at 300ms
        await tester.pump(const Duration(milliseconds: 150));
        expect(readLiquidPainter().fillRatio, closeTo(0.80, 1e-4));
      },
    );

    testWidgets(
      'RpgManaBar shifts border glow and liquid accent to arcane amber/violet pulse at <= 20% or <= 20 turns',
      (WidgetTester tester) async {
        Future<BoxDecoration> pumpAndReadFrame({
          required int mana,
          required int maxMana,
          int advanceMs = 150,
        }) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: RpgManaBar(
                    remainingMana: mana,
                    maxMana: maxMana,
                    animationsEnabled: true,
                  ),
                ),
              ),
            ),
          );
          await tester.pump(Duration(milliseconds: advanceMs));
          final frame = tester.widget<Container>(
            find.byKey(const ValueKey('rpg_mana_bar_frame')),
          );
          return frame.decoration! as BoxDecoration;
        }

        // Normal Mana (25 / 120 -> >20% and >20 turns): cyan outer glow
        final normalDecor = await pumpAndReadFrame(mana: 25, maxMana: 120);
        final normalShadow = normalDecor.boxShadow!.first;
        expect(normalShadow.color.r, lessThan(0.1));
        expect(normalShadow.color.b, greaterThan(0.9));

        // Low Mana by percentage (24 / 120 -> 20%): shifts to amber/violet pulse
        final lowPctDecor = await pumpAndReadFrame(mana: 24, maxMana: 120);
        final lowPctShadow = lowPctDecor.boxShadow!.first;
        expect(lowPctShadow.color.r, greaterThan(0.7));

        // Pulse animates blur radius over time
        await tester.pump(const Duration(milliseconds: 450));
        final pulsedFrame = tester.widget<Container>(
          find.byKey(const ValueKey('rpg_mana_bar_frame')),
        );
        final pulsedShadow = (pulsedFrame.decoration! as BoxDecoration).boxShadow!.first;
        expect(pulsedShadow.blurRadius, isNot(equals(lowPctShadow.blurRadius)));

        // Low Mana by absolute <= 20 turns (20 / 50 -> 40%, still <= 20 turns)
        final lowTurnDecor = await pumpAndReadFrame(mana: 20, maxMana: 50);
        expect(lowTurnDecor.boxShadow!.first.color.r, greaterThan(0.7));
        final liquidPainter = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('rpg_mana_liquid_paint')),
        ).painter! as RpgManaLiquidPainter;
        expect(liquidPainter.isLowMana, isTrue);
      },
    );

    testWidgets(
      'VersusArena renders RpgManaBar exclusively beneath Cleric HP bar (replacing PLAYER), keeps enemy side unchanged, and works in Dark and Light modes',
      (WidgetTester tester) async {
        final localization = LocalizationService();
        await localization.load();
        final clashKey = GlobalKey();

        for (final isDark in [true, false]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: isDark ? ThemeData.dark() : ThemeData.light(),
              home: Scaffold(
                body: SizedBox(
                  width: 390,
                  child: VersusArena(
                    userMove: HandMove.rock,
                    computerMove: HandMove.scissors,
                    winner: RoundWinner.user,
                    localization: localization,
                    animationsEnabled: false,
                    roundId: 1,
                    userHp: 45,
                    playerMaxHp: 50,
                    computerHp: 99,
                    computerMaxHp: 100,
                    remainingMana: 84,
                    maxMana: 100,
                    elementalMode: true,
                    clashCenterKey: clashKey,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(ManaPoolOrb), findsNothing);
          expect(find.byType(RpgManaBar), findsOneWidget);
          expect(find.text('PLAYER'), findsNothing);
          expect(find.text('GUARDIAN ROBOT'), findsOneWidget);
          expect(find.text('84 / 100'), findsOneWidget);

          final userHpRect = tester.getRect(find.byKey(const ValueKey('user_hp_bar')));
          final userManaRect = tester.getRect(find.byKey(const ValueKey('user_mana_bar')));
          final pcHpRect = tester.getRect(find.byKey(const ValueKey('pc_hp_bar')));
          final bossLabelRect = tester.getRect(
            find.byKey(const ValueKey('arena_boss_name_label')),
          );
          final clashRect = tester.getRect(find.byKey(clashKey));
          final arenaRect = tester.getRect(find.byType(VersusArena));

          // Mana bar matches HP bar width and sits directly beneath it
          expect(userManaRect.width, closeTo(userHpRect.width, 0.5));
          expect(userManaRect.left, closeTo(userHpRect.left, 0.5));
          expect(userManaRect.top, greaterThanOrEqualTo(userHpRect.bottom));

          // Enemy side retains HP bar + Boss Name aligned cleanly with player side
          expect(pcHpRect.top, closeTo(userHpRect.top, 0.5));
          expect(bossLabelRect.top, greaterThanOrEqualTo(pcHpRect.bottom));
          expect(clashRect.center.dx, closeTo(arenaRect.center.dx, 0.5));
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
