import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/billing_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';

class FakeInAppPurchaseClient implements InAppPurchaseClient {
  final StreamController<List<PurchaseDetails>> purchaseStreamController =
      StreamController<List<PurchaseDetails>>.broadcast();

  bool available;
  bool buyShouldSucceed;
  Map<String, String> storePrices;
  int queryProductDetailsCallCount = 0;
  int buyNonConsumableCallCount = 0;
  int buyConsumableCallCount = 0;
  int restorePurchasesCallCount = 0;
  final List<PurchaseDetails> completedPurchases = [];
  final List<PurchaseDetails> consumedPurchases = [];
  final List<String> boughtProductIds = [];

  FakeInAppPurchaseClient({
    this.available = true,
    this.buyShouldSucceed = true,
    Map<String, String>? storePrices,
  }) : storePrices = storePrices ??
            {
              BillingService.productResetButton: r'$0.99',
              BillingService.productPredictabilityScore: r'$0.99',
              BillingService.productRandomButton: r'$1.49',
              BillingService.productShowAlgorithm: r'$1.99',
              BillingService.productNewHands: r'$0.99',
              BillingService.productYourPrediction: r'$2.49',
              BillingService.productPcNextMove: r'$2.99',
              BillingService.productSuggestion: r'$3.49',
              BillingService.productRemoveAds: r'$4.99',
              BillingService.productCrystalBall: 'R\$ 9,90',
              BillingService.productConsumableSmall: r'$1.99',
              BillingService.productConsumableMedium: r'$4.99',
              BillingService.productConsumableLarge: r'$9.99',
              BillingService.productConsumableFire1500: r'$1.99',
              BillingService.productConsumableWater1500: r'$1.99',
              BillingService.productConsumableWood1500: r'$1.99',
              BillingService.productConsumableEarth1500: r'$1.99',
              BillingService.productConsumableMetal1500: r'$1.99',
            };

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      purchaseStreamController.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    queryProductDetailsCallCount++;
    final details = <ProductDetails>[];
    final notFound = <String>[];

    for (final id in identifiers) {
      final price = storePrices[id];
      if (price != null) {
        details.add(
          ProductDetails(
            id: id,
            title: id,
            description: 'Store product $id',
            price: price,
            rawPrice: 0.99,
            currencyCode: price.startsWith('R') ? 'BRL' : 'USD',
          ),
        );
      } else {
        notFound.add(id);
      }
    }

    return ProductDetailsResponse(
      productDetails: details,
      notFoundIDs: notFound,
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyNonConsumableCallCount++;
    boughtProductIds.add(purchaseParam.productDetails.id);
    return buyShouldSucceed;
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    buyConsumableCallCount++;
    boughtProductIds.add(purchaseParam.productDetails.id);
    return buyShouldSucceed;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }

  @override
  Future<void> consumePurchase(PurchaseDetails purchase) async {
    consumedPurchases.add(purchase);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restorePurchasesCallCount++;
  }

  void emitPurchaseUpdate(
    String productId,
    PurchaseStatus status, {
    String? errorMessage,
    bool pendingCompletePurchase = true,
  }) {
    final purchase = PurchaseDetails(
      purchaseID: 'order_$productId',
      productID: productId,
      verificationData: PurchaseVerificationData(
        localVerificationData: 'local_$productId',
        serverVerificationData: 'server_$productId',
        source: 'google_play',
      ),
      transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
      status: status,
    )..pendingCompletePurchase = pendingCompletePurchase;

    if (errorMessage != null) {
      purchase.error = IAPError(
        source: 'google_play',
        code: 'purchase_error',
        message: errorMessage,
      );
    }

    purchaseStreamController.add([purchase]);
  }

  void dispose() {
    purchaseStreamController.close();
  }
}

class _FakePlayGamesClient implements PlayGamesClient {
  int saveCallCount = 0;

  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'BillingTester';

  @override
  Future<String?> getPlayerID() async => 'player_billing_1';

  @override
  Future<String?> saveGame({required String data, required String name}) async {
    saveCallCount++;
    return 'success';
  }

  @override
  Future<String?> loadGame({required String name}) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BillingService & Google Play In-App Purchase Tests', () {
    test('Maps all 10 non-consumable shop items to exact Google Play Product IDs', () {
      expect(BillingService.allProductIds.length, 10);
      expect(
        BillingService.productIdForShopItem('Reset Button'),
        'unlock_reset_button',
      );
      expect(
        BillingService.productIdForShopItem('Predictability Score'),
        'unlock_predictability_score',
      );
      expect(
        BillingService.productIdForShopItem('Random Button'),
        'unlock_random_button',
      );
      expect(
        BillingService.productIdForShopItem('Show Algorithm'),
        'unlock_show_algorithm',
      );
      expect(
        BillingService.productIdForShopItem('New Hands'),
        'unlock_new_hands',
      );
      expect(
        BillingService.productIdForShopItem('Your Prediction'),
        'unlock_your_prediction',
      );
      expect(
        BillingService.productIdForShopItem('PC Next Move'),
        'unlock_pc_next_move',
      );
      expect(
        BillingService.productIdForShopItem('Sugestion'),
        'unlock_suggestion',
      );
      expect(
        BillingService.productIdForShopItem('Remove Ads'),
        'unlock_remove_ads',
      );
      expect(
        BillingService.productIdForShopItem('Crystal Ball'),
        'unlock_crystal_ball',
      );
    });

    test(
      'Initializes billing connection, queries all 10 product details, and returns localized store prices',
      () async {
        final fakeClient = FakeInAppPurchaseClient();
        addTearDown(fakeClient.dispose);

        final billing = BillingService(client: fakeClient);
        addTearDown(billing.dispose);

        await billing.initialize();

        expect(billing.isAvailable, isTrue);
        expect(billing.isLoadingProducts, isFalse);
        expect(fakeClient.queryProductDetailsCallCount, 1);
        expect(
          billing.getLocalizedPrice(BillingService.productResetButton),
          r'$0.99',
        );
        expect(
          billing.getLocalizedPrice(BillingService.productCrystalBall),
          'R\$ 9,90',
        );
      },
    );

    test(
      'PurchaseStatus.purchased and PurchaseStatus.restored unlock all 10 items in GameController without deducting Elemental Orbs, persist to SharedPreferences, trigger cloud save, and call completePurchase',
      () async {
        SharedPreferences.setMockInitialValues({
          'orbs_fire': 500,
          'orbs_water': 500,
          'orbs_wood': 500,
          'orbs_earth': 500,
          'orbs_metal': 500,
          'musicEnabled': false,
          'has_seen_story_intro': true,
        });
        final storage = StorageService();
        await storage.init();

        final fakePlayGamesClient = _FakePlayGamesClient();
        final playGames = PlayGamesService(
          storage: storage,
          client: fakePlayGamesClient,
        );
        await playGames.signIn();
        final savesBeforePurchases = fakePlayGamesClient.saveCallCount;

        final fakeIapClient = FakeInAppPurchaseClient();
        addTearDown(fakeIapClient.dispose);

        final billing = BillingService(client: fakeIapClient);
        await billing.initialize();

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
          billingService: billing,
        );
        addTearDown(controller.dispose);

        // Purchase 5 items via PurchaseStatus.purchased
        final purchasedIds = [
          BillingService.productResetButton,
          BillingService.productPredictabilityScore,
          BillingService.productRandomButton,
          BillingService.productShowAlgorithm,
          BillingService.productNewHands,
        ];
        for (final id in purchasedIds) {
          final started = await controller.buyWithRealMoney(id);
          expect(started, isTrue);
          fakeIapClient.emitPurchaseUpdate(id, PurchaseStatus.purchased);
          await Future<void>.delayed(Duration.zero);
        }

        // Restore the remaining 5 items via PurchaseStatus.restored
        final restoredIds = [
          BillingService.productYourPrediction,
          BillingService.productPcNextMove,
          BillingService.productSuggestion,
          BillingService.productRemoveAds,
          BillingService.productCrystalBall,
        ];
        final restoreStarted = await controller.restorePurchases();
        expect(restoreStarted, isTrue);
        expect(fakeIapClient.restorePurchasesCallCount, 1);

        for (final id in restoredIds) {
          fakeIapClient.emitPurchaseUpdate(id, PurchaseStatus.restored);
          await Future<void>.delayed(Duration.zero);
        }

        // Elemental Orbs are NOT deducted for real-money purchases/restores
        expect(controller.fireOrbs, 500);
        expect(controller.waterOrbs, 500);
        expect(controller.woodOrbs, 500);
        expect(controller.earthOrbs, 500);
        expect(controller.metalOrbs, 500);
        expect(storage.fireOrbs, 500);

        // All 10 items are unlocked in GameController and persisted in SharedPreferences
        expect(controller.unlockedReset, isTrue);
        expect(storage.unlockedReset, isTrue);
        expect(controller.unlockedPredictability, isTrue);
        expect(storage.unlockedPredictability, isTrue);
        expect(controller.unlockedRandom, isTrue);
        expect(storage.unlockedRandom, isTrue);
        expect(controller.unlockedAlgorithm, isTrue);
        expect(storage.unlockedAlgorithm, isTrue);
        expect(controller.unlockedNewHands, isTrue);
        expect(storage.unlockedNewHands, isTrue);
        expect(controller.unlockedYourPrediction, isTrue);
        expect(storage.unlockedYourPrediction, isTrue);
        expect(controller.unlockedNextMove, isTrue);
        expect(storage.unlockedNextMove, isTrue);
        expect(controller.unlockedSuggestion, isTrue);
        expect(storage.unlockedSuggestion, isTrue);
        expect(controller.unlockedAds, isTrue);
        expect(storage.unlockedAds, isTrue);
        expect(controller.unlockedCrystalBall, isTrue);
        expect(storage.unlockedCrystalBall, isTrue);

        // completePurchase was called for all 10 transactions so Google Play does not refund after 3 days
        expect(fakeIapClient.completedPurchases.length, 10);

        // Cloud save was triggered for each unlocked item
        expect(
          fakePlayGamesClient.saveCallCount,
          greaterThanOrEqualTo(savesBeforePurchases + 10),
        );
      },
    );

    test(
      'Fallback behavior when Google Play Billing is offline/unavailable: no fake prices and graceful handling',
      () async {
        final fakeClient = FakeInAppPurchaseClient(available: false);
        addTearDown(fakeClient.dispose);

        final billing = BillingService(client: fakeClient);
        addTearDown(billing.dispose);

        await billing.initialize();

        expect(billing.isAvailable, isFalse);
        expect(fakeClient.queryProductDetailsCallCount, 0);
        expect(
          billing.getLocalizedPrice(BillingService.productResetButton),
          isNull,
        );

        final buyResult = await billing.buyNonConsumable(
          BillingService.productResetButton,
        );
        expect(buyResult, isFalse);

        final restoreResult = await billing.restorePurchases();
        expect(restoreResult, isFalse);
      },
    );

    testWidgets(
      'ShopDialog displays side-by-side Elemental Orb and Real Money buttons, shows loading indicator and SnackBar feedback on purchase/restore/cancel/error',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'has_seen_story_predictability': true,
          'orbs_fire': 200,
          'orbs_water': 200,
          'orbs_wood': 200,
          'animationsEnabled': false,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeIapClient = FakeInAppPurchaseClient();
        addTearDown(fakeIapClient.dispose);

        final billing = BillingService(client: fakeIapClient);
        await billing.initialize();

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          adService: AdService(),
          billingService: billing,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pump();

        // Open ShopDialog via Sacred Temple on WorldMapScreen, then select Offerings tab
        await tester.tap(find.byKey(const ValueKey('landmark_sacred_temple')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('temple_tab_offerings')));
        await tester.pumpAndSettle();

        final shopScrollable = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Scrollable),
        );

        // Verify side-by-side Elemental Orb and Real Money buttons for Reset Button
        final orbBtn = find.byKey(
          const ValueKey('diamond_unlock_unlock_reset_button'),
        );
        final realMoneyBtn = find.byKey(
          const ValueKey('real_money_unlock_unlock_reset_button'),
        );
        await tester.scrollUntilVisible(
          orbBtn,
          140,
          scrollable: shopScrollable,
        );
        await tester.pumpAndSettle();
        expect(orbBtn, findsOneWidget);
        expect(realMoneyBtn, findsOneWidget);
        expect(
          find.descendant(of: orbBtn, matching: find.text('30')),
          findsNWidgets(3),
        );
        expect(
          find.descendant(of: realMoneyBtn, matching: find.text(r'$0.99')),
          findsOneWidget,
        );

        // Verify Restore Purchases button at the bottom of ShopDialog
        final restoreBtn = find.byKey(
          const ValueKey('shop_restore_purchases_button'),
        );
        expect(restoreBtn, findsOneWidget);
        expect(find.text('Restore Purchases'), findsOneWidget);

        // Tap Real Money button for Predictability Score ($0.99)
        final predRealMoneyBtn = find.byKey(
          const ValueKey('real_money_unlock_unlock_predictability_score'),
        );
        await tester.scrollUntilVisible(
          predRealMoneyBtn,
          -140,
          scrollable: shopScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(predRealMoneyBtn);
        await tester.pump();

        // While pending, loading indicator is shown inside the Real Money button
        expect(
          find.descendant(
            of: predRealMoneyBtn,
            matching: find.byKey(const ValueKey('purchase_loading_indicator')),
          ),
          findsOneWidget,
        );

        // Complete purchase via purchaseStream -> unlocks item, shows SnackBar
        fakeIapClient.emitPurchaseUpdate(
          BillingService.productPredictabilityScore,
          PurchaseStatus.purchased,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(controller.unlockedPredictability, isTrue);
        expect(controller.fireOrbs, 200); // Orbs untouched
        expect(find.text('Predictability Score: Unlocked!'), findsOneWidget);

        // Clear unlock SnackBar before testing cancellation feedback
        ScaffoldMessenger.of(tester.element(find.byType(Dialog))).removeCurrentSnackBar();
        await tester.pump();
        expect(find.text('Predictability Score: Unlocked!'), findsNothing);

        // Test cancellation feedback
        fakeIapClient.emitPurchaseUpdate(
          BillingService.productRandomButton,
          PurchaseStatus.canceled,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Purchase canceled.'), findsOneWidget);

        // Clear cancel SnackBar before testing restore purchases
        ScaffoldMessenger.of(tester.element(find.byType(Dialog))).removeCurrentSnackBar();
        await tester.pump();

        // Test Restore Purchases button
        await tester.tap(restoreBtn);
        await tester.pump();
        fakeIapClient.emitPurchaseUpdate(
          BillingService.productNewHands,
          PurchaseStatus.restored,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(controller.unlockedNewHands, isTrue);
        expect(
          find.text('Unlock Earth & Metal: Restored!'),
          findsOneWidget,
        );
      },
    );

    test(
      'Consumable orb packs call buyConsumable + consumePurchase, grant orbs, and allow repeat purchases',
      () async {
        SharedPreferences.setMockInitialValues({});
        final storage = StorageService();
        await storage.init();
        final fakeClient = FakeInAppPurchaseClient();
        final billing = BillingService(client: fakeClient);
        addTearDown(() {
          billing.dispose();
          fakeClient.dispose();
        });
        await billing.initialize();

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          adService: AdService(),
          billingService: billing,
        );
        addTearDown(controller.dispose);

        expect(BillingService.allConsumableProductIds.length, 8);
        expect(BillingService.allStoreProductIds.length, 18);

        // Purchase small pack twice -> +500 of all 5 elements twice (+1000 each)
        for (int i = 0; i < 2; i++) {
          final started = await controller.buyWithRealMoney(
            BillingService.productConsumableSmall,
          );
          expect(started, isTrue);
          fakeClient.emitPurchaseUpdate(
            BillingService.productConsumableSmall,
            PurchaseStatus.purchased,
          );
          await Future<void>.delayed(Duration.zero);
        }

        expect(fakeClient.buyConsumableCallCount, 2);
        expect(fakeClient.consumedPurchases.length, 2);
        expect(fakeClient.completedPurchases, isEmpty);
        expect(
          billing.isVerifiedPurchased(BillingService.productConsumableSmall),
          isFalse,
        );
        expect(controller.fireOrbs, 1000);
        expect(controller.waterOrbs, 1000);
        expect(controller.woodOrbs, 1000);
        expect(controller.earthOrbs, 1000);
        expect(controller.metalOrbs, 1000);

        // Purchase single-element Fire +1,500 pack -> adds +1500 Fire only
        final startedFire = await controller.buyWithRealMoney(
          BillingService.productConsumableFire1500,
        );
        expect(startedFire, isTrue);
        fakeClient.emitPurchaseUpdate(
          BillingService.productConsumableFire1500,
          PurchaseStatus.purchased,
        );
        await Future<void>.delayed(Duration.zero);

        expect(fakeClient.buyConsumableCallCount, 3);
        expect(fakeClient.consumedPurchases.length, 3);
        expect(controller.fireOrbs, 2500);
        expect(controller.waterOrbs, 1000);
      },
    );
  });
}
