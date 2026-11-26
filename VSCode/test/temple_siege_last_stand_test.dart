import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/models/royal_castle.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/temple_moral_choice_dialog.dart';
import 'package:how_predictable/views/dialogs/teleport_confirm_dialog.dart';
import 'package:how_predictable/views/dialogs/victory_cutscene_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/screens/world_map_screen.dart';
import 'package:how_predictable/views/widgets/versus_arena.dart';

class _ReadyRewardedAdClient extends AdMobClient {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadBanner({
    required String adUnitId,
    required AdSize size,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {}

  @override
  Widget? buildBannerWidget() => null;

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
  AdService? adService,
}) async {
  SharedPreferences.setMockInitialValues({
    'musicEnabled': false,
    'soundEnabled': false,
    'vibrationEnabled': false,
    'animationsEnabled': false,
    'has_seen_story_intro': true,
    'hasSeenStoryIntro': true,
    'has_shown_week10_archmage_warning': true,
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
    adService: adService ?? AdService(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Week 40+ Sacred Temple Siege (Last Stand)', () {
    test(
      'Controller activates Temple Siege from active boss (1, 2, 3, or 4), skips Stage 5, follows Guardian(1) -> Archmage(2) -> Baby(4) -> MetalWizard(3), and syncs CloudSaveData',
      () async {
        // 1. Resuming from each boss preserves exact active opponent (skipping Stage 5 -> 4)
        for (final entry in {1: 1, 2: 2, 3: 3, 4: 4, 5: 4}.entries) {
          final c = await _createController(
            prefs: {
              'current_week': 40,
              'enemy_stage': entry.key,
              'enemy_max_hp': GameController.maxHpForEnemyStage(entry.key),
              'pcHp': 5,
              'hp': 7,
              'totalRounds': 20,
            },
          );
          c.activateTempleSiege();
          expect(c.isTempleSiegeActive, isTrue);
          expect(c.currentWeek, GameController.siegeInvasionWeek);
          expect(c.enemyStage, entry.value);
          expect(c.isSacredTempleArena, isTrue);
          expect(c.userHp, c.playerMaxHp);
          expect(c.remainingMana, c.playerMaxMana);
          expect(
            c.computerHp,
            GameController.maxHpForEnemyStage(entry.value),
          );
          c.dispose();
        }

        // 2. Full reordered gauntlet progression via real battle victories: 1 -> 2 -> 4 -> 3 -> Victory
        final controller = await _createController(
          prefs: {
            'current_week': 40,
            'enemy_stage': 1,
            'enemy_max_hp': 100,
            'pcHp': 100,
          },
        );
        addTearDown(controller.dispose);
        controller.activateTempleSiege();
        expect(controller.enemyStage, 1);

        // Defeat Guardian Robot (1) -> advances to Robot Archmage (2)
        controller.userHp = 3;
        controller.totalRounds = 12;
        controller.computerHp = 1;
        controller.playTurn(
          (controller.crystalBallMove ?? HandMove.rock).counterForMode(
            elemental: controller.isElementalMode,
          ),
        );
        expect(controller.isBossVictoryPending, isTrue);
        var didCompleteAll = controller.advanceAfterBossVictory();
        expect(didCompleteAll, isFalse);
        expect(controller.enemyStage, 2);
        expect(controller.userHp, controller.playerMaxHp);
        expect(controller.remainingMana, controller.playerMaxMana);
        expect(controller.isSacredTempleArena, isTrue);
        expect(controller.shouldShowWeek10ArchmageWarning, isFalse);

        // Defeat Robot Archmage (2) -> skips Stage 5, advances to Baby Mage Robot (4)
        controller.userHp = 4;
        controller.totalRounds = 15;
        controller.computerHp = 1;
        controller.playTurn(
          (controller.crystalBallMove ?? HandMove.rock).counterForMode(
            elemental: controller.isElementalMode,
          ),
        );
        expect(controller.isBossVictoryPending, isTrue);
        didCompleteAll = controller.advanceAfterBossVictory();
        expect(didCompleteAll, isFalse);
        expect(controller.enemyStage, 4);
        expect(controller.userHp, controller.playerMaxHp);
        expect(controller.remainingMana, controller.playerMaxMana);
        expect(controller.isSacredTempleArena, isTrue);

        // Defeat Baby Mage Robot (4) -> advances to Metal Wizard (3) as Final Boss
        controller.userHp = 2;
        controller.totalRounds = 8;
        controller.computerHp = 1;
        final dualSpells = controller.crystalBallMoves;
        final dualWinner = HandMove.values.firstWhere(
          (m) {
            final res = DualSpellMatchupResult.evaluate(
              playerMove: m,
              spellA: dualSpells[0],
              spellB: dualSpells[1],
              elemental: controller.isElementalMode,
            );
            return res.bossDamage > 0 && res.playerDamage == 0;
          },
          orElse: () => dualSpells.first.counterForMode(
            elemental: controller.isElementalMode,
          ),
        );
        controller.playTurn(dualWinner);
        expect(controller.isBossVictoryPending, isTrue);
        didCompleteAll = controller.advanceAfterBossVictory();
        expect(didCompleteAll, isFalse);
        expect(controller.enemyStage, 3);
        expect(controller.userHp, controller.playerMaxHp);
        expect(controller.remainingMana, controller.playerMaxMana);
        expect(controller.isSacredTempleArena, isTrue);

        // Verify CloudSaveData preserves Temple Siege state and reload restores it
        final cloud = CloudSaveData.fromStorage(controller.storage);
        final roundTripped = CloudSaveData.fromJson(
          jsonDecode(jsonEncode(cloud.toJson())) as Map<String, dynamic>,
        );
        expect(roundTripped.isTempleSiegeActive, isTrue);

        // Defeat Metal Wizard (3) -> Victory!
        controller.computerHp = 1;
        controller.playTurn(
          (controller.crystalBallMove ?? HandMove.spock).counterForMode(
            elemental: controller.isElementalMode,
          ),
        );
        expect(controller.isBossVictoryPending, isTrue);
        didCompleteAll = controller.advanceAfterBossVictory();
        expect(didCompleteAll, isTrue);
        expect(controller.enemyStage, 1);
        expect(controller.isTempleSiegeActive, isFalse);
        expect(controller.currentWeek, 0);
        expect(controller.standardVictoryCount, 1);
        expect(controller.metalWizardDefeatedCount, 1);
        expect(controller.totalCyclesCount, 1);
        expect(
          controller.unlockedEndings,
          contains(NarrativeEnding.standardVictory.id),
        );
      },
    );

    testWidgets(
      'Passing Week 40 from Robot Archmage keeps player in GameScreen with temple_arena_bg, TempleAtmospherePainter, suppressed floor runes, and localized Temple Siege HUD badge (en/pt/es/de)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          prefs: {
            'current_week': 40,
            'enemy_stage': 2,
            'enemy_max_hp': 200,
            'pcHp': 200,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Enter Robot Archmage battle on Week 40
        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();
        expect(controller.enemyStage, 2);

        // Teleport on Week 40 -> activates Temple Siege against Robot Archmage (no immediate Game Over)
        await tester.tap(find.byKey(const ValueKey('teleport_portal_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('teleport_confirm_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('week40_kingdom_fall_dialog')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('temple_siege_invasion_dialog')),
          findsOneWidget,
        );
        expect(controller.isTempleSiegeActive, isTrue);
        expect(controller.enemyStage, 2);

        await tester.tap(
          find.byKey(const ValueKey('temple_siege_begin_button')),
        );
        await tester.pumpAndSettle();

        // Sacred Temple background, atmosphere painter, and suppressed runes even on Stage 2!
        expect(
          find.byKey(const ValueKey<String>('assets/images/temple_arena_bg.webp')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('assets/images/forge_arena_bg.webp')),
          findsNothing,
        );
        final templePaint = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('temple_arena_atmosphere_paint')),
        );
        expect(templePaint.painter, isA<TempleAtmospherePainter>());
        final floorPaint = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('sanctuary_runes_floor_paint')),
        );
        expect(
          (floorPaint.painter as SanctuaryRunesFloorPainter).suppressRunesGeometry,
          isTrue,
        );

        // Verify Temple Siege HUD badge across en / pt / es / de
        for (final entry in {
          'en': 'TEMPLE SIEGE',
          'pt': 'CERCO AO TEMPLO',
          'es': 'ASEDIO AL TEMPLO',
          'de': 'TEMPELBELAGERUNG',
        }.entries) {
          controller.setLanguage(entry.key);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('temple_siege_hud_badge')),
            findsOneWidget,
          );
          expect(find.text(entry.value), findsOneWidget);
        }
      },
    );

    testWidgets(
      'App launched during saved Temple Siege on WorldMapScreen auto-opens GameScreen at Guardian Robot without showing Map',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          prefs: {
            'current_week': 41,
            'is_temple_siege_active': true,
            'has_shown_temple_siege_intro': false,
            'enemy_stage': 1,
            'enemy_max_hp': 100,
            'pcHp': 100,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GameScreen), findsOneWidget);
        expect(
          find.byKey(const ValueKey('temple_siege_invasion_dialog')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('temple_siege_begin_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.enemyStage, 1);
        expect(
          find.byKey(const ValueKey<String>('assets/images/temple_arena_bg.webp')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('temple_siege_hud_badge')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Temple Siege skips Temple Master completely, advances Archmage (2) -> Baby Mage (4) -> Metal Wizard (3), and Victory saves the city',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          prefs: {
            'current_week': 41,
            'is_temple_siege_active': true,
            'has_shown_temple_siege_intro': true,
            'enemy_stage': 2,
            'enemy_max_hp': 200,
            'pcHp': 1,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GameScreen), findsOneWidget);
        expect(controller.enemyStage, 2);

        // Defeat Robot Archmage (2) -> advances directly to Baby Mage (4), NO TempleMoralChoiceDialog
        final counter2 = (controller.crystalBallMove ?? HandMove.rock).counterForMode(
          elemental: controller.isElementalMode,
        );
        controller.playTurn(counter2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.byType(TempleMoralChoiceDialog), findsNothing);
        expect(find.byKey(const ValueKey('boss_victory_modal')), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        // Now facing Baby Mage Robot (4) inside Sacred Temple!
        expect(controller.enemyStage, 4);
        expect(controller.computerHp, 400);
        expect(
          find.byKey(const ValueKey<String>('assets/images/temple_arena_bg.webp')),
          findsOneWidget,
        );

        // Reduce Baby Mage (4) to 1 HP and land dual-winning strike -> advances to Metal Wizard (3)
        controller.computerHp = 1;
        final dualSpells = controller.currentBabyMageDualSpells;
        final winningMove = HandMove.values.firstWhere(
          (m) {
            final res = DualSpellMatchupResult.evaluate(
              playerMove: m,
              spellA: dualSpells[0],
              spellB: dualSpells[1],
              elemental: controller.isElementalMode,
            );
            return res.bossDamage > 0 && res.playerDamage == 0;
          },
          orElse: () => dualSpells.first.counterForMode(
            elemental: controller.isElementalMode,
          ),
        );
        controller.playTurn(winningMove);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.byKey(const ValueKey('boss_victory_modal')), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        // Now facing Metal Wizard (3) inside Sacred Temple as Final Boss!
        expect(controller.enemyStage, 3);
        expect(controller.computerHp, 300);
        expect(
          find.byKey(const ValueKey<String>('assets/images/temple_arena_bg.webp')),
          findsOneWidget,
        );

        // Defeat Metal Wizard (3) -> Victory cutscene & return to Week 0
        controller.computerHp = 1;
        final mwCounter =
            (controller.crystalBallMove ?? HandMove.spock).counterForMode(
          elemental: controller.isElementalMode,
        );
        controller.playTurn(mwCounter);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.byKey(const ValueKey('boss_victory_modal')), findsOneWidget);
        expect(find.text('TEMPLE SIEGE BROKEN!'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VictoryCutsceneDialog), findsOneWidget);
        expect(find.text('TEMPLE SIEGE BROKEN · VICTORY'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('victory_cutscene_skip_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(controller.isTempleSiegeActive, isFalse);
        expect(controller.currentWeek, 0);
        expect(controller.standardVictoryCount, 1);
        expect(controller.metalWizardDefeatedCount, 1);
        expect(controller.totalCyclesCount, 1);
        expect(
          controller.unlockedEndings,
          contains(NarrativeEnding.standardVictory.id),
        );
      },
    );

    testWidgets(
      'Temple Siege Teleport ignores suppress warning, shows cowardly escape, archives spoils & relics, increments Deserter ending, and resets to Week 0',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          prefs: {
            'current_week': 41,
            'is_temple_siege_active': true,
            'has_shown_temple_siege_intro': true,
            'suppressTeleportWarning': true,
            'enemy_stage': 3,
            'enemy_max_hp': 300,
            'pcHp': 300,
            'orbs_fire': 40,
            'unlockedCrystalBall': true,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('teleport_portal_button')));
        await tester.pumpAndSettle();

        // Even with suppressTeleportWarning == true, cowardly escape warning MUST appear
        expect(find.byType(TeleportConfirmDialog), findsOneWidget);
        expect(find.text('Cowardly Escape From the Siege?'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('teleport_confirm_button')));
        await tester.pumpAndSettle();

        expect(find.byType(VictoryCutsceneDialog), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('victory_cutscene_skip_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(controller.isTempleSiegeActive, isFalse);
        expect(controller.currentWeek, 0);
        expect(controller.deserterCount, 1);
        expect(controller.totalCyclesCount, 1);
        expect(
          controller.unlockedEndings,
          contains(NarrativeEnding.theDeserter.id),
        );
        expect(controller.spoilsFireOrbs, 40);
        expect(
          controller.relicChamberStoredUpgrades,
          contains(ShopUpgradeArtifact.crystalBall.id),
        );
        expect(controller.unlockedCrystalBall, isFalse);
      },
    );

    testWidgets(
      'Temple Siege 0 HP death offers no Revive Ad, shows Heroic Death ending, archives spoils & relics, increments timeoutDefeatCount, and resets to Week 0',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final adService = AdService(client: _ReadyRewardedAdClient());
        await adService.initialize();

        final controller = await _createController(
          adService: adService,
          prefs: {
            'current_week': 41,
            'is_temple_siege_active': true,
            'has_shown_temple_siege_intro': true,
            'enemy_stage': 3,
            'enemy_max_hp': 300,
            'pcHp': 300,
            'userHp': 1,
            'unlockedNewHands': true,
            'showNewHands': true,
            'orbs_water': 25,
            'unlockedRandom': true,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Trigger a losing turn so playerHp hits 0 during Temple Siege
        final predictedEnemyMove = controller.crystalBallMove ?? HandMove.spock;
        final losingMove = HandMove.values.firstWhere(
          (m) => predictedEnemyMove.beats(m, elemental: controller.isElementalMode),
        );
        controller.playTurn(losingMove);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        expect(controller.userHp, 0);
        expect(
          find.byKey(const ValueKey('temple_siege_heroic_death_dialog')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('watch_ad_revive_button')), findsNothing);

        await tester.tap(
          find.byKey(const ValueKey('temple_siege_heroic_death_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(controller.isTempleSiegeActive, isFalse);
        expect(controller.currentWeek, 0);
        expect(controller.timeoutDefeatCount, 1);
        expect(controller.totalCyclesCount, 1);
        expect(
          controller.unlockedEndings,
          contains(NarrativeEnding.invasionTimeout.id),
        );
        expect(controller.spoilsWaterOrbs, 25);
        expect(
          controller.relicChamberStoredUpgrades,
          contains(ShopUpgradeArtifact.random.id),
        );
        expect(controller.unlockedRandom, isFalse);
      },
    );

    testWidgets(
      'Temple Siege 0 Mana exhaustion (with playerHp > 0) triggers Heroic Death defeat, archives spoils & relics, increments timeoutDefeatCount, and resets to Week 0',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          prefs: {
            'current_week': 41,
            'is_temple_siege_active': true,
            'has_shown_temple_siege_intro': true,
            'enemy_stage': 1,
            'enemy_max_hp': 100,
            'pcHp': 100,
            'userHp': 50,
            'orbs_wood': 33,
            'unlockedReset': true,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        controller.totalRounds = 99;
        await tester.pump();

        expect(controller.remainingMana, 1);
        expect(controller.userHp, 50);

        // Play a draw/non-lethal final round consuming the last point of Mana
        controller.playTurn(controller.crystalBallMove ?? HandMove.rock);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        expect(controller.remainingMana, 0);
        expect(controller.userHp, greaterThan(0));
        expect(
          find.byKey(const ValueKey('temple_siege_heroic_death_dialog')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('watch_ad_revive_button')), findsNothing);
        expect(
          find.textContaining('exhausted the very last spark of his Mana'),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('temple_siege_heroic_death_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(controller.isTempleSiegeActive, isFalse);
        expect(controller.currentWeek, 0);
        expect(controller.timeoutDefeatCount, 1);
        expect(controller.totalCyclesCount, 1);
        expect(
          controller.unlockedEndings,
          contains(NarrativeEnding.invasionTimeout.id),
        );
        expect(controller.spoilsWoodOrbs, 33);
        expect(
          controller.relicChamberStoredUpgrades,
          contains(ShopUpgradeArtifact.reset.id),
        );
        expect(controller.unlockedReset, isFalse);
      },
    );
  });
}
