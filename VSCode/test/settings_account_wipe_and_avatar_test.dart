import 'dart:async';
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
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/billing_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/settings_dialog.dart';
import 'package:how_predictable/views/screens/world_map_screen.dart';

const String _valid1x1PngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

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
  Widget? buildBannerWidget() => const SizedBox(
        key: ValueKey('wipe_test_banner'),
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
    onUserEarnedReward();
    onDismissed();
    return true;
  }

  @override
  void disposeRewarded() {}
}

class _TestBillingClient implements InAppPurchaseClient {
  final bool available;
  int restoreCallCount = 0;

  _TestBillingClient({this.available = true});

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => available;

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
    restoreCallCount++;
  }
}

class _AvatarPlayGamesClient implements PlayGamesClient, PlayGamesAvatarClient {
  bool shouldSucceedSignIn;
  String? mockPlayerName;
  String? mockPlayerId;
  String? mockAvatarBase64;
  Completer<String?>? avatarCompleter;
  bool shouldFailSave = false;
  final Map<String, String?> _cloudSavesByPlayer = {};
  int saveCount = 0;

  _AvatarPlayGamesClient({
    this.shouldSucceedSignIn = true,
    this.mockPlayerName = 'AvatarHero',
    this.mockPlayerId = 'player_avatar_1',
    this.mockAvatarBase64,
    this.avatarCompleter,
    String? initialCloudPayload,
  }) {
    if (initialCloudPayload != null && mockPlayerId != null) {
      _cloudSavesByPlayer[mockPlayerId!] = initialCloudPayload;
    }
  }

  String? get cloudPayload => _cloudSavesByPlayer[mockPlayerId ?? ''];
  set cloudPayload(String? val) {
    _cloudSavesByPlayer[mockPlayerId ?? ''] = val;
  }

  @override
  Future<String?> signIn() async => shouldSucceedSignIn ? 'success' : null;

  @override
  Future<String?> getPlayerName() async => mockPlayerName;

  @override
  Future<String?> getPlayerID() async => mockPlayerId;

  @override
  Future<String?> getPlayerIconImage() {
    final completer = avatarCompleter;
    if (completer != null) return completer.future;
    return Future<String?>.value(mockAvatarBase64);
  }

  @override
  Future<String?> saveGame({
    required String data,
    required String name,
  }) async {
    if (shouldFailSave) return null;
    saveCount++;
    _cloudSavesByPlayer[mockPlayerId ?? ''] = data;
    return 'success';
  }

  @override
  Future<String?> loadGame({required String name}) async =>
      _cloudSavesByPlayer[mockPlayerId ?? ''];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsDialog Player Profile Avatar & Full Account Wipe', () {
    testWidgets(
      'Player Profile avatar displays Play Games image when available and cohesive fallback icon when offline, loading, or unavailable',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final avatarCompleter = Completer<String?>();
        final pgClient = _AvatarPlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'PhotoHero',
          mockPlayerId: 'player_photo_1',
          avatarCompleter: avatarCompleter,
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: pgClient,
          profileRetryDelay: Duration.zero,
          maxAutoRetries: 0,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );
        addTearDown(() {
          controller.dispose();
          playGames.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(body: SettingsDialog(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Disconnected / Offline: shows fallback icon and no avatar image
        expect(
          find.byKey(const ValueKey('player_profile_avatar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('player_profile_avatar_fallback')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('player_profile_avatar_image')),
          findsNothing,
        );

        // 2. Tap Sign In while avatar fetch is still pending -> shows loading ring + fallback
        await tester.tap(
          find.byKey(const ValueKey('play_games_sign_in_button')),
        );
        await tester.pump();
        await tester.pump();

        expect(playGames.isSignedIn, isTrue);
        expect(playGames.isLoadingAvatar, isTrue);
        expect(
          find.byKey(const ValueKey('player_profile_avatar_loading')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('player_profile_avatar_fallback')),
          findsOneWidget,
        );

        // 3. Complete avatar fetch with valid Play Games PNG -> renders Image.memory
        avatarCompleter.complete(_valid1x1PngBase64);
        await tester.pumpAndSettle();

        expect(playGames.isLoadingAvatar, isFalse);
        expect(playGames.playerAvatarBytes, isNotNull);
        expect(
          find.byKey(const ValueKey('player_profile_avatar_image')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('player_profile_avatar_loading')),
          findsNothing,
        );

        // 4. Reconnect with null/unavailable avatar -> renders clean fallback icon
        pgClient.avatarCompleter = null;
        pgClient.mockAvatarBase64 = null;
        await playGames.signIn(silent: true);
        await tester.pumpAndSettle();

        expect(playGames.playerAvatarBytes, isNull);
        expect(
          find.byKey(const ValueKey('player_profile_avatar_image')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('player_profile_avatar_fallback')),
          findsOneWidget,
        );

        // 5. Reconnect with malformed/non-empty avatar string -> renders fallback safely
        final invalidAvatarClient = _AvatarPlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'PhotoHero',
          mockPlayerId: 'player_photo_1',
          mockAvatarBase64: 'not-valid-base64!!!',
        );
        final invalidAvatarService = PlayGamesService(
          storage: storage,
          client: invalidAvatarClient,
          profileRetryDelay: Duration.zero,
          maxAutoRetries: 0,
        );
        addTearDown(invalidAvatarService.dispose);
        await invalidAvatarService.signIn(silent: true);
        expect(invalidAvatarService.playerAvatarBytes, isNull);
      },
    );

    testWidgets(
      'Discreet trash button opens clear Full Account Wipe confirmation dialog, cancels cleanly, and explains IAPs vs orb unlocks and Cloud Save',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
          'orbs_fire': 320,
          'current_week': 7,
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
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(body: SettingsDialog(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();

        final trashBtn = find.byKey(
          const ValueKey('settings_wipe_account_button'),
        );
        expect(trashBtn, findsOneWidget);

        // Verify trash button is inside the Player Profile section
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('settings_player_profile_section')),
            matching: trashBtn,
          ),
          findsOneWidget,
        );

        await tester.tap(trashBtn);
        await tester.pumpAndSettle();

        final confirmDialog = find.byKey(
          const ValueKey('wipe_account_confirm_dialog'),
        );
        expect(confirmDialog, findsOneWidget);
        expect(find.text('Wipe Account Data?'), findsOneWidget);
        expect(
          find.descendant(
            of: confirmDialog,
            matching: find.textContaining('Forfeit Run'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: confirmDialog,
            matching: find.textContaining('Google Play Billing'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: confirmDialog,
            matching: find.textContaining('Restore Purchases'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: confirmDialog,
            matching: find.textContaining('Remove Ads'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: confirmDialog,
            matching: find.textContaining('in-game orbs/diamonds'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: confirmDialog,
            matching: find.textContaining('Cloud Save'),
          ),
          findsOneWidget,
        );

        // Cancel preserves all progression
        await tester.tap(
          find.byKey(const ValueKey('cancel_wipe_account_button')),
        );
        await tester.pumpAndSettle();
        expect(confirmDialog, findsNothing);
        expect(controller.fireOrbs, 320);
        expect(controller.currentWeek, 7);
      },
    );

    testWidgets(
      'Confirming Full Account Wipe erases orbs, unlocks (including orb-bought Remove Ads), Castle meta, memories, and statistics, while preserving UI settings and overwriting Cloud Save',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'has_seen_story_reset': true,
          'has_seen_story_algorithm': true,
          'has_shown_week10_archmage_warning': true,
          'animationsEnabled': false,
          'musicEnabled': false,
          'darkMode': false,
          'language': 'pt',
          'current_week': 15,
          'orbs_fire': 450,
          'orbs_water': 300,
          'orbs_wood': 250,
          'orbs_earth': 120,
          'orbs_metal': 80,
          'userScore': 14,
          'pcScore': 6,
          'total': 20,
          'hp_upgrade_level': 3,
          'mana_upgrade_level': 2,
          'unlockedReset': true,
          'unlockedAlgorithm': true,
          // Remove Ads unlocked via in-game orbs (NOT real-money IAP)
          'unlockedAds': true,
          'removeAdsEnabled': true,
          'treasury_orbs_fire': 90,
          'spoils_orbs_fire': 75,
          'relic_chamber_upgrades': ['random'],
          'peak_hp_upgrade_level': 4,
          'hall_of_heroes_claim_available': true,
          'unlocked_endings': ['ending_victor'],
          'encountered_bestiary': ['guardian_robot'],
          'total_cycles_count': 3,
          'standard_victory_count': 2,
          'offertory_level': 4,
          'offertory_cap_level': 3,
          'last_free_daily_prayer_date': '2026-11-26',
        });
        final storage = StorageService();
        await storage.init();

        final pgClient = _AvatarPlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'WipeHero',
          mockPlayerId: 'player_wipe_online',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: pgClient,
          profileRetryDelay: Duration.zero,
        );
        await playGames.signIn();

        final localization = LocalizationService();
        await tester.runAsync(() => localization.load());
        localization.setLanguage(storage.language);

        final adService = AdService(client: _TestAdMobClient());
        await adService.initialize(adsRemoved: true);

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
          playGames: playGames,
          adService: adService,
        );
        addTearDown(() {
          controller.dispose();
          playGames.dispose();
        });

        expect(controller.isRemoveAdsActive, isTrue);
        expect(adService.adsRemoved, isTrue);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(
              home: WorldMapScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open SettingsDialog -> tap discreet trash button -> confirm wipe
        await tester.tap(
          find.byKey(const ValueKey('world_map_settings_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('settings_wipe_account_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('wipe_account_confirm_dialog')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('confirm_wipe_account_button')),
        );
        await tester.pumpAndSettle();

        // 1. All local run & account progression wiped
        expect(find.byType(SettingsDialog), findsNothing);
        expect(controller.totalOrbs, 0);
        expect(controller.currentWeek, 0);
        expect(controller.totalRounds, 0);
        expect(controller.unlockedReset, isFalse);
        expect(controller.unlockedAlgorithm, isFalse);
        expect(controller.hasSeenStoryIntro, isFalse);
        expect(storage.hasSeenStory('has_seen_story_reset'), isFalse);
        expect(controller.treasuryFireOrbs, 0);
        expect(controller.spoilsFireOrbs, 0);
        expect(controller.relicChamberStoredUpgrades, isEmpty);
        expect(controller.peakHpUpgradeLevel, 0);
        expect(controller.hallOfHeroesClaimAvailable, isFalse);
        expect(controller.unlockedEndings, isEmpty);
        expect(controller.encounteredBestiary, isEmpty);
        expect(controller.totalCyclesCount, 0);
        expect(controller.standardVictoryCount, 0);
        expect(controller.offertoryRateLevel, 0);
        expect(controller.offertoryCapLevel, 0);
        expect(controller.lastFreeDailyPrayerDate, isNull);

        // 2. Orb-unlocked Remove Ads is NOT recovered -> ads re-enabled
        expect(controller.unlockedAds, isFalse);
        expect(controller.isRemoveAdsActive, isFalse);
        expect(adService.adsRemoved, isFalse);

        // 3. UI preferences preserved
        expect(controller.darkMode, isFalse);
        expect(controller.localization.currentLanguage, 'pt');

        // 4. Cloud Save overwritten with fresh wiped snapshot
        final cloudAfterWipe = CloudSaveData.tryParse(pgClient.cloudPayload)!;
        expect(cloudAfterWipe.totalOrbs, 0);
        expect(cloudAfterWipe.currentWeek, 0);
        expect(cloudAfterWipe.unlockedAds, isFalse);
        expect(cloudAfterWipe.treasuryFireOrbs, 0);
        expect(cloudAfterWipe.spoilsFireOrbs, 0);
        expect(cloudAfterWipe.relicChamberUpgrades, isEmpty);
        expect(cloudAfterWipe.totalCyclesCount, 0);
        expect(cloudAfterWipe.offertoryRateLevel, 0);
        expect(cloudAfterWipe.offertoryCapLevel, 0);
        expect(storage.pendingCloudWipeAtMillis, isNull);

        expect(
          find.byKey(const ValueKey('wipe_account_done_snackbar')),
          findsOneWidget,
        );
      },
    );

    test(
      'wipeAccountData preserves real-money Google Play Billing purchases, wipes orb-unlocked items, and blocks stale Cloud Save resurrection when wiped offline',
      () async {
        final staleCloud = CloudSaveData(
          fireOrbs: 900,
          waterOrbs: 800,
          currentWeek: 22,
          unlockedReset: true,
          unlockedAlgorithm: true,
          unlockedAds: true,
          removeAdsEnabled: true,
          spoilsFireOrbs: 150,
          totalCyclesCount: 5,
          purchasedIapProductIds: const [BillingService.productRemoveAds],
          updatedAtMillis: 1700000000000,
        );

        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'last_player_id': 'player_iap_offline',
          'orbs_fire': 900,
          'orbs_water': 800,
          'current_week': 22,
          'unlockedReset': true,
          'unlockedAlgorithm': true,
          'unlockedAds': true,
          'removeAdsEnabled': true,
          'iap_purchased_product_ids': [BillingService.productRemoveAds],
          'spoils_orbs_fire': 150,
          'total_cycles_count': 5,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        // Start offline (signIn fails initially)
        final pgClient = _AvatarPlayGamesClient(
          shouldSucceedSignIn: false,
          mockPlayerName: 'PaidHero',
          mockPlayerId: 'player_iap_offline',
          initialCloudPayload: staleCloud.toJsonString(),
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: pgClient,
          profileRetryDelay: Duration.zero,
          maxAutoRetries: 0,
        );
        final adService = AdService(client: _TestAdMobClient());
        await adService.initialize(adsRemoved: true);

        final billingClient = _TestBillingClient(available: true);
        final billingService = BillingService(client: billingClient);
        await billingService.initialize();

        int nowMs = 1750000000000;
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
          adService: adService,
          billingService: billingService,
          clock: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
        );
        addTearDown(() {
          controller.dispose();
          playGames.dispose();
          billingService.dispose();
        });

        // Wipe while offline
        final syncedImmediately = await controller.wipeAccountData();
        expect(syncedImmediately, isFalse);

        // Local progression wiped, real-money Remove Ads preserved, orb-unlocked Reset/Algorithm wiped
        expect(controller.totalOrbs, 0);
        expect(controller.currentWeek, 0);
        expect(controller.spoilsFireOrbs, 0);
        expect(controller.totalCyclesCount, 0);
        expect(controller.unlockedReset, isFalse);
        expect(controller.unlockedAlgorithm, isFalse);
        expect(controller.unlockedAds, isTrue);
        expect(controller.isRemoveAdsActive, isTrue);
        expect(adService.adsRemoved, isTrue);
        expect(
          storage.purchasedIapProductIds,
          contains(BillingService.productRemoveAds),
        );
        expect(billingClient.restoreCallCount, greaterThanOrEqualTo(1));
        expect(storage.pendingCloudWipeAtMillis, nowMs);
        expect(storage.pendingCloudWipePlayerId, 'player_iap_offline');

        // Later user comes back online and signs in -> stale 900-orb cloud save MUST NOT come back!
        pgClient.shouldSucceedSignIn = true;
        final connected = await playGames.signIn(silent: false);
        expect(connected, isTrue);

        expect(controller.totalOrbs, 0);
        expect(controller.currentWeek, 0);
        expect(controller.spoilsFireOrbs, 0);
        expect(controller.totalCyclesCount, 0);
        expect(controller.unlockedAlgorithm, isFalse);
        expect(controller.unlockedAds, isTrue);
        expect(storage.pendingCloudWipeAtMillis, isNull);

        // Cloud Save was overwritten with the wiped state + preserved real-money IAP
        final updatedCloud = CloudSaveData.tryParse(pgClient.cloudPayload)!;
        expect(updatedCloud.totalOrbs, 0);
        expect(updatedCloud.currentWeek, 0);
        expect(updatedCloud.spoilsFireOrbs, 0);
        expect(updatedCloud.totalCyclesCount, 0);
        expect(updatedCloud.unlockedAlgorithm, isFalse);
        expect(
          updatedCloud.purchasedIapProductIds,
          contains(BillingService.productRemoveAds),
        );
      },
    );

    test(
      'Full Account Wipe strings are localized in en, pt, es, and de',
      () async {
        final rawJson =
            await rootBundle.loadString('assets/data/stringsHowPredict.json');
        final map = json.decode(rawJson) as Map<String, dynamic>;

        for (final lang in ['en', 'pt', 'es', 'de']) {
          for (final key in [
            'wipe_account_tooltip',
            'wipe_account_title',
            'wipe_account_message',
            'wipe_account_confirm',
            'wipe_account_done_synced',
            'wipe_account_done_local',
          ]) {
            final value = map['${lang}_$key'] as String?;
            expect(
              value,
              isNotNull,
              reason: 'Missing ${lang}_$key in stringsHowPredict.json',
            );
            expect(
              value!.trim(),
              isNotEmpty,
              reason: 'Empty ${lang}_$key in stringsHowPredict.json',
            );
          }
          final message = map['${lang}_wipe_account_message'] as String;
          expect(message, contains('Google Play Billing'));
          expect(message, contains('Google Play Games'));
        }
      },
    );
  });
}
