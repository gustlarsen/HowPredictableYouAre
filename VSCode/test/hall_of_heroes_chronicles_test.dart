import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/royal_castle_dialog.dart';
import 'package:how_predictable/views/widgets/forfeit_flag_icon.dart';

class _TestAdMobClient implements AdMobClient {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isPrivacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptionsForm({
    OnConsentFormDismissedListener? onDismissed,
  }) async {
    onDismissed?.call(null);
  }

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

class _TestPlayGamesClient implements PlayGamesClient {
  String? mockPlayerId = 'chronicles_player_1';
  String? mockPlayerName = 'ChroniclesHero';
  final Map<String, String?> _cloudSaves = {};
  int saveCount = 0;

  String? get savedPayload => _cloudSaves[mockPlayerId ?? ''];
  set savedPayload(String? val) => _cloudSaves[mockPlayerId ?? ''] = val;

  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => mockPlayerName;

  @override
  Future<String?> getPlayerID() async => mockPlayerId;

  @override
  Future<String?> saveGame({required String data, required String name}) async {
    saveCount++;
    _cloudSaves[mockPlayerId ?? ''] = data;
    return 'success';
  }

  @override
  Future<String?> loadGame({required String name}) async =>
      _cloudSaves[mockPlayerId ?? ''];
}

Future<GameController> _createController({
  Map<String, Object> prefs = const {},
  _TestPlayGamesClient? playGamesClient,
  bool loadStrings = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_story_intro': true,
    'animationsEnabled': false,
    'musicEnabled': false,
    'soundEnabled': false,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();

  final localization = LocalizationService();
  if (loadStrings) {
    await localization.load();
  }

  final adService = AdService(client: _TestAdMobClient());
  await adService.initialize(adsRemoved: storage.unlockedAds);

  PlayGamesService? playGames;
  if (playGamesClient != null) {
    playGames = PlayGamesService(storage: storage, client: playGamesClient);
    await playGames.signIn();
  }

  return GameController(
    storage: storage,
    localization: localization,
    audio: AudioService(),
    adService: adService,
    playGames: playGames,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hall of Heroes Lifetime Chronicles & Run Statistics', () {
    test(
      'Each cycle termination path increments its respective counter and totalCyclesCount, while Turn 0 rewind and Teleport do not',
      () async {
        final controller = await _createController(
          prefs: {'current_week': 1},
        );
        addTearDown(controller.dispose);

        // Play a round, then perform Turn 0 battle rewind (resetGame) -> must NOT increment cycle counters
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        controller.resetGame();
        expect(controller.totalCyclesCount, 0);
        expect(controller.deathDefeatCount, 0);
        expect(controller.timeoutDefeatCount, 0);
        expect(controller.forfeitRunCount, 0);
        expect(controller.standardVictoryCount, 0);
        expect(controller.secretVictoryCount, 0);

        // Play a round, then Teleport to World Map (+1 Week) -> must NOT increment cycle counters
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        controller.teleportToWorldMap();
        expect(controller.currentWeek, 2);
        expect(controller.totalCyclesCount, 0);
        expect(controller.forfeitRunCount, 0);

        // 1. Battle Defeat (0 HP — Ending 1: Ruin)
        await controller.applyPermadeathReset(
          cause: PermadeathCause.battleDefeat,
        );
        expect(controller.deathDefeatCount, 1);
        expect(controller.timeoutDefeatCount, 0);
        expect(controller.totalCyclesCount, 1);

        // 2. Deadline Exceeded (Week 40 — Ending 2: Invasion)
        controller.currentWeek = GameController.maxCampaignWeeks;
        await controller.applyPermadeathReset(
          cause: PermadeathCause.deadlineExceeded,
        );
        expect(controller.timeoutDefeatCount, 1);
        expect(controller.deathDefeatCount, 1);
        expect(controller.totalCyclesCount, 2);

        // 3. Forfeit Run (SettingsDialog)
        await controller.resetAllProgress();
        expect(controller.forfeitRunCount, 1);
        expect(controller.totalCyclesCount, 3);

        // 4. Standard Victory in Week 14 (Stage 1 -> Stage 2 -> Stage 3 -> Stage 5 Temple Master -> Stage 4 Baby Mage)
        controller.currentWeek = 14;
        controller.enemyStage = 1;
        controller.computerHp = 1;
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper); // defeats Guardian Robot
        expect(controller.guardianRobotDefeatedCount, 1);
        expect(controller.advanceAfterBossVictory(), isFalse);
        expect(controller.enemyStage, 2);

        controller.computerHp = 1;
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper); // defeats Robot Archmage
        expect(controller.robotArchmageDefeatedCount, 1);
        expect(controller.advanceAfterBossVictory(), isFalse);
        expect(controller.enemyStage, 3);

        controller.computerHp = 1;
        controller.playTurn(HandMove.rock); // defeats Metal Wizard
        expect(controller.metalWizardDefeatedCount, 1);
        expect(controller.advanceAfterBossVictory(), isFalse);
        expect(controller.enemyStage, 5);

        controller.computerHp = 1;
        controller.crystalBallMove = HandMove.scissors;
        controller.playTurn(HandMove.rock); // defeats Temple High Master
        expect(controller.templeMasterDefeatedCount, 1);
        expect(controller.advanceAfterBossVictory(), isFalse);
        expect(controller.enemyStage, 4);

        controller.computerHp = 1;
        controller.setCrystalBallDualMoves(HandMove.wood, HandMove.metal);
        controller.playTurn(HandMove.rock); // Fire beats Wood + Metal -> defeats Baby Mage Robot
        expect(controller.babyMageRobotDefeatedCount, 1);
        expect(controller.standardVictoryCount, 1);
        expect(controller.totalCyclesCount, 4);
        expect(controller.fastestVictoryWeek, 14);
        expect(controller.advanceAfterBossVictory(), isTrue);

        // 5. Secret Week-0 Victory (Stage 1 -> Stage 3 on Week 0) updates fastestVictoryWeek to 0
        controller.currentWeek = 0;
        controller.enemyStage = 1;
        controller.computerHp = 1;
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper); // defeats Guardian Robot
        expect(controller.guardianRobotDefeatedCount, 2);
        expect(controller.advanceAfterBossVictory(), isFalse);
        expect(controller.enemyStage, 3);

        controller.computerHp = 1;
        controller.playTurn(HandMove.rock); // defeats Metal Wizard on Week 0
        expect(controller.metalWizardDefeatedCount, 2);
        expect(controller.secretVictoryCount, 1);
        expect(controller.totalCyclesCount, 5);
        expect(controller.fastestVictoryWeek, 0);
        expect(controller.advanceAfterBossVictory(), isTrue);

        // Subsequent slower Standard Victory (Week 25) keeps fastestVictoryWeek at 0
        controller.currentWeek = 25;
        controller.enemyStage = 4;
        controller.computerHp = 1;
        controller.setCrystalBallDualMoves(HandMove.wood, HandMove.metal);
        controller.playTurn(HandMove.rock);
        expect(controller.babyMageRobotDefeatedCount, 2);
        expect(controller.standardVictoryCount, 2);
        expect(controller.totalCyclesCount, 6);
        expect(controller.fastestVictoryWeek, 0);
      },
    );

    test(
      'Lifetime counters and fastestVictoryWeek survive Forfeit Run, 0 HP defeat, StorageService reload, and PlayGamesService Cloud Save merge',
      () async {
        final playGamesClient = _TestPlayGamesClient();
        final controller = await _createController(
          playGamesClient: playGamesClient,
          prefs: {
            'current_week': 12,
            'total_cycles_count': 4,
            'death_defeat_count': 1,
            'timeout_defeat_count': 1,
            'forfeit_run_count': 1,
            'standard_victory_count': 1,
            'secret_victory_count': 0,
            'fastest_victory_week': 12,
            'guardian_robot_defeated_count': 3,
            'robot_archmage_defeated_count': 1,
            'metal_wizard_defeated_count': 2,
            'baby_mage_robot_defeated_count': 1,
          },
        );
        addTearDown(controller.dispose);

        // Forfeit Run & 0 HP defeat never reset lifetime stats (they increment them)
        await controller.resetAllProgress();
        await controller.applyPermadeathReset(
          cause: PermadeathCause.battleDefeat,
        );
        expect(controller.totalCyclesCount, 6);
        expect(controller.forfeitRunCount, 2);
        expect(controller.deathDefeatCount, 2);
        expect(controller.timeoutDefeatCount, 1);
        expect(controller.standardVictoryCount, 1);
        expect(controller.fastestVictoryWeek, 12);
        expect(controller.guardianRobotDefeatedCount, 3);
        expect(controller.robotArchmageDefeatedCount, 1);
        expect(controller.metalWizardDefeatedCount, 2);
        expect(controller.babyMageRobotDefeatedCount, 1);

        // StorageService reload preserves all lifetime counters
        final reloadedStorage = StorageService();
        await reloadedStorage.init();
        expect(reloadedStorage.totalCyclesCount, 6);
        expect(reloadedStorage.deathDefeatCount, 2);
        expect(reloadedStorage.timeoutDefeatCount, 1);
        expect(reloadedStorage.forfeitRunCount, 2);
        expect(reloadedStorage.standardVictoryCount, 1);
        expect(reloadedStorage.secretVictoryCount, 0);
        expect(reloadedStorage.fastestVictoryWeek, 12);
        expect(reloadedStorage.guardianRobotDefeatedCount, 3);
        expect(reloadedStorage.robotArchmageDefeatedCount, 1);
        expect(reloadedStorage.metalWizardDefeatedCount, 2);
        expect(reloadedStorage.babyMageRobotDefeatedCount, 1);

        // CloudSaveData JSON round-trip
        final parsedCloud = CloudSaveData.tryParse(playGamesClient.savedPayload)!;
        expect(parsedCloud.totalCyclesCount, 6);
        expect(parsedCloud.deathDefeatCount, 2);
        expect(parsedCloud.timeoutDefeatCount, 1);
        expect(parsedCloud.forfeitRunCount, 2);
        expect(parsedCloud.standardVictoryCount, 1);
        expect(parsedCloud.secretVictoryCount, 0);
        expect(parsedCloud.fastestVictoryWeek, 12);
        expect(parsedCloud.guardianRobotDefeatedCount, 3);
        expect(parsedCloud.robotArchmageDefeatedCount, 1);
        expect(parsedCloud.metalWizardDefeatedCount, 2);
        expect(parsedCloud.babyMageRobotDefeatedCount, 1);

        // Merge with max(local, cloud) and min non-zero fastestVictoryWeek
        const localSave = CloudSaveData(
          totalCyclesCount: 6,
          deathDefeatCount: 2,
          timeoutDefeatCount: 3,
          forfeitRunCount: 2,
          standardVictoryCount: 1,
          secretVictoryCount: 0,
          fastestVictoryWeek: 12,
          guardianRobotDefeatedCount: 5,
          robotArchmageDefeatedCount: 1,
          metalWizardDefeatedCount: 2,
          babyMageRobotDefeatedCount: 1,
        );
        const cloudSave = CloudSaveData(
          totalCyclesCount: 8,
          deathDefeatCount: 4,
          timeoutDefeatCount: 1,
          forfeitRunCount: 1,
          standardVictoryCount: 2,
          secretVictoryCount: 1,
          fastestVictoryWeek: 1,
          guardianRobotDefeatedCount: 3,
          robotArchmageDefeatedCount: 3,
          metalWizardDefeatedCount: 4,
          babyMageRobotDefeatedCount: 2,
        );
        final merged = cloudSave.mergeOverLocal(localSave);
        expect(merged.totalCyclesCount, 8);
        expect(merged.deathDefeatCount, 4);
        expect(merged.timeoutDefeatCount, 3);
        expect(merged.forfeitRunCount, 2);
        expect(merged.standardVictoryCount, 2);
        expect(merged.secretVictoryCount, 1);
        expect(merged.fastestVictoryWeek, 1);
        expect(merged.guardianRobotDefeatedCount, 5);
        expect(merged.robotArchmageDefeatedCount, 3);
        expect(merged.metalWizardDefeatedCount, 4);
        expect(merged.babyMageRobotDefeatedCount, 2);

        // Min valid week ignores null / negative sentinel on either side, and preserves Week 0
        expect(
          const CloudSaveData(fastestVictoryWeek: null)
              .mergeOverLocal(const CloudSaveData(fastestVictoryWeek: 14))
              .fastestVictoryWeek,
          14,
        );
        expect(
          const CloudSaveData(fastestVictoryWeek: 9)
              .mergeOverLocal(const CloudSaveData(fastestVictoryWeek: -1))
              .fastestVictoryWeek,
          9,
        );
        expect(
          const CloudSaveData(fastestVictoryWeek: 0)
              .mergeOverLocal(const CloudSaveData(fastestVictoryWeek: 9))
              .fastestVictoryWeek,
          0,
        );

        // When local has more orbs than cloud, loadAndResolveCloudSave still merges higher cloud chronicles
        await reloadedStorage.setFireOrbs(999);
        playGamesClient.savedPayload = cloudSave.toJsonString();
        await controller.playGames.loadAndResolveCloudSave();
        expect(controller.totalCyclesCount, 8);
        expect(controller.fastestVictoryWeek, 1);
        expect(controller.secretVictoryCount, 1);
        expect(controller.fireOrbs, 999);

        // Account switch resets lifetime chronicles for the fresh account
        playGamesClient.mockPlayerId = 'chronicles_player_2';
        playGamesClient.mockPlayerName = 'FreshAccount';
        await controller.playGames.signIn();
        expect(controller.totalCyclesCount, 0);
        expect(controller.fastestVictoryWeek, isNull);
        expect(controller.guardianRobotDefeatedCount, 0);
      },
    );

    testWidgets(
      'RoyalCastleDialog Heroes tab renders Kingdom Chronicles, 4 Endings, Forfeited Runs, and Bosses Defeated in Dark & Light Mode even when hallOfHeroesClaimAvailable == false',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Case A: Fresh account (no blessings, no victories -> '--' fastest victory)
        final freshController = await _createController(
          loadStrings: true,
          prefs: {'hall_of_heroes_claim_available': false},
        );
        addTearDown(freshController.dispose);

        for (final isDark in [true, false]) {
          freshController.darkMode = isDark;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: RoyalCastleDialog(
                  controller: freshController,
                  initialWing: CastleWing.hallOfHeroes,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(
            find.byKey(const ValueKey('hall_of_heroes_empty_state')),
            findsOneWidget,
          );
          expect(
            find.text('No fallen hero blessings awaiting restoration.'),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('heroes_kingdom_chronicles_header')),
            findsOneWidget,
          );
          expect(find.text('Kingdom Chronicles'), findsOneWidget);
          expect(find.text('Total Cycles / Resets'), findsOneWidget);
          expect(find.text('Fastest Victory'), findsOneWidget);
          expect(find.text('--'), findsOneWidget);
          expect(find.text('Ending I: Ruin'), findsOneWidget);
          expect(find.text('Ending II: Invasion'), findsOneWidget);
          expect(find.text('Ending III: Sanctuary Victory'), findsOneWidget);
          expect(find.text('Ending IV: Flawless Rescue'), findsOneWidget);
          expect(find.text('Ending V: The Sacred Sacrifice'), findsOneWidget);
          expect(find.text('Ending VI: The Deserter'), findsOneWidget);
          expect(find.text('Forfeited Runs'), findsOneWidget);
          expect(find.byType(ForfeitFlagIcon), findsOneWidget);
          expect(find.text('Bosses Defeated'), findsOneWidget);
          expect(find.text('Guardian Robot'), findsOneWidget);
          expect(find.text('Robot Archmage'), findsOneWidget);
          expect(find.text('Metal Wizard'), findsOneWidget);
          expect(find.text('Temple High Master'), findsOneWidget);
          expect(find.text('Baby Mage Robot'), findsOneWidget);
        }

        // Case B: Claimed this cycle (hallOfHeroesClaimAvailable == false with peaks > 0 & populated stats)
        final veteranController = await _createController(
          loadStrings: true,
          prefs: {
            'hall_of_heroes_claim_available': false,
            'peak_hp_upgrade_level': 6,
            'peak_mana_upgrade_level': 4,
            'total_cycles_count': 17,
            'death_defeat_count': 5,
            'timeout_defeat_count': 2,
            'forfeit_run_count': 4,
            'standard_victory_count': 3,
            'secret_victory_count': 3,
            'fastest_victory_week': 0,
            'guardian_robot_defeated_count': 12,
            'robot_archmage_defeated_count': 7,
            'metal_wizard_defeated_count': 9,
            'baby_mage_robot_defeated_count': 3,
          },
        );
        addTearDown(veteranController.dispose);

        for (final isDark in [true, false]) {
          veteranController.darkMode = isDark;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: RoyalCastleDialog(
                  controller: veteranController,
                  initialWing: CastleWing.hallOfHeroes,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(
            find.text('Blessing already claimed this cycle'),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('hall_of_heroes_peak_hp_chip')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('hall_of_heroes_peak_mana_chip')),
            findsOneWidget,
          );
          expect(find.text('17'), findsOneWidget);
          expect(find.text('Week 0'), findsAtLeastNWidgets(2));
          expect(find.text('5'), findsOneWidget);
          expect(find.text('2'), findsOneWidget);
          expect(find.text('4'), findsOneWidget);
          expect(find.text('12'), findsOneWidget);
          expect(find.text('7'), findsOneWidget);
          expect(find.text('9'), findsOneWidget);

          // Scroll down to ensure Bosses Defeated cards are cleanly reachable
          final scrollFinder = find.byKey(
            const ValueKey('castle_wing_scroll_hallOfHeroes'),
          );
          await tester.drag(scrollFinder, const Offset(0, -300));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('heroes_boss_baby_mage_card')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );

    test(
      'All new Hall of Heroes Kingdom Chronicles localization keys exist across en, pt, es, and de',
      () async {
        final rawJson =
            await rootBundle.loadString('assets/data/stringsHowPredict.json');
        final map = json.decode(rawJson) as Map<String, dynamic>;

        const keys = [
          'castle_heroes_already_claimed',
          'castle_heroes_chronicles_title',
          'castle_heroes_total_cycles',
          'castle_heroes_fastest_victory',
          'castle_heroes_forfeited_runs',
          'castle_heroes_ending_1_title',
          'castle_heroes_ending_1_sub',
          'castle_heroes_ending_2_title',
          'castle_heroes_ending_2_sub',
          'castle_heroes_ending_3_title',
          'castle_heroes_ending_3_sub',
          'castle_heroes_ending_4_title',
          'castle_heroes_ending_4_sub',
          'castle_heroes_bosses_defeated',
        ];

        for (final lang in ['en', 'pt', 'es', 'de']) {
          for (final key in keys) {
            final flat = '${lang}_$key';
            expect(map[flat], isA<String>(), reason: 'Missing $flat');
            expect(
              (map[flat] as String).trim(),
              isNotEmpty,
              reason: 'Empty $flat',
            );
          }
        }
        expect(map['pt_castle_heroes_forfeited_runs'], 'Desistências');
      },
    );
  });
}
