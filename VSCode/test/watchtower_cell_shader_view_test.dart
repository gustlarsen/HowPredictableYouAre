import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_predictable/views/widgets/watchtower_cell_shader_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WatchtowerCellShaderView Piecewise Keyframe Blending Tests', () {
    testWidgets(
      'Registers and loads all 5 progressive belly stage PNGs plus blink PNG',
      (WidgetTester tester) async {
        for (final asset in WatchtowerCellShaderView.cryingStageAssets) {
          final bytes = await rootBundle.load(asset);
          expect(bytes.lengthInBytes, greaterThan(1000));
        }
        final blinkBytes = await rootBundle.load(
          WatchtowerCellShaderView.cryingBlinkAsset,
        );
        expect(blinkBytes.lengthInBytes, greaterThan(1000));
      },
    );

    testWidgets(
      'Selects correct adjacent keyframes, uStageBlend, blinkEnabled, and static fallback across Week 0, 1, 2, 10, 11, 20, 21, 31, 40, and >40',
      (WidgetTester tester) async {
        final stages = WatchtowerCellShaderView.cryingStageAssets;
        final cases = <({
          int week,
          int clamped,
          WatchtowerPrincessStage stage,
          double progress,
          int fromIdx,
          int toIdx,
          double blend,
          bool blink,
          String primary,
          String? secondary,
          String fallback,
          String imageKey,
        })>[
          (
            week: 0,
            clamped: 0,
            stage: WatchtowerPrincessStage.standing,
            progress: 0.0,
            fromIdx: 0,
            toIdx: 0,
            blend: 0.0,
            blink: false,
            primary: WatchtowerCellShaderView.standingAsset,
            secondary: null,
            fallback: WatchtowerCellShaderView.standingAsset,
            imageKey: 'watchtower_spyglass_princess_standing_image',
          ),
          (
            week: 1,
            clamped: 1,
            stage: WatchtowerPrincessStage.cryingWeek1,
            progress: 0.0,
            fromIdx: 0,
            toIdx: 0,
            blend: 0.0,
            blink: true,
            primary: stages[0],
            secondary: null,
            fallback: stages[0],
            imageKey: 'watchtower_spyglass_princess_crying_image',
          ),
          (
            week: 2,
            clamped: 2,
            stage: WatchtowerPrincessStage.cryingPregnant,
            progress: 1.0 / 39.0,
            fromIdx: 0,
            toIdx: 1,
            blend: 4.0 / 39.0,
            blink: true,
            primary: stages[0],
            secondary: stages[1],
            fallback: stages[0],
            imageKey: 'watchtower_spyglass_princess_crying_stage_0',
          ),
          (
            week: 10,
            clamped: 10,
            stage: WatchtowerPrincessStage.cryingPregnant,
            progress: 9.0 / 39.0,
            fromIdx: 0,
            toIdx: 1,
            blend: 36.0 / 39.0,
            blink: true,
            primary: stages[0],
            secondary: stages[1],
            fallback: stages[1],
            imageKey: 'watchtower_spyglass_princess_crying_stage_1',
          ),
          (
            week: 11,
            clamped: 11,
            stage: WatchtowerPrincessStage.cryingPregnant,
            progress: 10.0 / 39.0,
            fromIdx: 1,
            toIdx: 2,
            blend: 1.0 / 39.0,
            blink: false,
            primary: stages[1],
            secondary: stages[2],
            fallback: stages[1],
            imageKey: 'watchtower_spyglass_princess_crying_stage_1',
          ),
          (
            week: 20,
            clamped: 20,
            stage: WatchtowerPrincessStage.cryingPregnant,
            progress: 19.0 / 39.0,
            fromIdx: 1,
            toIdx: 2,
            blend: 37.0 / 39.0,
            blink: false,
            primary: stages[1],
            secondary: stages[2],
            fallback: stages[2],
            imageKey: 'watchtower_spyglass_princess_crying_stage_2',
          ),
          (
            week: 21,
            clamped: 21,
            stage: WatchtowerPrincessStage.cryingPregnant,
            progress: 20.0 / 39.0,
            fromIdx: 2,
            toIdx: 3,
            blend: 2.0 / 39.0,
            blink: false,
            primary: stages[2],
            secondary: stages[3],
            fallback: stages[2],
            imageKey: 'watchtower_spyglass_princess_crying_stage_2',
          ),
          (
            week: 31,
            clamped: 31,
            stage: WatchtowerPrincessStage.cryingPregnant,
            progress: 30.0 / 39.0,
            fromIdx: 3,
            toIdx: 4,
            blend: 3.0 / 39.0,
            blink: false,
            primary: stages[3],
            secondary: stages[4],
            fallback: stages[3],
            imageKey: 'watchtower_spyglass_princess_crying_stage_3',
          ),
          (
            week: 40,
            clamped: 40,
            stage: WatchtowerPrincessStage.cryingPregnant,
            progress: 1.0,
            fromIdx: 3,
            toIdx: 4,
            blend: 1.0,
            blink: false,
            primary: stages[3],
            secondary: stages[4],
            fallback: stages[4],
            imageKey: 'watchtower_spyglass_princess_crying_stage_4',
          ),
          (
            week: 45,
            clamped: 40,
            stage: WatchtowerPrincessStage.cryingPregnant,
            progress: 1.0,
            fromIdx: 3,
            toIdx: 4,
            blend: 1.0,
            blink: false,
            primary: stages[3],
            secondary: stages[4],
            fallback: stages[4],
            imageKey: 'watchtower_spyglass_princess_crying_stage_4',
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
            expect(view.stageFromIndex, c.fromIdx);
            expect(view.stageToIndex, c.toIdx);
            expect(view.stageBlend, closeTo(c.blend, 1e-6));
            expect(view.blinkEnabled, c.blink);
            expect(view.primaryPrincessAsset, c.primary);
            expect(view.secondaryPrincessAsset, c.secondary);
            expect(view.fallbackPrincessAsset, c.fallback);

            final imgFinder = find.byKey(ValueKey(c.imageKey));
            expect(imgFinder, findsOneWidget);
            final img = tester.widget<Image>(imgFinder);
            expect((img.image as AssetImage).assetName, c.fallback);
            expect(tester.takeException(), isNull);
          }
        }
      },
    );

    testWidgets(
      'Animated shader lifecycle transitions smoothly across Week 0..40 and disposes cleanly',
      (WidgetTester tester) async {
        for (final week in [0, 1, 2, 10, 11, 20, 21, 31, 40]) {
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
