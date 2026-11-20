import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/models/royal_castle.dart';
import 'package:how_predictable/models/story_chapter.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/billing_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/royal_castle_dialog.dart';
import 'package:how_predictable/views/dialogs/settings_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
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
  Widget? buildBannerWidget() => const SizedBox(
        key: ValueKey('reset_test_banner'),
        width: 320,
        height: 50,
      );

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
  Future<String?> getPlayerName() async => 'ResetHero';

  @override
  Future<String?> getPlayerID() async => 'reset_hero_1';

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

class _TestBillingClient implements InAppPurchaseClient {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(
      productDetails: const [],
      notFoundIDs: identifiers.toList(),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsDialog Reset All Progress -> Campaign Week 0 & Castle Archiving', () {
    test(
      'resetAllProgress archives artifacts, orbs, and HP/Mana levels, enforces Double-Reset Guard, resets to Week 0 / Turn 0, preserves global data, and syncs Cloud Save',
      () async {
        SharedPreferences.setMockInitialValues({
          'current_week': 14,
          'orbs_fire': 45,
          'orbs_water': 30,
          'orbs_wood': 25,
          'orbs_earth': 15,
          'orbs_metal': 10,
          'turn0_orbs_fire': 40,
          'turn0_orbs_water': 30,
          'turn0_orbs_wood': 25,
          'turn0_orbs_earth': 15,
          'turn0_orbs_metal': 10,
          'userScore': 7,
          'pcScore': 5,
          'total': 12,
          'userHp': 55,
          'pcHp': 93,
          'hp_upgrade_level': 3,
          'mana_upgrade_level': 2,
          'unlockedPredictability': true,
          'showPredictability': true,
          'unlockedReset': true,
          'showReset': true,
          'unlockedAlgorithm': true,
          'showAlgorithm': true,
          'giftBoxUnlocked': true,
          'giftBoxEnabled': true,
          'unlockedNewSkin': true,
          'showNewSkin': true,
          'unlockedCrystalBall': true,
          'showCrystalBall': true,
          'unlockedCrystalBallPlus': true,
          'showCrystalBallPlus': true,
          // Global Remove Ads IAP
          'iap_purchased_product_ids': [BillingService.productRemoveAds],
          'unlockedAds': true,
          'removeAdsEnabled': true,
          // Global story memories, Castle Library/Treasury/Hall of Heroes, UI settings
          'has_seen_story_intro': true,
          'has_seen_story_reset': true,
          'has_seen_story_algorithm': true,
          'unlocked_endings': ['ending_victor'],
          'encountered_bestiary': ['guardian_robot'],
          'treasury_orbs_fire': 25,
          'hall_of_heroes_hp_bonus': 4,
          'hall_of_heroes_mana_bonus': 1,
          'darkMode': false,
          'language': 'pt',
          'soundEnabled': false,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final playGamesClient = _TestPlayGamesClient();
        final playGames = PlayGamesService(
          storage: storage,
          client: playGamesClient,
        );
        await playGames.signIn();

        final localization = LocalizationService();
        await localization.load();

        final adService = AdService(client: _TestAdMobClient());
        await adService.initialize(adsRemoved: true);

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
          playGames: playGames,
          adService: adService,
          billingService: BillingService(client: _TestBillingClient()),
        );
        addTearDown(controller.dispose);

        // Record a Markov transition so matrix is non-empty
        controller.playTurn(HandMove.rock);
        controller.playTurn(HandMove.paper);
        expect(
          controller.engine.matrix.any((r) => r.any((c) => c > 0)),
          isTrue,
        );

        final fireBeforeReset = controller.fireOrbs;
        final waterBeforeReset = controller.waterOrbs;
        final woodBeforeReset = controller.woodOrbs;
        final earthBeforeReset = controller.earthOrbs;
        final metalBeforeReset = controller.metalOrbs;
        final treasuryFireBeforeReset = controller.treasuryFireOrbs;

        // First reset: archives items/orbs/stats and resets active run to Week 0 / Turn 0
        await controller.resetAllProgress();

        // 1. Campaign Week & active inventory wiped
        expect(controller.currentWeek, 0);
        expect(storage.currentWeek, 0);
        expect(controller.totalOrbs, 0);
        expect(controller.fireOrbs, 0);
        expect(controller.waterOrbs, 0);
        expect(controller.woodOrbs, 0);
        expect(controller.earthOrbs, 0);
        expect(controller.metalOrbs, 0);
        expect(controller.turn0FireOrbs, 0);
        expect(controller.turn0WaterOrbs, 0);
        expect(controller.turn0WoodOrbs, 0);
        expect(controller.turn0EarthOrbs, 0);
        expect(controller.turn0MetalOrbs, 0);

        // 2. Active run artifacts/upgrades locked (except real-money Remove Ads IAP)
        expect(controller.unlockedPredictability, isFalse);
        expect(controller.unlockedReset, isFalse);
        expect(controller.unlockedAlgorithm, isFalse);
        expect(controller.giftBoxUnlocked, isFalse);
        expect(controller.unlockedNewSkin, isFalse);
        expect(controller.unlockedCrystalBall, isFalse);
        expect(controller.unlockedCrystalBallPlus, isFalse);
        expect(controller.hpUpgradeLevel, 0);
        expect(controller.manaUpgradeLevel, 0);

        // 3. Battle/Arena state cleanly reset to Turn 0
        expect(controller.remainingMana, GameController.baseMaxMana);
        expect(controller.userHp, GameController.baseMaxHp);
        expect(controller.computerHp, GameController.pcMaxHp);
        expect(controller.userScore, 0);
        expect(controller.pcScore, 0);
        expect(controller.totalRounds, 0);
        expect(controller.percentPredict, 0.0);
        expect(controller.currentUserMove, isNull);
        expect(controller.currentComputerMove, isNull);
        expect(controller.lastUserMove, isNull);
        expect(
          controller.engine.matrix.every((r) => r.every((c) => c == 0)),
          isTrue,
        );

        // 4. Archived into Castle's Relic Chamber, Spoils of War, & Hall of Heroes
        expect(
          controller.relicChamberStoredUpgrades,
          containsAll([
            'predictability',
            'reset',
            'algorithm',
            'gift_box',
            'new_skin',
            'crystal_ball',
            'crystal_ball_plus',
          ]),
        );
        expect(
          controller.relicChamberStoredUpgrades,
          isNot(contains('remove_ads')),
        );
        expect(controller.spoilsFireOrbs, fireBeforeReset);
        expect(controller.spoilsWaterOrbs, waterBeforeReset);
        expect(controller.spoilsWoodOrbs, woodBeforeReset);
        expect(controller.spoilsEarthOrbs, earthBeforeReset);
        expect(controller.spoilsMetalOrbs, metalBeforeReset);
        expect(controller.peakHpUpgradeLevel, 4);
        expect(controller.peakManaUpgradeLevel, 2);
        expect(controller.hallOfHeroesClaimAvailable, isTrue);
        expect(controller.hasRoyalCastleNotification, isTrue);

        // 5. Global account data preserved
        expect(controller.hasSeenStoryIntro, isTrue);
        expect(controller.hasSeenStoryReset, isTrue);
        expect(controller.hasSeenStoryAlgorithm, isTrue);
        expect(
          controller.isStoryChapterUnlocked(StoryChapter.resetButton),
          isTrue,
        );
        expect(
          controller.isEndingUnlocked(NarrativeEnding.triumphantStrategist),
          isTrue,
        );
        expect(
          controller.isBestiaryEncountered(BestiaryCreature.guardianRobot),
          isTrue,
        );
        expect(controller.treasuryFireOrbs, treasuryFireBeforeReset);
        expect(controller.unlockedAds, isTrue);
        expect(controller.isRemoveAdsActive, isTrue);
        expect(controller.darkMode, isFalse);
        expect(controller.localization.currentLanguage, 'pt');
        expect(controller.soundEnabled, isFalse);

        // 6. Double-Reset Guard: second reset on empty hero MUST NOT wipe archived rewards
        await controller.resetAllProgress();

        expect(
          controller.relicChamberStoredUpgrades,
          containsAll([
            'predictability',
            'reset',
            'algorithm',
            'gift_box',
            'new_skin',
            'crystal_ball',
            'crystal_ball_plus',
          ]),
        );
        expect(controller.spoilsFireOrbs, fireBeforeReset);
        expect(controller.spoilsWaterOrbs, waterBeforeReset);
        expect(controller.spoilsWoodOrbs, woodBeforeReset);
        expect(controller.spoilsEarthOrbs, earthBeforeReset);
        expect(controller.spoilsMetalOrbs, metalBeforeReset);
        expect(controller.peakHpUpgradeLevel, 4);
        expect(controller.peakManaUpgradeLevel, 2);
        expect(controller.hallOfHeroesClaimAvailable, isTrue);

        // 7. Cloud Save reflects Week 0 + archived Castle pools
        final cloud = CloudSaveData.tryParse(playGamesClient.savedPayload)!;
        expect(cloud.currentWeek, 0);
        expect(cloud.totalOrbs, 0);
        expect(cloud.spoilsFireOrbs, fireBeforeReset);
        expect(
          cloud.relicChamberUpgrades,
          containsAll(['reset', 'algorithm', 'crystal_ball']),
        );
        expect(cloud.peakHpUpgradeLevel, 4);
        expect(cloud.peakManaUpgradeLevel, 2);
        expect(cloud.hallOfHeroesClaimAvailable, isTrue);
        expect(cloud.hasSeenStoryIntro, isTrue);
        expect(cloud.hasSeenStoryReset, isTrue);
        expect(cloud.unlockedAds, isTrue);
      },
    );

    testWidgets(
      'Confirming Reset All Progress from WorldMapScreen archives items/orbs to Castle, displays badge, and allows Castle recovery via Rewarded Ad',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
          'current_week': 8,
          'orbs_fire': 40,
          'orbs_water': 25,
          'unlockedReset': true,
          'unlockedRandom': true,
        });
        final storage = StorageService();
        await storage.init();

        final adClient = _TestAdMobClient(
          rewardedAvailable: true,
          grantRewardOnShow: true,
        );
        final adService = AdService(client: adClient);
        await adService.initialize();

        final localization = LocalizationService();
        await tester.runAsync(() => localization.load());

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
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Week 8 / 40'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('royal_castle_notification_badge')),
          findsNothing,
        );

        // Open SettingsDialog -> Reset All Progress
        await tester.tap(
          find.byKey(const ValueKey('world_map_settings_button')),
        );
        await tester.pumpAndSettle();

        final resetBtn = find.byKey(
          const ValueKey('settings_reset_progress_button'),
        );
        await tester.ensureVisible(resetBtn);
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();

        expect(find.text('Reset All Progress?'), findsOneWidget);
        expect(find.textContaining('Week 0'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('Royal Castle'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('rewarded video ad'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('confirm_reset_progress_button')),
        );
        await tester.pumpAndSettle();

        // Landed on WorldMapScreen at Week 0 with Castle badge
        expect(find.byType(SettingsDialog), findsNothing);
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(find.text('Week 0 / 40'), findsOneWidget);
        expect(controller.totalOrbs, 0);
        expect(controller.unlockedReset, isFalse);
        expect(controller.unlockedRandom, isFalse);
        expect(
          find.byKey(const ValueKey('royal_castle_notification_badge')),
          findsOneWidget,
        );

        // Open Royal Castle -> restore Relics & reclaim Spoils via Rewarded Ad
        await tester.tap(find.byKey(const ValueKey('landmark_royal_castle')));
        await tester.pumpAndSettle();
        expect(find.byType(RoyalCastleDialog), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('castle_tab_relics')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('relic_chamber_item_reset')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('relic_chamber_item_random')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('relic_chamber_restore_ad_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.unlockedReset, isTrue);
        expect(controller.unlockedRandom, isTrue);

        await tester.tap(find.byKey(const ValueKey('castle_tab_spoils')));
        await tester.pumpAndSettle();
        expect(find.text('+40'), findsOneWidget);
        expect(find.text('+25'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('spoils_reclaim_ad_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.fireOrbs, 40);
        expect(controller.waterOrbs, 25);

        await tester.tap(find.byKey(const ValueKey('royal_castle_close_button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('royal_castle_notification_badge')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Triggering Reset All Progress from inside GameScreen (Arena Settings) exits GameScreen and lands on WorldMapScreen at Week 0 with Castle badge',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
          'current_week': 9,
          'orbs_fire': 12,
          'unlockedAlgorithm': true,
          'showAlgorithm': true,
        });
        final storage = StorageService();
        await storage.init();

        final localization = LocalizationService();
        await tester.runAsync(() => localization.load());

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Enter battle arena (GameScreen)
        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GameScreen), findsOneWidget);

        // Win 1 round in arena to earn an extra Water/Fire orb and populate Markov matrix
        controller.crystalBallMove = HandMove.rock;
        controller.playTurn(HandMove.paper);
        await tester.pump();
        expect(controller.fireOrbs, 13);
        expect(controller.totalRounds, 1);

        // Open SettingsDialog from GameScreen AppBar
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsDialog), findsOneWidget);

        final resetBtn = find.byKey(
          const ValueKey('settings_reset_progress_button'),
        );
        await tester.ensureVisible(resetBtn);
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();

        // Confirm Reset All Progress
        await tester.tap(
          find.byKey(const ValueKey('confirm_reset_progress_button')),
        );
        await tester.pumpAndSettle();

        // Both SettingsDialog AND GameScreen are popped -> user lands on WorldMapScreen at Week 0
        expect(find.byType(SettingsDialog), findsNothing);
        expect(find.byType(GameScreen), findsNothing);
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(find.text('Week 0 / 40'), findsOneWidget);
        expect(controller.currentWeek, 0);
        expect(controller.totalOrbs, 0);
        expect(controller.totalRounds, 0);
        expect(controller.remainingMana, GameController.baseMaxMana);
        expect(controller.userHp, GameController.baseMaxHp);
        expect(controller.unlockedAlgorithm, isFalse);
        expect(controller.spoilsFireOrbs, 13);
        expect(
          controller.relicChamberStoredUpgrades,
          contains('algorithm'),
        );
        expect(
          find.byKey(const ValueKey('royal_castle_notification_badge')),
          findsOneWidget,
        );
      },
    );

    test(
      'Updated Reset All Progress confirmation and completion messages are localized in en, pt, es, and de',
      () async {
        final rawJson =
            await rootBundle.loadString('assets/data/stringsHowPredict.json');
        final map = json.decode(rawJson) as Map<String, dynamic>;

        for (final lang in ['en', 'pt', 'es', 'de']) {
          final msg = map['${lang}_reset_all_progress_message'] as String?;
          final done = map['${lang}_reset_all_progress_done'] as String?;
          expect(msg, isNotNull, reason: 'Missing ${lang}_reset_all_progress_message');
          expect(msg!.trim(), isNotEmpty);
          expect(msg, contains('0'));
          expect(done, isNotNull, reason: 'Missing ${lang}_reset_all_progress_done');
          expect(done!.trim(), isNotEmpty);
          expect(done, contains('0'));
        }
      },
    );
  });
}
