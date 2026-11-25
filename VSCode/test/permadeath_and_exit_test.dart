import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/billing_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/screens/world_map_screen.dart';

class _ConfigurableAdMobClient implements AdMobClient {
  bool rewardedAvailable;
  bool grantRewardOnShow;
  int showRewardedCount = 0;

  _ConfigurableAdMobClient({
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
        key: ValueKey('permadeath_test_banner'),
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

class _FakePlayGamesClient implements PlayGamesClient {
  String? savedPayload;
  int saveCount = 0;

  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'TestCleric';

  @override
  Future<String?> getPlayerID() async => 'cleric_1';

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

class _FakeBillingClient implements InAppPurchaseClient {
  final StreamController<List<PurchaseDetails>> _purchaseController =
      StreamController<List<PurchaseDetails>>.broadcast();
  final List<String> restoredIds;

  _FakeBillingClient({this.restoredIds = const []});

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _purchaseController.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(
      productDetails: [
        for (final id in identifiers)
          ProductDetails(
            id: id,
            title: id,
            description: 'Test IAP $id',
            price: '\$1.99',
            rawPrice: 1.99,
            currencyCode: 'USD',
          ),
      ],
      notFoundIDs: const [],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async =>
      true;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> consumePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    if (restoredIds.isEmpty) return;
    _purchaseController.add([
      for (final id in restoredIds)
        PurchaseDetails(
          productID: id,
          verificationData: PurchaseVerificationData(
            localVerificationData: 'local_$id',
            serverVerificationData: 'server_$id',
            source: 'google_play',
          ),
          transactionDate: '1700000000000',
          status: PurchaseStatus.restored,
        ),
    ]);
  }

  void dispose() {
    _purchaseController.close();
  }
}

/// Drives the AI to deal 1 final fatal damage when the user loses a round.
HandMove _losingMoveFor(GameController controller) {
  final aiPredictedMove = controller.crystalBallMove ?? HandMove.rock;
  // Return a move that loses to aiPredictedMove under current rules
  for (final candidate in [HandMove.rock, HandMove.paper, HandMove.scissors]) {
    if (aiPredictedMove.beats(candidate, elemental: controller.isElementalMode)) {
      return candidate;
    }
  }
  return HandMove.rock;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Battle Exit Rules, Death Revival, Week > 40 Fall & Permadeath', () {
    testWidgets(
      'AppBar has no back arrow and PopScope prevents escaping GameScreen',
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
        });
        final storage = StorageService();
        await storage.init();

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
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

        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GameScreen), findsOneWidget);
        expect(find.byKey(const ValueKey('game_retreat_button')), findsNothing);
        expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
        expect(find.byIcon(Icons.arrow_back), findsNothing);
        expect(find.byKey(const ValueKey('teleport_portal_button')), findsOneWidget);

        // Verify PopScope wraps GameScreen with canPop: false and blocks maybePop
        final popScopeFinder = find.descendant(
          of: find.byType(GameScreen),
          matching: find.byType(PopScope),
        );
        expect(popScopeFinder, findsOneWidget);
        final popScope = tester.widget<PopScope>(popScopeFinder);
        expect(popScope.canPop, isFalse);

        // Simulate Android system back button AND Navigator.maybePop()
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(GameScreen), findsOneWidget);

        final navState = tester.state<NavigatorState>(find.byType(Navigator));
        await navState.maybePop();
        await tester.pumpAndSettle();

        expect(find.byType(GameScreen), findsOneWidget);
        expect(controller.currentWeek, 0);
      },
    );

    testWidgets(
      'Reaching 0 HP locks inputs, waits ~650ms for hit animation, opens You Died dialog, handles early dismissal, and revives with kept orbs & week on Rewarded Ad',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': true,
          'musicEnabled': false,
          'current_week': 3,
          'orbs_fire': 10,
        });
        final storage = StorageService();
        await storage.init();

        final adClient = _ConfigurableAdMobClient(
          rewardedAvailable: true,
          grantRewardOnShow: false,
        );
        final adService = AdService(client: adClient);
        await adService.initialize();

        final playGamesClient = _FakePlayGamesClient();
        final playGames = PlayGamesService(
          storage: storage,
          client: playGamesClient,
        );
        await playGames.signIn();

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          adService: adService,
          playGames: playGames,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        // Enter battle (starts at HP 100, Mana 100)
        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(GameScreen), findsOneWidget);
        expect(controller.currentWeek, 3);

        // Award some orbs collected during battle and drop HP to 1
        controller.addOrbForMove(HandMove.rock, 5);
        controller.userHp = 1;
        controller.notifyListeners();
        await tester.pump();

        // Take fatal hit on a losing turn
        final losingMove = _losingMoveFor(controller);
        await tester.tap(find.byKey(ValueKey('hand_button_${losingMove.name}')));
        await tester.pump();

        expect(controller.userHp, 0);
        final turnAtDeath = controller.turnCount;

        // Inputs are locked immediately after HP hits 0
        await tester.tap(find.byKey(const ValueKey('hand_button_rock')));
        await tester.pump();
        expect(controller.turnCount, turnAtDeath);

        // Final hit impact animation plays first: dialog is NOT shown before 650ms
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('death_dialog')), findsNothing);

        // After ~650ms animation completes, You Died modal appears
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(find.byKey(const ValueKey('death_dialog')), findsOneWidget);
        expect(find.text('You Died'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('death_revive_ad_button')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('death_accept_button')), findsOneWidget);

        // If user dismisses ad early without earning reward, dialog remains open
        await tester.tap(find.byKey(const ValueKey('death_revive_ad_button')));
        await tester.pump();
        expect(adClient.showRewardedCount, 1);
        expect(find.byKey(const ValueKey('death_dialog')), findsOneWidget);
        expect(controller.userHp, 0);

        // Now complete rewarded ad properly -> revives HP=100, Mana=100, keeps orbs & week 3, retreats to map
        adClient.grantRewardOnShow = true;
        await tester.tap(find.byKey(const ValueKey('death_revive_ad_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byKey(const ValueKey('death_dialog')), findsNothing);
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(find.byType(GameScreen), findsNothing);
        expect(controller.userHp, GameController.maxHp);
        expect(controller.remainingMana, GameController.maxMana);
        expect(controller.fireOrbs, 15);
        expect(controller.currentWeek, 3);
        expect(find.text('Week 3 / 40'), findsOneWidget);
      },
    );

    testWidgets(
      'Accept Death hides revive button when no ad ready and runs Week 0 permadeath reset preserving paid IAPs while locking orb upgrades and overwriting cloud save',
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
          'current_week': 7,
          'orbs_fire': 250,
          'orbs_water': 120,
          'orbs_wood': 90,
          'orbs_earth': 60,
          'orbs_metal': 30,
          // Orb-bought upgrades (not paid with real money)
          'unlockedReset': true,
          'showReset': true,
          'unlockedAlgorithm': true,
          'unlockedAds': true,
          'removeAdsEnabled': true,
          'unlockedNewSkin': true,
          'gift_box_unlocked': true,
          // Persisted real-money IAP
          'iap_purchased_product_ids': [BillingService.productSuggestion],
          'unlockedSuggestion': true,
        });
        final storage = StorageService();
        await storage.init();

        final adClient = _ConfigurableAdMobClient(rewardedAvailable: false);
        final adService = AdService(client: adClient);
        await adService.initialize();

        final billingClient = _FakeBillingClient(
          restoredIds: [BillingService.productCrystalBall],
        );
        final billingService = BillingService(client: billingClient);
        await billingService.initialize();

        final playGamesClient = _FakePlayGamesClient();
        final playGames = PlayGamesService(
          storage: storage,
          client: playGamesClient,
        );
        await playGames.signIn();

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          adService: adService,
          billingService: billingService,
          playGames: playGames,
        );
        addTearDown(() {
          controller.dispose();
          billingService.dispose();
          billingClient.dispose();
        });

        // Simulate restoring Google Play IAP entitlements prior to death
        await controller.restorePurchases();
        await tester.pump();
        expect(controller.unlockedCrystalBall, isTrue);
        expect(controller.unlockedSuggestion, isTrue);
        expect(controller.unlockedReset, isTrue);

        // Save initial Week 7 cloud payload before permadeath
        await playGames.saveCloudData();
        final oldCloud = CloudSaveData.tryParse(playGamesClient.savedPayload)!;
        expect(oldCloud.currentWeek, 7);
        expect(oldCloud.fireOrbs, 250);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Week 7 / 40'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();

        // Trigger death (HP == 0)
        controller.userHp = 1;
        final losingMove = _losingMoveFor(controller);
        controller.playTurn(losingMove);
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const ValueKey('death_dialog')), findsOneWidget);
        // No ad ready -> revive button hidden
        expect(
          find.byKey(const ValueKey('death_revive_ad_button')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('death_accept_button')), findsOneWidget);

        // Accept Death -> permadeath hard reset to Week 0 & return to map
        await tester.tap(find.byKey(const ValueKey('death_accept_button')));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(find.byType(GameScreen), findsNothing);
        expect(controller.currentWeek, 0);
        expect(storage.currentWeek, 0);
        expect(find.text('Week 0 / 40'), findsOneWidget);

        // All 5 elemental orbs wiped to 0
        expect(controller.fireOrbs, 0);
        expect(controller.waterOrbs, 0);
        expect(controller.woodOrbs, 0);
        expect(controller.earthOrbs, 0);
        expect(controller.metalOrbs, 0);
        expect(controller.totalOrbs, 0);
        expect(controller.turn0FireOrbs, 0);
        expect(controller.turn0WaterOrbs, 0);
        expect(controller.turn0WoodOrbs, 0);
        expect(controller.turn0EarthOrbs, 0);
        expect(controller.turn0MetalOrbs, 0);

        // Orb-bought Offerings upgrades locked, HP/Mana 50/100, Markov cleared;
        // Vow of Silence (Remove Ads) remains permanently untouched
        expect(controller.unlockedReset, isFalse);
        expect(controller.unlockedAlgorithm, isFalse);
        expect(controller.unlockedAds, isTrue);
        expect(controller.isRemoveAdsOwned, isTrue);
        expect(controller.isRemoveAdsEnabled, isTrue);
        expect(controller.isRemoveAdsActive, isTrue);
        expect(
          controller.relicChamberStoredUpgrades,
          isNot(contains('remove_ads')),
        );
        expect(controller.unlockedNewSkin, isFalse);
        expect(controller.giftBoxUnlocked, isFalse);
        expect(controller.userHp, GameController.maxHp);
        expect(controller.remainingMana, GameController.maxMana);
        expect(
          controller.engine.matrix.every((row) => row.every((c) => c == 0)),
          isTrue,
        );

        // Real-money IAP upgrades permanently preserved
        expect(controller.unlockedCrystalBall, isTrue);
        expect(controller.unlockedSuggestion, isTrue);

        // Cloud Save overwritten with Week 0 so reloading cloud cannot revert it
        final resetCloud = CloudSaveData.tryParse(playGamesClient.savedPayload)!;
        expect(resetCloud.currentWeek, 0);
        expect(resetCloud.fireOrbs, 0);
        expect(resetCloud.unlockedCrystalBall, isTrue);
        expect(resetCloud.unlockedSuggestion, isTrue);
        await playGames.loadAndResolveCloudSave();
        expect(controller.currentWeek, 0);
      },
    );

    testWidgets(
      'Passing Week 40 via Teleport or 100 rounds triggers localized Metal Wizard conquest modal and resets to Week 0 while preserving real-money Remove Ads IAP',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'has_shown_week10_archmage_warning': true,
          'animationsEnabled': false,
          'musicEnabled': false,
          'current_week': 40,
          'orbs_fire': 500,
          'unlockedRandom': true,
          'iap_purchased_product_ids': [BillingService.productRemoveAds],
          'unlockedAds': true,
          'removeAdsEnabled': true,
        });
        final storage = StorageService();
        await storage.init();

        final adClient = _ConfigurableAdMobClient();
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

        expect(find.text('Week 40 / 40'), findsOneWidget);
        expect(find.byKey(const ValueKey('bottom_banner_ad_container')), findsNothing);

        // Case A: Teleport at Week 40 pushes week > 40 -> Kingdom Fall modal
        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('teleport_portal_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('teleport_confirm_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('week40_kingdom_fall_dialog')),
          findsOneWidget,
        );
        expect(find.text('The Kingdom Has Fallen'), findsOneWidget);
        expect(
          find.textContaining('Metal Wizard has taken over'),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('week40_kingdom_fall_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(controller.currentWeek, 0);
        expect(controller.fireOrbs, 0);
        expect(controller.unlockedRandom, isFalse);
        expect(controller.unlockedAds, isTrue);
        expect(controller.isRemoveAdsActive, isTrue);
        expect(find.text('Week 0 / 40'), findsOneWidget);
        expect(find.byKey(const ValueKey('bottom_banner_ad_container')), findsNothing);

        // Case B: Completing 100 rounds at Week 40 (and verify pt localization)
        controller.currentWeek = 40;
        controller.hasShownWeek10ArchmageWarning = true;
        storage.setCurrentWeek(40);
        storage.setHasShownWeek10ArchmageWarning(true);
        controller.setLanguage('pt');
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();

        for (var i = 0; i < 100; i++) {
          controller.playTurn(controller.crystalBallMove ?? HandMove.rock);
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(
          find.byKey(const ValueKey('battle_return_to_map_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('week40_kingdom_fall_dialog')),
          findsOneWidget,
        );
        expect(find.text('O Reino Caiu'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('week40_kingdom_fall_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(controller.currentWeek, 0);
        expect(controller.unlockedAds, isTrue);
      },
    );
  });
}
