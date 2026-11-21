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
import 'package:how_predictable/models/sacred_blessing.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/billing_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/widgets/temple_wing_icons.dart';

class _TempleAdMobClient implements AdMobClient {
  bool shouldEarnRewardOnShow;
  int loadRewardedCallCount = 0;
  int showRewardedCallCount = 0;

  _TempleAdMobClient({this.shouldEarnRewardOnShow = true});

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
  Widget? buildBannerWidget() => const SizedBox(height: 50);

  @override
  void disposeBanner() {}

  @override
  Future<void> loadRewarded({
    required String adUnitId,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    loadRewardedCallCount++;
    onLoaded();
  }

  @override
  Future<bool> showRewarded({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onDismissed,
    required VoidCallback onFailedToShow,
  }) async {
    showRewardedCallCount++;
    if (shouldEarnRewardOnShow) {
      onUserEarnedReward();
    }
    onDismissed();
    return true;
  }

  @override
  void disposeRewarded() {}
}

class _TempleBillingClient implements InAppPurchaseClient {
  final StreamController<List<PurchaseDetails>> _purchaseController =
      StreamController<List<PurchaseDetails>>.broadcast();
  bool available;
  int buyConsumableCallCount = 0;
  final List<PurchaseDetails> consumedPurchases = [];
  final Map<String, String> prices;

  _TempleBillingClient({
    this.available = true,
    Map<String, String>? prices,
  }) : prices = prices ??
            {
              for (final id in BillingService.allProductIds) id: r'$0.99',
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
      _purchaseController.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    if (!available) {
      return ProductDetailsResponse(
        productDetails: const [],
        notFoundIDs: identifiers.toList(),
      );
    }
    final found = <ProductDetails>[];
    final notFound = <String>[];
    for (final id in identifiers) {
      final p = prices[id];
      if (p != null) {
        found.add(
          ProductDetails(
            id: id,
            title: id,
            description: 'Sacred pack $id',
            price: p,
            rawPrice: 1.99,
            currencyCode: 'USD',
          ),
        );
      } else {
        notFound.add(id);
      }
    }
    return ProductDetailsResponse(
      productDetails: found,
      notFoundIDs: notFound,
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    buyConsumableCallCount++;
    _purchaseController.add([
      PurchaseDetails(
        purchaseID: 'temple_order_$buyConsumableCallCount',
        productID: purchaseParam.productDetails.id,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'local_${purchaseParam.productDetails.id}',
          serverVerificationData: 'server_${purchaseParam.productDetails.id}',
          source: 'google_play',
        ),
        transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
        status: PurchaseStatus.purchased,
      )..pendingCompletePurchase = true,
    ]);
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> consumePurchase(PurchaseDetails purchase) async {
    consumedPurchases.add(purchase);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}

  void dispose() {
    _purchaseController.close();
  }
}

Future<({
  GameController controller,
  _TempleAdMobClient adClient,
  _TempleBillingClient billingClient,
})> _createTempleHarness({
  Map<String, Object> prefs = const {},
  bool storeAvailable = true,
  bool shouldEarnRewardOnShow = true,
  String language = 'en',
}) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_story_intro': true,
    'animationsEnabled': false,
    'musicEnabled': false,
    'current_week': 1,
    'language': language,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();
  final localization = LocalizationService();
  await localization.load();
  localization.setLanguage(language);

  final adClient = _TempleAdMobClient(
    shouldEarnRewardOnShow: shouldEarnRewardOnShow,
  );
  final adService = AdService(client: adClient);
  await adService.initialize();

  final billingClient = _TempleBillingClient(available: storeAvailable);
  final billingService = BillingService(client: billingClient);
  await billingService.initialize();

  final controller = GameController(
    storage: storage,
    localization: localization,
    audio: AudioService(),
    adService: adService,
    billingService: billingService,
  );
  return (
    controller: controller,
    adClient: adClient,
    billingClient: billingClient,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sacred Temple 5-Tab Hub (SacredTempleDialog / ShopDialog)', () {
    testWidgets(
      'Renders single-row 5 vertical tab pills, persistent 5-orb balance bar, gold active styling, and zero overflow across en/pt/es/de and Dark/Light modes',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createTempleHarness(
          prefs: {
            'orbs_fire': 15,
            'orbs_water': 20,
            'orbs_wood': 25,
            'orbs_earth': 5,
            'orbs_metal': 8,
          },
        );
        final controller = harness.controller;
        addTearDown(() {
          controller.dispose();
          harness.billingClient.dispose();
        });

        for (final isDark in [true, false]) {
          controller.darkMode = isDark;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: SacredTempleDialog(
                  key: ValueKey('temple_theme_$isDark'),
                  controller: controller,
                  fromTemple: true,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Single-row 5 vertical tab pills
          const tabKeys = [
            ValueKey('temple_tab_consagration'),
            ValueKey('temple_tab_offerings'),
            ValueKey('temple_tab_transmute'),
            ValueKey('temple_tab_adoration'),
            ValueKey('temple_tab_prayer'),
          ];
          final firstTop = tester.getTopLeft(find.byKey(tabKeys.first)).dy;
          for (final key in tabKeys) {
            expect(find.byKey(key), findsOneWidget);
            expect(
              tester.getTopLeft(find.byKey(key)).dy,
              closeTo(firstTop, 1.0),
            );
            expect(
              tester.getBottomRight(find.byKey(key)).dx,
              lessThanOrEqualTo(360),
            );
          }

          // Active tab has solid gold (#F5C22B) fill and #1E1B16 dark charcoal text
          final activeLabel = tester.widget<Text>(find.text('Consagration'));
          expect(activeLabel.style?.color, const Color(0xFF1E1B16));

          // Navigate every wing and ensure persistent 5-orb bar stays visible
          for (int i = 0; i < tabKeys.length; i++) {
            await tester.tap(find.byKey(tabKeys[i]));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(const ValueKey('shop_orb_summary_bar')),
              findsOneWidget,
            );
          }
        }

        // Verify all 4 localizations render tabs and titles without key fallbacks
        const expectedTabNames = {
          'en': 'Transformation',
          'pt': 'Transformação',
          'es': 'Transformación',
          'de': 'Verwandlung',
        };
        const expectedTitles = {
          'en': 'Holy Transformation',
          'pt': 'Transformação Sagrada',
          'es': 'Transformación Sagrada',
          'de': 'Heilige Verwandlung',
        };
        for (final lang in LocalizationService.supportedLanguages) {
          controller.setLanguage(lang);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('sacred_temple_tab_bar')),
            findsOneWidget,
          );
          for (final tabKey in [
            'temple_tab_consagration',
            'temple_tab_offerings',
            'temple_tab_transmute',
            'temple_tab_adoration',
            'temple_tab_prayer',
          ]) {
            expect(controller.localization.t(tabKey), isNot(tabKey));
          }
          expect(
            controller.localization.t('temple_tab_transmute'),
            expectedTabNames[lang],
          );
          expect(
            controller.localization.t('temple_transmute_title'),
            expectedTitles[lang],
          );
          expect(find.text(expectedTabNames[lang]!), findsOneWidget);
        }
      },
    );

    testWidgets(
      'Wing 1 Consagration Room supports Orb upgrades and Watch Ad +1 Lv with weekly cap 3/3 (resetting on week advance), while Offerings shows artifacts only',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createTempleHarness(
          prefs: {'orbs_fire': 20, 'orbs_water': 20, 'orbs_wood': 20},
        );
        final controller = harness.controller;
        addTearDown(() {
          controller.dispose();
          harness.billingClient.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: SacredTempleDialog(
                controller: controller,
                initialWing: TempleWing.consagration,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('3 / 3 Ad Lv/Wk'), findsOneWidget);
        expect(find.text('Lv. 0 • 50 → 51 HP'), findsOneWidget);
        expect(find.text('Lv. 0 • 100 → 101 MANA'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('consagration_ad_disclosure_box')),
          findsOneWidget,
        );

        // Early dismissal grants 0 levels and consumes 0 weekly cap
        harness.adClient.shouldEarnRewardOnShow = false;
        await tester.tap(
          find.byKey(const ValueKey('consagration_hp_watch_ad_button')),
        );
        await tester.pumpAndSettle();
        expect(controller.hpUpgradeLevel, 0);
        expect(controller.adConsagrationsThisWeek, 0);

        // Earn 2 HP ad consagrations + 1 Mana ad consagration -> hits 3/3 weekly cap
        harness.adClient.shouldEarnRewardOnShow = true;
        await tester.tap(
          find.byKey(const ValueKey('consagration_hp_watch_ad_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('consagration_hp_watch_ad_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('consagration_mana_watch_ad_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.hpUpgradeLevel, 2);
        expect(controller.playerMaxHp, 52);
        expect(controller.manaUpgradeLevel, 1);
        expect(controller.playerMaxMana, 101);
        expect(controller.remainingWeeklyAdConsagrations, 0);
        expect(find.text('0 / 3 Ad Lv/Wk'), findsOneWidget);
        expect(find.text('Weekly Cap (3/3)'), findsNWidgets(2));

        // 4th ad tap does nothing because button is disabled
        final hpAdBtn = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('consagration_hp_watch_ad_button')),
        );
        expect(hpAdBtn.onPressed, isNull);

        // Orb upgrade still works independently of weekly ad cap
        await tester.tap(
          find.byKey(const ValueKey('shop_upgrade_max_hp_button')),
        );
        await tester.pumpAndSettle();
        expect(controller.hpUpgradeLevel, 3);
        expect(controller.playerMaxHp, 53);

        // Advancing campaign week resets weekly ad cap to 3/3
        controller.completeBattleWeek();
        await tester.pumpAndSettle();
        expect(controller.adConsagrationsThisWeek, 0);
        expect(controller.remainingWeeklyAdConsagrations, 3);

        // Switch to Wing 2: Offerings -> strictly artifacts, no HP/Mana/Free Orbs card
        await tester.tap(find.byKey(const ValueKey('temple_tab_offerings')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('temple_wing_offerings')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('shop_upgrade_max_hp_card')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('shop_upgrade_max_mana_card')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('shop_rewarded_ad_card')),
          findsNothing,
        );
        expect(find.text('Predictability Score'), findsOneWidget);
      },
    );

    testWidgets(
      'Wing 3 Holy Transformation supports 1x/10x/100x/MAX batch exchange, press-and-hold rapid exchange, and zero label truncation on 360dp',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createTempleHarness(
          prefs: {
            'orbs_fire': 600,
            'orbs_water': 10,
            'orbs_wood': 40,
            'orbs_earth': 2,
            'orbs_metal': 0,
          },
        );
        final controller = harness.controller;
        addTearDown(() {
          controller.dispose();
          harness.billingClient.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: SacredTempleDialog(
                controller: controller,
                initialWing: TempleWing.transmute,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Transformation labels & non-truncated 3 -> 1 Exchange header on 360dp
        expect(find.text('Transformation'), findsOneWidget);
        expect(find.text('Holy Transformation'), findsOneWidget);
        expect(
          find.text(
            'Transform 3 surplus Elemental Orbs of one element into 1 Elemental Orb of another.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Tip: Press & hold Exchange for rapid transformation.'),
          findsOneWidget,
        );
        final exchangeRateFinder = find.text('3 → 1 Exchange');
        final tapHintFinder = find.text('Tap orbs to switch');
        expect(exchangeRateFinder, findsOneWidget);
        expect(tapHintFinder, findsOneWidget);
        final exchangeTextWidget = tester.widget<Text>(exchangeRateFinder);
        expect(exchangeTextWidget.overflow, isNot(TextOverflow.ellipsis));
        expect(
          tester.getTopRight(exchangeRateFinder).dx,
          lessThan(tester.getTopLeft(tapHintFinder).dx),
        );
        expect(tester.takeException(), isNull);

        // All 4 batch pills fit on a single row inside 360dp
        for (final keyName in const [
          'alchemy_multiplier_1x',
          'alchemy_multiplier_10x',
          'alchemy_multiplier_100x',
          'alchemy_multiplier_max',
        ]) {
          expect(find.byKey(ValueKey(keyName)), findsOneWidget);
          expect(
            tester.getBottomRight(find.byKey(ValueKey(keyName))).dx,
            lessThanOrEqualTo(360),
          );
        }

        // Execute 100x trade: 600 Fire -> 300 Fire, 10 Water -> 110 Water
        await tester.tap(find.byKey(const ValueKey('alchemy_multiplier_100x')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('alchemy_transmute_button')));
        await tester.pumpAndSettle();
        expect(controller.fireOrbs, 300);
        expect(controller.waterOrbs, 110);
        expect(
          find.byKey(const ValueKey('alchemy_confirmation_badge')),
          findsOneWidget,
        );
        expect(find.text('-300 Fire ➔ +100 Water'), findsOneWidget);

        // Select 1x and hold the Exchange button to trigger rapid press-and-hold trades
        await tester.tap(find.byKey(const ValueKey('alchemy_multiplier_1x')));
        await tester.pumpAndSettle();

        final holdBtn = find.byKey(const ValueKey('alchemy_transmute_button'));
        final gesture = await tester.startGesture(tester.getCenter(holdBtn));
        await tester.pump(const Duration(milliseconds: 700));
        await gesture.up();
        await tester.pumpAndSettle();

        // Single tap on up + multiple rapid hold ticks (> 1 exchange total)
        expect(controller.fireOrbs, lessThan(297));
        expect(controller.waterOrbs, greaterThan(111));
      },
    );

    testWidgets(
      'Wing 4 Adoration Room sells all-element & single-element consumable orb packs with repeat consumption and offline fallback',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createTempleHarness();
        final controller = harness.controller;
        addTearDown(() {
          controller.dispose();
          harness.billingClient.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: Scaffold(
              body: SacredTempleDialog(
                controller: controller,
                initialWing: TempleWing.adoration,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Blessing Pouch'), findsOneWidget);
        expect(find.text('Sacred Reliquary'), findsOneWidget);
        expect(find.text('Divine Abundance'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('adoration_store_unavailable_banner')),
          findsNothing,
        );

        // Purchase Blessing Pouch (+500 all 5 orbs)
        await tester.tap(
          find.byKey(
            const ValueKey(
              'real_money_unlock_${BillingService.productConsumableSmall}',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(controller.fireOrbs, 500);
        expect(controller.waterOrbs, 500);
        expect(controller.woodOrbs, 500);
        expect(controller.earthOrbs, 500);
        expect(controller.metalOrbs, 500);
        expect(harness.billingClient.consumedPurchases.length, 1);

        // Scroll down and select Earth (+1,500) single-element bulk pack and buy twice
        final scrollable = find.descendant(
          of: find.byType(SacredTempleDialog),
          matching: find.byType(Scrollable),
        );
        final earthChip = find.byKey(
          const ValueKey('adoration_element_selector_earth'),
        );
        await tester.scrollUntilVisible(
          earthChip,
          160,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(earthChip);
        await tester.pumpAndSettle();
        expect(find.text('+1,500 Earth Orb'), findsOneWidget);

        final earthBuyBtn = find.byKey(
          const ValueKey(
            'real_money_unlock_${BillingService.productConsumableEarth1500}',
          ),
        );
        await tester.ensureVisible(earthBuyBtn);
        await tester.pumpAndSettle();
        await tester.tap(earthBuyBtn);
        await tester.pumpAndSettle();
        await tester.tap(earthBuyBtn);
        await tester.pumpAndSettle();

        expect(controller.earthOrbs, 3500);
        expect(controller.fireOrbs, 500);
        expect(harness.billingClient.consumedPurchases.length, 3);

        // Offline Google Play Billing -> graceful notice and Unavailable buttons (no fake prices)
        final offlineHarness = await _createTempleHarness(storeAvailable: false);
        addTearDown(() {
          offlineHarness.controller.dispose();
          offlineHarness.billingClient.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SacredTempleDialog(
                key: const ValueKey('adoration_offline'),
                controller: offlineHarness.controller,
                initialWing: TempleWing.adoration,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('adoration_store_unavailable_banner')),
          findsOneWidget,
        );
        expect(find.text('Unavailable'), findsWidgets);
        expect(find.text(r'$1.99'), findsNothing);
      },
    );

    testWidgets(
      'Wing 5 Prayer Room handles Free Daily Prayer, Ad Blessings, Remove Ads Perk, and applies Vitality/Clairvoyance/Harvest in battle',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createTempleHarness(
          prefs: {'current_week': 12},
        );
        final controller = harness.controller;
        addTearDown(() {
          controller.dispose();
          harness.billingClient.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: SacredTempleDialog(
                controller: controller,
                initialWing: TempleWing.prayer,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Phase 2+ Free Orbs card is shown alongside Sacred Blessings
        expect(
          find.byKey(const ValueKey('shop_rewarded_ad_card')),
          findsOneWidget,
        );
        expect(find.text('Pray (Free)'), findsNWidgets(2));
        final prayerScrollable = find.descendant(
          of: find.byType(SacredTempleDialog),
          matching: find.byType(Scrollable),
        );
        final harvestCard = find.byKey(
          const ValueKey('temple_blessing_card_harvest'),
        );
        await tester.scrollUntilVisible(
          harvestCard,
          120,
          scrollable: prayerScrollable,
        );
        await tester.pumpAndSettle();
        expect(harvestCard, findsOneWidget);
        expect(
          find.descendant(of: harvestCard, matching: find.text('Pray (Free)')),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('temple_blessing_pray_button_vitality')),
        );
        await tester.pumpAndSettle();

        // 1. Activate Blessing of Vitality via 1 Free Daily Prayer (no ad shown)
        await tester.tap(
          find.byKey(const ValueKey('temple_blessing_pray_button_vitality')),
        );
        await tester.pumpAndSettle();
        expect(controller.pendingBattleBlessing, SacredBlessing.vitality);
        expect(harness.adClient.showRewardedCallCount, 0);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Watch Ad: Pray'), findsNWidgets(2));

        // While Vitality is pending, mutual exclusion prevents activating Clairvoyance
        final blockedBtn = tester.widget<ElevatedButton>(
          find.byKey(
            const ValueKey('temple_blessing_pray_button_clairvoyance'),
          ),
        );
        expect(blockedBtn.onPressed, isNull);

        // 2. Start Battle 1 -> Vitality grants +15 Temp HP & GameScreen HUD pill, freeing pending slot
        controller.startNewBattle();
        expect(controller.activeBattleBlessing, SacredBlessing.vitality);
        expect(controller.pendingBattleBlessing, isNull);
        expect(controller.effectivePlayerMaxHp, 65);
        expect(controller.userHp, 65);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(home: GameScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('battle_sacred_blessing_pill_vitality')),
          findsOneWidget,
        );

        // 3. Re-open Prayer Room (daily free used, pending null) -> activate Clairvoyance via Watch Ad: Pray
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: SacredTempleDialog(
                key: const ValueKey('prayer_ad_reopen'),
                controller: controller,
                initialWing: TempleWing.prayer,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final clairvoyanceBtn = find.byKey(
          const ValueKey('temple_blessing_pray_button_clairvoyance'),
        );
        await tester.scrollUntilVisible(
          clairvoyanceBtn,
          120,
          scrollable: find.descendant(
            of: find.byType(SacredTempleDialog),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(clairvoyanceBtn);
        await tester.pumpAndSettle();
        expect(harness.adClient.showRewardedCallCount, 1);
        expect(controller.pendingBattleBlessing, SacredBlessing.clairvoyance);

        // Start Battle 2 -> Clairvoyance reveals enemy's first 3 moves in GameScreen
        controller.startNewBattle();
        expect(controller.activeBattleBlessing, SacredBlessing.clairvoyance);
        expect(controller.pendingBattleBlessing, isNull);
        expect(controller.effectivePlayerMaxHp, 50);
        expect(controller.isClairvoyanceActive, isTrue);
        expect(controller.clairvoyanceMovesRemaining, 3);
        final predictedTurn1 = controller.crystalBallMove!;

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(home: GameScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('battle_sacred_blessing_pill_clairvoyance')),
          findsOneWidget,
        );

        // Play 3 rounds -> Clairvoyance stays active for moves 1..3, expires at move 4
        controller.playTurn(predictedTurn1);
        expect(controller.clairvoyanceMovesRemaining, 2);
        controller.playTurn(HandMove.rock);
        expect(controller.clairvoyanceMovesRemaining, 1);
        controller.playTurn(HandMove.paper);
        expect(controller.clairvoyanceMovesRemaining, 0);
        expect(controller.isClairvoyanceActive, isFalse);

        // 4. Battle effect for Harvest (2x Elemental Orbs on round win) + Remove Ads Perk
        controller.unlockedAds = true;
        controller.removeAdsEnabled = true;
        expect(controller.canActivateSacredBlessingFree(), isTrue);
        expect(
          controller.activateSacredBlessingFree(SacredBlessing.harvest),
          isTrue,
        );
        controller.startNewBattle();
        expect(controller.isHarvestBlessingActive, isTrue);
        expect(controller.effectivePlayerMaxHp, 50);

        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('battle_sacred_blessing_pill_harvest')),
          findsOneWidget,
        );

        final woodBefore = controller.woodOrbs;
        // Fire (rock) beats Wood (scissors); grants 2x Wood orbs of the defeated enemy element
        controller.crystalBallMove = HandMove.scissors;
        controller.playTurn(HandMove.rock);
        expect(controller.lastWinner, RoundWinner.user);
        expect(controller.woodOrbs - woodBefore, 2);
      },
    );

    testWidgets(
      'All 5 Sacred Temple tabs, header emblem, and internal section headers render bespoke CustomPainter RPG icons cleanly in both Dark Mode and Light Mode',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 1. Standalone smoke checks across all 14 Sacred Temple vector painters
        final allPainters = <Widget>[
          const ConsagrationChaliceIcon(size: 28, isOnGoldBackground: false),
          const ConsagrationChaliceIcon(size: 28, isOnGoldBackground: true),
          const OfferingsAltarIcon(size: 28, isOnGoldBackground: false),
          const OfferingsAltarIcon(size: 28, isOnGoldBackground: true),
          const HolyTransformationIcon(size: 28, isOnGoldBackground: false),
          const HolyTransformationIcon(size: 28, isOnGoldBackground: true),
          const AdorationHarpIcon(size: 28, isOnGoldBackground: false),
          const AdorationHarpIcon(size: 28, isOnGoldBackground: true),
          const PrayerHandsIcon(size: 28, isOnGoldBackground: false),
          const PrayerHandsIcon(size: 28, isOnGoldBackground: true),
          const SacredTempleEmblemIcon(size: 32),
          const VitalityHeartIcon(size: 46),
          const ManaDropIcon(size: 46),
          const SacredRelicIcon(size: 24),
          const TransformationMiracleIcon(size: 22),
          const ReliquaryBundleIcon(size: 22),
          const ElementalCrystalIcon(size: 22),
          const MeditationHaloIcon(size: 24),
          const SacredBlessingIcon(size: 24),
        ];
        for (final icon in allPainters) {
          await tester.pumpWidget(
            MaterialApp(home: Scaffold(body: Center(child: icon))),
          );
          expect(tester.takeException(), isNull);
        }

        // 2. Full SacredTempleDialog verification across Dark Mode and Light Mode
        final harness = await _createTempleHarness(
          prefs: {'unlockedAds': false},
        );
        final controller = harness.controller;
        addTearDown(() {
          controller.dispose();
          harness.billingClient.dispose();
        });

        for (final isDark in [true, false]) {
          controller.darkMode = isDark;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: SacredTempleDialog(
                  key: ValueKey('temple_icons_theme_$isDark'),
                  controller: controller,
                  fromTemple: true,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(SacredTempleEmblemIcon), findsOneWidget);
          expect(
            tester.getSize(find.byType(SacredTempleEmblemIcon)),
            equals(const Size(32.0, 32.0)),
          );

          final consagrationTab =
              find.byKey(const ValueKey('temple_tab_consagration'));
          final offeringsTab =
              find.byKey(const ValueKey('temple_tab_offerings'));
          final transmuteTab =
              find.byKey(const ValueKey('temple_tab_transmute'));
          final adorationTab =
              find.byKey(const ValueKey('temple_tab_adoration'));
          final prayerTab = find.byKey(const ValueKey('temple_tab_prayer'));

          final chaliceFinder = find.descendant(
            of: consagrationTab,
            matching: find.byType(ConsagrationChaliceIcon),
          );
          final altarFinder = find.descendant(
            of: offeringsTab,
            matching: find.byType(OfferingsAltarIcon),
          );
          final transformationFinder = find.descendant(
            of: transmuteTab,
            matching: find.byType(HolyTransformationIcon),
          );
          final harpFinder = find.descendant(
            of: adorationTab,
            matching: find.byType(AdorationHarpIcon),
          );
          final handsFinder = find.descendant(
            of: prayerTab,
            matching: find.byType(PrayerHandsIcon),
          );

          for (final finder in [
            chaliceFinder,
            altarFinder,
            transformationFinder,
            harpFinder,
            handsFinder,
          ]) {
            expect(finder, findsOneWidget);
            expect(tester.getSize(finder), equals(const Size(28.0, 28.0)));
          }

          // Wing 1 (Consagration) active by default
          expect(tester.widget<ConsagrationChaliceIcon>(chaliceFinder).isOnGoldBackground, isTrue);
          expect(tester.widget<OfferingsAltarIcon>(altarFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<HolyTransformationIcon>(transformationFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<AdorationHarpIcon>(harpFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<PrayerHandsIcon>(handsFinder).isOnGoldBackground, isFalse);
          expect(find.byType(VitalityHeartIcon), findsOneWidget);
          expect(find.byType(ManaDropIcon), findsOneWidget);
          expect(
            tester.getSize(find.byType(VitalityHeartIcon)),
            equals(const Size(46.0, 46.0)),
          );
          expect(
            tester.getSize(find.byType(ManaDropIcon)),
            equals(const Size(46.0, 46.0)),
          );

          // Wing 2 (Offerings)
          await tester.tap(offeringsTab);
          await tester.pumpAndSettle();
          expect(tester.widget<ConsagrationChaliceIcon>(chaliceFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<OfferingsAltarIcon>(altarFinder).isOnGoldBackground, isTrue);
          expect(find.byType(SacredRelicIcon), findsOneWidget);

          // Wing 3 (Transformation)
          await tester.tap(transmuteTab);
          await tester.pumpAndSettle();
          expect(tester.widget<OfferingsAltarIcon>(altarFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<HolyTransformationIcon>(transformationFinder).isOnGoldBackground, isTrue);
          expect(find.byType(TransformationMiracleIcon), findsOneWidget);

          // Wing 4 (Adoration)
          await tester.tap(adorationTab);
          await tester.pumpAndSettle();
          expect(tester.widget<HolyTransformationIcon>(transformationFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<AdorationHarpIcon>(harpFinder).isOnGoldBackground, isTrue);
          expect(find.byType(ReliquaryBundleIcon), findsOneWidget);
          expect(find.byType(ElementalCrystalIcon), findsOneWidget);

          // Wing 5 (Prayer)
          await tester.tap(prayerTab);
          await tester.pumpAndSettle();
          expect(tester.widget<AdorationHarpIcon>(harpFinder).isOnGoldBackground, isFalse);
          expect(tester.widget<PrayerHandsIcon>(handsFinder).isOnGoldBackground, isTrue);
          expect(find.byType(MeditationHaloIcon), findsOneWidget);
          expect(find.byType(SacredBlessingIcon), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
