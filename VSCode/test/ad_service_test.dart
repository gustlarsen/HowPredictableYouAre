import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';

class FakeAdMobClient implements AdMobClient {
  bool shouldSucceedInit;
  bool shouldLoadBanner;
  bool shouldLoadRewarded;
  bool shouldShowRewardedSucceed;
  bool shouldEarnRewardOnShow;
  bool privacyOptionsRequired;
  int initializeCallCount = 0;
  int loadBannerCallCount = 0;
  int disposeBannerCallCount = 0;
  int loadRewardedCallCount = 0;
  int showRewardedCallCount = 0;
  int showPrivacyOptionsFormCallCount = 0;

  FakeAdMobClient({
    this.shouldSucceedInit = true,
    this.shouldLoadBanner = true,
    this.shouldLoadRewarded = true,
    this.shouldShowRewardedSucceed = true,
    this.shouldEarnRewardOnShow = true,
    this.privacyOptionsRequired = false,
  });

  @override
  Future<void> initialize() async {
    initializeCallCount++;
    if (!shouldSucceedInit) {
      throw Exception('Offline or AdMob unavailable');
    }
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    return privacyOptionsRequired;
  }

  @override
  Future<void> showPrivacyOptionsForm({
    OnConsentFormDismissedListener? onDismissed,
  }) async {
    showPrivacyOptionsFormCallCount++;
    onDismissed?.call(null);
  }

  @override
  Future<void> loadBanner({
    required String adUnitId,
    required AdSize size,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    loadBannerCallCount++;
    if (shouldLoadBanner) {
      onLoaded();
    } else {
      onFailed();
    }
  }

  @override
  Widget? buildBannerWidget() {
    return Container(
      key: const ValueKey('fake_banner_ad_widget'),
      width: 320,
      height: 50,
      color: Colors.black26,
    );
  }

  @override
  void disposeBanner() {
    disposeBannerCallCount++;
  }

  @override
  Future<void> loadRewarded({
    required String adUnitId,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    loadRewardedCallCount++;
    if (shouldLoadRewarded) {
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
    showRewardedCallCount++;
    if (!shouldShowRewardedSucceed) {
      onFailedToShow();
      return false;
    }
    if (shouldEarnRewardOnShow) {
      onUserEarnedReward();
    }
    onDismissed();
    return true;
  }

  @override
  void disposeRewarded() {}
}

class _FakePlayGamesClient implements PlayGamesClient {
  int saveCallCount = 0;

  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'AdTester';

  @override
  Future<String?> getPlayerID() async => 'player_ad_tester_1';

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

  group('AdService & AdMob Integration Tests', () {
    test(
      'Resolves official Google test Ad Unit IDs in debug mode and production Ad Unit IDs in release mode',
      () {
        expect(
          AdService.resolveBannerAdUnitId(isDebug: true),
          'ca-app-pub-3940256099942544/6300978111',
        );
        expect(
          AdService.resolveRewardedAdUnitId(isDebug: true),
          'ca-app-pub-3940256099942544/5224354917',
        );
        expect(
          AdService.resolveBannerAdUnitId(isDebug: false),
          'ca-app-pub-2990586338327178/5227771481',
        );
        expect(
          AdService.resolveRewardedAdUnitId(isDebug: false),
          'ca-app-pub-2990586338327178/9766971660',
        );
        expect(
          AdService.productionAppId,
          'ca-app-pub-2990586338327178~5364692228',
        );
      },
    );

    test(
      'Gracefully collapses banner height to 0 when offline or when banner load fails',
      () async {
        final fakeClient = FakeAdMobClient(
          shouldLoadBanner: false,
          shouldLoadRewarded: false,
        );
        final adService = AdService(client: fakeClient);
        await adService.initialize();

        expect(adService.isBannerAdLoaded, isFalse);
        expect(adService.bannerHeight, 0.0);
        expect(adService.isRewardedAdLoaded, isFalse);
      },
    );

    test(
      '(a) Completing a rewarded ad increments all 5 Elemental Orbs by 50, saves to SharedPreferences and PlayGamesService cloud save, and auto-reloads next ad',
      () async {
        SharedPreferences.setMockInitialValues({
          'orbs_fire': 100,
          'orbs_water': 100,
          'orbs_wood': 100,
          'orbs_earth': 100,
          'orbs_metal': 100,
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
        final initialSaves = fakePlayGamesClient.saveCallCount;

        final fakeAdClient = FakeAdMobClient();
        final adService = AdService(client: fakeAdClient);
        await adService.initialize();

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
          adService: adService,
        );
        addTearDown(() => controller.dispose());

        expect(controller.fireOrbs, 100);
        expect(adService.isRewardedAdLoaded, isTrue);
        expect(fakeAdClient.loadRewardedCallCount, 1);

        final earned = await controller.watchRewardedAd();
        expect(earned, isTrue);

        // +50 of each Elemental Orb granted and persisted
        expect(controller.fireOrbs, 150);
        expect(controller.waterOrbs, 150);
        expect(controller.woodOrbs, 150);
        expect(controller.earthOrbs, 150);
        expect(controller.metalOrbs, 150);
        expect(storage.fireOrbs, 150);
        expect(storage.waterOrbs, 150);
        expect(storage.woodOrbs, 150);
        expect(storage.earthOrbs, 150);
        expect(storage.metalOrbs, 150);

        // Cloud save triggered
        expect(fakePlayGamesClient.saveCallCount, greaterThan(initialSaves));

        // Next rewarded ad automatically preloaded after dismissal
        expect(fakeAdClient.loadRewardedCallCount, 2);
        expect(adService.isRewardedAdLoaded, isTrue);

        // 2-minute anti-spam cooldown is active
        expect(controller.isRewardedAdOnCooldown, isTrue);
        expect(controller.isRewardedAdReady, isFalse);
      },
    );

    test(
      '(b) Unlocking Remove Ads permanently hides and disposes banner ad while keeping voluntary Rewarded Ad available',
      () async {
        SharedPreferences.setMockInitialValues({
          'orbs_fire': 2500,
          'orbs_water': 2500,
          'orbs_wood': 2500,
          'orbs_earth': 2000,
          'orbs_metal': 2000,
          'musicEnabled': false,
          'has_seen_story_intro': true,
        });
        final storage = StorageService();
        await storage.init();

        final fakeAdClient = FakeAdMobClient();
        final adService = AdService(client: fakeAdClient);
        await adService.initialize();

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          adService: adService,
        );
        addTearDown(() => controller.dispose());

        expect(controller.shouldShowBannerAd, isTrue);
        expect(adService.isBannerAdLoaded, isTrue);
        expect(adService.bannerHeight, 50.0);

        // Purchase Remove Ads (cost: 2000 Fire/Water/Wood + 1500 Earth/Metal)
        final success = controller.unlockAds();
        expect(success, isTrue);
        expect(controller.fireOrbs, 500);
        expect(controller.earthOrbs, 500);
        expect(controller.unlockedAds, isTrue);
        expect(controller.shouldShowBannerAd, isFalse);
        expect(adService.isBannerAdLoaded, isFalse);
        expect(adService.bannerHeight, 0.0);
        expect(fakeAdClient.disposeBannerCallCount, greaterThanOrEqualTo(1));

        // Rewarded ad remains ready as a voluntary bonus
        expect(controller.isRewardedAdReady, isTrue);
      },
    );

    testWidgets(
      'GameScreen displays bottom banner and "Watch Ad +50 Orbs" button, grants +50 of each orb with SnackBar and 2m cooldown, and hides banner when Remove Ads is unlocked',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'orbs_fire': 2000,
          'orbs_water': 2000,
          'orbs_wood': 2000,
          'orbs_earth': 1500,
          'orbs_metal': 1500,
          'animationsEnabled': false,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeAdClient = FakeAdMobClient();
        final adService = AdService(client: fakeAdClient);
        await adService.initialize();

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          adService: adService,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(home: GameScreen()),
          ),
        );
        await tester.pump();

        // Bottom banner ad and Watch Ad +50 Orbs button are both visible with explicit disclosure
        expect(
          find.byKey(const ValueKey('bottom_banner_ad_container')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('watch_rewarded_ad_button')),
          findsOneWidget,
        );
        final watchAdButtonFinder = find.byKey(
          const ValueKey('watch_rewarded_ad_button'),
        );
        expect(
          find.descendant(
            of: watchAdButtonFinder,
            matching: find.byIcon(Icons.play_circle_fill_rounded),
          ),
          findsNothing,
        );
        final watchAdTextFinder = find.descendant(
          of: watchAdButtonFinder,
          matching: find.text(AdService.rewardedAdButtonLabel),
        );
        expect(watchAdTextFinder, findsOneWidget);
        final watchAdText = tester.widget<Text>(watchAdTextFinder);
        expect(watchAdText.style?.fontSize, equals(10.5));

        // Tap Watch Ad +50 Orbs button
        await tester.tap(find.byKey(const ValueKey('watch_rewarded_ad_button')));
        await tester.pump();

        // All 5 Elemental Orbs increased by 50 and celebratory SnackBar is shown
        expect(controller.fireOrbs, 2050);
        expect(controller.waterOrbs, 2050);
        expect(controller.woodOrbs, 2050);
        expect(controller.earthOrbs, 1550);
        expect(controller.metalOrbs, 1550);
        expect(
          find.text(GameController.rewardedAdSnackBarMessage),
          findsOneWidget,
        );

        // Watch Ad button is hidden during the 2-minute anti-spam cooldown
        expect(
          find.byKey(const ValueKey('watch_rewarded_ad_button')),
          findsNothing,
        );

        // Advance clock by 2 minutes -> cooldown finishes and button reappears
        await tester.pump(const Duration(minutes: 2));
        expect(controller.isRewardedAdOnCooldown, isFalse);
        expect(
          find.byKey(const ValueKey('watch_rewarded_ad_button')),
          findsOneWidget,
        );

        // Unlock Remove Ads -> both bottom banner and top AppBar Watch Ad pill immediately disappear
        expect(controller.unlockAds(), isTrue);
        expect(controller.isRemoveAdsActive, isTrue);
        await tester.pump();

        expect(
          find.byKey(const ValueKey('bottom_banner_ad_container')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('watch_rewarded_ad_button')),
          findsNothing,
        );

        // Open ShopDialog -> rewarded ad card is also hidden when Remove Ads is active
        await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('shop_rewarded_ad_card')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('shop_watch_rewarded_ad_button')),
          findsNothing,
        );

        // Toggle Remove Ads OFF in the shop -> pinned rewarded ad card in shop and top AppBar pill reappear immediately without scrolling
        controller.toggleRemoveAds(false);
        expect(controller.isRemoveAdsActive, isFalse);
        await tester.pumpAndSettle();

        final shopAdCardFinder = find.byKey(
          const ValueKey('shop_rewarded_ad_card'),
        );
        expect(shopAdCardFinder, findsOneWidget);
        expect(
          find.descendant(
            of: find.descendant(
              of: find.byType(ShopDialog),
              matching: find.byType(ListView),
            ),
            matching: shopAdCardFinder,
          ),
          findsNothing,
        );

        await tester.tap(find.byKey(const ValueKey('shop_close_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('watch_rewarded_ad_button')),
          findsOneWidget,
        );

        // Toggle Remove Ads back ON -> top AppBar rewarded ad pill is hidden again
        controller.toggleRemoveAds(true);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('watch_rewarded_ad_button')),
          findsNothing,
        );
      },
    );

    test(
      'Rewarded ad grants +50 Elemental Orbs exclusively inside onUserEarnedReward and does not grant reward if dismissed early',
      () async {
        SharedPreferences.setMockInitialValues({
          'orbs_fire': 100,
          'musicEnabled': false,
          'has_seen_story_intro': true,
        });
        final storage = StorageService();
        await storage.init();

        final fakeAdClient = FakeAdMobClient(shouldEarnRewardOnShow: false);
        final adService = AdService(client: fakeAdClient);
        await adService.initialize();

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          adService: adService,
        );
        addTearDown(() => controller.dispose());

        // Ad is shown, but user dismisses before earning reward (onUserEarnedReward not called)
        final earned = await controller.watchRewardedAd();
        expect(earned, isFalse);
        expect(controller.fireOrbs, 100);
        expect(storage.fireOrbs, 100);
        expect(controller.isRewardedAdOnCooldown, isFalse);
      },
    );

    testWidgets(
      'Rewarded ad button is hidden when isRewardedAdReady is false (no ad loaded)',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'orbs_fire': 100,
          'animationsEnabled': false,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeAdClient = FakeAdMobClient(shouldLoadRewarded: false);
        final adService = AdService(client: fakeAdClient);
        await adService.initialize();

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          adService: adService,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pump();

        expect(controller.isRewardedAdReady, isFalse);
        expect(
          find.byKey(const ValueKey('watch_rewarded_ad_button')),
          findsNothing,
        );
        expect(find.text(AdService.rewardedAdButtonLabel), findsNothing);
      },
    );

    testWidgets(
      'SettingsDialog shows "Privacy / Ad Settings" button when isPrivacyOptionsRequired is true and opens showPrivacyOptionsForm(), and hides it when false',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeAdClient = FakeAdMobClient(privacyOptionsRequired: true);
        final adService = AdService(client: fakeAdClient);
        await adService.initialize();

        expect(await adService.isPrivacyOptionsRequired, isTrue);

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          adService: adService,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pump();

        // Open SettingsDialog when user is in EEA/UK/Switzerland (privacyOptionsRequired == true)
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();

        final privacyBtn = find.byKey(
          const ValueKey('settings_privacy_options_button'),
        );
        expect(privacyBtn, findsOneWidget);
        expect(find.text('Privacy / Ad Settings'), findsOneWidget);

        await tester.ensureVisible(privacyBtn);
        await tester.tap(privacyBtn);
        await tester.pumpAndSettle();

        expect(fakeAdClient.showPrivacyOptionsFormCallCount, 1);

        // Close SettingsDialog
        await tester.tap(find.text('Ok'));
        await tester.pumpAndSettle();

        // Now simulate user outside EEA/UK/Switzerland (privacyOptionsRequired == false)
        fakeAdClient.privacyOptionsRequired = false;
        expect(await adService.isPrivacyOptionsRequired, isFalse);

        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('settings_privacy_options_button')),
          findsNothing,
        );
        expect(find.text('Privacy / Ad Settings'), findsNothing);
      },
    );

    testWidgets(
      'ShopDialog rewarded ad button displays explicit "Watch Ad +50 Orbs" disclosure, disables when not ready, and grants +50 of each orb on completion',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'orbs_fire': 100,
          'orbs_water': 100,
          'orbs_wood': 100,
          'orbs_earth': 100,
          'orbs_metal': 100,
          'animationsEnabled': false,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeAdClient = FakeAdMobClient();
        final adService = AdService(client: fakeAdClient);
        await adService.initialize();

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          adService: adService,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pump();

        // Open ShopDialog via Sacred Temple (Altar of Offerings) on WorldMapScreen
        await tester.tap(find.byKey(const ValueKey('landmark_sacred_temple')));
        await tester.pumpAndSettle();

        // Pinned Rewarded Ad card & button are immediately visible without scrolling
        final shopAdBtnFinder = find.byKey(
          const ValueKey('shop_watch_rewarded_ad_button'),
        );
        expect(shopAdBtnFinder, findsOneWidget);
        expect(
          find.descendant(
            of: shopAdBtnFinder,
            matching: find.text(AdService.rewardedAdButtonLabel),
          ),
          findsOneWidget,
        );
        expect(
          find.text('Watch a video ad for +50 of each Elemental Orb'),
          findsOneWidget,
        );

        // Tap the Shop rewarded ad button -> grants +50 of each orb and enters 2m cooldown (disabled)
        await tester.tap(shopAdBtnFinder);
        await tester.pump();

        expect(controller.fireOrbs, 150);
        expect(controller.waterOrbs, 150);
        expect(controller.woodOrbs, 150);
        expect(controller.earthOrbs, 150);
        expect(controller.metalOrbs, 150);
        expect(
          find.text(GameController.rewardedAdSnackBarMessage),
          findsOneWidget,
        );
        expect(controller.isRewardedAdReady, isFalse);
        expect(
          find.descendant(
            of: shopAdBtnFinder,
            matching: find.text('Wait 2m'),
          ),
          findsOneWidget,
        );
        final ButtonStyleButton disabledButton = tester.widget(shopAdBtnFinder);
        expect(disabledButton.onPressed, isNull);
      },
    );
  });
}
