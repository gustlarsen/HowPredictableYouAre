import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/widgets/versus_arena.dart';

Future<GameController> _createController({
  Map<String, Object> prefs = const {},
  bool animationsEnabled = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'musicEnabled': false,
    'soundEnabled': false,
    'vibrationEnabled': false,
    'animationsEnabled': animationsEnabled,
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

  group('Sacred Temple Battle Background & Atmosphere Integration', () {
    test('temple_arena_bg.webp exists, decodes at 571x1024, and is registered in pubspec.yaml', () async {
      final templeBgFile = File('assets/images/temple_arena_bg.webp');
      expect(templeBgFile.existsSync(), isTrue);
      final bytes = templeBgFile.readAsBytesSync();
      expect(bytes.length, greaterThan(50000));

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 571);
      expect(frame.image.height, 1024);

      final pubspecText = File('pubspec.yaml').readAsStringSync();
      expect(pubspecText.contains('assets/images/temple_arena_bg.webp'), isTrue);
      expect(pubspecText.contains('assets/images/forge_arena_bg.webp'), isTrue);
    });

    testWidgets('GameScreen renders temple_arena_bg.webp and TempleAtmospherePainter exclusively for Baby Mage Robot (stage 4)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = await _createController(
        prefs: {
          'current_week': 10,
          'enemy_stage': 4,
          'enemy_max_hp': 400,
          'pcHp': 400,
          'unlockedNewHands': true,
          'showNewHands': true,
        },
      );
      addTearDown(controller.dispose);
      expect(controller.enemyStage, 4);
      expect(controller.isBabyMageBoss, isTrue);

      for (final isDark in [true, false]) {
        controller.darkMode = isDark;
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: MaterialApp(
              theme: isDark
                  ? ThemeData.dark(useMaterial3: true)
                  : ThemeData.light(useMaterial3: true),
              home: const GameScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final templeBgFinder = find.byKey(
          const ValueKey<String>('assets/images/temple_arena_bg.webp'),
        );
        expect(templeBgFinder, findsOneWidget);
        final templeImage = tester.widget<Image>(templeBgFinder);
        expect(templeImage.fit, BoxFit.cover);

        expect(
          find.byKey(const ValueKey<String>('assets/images/forge_arena_bg.webp')),
          findsNothing,
        );

        final templePaintFinder = find.byKey(
          const ValueKey('temple_arena_atmosphere_paint'),
        );
        expect(templePaintFinder, findsOneWidget);
        final templeCustomPaint = tester.widget<CustomPaint>(templePaintFinder);
        expect(templeCustomPaint.painter, isA<TempleAtmospherePainter>());

        expect(
          find.byKey(const ValueKey('forge_arena_embers_paint')),
          findsNothing,
        );

        final floorPaint = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('sanctuary_runes_floor_paint')),
        );
        final floorPainter = floorPaint.painter as SanctuaryRunesFloorPainter;
        expect(floorPainter.suppressRunesGeometry, isTrue);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('GameScreen keeps forge_arena_bg.webp and _ForgeEmbersPainter unchanged for Guardian Robot (1), Robot Archmage (2), and Metal Wizard (3)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final stage in [1, 2, 3]) {
        final maxHp = stage * 100;
        final controller = await _createController(
          prefs: {
            'current_week': stage >= 2 ? 10 : 1,
            'enemy_stage': stage,
            'enemy_max_hp': maxHp,
            'pcHp': maxHp,
          },
        );
        addTearDown(controller.dispose);
        expect(controller.enemyStage, stage);
        expect(controller.isBabyMageBoss, isFalse);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: const GameScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('assets/images/forge_arena_bg.webp')),
          findsOneWidget,
          reason: 'Stage $stage should display forge_arena_bg.webp',
        );
        expect(
          find.byKey(const ValueKey('forge_arena_embers_paint')),
          findsOneWidget,
          reason: 'Stage $stage should display forge embers',
        );
        expect(
          find.byKey(const ValueKey<String>('assets/images/temple_arena_bg.webp')),
          findsNothing,
          reason: 'Stage $stage should NOT display temple_arena_bg.webp',
        );
        expect(
          find.byKey(const ValueKey('temple_arena_atmosphere_paint')),
          findsNothing,
          reason: 'Stage $stage should NOT display TempleAtmospherePainter',
        );

        final floorPaint = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('sanctuary_runes_floor_paint')),
        );
        final floorPainter = floorPaint.painter as SanctuaryRunesFloorPainter;
        expect(
          floorPainter.suppressRunesGeometry,
          isFalse,
          reason: 'Stage $stage should keep full SanctuaryRunesFloorPainter geometry',
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Mid-session transition from Metal Wizard (stage 3) into Temple High Master (stage 5) and Baby Mage Robot (stage 4) fades via AnimatedSwitcher (~400ms) into Sacred Temple and starts TempleAtmospherePainter', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = await _createController(
        animationsEnabled: true,
        prefs: {
          'currentWeek': 10,
          'enemyStage': 3,
          'enemyMaxHp': 300,
          'pcHp': 300,
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: const GameScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byKey(const ValueKey<String>('assets/images/forge_arena_bg.webp')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge_arena_embers_paint')),
        findsOneWidget,
      );

      // Simulate mid-session progression from Stage 3 (Metal Wizard) -> Stage 5 (Temple High Master)
      controller.pendingBossVictoryStage = 3;
      controller.pendingBossVictoryWeek = 10;
      final cycleEnded = controller.advanceAfterBossVictory();
      expect(cycleEnded, isFalse);
      expect(controller.enemyStage, 5);
      expect(controller.isTempleMasterBoss, isTrue);
      expect(controller.isSacredTempleArena, isTrue);

      // Advance past the 400ms AnimatedSwitcher fade transition
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(
        find.byKey(const ValueKey<String>('assets/images/temple_arena_bg.webp')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('assets/images/forge_arena_bg.webp')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('temple_arena_atmosphere_paint')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge_arena_embers_paint')),
        findsNothing,
      );

      // Pump additional frames to exercise TempleAtmospherePainter 60 FPS loop
      await tester.pump(const Duration(milliseconds: 1200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('VersusArena suppresses painted floor rune geometry on stage 4 during both idle and clash VFX', (WidgetTester tester) async {
      final localization = LocalizationService();
      await localization.load();

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
                roundId: 1,
                elementalMode: true,
                enemyStage: 4,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final floorPaint = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('sanctuary_runes_floor_paint')),
      );
      final painter = floorPaint.painter as SanctuaryRunesFloorPainter;
      expect(painter.suppressRunesGeometry, isTrue);
      expect(painter.clashPulse, greaterThan(0.0));
      expect(tester.takeException(), isNull);
    });
  });
}
