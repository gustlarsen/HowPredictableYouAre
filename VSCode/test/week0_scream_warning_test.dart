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
import 'package:how_predictable/views/dialogs/week0_scream_warning_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/screens/world_map_screen.dart';

class _FakePlayGamesClient implements PlayGamesClient {
  final Map<String, String?> _cloudSaves = {};
  String mockPlayerId = 'week0_player_1';
  String mockPlayerName = 'Week0Cleric';

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

  group('Week 0 Initialization & Post-Week-0 Scream Warning Carousel', () {
    test(
      'Fresh install, StorageService, CloudSaveData, new Play Games account with no cloud save, Forfeit, Permadeath, and Ending completion all start/reset on Week 0',
      () async {
        final fakeClient = _FakePlayGamesClient();
        final harness = await _createTestHarness(client: fakeClient);
        final controller = harness.controller;
        final storage = harness.storage;
        addTearDown(controller.dispose);

        // 1. Fresh install / fresh local storage
        expect(storage.currentWeek, 0);
        expect(controller.currentWeek, 0);
        expect(controller.hasShownWeek0ScreamWarning, isFalse);
        expect(controller.pendingWeek0ScreamWarning, isFalse);
        expect(controller.maxInspectableWorldMapWeek, 1);

        // 2. CloudSaveData defaults to Week 0
        const defaultCloud = CloudSaveData();
        expect(defaultCloud.currentWeek, 0);
        expect(CloudSaveData.fromJson(const {}).currentWeek, 0);

        // 3. New Play Games account with no cloud save starts at Week 0
        await controller.playGames.signIn();
        expect(controller.currentWeek, 0);

        // 4. Advance week and verify Forfeit Run resets to Week 0 & clears warning flag
        controller.completeBattleWeek();
        expect(controller.currentWeek, 1);
        expect(controller.pendingWeek0ScreamWarning, isTrue);
        expect(controller.consumePendingWeek0ScreamWarning(), isTrue);
        expect(controller.hasShownWeek0ScreamWarning, isTrue);

        await controller.resetAllProgress();
        expect(controller.currentWeek, 0);
        expect(storage.currentWeek, 0);
        expect(controller.hasShownWeek0ScreamWarning, isFalse);
        expect(controller.pendingWeek0ScreamWarning, isFalse);

        // 5. Permadeath (Game Over & Week 40 Deadline Exceeded) resets to Week 0
        controller.currentWeek = 5;
        await controller.applyPermadeathReset(
          cause: PermadeathCause.battleDefeat,
        );
        expect(controller.currentWeek, 0);
        expect(controller.hasShownWeek0ScreamWarning, isFalse);

        controller.currentWeek = GameController.maxCampaignWeeks;
        await controller.applyPermadeathReset(
          cause: PermadeathCause.deadlineExceeded,
        );
        expect(controller.currentWeek, 0);

        // 6. Standard Victory ending resets to Week 0
        controller.currentWeek = 12;
        controller.enemyStage = 4;
        controller.computerHp = 1;
        controller.crystalBallMove = HandMove.scissors;
        controller.playTurn(HandMove.rock);
        expect(controller.advanceAfterBossVictory(), isTrue);
        expect(controller.currentWeek, 0);
        expect(controller.hasShownWeek0ScreamWarning, isFalse);

        // 7. Switching to a brand-new Play Games account with no cloud save starts at Week 0
        controller.completeBattleWeek();
        expect(controller.currentWeek, 1);
        fakeClient.mockPlayerId = 'brand_new_account_no_cloud';
        fakeClient.mockPlayerName = 'BrandNewAccount';
        await controller.playGames.signIn();
        expect(controller.currentWeek, 0);
        expect(controller.hasShownWeek0ScreamWarning, isFalse);
      },
    );

    testWidgets(
      'Returning to WorldMapScreen after failing to defeat both Guardian Robot and Metal Wizard on Week 0 shows the 2-slide carousel warning once, and never again in the same run',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createTestHarness();
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

        // Starts cleanly on WorldMapScreen at Week 0 / 40 with no warning dialog
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(find.text('Week 0 / 40'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('week0_scream_warning_dialog')),
          findsNothing,
        );

        // Enter Metal Wizard's Lair on Week 0, defeat Guardian Robot (Stage 1 -> Stage 3),
        // then Teleport before defeating Metal Wizard.
        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GameScreen), findsOneWidget);

        controller.computerHp = 1;
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();
        expect(controller.enemyStage, 3);

        await tester.tap(find.byKey(const ValueKey('teleport_portal_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('teleport_confirm_button')));
        await tester.pumpAndSettle();

        // Returned to WorldMapScreen at Week 1 / 40 and 2-slide carousel dialog appears
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(controller.currentWeek, 1);
        expect(find.text('Week 1 / 40'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('week0_scream_warning_dialog')),
          findsOneWidget,
        );
        expect(find.text('WATCH TOWER ALERT'), findsOneWidget);
        expect(find.text('A Piercing Scream Echoes!'), findsOneWidget);
        expect(find.textContaining('loud, piercing scream'), findsOneWidget);
        expect(find.text('Next'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);

        // Advance to Slide 2
        await tester.tap(
          find.byKey(const ValueKey('week0_scream_next_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Check the Watch Tower'), findsOneWidget);
        expect(find.textContaining('Watch Tower'), findsWidgets);
        expect(find.textContaining('spyglass'), findsOneWidget);
        expect(find.text('Got It'), findsOneWidget);

        // Dismiss via "Got It"
        await tester.tap(
          find.byKey(const ValueKey('week0_scream_got_it_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('week0_scream_warning_dialog')),
          findsNothing,
        );
        expect(controller.hasShownWeek0ScreamWarning, isTrue);
        expect(storage.hasShownWeek0ScreamWarning, isTrue);

        // Visit Lair again on Week 1 and complete 100 rounds -> Week 2, modal must NOT appear again
        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();
        for (int i = 0; i < 100; i++) {
          controller.userHp = controller.playerMaxHp;
          controller.playTurn(HandMove.rock);
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(
          find.byKey(const ValueKey('battle_return_to_map_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.currentWeek, 2);
        expect(
          find.byKey(const ValueKey('week0_scream_warning_dialog')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Defeating both Guardian Robot and Metal Wizard on Week 0 triggers Secret Ending and does NOT display the scream warning',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createTestHarness(
          prefs: {
            'mana_upgrade_level': 220,
          },
        );
        final controller = harness.controller;
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.currentWeek, 0);

        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();

        // Defeat Stage 1 Guardian Robot in Week 0
        controller.computerHp = 1;
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();
        expect(controller.enemyStage, 3);

        // Defeat Stage 3 Metal Wizard in Week 0 -> Secret Ending!
        controller.computerHp = 1;
        controller.playTurn(HandMove.rock);
        expect(
          controller.isEndingUnlocked(NarrativeEnding.secretWeek1),
          isTrue,
        );
        await tester.pumpAndSettle();

        expect(find.text('Week 0 Lightning Victory!'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('SECRET WEEK-0 VICTORY'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('victory_cutscene_skip_button')),
        );
        await tester.pumpAndSettle();

        // Returned to WorldMapScreen at Week 0 with NO scream warning modal
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(controller.currentWeek, 0);
        expect(find.text('Week 0 / 40'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('week0_scream_warning_dialog')),
          findsNothing,
        );
        expect(controller.hasShownWeek0ScreamWarning, isFalse);
        expect(controller.pendingWeek0ScreamWarning, isFalse);
      },
    );

    testWidgets(
      'Fatal 0-HP death on Week 0 resets to Week 0 and does NOT show the scream warning',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createTestHarness();
        final controller = harness.controller;
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();

        controller.userHp = 1;
        controller.crystalBallMove = HandMove.paper;
        controller.playTurn(HandMove.rock);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('death_dialog')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('death_accept_button')));
        await tester.pumpAndSettle();

        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(controller.currentWeek, 0);
        expect(
          find.byKey(const ValueKey('week0_scream_warning_dialog')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Week0ScreamWarningDialog supports Dark Mode (#161A22) and Light Mode (#F5EFE2) and en/pt/es/de localizations',
      (WidgetTester tester) async {
        final harness = await _createTestHarness();
        final controller = harness.controller;
        final loc = harness.localization;
        addTearDown(controller.dispose);

        // Verify translations across all 4 languages including natural Portuguese copy
        for (final lang in ['en', 'pt', 'es', 'de']) {
          loc.setLanguage(lang);
          for (final key in [
            'week0_scream_alert_badge',
            'week0_scream_s1_speaker',
            'week0_scream_s1_title',
            'week0_scream_s1_body',
            'week0_scream_s2_speaker',
            'week0_scream_s2_title',
            'week0_scream_s2_body',
            'week0_scream_got_it',
          ]) {
            final value = loc.t(key, fallback: '__MISSING__');
            expect(value, isNot('__MISSING__'));
            expect(value.trim(), isNotEmpty);
          }
        }
        loc.setLanguage('pt');
        expect(
          loc.t('week0_scream_s1_body'),
          contains('um grito muito alto vindo do covil do mago foi ouvido'),
        );
        loc.setLanguage('en');

        for (final isDark in [true, false]) {
          controller.darkMode = isDark;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: Week0ScreamWarningDialog(controller: controller),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final card = tester.widget<Container>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('week0_scream_warning_dialog')),
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
