import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:how_predictable/views/dialogs/metal_wizard_spyglass_dialog.dart';
import 'package:how_predictable/views/dialogs/observatory_dialog.dart';
import 'package:how_predictable/views/dialogs/week10_archmage_warning_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/screens/world_map_screen.dart';

class _FakePlayGamesClient implements PlayGamesClient {
  final Map<String, String?> _cloudSaves = {};
  String mockPlayerId = 'week10_player_1';
  String mockPlayerName = 'Week10Cleric';

  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => mockPlayerName;

  @override
  Future<String?> getPlayerID() async => mockPlayerId;

  @override
  Future<String?> saveGame({required String data, required String name}) async {
    _cloudSaves[mockPlayerId] = data;
    return 'success';
  }

  @override
  Future<String?> loadGame({required String name}) async =>
      _cloudSaves[mockPlayerId];
}

Future<({
  StorageService storage,
  LocalizationService localization,
  PlayGamesService playGames,
  GameController controller,
})> _createTestHarness({
  Map<String, Object> prefs = const {},
  _FakePlayGamesClient? client,
  bool signIn = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_story_intro': true,
    'animationsEnabled': false,
    'musicEnabled': false,
    'soundEnabled': false,
    'vibrationEnabled': false,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();

  final localization = LocalizationService();
  await localization.load();

  final playGames = PlayGamesService(
    storage: storage,
    client: client ?? _FakePlayGamesClient(),
  );
  if (signIn) {
    await playGames.signIn();
  }

  final controller = GameController(
    storage: storage,
    localization: localization,
    audio: AudioService(),
    playGames: playGames,
    adService: AdService(),
  );

  return (
    storage: storage,
    localization: localization,
    playGames: playGames,
    controller: controller,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Week 10 Robot Archmage Interception & Warning Carousel', () {
    test(
      'StorageService & CloudSaveData persist Week 10 flags and reset cleanly on Forfeit, Game Over, Week 40 Deadline, and Cycle Endings',
      () async {
        final fakeClient = _FakePlayGamesClient();
        final harness = await _createTestHarness(
          client: fakeClient,
          signIn: true,
        );
        final controller = harness.controller;
        final storage = harness.storage;
        addTearDown(controller.dispose);

        // 1. Fresh defaults
        expect(storage.hasDefeatedRobotArchmage, isFalse);
        expect(storage.hasShownWeek10ArchmageWarning, isFalse);
        expect(storage.hasUnreadWeek10WatchtowerAlert, isFalse);
        expect(storage.savedMetalWizardHp, isNull);
        expect(controller.hasDefeatedRobotArchmage, isFalse);
        expect(controller.hasShownWeek10ArchmageWarning, isFalse);
        expect(controller.hasUnreadWeek10WatchtowerAlert, isFalse);
        expect(controller.savedMetalWizardHp, isNull);

        const defaultCloud = CloudSaveData();
        expect(defaultCloud.hasDefeatedRobotArchmage, isFalse);
        expect(defaultCloud.hasShownWeek10ArchmageWarning, isFalse);
        expect(defaultCloud.hasUnreadWeek10WatchtowerAlert, isFalse);
        expect(defaultCloud.savedMetalWizardHp, isNull);

        // 2. Round-trip via CloudSaveData JSON & applyToStorage
        await storage.setHasDefeatedRobotArchmage(true);
        await storage.setHasShownWeek10ArchmageWarning(true);
        await storage.setHasUnreadWeek10WatchtowerAlert(true);
        await storage.setSavedMetalWizardHp(180);

        final snapshot = CloudSaveData.fromStorage(storage);
        final decoded = CloudSaveData.tryParse(json.encode(snapshot.toJson()))!;
        expect(decoded.hasDefeatedRobotArchmage, isTrue);
        expect(decoded.hasShownWeek10ArchmageWarning, isTrue);
        expect(decoded.hasUnreadWeek10WatchtowerAlert, isTrue);
        expect(decoded.savedMetalWizardHp, 180);

        await storage.clearGameplayProgress();
        await decoded.applyToStorage(storage);
        expect(storage.hasDefeatedRobotArchmage, isTrue);
        expect(storage.hasShownWeek10ArchmageWarning, isTrue);
        expect(storage.hasUnreadWeek10WatchtowerAlert, isTrue);
        expect(storage.savedMetalWizardHp, 180);

        // Reload controller with those values
        controller.hasDefeatedRobotArchmage = true;
        controller.hasShownWeek10ArchmageWarning = true;
        controller.hasUnreadWeek10WatchtowerAlert = true;
        controller.savedMetalWizardHp = 180;

        // 3. Forfeit Run resets all 4 flags
        await controller.resetAllProgress();
        expect(controller.hasDefeatedRobotArchmage, isFalse);
        expect(controller.hasShownWeek10ArchmageWarning, isFalse);
        expect(controller.hasUnreadWeek10WatchtowerAlert, isFalse);
        expect(controller.savedMetalWizardHp, isNull);
        expect(storage.hasDefeatedRobotArchmage, isFalse);
        expect(storage.hasShownWeek10ArchmageWarning, isFalse);
        expect(storage.hasUnreadWeek10WatchtowerAlert, isFalse);
        expect(storage.savedMetalWizardHp, isNull);

        // 4. Game Over resets all 4 flags
        await storage.setHasDefeatedRobotArchmage(true);
        await storage.setHasShownWeek10ArchmageWarning(true);
        await storage.setHasUnreadWeek10WatchtowerAlert(true);
        await storage.setSavedMetalWizardHp(180);
        await controller.applyPermadeathReset(
          cause: PermadeathCause.battleDefeat,
        );
        expect(controller.hasDefeatedRobotArchmage, isFalse);
        expect(controller.hasShownWeek10ArchmageWarning, isFalse);
        expect(controller.hasUnreadWeek10WatchtowerAlert, isFalse);
        expect(controller.savedMetalWizardHp, isNull);

        // 5. Week 40 Deadline Exceeded resets all 4 flags
        await storage.setHasDefeatedRobotArchmage(true);
        await storage.setHasShownWeek10ArchmageWarning(true);
        await storage.setHasUnreadWeek10WatchtowerAlert(true);
        await storage.setSavedMetalWizardHp(180);
        controller.currentWeek = GameController.maxCampaignWeeks;
        await controller.applyPermadeathReset(
          cause: PermadeathCause.deadlineExceeded,
        );
        expect(controller.hasDefeatedRobotArchmage, isFalse);
        expect(controller.hasShownWeek10ArchmageWarning, isFalse);
        expect(controller.hasUnreadWeek10WatchtowerAlert, isFalse);
        expect(controller.savedMetalWizardHp, isNull);
      },
    );

    testWidgets(
      'Rule 2: Defeating Guardian Robot before Week 10 and fighting Metal Wizard at 180/300 HP intercepts at Week 10 with Robot Archmage (200 HP), then resumes Metal Wizard at 180/300 HP',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createTestHarness(
          prefs: {
            'current_week': 9,
            'enemy_stage': 3, // Guardian Robot already defeated -> fighting Metal Wizard
            'enemy_max_hp': 300,
            'pcHp': 180,
            'unlockedYourPrediction': true,
            'showYourPrediction': true,
            'orbs_fire': 2000,
            'orbs_water': 2000,
            'orbs_wood': 2000,
            'orbs_earth': 2000,
            'orbs_metal': 2000,
          },
        );
        final controller = harness.controller;
        final storage = harness.storage;
        addTearDown(controller.dispose);

        expect(controller.hasDefeatedGuardianRobot, isTrue);
        expect(controller.hasDefeatedMetalWizard, isFalse);
        expect(controller.hasDefeatedRobotArchmage, isFalse);
        expect(controller.enemyStage, 3);
        expect(controller.enemyHp, 180);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Simulate returning to World Map from the Week 9 Metal Wizard battle (at 180/300 HP)
        // which advances currentWeek from 9 -> 10.
        controller.completeBattleWeek();
        await tester.pumpAndSettle();

        expect(controller.currentWeek, 10);
        expect(controller.savedMetalWizardHp, 180);
        expect(storage.savedMetalWizardHp, 180);
        expect(controller.enemyStage, 2);
        expect(controller.enemyMaxHp, 200);
        expect(controller.enemyHp, 200);
        expect(controller.isArchmageBoss, isTrue);
        expect(controller.enemyUses5Elements, isTrue);
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.archmageRobot),
          isTrue,
        );
        expect(controller.isMarkovRecalibratorVisibleInShop, isTrue);

        // Dismiss the Start-of-Week-10 carousel warning modal
        expect(
          find.byKey(const ValueKey('week10_archmage_warning_dialog')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('week10_archmage_skip_button')),
        );
        await tester.pumpAndSettle();

        // Enter Metal Wizard's Lair -> immediately faces Robot Archmage (200 HP)
        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GameScreen), findsOneWidget);
        expect(controller.enemyStage, 2);
        expect(controller.enemyMaxHp, 200);
        expect(controller.enemyHp, 200);
        expect(controller.savedMetalWizardHp, 180);
        expect(find.text('ROBOT ARCHMAGE'), findsOneWidget);
        expect(find.text('200 / 200'), findsOneWidget);

        // Verify Robot Archmage rules: 5 elements, 1-step short-term AI, cumulative view until Recalibrator bought
        for (int i = 0; i < 6; i++) {
          controller.playTurn(HandMove.rock);
          controller.userHp = controller.playerMaxHp;
          controller.computerHp = 200;
          controller.playTurn(HandMove.paper);
        }
        controller.playTurn(HandMove.rock);
        controller.playTurn(HandMove.rock);
        expect(controller.predictedUserMoves, [HandMove.paper]);
        expect(
          [HandMove.paper, HandMove.lizard].contains(controller.crystalBallMove),
          isTrue,
        );

        // Defeat Robot Archmage (enemyHp <= 0)
        controller.computerHp = 1;
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        await tester.pumpAndSettle();

        expect(controller.enemyHp, 0);
        expect(controller.hasDefeatedRobotArchmage, isTrue);
        expect(storage.hasDefeatedRobotArchmage, isTrue);
        expect(find.byKey(const ValueKey('boss_victory_modal')), findsOneWidget);
        expect(find.text('Robot Archmage Destroyed!'), findsOneWidget);
        expect(find.text('Stage 3: The Metal Wizard Himself!'), findsOneWidget);

        // Confirm defeat modal -> resumes Metal Wizard restored at 180 / 300 HP!
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.enemyStage, 3);
        expect(controller.enemyMaxHp, 300);
        expect(controller.enemyHp, 180);
        expect(storage.pcHp, 180);
        expect(controller.savedMetalWizardHp, isNull);
        expect(storage.savedMetalWizardHp, isNull);
        expect(find.text('METAL WIZARD'), findsOneWidget);
        expect(find.text('180 / 300'), findsOneWidget);
      },
    );

    test(
      'Rule 2 (undamaged Metal Wizard) and Rule 3 (still on Guardian Robot at Week 10) transition cleanly',
      () async {
        // Case A: Undamaged Metal Wizard at Week 10 entry defaults saved HP to 300
        final undamagedHarness = await _createTestHarness(
          prefs: {
            'current_week': 10,
            'enemy_stage': 3,
            'enemy_max_hp': 300,
            'pcHp': 300,
          },
        );
        final c1 = undamagedHarness.controller;
        addTearDown(c1.dispose);

        c1.startNewBattle();
        expect(c1.enemyStage, 2);
        expect(c1.enemyHp, 200);
        expect(c1.savedMetalWizardHp, 300);

        c1.computerHp = 1;
        c1.crystalBallMove = HandMove.rock;
        c1.playTurn(HandMove.paper);
        expect(c1.hasDefeatedRobotArchmage, isTrue);
        c1.advanceAfterBossVictory();

        expect(c1.enemyStage, 3);
        expect(c1.enemyHp, 300);
        expect(c1.savedMetalWizardHp, isNull);

        // Case B: Rule 3 — still on Phase 1 Guardian Robot at Week 10
        final phase1Harness = await _createTestHarness(
          prefs: {
            'current_week': 10,
            'enemy_stage': 1,
            'enemy_max_hp': 100,
            'pcHp': 100,
          },
        );
        final c2 = phase1Harness.controller;
        addTearDown(c2.dispose);

        expect(c2.hasDefeatedGuardianRobot, isFalse);
        c2.startNewBattle();
        expect(c2.enemyStage, 1);
        expect(c2.enemyHp, 100);

        // Defeat Guardian Robot -> Robot Archmage (200 HP) -> Metal Wizard (300 HP)
        c2.computerHp = 1;
        c2.crystalBallMove = HandMove.rock;
        c2.playTurn(HandMove.paper);
        expect(c2.advanceAfterBossVictory(), isFalse);
        expect(c2.enemyStage, 2);
        expect(c2.enemyHp, 200);

        c2.computerHp = 1;
        c2.crystalBallMove = HandMove.rock;
        c2.playTurn(HandMove.paper);
        expect(c2.hasDefeatedRobotArchmage, isTrue);
        expect(c2.advanceAfterBossVictory(), isFalse);
        expect(c2.enemyStage, 3);
        expect(c2.enemyHp, 300);
      },
    );

    testWidgets(
      'Rule 1: Defeating Metal Wizard before Week 9 suppresses Robot Archmage and Week 10 carousel alert at Week 10',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createTestHarness(
          prefs: {
            'current_week': 5,
            'enemy_stage': 3,
            'enemy_max_hp': 300,
            'pcHp': 1,
          },
        );
        final controller = harness.controller;
        addTearDown(controller.dispose);

        // Defeat Metal Wizard in Week 5 -> advances to Stage 5 Temple High Master
        controller.playTurn(HandMove.rock);
        expect(controller.computerHp, 0);
        expect(controller.advanceAfterBossVictory(), isFalse);
        expect(controller.enemyStage, 5);
        expect(controller.hasDefeatedMetalWizard, isTrue);

        // Advance calendar from Week 5 to Week 10
        while (controller.currentWeek < 10) {
          controller.completeBattleWeek();
        }
        expect(controller.currentWeek, 10);
        expect(controller.enemyStage, 5);
        expect(controller.hasDefeatedRobotArchmage, isFalse);
        expect(controller.shouldShowWeek10ArchmageWarning, isFalse);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(
          find.byKey(const ValueKey('week10_archmage_warning_dialog')),
          findsNothing,
        );
        expect(controller.hasShownWeek10ArchmageWarning, isFalse);
        expect(controller.hasUnreadWeek10WatchtowerAlert, isFalse);
        expect(
          find.byKey(const ValueKey('watch_tower_notification_badge')),
          findsNothing,
        );

        // Entering battle at Week 10 continues Sacred Temple flow (Stage 5 -> Stage 4 -> Victory)
        controller.startNewBattle();
        expect(controller.enemyStage, 5);
        expect(controller.enemyHp, 350);
      },
    );

    testWidgets(
      'Start-of-Week-10 carousel warning appears once on WorldMapScreen, shows Watch Tower and Metal Wizard spyglass "!" badges, and clears upon opening Metal Wizard spyglass',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createTestHarness(
          prefs: {
            'current_week': 10,
            'enemy_stage': 1,
            'has_shown_week0_scream_warning': true,
          },
        );
        final controller = harness.controller;
        final storage = harness.storage;
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Carousel dialog rendered with Slide 1
        expect(
          find.byKey(const ValueKey('week10_archmage_warning_dialog')),
          findsOneWidget,
        );
        expect(find.text('WATCH TOWER ALERT'), findsOneWidget);
        expect(find.text('Robot Archmage Identified!'), findsOneWidget);
        expect(find.textContaining('Robot Archmage (200 HP)'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.text('Next'), findsOneWidget);
        expect(controller.hasShownWeek10ArchmageWarning, isTrue);
        expect(storage.hasShownWeek10ArchmageWarning, isTrue);
        expect(controller.hasUnreadWeek10WatchtowerAlert, isTrue);
        expect(storage.hasUnreadWeek10WatchtowerAlert, isTrue);

        // Advance to Slide 2
        await tester.tap(
          find.byKey(const ValueKey('week10_archmage_next_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text("Spy on the Metal Wizard's Lair"), findsOneWidget);
        expect(find.textContaining('Metal Wizard spyglass'), findsOneWidget);
        expect(find.text('Got It'), findsOneWidget);

        // Dismiss via "Got It"
        await tester.tap(
          find.byKey(const ValueKey('week10_archmage_got_it_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('week10_archmage_warning_dialog')),
          findsNothing,
        );

        // Watch Tower landmark on WorldMapScreen shows glowing "!" badge
        final mapBadge = find.byKey(
          const ValueKey('watch_tower_notification_badge'),
        );
        expect(mapBadge, findsOneWidget);
        expect(
          find.descendant(of: mapBadge, matching: find.text('!')),
          findsOneWidget,
        );

        // Open Watch Tower -> Metal Wizard spyglass button shows glowing "!" badge
        await tester.tap(
          find.byKey(const ValueKey('landmark_telescope_tower')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ObservatoryDialog), findsOneWidget);
        final wizardBadge = find.byKey(
          const ValueKey('observatory_wizard_archmage_badge'),
        );
        expect(wizardBadge, findsOneWidget);
        expect(
          find.descendant(of: wizardBadge, matching: find.text('!')),
          findsOneWidget,
        );

        // Tap Metal Wizard spyglass -> opens spyglass and clears unread alert + badges
        final wizardSpyBtn = find.byKey(
          const ValueKey('observatory_spy_wizard_button'),
        );
        await tester.ensureVisible(wizardSpyBtn);
        await tester.pumpAndSettle();
        await tester.tap(wizardSpyBtn);
        await tester.pumpAndSettle();

        expect(find.byType(MetalWizardSpyglassDialog), findsOneWidget);
        expect(controller.hasUnreadWeek10WatchtowerAlert, isFalse);
        expect(storage.hasUnreadWeek10WatchtowerAlert, isFalse);

        await tester.tap(
          find.byKey(const ValueKey('metal_wizard_spyglass_close_button')),
        );
        await tester.pumpAndSettle();
        expect(wizardBadge, findsNothing);

        await tester.tap(
          find.byKey(const ValueKey('observatory_close_button')),
        );
        await tester.pumpAndSettle();
        expect(mapBadge, findsNothing);

        // Advance to Week 11 -> carousel warning does NOT re-appear
        controller.completeBattleWeek();
        await tester.pumpAndSettle();
        expect(controller.currentWeek, 11);
        expect(
          find.byKey(const ValueKey('week10_archmage_warning_dialog')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Week10ArchmageWarningDialog supports Dark Mode (#161A22), Light Mode (#F5EFE2), and en/pt/es/de localizations',
      (WidgetTester tester) async {
        final harness = await _createTestHarness();
        final controller = harness.controller;
        final loc = harness.localization;
        addTearDown(controller.dispose);

        for (final lang in ['en', 'pt', 'es', 'de']) {
          loc.setLanguage(lang);
          for (final key in [
            'week10_archmage_alert_badge',
            'week10_archmage_s1_speaker',
            'week10_archmage_s1_title',
            'week10_archmage_s1_body',
            'week10_archmage_s2_speaker',
            'week10_archmage_s2_title',
            'week10_archmage_s2_body',
            'week10_archmage_got_it',
          ]) {
            final value = loc.t(key, fallback: '__MISSING__');
            expect(value, isNot('__MISSING__'));
            expect(value.trim(), isNotEmpty);
          }
        }
        loc.setLanguage('pt');
        expect(loc.t('week10_archmage_s1_title'), contains('Robô Arquimago'));
        expect(loc.t('week10_archmage_s1_body'), contains('Robô Arquimago'));
        expect(loc.t('week10_archmage_s2_body'), contains('Torre de Vigia'));
        loc.setLanguage('en');

        for (final isDark in [true, false]) {
          controller.darkMode = isDark;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: Week10ArchmageWarningDialog(controller: controller),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final card = tester.widget<Container>(
            find
                .descendant(
                  of: find.byKey(
                    const ValueKey('week10_archmage_warning_dialog'),
                  ),
                  matching: find.byType(Container),
                )
                .first,
          );
          final decoration = card.decoration! as BoxDecoration;
          expect(
            decoration.color,
            isDark ? const Color(0xFF161A22) : const Color(0xFFF5EFE2),
          );
        }
      },
    );
  });
}
