import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/notification_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/offline_offertory_dialog.dart';
import 'package:how_predictable/views/dialogs/settings_dialog.dart';
import 'package:how_predictable/views/screens/world_map_screen.dart';
import 'package:how_predictable/views/widgets/elemental_energy_sphere.dart';
import 'package:how_predictable/views/widgets/temple_wing_icons.dart';

class _MockScheduledNotification {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledAtUtc;
  final bool useExactAlarm;
  final String? payload;

  const _MockScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAtUtc,
    required this.useExactAlarm,
    this.payload,
  });
}

class _MockLocalNotificationsClient implements LocalNotificationsClient {
  bool exactAlarmsAllowed;
  int initializeCalls = 0;
  int permissionRequestCalls = 0;
  final List<int> cancelledIds = [];
  final List<_MockScheduledNotification> scheduledHistory = [];
  final Map<int, _MockScheduledNotification> activeScheduled = {};

  _MockLocalNotificationsClient({
    this.exactAlarmsAllowed = false,
  });

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    return true;
  }

  @override
  Future<bool> requestNotificationsPermission() async {
    permissionRequestCalls++;
    return true;
  }

  @override
  Future<bool> canScheduleExactAlarms() async => exactAlarmsAllowed;

  @override
  Future<void> scheduleZonedNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAtUtc,
    required bool useExactAlarm,
    String? payload,
  }) async {
    final entry = _MockScheduledNotification(
      id: id,
      title: title,
      body: body,
      scheduledAtUtc: scheduledAtUtc,
      useExactAlarm: useExactAlarm,
      payload: payload,
    );
    scheduledHistory.add(entry);
    activeScheduled[id] = entry;
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
    activeScheduled.remove(id);
  }
}

class _MockAdMobClient implements AdMobClient {
  bool loadSucceeds;
  bool earnRewardOnShow;
  int showRewardedCalls = 0;

  _MockAdMobClient({
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

class _MockPlayGamesClient implements PlayGamesClient {
  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'Hero';

  @override
  Future<String?> getPlayerID() async => 'player_notif_test';

  @override
  Future<String?> saveGame({
    required String data,
    required String name,
  }) async => 'saved';

  @override
  Future<String?> loadGame({required String name}) async => null;
}

Future<({
  GameController controller,
  StorageService storage,
  AdService adService,
  _MockAdMobClient adClient,
  NotificationService notificationService,
  _MockLocalNotificationsClient notifClient,
})> _createHarness({
  Map<String, Object> prefs = const {},
  required DateTime Function() clock,
  bool rewardedAdReady = true,
  bool earnRewardOnShow = true,
  bool exactAlarmsAllowed = false,
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

  final adClient = _MockAdMobClient(
    loadSucceeds: rewardedAdReady,
    earnRewardOnShow: earnRewardOnShow,
  );
  final adService = AdService(client: adClient);
  await adService.initialize(adsRemoved: false);

  final notifClient = _MockLocalNotificationsClient(
    exactAlarmsAllowed: exactAlarmsAllowed,
  );
  final notificationService = NotificationService(client: notifClient);

  final playGames = PlayGamesService(
    storage: storage,
    client: _MockPlayGamesClient(),
    retryBaseDelay: const Duration(milliseconds: 10),
    profileRetryDelay: Duration.zero,
  );

  final controller = GameController(
    storage: storage,
    localization: localization,
    audio: AudioService(),
    adService: adService,
    playGames: playGames,
    notificationService: notificationService,
    clock: clock,
  );

  return (
    controller: controller,
    storage: storage,
    adService: adService,
    adClient: adClient,
    notificationService: notificationService,
    notifClient: notifClient,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineOffertoryDialog on WorldMapScreen & Anti-Spam Rules', () {
    test('formatOfflineDuration formats minutes and hours cleanly', () {
      expect(
        OfflineOffertoryDialog.formatOfflineDuration(const Duration(minutes: 5)),
        equals('5m'),
      );
      expect(
        OfflineOffertoryDialog.formatOfflineDuration(
          const Duration(hours: 3, minutes: 42),
        ),
        equals('3h 42m'),
      );
      expect(
        OfflineOffertoryDialog.formatOfflineDuration(const Duration(hours: 8)),
        equals('8h 00m'),
      );
    });

    testWidgets(
      'Disables Watch Ad (2x Collect) button when rewarded ad is not ready',
      (WidgetTester tester) async {
        final now = DateTime.utc(2026, 11, 24, 15, 0, 0);
        final pausedAt = DateTime.utc(2026, 11, 24, 12, 0, 0);
        final h = await _createHarness(
          prefs: {
            'offertory_level': 1,
            'offertory_last_collected_at': pausedAt.millisecondsSinceEpoch,
            'last_app_paused_at': pausedAt.millisecondsSinceEpoch,
          },
          clock: () => now,
          rewardedAdReady: false,
        );
        addTearDown(h.controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OfflineOffertoryDialog(
                controller: h.controller,
                offlineDuration: const Duration(hours: 3),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final btn = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('offline_offertory_collect_2x_button')),
        );
        expect(btn.onPressed, isNull);
      },
    );

    testWidgets(
      'Appears automatically on WorldMapScreen after >= 2 minutes offline with formatted duration, 3D orbs, and Collect 1x + reschedules 8h notification',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Player was offline for 1h 12m with Offertory Rate Lv. 1 (12/h -> 14.4 orbs -> 14 whole orbs) at base Cap Lv. 0 (2h 00m)
        final now = DateTime.utc(2026, 11, 24, 13, 12, 0);
        final pausedAt = DateTime.utc(2026, 11, 24, 12, 0, 0);
        final h = await _createHarness(
          prefs: {
            'offertory_level': 1,
            'offertory_last_collected_at': pausedAt.millisecondsSinceEpoch,
            'last_app_paused_at': pausedAt.millisecondsSinceEpoch,
            'orbs_fire': 100,
            'orbs_water': 100,
            'orbs_wood': 100,
          },
          clock: () => now,
        );
        addTearDown(h.controller.dispose);
        final c = h.controller;

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: c,
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: const WorldMapScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Dialog appears automatically with Welcome Back title, icon, 2h base cap fill progress & single-row 3D orbs
        expect(
          find.byKey(const ValueKey('offline_offertory_dialog')),
          findsOneWidget,
        );
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.byType(OffertoryVaultIcon), findsOneWidget);
        expect(find.text('Welcome Back!'), findsOneWidget);
        // 1h 12m = 72m / 120m = 60% Full
        expect(find.text('Offline for 1h 12m • 60% Full'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('offline_offertory_fill_progress')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('offline_offertory_orbs_row')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('offline_offertory_sphere_fire')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('offline_offertory_sphere_water')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('offline_offertory_sphere_wood')),
          findsOneWidget,
        );
        expect(find.byType(ElementalEnergySphere), findsNWidgets(3));
        expect(find.text('+14'), findsNWidgets(3));
        // Separate 2x pill & redundant Later footer button are removed
        expect(
          find.byKey(const ValueKey('offline_offertory_2x_preview')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('offline_offertory_later_button')),
          findsNothing,
        );

        // Unified 2x hero button shows Watch Ad • 2x Collect + exact doubled/bonus breakdown
        expect(find.text('Watch Ad • 2x Collect'), findsOneWidget);
        expect(find.text('+28 per element (+14 bonus)'), findsOneWidget);
        // Secondary button shows Collect (+14 each)
        expect(find.text('Collect (+14 each)'), findsOneWidget);

        // Tap Collect (1x) -> grants 14 orbs per active element, preserves ~0.4 remainder, closes dialog & reschedules 2h notification
        await tester.tap(
          find.byKey(const ValueKey('offline_offertory_collect_1x_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('offline_offertory_dialog')),
          findsNothing,
        );
        expect(c.fireOrbs, equals(114));
        expect(c.waterOrbs, equals(114));
        expect(c.woodOrbs, equals(114));
        expect(c.offertoryPendingFraction, closeTo(0.4, 0.01));

        // Verify notification 1001 was cancelled and rescheduled for 2 hours ahead (base Cap Lv. 0)
        expect(
          h.notifClient.cancelledIds,
          contains(NotificationService.offertoryFullNotificationId),
        );
        final scheduled = h.notifClient.activeScheduled[
          NotificationService.offertoryFullNotificationId
        ];
        expect(scheduled, isNotNull);
        expect(
          scheduled!.scheduledAtUtc.difference(now),
          equals(const Duration(hours: 2)),
        );
        expect(scheduled.title, equals('Offertory Vault Full!'));
        expect(scheduled.useExactAlarm, isFalse);
      },
    );

    testWidgets(
      'Shows golden 8h 00m • 100% FULL (Paused) bar in Light Mode (#F5EFE2) for Phase 2+ (5 elements) on single row without scroll, and respects Watch Ad (2x) inside onUserEarnedReward',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Away for 10 hours (> 8h cap at Cap Lv. 12) in Phase 2 (enemy_stage = 2 -> 5 elements)
        // High level (Lv. 30 with +75% milestone = 630/h -> 5,040 orbs at 8h cap) to verify 4/5-digit single-row fit on 360dp width
        final now = DateTime.utc(2026, 11, 24, 22, 0, 0);
        final pausedAt = DateTime.utc(2026, 11, 24, 12, 0, 0);
        final h = await _createHarness(
          prefs: {
            'darkMode': false,
            'enemy_stage': 2,
            'offertory_level': 30,
            'offertory_cap_level': 12, // 120 + 12*30 = 480m = 8h 00m cap
            'offertory_last_collected_at': pausedAt.millisecondsSinceEpoch,
            'last_app_paused_at': pausedAt.millisecondsSinceEpoch,
            'orbs_fire': 10,
            'orbs_water': 10,
            'orbs_wood': 10,
            'orbs_earth': 10,
            'orbs_metal': 10,
          },
          clock: () => now,
          rewardedAdReady: true,
          earnRewardOnShow: false, // First attempt: user closes ad early!
        );
        addTearDown(h.controller.dispose);
        final c = h.controller;

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: c,
            child: MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              home: const WorldMapScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Verify Light Mode parchment surface (#F5EFE2) and zero vertical scrolling
        final dialogWidget = tester.widget<Dialog>(
          find.byKey(const ValueKey('offline_offertory_dialog')),
        );
        expect(dialogWidget.backgroundColor, equals(const Color(0xFFF5EFE2)));
        expect(find.byType(SingleChildScrollView), findsNothing);

        // Verify capped 8h 00m • 100% FULL (Paused) & all 5 active elements in a single horizontal Row
        expect(
          find.text('Offline for 8h 00m • 100% FULL (Paused)'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('offline_offertory_orbs_row')),
          findsOneWidget,
        );
        expect(find.byType(ElementalEnergySphere), findsNWidgets(5));
        final orbCentersY = GameController.allElementPool
            .map(
              (move) => tester
                  .getCenter(
                    find.byKey(ValueKey('offline_offertory_orb_${move.orbKey}')),
                  )
                  .dy,
            )
            .toSet();
        expect(orbCentersY.length, equals(1));

        expect(find.text('+5,040'), findsNWidgets(5));
        expect(find.text('Watch Ad • 2x Collect'), findsOneWidget);
        expect(
          find.text('+10,080 per element (+5,040 bonus)'),
          findsOneWidget,
        );
        expect(find.text('Collect (+5,040 each)'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('offline_offertory_ad_disclosure')),
          findsOneWidget,
        );

        // 1. User dismisses rewarded ad early -> 0 orbs granted, dialog stays open
        await tester.tap(
          find.byKey(const ValueKey('offline_offertory_collect_2x_button')),
        );
        await tester.pumpAndSettle();
        expect(h.adClient.showRewardedCalls, equals(1));
        expect(c.fireOrbs, equals(10));
        expect(c.earthOrbs, equals(10));
        expect(c.metalOrbs, equals(10));
        expect(
          find.byKey(const ValueKey('offline_offertory_dialog')),
          findsOneWidget,
        );

        // 2. User completes rewarded ad -> onUserEarnedReward grants 2x (10,080 orbs per element) & closes dialog
        h.adClient.earnRewardOnShow = true;
        await tester.tap(
          find.byKey(const ValueKey('offline_offertory_collect_2x_button')),
        );
        await tester.pumpAndSettle();
        expect(h.adClient.showRewardedCalls, equals(2));
        expect(c.fireOrbs, equals(10 + 10080));
        expect(c.waterOrbs, equals(10 + 10080));
        expect(c.woodOrbs, equals(10 + 10080));
        expect(c.earthOrbs, equals(10 + 10080));
        expect(c.metalOrbs, equals(10 + 10080));
        expect(
          find.byKey(const ValueKey('offline_offertory_dialog')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Ticks live every second when under 8h cap and updates orb counts & fill percentage in real time',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Lv. 20 (with +50% milestone = 360/h = 0.1 orbs/sec) at Cap Lv. 12 (8h 00m cap) -> 2h = 720 orbs, 25% Full
        DateTime fakeNow = DateTime.utc(2026, 11, 24, 14, 0, 0);
        final pausedAt = DateTime.utc(2026, 11, 24, 12, 0, 0);
        final h = await _createHarness(
          prefs: {
            'offertory_level': 20,
            'offertory_cap_level': 12,
            'offertory_last_collected_at': pausedAt.millisecondsSinceEpoch,
            'last_app_paused_at': pausedAt.millisecondsSinceEpoch,
          },
          clock: () => fakeNow,
        );
        addTearDown(h.controller.dispose);
        final c = h.controller;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: OfflineOffertoryDialog(
                controller: c,
                offlineDuration: const Duration(hours: 2),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Offline for 2h 00m • 25% Full'), findsOneWidget);
        expect(find.text('+720'), findsNWidgets(3));
        expect(find.text('+1,440 per element (+720 bonus)'), findsOneWidget);
        expect(find.text('Collect (+720 each)'), findsOneWidget);

        // Advance fake clock by 60 seconds and pump 1s timer tick -> 726 orbs!
        fakeNow = fakeNow.add(const Duration(seconds: 60));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('+726'), findsNWidgets(3));
        expect(find.text('+1,452 per element (+726 bonus)'), findsOneWidget);
        expect(find.text('Collect (+726 each)'), findsOneWidget);
      },
    );

    testWidgets(
      'Respects Remove Ads: shows Sanctuary Grace • 2x Collect off cooldown without ad prompts, and hides 2x button cleanly while on 4h cooldown',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        DateTime fakeNow = DateTime.utc(2026, 11, 24, 14, 0, 0);
        final pausedAt = DateTime.utc(2026, 11, 24, 12, 0, 0); // 2h -> 24 orbs
        final h = await _createHarness(
          prefs: {
            'unlockedAds': true,
            'removeAdsEnabled': true,
            'offertory_level': 1,
            'offertory_last_collected_at': pausedAt.millisecondsSinceEpoch,
            'last_app_paused_at': pausedAt.millisecondsSinceEpoch,
            'orbs_fire': 50,
            'orbs_water': 50,
            'orbs_wood': 50,
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

        // Remove Ads active & off cooldown -> shows Sanctuary Grace, ZERO ad prompts
        expect(find.text('Sanctuary Grace • 2x Collect'), findsOneWidget);
        expect(find.text('+48 per element (+24 bonus)'), findsOneWidget);
        expect(find.text('Watch Ad • 2x Collect'), findsNothing);
        expect(
          find.byKey(const ValueKey('offline_offertory_ad_disclosure')),
          findsNothing,
        );

        // Claim Sanctuary Grace -> 2x (48 orbs) granted with 0 ad calls
        await tester.tap(
          find.byKey(const ValueKey('offline_offertory_collect_2x_button')),
        );
        await tester.pumpAndSettle();
        expect(h.adClient.showRewardedCalls, equals(0));
        expect(c.fireOrbs, equals(98));
        expect(c.isOffertoryFreeDoubleReady(), isFalse);

        // Pause & resume 1 hour later (still inside 4h Sanctuary Grace cooldown; 1h / 2h base cap = 50% Full)
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        fakeNow = fakeNow.add(const Duration(hours: 1));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();

        // Dialog re-appears on resume, 2x button is cleanly hidden during cooldown
        expect(
          find.byKey(const ValueKey('offline_offertory_dialog')),
          findsOneWidget,
        );
        expect(find.text('Offline for 1h 00m • 50% Full'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('offline_offertory_collect_2x_button')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('offline_offertory_ad_disclosure')),
          findsNothing,
        );
        expect(find.text('Watch Ad • 2x Collect'), findsNothing);
      },
    );

    testWidgets(
      'Anti-spam guards: blocks popup under 2 minutes, blocks when dismissed in same session, and does not open over another modal dialog',
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
            'offertory_level': 10, // high rate so even 1 minute yields >= 1 orb
            'offertory_last_collected_at': fakeNow.millisecondsSinceEpoch,
            'last_app_paused_at': fakeNow.millisecondsSinceEpoch,
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
        expect(
          find.byKey(const ValueKey('offline_offertory_dialog')),
          findsNothing,
        );

        // 1. Away for only 119 seconds (< 2 minutes) -> MUST NOT open
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        fakeNow = fakeNow.add(const Duration(seconds: 119));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('offline_offertory_dialog')),
          findsNothing,
        );

        // 2. Away for 10 minutes -> opens, then dismissing via top-right X prevents re-opening during same session
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        fakeNow = fakeNow.add(const Duration(minutes: 10));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('offline_offertory_dialog')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('offline_offertory_close_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('offline_offertory_dialog')),
          findsNothing,
        );
        c.notifyListeners();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('offline_offertory_dialog')),
          findsNothing,
        );

        // 3. Open SettingsDialog (blocking modal), pause & resume 10 minutes later -> must NOT stack OfflineOffertoryDialog over SettingsDialog
        await tester.tap(
          find.byKey(const ValueKey('world_map_settings_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SettingsDialog), findsOneWidget);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        fakeNow = fakeNow.add(const Duration(minutes: 10));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('offline_offertory_dialog')),
          findsNothing,
        );
      },
    );

    test('All 4 languages (en, pt, es, de) have refined OfflineOffertoryDialog strings', () async {
      final loc = LocalizationService();
      await loc.load();
      for (final lang in LocalizationService.supportedLanguages) {
        loc.setLanguage(lang);
        for (final key in const [
          'offertory_offline_duration_progress',
          'offertory_offline_storage_full',
          'offertory_watch_ad_2x_hero_title',
          'offertory_sanctuary_grace_2x_hero_title',
          'offertory_offline_2x_subline',
          'offertory_collect_each_btn',
        ]) {
          final val = loc.t(key);
          expect(val, isNot(equals(key)), reason: 'Missing $lang/$key');
          expect(val.trim(), isNotEmpty, reason: 'Empty $lang/$key');
        }
      }
    });
  });

  group('Local Notification Scheduling, Permission & SettingsDialog Toggle', () {
    test(
      'Requests permission contextually on first Offertory build (Lv. 0 -> Lv. 1), reschedules on collect & tithe boost, and localizes in pt/es/de',
      () async {
        DateTime fakeNow = DateTime.utc(2026, 11, 24, 12, 0, 0);
        final h = await _createHarness(
          prefs: {
            'orbs_fire': 500,
            'orbs_water': 500,
            'orbs_wood': 500,
          },
          clock: () => fakeNow,
          exactAlarmsAllowed: true,
        );
        addTearDown(h.controller.dispose);
        final c = h.controller;

        // Startup with Lv. 0: initializes plugin, cancels any stale alert, does NOT request permission prematurely
        await c.initializeNotifications();
        expect(h.notifClient.initializeCalls, greaterThanOrEqualTo(1));
        expect(h.notifClient.permissionRequestCalls, equals(0));
        expect(h.notifClient.activeScheduled, isEmpty);

        // First upgrade Lv. 0 -> Lv. 1: requests permission contextually and schedules 2h base cap notification
        expect(c.upgradeOffertoryBatch(1), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(h.notifClient.permissionRequestCalls, equals(1));
        final firstNotif = h.notifClient.activeScheduled[
          NotificationService.offertoryFullNotificationId
        ];
        expect(firstNotif, isNotNull);
        expect(
          firstNotif!.scheduledAtUtc,
          equals(fakeNow.add(const Duration(hours: 2))),
        );
        expect(firstNotif.useExactAlarm, isTrue);

        // Advance 1 hour, collect orbs (12 orbs) -> cancels old 1001 and schedules fresh 2h from new timestamp
        fakeNow = fakeNow.add(const Duration(hours: 1));
        expect(c.collectOffertoryOrbs(), equals(12));
        await Future<void>.delayed(Duration.zero);
        final afterCollect = h.notifClient.activeScheduled[
          NotificationService.offertoryFullNotificationId
        ];
        expect(afterCollect, isNotNull);
        expect(
          afterCollect!.scheduledAtUtc,
          equals(fakeNow.add(const Duration(hours: 2))),
        );

        // Switch language to Portuguese -> reschedules with localized Gazofilácio title & body
        c.setLanguage('pt');
        await Future<void>.delayed(Duration.zero);
        final ptNotif = h.notifClient.activeScheduled[
          NotificationService.offertoryFullNotificationId
        ];
        expect(ptNotif, isNotNull);
        expect(ptNotif!.title, equals('Gazofilácio Cheio!'));
        expect(ptNotif.body, contains('Gazofilácio do Templo'));

        // Advance 2 hours (100% full, remaining == 0s <= 60s) -> cancels notification rather than scheduling in past
        fakeNow = fakeNow.add(const Duration(hours: 2));
        await c.syncOffertoryFullNotification();
        expect(h.notifClient.activeScheduled, isEmpty);
      },
    );

    testWidgets(
      'SettingsDialog toggles Offertory Full Notification OFF to cancel pending notification and ON to request permission and reschedule',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime.utc(2026, 11, 24, 12, 0, 0);
        final h = await _createHarness(
          prefs: {
            'offertory_level': 1,
            'offertory_last_collected_at': now.millisecondsSinceEpoch,
            'last_app_paused_at': now.millisecondsSinceEpoch,
          },
          clock: () => now,
        );
        addTearDown(h.controller.dispose);
        final c = h.controller;
        await c.initializeNotifications();
        expect(
          h.notifClient.activeScheduled[
            NotificationService.offertoryFullNotificationId
          ],
          isNotNull,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsDialog(controller: c),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final toggleFinder = find.byKey(
          const ValueKey('settings_offertory_notifications_tile'),
        );
        await tester.ensureVisible(toggleFinder);
        expect(toggleFinder, findsOneWidget);
        expect(find.text('Offertory Full Notification'), findsOneWidget);
        expect(c.offertoryNotificationsEnabled, isTrue);

        // Toggle OFF -> persists false & immediately cancels pending notification 1001
        await tester.tap(toggleFinder);
        await tester.pumpAndSettle();
        expect(c.offertoryNotificationsEnabled, isFalse);
        expect(h.storage.offertoryNotificationsEnabled, isFalse);
        expect(h.notifClient.activeScheduled, isEmpty);

        // Toggle back ON -> persists true, requests permission & reschedules 1001
        final permCallsBefore = h.notifClient.permissionRequestCalls;
        await tester.tap(toggleFinder);
        await tester.pumpAndSettle();
        expect(c.offertoryNotificationsEnabled, isTrue);
        expect(h.storage.offertoryNotificationsEnabled, isTrue);
        expect(h.notifClient.permissionRequestCalls, equals(permCallsBefore + 1));
        expect(
          h.notifClient.activeScheduled[
            NotificationService.offertoryFullNotificationId
          ],
          isNotNull,
        );
      },
    );

    testWidgets(
      'OfflineOffertoryDialog honors high uncapped Max Offline Time Cap (Lv. 20 = 12h & Lv. 50 = 27h) for orbs, fill %, clamping, and post-collect notification rescheduling',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Rate Lv. 1 (12/h) + Cap Lv. 50 (120 + 50*30 = 1620m = 27h 00m Cap); away for 20h -> 240 orbs, 74% Full!
        final pausedAt = DateTime.utc(2026, 11, 24, 12, 0, 0);
        DateTime fakeNow = pausedAt.add(const Duration(hours: 20));
        final h = await _createHarness(
          prefs: {
            'offertory_rate_level': 1,
            'offertory_cap_level': 50, // 27h 00m cap (uncapped!)
            'offertory_last_collected_at': pausedAt.millisecondsSinceEpoch,
            'last_app_paused_at': pausedAt.millisecondsSinceEpoch,
            'orbs_fire': 100,
            'orbs_water': 100,
            'orbs_wood': 100,
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

        expect(
          find.byKey(const ValueKey('offline_offertory_dialog')),
          findsOneWidget,
        );
        // 20h / 27h = 74.07% -> 74% Full, 240 orbs per element
        expect(find.text('Offline for 20h 00m • 74% Full'), findsOneWidget);
        expect(find.text('+240'), findsNWidgets(3));
        expect(find.text('Collect (+240 each)'), findsOneWidget);

        // Collect 1x -> grants 240 orbs & reschedules notification for 27h ahead
        await tester.tap(
          find.byKey(const ValueKey('offline_offertory_collect_1x_button')),
        );
        await tester.pumpAndSettle();
        expect(c.fireOrbs, equals(340));
        final scheduled = h.notifClient.activeScheduled[
          NotificationService.offertoryFullNotificationId
        ];
        expect(scheduled, isNotNull);
        expect(
          scheduled!.scheduledAtUtc.difference(fakeNow),
          equals(const Duration(hours: 27)),
        );

        // Now go offline 30h (> 27h Cap) -> clamped to 27h 00m • 100% FULL (Paused) & +324 orbs
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        fakeNow = fakeNow.add(const Duration(hours: 30));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Offline for 27h 00m • 100% FULL (Paused)'),
          findsOneWidget,
        );
        expect(find.text('+324'), findsNWidgets(3));
      },
    );

    test(
      'Reschedules local notification accurately when Offline Cap (+30m/lv) or Consecration Rate is upgraded (mid-interval, while FULL, and at high uncapped levels)',
      () async {
        DateTime fakeNow = DateTime.utc(2026, 11, 24, 12, 0, 0);
        final h = await _createHarness(
          prefs: {
            'orbs_fire': 100000000,
            'orbs_water': 100000000,
            'orbs_wood': 100000000,
          },
          clock: () => fakeNow,
          exactAlarmsAllowed: true,
        );
        addTearDown(h.controller.dispose);
        final c = h.controller;

        // 1. Build Rate Lv. 1 at Cap Lv. 0 (2h 00m Cap) -> schedules at t + 2h
        expect(c.upgradeOffertoryRateBatch(1), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(
          h.notifClient
              .activeScheduled[NotificationService.offertoryFullNotificationId]
              ?.scheduledAtUtc,
          equals(fakeNow.add(const Duration(hours: 2))),
        );

        // 2. Advance 1h, upgrade Offline Cap Lv. 0 -> Lv. 1 (2h 30m Cap) -> reschedules for now + 1h 30m
        fakeNow = fakeNow.add(const Duration(hours: 1));
        expect(c.upgradeOffertoryCap(), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(
          h.notifClient
              .activeScheduled[NotificationService.offertoryFullNotificationId]
              ?.scheduledAtUtc,
          equals(fakeNow.add(const Duration(hours: 1, minutes: 30))),
        );

        // 3. Advance 30m, upgrade Consecration Rate Lv. 1 -> Lv. 2 -> reschedules for now + 1h
        fakeNow = fakeNow.add(const Duration(minutes: 30));
        expect(c.upgradeOffertoryRateBatch(1), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(
          h.notifClient
              .activeScheduled[NotificationService.offertoryFullNotificationId]
              ?.scheduledAtUtc,
          equals(fakeNow.add(const Duration(hours: 1))),
        );

        // 4. Advance 2h (past 2h 30m cap -> FULL -> notification cancelled)
        fakeNow = fakeNow.add(const Duration(hours: 2));
        await c.syncOffertoryFullNotification();
        expect(h.notifClient.activeScheduled, isEmpty);

        // 5. Expand Cap while FULL (2h 30m -> 3h 00m) -> immediately schedules notification for now + 30m!
        expect(c.upgradeOffertoryCap(), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(
          h.notifClient
              .activeScheduled[NotificationService.offertoryFullNotificationId]
              ?.scheduledAtUtc,
          equals(fakeNow.add(const Duration(minutes: 30))),
        );

        // 6. Bulk expand Cap by 48 levels (Lv. 2 -> Lv. 50 = 27h 00m) -> remaining = 27h - 2h 30m = 24h 30m!
        expect(c.upgradeOffertoryCap(levels: 48), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(
          h.notifClient
              .activeScheduled[NotificationService.offertoryFullNotificationId]
              ?.scheduledAtUtc,
          equals(fakeNow.add(const Duration(hours: 24, minutes: 30))),
        );
      },
    );
  });
}
