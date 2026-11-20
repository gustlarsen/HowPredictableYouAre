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

  group('Cleric 60 HP Baseline, Infinite Stat Upgrades & Dynamic Bars', () {
    test(
      'Cleric starts at 60 Max HP (-1 per loss, 0 on tie) and 100 Max Mana; upgrades scale dynamically across resets and battles',
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

        expect(GameController.baseMaxHp, 60);
        expect(GameController.baseMaxMana, 100);
        expect(controller.hpUpgradeLevel, 0);
        expect(controller.manaUpgradeLevel, 0);
        expect(controller.playerMaxHp, 60);
        expect(controller.playerMaxMana, 100);
        expect(controller.userHp, 60);
        expect(controller.remainingMana, 100);
        expect(controller.computerHp, 100);

        // Cost formulas (Fire, Water, Wood only; Earth & Metal always 0)
        expect(GameController.maxHpUpgradeCostForLevel(0).fire, 2);
        expect(GameController.maxHpUpgradeCostForLevel(1).fire, 2);
        expect(GameController.maxHpUpgradeCostForLevel(2).fire, 3);
        expect(GameController.maxHpUpgradeCostForLevel(10).fire, 7);
        expect(GameController.maxHpUpgradeCostForLevel(10).earth, 0);
        expect(GameController.maxHpUpgradeCostForLevel(10).metal, 0);

        expect(GameController.maxManaUpgradeCostForLevel(0).fire, 3);
        expect(GameController.maxManaUpgradeCostForLevel(1).fire, 3);
        expect(GameController.maxManaUpgradeCostForLevel(2).fire, 4);
        expect(GameController.maxManaUpgradeCostForLevel(10).fire, 8);
        expect(GameController.maxManaUpgradeCostForLevel(10).earth, 0);
        expect(GameController.maxManaUpgradeCostForLevel(10).metal, 0);

        // Purchase +1 Max HP 12 times uncapped with 0 Earth & 0 Metal orbs
        var expectedSpentHp = 0;
        for (var lv = 0; lv < 12; lv++) {
          final expectedCost = 2 + (lv ~/ 2);
          expect(controller.nextMaxHpUpgradeCost.fire, expectedCost);
          expect(controller.nextMaxHpUpgradeCost.water, expectedCost);
          expect(controller.nextMaxHpUpgradeCost.wood, expectedCost);
          expect(controller.nextMaxHpUpgradeCost.earth, 0);
          expect(controller.nextMaxHpUpgradeCost.metal, 0);
          expect(controller.upgradeMaxHp(), isTrue);
          expectedSpentHp += expectedCost;
        }
        expect(controller.hpUpgradeLevel, 12);
        expect(controller.playerMaxHp, 72);
        expect(controller.userHp, 72); // Out-of-combat updates current HP
        expect(controller.fireOrbs, 200 - expectedSpentHp);

        // Purchase +1 Max Mana 11 times uncapped
        var expectedSpentMana = 0;
        for (var lv = 0; lv < 11; lv++) {
          final expectedCost = 3 + (lv ~/ 2);
          expect(controller.nextMaxManaUpgradeCost.fire, expectedCost);
          expect(controller.upgradeMaxMana(), isTrue);
          expectedSpentMana += expectedCost;
        }
        expect(controller.manaUpgradeLevel, 11);
        expect(controller.playerMaxMana, 111);
        expect(controller.remainingMana, 111);
        expect(
          controller.fireOrbs,
          200 - expectedSpentHp - expectedSpentMana,
        );

        // Verify Storage & Cloud Save persistence across reload
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final cloud = CloudSaveData.tryParse(playGamesClient.savedPayload)!;
        expect(cloud.hpUpgradeLevel, 12);
        expect(cloud.manaUpgradeLevel, 11);

        // Play 1 loss (-1 HP from 72 -> 71) and 1 draw (0 HP loss, -1 Mana)
        controller.crystalBallMove = HandMove.paper;
        controller.playTurn(HandMove.rock);
        expect(controller.userHp, 71);
        expect(controller.remainingMana, 110);

        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.rock);
        expect(controller.userHp, 71);
        expect(controller.remainingMana, 109);

        // Purchasing mid-battle expands Max HP without healing damage taken
        expect(controller.upgradeMaxHp(), isTrue);
        expect(controller.playerMaxHp, 73);
        expect(controller.userHp, 71);

        // Turn 0 Reset & Teleport/New Battle restore HP to playerMaxHp & Mana to playerMaxMana
        controller.resetGame();
        expect(controller.userHp, 73);
        expect(controller.remainingMana, 111);

        controller.crystalBallMove = HandMove.paper;
        controller.playTurn(HandMove.rock);
        expect(controller.userHp, 72);
        controller.completeBattleWeek();
        expect(controller.userHp, 73);
        expect(controller.remainingMana, 111);

        // Battle reaches completion at playerMaxMana (111 rounds), NOT at 100
        for (var i = 0; i < 100; i++) {
          controller.crystalBallMove = HandMove.rock;
          controller.playTurn(HandMove.rock);
        }
        expect(controller.totalRounds, 100);
        expect(controller.remainingMana, 11);
        expect(controller.is100RoundsAlertPending, isFalse);

        for (var i = 0; i < 11; i++) {
          controller.crystalBallMove = HandMove.rock;
          controller.playTurn(HandMove.rock);
        }
        expect(controller.totalRounds, 111);
        expect(controller.remainingMana, 0);
        expect(controller.is100RoundsAlertPending, isTrue);

        // Insufficient orbs rejects purchase cleanly
        controller.fireOrbs = 0;
        expect(controller.upgradeMaxHp(), isFalse);
        expect(controller.upgradeMaxMana(), isFalse);
      },
    );

    testWidgets(
      'RpgHpBar and ManaPoolOrb scale proportions, colors, and warning thresholds dynamically with playerMaxHp & playerMaxMana',
      (WidgetTester tester) async {
        // Test dynamic maxHp = 60:
        // 36/60 = 60% -> Emerald Green
        // 35/60 = 58.3% -> Amber
        // 18/60 = 30% -> Amber (non-critical)
        // 17/60 = 28.3% -> Crimson Red + critical glow
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

        await pumpHpBar(hp: 36, maxHp: 60);
        expect(find.text('HP 36'), findsOneWidget);
        expect(readWidthFactor(), closeTo(0.60, 0.001));
        expect(readFillColor().toARGB32(), const Color(0xFF2ECC71).withValues(alpha: 0.95).toARGB32());

        await pumpHpBar(hp: 35, maxHp: 60);
        expect(readWidthFactor(), closeTo(35 / 60, 0.001));
        expect(readFillColor().toARGB32(), const Color(0xFFFFB300).withValues(alpha: 0.95).toARGB32());

        await pumpHpBar(hp: 18, maxHp: 60);
        expect(readOuterDecor().boxShadow!.first.color, Colors.black54);
        expect(readFillColor().toARGB32(), const Color(0xFFFFB300).withValues(alpha: 0.95).toARGB32());

        await pumpHpBar(hp: 17, maxHp: 60);
        expect(readOuterDecor().boxShadow!.first.color.r, greaterThan(0.8));
        expect(readFillColor().toARGB32(), const Color(0xFFE74C3C).withValues(alpha: 0.95).toARGB32());

        // Dynamic upgraded maxHp = 80: 24/80 = 30% non-critical vs 23/80 = 28.75% critical
        await pumpHpBar(hp: 24, maxHp: 80);
        expect(readOuterDecor().boxShadow!.first.color, Colors.black54);
        await pumpHpBar(hp: 23, maxHp: 80);
        expect(readOuterDecor().boxShadow!.first.color.r, greaterThan(0.8));

        // ManaPoolOrb dynamic maxMana = 120: 25/120 > 20% normal cyan vs 24/120 <= 20% urgent amber/violet
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

        // VersusArena renders upgraded player HP 72 and Mana 120 cleanly
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
                  userHp: 72,
                  playerMaxHp: 72,
                  computerHp: 99,
                  computerMaxHp: 100,
                  remainingMana: 120,
                  maxMana: 120,
                ),
              ),
            ),
          ),
        );
        expect(find.text('HP 72'), findsOneWidget);
        expect(find.text('120'), findsOneWidget);
      },
    );

    testWidgets(
      'ShopDialog displays Max HP and Max Mana infinite upgrades right below Free Elemental Orbs with dynamic costs & immediate purchases',
      (WidgetTester tester) async {
        final controller = await _createController(
          prefs: {
            'orbs_fire': 20,
            'orbs_water': 20,
            'orbs_wood': 20,
            'orbs_earth': 0,
            'orbs_metal': 0,
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

        final hpCard = find.byKey(const ValueKey('shop_upgrade_max_hp_card'));
        final manaCard = find.byKey(const ValueKey('shop_upgrade_max_mana_card'));
        final hpBtn = find.byKey(const ValueKey('shop_upgrade_max_hp_button'));
        final manaBtn = find.byKey(const ValueKey('shop_upgrade_max_mana_button'));
        final adCard = find.byKey(const ValueKey('shop_rewarded_ad_card'));

        expect(adCard, findsOneWidget);
        expect(hpCard, findsOneWidget);
        expect(manaCard, findsOneWidget);
        expect(hpBtn, findsOneWidget);
        expect(manaBtn, findsOneWidget);

        // Positioned right below Free Elemental Orbs and has NO Switch toggle
        expect(
          tester.getTopLeft(adCard).dy,
          lessThan(tester.getTopLeft(hpCard).dy),
        );
        expect(
          tester.getTopLeft(hpCard).dy,
          lessThan(tester.getTopLeft(manaCard).dy),
        );
        expect(
          find.descendant(of: hpCard, matching: find.byType(Switch)),
          findsNothing,
        );
        expect(
          find.descendant(of: manaCard, matching: find.byType(Switch)),
          findsNothing,
        );

        expect(find.text('Lv. 0 • 60 → 61 HP'), findsOneWidget);
        expect(find.text('Lv. 0 • 100 → 101 MANA'), findsOneWidget);

        // Purchase 2x +1 Max HP (cost 2 each -> cost increases to 3 at Lv 2)
        await tester.tap(hpBtn);
        await tester.pumpAndSettle();
        expect(controller.hpUpgradeLevel, 1);
        expect(controller.userHp, 61);
        expect(find.text('Lv. 1 • 61 → 62 HP'), findsOneWidget);

        await tester.tap(hpBtn);
        await tester.pumpAndSettle();
        expect(controller.hpUpgradeLevel, 2);
        expect(controller.userHp, 62);
        expect(find.text('Lv. 2 • 62 → 63 HP'), findsOneWidget);
        expect(
          find.descendant(of: hpBtn, matching: find.text('3')),
          findsNWidgets(3),
        );

        // Purchase +1 Max Mana (cost 3)
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

  group('Hall of Heroes Castle Wing & Defeat Preservation', () {
    test(
      'Defeat snapshots HP & Mana upgrade levels into Hall of Heroes, ad & Remove Ads restore and clear vault cleanly',
      () async {
        final adClient = _TestAdMobClient(
          rewardedAvailable: true,
          grantRewardOnShow: true,
        );
        final playGamesClient = _TestPlayGamesClient();
        final controller = await _createController(
          prefs: {
            'orbs_fire': 100,
            'orbs_water': 100,
            'orbs_wood': 100,
            'hp_upgrade_level': 18,
            'mana_upgrade_level': 12,
          },
          adClient: adClient,
          playGamesClient: playGamesClient,
        );
        addTearDown(controller.dispose);

        expect(controller.playerMaxHp, 78);
        expect(controller.playerMaxMana, 112);
        expect(controller.hasHallOfHeroesBlessings, isFalse);

        // Total defeat resets active Cleric to 60 HP / 100 Mana and stores Hall of Heroes blessings
        await controller.applyPermadeathReset();
        expect(controller.hpUpgradeLevel, 0);
        expect(controller.manaUpgradeLevel, 0);
        expect(controller.playerMaxHp, 60);
        expect(controller.playerMaxMana, 100);
        expect(controller.userHp, 60);
        expect(controller.hallOfHeroesHpBonus, 18);
        expect(controller.hallOfHeroesManaBonus, 12);
        expect(controller.hasHallOfHeroesBlessings, isTrue);
        expect(controller.hasRoyalCastleNotification, isTrue);

        // Cloud Save persists Hall of Heroes vault
        final cloudAfterDefeat =
            CloudSaveData.tryParse(playGamesClient.savedPayload)!;
        expect(cloudAfterDefeat.hallOfHeroesHpBonus, 18);
        expect(cloudAfterDefeat.hallOfHeroesManaBonus, 12);

        // Early ad dismissal does not restore or clear vault
        adClient.grantRewardOnShow = false;
        final failedRestore = await controller.watchAdToRestoreHallOfHeroes();
        expect(failedRestore, isFalse);
        expect(controller.hallOfHeroesHpBonus, 18);
        expect(controller.hpUpgradeLevel, 0);

        // Complete Rewarded Ad restores stats and immediately zeroes vault (no duplication loop)
        adClient.grantRewardOnShow = true;
        final restored = await controller.watchAdToRestoreHallOfHeroes();
        expect(restored, isTrue);
        expect(controller.hpUpgradeLevel, 18);
        expect(controller.manaUpgradeLevel, 12);
        expect(controller.playerMaxHp, 78);
        expect(controller.playerMaxMana, 112);
        expect(controller.userHp, 78);
        expect(controller.hallOfHeroesHpBonus, 0);
        expect(controller.hallOfHeroesManaBonus, 0);
        expect(controller.hasHallOfHeroesBlessings, isFalse);

        // Subsequent claim or empty defeat cannot duplicate restored stats
        expect(controller.restoreHallOfHeroesDirect(), isFalse);

        // Remove Ads users restore blessings directly without ad
        await controller.applyPermadeathReset();
        expect(controller.hallOfHeroesHpBonus, 18);
        expect(controller.hallOfHeroesManaBonus, 12);
        expect(controller.restoreHallOfHeroesDirect(), isFalse); // Not Remove Ads yet

        controller.unlockedAds = true;
        controller.removeAdsEnabled = true;
        final adCountBefore = adClient.showRewardedCount;
        expect(controller.restoreHallOfHeroesDirect(), isTrue);
        expect(adClient.showRewardedCount, adCountBefore);
        expect(controller.hpUpgradeLevel, 18);
        expect(controller.manaUpgradeLevel, 12);
        expect(controller.hallOfHeroesHpBonus, 0);
        expect(controller.hallOfHeroesManaBonus, 0);
      },
    );

    testWidgets(
      'RoyalCastleDialog renders all 6 compact tabs without scrolling on 390x844, claims Hall of Heroes blessings, and clears WorldMap badge',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await _createController(
          prefs: {
            'hall_of_heroes_hp_bonus': 18,
            'hall_of_heroes_mana_bonus': 12,
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
        expect(find.text('+18 Max HP'), findsOneWidget);
        expect(find.text('+12 Max MANA'), findsOneWidget);

        // Claim via Rewarded Ad button
        final restoreAdBtn =
            find.byKey(const ValueKey('hall_of_heroes_restore_ad_button'));
        expect(restoreAdBtn, findsOneWidget);
        await tester.tap(restoreAdBtn);
        await tester.pumpAndSettle();

        expect(controller.hpUpgradeLevel, 18);
        expect(controller.manaUpgradeLevel, 12);
        expect(controller.hallOfHeroesHpBonus, 0);
        expect(controller.hallOfHeroesManaBonus, 0);
        expect(
          find.byKey(const ValueKey('hall_of_heroes_empty_state')),
          findsOneWidget,
        );

        // Close Castle -> World Map notification badge is cleared
        await tester.tap(find.byKey(const ValueKey('royal_castle_close_button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('royal_castle_notification_badge')),
          findsNothing,
        );
      },
    );

    test(
      'All new Cleric progression & Hall of Heroes localization keys exist cleanly across en, pt, es, and de',
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
          'castle_heroes_restore_direct',
          'castle_heroes_restore_ad',
          'castle_heroes_ad_disclosure',
          'castle_heroes_restored_msg',
        ];

        for (final lang in ['en', 'pt', 'es', 'de']) {
          for (final key in requiredKeys) {
            final flatKey = '${lang}_$key';
            final value = map[flatKey];
            expect(
              value,
              isA<String>(),
              reason: 'Missing $flatKey',
            );
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
