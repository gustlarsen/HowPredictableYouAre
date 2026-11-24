import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';
import 'package:how_predictable/views/screens/world_map_screen.dart';
import 'package:how_predictable/views/widgets/elemental_energy_sphere.dart';
import 'package:how_predictable/views/widgets/temple_wing_icons.dart';

class _OffertoryAdMobClient implements AdMobClient {
  bool loadSucceeds;
  bool earnRewardOnShow;
  int showRewardedCalls = 0;

  _OffertoryAdMobClient({
    this.loadSucceeds = true,
    this.earnRewardOnShow = true,
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
  Widget? buildBannerWidget() => const SizedBox(height: 50, width: 320);

  @override
  void disposeBanner() {}

  @override
  Future<void> loadRewarded({
    required String adUnitId,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    if (loadSucceeds) {
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
    showRewardedCalls++;
    if (earnRewardOnShow) {
      onUserEarnedReward();
    }
    onDismissed();
    return true;
  }

  @override
  void disposeRewarded() {}
}

class _OffertoryPlayGamesClient implements PlayGamesClient {
  String playerId;
  final Map<String, String?> saves = {};
  int saveCalls = 0;

  _OffertoryPlayGamesClient({this.playerId = 'player_offertory_a'});

  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'OffertoryHero';

  @override
  Future<String?> getPlayerID() async => playerId;

  @override
  Future<String?> saveGame({
    required String data,
    required String name,
  }) async {
    saveCalls++;
    saves[playerId] = data;
    return 'saved';
  }

  @override
  Future<String?> loadGame({required String name}) async => saves[playerId];
}

Future<({
  GameController controller,
  StorageService storage,
  AdService adService,
  _OffertoryAdMobClient adClient,
  PlayGamesService playGames,
  _OffertoryPlayGamesClient pgClient,
})> _createHarness({
  Map<String, Object> prefs = const {},
  DateTime Function()? clock,
  bool rewardedAdReady = true,
  bool earnRewardOnShow = true,
  _OffertoryPlayGamesClient? pgClient,
}) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_story_intro': true,
    'musicEnabled': false,
    'soundEnabled': false,
    'vibrationEnabled': false,
    'animationsEnabled': false,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();

  final localization = LocalizationService();
  await localization.load();

  final adClient = _OffertoryAdMobClient(
    loadSucceeds: rewardedAdReady,
    earnRewardOnShow: earnRewardOnShow,
  );
  final adService = AdService(client: adClient);
  await adService.initialize(adsRemoved: false);

  final resolvedPgClient = pgClient ?? _OffertoryPlayGamesClient();
  final playGames = PlayGamesService(
    storage: storage,
    client: resolvedPgClient,
    retryBaseDelay: const Duration(milliseconds: 10),
    profileRetryDelay: Duration.zero,
  );

  final controller = GameController(
    storage: storage,
    localization: localization,
    audio: AudioService(),
    adService: adService,
    playGames: playGames,
    clock: clock,
  );

  return (
    controller: controller,
    storage: storage,
    adService: adService,
    adClient: adClient,
    playGames: playGames,
    pgClient: resolvedPgClient,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offertory Idle Orb Generator Math & Mechanics', () {
    test(
      'Cost formula floor(20 * 1.15^(Nv - 1)), progressive summation, 12/h base rate, +25% per 10 levels, 2x boost, and strict 8-hour offline cap',
      () async {
        DateTime fakeNow = DateTime.utc(2026, 11, 24, 12, 0, 0);
        final h = await _createHarness(
          prefs: {
            'orbs_fire': 1000000,
            'orbs_water': 1000000,
            'orbs_wood': 1000000,
          },
          clock: () => fakeNow,
        );
        addTearDown(h.controller.dispose);
        final c = h.controller;

        // 1. Exact formula floor(20 * 1.15^(Nv - 1))
        for (final nv in [1, 2, 5, 10, 20, 30, 50]) {
          final expected = (20.0 * math.pow(1.15, nv - 1)).floor();
          expect(
            GameController.offertoryUnitCostForTargetLevel(nv),
            equals(expected),
            reason: 'Mismatch at Nv=$nv',
          );
        }
        expect(GameController.offertoryUnitCostForTargetLevel(1), equals(20));

        // 2. Exact progressive level-by-level summation for 10 levels from Lv. 0
        int expectedSum10 = 0;
        for (int nv = 1; nv <= 10; nv++) {
          expectedSum10 += (20.0 * math.pow(1.15, nv - 1)).floor();
        }
        expect(c.offertoryUnitCostForLevels(10), equals(expectedSum10));

        // Unbuilt Lv. 0 produces 0/h
        expect(c.offertoryLevel, equals(0));
        expect(c.offertoryHourlyRate(), equals(0.0));
        expect(c.offertoryStoredOrbs(), equals(0));
        expect(c.isOffertoryFull, isFalse);

        // Upgrade 10 levels at once -> Lv. 10 (+25% milestone = 1.25x -> 12 * 10 * 1.25 = 150/h)
        expect(c.upgradeOffertoryBatch(10), isTrue);
        expect(c.offertoryLevel, equals(10));
        expect(c.offertoryMilestoneMultiplier, closeTo(1.25, 1e-9));
        expect(c.offertoryMilestoneBonusPercent, equals(25));
        expect(c.offertoryHourlyRate(), closeTo(150.0, 1e-9));
        expect(c.offertoryPerMinuteRate(), closeTo(2.5, 1e-9));
        expect(c.fireOrbs, equals(1000000 - expectedSum10));

        // Check Lv. 20 milestone rate preview: 12 * 20 * 1.5 = 360/h
        expect(c.offertoryHourlyRate(level: 20), closeTo(360.0, 1e-9));

        // 3. Advance 3 hours offline -> 450 orbs per active element
        fakeNow = fakeNow.add(const Duration(hours: 3));
        expect(c.offertoryStoredOrbs(), equals(450));
        expect(c.isOffertoryFull, isFalse);
        expect(c.offertoryFillProgress(), closeTo(3.0 / 8.0, 1e-6));

        // 4. Advance 9 more hours (12h total) -> strictly clamped to 8-hour cap (150 * 8 = 1200)
        fakeNow = fakeNow.add(const Duration(hours: 9));
        expect(c.isOffertoryFull, isTrue);
        expect(c.offertoryFillProgress(), closeTo(1.0, 1e-9));
        expect(c.offertoryStoredOrbs(), equals(1200));

        // Collect 1x -> grants 1200 to Fire/Water/Wood, resets timer
        final beforeFire = c.fireOrbs;
        final collected = c.collectOffertoryOrbs(multiplier: 1);
        expect(collected, equals(1200));
        expect(c.fireOrbs, equals(beforeFire + 1200));
        expect(c.offertoryStoredOrbs(), equals(0));
        expect(c.isOffertoryFull, isFalse);

        // 5. Fractional preservation: Lv. 10 = 2.5 orbs/min -> after 36 seconds = 1.5 orbs
        fakeNow = fakeNow.add(const Duration(seconds: 36));
        expect(c.offertoryStoredOrbs(), equals(1));
        expect(c.collectOffertoryOrbs(multiplier: 1), equals(1));
        expect(c.offertoryPendingFraction, closeTo(0.5, 1e-6));
        // After 12 more seconds (+0.5 orb) -> 0.5 + 0.5 = 1.0 whole orb!
        fakeNow = fakeNow.add(const Duration(seconds: 12));
        expect(c.offertoryStoredOrbs(), equals(1));
        expect(c.collectOffertoryOrbs(multiplier: 1), equals(1));

        // 6. Settling before upgrade & boost (no retroactive distortion!)
        // Wait 2 hours at Lv. 10 (150/h -> 300 orbs), then upgrade to Lv. 20 (360/h)
        fakeNow = fakeNow.add(const Duration(hours: 2));
        expect(c.offertoryStoredOrbs(), equals(300));
        expect(c.upgradeOffertoryBatch(10), isTrue);
        expect(c.offertoryLevel, equals(20));
        // Immediately after upgrade, stored orbs MUST remain 300 (not retroactively 2 * 360 = 720)
        expect(c.offertoryStoredOrbs(), equals(300));
        // After 1 more hour at Lv. 20 (360/h) -> 300 + 360 = 660
        fakeNow = fakeNow.add(const Duration(hours: 1));
        expect(c.offertoryStoredOrbs(), equals(660));
        expect(c.collectOffertoryOrbs(multiplier: 1), equals(660));

        // 7. Piecewise offline 2x boost expiry:
        // Invoke 2x Tithe Boost (4h duration) at Lv. 20 (360/h base -> 720/h boosted)
        expect(c.invokeOffertoryTitheBoost(), isTrue);
        expect(c.isOffertoryBoostActive(), isTrue);
        expect(c.offertoryHourlyRate(), closeTo(720.0, 1e-9));
        // Stay offline 8 hours: 4h @ 720/h (2880) + 4h @ 360/h (1440) = 4320
        fakeNow = fakeNow.add(const Duration(hours: 8));
        expect(c.isOffertoryBoostActive(), isFalse);
        expect(c.isOffertoryFull, isTrue);
        expect(c.offertoryStoredOrbs(), equals(4320));
      },
    );

    test(
      'Phase 1 charges & generates ONLY Fire, Water, Wood; Phase 2+ charges & generates all 5 elements',
      () async {
        DateTime fakeNow = DateTime.utc(2026, 11, 24, 12, 0, 0);
        final h = await _createHarness(
          prefs: {
            'orbs_fire': 500,
            'orbs_water': 500,
            'orbs_wood': 500,
            'orbs_earth': 0,
            'orbs_metal': 0,
            'current_week': 0,
            'enemy_stage': 1,
            'unlockedNewHands': false,
          },
          clock: () => fakeNow,
        );
        addTearDown(h.controller.dispose);
        final c = h.controller;

        // Phase 1: only 3 active elements, can upgrade even with 0 Earth & Metal
        expect(c.includesEarthAndMetalInBonuses, isFalse);
        expect(c.offertoryActiveElements.length, equals(3));
        expect(c.upgradeOffertoryBatch(1), isTrue);
        expect(c.fireOrbs, equals(480));
        expect(c.waterOrbs, equals(480));
        expect(c.woodOrbs, equals(480));
        expect(c.earthOrbs, equals(0));
        expect(c.metalOrbs, equals(0));

        // Generate 1 hour (12 orbs) -> grants ONLY Fire, Water, Wood
        fakeNow = fakeNow.add(const Duration(hours: 1));
        expect(c.collectOffertoryOrbs(), equals(12));
        expect(c.fireOrbs, equals(492));
        expect(c.waterOrbs, equals(492));
        expect(c.woodOrbs, equals(492));
        expect(c.earthOrbs, equals(0));
        expect(c.metalOrbs, equals(0));

        // Transition to Phase 2 (e.g., Week 10 reached)
        c.currentWeek = GameController.phase2StartWeek;
        expect(c.includesEarthAndMetalInBonuses, isTrue);
        expect(c.offertoryActiveElements.length, equals(5));

        // Upgrade now requires Earth & Metal too -> fails while Earth/Metal == 0
        expect(c.upgradeOffertoryBatch(1), isFalse);

        // Give Earth & Metal orbs -> upgrade deducts all 5 elements
        c.earthOrbs = 500;
        c.metalOrbs = 500;
        final lv2Cost = GameController.offertoryUnitCostForTargetLevel(2);
        expect(c.upgradeOffertoryBatch(1), isTrue);
        expect(c.earthOrbs, equals(500 - lv2Cost));
        expect(c.metalOrbs, equals(500 - lv2Cost));

        // Generate 1 hour at Lv. 2 (24/h) -> grants to all 5 elements
        fakeNow = fakeNow.add(const Duration(hours: 1));
        expect(c.collectOffertoryOrbs(), equals(24));
        expect(c.earthOrbs, equals(500 - lv2Cost + 24));
        expect(c.metalOrbs, equals(500 - lv2Cost + 24));
      },
    );

    test(
      'offertoryLevel survives Hero Death (0 HP), Week 40 defeat, and Forfeit Run; merges via highest level in Cloud Save & isolates across accounts',
      () async {
        DateTime fakeNow = DateTime.utc(2026, 11, 24, 12, 0, 0);
        final pgClient = _OffertoryPlayGamesClient(playerId: 'acct_alpha');
        final h = await _createHarness(
          prefs: {
            'orbs_fire': 5000,
            'orbs_water': 5000,
            'orbs_wood': 5000,
          },
          clock: () => fakeNow,
          pgClient: pgClient,
        );
        addTearDown(h.controller.dispose);
        final c = h.controller;

        expect(c.upgradeOffertoryBatch(5), isTrue);
        expect(c.offertoryLevel, equals(5));
        expect(h.storage.offertoryLevel, equals(5));

        // 1. Hero Death (0 HP)
        c.userHp = 0;
        await c.applyPermadeathReset(cause: PermadeathCause.battleDefeat);
        expect(c.offertoryLevel, equals(5));
        expect(h.storage.offertoryLevel, equals(5));

        // 2. Week 40 Defeat
        c.currentWeek = GameController.maxCampaignWeeks;
        await c.applyPermadeathReset(cause: PermadeathCause.deadlineExceeded);
        expect(c.offertoryLevel, equals(5));
        expect(h.storage.offertoryLevel, equals(5));

        // 3. Forfeit Run
        await c.resetAllProgress();
        expect(c.offertoryLevel, equals(5));
        expect(h.storage.offertoryLevel, equals(5));

        // 4. Play Games Cloud Save serialization & highest-level merge
        final localSnap = CloudSaveData.fromStorage(h.storage);
        final roundTripped = CloudSaveData.tryParse(localSnap.toJsonString());
        expect(roundTripped, isNotNull);
        expect(roundTripped!.offertoryLevel, equals(5));

        // Cloud has higher offertoryLevel (12) -> merges to 12
        final higherCloud = CloudSaveData(
          offertoryLevel: 12,
          offertoryLastCollectedAt: fakeNow.millisecondsSinceEpoch,
          offertoryPendingFraction: 0.4,
        );
        pgClient.saves['acct_alpha'] = higherCloud.toJsonString();
        expect(await h.playGames.signIn(silent: true), isTrue);
        expect(c.offertoryLevel, equals(12));
        expect(h.storage.offertoryLevel, equals(12));

        // Multi-account switch to acct_beta with no save -> resets Offertory to Lv. 0
        pgClient.playerId = 'acct_beta';
        expect(await h.playGames.handleAppResumed(), isTrue);
        expect(c.offertoryLevel, equals(0));
        expect(h.storage.offertoryLevel, equals(0));
      },
    );

    test(
      '10% Tithe sacrifice (min 50, 4h duration, 8h cap) and 2x Collect (AdMob onUserEarnedReward & Remove Ads Sanctuary Grace 4h cooldown)',
      () async {
        DateTime fakeNow = DateTime.utc(2026, 11, 24, 12, 0, 0);
        final h = await _createHarness(
          prefs: {
            'orbs_fire': 200,
            'orbs_water': 150,
            'orbs_wood': 40, // below 50 minimum!
          },
          clock: () => fakeNow,
          rewardedAdReady: true,
          earnRewardOnShow: false, // ad dismissed early first
        );
        addTearDown(h.controller.dispose);
        final c = h.controller;

        // Build Lv. 1 (costs 20 each -> balances: 180, 130, 20)
        expect(c.upgradeOffertoryBatch(1), isTrue);
        expect(c.canInvokeOffertoryTitheBoost(), isFalse); // wood < 50

        // Raise wood to 50 -> exact 10% tithe deducts 18 Fire, 13 Water, 5 Wood
        c.woodOrbs = 50;
        expect(c.canInvokeOffertoryTitheBoost(), isTrue);
        expect(c.invokeOffertoryTitheBoost(), isTrue);
        expect(c.fireOrbs, equals(162));
        expect(c.waterOrbs, equals(117));
        expect(c.woodOrbs, equals(45));
        expect(
          c.offertoryBoostRemaining(),
          equals(const Duration(hours: 4)),
        );

        // Extend once more (requires >= 50 each) -> caps at 8 hours total
        c.woodOrbs = 50;
        expect(c.invokeOffertoryTitheBoost(), isTrue);
        expect(
          c.offertoryBoostRemaining(),
          equals(const Duration(hours: 8)),
        );
        // Already at 8h cap -> cannot invoke again until time elapses
        c.woodOrbs = 100;
        expect(c.isOffertoryBoostAtMaxCap(), isTrue);
        expect(c.canInvokeOffertoryTitheBoost(), isFalse);

        // Advance 1 hour with 2x boost at Lv. 1 -> 24 orbs stored
        fakeNow = fakeNow.add(const Duration(hours: 1));
        expect(c.offertoryStoredOrbs(), equals(24));

        // Watch Ad 2x Collect when ad dismissed without reward -> 0 granted, vault intact
        final dismissedRes = await c.watchAdToDoubleCollectOffertory();
        expect(dismissedRes, equals(0));
        expect(c.offertoryStoredOrbs(), equals(24));

        // Watch Ad 2x Collect when reward earned -> grants 48 orbs!
        h.adClient.earnRewardOnShow = true;
        final fireBeforeAd = c.fireOrbs;
        final adRes = await c.watchAdToDoubleCollectOffertory();
        expect(adRes, equals(48));
        expect(c.fireOrbs, equals(fireBeforeAd + 48));
        expect(c.offertoryStoredOrbs(), equals(0));

        // Enable Remove Ads -> Sanctuary Grace 2x Collect works directly with 4h cooldown
        c.unlockedAds = true;
        c.removeAdsEnabled = true;
        fakeNow = fakeNow.add(const Duration(hours: 1));
        expect(c.offertoryStoredOrbs(), equals(24));
        expect(c.canWatchAdDoubleCollectOffertory(), isFalse);
        expect(c.canClaimRemoveAdsDoubleCollectOffertory(), isTrue);

        final fireBeforeGrace = c.fireOrbs;
        expect(c.claimRemoveAdsDoubleCollectOffertory(), equals(48));
        expect(c.fireOrbs, equals(fireBeforeGrace + 48));

        // 1 hour later: Sanctuary Grace still on cooldown, but 1x Collect works
        fakeNow = fakeNow.add(const Duration(hours: 1));
        expect(c.isOffertoryFreeDoubleReady(), isFalse);
        expect(c.canClaimRemoveAdsDoubleCollectOffertory(), isFalse);
        expect(c.collectOffertoryOrbs(multiplier: 1), equals(24));

        // 3 more hours later (4h since grace): Sanctuary Grace ready again
        fakeNow = fakeNow.add(const Duration(hours: 3));
        expect(c.isOffertoryFreeDoubleReady(), isTrue);
        expect(c.canClaimRemoveAdsDoubleCollectOffertory(), isTrue);
      },
    );
  });

  group('Offertory Wing UI, Localizations & WorldMapScreen Badge', () {
    testWidgets(
      'SacredTempleDialog renders 6 tabs, Offertory cards, 3D orbs, MAX confirmation dialog (>=10 lv), Dark/Light mode, and all 4 localizations',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        DateTime fakeNow = DateTime.utc(2026, 11, 24, 12, 0, 0);
        final h = await _createHarness(
          prefs: {
            'orbs_fire': 5000,
            'orbs_water': 5000,
            'orbs_wood': 5000,
          },
          clock: () => fakeNow,
        );
        addTearDown(h.controller.dispose);
        final c = h.controller;

        for (final isDark in [true, false]) {
          c.darkMode = isDark;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: SacredTempleDialog(
                  key: ValueKey('offertory_theme_$isDark'),
                  controller: c,
                  fromTemple: true,
                  initialWing: TempleWing.offertory,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // All 6 tabs exist on a single horizontal row
          const tabKeys = [
            ValueKey('temple_tab_consagration'),
            ValueKey('temple_tab_offerings'),
            ValueKey('temple_tab_transmute'),
            ValueKey('temple_tab_adoration'),
            ValueKey('temple_tab_prayer'),
            ValueKey('temple_tab_offertory'),
          ];
          final firstTop = tester.getTopLeft(find.byKey(tabKeys.first)).dy;
          for (final k in tabKeys) {
            expect(find.byKey(k), findsOneWidget);
            expect(tester.getTopLeft(find.byKey(k)).dy, closeTo(firstTop, 1.0));
          }

          // Bespoke CustomPainter icons & 3D orbs rendered
          expect(find.byType(OffertoryVaultIcon), findsWidgets);
          expect(find.byType(TitheBlessingIcon), findsOneWidget);
          expect(find.byType(ElementalEnergySphere), findsWidgets);
          expect(find.byKey(const ValueKey('offertory_vault_card')), findsOneWidget);
          expect(find.byKey(const ValueKey('offertory_upgrade_card')), findsOneWidget);
          expect(find.byKey(const ValueKey('offertory_tithe_card')), findsOneWidget);
        }

        // Verify all 4 localized tab names
        const expectedTabLabels = {
          'en': 'Offertory',
          'pt': 'Gazofilácio',
          'es': 'Ofertorio',
          'de': 'Opferstock',
        };
        for (final entry in expectedTabLabels.entries) {
          c.setLanguage(entry.key);
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('temple_tab_offertory')),
              matching: find.text(entry.value),
            ),
            findsOneWidget,
          );
        }
        c.setLanguage('en');
        await tester.pumpAndSettle();

        // Select MAX batch (>= 10 affordable levels) -> triggers confirmation modal
        await tester.tap(find.byKey(const ValueKey('offertory_batch_max')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('offertory_next_milestone_badge')),
          findsOneWidget,
        );

        await tester.ensureVisible(
          find.byKey(const ValueKey('offertory_upgrade_button')),
        );
        await tester.tap(find.byKey(const ValueKey('offertory_upgrade_button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('offertory_max_confirm_dialog')),
          findsOneWidget,
        );

        // Confirm MAX upgrade -> upgrades >= 10 levels & shows milestone badge
        await tester.tap(
          find.byKey(const ValueKey('offertory_max_confirm_submit')),
        );
        await tester.pumpAndSettle();
        expect(c.offertoryLevel, greaterThanOrEqualTo(10));
        expect(
          find.byKey(const ValueKey('offertory_milestone_badge')),
          findsOneWidget,
        );

        // Advance 8h -> FULL badge & notification dot appear on Offertory tab pill
        fakeNow = fakeNow.add(const Duration(hours: 8));
        c.notifyListeners();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('offertory_full_badge')), findsOneWidget);
        expect(
          find.byKey(const Key('temple_tab_offertory_dot')),
          findsOneWidget,
        );

        // Collect 1x clears full badge and notification dot
        await tester.ensureVisible(
          find.byKey(const ValueKey('offertory_collect_button')),
        );
        await tester.tap(find.byKey(const ValueKey('offertory_collect_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('offertory_full_badge')), findsNothing);
        expect(
          find.byKey(const Key('temple_tab_offertory_dot')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'WorldMapScreen shows pulsing golden badge on Sacred Temple landmark only when Offertory reaches 8-hour cap',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        DateTime fakeNow = DateTime.utc(2026, 11, 24, 12, 0, 0);
        final h = await _createHarness(
          prefs: {
            'orbs_fire': 500,
            'orbs_water': 500,
            'orbs_wood': 500,
          },
          clock: () => fakeNow,
        );
        addTearDown(h.controller.dispose);
        final c = h.controller;

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: c,
            child: const MaterialApp(home: WorldMapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Lv. 0 -> no badge on Sacred Temple
        expect(
          find.byKey(const ValueKey('sacred_temple_notification_badge')),
          findsNothing,
        );

        // Build Lv. 1 and advance 4h (< 8h) -> still no badge
        expect(c.upgradeOffertoryBatch(1), isTrue);
        fakeNow = fakeNow.add(const Duration(hours: 4));
        c.notifyListeners();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('sacred_temple_notification_badge')),
          findsNothing,
        );

        // Advance 4 more hours (8h total = FULL) -> badge appears on Sacred Temple!
        fakeNow = fakeNow.add(const Duration(hours: 4));
        c.notifyListeners();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('sacred_temple_notification_badge')),
          findsOneWidget,
        );

        // Collect orbs -> badge disappears immediately
        expect(c.collectOffertoryOrbs(), equals(96));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('sacred_temple_notification_badge')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Offertory UI switches cleanly between AdMob Watch Ad (2x Collect) and Remove Ads Sanctuary Grace (no ad prompt), supports 10% Tithe card, and plays parabolic flying 3D orbs animation',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        DateTime fakeNow = DateTime.utc(2026, 11, 24, 12, 0, 0);
        final h = await _createHarness(
          prefs: {
            'orbs_fire': 500,
            'orbs_water': 500,
            'orbs_wood': 500,
            'animationsEnabled': true,
          },
          clock: () => fakeNow,
        );
        addTearDown(h.controller.dispose);
        final c = h.controller;
        expect(c.upgradeOffertoryBatch(1), isTrue);
        fakeNow = fakeNow.add(const Duration(hours: 2)); // 24 orbs stored

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: SacredTempleDialog(
                controller: c,
                fromTemple: true,
                initialWing: TempleWing.offertory,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Non-Remove-Ads mode: shows Watch Ad (2x Collect) + AdMob disclosure
        expect(find.text('Watch Ad (2x Collect)'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('offertory_ad_disclosure_box')),
          findsOneWidget,
        );

        // Tap Watch Ad (2x Collect) -> grants 48 orbs & triggers flying 3D orbs overlay
        final fireBefore = c.fireOrbs;
        await tester.tap(
          find.byKey(const ValueKey('offertory_double_collect_button')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(c.fireOrbs, equals(fireBefore + 48));
        expect(
          find.byKey(const ValueKey('offertory_flying_orbs_overlay')),
          findsOneWidget,
        );
        await tester.pumpAndSettle();

        // Tap Vow of Tithe button -> activates 2x speed & shows live countdown timer
        await tester.ensureVisible(
          find.byKey(const ValueKey('offertory_tithe_button')),
        );
        await tester.tap(find.byKey(const ValueKey('offertory_tithe_button')));
        await tester.pumpAndSettle();
        expect(c.isOffertoryBoostActive(), isTrue);
        expect(find.byKey(const ValueKey('offertory_boost_timer')), findsOneWidget);

        // Switch to Remove Ads active -> AdMob disclosure disappears & Sanctuary Grace shown
        c.unlockedAds = true;
        c.removeAdsEnabled = true;
        fakeNow = fakeNow.add(const Duration(hours: 1)); // 24 orbs stored with 2x boost
        c.notifyListeners();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('offertory_ad_disclosure_box')),
          findsNothing,
        );
        expect(find.text('Watch Ad (2x Collect)'), findsNothing);
        expect(find.text('2x Collect (Sanctuary Grace)'), findsOneWidget);

        // Tap Sanctuary Grace -> grants 48 orbs without invoking AdMob
        final adCallsBefore = h.adClient.showRewardedCalls;
        await tester.ensureVisible(
          find.byKey(const ValueKey('offertory_double_collect_button')),
        );
        await tester.tap(
          find.byKey(const ValueKey('offertory_double_collect_button')),
        );
        await tester.pumpAndSettle();
        expect(h.adClient.showRewardedCalls, equals(adCallsBefore));
        expect(c.isOffertoryFreeDoubleReady(), isFalse);
      },
    );
  });
}
