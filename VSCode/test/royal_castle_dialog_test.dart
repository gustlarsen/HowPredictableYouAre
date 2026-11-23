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
import 'package:how_predictable/views/widgets/castle_wing_icons.dart';
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
  int saveGameCount = 0;

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
    saveGameCount++;
    return 'success';
  }

  @override
  Future<String?> loadGame({required String name}) async => savedPayload;
}

class _SpyAudioService extends AudioService {
  int alchemyTransmuteCount = 0;

  @override
  Future<void> playAlchemyTransmute() async {
    alchemyTransmuteCount++;
  }
}

Future<GameController> _createController({
  Map<String, Object> prefs = const {},
  _TestAdMobClient? adClient,
  _TestPlayGamesClient? playGamesClient,
  AudioService? audioService,
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
    audio: audioService ?? AudioService(),
    adService: adService,
    playGames: playGames,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Royal Castle Hub Unit & Logic Tests', () {
    test(
      'Winning rounds mirrors +1 orb to Royal Treasury up to shared 200 capacity (e.g. 200 Fire alone) and claiming transfers, resets to 0, & upgrades capacity +20',
      () async {
        final adClient = _TestAdMobClient(grantRewardOnShow: false);
        final controller = await _createController(
          adClient: adClient,
          prefs: {
            'enemy_stage': 4,
            'enemy_max_hp': 400,
            'pcHp': 400,
            'mana_upgrade_level': 150,
            'royal_decrees_completed_cycle_ids': [
              'decree_no_repeat_10',
              'decree_defeat_15',
              'decree_predict_70',
            ],
          },
        );
        addTearDown(controller.dispose);

        expect(controller.treasuryMaxCapacity, 200);
        expect(controller.treasuryVaultLevel, 1);

        // Win 205 Fire orbs (Paper beats Rock/Fire in elemental mode)
        for (int i = 0; i < 205; i++) {
          controller.crystalBallMove = HandMove.rock;
          controller.playTurn(HandMove.paper);
        }

        // Backpack receives all 205; Treasury caps shared total at 200 Fire orbs alone
        expect(controller.fireOrbs, 205);
        expect(controller.treasuryFireOrbs, 200);
        expect(controller.treasuryWaterOrbs, 0);
        expect(controller.totalTreasuryOrbs, 200);
        expect(controller.isTreasuryFull, isTrue);
        expect(controller.hasRoyalCastleNotification, isTrue);

        // Early ad dismissal does not claim, reset Treasury, or upgrade vault
        final failedClaim = await controller.watchAdToClaimTreasury();
        expect(failedClaim, isFalse);
        expect(controller.fireOrbs, 205);
        expect(controller.treasuryFireOrbs, 200);
        expect(controller.treasuryMaxCapacity, 200);
        expect(controller.treasuryVaultLevel, 1);

        // Complete rewarded ad transfers Treasury orbs, resets Treasury to 0,
        // increments vault level (1 -> 2), and increases capacity (+20 -> 220)
        adClient.grantRewardOnShow = true;
        final okClaim = await controller.watchAdToClaimTreasury();
        expect(okClaim, isTrue);
        expect(controller.fireOrbs, 405);
        expect(controller.turn0FireOrbs, 200);
        expect(controller.treasuryFireOrbs, 0);
        expect(controller.totalTreasuryOrbs, 0);
        expect(controller.treasuryVaultLevel, 2);
        expect(controller.treasuryMaxCapacity, 220);
        expect(controller.isTreasuryFull, isFalse);
        expect(controller.hasRoyalCastleNotification, isFalse);
      },
    );

    test(
      'Remove Ads users can claim Treasury anytime (>= 1 orb), restore Relics, and reclaim Spoils directly without watching an ad',
      () async {
        final adClient = _TestAdMobClient(rewardedAvailable: false);
        final controller = await _createController(
          adClient: adClient,
          prefs: {
            'unlockedAds': true,
            'removeAdsEnabled': true,
            'treasury_orbs_water': 1,
            'spoils_orbs_wood': 7,
            'relic_chamber_upgrades': ['reset', 'algorithm'],
          },
        );
        addTearDown(controller.dispose);

        expect(controller.isRemoveAdsActive, isTrue);
        expect(controller.isTreasuryFull, isFalse);
        expect(controller.claimTreasuryDirect(), isTrue);
        expect(controller.waterOrbs, 1);
        expect(controller.treasuryWaterOrbs, 0);
        expect(controller.treasuryVaultLevel, 2);
        expect(controller.treasuryMaxCapacity, 220);

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
      '3-to-1 Royal Alchemy deducts 3*batches source orbs, adds batches target orbs atomically with single cloud save and audio feedback, and rejects invalid exchanges',
      () async {
        final playGamesClient = _TestPlayGamesClient();
        final spyAudio = _SpyAudioService();
        final controller = await _createController(
          playGamesClient: playGamesClient,
          audioService: spyAudio,
          prefs: {
            'orbs_fire': 3010,
            'orbs_water': 1,
            'turn0_orbs_fire': 3004,
            'turn0_orbs_water': 1,
            'turn0_orbs_wood': 0,
            'turn0_orbs_earth': 0,
            'turn0_orbs_metal': 0,
          },
        );
        addTearDown(controller.dispose);

        final savesBefore = playGamesClient.saveGameCount;

        // Cannot transmute to same element
        expect(controller.transmuteOrbs(HandMove.rock, HandMove.rock), isFalse);
        // Cannot transmute with invalid batch count (< 1)
        expect(
          controller.transmuteOrbs(HandMove.rock, HandMove.paper, batches: 0),
          isFalse,
        );
        expect(
          controller.transmuteOrbs(HandMove.rock, HandMove.paper, batches: -3),
          isFalse,
        );
        // Cannot transmute when source balance < 3 * batches
        expect(controller.transmuteOrbs(HandMove.paper, HandMove.rock), isFalse);
        expect(
          controller.transmuteOrbs(HandMove.rock, HandMove.paper, batches: 1004),
          isFalse,
        );
        expect(playGamesClient.saveGameCount, savesBefore);
        expect(spyAudio.alchemyTransmuteCount, 0);

        // Single batch (default batches = 1): 3 Fire -> 1 Earth
        expect(controller.transmuteOrbs(HandMove.rock, HandMove.lizard), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(controller.fireOrbs, 3007);
        expect(controller.earthOrbs, 1);
        expect(controller.turn0FireOrbs, 3001);
        expect(controller.turn0EarthOrbs, 1);
        expect(controller.storage.fireOrbs, 3007);
        expect(controller.storage.earthOrbs, 1);
        expect(playGamesClient.saveGameCount, savesBefore + 1);
        expect(spyAudio.alchemyTransmuteCount, 1);

        // Atomic 1000x batch: 3000 Fire -> 1000 Water in a single save
        expect(
          controller.transmuteOrbs(HandMove.rock, HandMove.paper, batches: 1000),
          isTrue,
        );
        await Future<void>.delayed(Duration.zero);
        expect(controller.fireOrbs, 7);
        expect(controller.waterOrbs, 1001);
        expect(controller.turn0FireOrbs, 1);
        expect(controller.turn0WaterOrbs, 1001);
        expect(controller.storage.fireOrbs, 7);
        expect(controller.storage.waterOrbs, 1001);
        expect(playGamesClient.saveGameCount, savesBefore + 2);
        expect(spyAudio.alchemyTransmuteCount, 2);
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

        // Bestiary: Phase 1 battle unlocks Guardian Robot; Archmage & Baby Mage unlock on boss progression
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.guardianRobot),
          isTrue,
        );
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.archmageRobot),
          isFalse,
        );
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.babyRobot),
          isFalse,
        );

        // Complete 100 rounds at 100% score (15 wins + 85 draws so Phase 1 Guardian stays > 0 HP)
        // -> unlocks ending_perfect & predictAbove70 decree
        for (int i = 15; i < 100; i++) {
          controller.crystalBallMove = HandMove.rock;
          controller.playTurn(HandMove.rock);
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
          contains('guardian_robot'),
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
            'treasury_orbs_fire': 190,
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
          expect(find.text('Endings Discovered: 1 / 6'), findsOneWidget);
          expect(find.text('Guardian Robot'), findsOneWidget);
          expect(find.text('Story Memories'), findsOneWidget);

          // Wing 3: Treasury (Piggy Bank 3D Orbs Vault only; Alchemy moved to Sacred Temple)
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
            find.byKey(const ValueKey('treasury_vault_level_pill')),
            findsOneWidget,
          );
          expect(find.text('Lv. 1'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('treasury_orbs_horizontal_row')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('treasury_total_count')),
            findsOneWidget,
          );
          expect(find.text('200 / 200 • FULL'), findsOneWidget);
          expect(find.text('FULL'), findsNothing);
          expect(find.byType(ElementalEnergySphere), findsAtLeastNWidgets(5));
          expect(
            find.byKey(const ValueKey('treasury_claim_ad_button')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('treasury_upgrade_callout')),
            findsOneWidget,
          );
          expect(
            find.text('Claim to collect & upgrade vault (+20 capacity)'),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('royal_alchemy_card')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('alchemy_transmute_button')),
            findsNothing,
          );

          // Verify Treasury Vault + Ok button fit within 390x844 viewport
          final vaultBottom = tester
              .getBottomRight(find.byKey(const ValueKey('treasury_vault_card')))
              .dy;
          final okFinder = find.text('Ok');
          expect(okFinder, findsOneWidget);
          final okBottom = tester.getBottomRight(okFinder).dy;
          expect(vaultBottom, lessThanOrEqualTo(844));
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

        // Now test interactive Treasury Claiming inside UI
        await tester.tap(find.byKey(const ValueKey('castle_tab_treasury')));
        await tester.pumpAndSettle();

        // Claim Treasury via Rewarded Ad (no scrolling needed)
        await tester.tap(find.byKey(const ValueKey('treasury_claim_ad_button')));
        await tester.pumpAndSettle();
        expect(controller.fireOrbs, 199);
        expect(controller.woodOrbs, 10);
        expect(controller.totalTreasuryOrbs, 0);
        expect(controller.treasuryVaultLevel, 2);
        expect(controller.treasuryMaxCapacity, 220);
        expect(find.text('Lv. 2'), findsOneWidget);
        expect(find.text('0 / 220'), findsOneWidget);
        expect(
          find.text('Treasury claimed! Vault capacity increased to 220 (+20)!'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('castle_tab_treasury_dot')), findsNothing);
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
            'treasury_orbs_fire': 200,
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

        // Modal header badge renders RoyalCastleIcon while Throne tab renders ThroneCrownIcon
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.byType(RoyalCastleIcon),
          ),
          findsOneWidget,
        );

        final throneTab = find.byKey(const ValueKey('castle_tab_throne'));
        final throneIconFinder = find.descendant(
          of: throneTab,
          matching: find.byType(ThroneCrownIcon),
        );
        expect(throneIconFinder, findsOneWidget);
        expect(
          tester.widget<ThroneCrownIcon>(throneIconFinder).isOnGoldBackground,
          isTrue,
        );

        // Switch to Library tab -> Throne tab switches to inactive palette
        await tester.tap(find.byKey(const ValueKey('castle_tab_library')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<ThroneCrownIcon>(throneIconFinder).isOnGoldBackground,
          isFalse,
        );
      },
    );

    testWidgets(
      'Royal Castle Treasury focuses strictly on Piggy Bank Orb Vault without Alchemy in Dark & Light modes on 360dp',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 760);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          loadJsonStrings: true,
          prefs: {
            'treasury_orbs_fire': 25,
            'treasury_orbs_water': 15,
            'treasury_orbs_wood': 10,
            'treasury_orbs_earth': 5,
            'treasury_orbs_metal': 5,
          },
        );
        addTearDown(controller.dispose);

        for (final isDark in [true, false]) {
          controller.darkMode = isDark;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: RoyalCastleDialog(
                  controller: controller,
                  initialWing: CastleWing.treasury,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(
            find.byKey(const ValueKey('treasury_vault_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('royal_alchemy_card')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('alchemy_transmute_button')),
            findsNothing,
          );

          final vaultBottom = tester
              .getBottomRight(find.byKey(const ValueKey('treasury_vault_card')))
              .dy;
          final okBottom = tester.getBottomRight(find.text('Ok')).dy;
          expect(vaultBottom, lessThanOrEqualTo(760));
          expect(okBottom, lessThanOrEqualTo(760));
        }
      },
    );

    testWidgets(
      'All 6 Castle tabs and internal section headers render bespoke CustomPainter RPG icons cleanly in both Dark Mode and Light Mode',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 1. Standalone painter smoke checks for all 9 internal wing accent icons
        final accentIcons = <Widget>[
          const RoyalScrollIcon(size: 22),
          const GoldenHourglassIcon(size: 24),
          const LaurelWreathIcon(size: 22),
          const AutomatonHeadIcon(size: 24),
          const AlchemyFlaskIcon(size: 22),
          const RunicShieldIcon(size: 24),
          const WarBannerIcon(size: 24),
          const RubyHeartIcon(size: 22),
          const ManaCrystalIcon(size: 22),
        ];
        for (final icon in accentIcons) {
          await tester.pumpWidget(
            MaterialApp(home: Scaffold(body: Center(child: icon))),
          );
          expect(tester.takeException(), isNull);
        }

        // 2. Full RoyalCastleDialog verification across Dark Mode & Light Mode
        final controller = await _createController(
          loadJsonStrings: true,
          prefs: {
            'hall_of_heroes_hp_bonus': 12,
            'hall_of_heroes_mana_bonus': 8,
            'treasury_orbs_fire': 10,
            'spoils_orbs_fire': 5,
            'relic_chamber_items': ['reset'],
          },
        );
        addTearDown(controller.dispose);

        for (final isDark in [true, false]) {
          controller.darkMode = isDark;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: RoyalCastleDialog(
                  key: ValueKey('castle_dialog_theme_$isDark'),
                  controller: controller,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final throneTab = find.byKey(const ValueKey('castle_tab_throne'));
          final libraryTab = find.byKey(const ValueKey('castle_tab_library'));
          final treasuryTab = find.byKey(const ValueKey('castle_tab_treasury'));
          final relicsTab = find.byKey(const ValueKey('castle_tab_relics'));
          final spoilsTab = find.byKey(const ValueKey('castle_tab_spoils'));
          final heroesTab =
              find.byKey(const ValueKey('castle_tab_hall_of_heroes'));

          // All 6 bespoke tab icons are mounted simultaneously at 20x20
          final crownFinder = find.descendant(
            of: throneTab,
            matching: find.byType(ThroneCrownIcon),
          );
          final tomeFinder = find.descendant(
            of: libraryTab,
            matching: find.byType(LibraryTomeIcon),
          );
          final chestFinder = find.descendant(
            of: treasuryTab,
            matching: find.byType(TreasuryChestIcon),
          );
          final swordFinder = find.descendant(
            of: relicsTab,
            matching: find.byType(RelicsSwordIcon),
          );
          final pouchFinder = find.descendant(
            of: spoilsTab,
            matching: find.byType(SpoilsPouchIcon),
          );
          final helmFinder = find.descendant(
            of: heroesTab,
            matching: find.byType(HeroesHelmIcon),
          );

          for (final finder in [
            crownFinder,
            tomeFinder,
            chestFinder,
            swordFinder,
            pouchFinder,
            helmFinder,
          ]) {
            expect(finder, findsOneWidget);
            expect(tester.getSize(finder), equals(const Size(20.0, 20.0)));
          }

          // Wing 1 (Throne) active by default -> high contrast on gold; others inactive
          expect(tester.widget<ThroneCrownIcon>(crownFinder).isOnGoldBackground, isTrue);
          expect(tester.widget<LibraryTomeIcon>(tomeFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<TreasuryChestIcon>(chestFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<RelicsSwordIcon>(swordFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<SpoilsPouchIcon>(pouchFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<HeroesHelmIcon>(helmFinder).isOnGoldBackground, isFalse);
          expect(find.byType(GoldenHourglassIcon), findsOneWidget);
          expect(find.byType(RoyalScrollIcon), findsOneWidget);

          // Wing 2 (Library)
          await tester.tap(libraryTab);
          await tester.pumpAndSettle();
          expect(tester.widget<ThroneCrownIcon>(crownFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<LibraryTomeIcon>(tomeFinder).isOnGoldBackground, isTrue);
          expect(find.byType(LaurelWreathIcon), findsOneWidget);
          expect(find.byType(AutomatonHeadIcon), findsOneWidget);

          // Wing 3 (Treasury)
          await tester.tap(treasuryTab);
          await tester.pumpAndSettle();
          expect(tester.widget<LibraryTomeIcon>(tomeFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<TreasuryChestIcon>(chestFinder).isOnGoldBackground, isTrue);
          expect(find.byType(TreasuryChestIcon), findsOneWidget);
          expect(
            find.byKey(const ValueKey('treasury_vault_level_pill')),
            findsOneWidget,
          );

          // Wing 4 (Relics)
          await tester.tap(relicsTab);
          await tester.pumpAndSettle();
          expect(tester.widget<TreasuryChestIcon>(chestFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<RelicsSwordIcon>(swordFinder).isOnGoldBackground, isTrue);
          expect(find.byType(RunicShieldIcon), findsOneWidget);

          // Wing 5 (Spoils)
          await tester.tap(spoilsTab);
          await tester.pumpAndSettle();
          expect(tester.widget<RelicsSwordIcon>(swordFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<SpoilsPouchIcon>(pouchFinder).isOnGoldBackground, isTrue);
          expect(find.byType(WarBannerIcon), findsOneWidget);

          // Wing 6 (Hall of Heroes)
          await tester.tap(heroesTab);
          await tester.pumpAndSettle();
          expect(tester.widget<SpoilsPouchIcon>(pouchFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<HeroesHelmIcon>(helmFinder).isOnGoldBackground, isTrue);
          expect(find.byType(HeroesHelmIcon), findsNWidgets(2));
          expect(find.byType(RubyHeartIcon), findsOneWidget);
          expect(find.byType(ManaCrystalIcon), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  });

  group('Royal Treasury Progressive Shared Capacity & Persistence', () {
    test(
      'Unlocking Earth & Metal grants +100 capacity once (200 -> 300), toggling ON/OFF grants nothing extra, and existing saves migrate on load',
      () async {
        // 1. Fresh account starts at 200 capacity, Lv. 1
        final controller = await _createController(
          prefs: {
            'orbs_earth': 100,
            'orbs_metal': 100,
          },
        );
        addTearDown(controller.dispose);

        expect(controller.treasuryMaxCapacity, 200);
        expect(controller.treasuryVaultLevel, 1);
        expect(controller.treasuryEarthMetalBonusGranted, isFalse);

        // Unlock Earth & Metal -> +100 capacity once (200 -> 300)
        expect(controller.unlockNewHands(), isTrue);
        expect(controller.unlockedNewHands, isTrue);
        expect(controller.treasuryEarthMetalBonusGranted, isTrue);
        expect(controller.treasuryMaxCapacity, 300);
        expect(controller.storage.treasuryMaxCapacity, 300);
        expect(controller.storage.treasuryEarthMetalBonusGranted, isTrue);

        // Toggling Earth & Metal ON/OFF never grants extra capacity
        controller.toggleShowNewHands(true);
        expect(controller.treasuryMaxCapacity, 300);
        controller.toggleShowNewHands(false);
        expect(controller.treasuryMaxCapacity, 300);
        controller.toggleShowNewHands(true);
        expect(controller.treasuryMaxCapacity, 300);

        // Resetting run and re-unlocking Earth & Metal never grants +100 again
        await controller.resetAllProgress();
        expect(controller.unlockedNewHands, isFalse);
        expect(controller.treasuryEarthMetalBonusGranted, isTrue);
        expect(controller.treasuryMaxCapacity, 300);

        controller.addAllOrbs(100);
        expect(controller.unlockNewHands(), isTrue);
        expect(controller.treasuryMaxCapacity, 300);

        // 2. Existing save migration: unlockedNewHands=true & bonus flag=false -> +100 on load
        final migratedController = await _createController(
          prefs: {
            'unlockedNewHands': true,
          },
        );
        addTearDown(migratedController.dispose);
        expect(migratedController.treasuryEarthMetalBonusGranted, isTrue);
        expect(migratedController.treasuryMaxCapacity, 300);
        expect(migratedController.storage.treasuryEarthMetalBonusGranted, isTrue);
        expect(migratedController.storage.treasuryMaxCapacity, 300);

        // 3. IAP unlock path also grants +100 once
        final iapController = await _createController();
        addTearDown(iapController.dispose);
        expect(iapController.treasuryMaxCapacity, 200);
        expect(
          iapController.unlockByProductId(BillingService.productNewHands),
          isTrue,
        );
        expect(iapController.treasuryMaxCapacity, 300);
        expect(iapController.treasuryEarthMetalBonusGranted, isTrue);
        // Calling IAP restore again does not add another +100
        expect(
          iapController.unlockByProductId(BillingService.productNewHands),
          isTrue,
        );
        expect(iapController.treasuryMaxCapacity, 300);
      },
    );

    test(
      'Treasury capacity, vault level, and Earth/Metal bonus flag survive 0 HP defeat, Week 40 deadline, Reset All Progress, and sync/merge via CloudSaveData',
      () async {
        final playGamesClient = _TestPlayGamesClient();
        final controller = await _createController(
          playGamesClient: playGamesClient,
          prefs: {
            'unlockedAds': true,
            'removeAdsEnabled': true,
            'treasury_orbs_fire': 5,
            'orbs_earth': 50,
            'orbs_metal': 50,
          },
        );
        addTearDown(controller.dispose);

        // Claim with >= 1 orb -> Lv. 1 -> Lv. 2, capacity 200 -> 220
        expect(controller.claimTreasuryDirect(), isTrue);
        expect(controller.treasuryVaultLevel, 2);
        expect(controller.treasuryMaxCapacity, 220);

        // Unlock Earth & Metal -> capacity 220 -> 320
        expect(controller.unlockNewHands(), isTrue);
        expect(controller.treasuryMaxCapacity, 320);

        // 0 HP defeat preserves capacity, vault level, and bonus flag
        await controller.applyPermadeathReset(
          cause: PermadeathCause.battleDefeat,
        );
        expect(controller.treasuryVaultLevel, 2);
        expect(controller.treasuryMaxCapacity, 320);
        expect(controller.treasuryEarthMetalBonusGranted, isTrue);

        // Week 40 deadline preserves capacity, vault level, and bonus flag
        await controller.applyPermadeathReset(
          cause: PermadeathCause.deadlineExceeded,
        );
        expect(controller.treasuryVaultLevel, 2);
        expect(controller.treasuryMaxCapacity, 320);
        expect(controller.treasuryEarthMetalBonusGranted, isTrue);

        // Reset All Progress preserves capacity, vault level, and bonus flag
        await controller.resetAllProgress();
        expect(controller.treasuryVaultLevel, 2);
        expect(controller.treasuryMaxCapacity, 320);
        expect(controller.treasuryEarthMetalBonusGranted, isTrue);

        // CloudSaveData round-trip & merge (max(local, cloud) and local || cloud)
        await Future<void>.delayed(Duration.zero);
        final cloud = CloudSaveData.tryParse(playGamesClient.savedPayload)!;
        expect(cloud.treasuryVaultLevel, 2);
        expect(cloud.treasuryMaxCapacity, 320);
        expect(cloud.treasuryEarthMetalBonusGranted, isTrue);

        const olderCloud = CloudSaveData(
          treasuryMaxCapacity: 260,
          treasuryVaultLevel: 4,
          treasuryEarthMetalBonusGranted: false,
        );
        const richerLocal = CloudSaveData(
          treasuryMaxCapacity: 320,
          treasuryVaultLevel: 2,
          treasuryEarthMetalBonusGranted: true,
        );
        final merged = olderCloud.mergeOverLocal(richerLocal);
        expect(merged.treasuryMaxCapacity, 320);
        expect(merged.treasuryVaultLevel, 4);
        expect(merged.treasuryEarthMetalBonusGranted, isTrue);
      },
    );

    testWidgets(
      'Treasury tab renders Lv. X pill, partial/full shared bar, 4- & 5-digit FittedBox counters, +20 sub-label, and Dark/Light theme without overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 760);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          loadJsonStrings: true,
          prefs: {
            'treasury_orbs_fire': 1240,
            'treasury_orbs_water': 12400,
            'treasury_max_capacity': 20000,
            'treasury_vault_level': 7,
            'unlockedAds': true,
            'removeAdsEnabled': true,
          },
        );
        addTearDown(controller.dispose);

        for (final isDark in [true, false]) {
          controller.darkMode = isDark;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: RoyalCastleDialog(
                  controller: controller,
                  initialWing: CastleWing.treasury,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(find.text('Lv. 7'), findsOneWidget);
          expect(find.text('13640 / 20000'), findsOneWidget);
          expect(find.text('1240'), findsOneWidget);
          expect(find.text('12400'), findsOneWidget);
          expect(
            find.text('Claim to collect & upgrade vault (+20 capacity)'),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('treasury_claim_direct_button')),
            findsOneWidget,
          );
          // Not full yet -> no Treasury tab dot
          expect(
            find.byKey(const Key('castle_tab_treasury_dot')),
            findsNothing,
          );

          // Verify 4- and 5-digit orb counters are wrapped in FittedBox(scaleDown)
          final fireColumn = find.byKey(const ValueKey('treasury_element_fire'));
          final fireFitted = find.descendant(
            of: fireColumn,
            matching: find.byType(FittedBox),
          );
          expect(fireFitted, findsOneWidget);
          expect(
            tester.widget<FittedBox>(fireFitted).fit,
            BoxFit.scaleDown,
          );
        }
      },
    );
  });
}
