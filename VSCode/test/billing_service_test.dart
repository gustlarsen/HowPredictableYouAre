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
  int restorePurchasesCallCount = 0;
  final List<PurchaseDetails> completedPurchases = [];
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
            description: 'Non-consumable unlock $id',
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
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
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
      'PurchaseStatus.purchased and PurchaseStatus.restored unlock all 10 items in GameController without deducting diamonds, persist to SharedPreferences, trigger cloud save, and call completePurchase',
      () async {
        SharedPreferences.setMockInitialValues({
          'diamonds': 500,
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

        // Diamonds are NOT deducted for real-money purchases/restores
        expect(controller.diamonds, 500);
        expect(storage.diamonds, 500);

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
      'ShopDialog displays side-by-side Diamond and Real Money buttons, shows loading indicator and SnackBar feedback on purchase/restore/cancel/error',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'has_seen_story_predictability': true,
          'diamonds': 200,
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

        // Open ShopDialog
        await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
        await tester.pumpAndSettle();

        // Verify side-by-side Diamond and Real Money buttons for Reset Button
        final diamondBtn = find.byKey(
          const ValueKey('diamond_unlock_unlock_reset_button'),
        );
        final realMoneyBtn = find.byKey(
          const ValueKey('real_money_unlock_unlock_reset_button'),
        );
        expect(diamondBtn, findsOneWidget);
        expect(realMoneyBtn, findsOneWidget);
        expect(
          find.descendant(of: diamondBtn, matching: find.text('100 💎')),
          findsOneWidget,
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
        expect(controller.diamonds, 200); // Diamonds untouched
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
          find.text('New Hands (Lizard & Spock): Restored!'),
          findsOneWidget,
        );
      },
    );
  });
}
