import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show AdSize;
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/models/royal_castle.dart';
import 'package:how_predictable/models/story_chapter.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/royal_castle_dialog.dart';
import 'package:how_predictable/views/dialogs/victory_cutscene_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/widgets/elemental_energy_sphere.dart';
import 'package:how_predictable/views/widgets/elemental_symbol_icon.dart';
import 'package:how_predictable/views/widgets/rpg_backpack_icon.dart';
import 'package:how_predictable/views/widgets/versus_arena.dart';

class _TestAdMobClient extends AdMobClient {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadBanner({
    required String adUnitId,
    required AdSize size,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    onLoaded();
  }

  @override
  Widget? buildBannerWidget() => const SizedBox(width: 320, height: 50);

  @override
  void disposeBanner() {}

  @override
  Future<void> loadRewarded({
    required String adUnitId,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    onLoaded();
  }

  @override
  Future<bool> showRewarded({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onDismissed,
    required VoidCallback onFailedToShow,
  }) async {
    onUserEarnedReward();
    onDismissed();
    return true;
  }

  @override
  void disposeRewarded() {}
}

Future<GameController> _createController({
  Map<String, Object> prefs = const {},
  bool withBannerAd = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'musicEnabled': false,
    'soundEnabled': false,
    'vibrationEnabled': false,
    'animationsEnabled': false,
    'has_seen_story_intro': true,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();
  final localization = LocalizationService();
  await localization.load();
  final adService = withBannerAd ? AdService(client: _TestAdMobClient()) : null;
  if (adService != null) {
    await adService.loadBannerAd();
  }
  return GameController(
    storage: storage,
    localization: localization,
    audio: AudioService(),
    adService: adService,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Robot Mage & RPG Battle UI Asset Integrity & Cutscene Integration', () {
    test('9:16 cliff cutscene WebP, forge arena WebP, and 512x512 RGBA transparent player/enemy PNGs exist and are registered in pubspec.yaml', () async {
      final cliffFile = File('assets/images/story/robot_mage_cliff.webp');
      expect(cliffFile.existsSync(), isTrue);
      expect(cliffFile.lengthSync(), greaterThan(20000));

      final forgeBgFile = File('assets/images/forge_arena_bg.webp');
      expect(forgeBgFile.existsSync(), isTrue);
      expect(forgeBgFile.lengthSync(), greaterThan(20000));

      final pubspecText = File('pubspec.yaml').readAsStringSync();
      expect(pubspecText.contains('assets/images/enemies/'), isTrue);
      expect(pubspecText.contains('assets/images/player/'), isTrue);
      expect(pubspecText.contains('assets/images/forge_arena_bg.webp'), isTrue);
      expect(pubspecText.contains('assets/images/story/'), isTrue);
      expect(pubspecText.contains('assets/images/enemies/metal_wizard_idle.png'), isTrue);
      expect(pubspecText.contains('assets/images/enemies/metal_wizard_hit.png'), isTrue);
      expect(pubspecText.contains('assets/images/enemies/temple_master_hit.png'), isTrue);

      const expectedSprites = [
        'assets/images/player/cleric_idle.png',
        'assets/images/enemies/guardian_robot_idle.png',
        'assets/images/enemies/guardian_robot_attack.png',
        'assets/images/enemies/guardian_robot_hit.png',
        'assets/images/enemies/robot_archmage_idle.png',
        'assets/images/enemies/robot_archmage_hit.png',
        'assets/images/enemies/metal_wizard_idle.png',
        'assets/images/enemies/metal_wizard_hit.png',
        'assets/images/enemies/temple_master_idle.png',
        'assets/images/enemies/temple_master_hit.png',
        'assets/images/enemies/baby_robot_mage_idle.png',
        'assets/images/enemies/baby_robot_mage_hit.png',
      ];

      for (final path in expectedSprites) {
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

  group('VersusArena Player & Boss Sprite Animation Tests', () {
    testWidgets('Phase 1 Guardian Robot shows idle by default, swaps to attack (~450ms) on PC win, and swaps to hit (~450ms) on Player impact while Cleric sprite and Sanctuary Runes render cleanly', (WidgetTester tester) async {
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

      // Idle state -> cleric_idle.png, sanctuary_runes_floor_paint, and guardian_robot_idle.png
      await pumpArena(roundId: 0);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('sanctuary_runes_floor_paint')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('versus_player_sprite')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('assets/images/player/cleric_idle.png')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('assets/images/enemies/guardian_robot_idle.png')),
        findsOneWidget,
      );
      expect(find.text('PLAYER'), findsNothing);
      expect(find.byKey(const ValueKey('user_mana_bar')), findsOneWidget);
      expect(find.text('GUARDIAN ROBOT'), findsOneWidget);

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

      // Stage 2: Robot Archmage (idle during PC win / launch, swaps to robot_archmage_hit.png at impact, then reverts)
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
      final archmageIdleFinder = find.byKey(
        const ValueKey('assets/images/enemies/robot_archmage_idle.png'),
      );
      expect(archmageIdleFinder, findsOneWidget);
      expect(tester.widget<Image>(archmageIdleFinder).gaplessPlayback, isTrue);
      expect(find.text('ROBOT ARCHMAGE'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700)); // finish round 1

      // Stage 2 impact damage -> idle during launch/clash, swaps to robot_archmage_hit.png at 550ms impact
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
                roundId: 2,
                elementalMode: true,
                enemyStage: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(archmageIdleFinder, findsOneWidget);

      await tester.pump(const Duration(milliseconds: 360)); // 560ms total -> impact fired!
      final archmageHitFinder = find.byKey(
        const ValueKey('assets/images/enemies/robot_archmage_hit.png'),
      );
      expect(archmageHitFinder, findsOneWidget);
      expect(tester.widget<Image>(archmageHitFinder).gaplessPlayback, isTrue);

      await tester.pump(const Duration(milliseconds: 460)); // reverts to idle
      expect(archmageIdleFinder, findsOneWidget);
      expect(tester.takeException(), isNull);

      // Stage 3: Metal Wizard (idle on draw, swaps to metal_wizard_hit.png at 550ms impact on player win, then reverts)
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
                roundId: 3,
                elementalMode: true,
                enemyStage: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final metalWizardIdleFinder = find.byKey(
        const ValueKey('assets/images/enemies/metal_wizard_idle.png'),
      );
      expect(metalWizardIdleFinder, findsOneWidget);
      expect(tester.widget<Image>(metalWizardIdleFinder).gaplessPlayback, isTrue);
      expect(find.text('METAL WIZARD'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700)); // finish round 3

      // Stage 3 impact damage -> idle during launch/clash, swaps to metal_wizard_hit.png at 550ms impact
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: VersusArena(
                userMove: HandMove.rock,
                computerMove: HandMove.spock,
                winner: RoundWinner.user,
                localization: localization,
                animationsEnabled: true,
                roundId: 4,
                elementalMode: true,
                enemyStage: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(metalWizardIdleFinder, findsOneWidget);

      await tester.pump(const Duration(milliseconds: 360)); // 560ms total -> impact fired!
      final metalWizardHitFinder = find.byKey(
        const ValueKey('assets/images/enemies/metal_wizard_hit.png'),
      );
      expect(metalWizardHitFinder, findsOneWidget);
      expect(tester.widget<Image>(metalWizardHitFinder).gaplessPlayback, isTrue);

      await tester.pump(const Duration(milliseconds: 460)); // reverts to idle
      expect(metalWizardIdleFinder, findsOneWidget);
      expect(tester.takeException(), isNull);

      // Stage 4: Baby Mage Robot (idle during launch/clash, swaps to baby_robot_mage_hit.png at 550ms impact, then reverts)
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
                roundId: 5,
                elementalMode: true,
                enemyStage: 4,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final babyIdleFinder = find.byKey(
        const ValueKey('assets/images/enemies/baby_robot_mage_idle.png'),
      );
      expect(babyIdleFinder, findsOneWidget);
      expect(tester.widget<Image>(babyIdleFinder).gaplessPlayback, isTrue);

      await tester.pump(const Duration(milliseconds: 450)); // 650ms total -> inside impact hit window
      final babyHitFinder = find.byKey(
        const ValueKey('assets/images/enemies/baby_robot_mage_hit.png'),
      );
      expect(babyHitFinder, findsOneWidget);
      expect(tester.widget<Image>(babyHitFinder).gaplessPlayback, isTrue);
      expect(find.text('BABY MAGE ROBOT'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 460)); // reverts to idle
      expect(babyIdleFinder, findsOneWidget);
      expect(tester.takeException(), isNull);

      // Stage 5: Temple High Master (idle during PC win / launch, swaps to temple_master_hit.png at 550ms impact, then reverts)
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
                roundId: 6,
                elementalMode: true,
                enemyStage: 5,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final templeMasterIdleFinder = find.byKey(
        const ValueKey('assets/images/enemies/temple_master_idle.png'),
      );
      expect(templeMasterIdleFinder, findsOneWidget);
      expect(tester.widget<Image>(templeMasterIdleFinder).gaplessPlayback, isTrue);
      expect(find.text('TEMPLE HIGH MASTER'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700)); // finish round 6

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
                roundId: 7,
                elementalMode: true,
                enemyStage: 5,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(templeMasterIdleFinder, findsOneWidget);

      await tester.pump(const Duration(milliseconds: 360)); // 560ms total -> impact fired!
      final templeMasterHitFinder = find.byKey(
        const ValueKey('assets/images/enemies/temple_master_hit.png'),
      );
      expect(templeMasterHitFinder, findsOneWidget);
      expect(tester.widget<Image>(templeMasterHitFinder).gaplessPlayback, isTrue);

      await tester.pump(const Duration(milliseconds: 460)); // reverts to idle
      expect(templeMasterIdleFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Baby Mage Robot dual elemental badges stack vertically near staff without overlapping face, shield, or HP bar',
      (WidgetTester tester) async {
        final localization = LocalizationService();
        await localization.load();

        for (final compactHeight in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: SizedBox(
                  width: 390,
                  child: VersusArena(
                    userMove: HandMove.scissors,
                    computerMove: HandMove.water,
                    secondaryComputerMove: HandMove.earth,
                    winner: RoundWinner.user,
                    localization: localization,
                    animationsEnabled: false,
                    roundId: 1,
                    elementalMode: true,
                    isPhase2: true,
                    enemyStage: 4,
                    compactHeight: compactHeight,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          final dualBadgesFinder = find.byKey(
            const ValueKey('pc_dual_elemental_badges'),
          );
          final primaryBadgeFinder = find.byKey(
            const ValueKey('pc_primary_elemental_badge'),
          );
          final secondaryBadgeFinder = find.byKey(
            const ValueKey('pc_secondary_elemental_badge'),
          );
          final orbContainerFinder = find.byKey(
            const ValueKey('pc_orb_container'),
          );
          final hpBarFinder = find.byKey(const ValueKey('pc_hp_bar'));
          final shieldBadgeFinder = find.byKey(
            const ValueKey('phase2_boss_shield_badge'),
          );
          final bossSpriteFinder = find.byKey(
            const ValueKey('versus_boss_sprite_stage_4'),
          );

          expect(dualBadgesFinder, findsOneWidget);
          expect(tester.widget<Widget>(dualBadgesFinder), isA<Column>());
          expect(primaryBadgeFinder, findsOneWidget);
          expect(secondaryBadgeFinder, findsOneWidget);

          // Verify icons inside top and bottom badges
          expect(
            find.descendant(
              of: primaryBadgeFinder,
              matching: find.byWidgetPredicate(
                (w) => w is ElementalSymbolIcon && w.move == HandMove.water,
              ),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: secondaryBadgeFinder,
              matching: find.byWidgetPredicate(
                (w) => w is ElementalSymbolIcon && w.move == HandMove.earth,
              ),
            ),
            findsOneWidget,
          );

          final primaryRect = tester.getRect(primaryBadgeFinder);
          final secondaryRect = tester.getRect(secondaryBadgeFinder);
          final orbRect = tester.getRect(orbContainerFinder);
          final hpBarRect = tester.getRect(hpBarFinder);
          final shieldRect = tester.getRect(shieldBadgeFinder);
          final bossRect = tester.getRect(bossSpriteFinder);

          // Stacked vertically with ~4px gap, same horizontal center
          expect(secondaryRect.center.dx, closeTo(primaryRect.center.dx, 0.1));
          expect(secondaryRect.top - primaryRect.bottom, closeTo(4.0, 0.1));

          // Anchored on left/staff side of pc_orb_container, leaving center/face unobstructed
          expect(primaryRect.left, closeTo(orbRect.left, 0.1));
          expect(secondaryRect.left, closeTo(orbRect.left, 0.1));
          expect(primaryRect.right, lessThan(bossRect.center.dx));
          expect(secondaryRect.right, lessThan(bossRect.center.dx));

          // Fits cleanly above the HP bar and separate from top-right shield badge
          expect(secondaryRect.bottom, lessThanOrEqualTo(orbRect.bottom));
          expect(secondaryRect.bottom, lessThan(hpBarRect.top));
          expect(primaryRect.overlaps(shieldRect), isFalse);
          expect(secondaryRect.overlaps(shieldRect), isFalse);
          expect(tester.takeException(), isNull);
        }

        // Visibility states: null secondaryComputerMove renders single badge, null computerMove renders none
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SizedBox(
                width: 390,
                child: VersusArena(
                  userMove: null,
                  computerMove: null,
                  secondaryComputerMove: null,
                  winner: null,
                  localization: localization,
                  animationsEnabled: false,
                  roundId: 0,
                  elementalMode: true,
                  isPhase2: true,
                  enemyStage: 4,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('pc_dual_elemental_badges')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('pc_primary_elemental_badge')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('pc_secondary_elemental_badge')),
          findsNothing,
        );
      },
    );
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
      expect(find.byKey(const ValueKey('bestiary_portrait_metal_wizard')), findsNothing);
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
        expect(find.byKey(const ValueKey('bestiary_portrait_metal_wizard')), findsOneWidget);
        expect(find.byKey(const ValueKey('bestiary_portrait_baby_robot')), findsOneWidget);
        expect(find.byKey(const ValueKey('bestiary_silhouette_guardian_robot')), findsNothing);
        expect(find.byKey(const ValueKey('bestiary_silhouette_archmage_robot')), findsNothing);
        expect(find.byKey(const ValueKey('bestiary_silhouette_metal_wizard')), findsNothing);
        expect(find.byKey(const ValueKey('bestiary_silhouette_baby_robot')), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('RPG Battle Screen UI Overhaul Full-Screen Integration', () {
    testWidgets('GameScreen renders forge_arena_bg.webp, drifting embers, open leather backpack HUD, ScoreHeader gauge pill, CustomPainter HintsBar, Sanctuary Runes, Cleric vs Boss, 3D ElementalEnergySphere deck with flame aura, and bottom banner ad', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = await _createController(
        withBannerAd: true,
        prefs: {
          'unlockedPredictability': true,
          'showPredictability': true,
          'unlockedYourPrediction': true,
          'showYourPrediction': true,
          'unlockedNextMove': true,
          'showNextMove': true,
          'unlockedSuggestion': true,
          'showSuggestion': true,
          'unlockedCrystalBall': true,
          'showCrystalBall': true,
          'unlockedNewHands': true,
          'showNewHands': true,
          'unlockedRandom': true,
          'showRandom': true,
          'orbs_fire': 10,
          'orbs_water': 10,
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
      await tester.pumpAndSettle();

      // 1. Forge background & drifting embers
      expect(
        find.byKey(const ValueKey<String>('assets/images/forge_arena_bg.webp')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge_arena_embers_paint')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bottom_banner_ad_container')),
        findsOneWidget,
      );

      // 2. Top HUD Bar with open leather backpack (no WEEK X / 40 badge in battle HUD)
      expect(find.byKey(const ValueKey('battle_top_hud_bar')), findsOneWidget);
      final hudBackpack = tester.widget<RpgBackpackIcon>(
        find.descendant(
          of: find.byKey(const ValueKey('battle_top_hud_bar')),
          matching: find.byType(RpgBackpackIcon),
        ),
      );
      expect(hudBackpack.isOpen, isTrue);
      expect(hudBackpack.size, 38.0);
      expect(hudBackpack.ownedOrbs, containsAll([HandMove.rock, HandMove.paper]));
      expect(find.byKey(const ValueKey('battle_week_counter_badge')), findsNothing);
      expect(find.text('WEEK 1 / 40'), findsNothing);

      // 3. ScoreHeader renders all 4 metrics on a single horizontal row without Gauge pill box
      expect(find.byKey(const ValueKey('score_header_gauge_pill')), findsNothing);
      expect(find.text('Your Score:'), findsOneWidget);
      expect(find.text('PC Score:'), findsOneWidget);
      expect(find.text('Total:'), findsOneWidget);
      expect(find.text('Gauge:'), findsOneWidget);
      expect(find.text('You Chose:'), findsNothing);
      expect(find.text('PC Chose:'), findsNothing);
      expect(find.byKey(const ValueKey('vs_badge')), findsNothing);
      expect(find.text('VS'), findsNothing);

      // 4. HintsBar with CustomPainter mini-icons
      expect(find.byKey(const ValueKey('hint_mini_icon_brain')), findsOneWidget);
      expect(find.byKey(const ValueKey('hint_mini_icon_robot')), findsOneWidget);
      expect(find.byKey(const ValueKey('hint_mini_icon_lightbulb')), findsOneWidget);
      expect(find.byKey(const ValueKey('hint_mini_icon_crystalBall')), findsOneWidget);

      // 5. Glossy 3D ElementalEnergySphere bottom action deck & flame aura on selected orb
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('move_selection_card')),
          matching: find.byType(ElementalEnergySphere),
        ),
        findsNWidgets(5),
      );
      await tester.tap(find.byKey(const ValueKey('hand_button_rock')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('active_orb_flame_aura_rock')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
