import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_predictable/views/widgets/watchtower_cell_shader_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WatchtowerCellShaderView Dedicated Weekly Frames & Blink Tests', () {
    testWidgets(
      'Registers and loads Week 0, restored Week 1, blink frame, and all 39 weekly PNGs (Week 2..40)',
      (WidgetTester tester) async {
        for (final asset in [
          WatchtowerCellShaderView.standingAsset,
          WatchtowerCellShaderView.cryingWeek1Asset,
          WatchtowerCellShaderView.cryingBlinkAsset,
        ]) {
          final bytes = await rootBundle.load(asset);
          expect(bytes.lengthInBytes, greaterThan(1000));
        }

        for (var week = 2; week <= 40; week++) {
          final asset = WatchtowerCellShaderView.weeklyAssetForWeek(week);
          final bytes = await rootBundle.load(asset);
          expect(
            bytes.lengthInBytes,
            greaterThan(1000),
            reason: 'Expected valid PNG asset for Week $week at $asset',
          );
        }
      },
    );

    test('computeBlinkValue produces crisp ~180ms blinks with occasional double-blink', () {
      // Eyes open at t = 0.0 and between blinks
      expect(WatchtowerCellShaderView.computeBlinkValue(0.0), 0.0);
      expect(WatchtowerCellShaderView.computeBlinkValue(1.5), 0.0);
      expect(WatchtowerCellShaderView.computeBlinkValue(4.5), 0.0);

      // Peak of first single blink (~2.60s + 0.085s)
      expect(WatchtowerCellShaderView.computeBlinkValue(2.685), 1.0);
      expect(WatchtowerCellShaderView.computeBlinkValue(2.90), 0.0);

      // Double-blink at 11.10s and 11.40s with open gap between them
      expect(WatchtowerCellShaderView.computeBlinkValue(11.18), 1.0);
      expect(WatchtowerCellShaderView.computeBlinkValue(11.33), 0.0);
      expect(WatchtowerCellShaderView.computeBlinkValue(11.48), 1.0);

      // Wraps seamlessly across cycle boundary
      expect(
        WatchtowerCellShaderView.computeBlinkValue(
          WatchtowerCellShaderView.blinkCycleDurationSeconds + 2.685,
        ),
        1.0,
      );
    });

    testWidgets(
      'Selects exact single sprite per week with zero cross-fade across Week 0, 1, 2, 20, 40, and >40',
      (WidgetTester tester) async {
        final cases = <({
          int week,
          int clamped,
          WatchtowerPrincessStage stage,
          double progress,
          bool blink,
          String asset,
          String imageKey,
        })>[
          (
            week: 0,
            clamped: 0,
            stage: WatchtowerPrincessStage.standing,
            progress: 0.0,
            blink: false,
            asset: WatchtowerCellShaderView.standingAsset,
            imageKey: 'watchtower_spyglass_princess_standing_image',
          ),
          (
            week: 1,
            clamped: 1,
            stage: WatchtowerPrincessStage.cryingWeek1,
            progress: 0.0,
            blink: true,
            asset: WatchtowerCellShaderView.cryingWeek1Asset,
            imageKey: 'watchtower_spyglass_princess_crying_image',
          ),
          (
            week: 2,
            clamped: 2,
            stage: WatchtowerPrincessStage.cryingPregnant,
            progress: 1.0 / 39.0,
            blink: true,
            asset: 'assets/images/princess_weeks/princess_week_02.png',
            imageKey: 'watchtower_spyglass_princess_week_02_image',
          ),
          (
            week: 20,
            clamped: 20,
            stage: WatchtowerPrincessStage.cryingPregnant,
            progress: 19.0 / 39.0,
            blink: true,
            asset: 'assets/images/princess_weeks/princess_week_20.png',
            imageKey: 'watchtower_spyglass_princess_week_20_image',
          ),
          (
            week: 40,
            clamped: 40,
            stage: WatchtowerPrincessStage.cryingPregnant,
            progress: 1.0,
            blink: true,
            asset: 'assets/images/princess_weeks/princess_week_40.png',
            imageKey: 'watchtower_spyglass_princess_week_40_image',
          ),
          (
            week: 45,
            clamped: 40,
            stage: WatchtowerPrincessStage.cryingPregnant,
            progress: 1.0,
            blink: true,
            asset: 'assets/images/princess_weeks/princess_week_40.png',
            imageKey: 'watchtower_spyglass_princess_week_40_image',
          ),
        ];

        for (final c in cases) {
          for (final fullScreen in [false, true]) {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 320,
                    height: 320,
                    child: WatchtowerCellShaderView(
                      animationsEnabled: false,
                      forceStaticFallback: true,
                      isFullScreen: fullScreen,
                      currentWeek: c.week,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final view = tester.widget<WatchtowerCellShaderView>(
              find.byType(WatchtowerCellShaderView),
            );
            expect(view.clampedWeek, c.clamped);
            expect(view.princessStage, c.stage);
            expect(view.bellyProgress, closeTo(c.progress, 1e-6));
            expect(view.abdomenGrowth, closeTo(c.progress, 1e-6));
            expect(view.blinkEnabled, c.blink);
            expect(view.activePrincessAsset, c.asset);
            expect(view.primaryPrincessAsset, c.asset);

            final imgFinder = find.byKey(ValueKey(c.imageKey));
            expect(imgFinder, findsOneWidget);
            final img = tester.widget<Image>(imgFinder);
            expect((img.image as AssetImage).assetName, c.asset);
            expect(tester.takeException(), isNull);
          }
        }
      },
    );

    testWidgets(
      'Animated shader lifecycle loads single active texture per week across Week 0..40 and disposes cleanly',
      (WidgetTester tester) async {
        for (final week in [0, 1, 2, 10, 20, 30, 40]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 320,
                  height: 320,
                  child: WatchtowerCellShaderView(
                    animationsEnabled: true,
                    currentWeek: week,
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 60));
          expect(find.byType(WatchtowerCellShaderView), findsOneWidget);
          expect(tester.takeException(), isNull);
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
