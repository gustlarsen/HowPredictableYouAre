import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:how_predictable/views/dialogs/shop_dialog.dart';
import 'package:how_predictable/views/screens/world_map_screen.dart';
import 'package:how_predictable/views/widgets/mana_pool_orb.dart';
import 'package:how_predictable/views/widgets/rpg_hp_bar.dart';
import 'package:how_predictable/views/widgets/versus_arena.dart';

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
  int saveCount = 0;

  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'ClericTester';

  @override
  Future<String?> getPlayerID() async => 'cleric_tester_1';

  @override
  Future<String?> saveGame({
    required String data,
    required String name,
  }) async {
    savedPayload = data;
    saveCount++;
    return 'success';
  }

  @override
  Future<String?> loadGame({required String name}) async => savedPayload;
}

Future<GameController> _createController({
  Map<String, Object> prefs = const {},
  _TestAdMobClient? adClient,
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

  group('Cleric 50 HP Baseline, Infinite Stat Upgrades & Dynamic Bars', () {
    test(
      '1. Cleric starts at 50 Max HP (-1 per loss, 0 on tie) and 100 Max Mana; upgrades, Teleport & Reset scale dynamically',
      () async {
        final playGamesClient = _TestPlayGamesClient();
        final controller = await _createController(
          prefs: {
            'orbs_fire': 200,
            'orbs_water': 200,
            'orbs_wood': 200,
            'orbs_earth': 0,
            'orbs_metal': 0,
          },
          playGamesClient: playGamesClient,
        );
        addTearDown(controller.dispose);

        expect(GameController.baseMaxHp, 50);
        expect(GameController.baseMaxMana, 100);
        expect(controller.hpUpgradeLevel, 0);
        expect(controller.manaUpgradeLevel, 0);
        expect(controller.playerMaxHp, 50);
        expect(controller.playerMaxMana, 100);
        expect(controller.userHp, 50);
        expect(controller.remainingMana, 100);
        expect(controller.computerHp, 100);

        // Purchase +1 Max HP 12 times uncapped with 0 Earth & 0 Metal orbs
        var expectedSpentHp = 0;
        for (var lv = 0; lv < 12; lv++) {
          final expectedCost = 2 + (lv ~/ 2);
          expect(controller.nextMaxHpUpgradeCost.fire, expectedCost);
          expect(controller.nextMaxHpUpgradeCost.earth, 0);
          expect(controller.nextMaxHpUpgradeCost.metal, 0);
          expect(controller.upgradeMaxHp(), isTrue);
          expectedSpentHp += expectedCost;
        }
        expect(controller.hpUpgradeLevel, 12);
        expect(controller.peakHpUpgradeLevel, 12);
        expect(controller.playerMaxHp, 62);
        expect(controller.userHp, 62);

        // Purchase +1 Max Mana 11 times uncapped
        var expectedSpentMana = 0;
        for (var lv = 0; lv < 11; lv++) {
          final expectedCost = 3 + (lv ~/ 2);
          expect(controller.nextMaxManaUpgradeCost.fire, expectedCost);
          expect(controller.upgradeMaxMana(), isTrue);
          expectedSpentMana += expectedCost;
        }
        expect(controller.manaUpgradeLevel, 11);
        expect(controller.peakManaUpgradeLevel, 11);
        expect(controller.playerMaxMana, 111);
        expect(controller.remainingMana, 111);
        expect(
          controller.fireOrbs,
          200 - expectedSpentHp - expectedSpentMana,
        );

        // Verify Cloud Save persistence
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final cloud = CloudSaveData.tryParse(playGamesClient.savedPayload)!;
        expect(cloud.hpUpgradeLevel, 12);
        expect(cloud.manaUpgradeLevel, 11);
        expect(cloud.peakHpUpgradeLevel, 12);
        expect(cloud.peakManaUpgradeLevel, 11);

        // Lose 1 round (-1 HP -> 61) and draw 1 round (0 HP damage, -1 Mana)
        controller.crystalBallMove = HandMove.paper;
        controller.playTurn(HandMove.rock);
        expect(controller.userHp, 61);
        expect(controller.remainingMana, 110);

        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.rock);
        expect(controller.userHp, 61);
        expect(controller.remainingMana, 109);

        // Turn 0 Reset & Teleport restore HP to playerMaxHp & Mana to playerMaxMana
        controller.resetGame();
        expect(controller.userHp, 62);
        expect(controller.remainingMana, 111);

        controller.crystalBallMove = HandMove.paper;
        controller.playTurn(HandMove.rock);
        expect(controller.userHp, 61);
        controller.teleportToWorldMap();
        expect(controller.userHp, 62);
        expect(controller.remainingMana, 111);
      },
    );

    testWidgets(
      '1b. RpgHpBar, ManaPoolOrb, and VersusArena scale proportionally against 50 base HP and dynamic maxMana; ShopDialog shows Lv. 0 • 50 → 51 HP',
      (WidgetTester tester) async {
        Future<void> pumpHpBar({required int hp, required int maxHp}) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: RpgHpBar(
                    hp: hp,
                    maxHp: maxHp,
                    animationsEnabled: false,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        Color readFillColor() {
          final frac = tester.widget<FractionallySizedBox>(
            find.descendant(
              of: find.byType(RpgHpBar),
              matching: find.byType(FractionallySizedBox),
            ),
          );
          final inner = frac.child! as Container;
          final gradient =
              (inner.decoration! as BoxDecoration).gradient! as LinearGradient;
          return gradient.colors.first;
        }

        double readWidthFactor() {
          final frac = tester.widget<FractionallySizedBox>(
            find.descendant(
              of: find.byType(RpgHpBar),
              matching: find.byType(FractionallySizedBox),
            ),
          );
          return frac.widthFactor!;
        }

        BoxDecoration readOuterDecor() {
          final container = tester.widget<Container>(
            find.descendant(
              of: find.byType(RpgHpBar),
              matching: find.byType(Container).first,
            ),
          );
          return container.decoration! as BoxDecoration;
        }

        // Baseline maxHp = 50:
        // 30/50 = 60% -> Emerald Green
        // 29/50 = 58% -> Amber
        // 15/50 = 30% -> Amber (non-critical)
        // 14/50 = 28% -> Crimson Red + critical pulse glow
        await pumpHpBar(hp: 30, maxHp: 50);
        expect(find.text('HP 30'), findsOneWidget);
        expect(readWidthFactor(), closeTo(0.60, 0.001));
        expect(
          readFillColor().toARGB32(),
          const Color(0xFF2ECC71).withValues(alpha: 0.95).toARGB32(),
        );

        await pumpHpBar(hp: 29, maxHp: 50);
        expect(readWidthFactor(), closeTo(29 / 50, 0.001));
        expect(
          readFillColor().toARGB32(),
          const Color(0xFFFFB300).withValues(alpha: 0.95).toARGB32(),
        );

        await pumpHpBar(hp: 15, maxHp: 50);
        expect(readOuterDecor().boxShadow!.first.color, Colors.black54);
        expect(
          readFillColor().toARGB32(),
          const Color(0xFFFFB300).withValues(alpha: 0.95).toARGB32(),
        );

        await pumpHpBar(hp: 14, maxHp: 50);
        expect(readOuterDecor().boxShadow!.first.color.r, greaterThan(0.8));
        expect(
          readFillColor().toARGB32(),
          const Color(0xFFE74C3C).withValues(alpha: 0.95).toARGB32(),
        );

        // ManaPoolOrb dynamic maxMana = 120: 25/120 > 20% normal cyan vs 24/120 <= 20% low mana
        Future<BoxDecoration> pumpManaOrb(int mana) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: ManaPoolOrb(
                    remainingMana: mana,
                    maxMana: 120,
                    animationsEnabled: false,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final frame = tester.widget<Container>(
            find.byKey(const ValueKey('mana_pool_orb_frame')),
          );
          return frame.decoration! as BoxDecoration;
        }

        final normalManaDecor = await pumpManaOrb(25);
        expect(
          normalManaDecor.boxShadow!.first.color.toARGB32(),
          const Color(0xFF00E5FF).withValues(alpha: 0.40).toARGB32(),
        );
        final lowManaDecor = await pumpManaOrb(24);
        expect(
          lowManaDecor.boxShadow!.first.color.toARGB32(),
          isNot(const Color(0xFF00E5FF).withValues(alpha: 0.40).toARGB32()),
        );

        // VersusArena defaults & ShopDialog display 50-based progression
        final localization = LocalizationService();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: VersusArena(
                  userMove: HandMove.rock,
                  computerMove: HandMove.scissors,
                  winner: RoundWinner.user,
                  localization: localization,
                  animationsEnabled: false,
                  roundId: 1,
                ),
              ),
            ),
          ),
        );
        expect(find.text('HP 50'), findsOneWidget);

        final controller = await _createController(
          prefs: {
            'orbs_fire': 20,
            'orbs_water': 20,
            'orbs_wood': 20,
            'darkMode': true,
          },
          loadStrings: true,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(body: ShopDialog(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('temple_tab_consagration')));
        await tester.pumpAndSettle();

        final hpCard = find.byKey(const ValueKey('shop_upgrade_max_hp_card'));
        final hpBtn = find.byKey(const ValueKey('shop_upgrade_max_hp_button'));
        final manaBtn = find.byKey(const ValueKey('shop_upgrade_max_mana_button'));
        expect(
          find.descendant(of: hpCard, matching: find.byType(Switch)),
          findsNothing,
        );
        expect(find.text('Lv. 0 • 50 → 51 HP'), findsOneWidget);
        expect(find.text('Lv. 0 • 100 → 101 MANA'), findsOneWidget);

        await tester.tap(hpBtn);
        await tester.pumpAndSettle();
        expect(controller.hpUpgradeLevel, 1);
        expect(controller.playerMaxHp, 51);
        expect(controller.userHp, 51);
        expect(find.text('Lv. 1 • 51 → 52 HP'), findsOneWidget);

        await tester.ensureVisible(manaBtn);
        await tester.pumpAndSettle();
        await tester.tap(manaBtn);
        await tester.pumpAndSettle();
        expect(controller.manaUpgradeLevel, 1);
        expect(controller.playerMaxMana, 101);
        expect(find.text('Lv. 1 • 101 → 102 MANA'), findsOneWidget);
      },
    );
  });

  group('Hall of Heroes Historical Peak Restoration (max, never +=)', () {
    test(
      '2. Independent all-time peaks never downgrade across weaker runs, permadeath defeats, or Reset All Progress',
      () async {
        final controller = await _createController(
          prefs: {
            'orbs_fire': 500,
            'orbs_water': 500,
            'orbs_wood': 500,
          },
        );
        addTearDown(controller.dispose);

        // Run 1: Reach HP Lv. 9, Mana Lv. 2
        for (var i = 0; i < 9; i++) {
          expect(controller.upgradeMaxHp(), isTrue);
        }
        for (var i = 0; i < 2; i++) {
          expect(controller.upgradeMaxMana(), isTrue);
        }
        expect(controller.peakHpUpgradeLevel, 9);
        expect(controller.peakManaUpgradeLevel, 2);

        // Permadeath defeat -> active stats reset to 50 HP / 100 Mana, claim unlocked
        await controller.applyPermadeathReset();
        expect(controller.hpUpgradeLevel, 0);
        expect(controller.manaUpgradeLevel, 0);
        expect(controller.playerMaxHp, 50);
        expect(controller.playerMaxMana, 100);
        expect(controller.userHp, 50);
        expect(controller.peakHpUpgradeLevel, 9);
        expect(controller.peakManaUpgradeLevel, 2);
        expect(controller.hallOfHeroesClaimAvailable, isTrue);
        expect(controller.hasHallOfHeroesBlessings, isTrue);

        // Run 2 (weaker HP, stronger Mana): Reach HP Lv. 3, Mana Lv. 11
        await controller.storage.setAllOrbs(
          fire: 500,
          water: 500,
          wood: 500,
          earth: 0,
          metal: 0,
        );
        controller.fireOrbs = 500;
        controller.waterOrbs = 500;
        controller.woodOrbs = 500;
        for (var i = 0; i < 3; i++) {
          expect(controller.upgradeMaxHp(), isTrue);
        }
        for (var i = 0; i < 11; i++) {
          expect(controller.upgradeMaxMana(), isTrue);
        }
        expect(controller.hpUpgradeLevel, 3);
        expect(controller.manaUpgradeLevel, 11);
        expect(controller.peakHpUpgradeLevel, 9); // Never downgraded from 9 to 3
        expect(controller.peakManaUpgradeLevel, 11); // Upgraded from 2 to 11

        // Permadeath defeat preserves independent peaks: HP = 9, Mana = 11
        await controller.applyPermadeathReset();
        expect(controller.hpUpgradeLevel, 0);
        expect(controller.manaUpgradeLevel, 0);
        expect(controller.peakHpUpgradeLevel, 9);
        expect(controller.peakManaUpgradeLevel, 11);
        expect(controller.hallOfHeroesClaimAvailable, isTrue);

        // Reset All Progress also evaluates max and keeps hallOfHeroesClaimAvailable == true
        await controller.resetAllProgress();
        expect(controller.hpUpgradeLevel, 0);
        expect(controller.manaUpgradeLevel, 0);
        expect(controller.playerMaxHp, 50);
        expect(controller.peakHpUpgradeLevel, 9);
        expect(controller.peakManaUpgradeLevel, 11);
        expect(controller.hallOfHeroesClaimAvailable, isTrue);
      },
    );

    test(
      '3. Partial mid-run purchase before claiming Hall of Heroes uses max(current, peak) ceiling, NOT sum (+=)',
      () async {
        final adClient = _TestAdMobClient(
          rewardedAvailable: true,
          grantRewardOnShow: true,
        );
        final controller = await _createController(
          prefs: {
            'orbs_fire': 200,
            'orbs_water': 200,
            'orbs_wood': 200,
            'peak_hp_upgrade_level': 10,
            'peak_mana_upgrade_level': 12,
            'hall_of_heroes_claim_available': true,
          },
          adClient: adClient,
        );
        addTearDown(controller.dispose);

        // Buy 2 HP levels (Lv. 2 -> 52 Max HP) and 4 Mana levels (Lv. 4 -> 104 Max Mana)
        expect(controller.upgradeMaxHp(), isTrue);
        expect(controller.upgradeMaxHp(), isTrue);
        for (var i = 0; i < 4; i++) {
          expect(controller.upgradeMaxMana(), isTrue);
        }
        expect(controller.hpUpgradeLevel, 2);
        expect(controller.manaUpgradeLevel, 4);
        expect(controller.playerMaxHp, 52);
        expect(controller.playerMaxMana, 104);

        // Claim Hall of Heroes -> restores to Peak HP Lv. 10 (60 Max HP) & Peak Mana Lv. 12 (112 Max Mana), NOT 12 or 16
        final restored = await controller.watchAdToRestoreHallOfHeroes();
        expect(restored, isTrue);
        expect(controller.hpUpgradeLevel, 10);
        expect(controller.manaUpgradeLevel, 12);
        expect(controller.playerMaxHp, 60);
        expect(controller.playerMaxMana, 112);
        expect(controller.userHp, 60);
        expect(controller.remainingMana, 112);
      },
    );

    test(
      '4. Higher current upgrade levels in active run are preserved without downgrading on claim',
      () async {
        final controller = await _createController(
          prefs: {
            'orbs_fire': 500,
            'orbs_water': 500,
            'orbs_wood': 500,
            'hp_upgrade_level': 14,
            'mana_upgrade_level': 15,
            'peak_hp_upgrade_level': 10,
            'peak_mana_upgrade_level': 12,
            'hall_of_heroes_claim_available': true,
            'unlockedAds': true,
            'removeAdsEnabled': true,
          },
        );
        addTearDown(controller.dispose);

        expect(controller.playerMaxHp, 64);
        expect(controller.playerMaxMana, 115);

        final restored = controller.restoreHallOfHeroesDirect();
        expect(restored, isTrue);
        expect(controller.hpUpgradeLevel, 14); // max(14, 10) == 14
        expect(controller.manaUpgradeLevel, 15); // max(15, 12) == 15
        expect(controller.playerMaxHp, 64);
        expect(controller.playerMaxMana, 115);
      },
    );

    test(
      '5 & 6. Single-claim lock, Remove Ads bypass, StorageService reload, and CloudSaveData round-trip',
      () async {
        final adClient = _TestAdMobClient(
          rewardedAvailable: true,
          grantRewardOnShow: true,
        );
        final playGamesClient = _TestPlayGamesClient();
        final controller = await _createController(
          prefs: {
            'peak_hp_upgrade_level': 10,
            'peak_mana_upgrade_level': 8,
            'hall_of_heroes_claim_available': true,
          },
          adClient: adClient,
          playGamesClient: playGamesClient,
        );
        addTearDown(controller.dispose);

        // Early ad dismissal neither restores nor clears flag
        adClient.grantRewardOnShow = false;
        expect(await controller.watchAdToRestoreHallOfHeroes(), isFalse);
        expect(controller.hallOfHeroesClaimAvailable, isTrue);
        expect(controller.hpUpgradeLevel, 0);

        // Rewarded Ad claim succeeds and locks further claims in the same cycle
        adClient.grantRewardOnShow = true;
        expect(await controller.watchAdToRestoreHallOfHeroes(), isTrue);
        expect(controller.hpUpgradeLevel, 10);
        expect(controller.manaUpgradeLevel, 8);
        expect(controller.hallOfHeroesClaimAvailable, isFalse);
        expect(controller.hasHallOfHeroesBlessings, isFalse);
        expect(controller.hasRoyalCastleNotification, isFalse);
        expect(controller.peakHpUpgradeLevel, 10);
        expect(controller.peakManaUpgradeLevel, 8);

        // Second claim attempt in same run fails
        expect(await controller.watchAdToRestoreHallOfHeroes(), isFalse);

        // Verify Cloud Save round-trip and StorageService persistence across reload
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final cloud = CloudSaveData.tryParse(playGamesClient.savedPayload)!;
        expect(cloud.hpUpgradeLevel, 10);
        expect(cloud.manaUpgradeLevel, 8);
        expect(cloud.peakHpUpgradeLevel, 10);
        expect(cloud.peakManaUpgradeLevel, 8);
        expect(cloud.hallOfHeroesClaimAvailable, isFalse);

        // New defeat re-enables claimAvailable without losing peaks; Remove Ads claims without ad
        controller.unlockedAds = true;
        controller.removeAdsEnabled = true;
        await controller.storage.setUnlockedAds(true);
        await controller.storage.setRemoveAdsEnabled(true);
        await controller.applyPermadeathReset();

        // Reload StorageService & controller from storage
        final reloadedStorage = StorageService();
        await reloadedStorage.init();
        expect(reloadedStorage.peakHpUpgradeLevel, 10);
        expect(reloadedStorage.peakManaUpgradeLevel, 8);
        expect(reloadedStorage.hallOfHeroesClaimAvailable, isTrue);

        final adCountBefore = adClient.showRewardedCount;
        controller.unlockedAds = true;
        controller.removeAdsEnabled = true;
        expect(controller.restoreHallOfHeroesDirect(), isTrue);
        expect(adClient.showRewardedCount, adCountBefore);
        expect(controller.hpUpgradeLevel, 10);
        expect(controller.manaUpgradeLevel, 8);
        expect(controller.playerMaxHp, 60);
        expect(controller.playerMaxMana, 108);
        expect(controller.hallOfHeroesClaimAvailable, isFalse);
      },
    );

    testWidgets(
      '7. RoyalCastleDialog compact 6-tab bar displays Heroes peak level & max stat (Lv. 10 • 60 Max HP), claims cleanly, and clears WorldMap badge',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          prefs: {
            'peak_hp_upgrade_level': 10,
            'peak_mana_upgrade_level': 8,
            'hall_of_heroes_claim_available': true,
            'unlockedAds': false,
          },
          loadStrings: true,
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

        // Open Royal Castle and tap 6th wing (Hall of Heroes) directly in single-row tab bar
        await tester.tap(find.byKey(const ValueKey('landmark_royal_castle')));
        await tester.pumpAndSettle();

        final hallTab = find.byKey(const ValueKey('castle_tab_hall_of_heroes'));
        expect(
          find.byKey(const ValueKey('royal_castle_tab_bar')),
          findsOneWidget,
        );
        expect(hallTab, findsOneWidget);
        await tester.tap(hallTab);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('castle_wing_hall_of_heroes')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('hall_of_heroes_hp_bonus_row')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('hall_of_heroes_mana_bonus_row')),
          findsOneWidget,
        );
        expect(find.text('Lv. 10 • 60 Max HP'), findsOneWidget);
        expect(find.text('Lv. 8 • 108 Max Mana'), findsOneWidget);

        // Tap Watch Ad to Restore
        final restoreAdBtn =
            find.byKey(const ValueKey('hall_of_heroes_restore_ad_button'));
        expect(restoreAdBtn, findsOneWidget);
        await tester.ensureVisible(restoreAdBtn);
        await tester.pumpAndSettle();
        await tester.tap(restoreAdBtn);
        await tester.pumpAndSettle();

        expect(controller.hpUpgradeLevel, 10);
        expect(controller.manaUpgradeLevel, 8);
        expect(controller.playerMaxHp, 60);
        expect(controller.playerMaxMana, 108);
        expect(controller.hallOfHeroesClaimAvailable, isFalse);
        expect(
          find.byKey(const ValueKey('hall_of_heroes_empty_state')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('royal_castle_close_button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('royal_castle_notification_badge')),
          findsNothing,
        );
      },
    );

    test(
      'All Cleric progression & Hall of Heroes localization keys exist cleanly across en, pt, es, and de',
      () async {
        final rawJson =
            await rootBundle.loadString('assets/data/stringsHowPredict.json');
        final map = json.decode(rawJson) as Map<String, dynamic>;

        const requiredKeys = [
          'upgrade_max_hp_title',
          'upgrade_max_hp_desc',
          'upgrade_max_mana_title',
          'upgrade_max_mana_desc',
          'stat_upgrade_action_label',
          'castle_tab_hall_of_heroes',
          'castle_wing_heroes_subtitle',
          'castle_heroes_desc',
          'castle_heroes_empty',
          'castle_heroes_hp_blessing',
          'castle_heroes_mana_blessing',
          'mana_title_word',
          'castle_heroes_restore_direct',
          'castle_heroes_restore_ad',
          'castle_heroes_ad_disclosure',
          'castle_heroes_restored_msg',
        ];

        for (final lang in ['en', 'pt', 'es', 'de']) {
          for (final key in requiredKeys) {
            final flatKey = '${lang}_$key';
            final value = map[flatKey];
            expect(value, isA<String>(), reason: 'Missing $flatKey');
            expect(
              (value as String).trim(),
              isNotEmpty,
              reason: 'Empty $flatKey',
            );
          }
          final rewind = map['${lang}_reset_rewind_message'] as String;
          expect(rewind.contains('{mana}'), isTrue);
          expect(rewind.contains('{hp}'), isTrue);
        }
      },
    );
  });
}
