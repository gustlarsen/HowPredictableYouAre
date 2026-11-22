import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/views/widgets/mana_pool_orb.dart';
import 'package:how_predictable/views/widgets/versus_arena.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ManaPoolOrb & VersusArena Integration Tests', () {
    testWidgets(
      'ManaPoolOrb renders compact ornate RPG crystal orb with wavy liquid CustomPainter, meniscus, bubbles, remaining value, and localized MANA labels',
      (WidgetTester tester) async {
        final localization = LocalizationService();
        await localization.load();

        Future<void> pumpOrb({
          required int mana,
          required String lang,
        }) async {
          localization.setLanguage(lang);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: ManaPoolOrb(
                    remainingMana: mana,
                    localization: localization,
                    animationsEnabled: false,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
        }

        ManaPoolLiquidPainter readLiquidPainter() {
          final paint = tester.widget<CustomPaint>(
            find.byKey(const ValueKey('mana_liquid_paint')),
          );
          return paint.painter! as ManaPoolLiquidPainter;
        }

        // English at 100 Mana
        await pumpOrb(mana: 100, lang: 'en');
        expect(find.text('100'), findsOneWidget);
        expect(find.text('MANA'), findsOneWidget);

        final orbRect = tester.getRect(find.byType(ManaPoolOrb));
        expect(orbRect.width, inInclusiveRange(44.0, 48.0));
        expect(orbRect.height, inInclusiveRange(44.0, 48.0));
        expect(orbRect.width, equals(orbRect.height));

        // Ornate frame painter and 3D glass highlight painter are mounted
        final framePaint = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('mana_orb_frame_paint')),
        );
        expect(framePaint.painter, isA<ManaPoolFramePainter>());
        final glassPaint = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('mana_glass_highlight_paint')),
        );
        expect(glassPaint.painter, isA<ManaPoolGlassPainter>());

        final fullLiquid = readLiquidPainter();
        expect(fullLiquid.fillRatio, closeTo(1.0, 1e-4));
        expect(fullLiquid.hasLiquid, isTrue);
        expect(fullLiquid.hasMeniscus, isTrue);
        expect(
          fullLiquid.computeVisibleBubbles(const Size(38, 38)).length,
          inInclusiveRange(3, 4),
        );

        // Portuguese at 50 Mana
        await pumpOrb(mana: 50, lang: 'pt');
        expect(find.text('50'), findsOneWidget);
        expect(find.text('MANA'), findsOneWidget);
        final halfLiquid = readLiquidPainter();
        expect(halfLiquid.fillRatio, closeTo(0.5, 1e-4));
        expect(halfLiquid.hasMeniscus, isTrue);
        // Sine-wave surface varies across x rather than remaining flat
        final yLeft = halfLiquid.surfaceYAt(4.0, const Size(38, 38));
        final yRight = halfLiquid.surfaceYAt(14.0, const Size(38, 38));
        expect(yLeft, isNot(equals(yRight)));

        // Spanish at 25 Mana
        await pumpOrb(mana: 25, lang: 'es');
        expect(find.text('25'), findsOneWidget);
        expect(find.text('MANÁ'), findsOneWidget);

        // German at 0 Mana
        await pumpOrb(mana: 0, lang: 'de');
        expect(find.text('0'), findsOneWidget);
        expect(find.text('MANA'), findsOneWidget);
        final emptyLiquid = readLiquidPainter();
        expect(emptyLiquid.fillRatio, closeTo(0.0, 1e-4));
        expect(emptyLiquid.hasLiquid, isFalse);
        expect(emptyLiquid.hasMeniscus, isFalse);
        expect(emptyLiquid.computeVisibleBubbles(const Size(38, 38)), isEmpty);
      },
    );

    testWidgets(
      'ManaPoolOrb smoothly drains wavy liquid over 300ms, advances wave phase, and shows floating cyan -1 indicator when Mana decreases',
      (WidgetTester tester) async {
        final localization = LocalizationService();

        ManaPoolLiquidPainter readLiquidPainter() {
          final paint = tester.widget<CustomPaint>(
            find.byKey(const ValueKey('mana_liquid_paint')),
          );
          return paint.painter! as ManaPoolLiquidPainter;
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ManaPoolOrb(
                  remainingMana: 100,
                  localization: localization,
                  animationsEnabled: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('mana_drain_indicator')), findsNothing);
        final initialWavePhase = readLiquidPainter().wavePhase;

        // Advance 200ms: continuous sine-wave motion advances wavePhase smoothly
        await tester.pump(const Duration(milliseconds: 200));
        expect(readLiquidPainter().wavePhase, isNot(equals(initialWavePhase)));

        // Decrement by 1 -> 99
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ManaPoolOrb(
                  remainingMana: 99,
                  localization: localization,
                  animationsEnabled: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Advance 150ms into the ~300ms drain & 550ms floating -1 indicator
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('99'), findsOneWidget);
        expect(find.byKey(const ValueKey('mana_drain_indicator')), findsOneWidget);
        expect(find.text('-1'), findsOneWidget);

        final earlyY = tester
            .getTopLeft(find.byKey(const ValueKey('mana_drain_indicator')))
            .dy;
        final midFill = readLiquidPainter().fillRatio;
        expect(midFill, greaterThan(0.99));
        expect(midFill, lessThan(1.0));

        // Advance another 150ms (total 300ms): liquid finishes draining, -1 drifts higher upward
        await tester.pump(const Duration(milliseconds: 150));
        final laterY = tester
            .getTopLeft(find.byKey(const ValueKey('mana_drain_indicator')))
            .dy;
        expect(laterY, lessThan(earlyY));

        final settledFill = readLiquidPainter().fillRatio;
        expect(settledFill, closeTo(0.99, 1e-4));

        // Finish 550ms indicator fade-out animation (300ms + 300ms = 600ms)
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('mana_drain_indicator')), findsNothing);

        // Resetting Mana back up to 100 does NOT trigger a -1 indicator
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ManaPoolOrb(
                  remainingMana: 100,
                  localization: localization,
                  animationsEnabled: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.byKey(const ValueKey('mana_drain_indicator')), findsNothing);
      },
    );

    testWidgets(
      'ManaPoolOrb shifts glow & border toward urgent arcane amber/violet pulse when remainingMana <= 20',
      (WidgetTester tester) async {
        final localization = LocalizationService();

        // Normal Mana (21): cyan-gold ring and cyan outer glow
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ManaPoolOrb(
                  remainingMana: 21,
                  localization: localization,
                  animationsEnabled: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final normalFrame = tester.widget<Container>(
          find.byKey(const ValueKey('mana_pool_orb_frame')),
        );
        final normalDecor = normalFrame.decoration! as BoxDecoration;
        final normalShadow = normalDecor.boxShadow!.first;
        // Normal primary shadow is cyan (#00E5FF) -> low red, high blue/green
        expect(normalShadow.color.r, lessThan(0.1));
        expect(normalShadow.color.b, greaterThan(0.9));

        // Low Mana (20): shifts toward urgent arcane amber/violet pulse
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ManaPoolOrb(
                  remainingMana: 20,
                  localization: localization,
                  animationsEnabled: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final lowFrameAt200 = tester.widget<Container>(
          find.byKey(const ValueKey('mana_pool_orb_frame')),
        );
        final lowDecorAt200 = lowFrameAt200.decoration! as BoxDecoration;
        final lowShadowAt200 = lowDecorAt200.boxShadow!.first;
        // Amber/violet pulse has high red component unlike pure cyan
        expect(lowShadowAt200.color.r, greaterThan(0.7));

        await tester.pump(const Duration(milliseconds: 450));
        final lowFrameAt650 = tester.widget<Container>(
          find.byKey(const ValueKey('mana_pool_orb_frame')),
        );
        final lowDecorAt650 = lowFrameAt650.decoration! as BoxDecoration;
        final lowShadowAt650 = lowDecorAt650.boxShadow!.first;
        expect(lowShadowAt650.blurRadius, isNot(equals(lowShadowAt200.blurRadius)));

        final lowFramePainter = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('mana_orb_frame_paint')),
        ).painter! as ManaPoolFramePainter;
        expect(lowFramePainter.isLowMana, isTrue);

        final lowLiquidPainter = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('mana_liquid_paint')),
        ).painter! as ManaPoolLiquidPainter;
        expect(lowLiquidPainter.isLowMana, isTrue);
        expect(lowLiquidPainter.fillRatio, closeTo(0.20, 1e-4));
        expect(lowLiquidPainter.hasMeniscus, isTrue);
      },
    );

    testWidgets(
      'ManaPoolOrb sits centrally near the top of VersusArena without a VS badge and preserves exact fixed arena height',
      (WidgetTester tester) async {
        final localization = LocalizationService();
        await localization.load();

        Future<double> pumpArena({
          required int mana,
          HandMove? userMove,
          HandMove? computerMove,
          RoundWinner? winner,
          int roundId = 0,
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
                    remainingMana: mana,
                    elementalMode: true,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          return tester.getSize(find.byType(VersusArena)).height;
        }

        final heightAt100 = await pumpArena(mana: 100);
        final arenaRect = tester.getRect(find.byType(VersusArena));
        final manaOrbRect = tester.getRect(find.byKey(const ValueKey('mana_pool_orb')));
        final userLabelRect = tester.getRect(find.text('You Chose:'));
        final pcLabelRect = tester.getRect(find.text('PC Chose:'));

        // Central VS badge is completely removed; ManaPoolOrb is centered horizontally
        expect(find.byKey(const ValueKey('vs_badge')), findsNothing);
        expect(find.text('VS'), findsNothing);
        expect(manaOrbRect.center.dx, closeTo(arenaRect.center.dx, 0.5));
        expect(find.byKey(const ValueKey('versus_sanctuary_floor_paint')), findsOneWidget);
        expect(find.byKey(const ValueKey('battle_outcome_ribbon')), findsOneWidget);

        // Top-aligned vertically with "You Chose:" and "PC Chose:"
        expect(manaOrbRect.top, closeTo(userLabelRect.top, 0.5));
        expect(manaOrbRect.top, closeTo(pcLabelRect.top, 0.5));
        expect(find.text('100'), findsOneWidget);

        // Height remains strictly identical across remainingMana values and match states
        final heightAt99 = await pumpArena(
          mana: 99,
          userMove: HandMove.rock,
          computerMove: HandMove.scissors,
          winner: RoundWinner.user,
          roundId: 1,
        );
        expect(find.text('99'), findsOneWidget);
        expect(heightAt99, equals(heightAt100));

        final heightAt15 = await pumpArena(
          mana: 15,
          userMove: HandMove.paper,
          computerMove: HandMove.rock,
          winner: RoundWinner.user,
          roundId: 85,
        );
        expect(find.text('15'), findsOneWidget);
        expect(heightAt15, equals(heightAt100));

        final heightAt0 = await pumpArena(
          mana: 0,
          userMove: HandMove.scissors,
          computerMove: HandMove.rock,
          winner: RoundWinner.computer,
          roundId: 100,
        );
        expect(find.text('0'), findsOneWidget);
        expect(heightAt0, equals(heightAt100));
      },
    );
  });
}
