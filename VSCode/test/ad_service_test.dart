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

class FakeAdMobClient implements AdMobClient {
  bool shouldSucceedInit;
  bool shouldLoadBanner;
  bool shouldLoadRewarded;
  bool shouldShowRewardedSucceed;
  int initializeCallCount = 0;
  int loadBannerCallCount = 0;
  int disposeBannerCallCount = 0;
  int loadRewardedCallCount = 0;
  int showRewardedCallCount = 0;

  FakeAdMobClient({
    this.shouldSucceedInit = true,
    this.shouldLoadBanner = true,
    this.shouldLoadRewarded = true,
    this.shouldShowRewardedSucceed = true,
  });

  @override
  Future<void> initialize() async {
    initializeCallCount++;
    if (!shouldSucceedInit) {
      throw Exception('Offline or AdMob unavailable');
    }
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
    onUserEarnedReward();
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
      '(a) Completing a rewarded ad increments diamonds by 50, saves to SharedPreferences and PlayGamesService cloud save, and auto-reloads next ad',
      () async {
        SharedPreferences.setMockInitialValues({
          'diamonds': 100,
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

        expect(controller.diamonds, 100);
        expect(adService.isRewardedAdLoaded, isTrue);
        expect(fakeAdClient.loadRewardedCallCount, 1);

        final earned = await controller.watchRewardedAd();
        expect(earned, isTrue);

        // +50 diamonds granted and persisted
        expect(controller.diamonds, 150);
        expect(storage.diamonds, 150);

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
          'diamonds': 12000,
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

        // Purchase Remove Ads (cost: 10000)
        final success = controller.unlockAds();
        expect(success, isTrue);
        expect(controller.diamonds, 2000);
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
      'GameScreen displays bottom banner and +50 💎 Watch Ad button, grants +50 💎 with SnackBar and 2m cooldown, and hides banner when Remove Ads is unlocked',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'diamonds': 10000,
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

        // Bottom banner ad and Watch Ad (+50 💎) button are both visible
        expect(
          find.byKey(const ValueKey('bottom_banner_ad_container')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('watch_rewarded_ad_button')),
          findsOneWidget,
        );
        expect(find.text('+50 💎'), findsOneWidget);

        // Tap Watch Ad (+50 💎) button
        await tester.tap(find.byKey(const ValueKey('watch_rewarded_ad_button')));
        await tester.pump();

        // Diamonds increased by 50 (10000 -> 10050) and celebratory SnackBar is shown
        expect(controller.diamonds, 10050);
        expect(find.text('+50 💎 earned!'), findsOneWidget);

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

        // Unlock Remove Ads -> bottom banner immediately disappears, while Watch Ad button stays available
        expect(controller.unlockAds(), isTrue);
        await tester.pump();

        expect(
          find.byKey(const ValueKey('bottom_banner_ad_container')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('watch_rewarded_ad_button')),
          findsOneWidget,
        );
      },
    );
  });
}
