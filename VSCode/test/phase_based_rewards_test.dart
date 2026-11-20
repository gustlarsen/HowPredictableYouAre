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
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/widgets/adaptive_rewarded_ad_button.dart';

class _TestAdMobClient implements AdMobClient {
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
    onLoaded();
  }

  @override
  Future<bool> showRewarded({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onDismissed,
    required VoidCallback onFailedToShow,
  }) async {
    onUserEarnedReward();
    onDismissed();
    return true;
  }

  @override
  void disposeRewarded() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase-Based Rewarded Ad & Gift Box Rewards', () {
    test('Phase 1 grants 3 main elements only for Ad (+50) and Gift (+5) and Turn 0 reset preserves Ad while reverting Gift', () async {
      SharedPreferences.setMockInitialValues({
        'musicEnabled': false,
        'current_week': 3,
        'orbs_fire': 10,
        'orbs_water': 10,
        'orbs_wood': 10,
        'orbs_earth': 2,
        'orbs_metal': 4,
        'giftBoxUnlocked': true,
        'giftBoxEnabled': true,
      });
      final storage = StorageService();
      await storage.init();
      final adService = AdService(client: _TestAdMobClient());
      await adService.initialize();
      final controller = GameController(
        storage: storage,
        localization: LocalizationService(),
        audio: AudioService(),
        adService: adService,
      );
      addTearDown(controller.dispose);

      expect(controller.isPhase2, isFalse);
      expect(controller.unlockedNewHands, isFalse);
      expect(controller.includesEarthAndMetalInBonuses, isFalse);

      // Gift Box grants +5 Fire/Water/Wood and 0 Earth/Metal
      controller.claimGift();
      expect(controller.fireOrbs, 15);
      expect(controller.waterOrbs, 15);
      expect(controller.woodOrbs, 15);
      expect(controller.earthOrbs, 2);
      expect(controller.metalOrbs, 4);

      // Rewarded Ad grants +50 Fire/Water/Wood and 0 Earth/Metal
      final earned = await controller.watchRewardedAd();
      expect(earned, isTrue);
      expect(controller.fireOrbs, 65);
      expect(controller.waterOrbs, 65);
      expect(controller.woodOrbs, 65);
      expect(controller.earthOrbs, 2);
      expect(controller.metalOrbs, 4);

      // Turn 0 baseline protected only the 3 granted main elements (+50)
      expect(controller.turn0FireOrbs, 60);
      expect(controller.turn0WaterOrbs, 60);
      expect(controller.turn0WoodOrbs, 60);
      expect(controller.turn0EarthOrbs, 2);
      expect(controller.turn0MetalOrbs, 4);

      // Rewind to Turn 0 reverts Gift Box (+5) while keeping Ad (+50)
      controller.resetGame();
      expect(controller.fireOrbs, 60);
      expect(controller.waterOrbs, 60);
      expect(controller.woodOrbs, 60);
      expect(controller.earthOrbs, 2);
      expect(controller.metalOrbs, 4);
    });

    test('Phase 2+ grants all 5 elements for Ad (+50) and Gift (+5) and Turn 0 reset preserves all 5 Ad orbs while reverting Gift', () async {
      SharedPreferences.setMockInitialValues({
        'musicEnabled': false,
        'current_week': 10,
        'orbs_fire': 10,
        'orbs_water': 10,
        'orbs_wood': 10,
        'orbs_earth': 10,
        'orbs_metal': 10,
        'giftBoxUnlocked': true,
        'giftBoxEnabled': true,
      });
      final storage = StorageService();
      await storage.init();
      final adService = AdService(client: _TestAdMobClient());
      await adService.initialize();
      final controller = GameController(
        storage: storage,
        localization: LocalizationService(),
        audio: AudioService(),
        adService: adService,
      );
      addTearDown(controller.dispose);

      expect(controller.isPhase2, isTrue);
      expect(controller.includesEarthAndMetalInBonuses, isTrue);

      // Gift Box grants +5 of all 5 elements
      controller.claimGift();
      expect(controller.fireOrbs, 15);
      expect(controller.waterOrbs, 15);
      expect(controller.woodOrbs, 15);
      expect(controller.earthOrbs, 15);
      expect(controller.metalOrbs, 15);

      // Rewarded Ad grants +50 of all 5 elements
      final earned = await controller.watchRewardedAd();
      expect(earned, isTrue);
      expect(controller.fireOrbs, 65);
      expect(controller.waterOrbs, 65);
      expect(controller.woodOrbs, 65);
      expect(controller.earthOrbs, 65);
      expect(controller.metalOrbs, 65);

      // Turn 0 baseline protected all 5 elements (+50)
      expect(controller.turn0FireOrbs, 60);
      expect(controller.turn0WaterOrbs, 60);
      expect(controller.turn0WoodOrbs, 60);
      expect(controller.turn0EarthOrbs, 60);
      expect(controller.turn0MetalOrbs, 60);

      // Rewind to Turn 0 reverts Gift Box (+5) while keeping all 5 Ad (+50)
      controller.resetGame();
      expect(controller.fireOrbs, 60);
      expect(controller.waterOrbs, 60);
      expect(controller.woodOrbs, 60);
      expect(controller.earthOrbs, 60);
      expect(controller.metalOrbs, 60);
    });

    test('Unlocking Earth & Metal before Phase 2 also enables 5-element Ad and Gift bonuses', () async {
      SharedPreferences.setMockInitialValues({
        'musicEnabled': false,
        'current_week': 2,
        'orbs_earth': 50,
        'orbs_metal': 50,
        'giftBoxUnlocked': true,
        'giftBoxEnabled': true,
      });
      final storage = StorageService();
      await storage.init();
      final adService = AdService(client: _TestAdMobClient());
      await adService.initialize();
      final controller = GameController(
        storage: storage,
        localization: LocalizationService(),
        audio: AudioService(),
        adService: adService,
      );
      addTearDown(controller.dispose);

      expect(controller.isPhase2, isFalse);
      expect(controller.unlockNewHands(), isTrue);
      expect(controller.includesEarthAndMetalInBonuses, isTrue);

      controller.claimGift();
      expect(controller.fireOrbs, 5);
      expect(controller.earthOrbs, 5);
      expect(controller.metalOrbs, 5);

      await controller.watchRewardedAd();
      expect(controller.fireOrbs, 55);
      expect(controller.earthOrbs, 55);
      expect(controller.metalOrbs, 55);
    });

    testWidgets('ShopDialog & GameScreen show 3 icons and main-element disclosure in Phase 1', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        'animationsEnabled': false,
        'musicEnabled': false,
        'current_week': 0,
        'giftBoxUnlocked': true,
        'giftBoxEnabled': true,
      });
      final storage = StorageService();
      await storage.init();
      final adService = AdService(client: _TestAdMobClient());
      await adService.initialize();
      final controller = GameController(
        storage: storage,
        localization: LocalizationService(),
        audio: AudioService(),
        adService: adService,
      );
      addTearDown(controller.dispose);

      // 1. GameScreen tooltips and SnackBars in Phase 1
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const HowPredictableApp(home: GameScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final adWidget = tester.widget<AdaptiveRewardedAdButton>(
        find.byType(AdaptiveRewardedAdButton),
      );
      expect(adWidget.tooltip, 'Watch a video ad for +50 Fire, Water & Wood Orbs');

      final giftBtn = tester.widget<IconButton>(
        find.byKey(const ValueKey('gift_box_button')),
      );
      expect(giftBtn.tooltip, 'Claim Free +5 Fire, Water & Wood Orbs Gift');

      await tester.tap(find.byKey(const ValueKey('gift_box_button')));
      await tester.pump();
      expect(find.text('🎁 +5 Fire, Water & Wood Orbs Claimed!'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('watch_rewarded_ad_button')));
      await tester.pump();
      expect(find.text('+50 Fire, Water & Wood Orbs earned!'), findsOneWidget);

      // 2. ShopDialog shows only the 3 main element icons in Free Elemental Orbs card
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: controller,
              child: ShopDialog(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('shop_ad_orb_icon_rock')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop_ad_orb_icon_paper')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop_ad_orb_icon_scissors')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop_ad_orb_icon_lizard')), findsNothing);
      expect(find.byKey(const ValueKey('shop_ad_orb_icon_spock')), findsNothing);
    });

    testWidgets('ShopDialog & GameScreen show all 5 icons and every-element disclosure in Phase 2+', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        'animationsEnabled': false,
        'musicEnabled': false,
        'current_week': 10,
        'giftBoxUnlocked': true,
        'giftBoxEnabled': true,
      });
      final storage = StorageService();
      await storage.init();
      final adService = AdService(client: _TestAdMobClient());
      await adService.initialize();
      final controller = GameController(
        storage: storage,
        localization: LocalizationService(),
        audio: AudioService(),
        adService: adService,
      );
      addTearDown(controller.dispose);

      // 1. GameScreen tooltips and SnackBars in Phase 2+
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const HowPredictableApp(home: GameScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final adWidget = tester.widget<AdaptiveRewardedAdButton>(
        find.byType(AdaptiveRewardedAdButton),
      );
      expect(adWidget.tooltip, 'Watch a video ad for +50 of every element');

      final giftBtn = tester.widget<IconButton>(
        find.byKey(const ValueKey('gift_box_button')),
      );
      expect(giftBtn.tooltip, 'Claim Free +5 Orbs of Every Element Gift');

      await tester.tap(find.byKey(const ValueKey('gift_box_button')));
      await tester.pump();
      expect(find.text('🎁 +5 Orbs of Every Element Claimed!'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('watch_rewarded_ad_button')));
      await tester.pump();
      expect(find.text('+50 Orbs of every element earned!'), findsOneWidget);

      // 2. ShopDialog shows all 5 element icons in Free Elemental Orbs card
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: controller,
              child: ShopDialog(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('shop_ad_orb_icon_rock')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop_ad_orb_icon_paper')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop_ad_orb_icon_scissors')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop_ad_orb_icon_lizard')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop_ad_orb_icon_spock')), findsOneWidget);
    });

    test('All Phase 1 and Phase 2+ reward localization keys exist across en, pt, es, and de', () async {
      final localization = LocalizationService();
      await localization.load();

      const keys = [
        'rewarded_ad_desc',
        'rewarded_ad_desc_main',
        'rewarded_ad_claimed_main',
        'rewarded_ad_claimed_all',
        'gift_tooltip',
        'gift_tooltip_main',
        'gift_claimed_msg',
        'gift_claimed_msg_main',
        'gift_box_desc',
        'gift_box_desc_main',
      ];
      for (final lang in LocalizationService.supportedLanguages) {
        localization.setLanguage(lang);
        for (final key in keys) {
          final value = localization.t(key);
          expect(value, isNot(key), reason: 'Missing $lang key: $key');
          expect(value.trim(), isNotEmpty, reason: 'Empty $lang key: $key');
        }
      }
    });
  });
}
