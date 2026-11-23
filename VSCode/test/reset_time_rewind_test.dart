import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/theme/app_theme.dart';
import 'package:how_predictable/views/screens/game_screen.dart';

class _FakeAdMobClient implements AdMobClient {
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

class _FakePlayGamesClient implements PlayGamesClient {
  int saveCount = 0;
  String? lastSavedJson;

  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'TimeCleric';

  @override
  Future<String?> getPlayerID() async => 'player_rewind_1';

  @override
  Future<String?> saveGame({
    required String data,
    required String name,
  }) async {
    saveCount++;
    lastSavedJson = data;
    return 'success';
  }

  @override
  Future<String?> loadGame({required String name}) async => lastSavedJson;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Turn 0 Battle Snapshot & Time Rewind Reset Tests', () {
    test(
      'Records Turn 0 baseline snapshot, persists mid-battle across restarts, reverts battle-win and Gift Box orbs, preserves Rewarded Ad +50 orbs, and syncs Cloud Save',
      () async {
        SharedPreferences.setMockInitialValues({
          'orbs_fire': 10,
          'orbs_water': 5,
          'orbs_wood': 0,
          'orbs_earth': 2,
          'orbs_metal': 1,
          'giftBoxUnlocked': true,
          'giftBoxEnabled': true,
          'current_week': 4,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final adService = AdService(client: _FakeAdMobClient());
        await adService.initialize();

        final fakePlayGamesClient = _FakePlayGamesClient();
        final playGames = PlayGamesService(
          storage: storage,
          client: fakePlayGamesClient,
        );
        await playGames.signIn();
        fakePlayGamesClient.saveCount = 0;

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
          adService: adService,
        );
        addTearDown(controller.dispose);

        // Turn 0 snapshot initialized from starting balances
        expect(controller.turn0FireOrbs, 10);
        expect(controller.turn0WaterOrbs, 5);
        expect(controller.turn0WoodOrbs, 0);
        expect(controller.turn0EarthOrbs, 2);
        expect(controller.turn0MetalOrbs, 1);
        expect(controller.totalLostOrbsOnReset, 0);

        // 1. Win 2 Fire orbs (Water beats Fire) and 1 Wood orb (Fire beats Wood)
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        controller.crystalBallMove = HandMove.scissors;
        controller.playTurn(HandMove.rock);
        // Also lose 1 round so userHp drops to 49
        controller.crystalBallMove = HandMove.paper;
        controller.playTurn(HandMove.rock);

        expect(controller.fireOrbs, 12);
        expect(controller.woodOrbs, 1);
        expect(controller.userScore, 3);
        expect(controller.pcScore, 1);
        expect(controller.totalRounds, 4);
        expect(controller.remainingMana, 96);
        expect(controller.userHp, 49);
        expect(controller.computerHp, 97);

        // 2. Claim periodic Gift Box (+5 Fire/Water/Wood in Phase 1) -> reversible
        controller.claimGift();
        expect(controller.fireOrbs, 17);
        expect(controller.waterOrbs, 10);
        expect(controller.woodOrbs, 6);
        expect(controller.earthOrbs, 2);
        expect(controller.metalOrbs, 1);

        // 3. Watch Rewarded Video Ad (+50 Fire/Water/Wood in Phase 1) -> PROTECTED
        final adOk = await controller.watchRewardedAd();
        expect(adOk, isTrue);
        expect(controller.fireOrbs, 67);
        expect(controller.waterOrbs, 60);
        expect(controller.woodOrbs, 56);
        expect(controller.earthOrbs, 2);
        expect(controller.metalOrbs, 1);

        // Turn 0 snapshot grew by +50 for Fire/Water/Wood so Ad orbs are protected
        expect(controller.turn0FireOrbs, 60);
        expect(controller.turn0WaterOrbs, 55);
        expect(controller.turn0WoodOrbs, 50);
        expect(controller.turn0EarthOrbs, 2);
        expect(controller.turn0MetalOrbs, 1);

        // 4. Simulate closing & reopening the app mid-battle
        controller.cancelPendingTimers();
        final reopenedStorage = StorageService();
        await reopenedStorage.init();
        final reopenedController = GameController(
          storage: reopenedStorage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
          adService: adService,
        );
        addTearDown(reopenedController.dispose);

        expect(reopenedController.totalRounds, 4);
        expect(reopenedController.remainingMana, 96);
        expect(reopenedController.fireOrbs, 67);
        expect(reopenedController.turn0FireOrbs, 60);
        expect(reopenedController.lostOrbsFor(HandMove.rock), 7);
        expect(reopenedController.lostOrbsFor(HandMove.paper), 5);
        expect(reopenedController.lostOrbsFor(HandMove.scissors), 6);
        expect(reopenedController.lostOrbsFor(HandMove.lizard), 0);
        expect(reopenedController.lostOrbsFor(HandMove.spock), 0);

        // 5. Confirm Reset (Time Rewind back to Turn 0)
        final savesBeforeReset = fakePlayGamesClient.saveCount;
        reopenedController.resetGame();
        await Future<void>.delayed(Duration.zero);

        // Battle stats, HP, Mana, Markov matrix, and hands restored to Turn 0
        expect(reopenedController.userHp, 50);
        expect(reopenedController.computerHp, 100);
        expect(reopenedController.remainingMana, 100);
        expect(reopenedController.totalRounds, 0);
        expect(reopenedController.turnCount, 0);
        expect(reopenedController.userScore, 0);
        expect(reopenedController.pcScore, 0);
        expect(reopenedController.percentPredict, 0.0);
        expect(reopenedController.currentUserMove, isNull);
        expect(reopenedController.currentComputerMove, isNull);
        expect(reopenedController.lastUserMove, isNull);
        expect(
          reopenedController.engine.matrix.every((r) => r.every((c) => c == 0)),
          isTrue,
        );
        // Week counter must NOT advance on Reset
        expect(reopenedController.currentWeek, 4);

        // Battle-win & Gift Box orbs removed; initial + Rewarded Ad (+50) orbs preserved
        expect(reopenedController.fireOrbs, 60);
        expect(reopenedController.waterOrbs, 55);
        expect(reopenedController.woodOrbs, 50);
        expect(reopenedController.earthOrbs, 2);
        expect(reopenedController.metalOrbs, 1);
        expect(reopenedStorage.fireOrbs, 60);
        expect(reopenedStorage.waterOrbs, 55);
        expect(reopenedStorage.woodOrbs, 50);
        expect(reopenedStorage.earthOrbs, 2);
        expect(reopenedStorage.metalOrbs, 1);
        expect(reopenedController.totalLostOrbsOnReset, 0);

        // Cloud save synced with rewound orbs & reset battle stats
        expect(fakePlayGamesClient.saveCount, greaterThan(savesBeforeReset));
        final saved = CloudSaveData.tryParse(fakePlayGamesClient.lastSavedJson)!;
        expect(saved.fireOrbs, 60);
        expect(saved.turn0FireOrbs, 60);
        expect(saved.total, 0);
        expect(saved.userHp, 50);
        expect(saved.pcHp, 100);
        expect(saved.currentWeek, 4);
      },
    );

    test(
      'startNewBattle and completeBattleWeek preserve current orbs and capture fresh Turn 0 snapshot',
      () async {
        SharedPreferences.setMockInitialValues({
          'orbs_fire': 10,
          'orbs_water': 10,
          'orbs_wood': 10,
          'giftBoxUnlocked': true,
          'giftBoxEnabled': true,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
        );
        addTearDown(controller.dispose);

        // Simulate claiming a Gift Box on WorldMap before entering battle
        controller.claimGift();
        expect(controller.fireOrbs, 15);
        expect(controller.turn0FireOrbs, 10);

        // Entering battle from WorldMap captures post-gift orbs as Turn 0 baseline
        controller.startNewBattle();
        expect(controller.fireOrbs, 15);
        expect(controller.turn0FireOrbs, 15);
        expect(controller.lostOrbsFor(HandMove.rock), 0);

        // Win 1 Fire orb in battle and teleport to World Map -> orb is kept & new baseline updated
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        expect(controller.fireOrbs, 16);
        expect(controller.lostOrbsFor(HandMove.rock), 1);

        controller.teleportToWorldMap();
        expect(controller.currentWeek, 1);
        expect(controller.fireOrbs, 16);
        expect(controller.turn0FireOrbs, 16);
        expect(controller.totalRounds, 0);
        expect(controller.lostOrbsFor(HandMove.rock), 0);
      },
    );

    testWidgets(
      'Reset dialog lists exact lost orbs from battle wins and Gift Box while excluding Rewarded Ad +50 orbs, and rewinds on confirm',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'unlockedReset': true,
          'showReset': true,
          'unlockedNewHands': true,
          'showNewHands': true,
          'giftBoxUnlocked': true,
          'giftBoxEnabled': true,
          'unlockedAlgorithm': true,
          'showAlgorithm': true,
          'orbs_fire': 10,
          'orbs_water': 10,
          'orbs_wood': 10,
          'orbs_earth': 10,
          'orbs_metal': 10,
          'animationsEnabled': false,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();
        final localization = LocalizationService();
        await tester.runAsync(() => localization.load());

        final adService = AdService(client: _FakeAdMobClient());
        await adService.initialize();

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
          adService: adService,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(home: GameScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Win 2 Fire orbs and 1 Wood orb
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        controller.crystalBallMove = HandMove.scissors;
        controller.playTurn(HandMove.rock);
        await tester.pump();

        // Claim Gift Box (+5 each since Earth & Metal unlocked) via AppBar button
        await tester.tap(find.byKey(const ValueKey('gift_box_button')));
        await tester.pumpAndSettle();

        // Watch Rewarded Video Ad (+50 each since Earth & Metal unlocked) via AppBar button
        await tester.tap(find.byKey(const ValueKey('watch_rewarded_ad_button')));
        await tester.pumpAndSettle();

        // Expected balances: Fire=67, Water=65, Wood=66, Earth=65, Metal=65
        // Expected losses on Reset: Fire=-7, Water=-5, Wood=-6, Earth=-5, Metal=-5
        expect(controller.fireOrbs, 67);
        expect(controller.waterOrbs, 65);
        expect(controller.woodOrbs, 66);
        expect(controller.earthOrbs, 65);
        expect(controller.metalOrbs, 65);

        // Tap top-bar Reset button
        await tester.tap(find.byIcon(Icons.restart_alt));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('reset_confirm_dialog')), findsOneWidget);
        expect(find.text('Rewind to Turn 0?'), findsOneWidget);
        expect(
          find.textContaining('Mana to 100, HP to 50, scores to 0'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('reset_orbs_lost_card')), findsOneWidget);
        expect(find.text('-7 Fire'), findsOneWidget);
        expect(find.text('-5 Water'), findsOneWidget);
        expect(find.text('-6 Wood'), findsOneWidget);
        expect(find.text('-5 Earth'), findsOneWidget);
        expect(find.text('-5 Metal'), findsOneWidget);
        expect(find.byKey(const ValueKey('reset_no_orbs_lost_note')), findsNothing);

        // Cancel first -> nothing is lost or reset
        await tester.tap(find.byKey(const ValueKey('reset_cancel_button')));
        await tester.pumpAndSettle();
        expect(controller.fireOrbs, 67);
        expect(controller.totalRounds, 3);
        expect(controller.remainingMana, 97);

        // Open Reset dialog again and confirm RESET
        await tester.tap(find.byIcon(Icons.restart_alt));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('reset_confirm_button')));
        await tester.pumpAndSettle();

        // Rewarded Ad (+50) orbs preserved, battle/gift orbs reverted
        expect(controller.fireOrbs, 60);
        expect(controller.waterOrbs, 60);
        expect(controller.woodOrbs, 60);
        expect(controller.earthOrbs, 60);
        expect(controller.metalOrbs, 60);

        // Mana 100, HP 50, scores 0, Markov cleared
        expect(controller.remainingMana, 100);
        expect(controller.userHp, 50);
        expect(controller.computerHp, 100);
        expect(controller.userScore, 0);
        expect(controller.pcScore, 0);
        expect(controller.totalRounds, 0);
        expect(
          controller.engine.matrix.every((r) => r.every((c) => c == 0)),
          isTrue,
        );
        expect(find.text('Time rewound to Turn 0!'), findsOneWidget);
      },
    );

    testWidgets(
      'Reset dialog hides zero-loss elements, shows clean no-loss note after Rewarded Ad only, and adapts to Light/Dark Mode',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'unlockedReset': true,
          'showReset': true,
          'darkMode': false,
          'animationsEnabled': false,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();
        final localization = LocalizationService();
        await tester.runAsync(() => localization.load());

        final adService = AdService(client: _FakeAdMobClient());
        await adService.initialize();

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
          adService: adService,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(home: GameScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Watch Rewarded Ad (+50) and lose 1 round (0 battle orbs earned)
        await tester.tap(find.byKey(const ValueKey('watch_rewarded_ad_button')));
        await tester.pumpAndSettle();
        controller.crystalBallMove = HandMove.paper;
        controller.playTurn(HandMove.rock);
        await tester.pump();

        expect(controller.userHp, 49);
        expect(controller.remainingMana, 99);
        expect(controller.fireOrbs, 50);

        // Open Reset dialog in Light Mode
        await tester.tap(find.byIcon(Icons.restart_alt));
        await tester.pumpAndSettle();

        const lightPalette = AppPalette(isDark: false);
        final dialog = tester.widget<AlertDialog>(
          find.byKey(const ValueKey('reset_confirm_dialog')),
        );
        expect(dialog.backgroundColor, lightPalette.dialogSurface);
        expect(find.byKey(const ValueKey('reset_orbs_lost_card')), findsNothing);
        expect(
          find.byKey(const ValueKey('reset_no_orbs_lost_note')),
          findsOneWidget,
        );
        expect(find.text('No Elemental Orbs will be lost.'), findsOneWidget);

        // Confirm RESET -> HP & Mana restored, +50 Rewarded Ad orbs preserved
        await tester.tap(find.byKey(const ValueKey('reset_confirm_button')));
        await tester.pumpAndSettle();

        expect(controller.userHp, 50);
        expect(controller.remainingMana, 100);
        expect(controller.fireOrbs, 50);
        expect(controller.waterOrbs, 50);
        expect(controller.woodOrbs, 50);
        expect(controller.earthOrbs, 0);
        expect(controller.metalOrbs, 0);

        // Now win ONLY 1 Fire orb, switch to Dark Mode, and verify only Fire badge is shown
        controller.toggleDarkMode(true);
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.restart_alt));
        await tester.pumpAndSettle();

        final darkDialog = tester.widget<AlertDialog>(
          find.byKey(const ValueKey('reset_confirm_dialog')),
        );
        expect(darkDialog.backgroundColor, const Color(0xFF14161D));
        expect(find.text('-1 Fire'), findsOneWidget);
        expect(find.byKey(const ValueKey('reset_lost_orb_water')), findsNothing);
        expect(find.byKey(const ValueKey('reset_lost_orb_wood')), findsNothing);
        expect(find.byKey(const ValueKey('reset_lost_orb_earth')), findsNothing);
        expect(find.byKey(const ValueKey('reset_lost_orb_metal')), findsNothing);
      },
    );

    test(
      'All new Reset Rewind localization keys exist across en, pt, es, and de',
      () async {
        final localization = LocalizationService();
        await localization.load();

        const keys = [
          'reset_rewind_title',
          'reset_rewind_message',
          'reset_orbs_lost_header',
          'reset_no_orbs_lost',
          'reset_cancel',
          'reset_rewind_done',
        ];
        for (final lang in LocalizationService.supportedLanguages) {
          localization.setLanguage(lang);
          for (final key in keys) {
            final value = localization.t(key);
            expect(value, isNot(key), reason: 'Missing $lang translation for $key');
            expect(value.trim(), isNotEmpty);
          }
        }
      },
    );
  });
}
