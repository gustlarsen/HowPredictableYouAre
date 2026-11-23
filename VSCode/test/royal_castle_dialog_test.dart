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

        // Modal header badge renders RoyalCastleIcon at 32x32 while Throne tab renders ThroneCrownIcon
        final headerCastleFinder = find.descendant(
          of: dialogFinder,
          matching: find.byType(RoyalCastleIcon),
        );
        expect(headerCastleFinder, findsOneWidget);
        expect(
          tester.getSize(headerCastleFinder),
          equals(const Size(32.0, 32.0)),
        );

        final throneTab = find.byKey(const ValueKey('castle_tab_throne'));
        final throneIconFinder = find.descendant(
          of: throneTab,
          matching: find.byType(ThroneCrownIcon),
        );
        expect(throneIconFinder, findsOneWidget);
        expect(
          tester.widget<ThroneCrownIcon>(throneIconFinder).isOnGoldBackground,
          isFalse,
        );

        // Switch to Library tab -> Throne tab icon stays colorful (isOnGoldBackground: false)
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

          // Header RoyalCastleIcon badge renders at 32x32
          expect(
            tester.getSize(find.byType(RoyalCastleIcon)),
            equals(const Size(32.0, 32.0)),
          );

          // Helper to verify active/inactive glowing gold border tab pill styling
          void expectCastleTabStyling(
            Finder tabFinder, {
            required bool active,
          }) {
            final pillContainer = tester.widget<Container>(
              find.descendant(
                of: tabFinder,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Container &&
                      w.decoration is BoxDecoration &&
                      (w.decoration! as BoxDecoration).borderRadius ==
                          BorderRadius.circular(12),
                ),
              ),
            );
            final decor = pillContainer.decoration! as BoxDecoration;
            final border = decor.border! as Border;
            final baseSurface = isDark
                ? const Color(0xFF1C202B)
                : const Color(0xFFF5EFE2);
            if (active) {
              final expectedTint =
                  (isDark ? const Color(0xFFF5C22B) : const Color(0xFFD99B00))
                      .withValues(alpha: 0.14);
              expect(
                decor.color,
                equals(Color.alphaBlend(expectedTint, baseSurface)),
              );
              expect(decor.color, isNot(equals(const Color(0xFFF5C22B))));
              expect(border.top.width, equals(2.2));
              expect(
                border.top.color,
                equals(
                  isDark ? const Color(0xFFFFD54F) : const Color(0xFFC88A00),
                ),
              );
              expect(decor.boxShadow, isNotNull);
              expect(decor.boxShadow!.length, equals(1));
              expect(decor.boxShadow!.first.blurRadius, equals(8.0));
              expect(decor.boxShadow!.first.spreadRadius, equals(0.5));
            } else {
              expect(decor.color, equals(baseSurface));
              expect(border.top.width, equals(1.0));
              expect(decor.boxShadow, isNull);
            }
          }

          // Wing 1 (Throne) active by default -> all icons stay 100% colorful (isOnGoldBackground: false)
          expect(tester.widget<ThroneCrownIcon>(crownFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<LibraryTomeIcon>(tomeFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<TreasuryChestIcon>(chestFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<RelicsSwordIcon>(swordFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<SpoilsPouchIcon>(pouchFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<HeroesHelmIcon>(helmFinder).isOnGoldBackground, isFalse);
          expectCastleTabStyling(throneTab, active: true);
          expectCastleTabStyling(libraryTab, active: false);
          expectCastleTabStyling(treasuryTab, active: false);
          expectCastleTabStyling(relicsTab, active: false);
          expectCastleTabStyling(spoilsTab, active: false);
          expectCastleTabStyling(heroesTab, active: false);
          expect(find.byType(GoldenHourglassIcon), findsOneWidget);
          expect(find.byType(RoyalScrollIcon), findsOneWidget);

          // Verify Week 40 — The Final Deadline milestone renders full description without text truncation
          final week40Finder = find.byKey(
            const ValueKey('throne_milestone_week_40'),
          );
          final week40Title = tester.widget<Text>(
            find.descendant(
              of: week40Finder,
              matching: find.text('Week 40 — The Final Deadline'),
            ),
          );
          final week40Desc = tester.widget<Text>(
            find.descendant(
              of: week40Finder,
              matching: find.text(
                "The Kingdom's 40-week defense horizon—stand ready for the ultimate battle of minds.",
              ),
            ),
          );
          expect(week40Title.maxLines, isNull);
          expect(week40Desc.maxLines, isNull);
          expect(week40Desc.overflow, isNull);
          await tester.ensureVisible(week40Finder);
          await tester.pumpAndSettle();
          final scrollViewportBottom = tester
              .getBottomLeft(
                find.byKey(const ValueKey('castle_wing_scroll_throneRoom')),
              )
              .dy;
          expect(
            tester.getBottomLeft(week40Finder).dy,
            lessThanOrEqualTo(scrollViewportBottom),
          );

          // Wing 2 (Library)
          await tester.tap(libraryTab);
          await tester.pumpAndSettle();
          expect(tester.widget<ThroneCrownIcon>(crownFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<LibraryTomeIcon>(tomeFinder).isOnGoldBackground, isFalse);
          expectCastleTabStyling(throneTab, active: false);
          expectCastleTabStyling(libraryTab, active: true);
          expect(find.byType(LaurelWreathIcon), findsOneWidget);
          expect(find.byType(AutomatonHeadIcon), findsOneWidget);

          // Wing 3 (Treasury)
          await tester.tap(treasuryTab);
          await tester.pumpAndSettle();
          expect(tester.widget<LibraryTomeIcon>(tomeFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<TreasuryChestIcon>(chestFinder).isOnGoldBackground, isFalse);
          expectCastleTabStyling(libraryTab, active: false);
          expectCastleTabStyling(treasuryTab, active: true);
          expect(find.byType(TreasuryChestIcon), findsOneWidget);
          expect(
            find.byKey(const ValueKey('treasury_vault_level_pill')),
            findsOneWidget,
          );

          // Wing 4 (Relics)
          await tester.tap(relicsTab);
          await tester.pumpAndSettle();
          expect(tester.widget<TreasuryChestIcon>(chestFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<RelicsSwordIcon>(swordFinder).isOnGoldBackground, isFalse);
          expectCastleTabStyling(treasuryTab, active: false);
          expectCastleTabStyling(relicsTab, active: true);
          expect(find.byType(RunicShieldIcon), findsOneWidget);

          // Wing 5 (Spoils)
          await tester.tap(spoilsTab);
          await tester.pumpAndSettle();
          expect(tester.widget<RelicsSwordIcon>(swordFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<SpoilsPouchIcon>(pouchFinder).isOnGoldBackground, isFalse);
          expectCastleTabStyling(relicsTab, active: false);
          expectCastleTabStyling(spoilsTab, active: true);
          expect(find.byType(WarBannerIcon), findsOneWidget);

          // Wing 6 (Hall of Heroes)
          await tester.tap(heroesTab);
          await tester.pumpAndSettle();
          expect(tester.widget<SpoilsPouchIcon>(pouchFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<HeroesHelmIcon>(helmFinder).isOnGoldBackground, isFalse);
          expectCastleTabStyling(spoilsTab, active: false);
          expectCastleTabStyling(heroesTab, active: true);
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

  group('Relic Chamber Pinned Restore & Exact Active/Inactive State Preservation', () {
    test(
      'Archiving via permadeath defeat and Forfeit Run preserves exact per-relic enabled states and Overcharged Staff speed across StorageService reload and CloudSaveData',
      () async {
        final playGamesClient = _TestPlayGamesClient();
        final controller = await _createController(
          playGamesClient: playGamesClient,
          loadJsonStrings: true,
          prefs: {
            'current_week': 12,
            'unlockedPredictability': true,
            'showPredictability': true,
            'unlockedReset': true,
            'showReset': false,
            'unlockedRandom': true,
            'showRandom': true,
            'unlockedAlgorithm': true,
            'showAlgorithm': false,
            'unlockedYourPrediction': true,
            'showYourPrediction': false,
            'unlockedNextMove': true,
            'showNextMove': true,
            'unlockedSuggestion': true,
            'showSuggestion': false,
            'unlockedNewHands': true,
            'showNewHands': true,
            'unlockedNewSkin': true,
            'showNewSkin': false,
            'unlockedCrystalBall': true,
            'showCrystalBall': true,
            'unlockedCrystalBallPlus': true,
            'showCrystalBallPlus': false,
            'unlockedMarkovRecalibrator': true,
            'showMarkovRecalibrator': true,
            'giftBoxUnlocked': true,
            'giftBoxEnabled': false,
            'overcharged_staff_level': 6,
            'overcharged_staff_enabled': false,
            'overcharged_staff_selected_speed': 10,
          },
        );
        addTearDown(controller.dispose);

        // 1. Trigger 0 HP defeat -> archives all relics + exact active/inactive states + staff 10x speed
        await controller.applyPermadeathReset(
          cause: PermadeathCause.battleDefeat,
        );
        expect(controller.unlockedPredictability, isFalse);
        expect(controller.showPredictability, isFalse);
        expect(controller.unlockedNewSkin, isFalse);
        expect(controller.showNewSkin, isFalse);
        expect(controller.overchargedStaffLevel, 0);
        expect(controller.overchargedStaffEnabled, isFalse);

        // Verify archived states & Overcharged Staff speed
        expect(controller.isRelicStoredEnabled(ShopUpgradeArtifact.predictability), isTrue);
        expect(controller.isRelicStoredEnabled(ShopUpgradeArtifact.reset), isFalse);
        expect(controller.isRelicStoredEnabled(ShopUpgradeArtifact.random), isTrue);
        expect(controller.isRelicStoredEnabled(ShopUpgradeArtifact.algorithm), isFalse);
        expect(controller.isRelicStoredEnabled(ShopUpgradeArtifact.yourPrediction), isFalse);
        expect(controller.isRelicStoredEnabled(ShopUpgradeArtifact.nextMove), isTrue);
        expect(controller.isRelicStoredEnabled(ShopUpgradeArtifact.suggestion), isFalse);
        expect(controller.isRelicStoredEnabled(ShopUpgradeArtifact.newHands), isTrue);
        expect(controller.isRelicStoredEnabled(ShopUpgradeArtifact.newSkin), isFalse);
        expect(controller.isRelicStoredEnabled(ShopUpgradeArtifact.crystalBall), isTrue);
        expect(controller.isRelicStoredEnabled(ShopUpgradeArtifact.crystalBallPlus), isFalse);
        expect(controller.isRelicStoredEnabled(ShopUpgradeArtifact.markovRecalibrator), isTrue);
        expect(controller.isRelicStoredEnabled(ShopUpgradeArtifact.giftBox), isFalse);
        expect(controller.isRelicStoredEnabled(ShopUpgradeArtifact.overchargedStaff), isFalse);
        expect(controller.storedRelicOverchargedStaffLevel, 6);
        expect(controller.storedRelicOverchargedStaffSpeed, 10);

        // 2. Survive StorageService reload from SharedPreferences without wiping prefs
        final reloadedStorage = StorageService();
        await reloadedStorage.init();
        final reloadedAdService = AdService(client: _TestAdMobClient());
        await reloadedAdService.initialize(adsRemoved: false);
        final reloadedController = GameController(
          storage: reloadedStorage,
          localization: LocalizationService(),
          audio: AudioService(),
          adService: reloadedAdService,
        );
        addTearDown(reloadedController.dispose);

        expect(reloadedController.isRelicStoredEnabled(ShopUpgradeArtifact.reset), isFalse);
        expect(reloadedController.isRelicStoredEnabled(ShopUpgradeArtifact.newSkin), isFalse);
        expect(reloadedController.isRelicStoredEnabled(ShopUpgradeArtifact.predictability), isTrue);
        expect(reloadedController.isRelicStoredEnabled(ShopUpgradeArtifact.overchargedStaff), isFalse);
        expect(reloadedController.storedRelicOverchargedStaffSpeed, 10);

        // 3. Survive PlayGamesService CloudSaveData JSON round-trip
        await Future<void>.delayed(Duration.zero);
        final cloud = CloudSaveData.tryParse(playGamesClient.savedPayload);
        expect(cloud, isNotNull);
        expect(cloud!.relicChamberUpgradeStates['reset'], isFalse);
        expect(cloud.relicChamberUpgradeStates['new_skin'], isFalse);
        expect(cloud.relicChamberUpgradeStates['predictability'], isTrue);
        expect(cloud.relicChamberUpgradeStates['overcharged_staff'], isFalse);
        expect(cloud.relicChamberOverchargedStaffSpeed, 10);

        // 4. Restore via Rewarded Ad -> restores exact prior active/inactive states & 10x speed
        final restored = await reloadedController.watchAdToRestoreRelics();
        expect(restored, isTrue);
        expect(reloadedController.unlockedPredictability, isTrue);
        expect(reloadedController.showPredictability, isTrue);
        expect(reloadedController.unlockedReset, isTrue);
        expect(reloadedController.showReset, isFalse);
        expect(reloadedController.unlockedRandom, isTrue);
        expect(reloadedController.showRandom, isTrue);
        expect(reloadedController.unlockedAlgorithm, isTrue);
        expect(reloadedController.showAlgorithm, isFalse);
        expect(reloadedController.unlockedYourPrediction, isTrue);
        expect(reloadedController.showYourPrediction, isFalse);
        expect(reloadedController.unlockedNextMove, isTrue);
        expect(reloadedController.showNextMove, isTrue);
        expect(reloadedController.unlockedSuggestion, isTrue);
        expect(reloadedController.showSuggestion, isFalse);
        expect(reloadedController.unlockedNewHands, isTrue);
        expect(reloadedController.showNewHands, isTrue);
        expect(reloadedController.unlockedNewSkin, isTrue);
        expect(reloadedController.showNewSkin, isFalse);
        expect(reloadedController.unlockedCrystalBall, isTrue);
        expect(reloadedController.showCrystalBall, isTrue);
        expect(reloadedController.unlockedCrystalBallPlus, isTrue);
        expect(reloadedController.showCrystalBallPlus, isFalse);
        expect(reloadedController.unlockedMarkovRecalibrator, isTrue);
        expect(reloadedController.showMarkovRecalibrator, isTrue);
        expect(reloadedController.giftBoxUnlocked, isTrue);
        expect(reloadedController.giftBoxEnabled, isFalse);
        expect(reloadedController.overchargedStaffLevel, 6);
        expect(reloadedController.overchargedStaffEnabled, isFalse);
        expect(reloadedController.overchargedStaffSelectedSpeed, 10);
        expect(reloadedController.relicChamberStoredUpgrades, isEmpty);
        expect(reloadedController.relicChamberStoredUpgradeStates, isEmpty);
        expect(reloadedController.relicChamberStoredOverchargedStaffSpeed, isNull);
        expect(reloadedController.hasAvailableRelicChamberUpgrades, isFalse);

        // 5. Also verify Forfeit Run (resetAllProgress) captures & restores flipped states (e.g., New Skin ON, Random OFF, Staff ON at 5x)
        reloadedController.toggleShowNewSkin(true);
        reloadedController.toggleShowRandom(false);
        reloadedController.toggleOverchargedStaff(true);
        reloadedController.selectOverchargedStaffSpeed(5);
        await reloadedController.resetAllProgress();

        expect(reloadedController.isRelicStoredEnabled(ShopUpgradeArtifact.newSkin), isTrue);
        expect(reloadedController.isRelicStoredEnabled(ShopUpgradeArtifact.random), isFalse);
        expect(reloadedController.isRelicStoredEnabled(ShopUpgradeArtifact.overchargedStaff), isTrue);
        expect(reloadedController.storedRelicOverchargedStaffSpeed, 5);

        expect(await reloadedController.watchAdToRestoreRelics(), isTrue);
        expect(reloadedController.showNewSkin, isTrue);
        expect(reloadedController.showRandom, isFalse);
        expect(reloadedController.overchargedStaffEnabled, isTrue);
        expect(reloadedController.overchargedStaffSelectedSpeed, 5);

        // 6. Backward compatibility: legacy CloudSaveData JSON without relicChamberUpgradeStates defaults to true
        final legacyCloud = CloudSaveData.tryParse(
          '{"relicChamberUpgrades": ["reset", "new_skin", "overcharged_staff:4"]}',
        )!;
        expect(legacyCloud.relicChamberUpgradeStates, isEmpty);
        SharedPreferences.setMockInitialValues({});
        final legacyStorage = StorageService();
        await legacyStorage.init();
        await legacyCloud.applyToStorage(legacyStorage);
        final legacyAdService = AdService(client: _TestAdMobClient());
        await legacyAdService.initialize(adsRemoved: false);
        final legacyController = GameController(
          storage: legacyStorage,
          localization: LocalizationService(),
          audio: AudioService(),
          adService: legacyAdService,
        );
        addTearDown(legacyController.dispose);
        expect(legacyController.isRelicStoredEnabled(ShopUpgradeArtifact.reset), isTrue);
        expect(legacyController.isRelicStoredEnabled(ShopUpgradeArtifact.newSkin), isTrue);
        expect(await legacyController.watchAdToRestoreRelics(), isTrue);
        expect(legacyController.showReset, isTrue);
        expect(legacyController.showNewSkin, isTrue);
        expect(legacyController.overchargedStaffLevel, 4);
        expect(legacyController.overchargedStaffEnabled, isTrue);
        expect(legacyController.overchargedStaffSelectedSpeed, 10);
      },
    );

    test(
      'Relic Chamber UI strings are localized in en, pt, es, and de',
      () async {
        final loc = LocalizationService();
        await loc.load();
        const keys = [
          'castle_relics_status_active',
          'castle_relics_status_inactive',
          'castle_relics_ready_summary_one',
          'castle_relics_ready_summary_many',
          'castle_relics_restored_msg',
          'castle_relics_restore_direct',
        ];
        for (final lang in LocalizationService.supportedLanguages) {
          loc.setLanguage(lang);
          for (final key in keys) {
            final value = loc.t(key);
            expect(value, isNotEmpty, reason: 'Missing $lang $key');
            expect(value, isNot(key), reason: 'Fallback key returned for $lang $key');
          }
        }
      },
    );

    testWidgets(
      'RoyalCastleDialog Relics tab pins golden Restore Relics button at top above scrollable list, shows Active/Inactive badges without per-row ad icons, and clears notification dot on restore',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final prefsWithMixedRelics = <String, Object>{
          'unlockedPredictability': true,
          'showPredictability': true,
          'unlockedReset': true,
          'showReset': false,
          'unlockedRandom': true,
          'showRandom': true,
          'unlockedAlgorithm': true,
          'showAlgorithm': false,
          'unlockedYourPrediction': true,
          'showYourPrediction': false,
          'unlockedNextMove': true,
          'showNextMove': true,
          'unlockedSuggestion': true,
          'showSuggestion': false,
          'unlockedNewHands': true,
          'showNewHands': true,
          'unlockedNewSkin': true,
          'showNewSkin': false,
          'overcharged_staff_level': 6,
          'overcharged_staff_enabled': false,
          'overcharged_staff_selected_speed': 10,
        };

        for (final isRemoveAds in [false, true]) {
          for (final isDark in [true, false]) {
            final controller = await _createController(
              loadJsonStrings: true,
              prefs: {
                ...prefsWithMixedRelics,
                'darkMode': isDark,
                if (isRemoveAds) ...{
                  'unlockedAds': true,
                  'removeAdsEnabled': true,
                },
              },
            );
            addTearDown(controller.dispose);

            await controller.applyPermadeathReset(
              cause: PermadeathCause.battleDefeat,
            );

            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData.light(useMaterial3: true),
                darkTheme: ThemeData.dark(useMaterial3: true),
                themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                home: Scaffold(
                  body: RoyalCastleDialog(
                    controller: controller,
                    initialWing: CastleWing.relicChamber,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            final buttonKey = isRemoveAds
                ? const ValueKey('relic_chamber_restore_direct_button')
                : const ValueKey('relic_chamber_restore_ad_button');
            final buttonFinder = find.byKey(buttonKey);
            final scrollFinder = find.byKey(
              const ValueKey('castle_wing_scroll_relicChamber'),
            );
            final summaryFinder = find.byKey(
              const ValueKey('relic_chamber_header_summary'),
            );

            expect(buttonFinder, findsOneWidget);
            expect(scrollFinder, findsOneWidget);
            expect(summaryFinder, findsOneWidget);
            expect(find.text('Restore Relics'), findsOneWidget);
            expect(
              find.text('10 Relics ready • Previous active states preserved'),
              findsOneWidget,
            );

            // Rewarded ad icon appears inside button when ads active, hidden when Remove Ads active
            final adIconInButton = find.descendant(
              of: buttonFinder,
              matching: find.byIcon(Icons.ondemand_video_rounded),
            );
            expect(
              adIconInButton,
              isRemoveAds ? findsNothing : findsOneWidget,
            );

            // Button is pinned ABOVE the scrollable list and BELOW the tab bar
            final tabBarBottom = tester
                .getBottomLeft(find.byKey(const ValueKey('royal_castle_tab_bar')))
                .dy;
            final buttonTop = tester.getTopLeft(buttonFinder).dy;
            final buttonBottom = tester.getBottomLeft(buttonFinder).dy;
            final scrollTop = tester.getTopLeft(scrollFinder).dy;

            expect(buttonTop, greaterThan(tabBarBottom));
            expect(buttonBottom, lessThanOrEqualTo(scrollTop));
            expect(
              find.descendant(of: scrollFinder, matching: buttonFinder),
              findsNothing,
            );

            // Verify button stays pinned at exact same Y when scrolling the relic list
            await tester.drag(scrollFinder, const Offset(0, -250));
            await tester.pumpAndSettle();
            expect(tester.getTopLeft(buttonFinder).dy, closeTo(buttonTop, 0.5));

            // Scroll back to top and check Active / Inactive status badges and no per-row ad icons
            await tester.drag(scrollFinder, const Offset(0, 250));
            await tester.pumpAndSettle();

            final predStatus = find.byKey(
              const ValueKey('relic_chamber_status_predictability'),
            );
            final resetStatus = find.byKey(
              const ValueKey('relic_chamber_status_reset'),
            );
            expect(predStatus, findsOneWidget);
            expect(resetStatus, findsOneWidget);
            expect(
              find.descendant(of: predStatus, matching: find.text('Active')),
              findsOneWidget,
            );
            expect(
              find.descendant(of: resetStatus, matching: find.text('Inactive')),
              findsOneWidget,
            );

            // No video/ad icons on individual relic rows
            expect(
              find.descendant(
                of: scrollFinder,
                matching: find.byIcon(Icons.ondemand_video_rounded),
              ),
              findsNothing,
            );
            expect(
              find.descendant(
                of: scrollFinder,
                matching: find.byIcon(Icons.play_circle_fill_rounded),
              ),
              findsNothing,
            );

            // Tap Restore Relics -> restores exact Active/Inactive states, clears pool, clears tab dot, shows toast
            expect(find.byKey(const Key('castle_tab_relics_dot')), findsOneWidget);
            await tester.tap(buttonFinder);
            await tester.pumpAndSettle();

            expect(controller.unlockedPredictability, isTrue);
            expect(controller.showPredictability, isTrue);
            expect(controller.unlockedReset, isTrue);
            expect(controller.showReset, isFalse);
            expect(controller.unlockedNewSkin, isTrue);
            expect(controller.showNewSkin, isFalse);
            expect(controller.overchargedStaffLevel, 6);
            expect(controller.overchargedStaffEnabled, isFalse);
            expect(controller.overchargedStaffSelectedSpeed, 10);
            expect(controller.hasAvailableRelicChamberUpgrades, isFalse);
            expect(find.byKey(const Key('castle_tab_relics_dot')), findsNothing);
            expect(find.byKey(const ValueKey('relic_chamber_empty_state')), findsOneWidget);
            expect(
              find.text('Relics restored with their previous active states!'),
              findsOneWidget,
            );
          }
        }
      },
    );
  });
}

