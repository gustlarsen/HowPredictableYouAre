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
import 'package:how_predictable/services/billing_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/theme/app_theme.dart';
import 'package:how_predictable/views/dialogs/royal_castle_dialog.dart';
import 'package:how_predictable/views/screens/world_map_screen.dart';

class _TestAdMobClient implements AdMobClient {
  bool rewardedAvailable;
  bool grantRewardOnShow;
  int showRewardedCount = 0;

  _TestAdMobClient({
    this.rewardedAvailable = true,
    this.grantRewardOnShow = true,
  });

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
    if (rewardedAvailable) {
      onLoaded();
    } else {
      onFailed();
    }
  }

  @override
  Future<bool> showRewarded({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onDismissed,
    required VoidCallback onFailedToShow,
  }) async {
    showRewardedCount++;
    if (!rewardedAvailable) {
      onFailedToShow();
      return false;
    }
    if (grantRewardOnShow) {
      onUserEarnedReward();
    }
    onDismissed();
    return true;
  }

  @override
  void disposeRewarded() {}
}

class _TestPlayGamesClient implements PlayGamesClient {
  String? savedPayload;

  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'CastleTester';

  @override
  Future<String?> getPlayerID() async => 'castle_tester_1';

  @override
  Future<String?> saveGame({
    required String data,
    required String name,
  }) async {
    savedPayload = data;
    return 'success';
  }

  @override
  Future<String?> loadGame({required String name}) async => savedPayload;
}

Future<GameController> _createController({
  Map<String, Object> prefs = const {},
  _TestAdMobClient? adClient,
  _TestPlayGamesClient? playGamesClient,
  bool loadJsonStrings = false,
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
  if (loadJsonStrings) {
    await localization.load();
  }

  final adService = AdService(client: adClient ?? _TestAdMobClient());
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

  group('Royal Castle Hub Unit & Logic Tests', () {
    test(
      'Winning rounds mirrors +1 orb to Royal Treasury (capped at 50 per element) and claiming transfers & resets to 0',
      () async {
        final adClient = _TestAdMobClient(grantRewardOnShow: false);
        final controller = await _createController(adClient: adClient);
        addTearDown(controller.dispose);

        // Win 52 Fire orbs (Paper beats Rock/Fire in elemental mode)
        for (int i = 0; i < 52; i++) {
          controller.crystalBallMove = HandMove.rock;
          controller.playTurn(HandMove.paper);
        }

        // Backpack receives all 52; Treasury caps Fire at 50 per element
        // (and defeat15 Royal Decree deposits +5 to each element).
        expect(controller.fireOrbs, 52);
        expect(controller.treasuryFireOrbs, 50);
        expect(controller.treasuryWaterOrbs, 5);
        expect(controller.totalTreasuryOrbs, 70);
        expect(controller.isAnyTreasuryElementFull, isTrue);
        expect(controller.hasRoyalCastleNotification, isTrue);

        // Early ad dismissal does not claim or reset Treasury
        final failedClaim = await controller.watchAdToClaimTreasury();
        expect(failedClaim, isFalse);
        expect(controller.fireOrbs, 52);
        expect(controller.treasuryFireOrbs, 50);

        // Complete rewarded ad transfers Treasury orbs & resets Treasury to 0
        adClient.grantRewardOnShow = true;
        final okClaim = await controller.watchAdToClaimTreasury();
        expect(okClaim, isTrue);
        expect(controller.fireOrbs, 102);
        expect(controller.waterOrbs, 5);
        expect(controller.turn0FireOrbs, 50);
        expect(controller.treasuryFireOrbs, 0);
        expect(controller.totalTreasuryOrbs, 0);
        expect(controller.isAnyTreasuryElementFull, isFalse);
        expect(controller.hasRoyalCastleNotification, isFalse);
      },
    );

    test(
      'Remove Ads users can claim Treasury, restore Relics, and reclaim Spoils directly without watching an ad',
      () async {
        final adClient = _TestAdMobClient(rewardedAvailable: false);
        final controller = await _createController(
          adClient: adClient,
          prefs: {
            'unlockedAds': true,
            'removeAdsEnabled': true,
            'treasury_orbs_water': 12,
            'spoils_orbs_wood': 7,
            'relic_chamber_upgrades': ['reset', 'algorithm'],
          },
        );
        addTearDown(controller.dispose);

        expect(controller.isRemoveAdsActive, isTrue);
        expect(controller.claimTreasuryDirect(), isTrue);
        expect(controller.waterOrbs, 12);
        expect(controller.treasuryWaterOrbs, 0);

        expect(controller.restoreRelicsDirect(), isTrue);
        expect(controller.unlockedReset, isTrue);
        expect(controller.unlockedAlgorithm, isTrue);
        expect(controller.relicChamberStoredUpgrades, isEmpty);

        expect(controller.reclaimSpoilsDirect(), isTrue);
        expect(controller.woodOrbs, 7);
        expect(controller.spoilsWoodOrbs, 0);
        expect(adClient.showRewardedCount, 0);
      },
    );

    test(
      'Turn 0 Reset & Campaign Defeat accumulate lost orbs in Spoils of War, and claiming prevents reset duplication',
      () async {
        final controller = await _createController(
          prefs: {
            'orbs_fire': 10,
            'orbs_water': 4,
            'unlockedReset': true,
            'unlockedAlgorithm': true,
            'iap_purchased_product_ids': [BillingService.productSuggestion],
            'unlockedSuggestion': true,
          },
        );
        addTearDown(controller.dispose);

        // Win 2 Fire orbs and 1 Wood orb in battle
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        controller.crystalBallMove = HandMove.scissors;
        controller.playTurn(HandMove.rock);
        expect(controller.fireOrbs, 12);
        expect(controller.woodOrbs, 1);

        // 1. Confirm Turn 0 Battle Reset -> lost orbs (+2 Fire, +1 Wood) enter Spoils of War
        controller.resetGame();
        expect(controller.fireOrbs, 10);
        expect(controller.woodOrbs, 0);
        expect(controller.spoilsFireOrbs, 2);
        expect(controller.spoilsWoodOrbs, 1);
        expect(controller.hasSpoilsOfWarOrbs, isTrue);

        // 2. Campaign Defeat -> remaining backpack orbs (+10 Fire, +4 Water) accumulate into Spoils of War
        //    and orb-bought upgrades enter Relic Chamber (excluding paid IAP 'suggestion')
        await controller.applyPermadeathReset();
        expect(controller.fireOrbs, 0);
        expect(controller.waterOrbs, 0);
        expect(controller.spoilsFireOrbs, 12);
        expect(controller.spoilsWaterOrbs, 4);
        expect(controller.spoilsWoodOrbs, 1);
        expect(controller.unlockedReset, isFalse);
        expect(controller.unlockedAlgorithm, isFalse);
        expect(controller.unlockedSuggestion, isTrue);
        expect(
          controller.relicChamberStoredUpgrades,
          containsAll(['reset', 'algorithm']),
        );
        expect(
          controller.relicChamberStoredUpgrades,
          isNot(contains('suggestion')),
        );
        expect(controller.isEndingUnlocked(NarrativeEnding.kingdomFall), isTrue);

        // 3. Reclaim Spoils of War -> restores orbs, updates Turn 0 baseline, and zeroes Spoils
        final reclaimed = await controller.watchAdToReclaimSpoils();
        expect(reclaimed, isTrue);
        expect(controller.fireOrbs, 12);
        expect(controller.waterOrbs, 4);
        expect(controller.woodOrbs, 1);
        expect(controller.turn0FireOrbs, 12);
        expect(controller.turn0WaterOrbs, 4);
        expect(controller.turn0WoodOrbs, 1);
        expect(controller.totalSpoilsOfWarOrbs, 0);

        // Anti-exploit: resetting immediately afterward must NOT re-add reclaimed orbs to Spoils
        controller.resetGame();
        expect(controller.totalSpoilsOfWarOrbs, 0);
        expect(controller.fireOrbs, 12);

        // 4. Restore Relic Chamber -> unlocks stored upgrades and clears Relic Chamber
        final restored = await controller.watchAdToRestoreRelics();
        expect(restored, isTrue);
        expect(controller.unlockedReset, isTrue);
        expect(controller.unlockedAlgorithm, isTrue);
        expect(controller.relicChamberStoredUpgrades, isEmpty);
        expect(controller.hasAvailableRelicChamberUpgrades, isFalse);

        // Anti-exploit: claiming again returns false
        expect(await controller.watchAdToRestoreRelics(), isFalse);
      },
    );

    test(
      '3-to-1 Royal Alchemy deducts 3 source orbs, adds 1 target orb, and rejects invalid exchanges',
      () async {
        final controller = await _createController(
          prefs: {'orbs_fire': 7, 'orbs_water': 1},
        );
        addTearDown(controller.dispose);

        // Cannot transmute to same element
        expect(controller.transmuteOrbs(HandMove.rock, HandMove.rock), isFalse);
        // Cannot transmute when < 3
        expect(controller.transmuteOrbs(HandMove.paper, HandMove.rock), isFalse);

        // Valid 3 Fire -> 1 Earth
        expect(controller.transmuteOrbs(HandMove.rock, HandMove.lizard), isTrue);
        expect(controller.fireOrbs, 4);
        expect(controller.earthOrbs, 1);
        expect(controller.turn0FireOrbs, 4);
        expect(controller.turn0EarthOrbs, 1);
      },
    );

    test(
      'Royal Decrees, Arcane Bestiary, Narrative Endings, and CloudSaveData sync work end-to-end',
      () async {
        final playGamesClient = _TestPlayGamesClient();
        final controller = await _createController(
          playGamesClient: playGamesClient,
          prefs: {'current_week': 10},
        );
        addTearDown(controller.dispose);

        // Play 15 wins alternating Paper & Rock so no consecutive element repeats (completes both noRepeatWin10 & defeat15!)
        for (int i = 0; i < 15; i++) {
          if (i.isEven) {
            controller.crystalBallMove = HandMove.rock;
            controller.playTurn(HandMove.paper);
          } else {
            controller.crystalBallMove = HandMove.scissors;
            controller.playTurn(HandMove.rock);
          }
        }

        expect(
          controller.isDecreeCompletedInCycle(RoyalDecreeType.noRepeatWin10),
          isTrue,
        );
        expect(
          controller.isDecreeCompletedInCycle(RoyalDecreeType.defeat15),
          isTrue,
        );
        expect(controller.totalDecreesCompleted, 2);
        // Bonus orbs deposited into Royal Treasury (5 + 5 = 10 per element + round wins)
        expect(controller.treasuryWaterOrbs, 10);
        expect(controller.treasuryEarthOrbs, 10);

        // Bestiary: Baby Robot (turn 1 random), Guardian Robot (turn 2+ prediction), Archmage Robot (Week 10)
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.babyRobot),
          isTrue,
        );
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.guardianRobot),
          isTrue,
        );
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.archmageRobot),
          isTrue,
        );

        // Complete 100 rounds at 100% score -> unlocks ending_perfect & predictAbove70 decree
        for (int i = 15; i < 100; i++) {
          controller.crystalBallMove = HandMove.rock;
          controller.playTurn(HandMove.paper);
        }
        expect(
          controller.isEndingUnlocked(NarrativeEnding.perfectPredictor),
          isTrue,
        );
        expect(
          controller.isDecreeCompletedInCycle(RoyalDecreeType.predictAbove70),
          isTrue,
        );

        // CloudSaveData round-trip check
        final cloud = CloudSaveData.tryParse(playGamesClient.savedPayload)!;
        expect(cloud.totalDecreesCompleted, 3);
        expect(cloud.unlockedEndings, contains('ending_perfect'));
        expect(
          cloud.encounteredBestiary,
          containsAll(['baby_robot', 'guardian_robot', 'archmage_robot']),
        );
        expect(cloud.treasuryWaterOrbs, greaterThanOrEqualTo(10));
      },
    );
  });

  group('Royal Castle Hub Widget & Theme Tests', () {
    testWidgets(
      'All 5 Royal Castle tabs render cleanly in both Dark Mode and Light Mode and support interactive claims & alchemy',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          loadJsonStrings: true,
          prefs: {
            'current_week': 10,
            'orbs_fire': 9,
            'orbs_water': 2,
            'treasury_orbs_fire': 50,
            'treasury_orbs_wood': 10,
            'spoils_orbs_earth': 6,
            'relic_chamber_upgrades': ['reset'],
            'unlocked_endings': ['ending_perfect'],
            'encountered_bestiary': ['guardian_robot'],
          },
        );
        addTearDown(controller.dispose);

        for (final isDark in [true, false]) {
          controller.darkMode = isDark;
          final expectedPalette = AppPalette(isDark: isDark);

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: RoyalCastleDialog(controller: controller),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Check dialog surface adapts properly to Dark vs Light theme
          final dialog = tester.widget<Dialog>(
            find.byKey(const ValueKey('royal_castle_dialog')),
          );
          expect(dialog.backgroundColor, expectedPalette.dialogSurface);

          // Wing 1: Throne Room + Milestones + Royal Decrees
          final throneTab = find.byKey(const ValueKey('castle_tab_throne'));
          await tester.ensureVisible(throneTab);
          await tester.pumpAndSettle();
          await tester.tap(throneTab);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('castle_wing_throne_room')),
            findsOneWidget,
          );
          expect(find.text('Royal Decrees'), findsOneWidget);
          expect(find.text('Unbroken Variety'), findsOneWidget);

          // Wing 2: Library (Endings X/4 + Bestiary + Story Memories)
          final libTab = find.byKey(const ValueKey('castle_tab_library'));
          await tester.ensureVisible(libTab);
          await tester.pumpAndSettle();
          await tester.tap(libTab);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('castle_wing_library')),
            findsOneWidget,
          );
          expect(find.text('Endings Discovered: 1 / 4'), findsOneWidget);
          expect(find.text('Guardian Robot'), findsOneWidget);
          expect(find.text('Story Memories'), findsOneWidget);

          // Wing 3: Treasury (Piggy Bank + 3-to-1 Alchemy)
          final treasuryTab = find.byKey(const ValueKey('castle_tab_treasury'));
          await tester.ensureVisible(treasuryTab);
          await tester.pumpAndSettle();
          await tester.tap(treasuryTab);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('castle_wing_treasury')),
            findsOneWidget,
          );
          expect(find.text('FULL'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('treasury_claim_ad_button')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('alchemy_transmute_button')),
            findsOneWidget,
          );

          // Wing 4: Relic Chamber
          final relicsTab = find.byKey(const ValueKey('castle_tab_relics'));
          await tester.ensureVisible(relicsTab);
          await tester.pumpAndSettle();
          await tester.tap(relicsTab);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('castle_wing_relic_chamber')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('relic_chamber_restore_ad_button')),
            findsOneWidget,
          );

          // Wing 5: Spoils of War
          final spoilsTab = find.byKey(const ValueKey('castle_tab_spoils'));
          await tester.ensureVisible(spoilsTab);
          await tester.pumpAndSettle();
          await tester.tap(spoilsTab);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('castle_wing_spoils_of_war')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('spoils_reclaim_ad_button')),
            findsOneWidget,
          );
        }

        // Now test interactive Alchemy + Claiming inside UI
        final treasuryTab = find.byKey(const ValueKey('castle_tab_treasury'));
        await tester.ensureVisible(treasuryTab);
        await tester.pumpAndSettle();
        await tester.tap(treasuryTab);
        await tester.pumpAndSettle();

        // Transmute 3 Fire -> 1 Water
        await tester.ensureVisible(
          find.byKey(const ValueKey('alchemy_transmute_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('alchemy_transmute_button')));
        await tester.pumpAndSettle();
        expect(controller.fireOrbs, 6);
        expect(controller.waterOrbs, 3);

        // Claim Treasury via Rewarded Ad
        await tester.ensureVisible(
          find.byKey(const ValueKey('treasury_claim_ad_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('treasury_claim_ad_button')));
        await tester.pumpAndSettle();
        expect(controller.fireOrbs, 56);
        expect(controller.woodOrbs, 10);
        expect(controller.totalTreasuryOrbs, 0);
      },
    );

    testWidgets(
      'WorldMapScreen displays pulsing golden notification badge on Royal Castle when Treasury full, Relics stored, or Spoils waiting, and hides it after claiming',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          loadJsonStrings: true,
          prefs: {
            'treasury_orbs_fire': 50,
            'unlockedAds': true,
            'removeAdsEnabled': true,
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

        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(
          find.byKey(const ValueKey('royal_castle_notification_badge')),
          findsOneWidget,
        );

        // Open Royal Castle, switch to Treasury, claim directly, close
        await tester.tap(find.byKey(const ValueKey('landmark_royal_castle')));
        await tester.pumpAndSettle();
        final treasuryTab = find.byKey(const ValueKey('castle_tab_treasury'));
        await tester.ensureVisible(treasuryTab);
        await tester.pumpAndSettle();
        await tester.tap(treasuryTab);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('treasury_claim_direct_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('royal_castle_close_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('royal_castle_notification_badge')),
          findsNothing,
        );
      },
    );
  });
}
