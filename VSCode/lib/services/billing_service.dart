import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../models/move.dart';

/// Types of purchase lifecycle events emitted by [BillingService].
enum BillingEventType {
  pending,
  purchased,
  restored,
  canceled,
  error,
}

/// Represents a purchase or restore update for UI feedback (e.g., SnackBars).
class BillingPurchaseEvent {
  final String productId;
  final BillingEventType type;
  final String? message;

  const BillingPurchaseEvent({
    required this.productId,
    required this.type,
    this.message,
  });
}

/// Abstraction over [InAppPurchase] so that [BillingService] uses the official
/// `in_app_purchase` SDK (`InAppPurchase.instance`) in production while
/// remaining deterministically testable in unit and widget tests.
abstract class InAppPurchaseClient {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  });
  Future<void> consumePurchase(PurchaseDetails purchase);
  Future<void> completePurchase(PurchaseDetails purchase);
  Future<void> restorePurchases({String? applicationUserName});
}

/// Default production implementation of [InAppPurchaseClient] backed by
/// [InAppPurchase.instance].
class DefaultInAppPurchaseClient implements InAppPurchaseClient {
  InAppPurchase? _iap;

  DefaultInAppPurchaseClient({InAppPurchase? iap}) : _iap = iap;

  InAppPurchase get _instance => _iap ??= InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _instance.purchaseStream;

  @override
  Future<bool> isAvailable() => _instance.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _instance.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _instance.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) =>
      _instance.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: autoConsume,
      );

  @override
  Future<void> consumePurchase(PurchaseDetails purchase) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidAddition =
          _instance.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      await androidAddition.consumePurchase(purchase);
    } else if (purchase.pendingCompletePurchase) {
      await _instance.completePurchase(purchase);
    }
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _instance.completePurchase(purchase);

  @override
  Future<void> restorePurchases({String? applicationUserName}) =>
      _instance.restorePurchases(applicationUserName: applicationUserName);
}

/// Manages Google Play Billing (In-App Purchases) for all 10 non-consumable
/// shop upgrades and 8 consumable Elemental Orb packs, including localized price
/// queries, purchase stream handling, immediate entitlement granting,
/// consumption/acknowledgment, and purchase restoration.
class BillingService extends ChangeNotifier {
  static const String productResetButton = 'unlock_reset_button';
  static const String productPredictabilityScore =
      'unlock_predictability_score';
  static const String productRandomButton = 'unlock_random_button';
  static const String productShowAlgorithm = 'unlock_show_algorithm';
  static const String productNewHands = 'unlock_new_hands';
  static const String productYourPrediction = 'unlock_your_prediction';
  static const String productPcNextMove = 'unlock_pc_next_move';
  static const String productSuggestion = 'unlock_suggestion';
  static const String productRemoveAds = 'unlock_remove_ads';
  static const String productCrystalBall = 'unlock_crystal_ball';

  // Consumable All-Element Orb Bundles
  static const String productConsumableSmall = 'consumable_orbs_pack_small';
  static const String productConsumableMedium = 'consumable_orbs_pack_medium';
  static const String productConsumableLarge = 'consumable_orbs_pack_large';

  // Consumable Single-Element Bulk Packs (+1,500)
  static const String productConsumableFire1500 = 'consumable_orbs_fire_1500';
  static const String productConsumableWater1500 =
      'consumable_orbs_water_1500';
  static const String productConsumableWood1500 = 'consumable_orbs_wood_1500';
  static const String productConsumableEarth1500 =
      'consumable_orbs_earth_1500';
  static const String productConsumableMetal1500 =
      'consumable_orbs_metal_1500';

  /// Exact set of all 10 non-consumable Google Play Product IDs.
  static const Set<String> allProductIds = {
    productResetButton,
    productPredictabilityScore,
    productRandomButton,
    productShowAlgorithm,
    productNewHands,
    productYourPrediction,
    productPcNextMove,
    productSuggestion,
    productRemoveAds,
    productCrystalBall,
  };

  /// Exact set of all 8 consumable Elemental Orb pack Google Play Product IDs.
  static const Set<String> allConsumableProductIds = {
    productConsumableSmall,
    productConsumableMedium,
    productConsumableLarge,
    productConsumableFire1500,
    productConsumableWater1500,
    productConsumableWood1500,
    productConsumableEarth1500,
    productConsumableMetal1500,
  };

  /// Combined set of all 18 store Product IDs (non-consumables + consumables).
  static const Set<String> allStoreProductIds = {
    productResetButton,
    productPredictabilityScore,
    productRandomButton,
    productShowAlgorithm,
    productNewHands,
    productYourPrediction,
    productPcNextMove,
    productSuggestion,
    productRemoveAds,
    productCrystalBall,
    productConsumableSmall,
    productConsumableMedium,
    productConsumableLarge,
    productConsumableFire1500,
    productConsumableWater1500,
    productConsumableWood1500,
    productConsumableEarth1500,
    productConsumableMetal1500,
  };

  static bool isConsumableProduct(String productId) =>
      allConsumableProductIds.contains(productId);

  static String consumableProductIdForMove(HandMove move) {
    switch (move) {
      case HandMove.rock:
        return productConsumableFire1500;
      case HandMove.paper:
        return productConsumableWater1500;
      case HandMove.scissors:
        return productConsumableWood1500;
      case HandMove.lizard:
        return productConsumableEarth1500;
      case HandMove.spock:
        return productConsumableMetal1500;
    }
  }

  /// Canonical mapping of the 10 shop item names to their Google Play Product IDs.
  static const Map<String, String> shopItemProductIds = {
    'Reset Button': productResetButton,
    'Predictability Score': productPredictabilityScore,
    'Random Button': productRandomButton,
    'Show Algorithm': productShowAlgorithm,
    'New Hands': productNewHands,
    'Your Prediction': productYourPrediction,
    'PC Next Move': productPcNextMove,
    'Sugestion': productSuggestion,
    'Remove Ads': productRemoveAds,
    'Crystal Ball': productCrystalBall,
  };

  /// Resolves the Google Play Product ID for a given shop item label.
  static String? productIdForShopItem(String itemName) {
    final trimmed = itemName.trim();
    if (shopItemProductIds.containsKey(trimmed)) {
      return shopItemProductIds[trimmed];
    }
    if (trimmed == 'Unlock Earth & Metal') {
      return productNewHands;
    }
    if (trimmed == 'Suggestion') {
      return productSuggestion;
    }
    return null;
  }

  final InAppPurchaseClient _client;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _isAvailable = false;
  bool _isLoadingProducts = false;
  bool _isRestoring = false;
  final Map<String, ProductDetails> _productsById = {};
  final Set<String> _pendingProductIds = {};
  final Set<String> _verifiedPurchasedProductIds = {};
  final List<void Function(BillingPurchaseEvent)> _eventListeners = [];

  /// Invoked immediately whenever a purchase has status [PurchaseStatus.purchased]
  /// or [PurchaseStatus.restored] so [GameController] unlocks and persists the item.
  FutureOr<void> Function(String productId, PurchaseStatus status)?
      onEntitlementGranted;

  BillingService({
    InAppPurchaseClient? client,
    this.onEntitlementGranted,
  }) : _client = client ?? DefaultInAppPurchaseClient();

  bool get isAvailable => _isAvailable;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isRestoring => _isRestoring;
  bool get hasPendingPurchase => _pendingProductIds.isNotEmpty;

  Map<String, ProductDetails> get productsById =>
      Map.unmodifiable(_productsById);

  Set<String> get pendingProductIds => Set.unmodifiable(_pendingProductIds);

  Set<String> get verifiedPurchasedProductIds =>
      Set.unmodifiable(_verifiedPurchasedProductIds);

  bool isVerifiedPurchased(String productId) =>
      _verifiedPurchasedProductIds.contains(productId);

  bool isPurchasePending(String productId) =>
      _pendingProductIds.contains(productId);

  /// Returns the queried [ProductDetails] for [productId], or `null` if unavailable.
  ProductDetails? getProductDetails(String productId) =>
      _productsById[productId];

  /// Returns the localized store price (e.g., `$0.99`, `R$ 4,90`) fetched from
  /// Google Play for [productId], or `null` when Google Play Billing is offline
  /// or the product details have not been loaded.
  String? getLocalizedPrice(String productId) =>
      _productsById[productId]?.price;

  void addEventListener(void Function(BillingPurchaseEvent) listener) {
    if (!_eventListeners.contains(listener)) {
      _eventListeners.add(listener);
    }
  }

  void removeEventListener(void Function(BillingPurchaseEvent) listener) {
    _eventListeners.remove(listener);
  }

  void _emitEvent(BillingPurchaseEvent event) {
    for (final listener in List<void Function(BillingPurchaseEvent)>.from(
      _eventListeners,
    )) {
      listener(event);
    }
  }

  /// Initializes the Google Play Billing connection on app startup, subscribes
  /// to [InAppPurchase.purchaseStream], and queries localized product details
  /// for all 10 non-consumable shop items.
  Future<void> initialize() async {
    _purchaseSubscription ??= _client.purchaseStream.listen(
      (purchases) {
        unawaited(_handlePurchaseUpdates(purchases));
      },
      onError: (Object error) {
        _isRestoring = false;
        _pendingProductIds.clear();
        _emitEvent(
          BillingPurchaseEvent(
            productId: '',
            type: BillingEventType.error,
            message: error.toString(),
          ),
        );
        notifyListeners();
      },
    );

    try {
      final available = await _client.isAvailable();
      _isAvailable = available;
      if (!available) {
        _isLoadingProducts = false;
        notifyListeners();
        return;
      }
      notifyListeners();
      await queryProductDetails();
    } catch (_) {
      _isAvailable = false;
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  /// Queries Google Play Billing for all store product details
  /// (non-consumables + consumable orb packs) and caches their localized store prices.
  Future<ProductDetailsResponse?> queryProductDetails([
    Set<String> productIds = allStoreProductIds,
  ]) async {
    if (!_isAvailable) {
      return null;
    }

    _isLoadingProducts = true;
    notifyListeners();

    try {
      final response = await _client.queryProductDetails(productIds);
      if (response.error == null) {
        for (final detail in response.productDetails) {
          _productsById[detail.id] = detail;
        }
      }
      _isLoadingProducts = false;
      notifyListeners();
      return response;
    } catch (_) {
      _isLoadingProducts = false;
      notifyListeners();
      return null;
    }
  }

  /// Initiates a Google Play Billing non-consumable purchase flow for [productId].
  Future<bool> buyNonConsumable(String productId) async {
    return _startPurchaseFlow(productId, isConsumable: false);
  }

  /// Initiates a Google Play Billing consumable purchase flow for [productId]
  /// (used for repeatable Elemental Orb bundles in the Adoration Room).
  Future<bool> buyConsumable(String productId) async {
    return _startPurchaseFlow(productId, isConsumable: true);
  }

  Future<bool> _startPurchaseFlow(
    String productId, {
    required bool isConsumable,
  }) async {
    if (!_isAvailable) {
      _emitEvent(
        BillingPurchaseEvent(
          productId: productId,
          type: BillingEventType.error,
          message: 'Google Play Billing is currently unavailable.',
        ),
      );
      notifyListeners();
      return false;
    }

    final productDetails = _productsById[productId];
    if (productDetails == null) {
      _emitEvent(
        BillingPurchaseEvent(
          productId: productId,
          type: BillingEventType.error,
          message: 'Product details unavailable in Google Play Store.',
        ),
      );
      notifyListeners();
      return false;
    }

    _pendingProductIds.add(productId);
    notifyListeners();

    try {
      final purchaseParam = PurchaseParam(productDetails: productDetails);
      final started = isConsumable
          ? await _client.buyConsumable(
              purchaseParam: purchaseParam,
              autoConsume: false,
            )
          : await _client.buyNonConsumable(purchaseParam: purchaseParam);
      if (!started) {
        _pendingProductIds.remove(productId);
        _emitEvent(
          BillingPurchaseEvent(
            productId: productId,
            type: BillingEventType.error,
            message: 'Unable to start purchase flow.',
          ),
        );
        notifyListeners();
      }
      return started;
    } catch (_) {
      _pendingProductIds.remove(productId);
      _emitEvent(
        BillingPurchaseEvent(
          productId: productId,
          type: BillingEventType.error,
          message: 'Purchase failed to start.',
        ),
      );
      notifyListeners();
      return false;
    }
  }

  /// Restores previously purchased non-consumable items from Google Play
  /// so players who reinstall the app or switch devices recover their items.
  Future<bool> restorePurchases() async {
    if (!_isAvailable) {
      _emitEvent(
        const BillingPurchaseEvent(
          productId: '',
          type: BillingEventType.error,
          message: 'Google Play Billing is currently unavailable.',
        ),
      );
      notifyListeners();
      return false;
    }

    _isRestoring = true;
    notifyListeners();

    try {
      await _client.restorePurchases();
      _isRestoring = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isRestoring = false;
      _emitEvent(
        const BillingPurchaseEvent(
          productId: '',
          type: BillingEventType.error,
          message: 'Failed to restore purchases.',
        ),
      );
      notifyListeners();
      return false;
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      final productId = purchase.productID;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _pendingProductIds.add(productId);
          _emitEvent(
            BillingPurchaseEvent(
              productId: productId,
              type: BillingEventType.pending,
            ),
          );
          notifyListeners();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _pendingProductIds.remove(productId);
          _isRestoring = false;
          final isConsumable = isConsumableProduct(productId);
          if (!isConsumable) {
            _verifiedPurchasedProductIds.add(productId);
          }

          // Immediately grant entitlement in GameController (persisting to
          // SharedPreferences and triggering PlayGamesService cloud save).
          await onEntitlementGranted?.call(productId, purchase.status);

          // CRITICAL: Consume repeatable orb packs (which also acknowledges them
          // and allows repurchasing) or acknowledge/complete non-consumables so
          // Google Play does not refund the transaction after 3 days.
          if (isConsumable) {
            try {
              await _client.consumePurchase(purchase);
            } catch (_) {}
          } else {
            try {
              await _client.completePurchase(purchase);
            } catch (_) {}
          }

          _emitEvent(
            BillingPurchaseEvent(
              productId: productId,
              type: purchase.status == PurchaseStatus.restored
                  ? BillingEventType.restored
                  : BillingEventType.purchased,
            ),
          );
          notifyListeners();
          break;

        case PurchaseStatus.canceled:
          _pendingProductIds.remove(productId);
          _isRestoring = false;
          if (purchase.pendingCompletePurchase) {
            try {
              await _client.completePurchase(purchase);
            } catch (_) {}
          }
          _emitEvent(
            BillingPurchaseEvent(
              productId: productId,
              type: BillingEventType.canceled,
              message: 'Purchase canceled.',
            ),
          );
          notifyListeners();
          break;

        case PurchaseStatus.error:
          _pendingProductIds.remove(productId);
          _isRestoring = false;
          if (purchase.pendingCompletePurchase) {
            try {
              await _client.completePurchase(purchase);
            } catch (_) {}
          }
          _emitEvent(
            BillingPurchaseEvent(
              productId: productId,
              type: BillingEventType.error,
              message: purchase.error?.message.isNotEmpty == true
                  ? purchase.error!.message
                  : 'Purchase failed.',
            ),
          );
          notifyListeners();
          break;
      }
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _eventListeners.clear();
    super.dispose();
  }
}
