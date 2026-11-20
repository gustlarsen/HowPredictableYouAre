import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _TestPlayGamesClient implements PlayGamesClient {
  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'TestPlayer';

  @override
  Future<String?> getPlayerID() async => 'test_player_1';

  @override
  Future<String?> saveGame({
    required String data,
    required String name,
  }) async => 'success';

  @override
  Future<String?> loadGame({required String name}) async => null;
}

class _TestAdMobClient implements AdMobClient {
  int loadBannerCount = 0;

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
    loadBannerCount++;
    onLoaded();
  }

  @override
  Widget? buildBannerWidget() => const SizedBox(
    key: ValueKey('viewport_test_banner'),
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
    onLoaded();
  }

  @override
  Future<bool> showRewarded({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onDismissed,
    required VoidCallback onFailedToShow,
  }) async {
    onDismissed();
    return true;
  }

  @override
  void disposeRewarded() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Post-Update Viewport & Metrics Recovery Tests', () {
    testWidgets(
      'HowPredictableApp recovers full-screen layout, SafeArea insets, native viewport sync, and AdService banner on metrics change and resume',
      (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        const viewportChannel = MethodChannel(
          'com.gustlarsen.howpredictable/viewport',
        );
        int syncViewportCalls = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          viewportChannel,
          (MethodCall call) async {
            if (call.method == 'syncViewport') {
              syncViewportCalls++;
              return true;
            }
            return null;
          },
        );

        try {
          // Start in shrunk 75% viewport with 0 bottom inset (simulating transient post-update state)
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = const Size(345, 768);
          tester.view.viewPadding = FakeViewPadding.zero;
          tester.view.padding = FakeViewPadding.zero;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.view.resetViewPadding();
            tester.view.resetPadding();
          });

          SharedPreferences.setMockInitialValues({
            'has_seen_story_intro': true,
            'animationsEnabled': false,
            'musicEnabled': false,
          });
          final storage = StorageService();
          await storage.init();

          final localization = LocalizationService();
          await tester.runAsync(() => localization.load());

          final adClient = _TestAdMobClient();
          final adService = AdService(client: adClient);
          await adService.initialize(adsRemoved: false);

          final playGames = PlayGamesService(
            storage: storage,
            client: _TestPlayGamesClient(),
          );

          final controller = GameController(
            storage: storage,
            localization: localization,
            audio: AudioService(),
            playGames: playGames,
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

          expect(
            tester.getSize(find.byKey(const ValueKey('world_map_screen'))),
            equals(const Size(345, 768)),
          );
          final initialBannerLoads = adClient.loadBannerCount;

          // Recover to full 100% screen metrics + system navigation bar inset and trigger resume
          tester.view.physicalSize = const Size(460, 1024);
          tester.view.viewPadding = const FakeViewPadding(top: 32, bottom: 48);
          tester.view.padding = const FakeViewPadding(top: 32, bottom: 48);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();

          expect(syncViewportCalls, greaterThanOrEqualTo(1));
          expect(
            tester.getSize(find.byKey(const ValueKey('world_map_screen'))),
            equals(const Size(460, 1024)),
          );
          expect(adClient.loadBannerCount, greaterThan(initialBannerLoads));

          // Bottom banner must sit above the 48px navigation bar SafeArea inset
          final bannerRect = tester.getRect(
            find.byKey(const ValueKey('bottom_banner_ad_container')),
          );
          expect(bannerRect.bottom, lessThanOrEqualTo(1024 - 48));
          expect(bannerRect.center.dx, closeTo(230.0, 1.0));
        } finally {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            viewportChannel,
            null,
          );
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    test(
      'AdService reloads banner and increments bannerViewGeneration only on significant metrics shifts',
      () async {
        final adClient = _TestAdMobClient();
        final adService = AdService(client: adClient);
        await adService.initialize(adsRemoved: false);
        expect(adClient.loadBannerCount, 1);
        expect(adService.bannerViewGeneration, 0);

        // Baseline metrics capture should not reload
        adService.handleMetricsChanged(
          devicePixelRatio: 2.0,
          logicalSize: const Size(390, 844),
        );
        await Future<void>.delayed(Duration.zero);
        expect(adClient.loadBannerCount, 1);
        expect(adService.bannerViewGeneration, 0);

        // Sub-threshold jitter should not reload
        adService.handleMetricsChanged(
          devicePixelRatio: 2.01,
          logicalSize: const Size(391, 845),
        );
        await Future<void>.delayed(Duration.zero);
        expect(adClient.loadBannerCount, 1);
        expect(adService.bannerViewGeneration, 0);

        // Significant DPR/size recovery (e.g. 0.75x -> 1.0x) reloads banner
        adService.handleMetricsChanged(
          devicePixelRatio: 2.8,
          logicalSize: const Size(460, 1024),
        );
        await Future<void>.delayed(Duration.zero);
        expect(adClient.loadBannerCount, 2);
        expect(adService.bannerViewGeneration, 1);
      },
    );
  });
}
