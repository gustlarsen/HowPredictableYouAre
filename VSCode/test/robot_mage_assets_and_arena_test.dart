import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/models/royal_castle.dart';
import 'package:how_predictable/models/story_chapter.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/royal_castle_dialog.dart';
import 'package:how_predictable/views/dialogs/victory_cutscene_dialog.dart';
import 'package:how_predictable/views/widgets/metal_wizard_lair_icon.dart';
import 'package:how_predictable/views/widgets/versus_arena.dart';

Future<GameController> _createController({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'musicEnabled': false,
    'soundEnabled': false,
    'vibrationEnabled': false,
    'animationsEnabled': false,
    'hasSeenStoryIntro': true,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();
  final localization = LocalizationService();
  await localization.load();
  return GameController(
    storage: storage,
    localization: localization,
    audio: AudioService(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Robot Mage Asset Integrity & Cutscene Integration', () {
    test('9:16 cliff cutscene WebP and 512x512 RGBA transparent enemy PNGs exist and are registered in pubspec.yaml', () async {
      final cliffFile = File('assets/images/story/robot_mage_cliff.webp');
      expect(cliffFile.existsSync(), isTrue);
      expect(cliffFile.lengthSync(), greaterThan(20000));

      final pubspecText = File('pubspec.yaml').readAsStringSync();
      expect(pubspecText.contains('assets/images/enemies/'), isTrue);
      expect(pubspecText.contains('assets/images/story/'), isTrue);

      const expectedEnemySprites = [
        'assets/images/enemies/guardian_robot_idle.png',
        'assets/images/enemies/guardian_robot_attack.png',
        'assets/images/enemies/guardian_robot_hit.png',
        'assets/images/enemies/robot_archmage_idle.png',
        'assets/images/enemies/baby_robot_mage_idle.png',
      ];

      for (final path in expectedEnemySprites) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'Missing $path');
        final bytes = file.readAsBytesSync();
        expect(bytes.length, greaterThan(10000));

        // Verify PNG signature, 512x512 dimensions, and RGBA (color type 6)
        expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final bd = ByteData.sublistView(bytes);
        final width = bd.getUint32(16);
        final height = bd.getUint32(20);
        final colorType = bytes[25];
        expect(width, 512, reason: '$path width should be 512');
        expect(height, 512, reason: '$path height should be 512');
        expect(colorType, 6, reason: '$path should be RGBA (color type 6)');

        // Decode with dart:ui to verify corner pixels have clean alpha == 0
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final rgbaData = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(rgbaData, isNotNull);
        // Top-left pixel (0, 0) alpha byte at index 3 must be 0
        expect(rgbaData!.getUint8(3), 0, reason: '$path top-left must be transparent');
        // Top-right pixel (511, 0) alpha byte must be 0
        expect(
          rgbaData.getUint8(511 * 4 + 3),
          0,
          reason: '$path top-right must be transparent',
        );
      }

      expect(
        StoryChapter.intro.assetPath,
        'assets/images/story/robot_mage_cliff.webp',
      );
    });

    testWidgets('VictoryCutsceneDialog displays robot_mage_cliff.webp backdrop cleanly in Dark and Light modes', (WidgetTester tester) async {
      final controller = await _createController();
      addTearDown(controller.dispose);

      for (final isDark in [true, false]) {
        for (final type in VictoryCutsceneType.values) {
          controller.darkMode = isDark;
          await tester.pumpWidget(
            MaterialApp(
              theme: isDark ? ThemeData.dark() : ThemeData.light(),
              home: Scaffold(
                body: VictoryCutsceneDialog(
                  type: type,
                  controller: controller,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final bgFinder = find.byKey(const ValueKey('victory_cutscene_bg_image'));
          expect(bgFinder, findsOneWidget);
          final imageWidget = tester.widget<Image>(bgFinder);
          expect(
            (imageWidget.image as AssetImage).assetName,
            'assets/images/story/robot_mage_cliff.webp',
          );
          expect(tester.takeException(), isNull);
        }
      }
    });
  });

  group('VersusArena Boss Sprite Animation Tests', () {
    testWidgets('Phase 1 Guardian Robot shows idle by default, swaps to attack (~450ms) on PC win, and swaps to hit (~450ms) on Player impact', (WidgetTester tester) async {
      final localization = LocalizationService();
      await localization.load();

      Future<void> pumpArena({
        required int roundId,
        RoundWinner? winner,
        HandMove? userMove,
        HandMove? computerMove,
        int enemyStage = 1,
      }) {
        return tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: VersusArena(
                  userMove: userMove,
                  computerMove: computerMove,
                  winner: winner,
                  localization: localization,
                  animationsEnabled: true,
                  roundId: roundId,
                  elementalMode: true,
                  enemyStage: enemyStage,
                ),
              ),
            ),
          ),
        );
      }

      // Idle state -> guardian_robot_idle.png
      await pumpArena(roundId: 0);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('assets/images/enemies/guardian_robot_idle.png')),
        findsOneWidget,
      );

      // PC wins round 1 -> guardian_robot_attack.png active for ~450ms, then reverts to idle
      await pumpArena(
        roundId: 1,
        winner: RoundWinner.computer,
        userMove: HandMove.rock,
        computerMove: HandMove.paper,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        find.byKey(const ValueKey('assets/images/enemies/guardian_robot_attack.png')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 350)); // 470ms total (>450ms)
      expect(
        find.byKey(const ValueKey('assets/images/enemies/guardian_robot_idle.png')),
        findsOneWidget,
      );

      // Finish remaining VFX duration
      await tester.pump(const Duration(milliseconds: 350));

      // Player deals damage round 2 -> idle during launch/clash, swaps to guardian_robot_hit.png at 550ms impact for ~450ms
      await pumpArena(
        roundId: 2,
        winner: RoundWinner.user,
        userMove: HandMove.rock,
        computerMove: HandMove.scissors,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byKey(const ValueKey('assets/images/enemies/guardian_robot_idle.png')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 360)); // 560ms total -> impact fired!
      expect(
        find.byKey(const ValueKey('assets/images/enemies/guardian_robot_hit.png')),
        findsOneWidget,
      );

      // At 460ms after impact -> reverts back to guardian_robot_idle.png
      await tester.pump(const Duration(milliseconds: 460));
      expect(
        find.byKey(const ValueKey('assets/images/enemies/guardian_robot_idle.png')),
        findsOneWidget,
      );
    });

    testWidgets('Stages 2, 3, and 4 render Robot Archmage, Metal Wizard, and Baby Mage Robot sprites cleanly with attack/hit motions', (WidgetTester tester) async {
      final localization = LocalizationService();
      await localization.load();

      // Stage 2: Robot Archmage
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: VersusArena(
                userMove: HandMove.rock,
                computerMove: HandMove.paper,
                winner: RoundWinner.computer,
                localization: localization,
                animationsEnabled: true,
                roundId: 1,
                elementalMode: true,
                enemyStage: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        find.byKey(const ValueKey('assets/images/enemies/robot_archmage_idle.png')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Stage 3: Metal Wizard
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: VersusArena(
                userMove: HandMove.spock,
                computerMove: HandMove.spock,
                winner: RoundWinner.draw,
                localization: localization,
                animationsEnabled: true,
                roundId: 2,
                elementalMode: true,
                enemyStage: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('versus_boss_sprite_stage_3')),
          matching: find.byType(MetalWizardLairIcon),
        ),
        findsOneWidget,
      );

      // Stage 4: Baby Mage Robot
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: VersusArena(
                userMove: HandMove.rock,
                computerMove: HandMove.scissors,
                winner: RoundWinner.user,
                localization: localization,
                animationsEnabled: true,
                roundId: 3,
                elementalMode: true,
                enemyStage: 4,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 650));
      expect(
        find.byKey(const ValueKey('assets/images/enemies/baby_robot_mage_idle.png')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Arcane Bestiary Portrait & Silhouette Tests', () {
    testWidgets('Arcane Bestiary displays silhouetted portraits when locked and transparent PNG portraits when unlocked', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. All locked -> silhouetted portraits shown, full-color portraits hidden
      final lockedController = await _createController();
      addTearDown(lockedController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: RoyalCastleDialog(
              controller: lockedController,
              initialWing: CastleWing.library,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('bestiary_silhouette_guardian_robot')), findsOneWidget);
      expect(find.byKey(const ValueKey('bestiary_silhouette_archmage_robot')), findsOneWidget);
      expect(find.byKey(const ValueKey('bestiary_silhouette_metal_wizard')), findsOneWidget);
      expect(find.byKey(const ValueKey('bestiary_silhouette_baby_robot')), findsOneWidget);
      expect(find.byKey(const ValueKey('bestiary_portrait_guardian_robot')), findsNothing);
      expect(find.byKey(const ValueKey('bestiary_portrait_archmage_robot')), findsNothing);
      expect(find.byKey(const ValueKey('bestiary_portrait_baby_robot')), findsNothing);

      // 2. All unlocked -> transparent PNG portraits rendered cleanly in Dark & Light modes
      final unlockedController = await _createController(
        prefs: {
          'encountered_bestiary': [
            BestiaryCreature.guardianRobot.id,
            BestiaryCreature.archmageRobot.id,
            BestiaryCreature.metalWizard.id,
            BestiaryCreature.babyRobot.id,
          ],
        },
      );
      addTearDown(unlockedController.dispose);

      for (final isDark in [true, false]) {
        unlockedController.darkMode = isDark;
        await tester.pumpWidget(
          MaterialApp(
            theme: isDark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              body: RoyalCastleDialog(
                controller: unlockedController,
                initialWing: CastleWing.library,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('bestiary_portrait_guardian_robot')), findsOneWidget);
        expect(find.byKey(const ValueKey('bestiary_portrait_archmage_robot')), findsOneWidget);
        expect(find.byKey(const ValueKey('bestiary_portrait_baby_robot')), findsOneWidget);
        expect(find.byKey(const ValueKey('bestiary_silhouette_guardian_robot')), findsNothing);
        expect(find.byKey(const ValueKey('bestiary_silhouette_archmage_robot')), findsNothing);
        expect(find.byKey(const ValueKey('bestiary_silhouette_baby_robot')), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
