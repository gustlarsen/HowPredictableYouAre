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
import 'package:how_predictable/views/widgets/elemental_energy_sphere.dart';
import 'package:how_predictable/views/widgets/royal_castle_icon.dart';

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

        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

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

          // All 6 compact tabs are visible in a single horizontal row
          final tabKeys = [
            const ValueKey('castle_tab_throne'),
            const ValueKey('castle_tab_library'),
            const ValueKey('castle_tab_treasury'),
            const ValueKey('castle_tab_relics'),
            const ValueKey('castle_tab_spoils'),
            const ValueKey('castle_tab_hall_of_heroes'),
          ];
          final firstTabY = tester.getTopLeft(find.byKey(tabKeys.first)).dy;
          for (final key in tabKeys) {
            expect(find.byKey(key), findsOneWidget);
            expect(tester.getTopLeft(find.byKey(key)).dy, closeTo(firstTabY, 1.0));
          }
          expect(find.byKey(const Key('castle_tab_treasury_dot')), findsOneWidget);
          expect(find.byKey(const Key('castle_tab_relics_dot')), findsOneWidget);
          expect(find.byKey(const Key('castle_tab_spoils_dot')), findsOneWidget);

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

          // Wing 3: Treasury (Piggy Bank 3D Orbs + Visual 3-to-1 Alchemy)
          await tester.tap(find.byKey(const ValueKey('castle_tab_treasury')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('castle_wing_treasury')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('treasury_vault_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('treasury_orbs_horizontal_row')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('treasury_total_count')),
            findsOneWidget,
          );
          expect(find.text('60 / 250'), findsOneWidget);
          expect(find.text('FULL'), findsOneWidget);
          expect(find.byType(ElementalEnergySphere), findsAtLeastNWidgets(7));
          expect(
            find.byKey(const ValueKey('treasury_claim_ad_button')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('royal_alchemy_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('alchemy_source_selector')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('alchemy_target_selector')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('alchemy_transmute_button')),
            findsOneWidget,
          );

          // Verify Treasury + Royal Alchemy + Ok button fit within 390x844 viewport
          final alchemyBottom = tester
              .getBottomRight(find.byKey(const ValueKey('royal_alchemy_card')))
              .dy;
          final okFinder = find.text('Ok');
          expect(okFinder, findsOneWidget);
          final okBottom = tester.getBottomRight(okFinder).dy;
          expect(alchemyBottom, lessThanOrEqualTo(844));
          expect(okBottom, lessThanOrEqualTo(844));

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

          // Wing 6: Hall of Heroes
          await tester.tap(find.byKey(const ValueKey('castle_tab_hall_of_heroes')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('castle_wing_hall_of_heroes')),
            findsOneWidget,
          );
        }

        // Now test interactive Alchemy orb cycling + Exchange + Claiming inside UI
        await tester.tap(find.byKey(const ValueKey('castle_tab_treasury')));
        await tester.pumpAndSettle();

        // Tap target selector to verify orb cycling (default Water -> Wood), then back around
        await tester.tap(find.byKey(const ValueKey('alchemy_target_selector')));
        await tester.pumpAndSettle();
        // Transmute 3 Fire -> 1 Wood
        await tester.tap(find.byKey(const ValueKey('alchemy_transmute_button')));
        await tester.pumpAndSettle();
        expect(controller.fireOrbs, 6);
        expect(controller.woodOrbs, 1);

        // Claim Treasury via Rewarded Ad (no scrolling needed)
        await tester.tap(find.byKey(const ValueKey('treasury_claim_ad_button')));
        await tester.pumpAndSettle();
        expect(controller.fireOrbs, 56);
        expect(controller.woodOrbs, 11);
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

    testWidgets(
      'RoyalCastleIcon renders stone-gray and high-contrast gold-background variants cleanly and replaces yellow castle icons across WorldMapScreen and RoyalCastleDialog',
      (WidgetTester tester) async {
        // 1. Standalone RoyalCastleIcon variants & sizes
        for (final onGold in [false, true]) {
          for (final iconSize in [17.0, 24.0, 48.0]) {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: RoyalCastleIcon(
                      size: iconSize,
                      isOnGoldBackground: onGold,
                    ),
                  ),
                ),
              ),
            );
            final finder = find.byType(RoyalCastleIcon);
            expect(finder, findsOneWidget);
            expect(tester.getSize(finder), equals(Size(iconSize, iconSize)));
            expect(tester.takeException(), isNull);
          }
        }

        // 2. WorldMapScreen Royal Castle pin + RoyalCastleDialog header & Throne tab
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(loadJsonStrings: true);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        final worldMapPin = find.byKey(const ValueKey('landmark_royal_castle'));
        expect(worldMapPin, findsOneWidget);
        expect(
          find.descendant(
            of: worldMapPin,
            matching: find.byIcon(Icons.castle_rounded),
          ),
          findsNothing,
        );
        final mapCastleFinder = find.descendant(
          of: worldMapPin,
          matching: find.byType(RoyalCastleIcon),
        );
        expect(mapCastleFinder, findsOneWidget);
        expect(
          tester.widget<RoyalCastleIcon>(mapCastleFinder).isOnGoldBackground,
          isFalse,
        );

        // Open RoyalCastleDialog -> Throne tab active by default
        await tester.tap(worldMapPin);
        await tester.pumpAndSettle();

        final dialogFinder = find.byKey(const ValueKey('royal_castle_dialog'));
        expect(dialogFinder, findsOneWidget);
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.byIcon(Icons.castle_rounded),
          ),
          findsNothing,
        );

        // Both header badge and Throne tab render RoyalCastleIcon
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.byType(RoyalCastleIcon),
          ),
          findsNWidgets(2),
        );

        final throneTab = find.byKey(const ValueKey('castle_tab_throne'));
        final throneIconFinder = find.descendant(
          of: throneTab,
          matching: find.byType(RoyalCastleIcon),
        );
        expect(throneIconFinder, findsOneWidget);
        expect(
          tester.widget<RoyalCastleIcon>(throneIconFinder).isOnGoldBackground,
          isTrue,
        );

        // Switch to Library tab -> Throne tab switches to inactive stone-gray palette
        await tester.tap(find.byKey(const ValueKey('castle_tab_library')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<RoyalCastleIcon>(throneIconFinder).isOnGoldBackground,
          isFalse,
        );
      },
    );
  });
}
