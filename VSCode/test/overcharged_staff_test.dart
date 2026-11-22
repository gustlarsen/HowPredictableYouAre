import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/models/royal_castle.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/royal_castle_dialog.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/widgets/elemental_energy_sphere.dart';

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
  }) async {}

  @override
  Widget? buildBannerWidget() => null;

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

class _TestPlayGamesClient implements PlayGamesClient {
  String? savedPayload;

  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'StaffTester';

  @override
  Future<String?> getPlayerID() async => 'staff_tester_1';

  @override
  Future<String?> saveGame({
    required String data,
    required String name,
  }) async {
    savedPayload = data;
    return 'success';
  }

  @override
  Future<String?> loadGame({required String name}) async => savedPayload;
}

Future<GameController> _createController({
  Map<String, Object> prefs = const {},
  _TestPlayGamesClient? playGamesClient,
  AudioService? audioService,
}) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_story_intro': true,
    'animationsEnabled': false,
    'musicEnabled': false,
    'soundEnabled': false,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();
  final localization = LocalizationService();
  await localization.load();
  final adService = AdService(client: _TestAdMobClient());
  await adService.initialize(adsRemoved: storage.unlockedAds);

  PlayGamesService? playGames;
  if (playGamesClient != null) {
    playGames = PlayGamesService(storage: storage, client: playGamesClient);
    await playGames.signIn();
  }

  return GameController(
    storage: storage,
    localization: localization,
    audio: audioService ?? AudioService(),
    adService: adService,
    playGames: playGames,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Overcharged Staff Unit, Persistence, Cloud Save & Relic Chamber Tests', () {
    test(
      'Purchasing Levels 1–4 deducts exact elemental orb costs and updates speed tiers & intervals',
      () async {
        final controller = await _createController(
          prefs: {
            'orbs_fire': 2000,
            'orbs_water': 2000,
            'orbs_wood': 2000,
            'orbs_earth': 1000,
            'orbs_metal': 1000,
          },
        );
        addTearDown(controller.dispose);

        expect(controller.overchargedStaffLevel, 0);
        expect(controller.isOverchargedStaffUnlocked, isFalse);
        expect(controller.isOverchargedStaffActive, isFalse);
        expect(
          controller.nextOverchargedStaffUpgradeCost,
          GameController.costOverchargedStaffLv1,
        );

        // Level 1: 100 Fire + 100 Water + 100 Wood -> 1x (750ms)
        expect(controller.unlockOrUpgradeOverchargedStaff(), isTrue);
        expect(controller.overchargedStaffLevel, 1);
        expect(controller.overchargedStaffEnabled, isTrue);
        expect(controller.isOverchargedStaffActive, isTrue);
        expect(controller.overchargedStaffSelectedSpeed, 1);
        expect(controller.overchargedStaffIntervalMs, 750);
        expect(controller.fireOrbs, 1900);
        expect(controller.waterOrbs, 1900);
        expect(controller.woodOrbs, 1900);
        expect(controller.earthOrbs, 1000);
        expect(controller.metalOrbs, 1000);
        expect(controller.selectOverchargedStaffSpeed(2), isFalse);

        // Level 2: 250 Fire + 250 Water + 250 Wood -> auto-selects 2x (375ms)
        expect(controller.unlockOrUpgradeOverchargedStaff(), isTrue);
        expect(controller.overchargedStaffLevel, 2);
        expect(controller.overchargedStaffSelectedSpeed, 2);
        expect(controller.overchargedStaffIntervalMs, 375);
        expect(controller.fireOrbs, 1650);
        expect(controller.waterOrbs, 1650);
        expect(controller.woodOrbs, 1650);
        expect(controller.selectOverchargedStaffSpeed(1), isTrue);
        expect(controller.overchargedStaffIntervalMs, 750);
        expect(controller.selectOverchargedStaffSpeed(5), isFalse);

        // Level 3: 500 F/W/W + 200 E/M -> auto-selects 5x (150ms)
        expect(controller.unlockOrUpgradeOverchargedStaff(), isTrue);
        expect(controller.overchargedStaffLevel, 3);
        expect(controller.overchargedStaffSelectedSpeed, 5);
        expect(controller.overchargedStaffIntervalMs, 150);
        expect(controller.fireOrbs, 1150);
        expect(controller.waterOrbs, 1150);
        expect(controller.woodOrbs, 1150);
        expect(controller.earthOrbs, 800);
        expect(controller.metalOrbs, 800);
        expect(controller.selectOverchargedStaffSpeed(10), isFalse);

        // Level 4 MAX: 1,000 F/W/W + 500 E/M -> auto-selects 10x (75ms)
        expect(controller.unlockOrUpgradeOverchargedStaff(), isTrue);
        expect(controller.overchargedStaffLevel, 4);
        expect(controller.overchargedStaffSelectedSpeed, 10);
        expect(controller.overchargedStaffIntervalMs, 75);
        expect(controller.fireOrbs, 150);
        expect(controller.waterOrbs, 150);
        expect(controller.woodOrbs, 150);
        expect(controller.earthOrbs, 300);
        expect(controller.metalOrbs, 300);
        expect(controller.nextOverchargedStaffUpgradeCost, isNull);
        expect(controller.unlockOrUpgradeOverchargedStaff(), isFalse);

        // Storage persistence check
        expect(controller.storage.overchargedStaffLevel, 4);
        expect(controller.storage.overchargedStaffEnabled, isTrue);
        expect(controller.storage.overchargedStaffSelectedSpeed, 10);
      },
    );

    test(
      'CloudSaveData serializes, compares, and restores Overcharged Staff state',
      () async {
        final controller = await _createController(
          prefs: {
            'overcharged_staff_level': 3,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 5,
          },
        );
        addTearDown(controller.dispose);

        final snapshot = CloudSaveData.fromStorage(controller.storage);
        expect(snapshot.overchargedStaffLevel, 3);
        expect(snapshot.overchargedStaffEnabled, isTrue);
        expect(snapshot.overchargedStaffSelectedSpeed, 5);

        final parsed = CloudSaveData.tryParse(snapshot.toJsonString());
        expect(parsed, isNotNull);
        expect(parsed!.overchargedStaffLevel, 3);
        expect(parsed.overchargedStaffEnabled, isTrue);
        expect(parsed.overchargedStaffSelectedSpeed, 5);
        expect(
          parsed.hasHigherProgressionOrOrbsThan(const CloudSaveData()),
          isTrue,
        );

        SharedPreferences.setMockInitialValues({});
        final freshStorage = StorageService();
        await freshStorage.init();
        await parsed.applyToStorage(freshStorage);
        expect(freshStorage.overchargedStaffLevel, 3);
        expect(freshStorage.overchargedStaffEnabled, isTrue);
        expect(freshStorage.overchargedStaffSelectedSpeed, 5);
      },
    );

    test(
      'Relic Chamber captures and restores Overcharged Staff along with its unlocked level across defeat & resetAllProgress',
      () async {
        final playGamesClient = _TestPlayGamesClient();
        final controller = await _createController(
          playGamesClient: playGamesClient,
          prefs: {
            'overcharged_staff_level': 3,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 5,
            'current_week': 12,
          },
        );
        addTearDown(controller.dispose);

        // Permadeath defeat -> captures 'overcharged_staff:3' in Relic Chamber
        await controller.applyPermadeathReset(
          cause: PermadeathCause.battleDefeat,
        );
        expect(controller.overchargedStaffLevel, 0);
        expect(controller.overchargedStaffEnabled, isFalse);
        expect(controller.storedRelicOverchargedStaffLevel, 3);
        expect(
          controller.availableRelicChamberArtifacts,
          contains(ShopUpgradeArtifact.overchargedStaff),
        );

        // Restore via Relic Chamber -> restores Lv. 3 and unlocks 5x speed
        final restored = await controller.watchAdToRestoreRelics();
        expect(restored, isTrue);
        expect(controller.overchargedStaffLevel, 3);
        expect(controller.overchargedStaffEnabled, isTrue);
        expect(controller.overchargedStaffSelectedSpeed, 5);
        expect(controller.relicChamberStoredUpgrades, isEmpty);

        // Upgrade to Lv. 4 and use resetAllProgress -> captures 'overcharged_staff:4'
        controller.addAllOrbs(1500);
        expect(controller.unlockOrUpgradeOverchargedStaff(), isTrue);
        expect(controller.overchargedStaffLevel, 4);
        await controller.resetAllProgress();
        expect(controller.overchargedStaffLevel, 0);
        expect(controller.storedRelicOverchargedStaffLevel, 4);

        final restoredLv4 = await controller.watchAdToRestoreRelics();
        expect(restoredLv4, isTrue);
        expect(controller.overchargedStaffLevel, 4);
        expect(controller.overchargedStaffSelectedSpeed, 10);
      },
    );

    test('Localization keys for Overcharged Staff exist in en, pt, es, de', () async {
      final loc = LocalizationService();
      await loc.load();
      const keys = [
        'overcharged_staff_title',
        'overcharged_staff_desc',
        'overcharged_staff_speed_label',
        'overcharged_staff_level_prefix',
        'overcharged_staff_max_badge',
        'overcharged_staff_upgrade_lv',
        'overcharged_staff_unlock_action',
      ];
      for (final lang in LocalizationService.supportedLanguages) {
        loc.setLanguage(lang);
        for (final key in keys) {
          final value = loc.t(key);
          expect(value, isNotEmpty, reason: 'Missing $lang $key');
          expect(value, isNot(key), reason: 'Fallback key returned for $lang $key');
        }
      }
    });
  });

  group('Overcharged Staff ShopDialog & RoyalCastleDialog Widget Tests', () {
    for (final isDark in [true, false]) {
      testWidgets(
        'ShopDialog purchases Lv 1-4, displays 1x/2x/5x/10x speed pills, locks, toggle dimming, and MAX badge (${isDark ? "Dark" : "Light"} Mode)',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(380, 760);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final controller = await _createController(
            prefs: {
              'darkMode': isDark,
              'orbs_fire': 2000,
              'orbs_water': 2000,
              'orbs_wood': 2000,
              'orbs_earth': 1000,
              'orbs_metal': 1000,
            },
          );
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            MaterialApp(
              theme: isDark
                  ? ThemeData.dark(useMaterial3: true)
                  : ThemeData.light(useMaterial3: true),
              home: Scaffold(
                body: ShopDialog(controller: controller, fromTemple: true),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const ValueKey('temple_tab_offerings')));
          await tester.pumpAndSettle();

          final scrollable = find.descendant(
            of: find.byKey(const ValueKey('temple_wing_offerings')),
            matching: find.byType(Scrollable),
          );
          final staffCard = find.byKey(
            const ValueKey('shop_overcharged_staff_card'),
          );
          await tester.scrollUntilVisible(
            staffCard,
            180,
            scrollable: scrollable,
          );
          await tester.pumpAndSettle();
          expect(staffCard, findsOneWidget);

          // Locked state: 3D orbs for 100 Fire/Water/Wood on Unlock button
          final upgradeBtn = find.byKey(
            const ValueKey('overcharged_staff_upgrade_button'),
          );
          expect(
            find.descendant(
              of: upgradeBtn,
              matching: find.byType(ElementalEnergySphere),
            ),
            findsNWidgets(3),
          );

          // Purchase Level 1
          await tester.tap(upgradeBtn);
          await tester.pumpAndSettle();
          expect(controller.overchargedStaffLevel, 1);
          expect(controller.overchargedStaffEnabled, isTrue);
          expect(controller.overchargedStaffSelectedSpeed, 1);

          // Speed row visible with 1x active and 2x/5x/10x showing lock icons
          expect(
            find.byKey(const ValueKey('overcharged_staff_speed_row')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('overcharged_staff_speed_row')),
              matching: find.byIcon(Icons.lock_rounded),
            ),
            findsNWidgets(3),
          );

          // Toggle OFF dims speed selector row
          await tester.tap(
            find.byKey(const ValueKey('overcharged_staff_switch')),
          );
          await tester.pumpAndSettle();
          expect(controller.overchargedStaffEnabled, isFalse);
          final dimmedOpacity = tester.widget<AnimatedOpacity>(
            find.byKey(const ValueKey('overcharged_staff_speed_row_opacity')),
          );
          expect(dimmedOpacity.opacity, closeTo(0.45, 0.01));

          // Toggle ON restores opacity to 1.0
          await tester.tap(
            find.byKey(const ValueKey('overcharged_staff_switch')),
          );
          await tester.pumpAndSettle();
          expect(controller.overchargedStaffEnabled, isTrue);
          final activeOpacity = tester.widget<AnimatedOpacity>(
            find.byKey(const ValueKey('overcharged_staff_speed_row_opacity')),
          );
          expect(activeOpacity.opacity, 1.0);

          // Purchase Level 2 -> auto-selects 2x, 2 locks remain (5x, 10x)
          await tester.ensureVisible(upgradeBtn);
          await tester.pumpAndSettle();
          await tester.tap(upgradeBtn);
          await tester.pumpAndSettle();
          expect(controller.overchargedStaffLevel, 2);
          expect(controller.overchargedStaffSelectedSpeed, 2);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('overcharged_staff_speed_row')),
              matching: find.byIcon(Icons.lock_rounded),
            ),
            findsNWidgets(2),
          );

          // Switch back to 1x, then back to 2x
          final speed1x = find.byKey(const ValueKey('overcharged_staff_speed_1x'));
          await tester.ensureVisible(speed1x);
          await tester.pumpAndSettle();
          await tester.tap(speed1x);
          await tester.pumpAndSettle();
          expect(controller.overchargedStaffSelectedSpeed, 1);

          // Purchase Level 3 -> 5x auto-selected, 5 3D orbs shown for Lv. 4 upgrade
          await tester.ensureVisible(upgradeBtn);
          await tester.pumpAndSettle();
          await tester.tap(upgradeBtn);
          await tester.pumpAndSettle();
          expect(controller.overchargedStaffLevel, 3);
          expect(controller.overchargedStaffSelectedSpeed, 5);
          expect(
            find.descendant(
              of: upgradeBtn,
              matching: find.byType(ElementalEnergySphere),
            ),
            findsNWidgets(5),
          );

          // Purchase Level 4 -> 10x auto-selected, MAX badge rendered, no locks
          await tester.ensureVisible(upgradeBtn);
          await tester.pumpAndSettle();
          await tester.tap(upgradeBtn);
          await tester.pumpAndSettle();
          expect(controller.overchargedStaffLevel, 4);
          expect(controller.overchargedStaffSelectedSpeed, 10);
          expect(
            find.byKey(const ValueKey('overcharged_staff_max_badge')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('overcharged_staff_speed_row')),
              matching: find.byIcon(Icons.lock_rounded),
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('RoyalCastleDialog Relic Chamber shows Overcharged Staff with its level', (
      WidgetTester tester,
    ) async {
      final controller = await _createController(
        prefs: {
          'relic_chamber_upgrades': ['overcharged_staff:3'],
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: RoyalCastleDialog(
              controller: controller,
              initialWing: CastleWing.relicChamber,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('relic_chamber_item_overcharged_staff')),
        findsOneWidget,
      );
      expect(find.text('Overcharged Staff (Lv. 3)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('GameScreen Hold-to-Fire, Charge Ring, Haptics & Safety Brake Widget Tests', () {
    testWidgets(
      'Quick tap (< 250ms) fires 1 move immediately without double-firing; Hold (>= 250ms) on Fire fires at selected interval and stops on release',
      (WidgetTester tester) async {
        final controller = await _createController(
          prefs: {
            'overcharged_staff_level': 2,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 2, // 375ms
            'mana_upgrade_level': 100,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: const GameScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fireButton = find.byKey(const ValueKey('hand_button_rock'));
        expect(fireButton, findsOneWidget);

        // 1. Quick tap (< 250ms) -> exactly 1 move
        await tester.tap(fireButton);
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.totalRounds, 1);
        expect(controller.currentUserMove, HandMove.rock);

        // 2. Press & hold >= 250ms at 2x (375ms):
        // t=0: move #2 (initial), t=250: move #3, t=625: move #4, t=1000: move #5
        final center = tester.getCenter(fireButton);
        final gesture = await tester.startGesture(center);
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.totalRounds, 2);
        // Visual charge ring renders while holding
        expect(
          find.byKey(const ValueKey('overcharged_charge_ring_rock')),
          findsOneWidget,
        );

        await tester.pump(const Duration(milliseconds: 155)); // t=255ms
        expect(controller.totalRounds, 3);

        await tester.pump(const Duration(milliseconds: 375)); // t=630ms
        expect(controller.totalRounds, 4);

        await tester.pump(const Duration(milliseconds: 375)); // t=1005ms
        expect(controller.totalRounds, 5);

        // Release finger -> stops immediately and hides charge ring
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 800));
        expect(controller.totalRounds, 5);
        expect(
          find.byKey(const ValueKey('overcharged_charge_ring_rock')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Hold on Earth/Metal (5 elements) and Random button rapid-fires and stops when dragged outside bounds or canceled',
      (WidgetTester tester) async {
        final controller = await _createController(
          prefs: {
            'overcharged_staff_level': 3,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 5, // 150ms
            'unlockedNewHands': true,
            'showNewHands': true,
            'unlockedRandom': true,
            'showRandom': true,
            'mana_upgrade_level': 100,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: const GameScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Hold Metal button (hand_button_spock) then drag pointer outside bounds -> stops immediately
        final metalBtn = find.byKey(const ValueKey('hand_button_spock'));
        expect(metalBtn, findsOneWidget);
        final metalGesture = await tester.startGesture(tester.getCenter(metalBtn));
        await tester.pump(const Duration(milliseconds: 260)); // t=260ms -> 2 moves
        expect(controller.totalRounds, 2);
        expect(controller.currentUserMove, HandMove.spock);

        // Drag far outside Metal button bounds
        await metalGesture.moveTo(const Offset(5, 5));
        await tester.pump(const Duration(milliseconds: 500));
        expect(controller.totalRounds, 2);
        await metalGesture.up();
        await tester.pump();

        // 2. Hold Random button -> rapid-fires at 150ms interval and stops on release
        final randomBtn = find.byKey(const ValueKey('random_move_button'));
        expect(randomBtn, findsOneWidget);
        final randomGesture = await tester.startGesture(tester.getCenter(randomBtn));
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.totalRounds, 3);
        expect(
          find.byKey(const ValueKey('overcharged_charge_ring_random')),
          findsOneWidget,
        );

        await tester.pump(const Duration(milliseconds: 155)); // t=255ms -> +1
        expect(controller.totalRounds, 4);
        await tester.pump(const Duration(milliseconds: 150)); // t=405ms -> +1
        expect(controller.totalRounds, 5);
        await tester.pump(const Duration(milliseconds: 150)); // t=555ms -> +1
        expect(controller.totalRounds, 6);

        await randomGesture.cancel();
        await tester.pump(const Duration(milliseconds: 400));
        expect(controller.totalRounds, 6);
        expect(
          find.byKey(const ValueKey('overcharged_charge_ring_random')),
          findsNothing,
        );
      },
    );

    testWidgets(
      '10x rapid-fire (75ms) throttles light haptic feedback to at most once every ~150ms',
      (WidgetTester tester) async {
        const vibratorChannel = MethodChannel(
          'com.gustlarsen.howpredictable/vibrator',
        );
        final rapidVibrationCalls = <int>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          vibratorChannel,
          (MethodCall call) async {
            if (call.method == 'vibrate') {
              final args = call.arguments as Map?;
              final duration = (args?['duration'] as num?)?.toInt() ?? 0;
              if (duration == AudioService.rapidFireHapticDurationMs) {
                rapidVibrationCalls.add(duration);
              }
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            vibratorChannel,
            null,
          );
        });

        final controller = await _createController(
          prefs: {
            'overcharged_staff_level': 4,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 10, // 75ms
            'vibrationEnabled': true,
            'mana_upgrade_level': 100,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: const GameScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fireBtn = find.byKey(const ValueKey('hand_button_rock'));
        final gesture = await tester.startGesture(tester.getCenter(fireBtn));
        // Advance through 250ms threshold + 4 intervals (4 * 75ms = 300ms -> 5 rapid ticks)
        await tester.pump(const Duration(milliseconds: 255));
        await tester.pump(const Duration(milliseconds: 75));
        await tester.pump(const Duration(milliseconds: 75));
        await tester.pump(const Duration(milliseconds: 75));
        await tester.pump(const Duration(milliseconds: 75));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 200));

        // 6 rounds total (1 initial + 5 rapid ticks), but rapid haptics throttled to 3 (at 255, 405, 555)
        expect(controller.totalRounds, 6);
        expect(rapidVibrationCalls.length, 3);
      },
    );

    testWidgets(
      'Safety brake stops rapid-fire immediately when playerHp <= 5, when enemyHp == 0, or when remainingMana == 0',
      (WidgetTester tester) async {
        // Case A: Critical HP protection (playerHp drops to 5 -> halts immediately)
        final hpController = await _createController(
          prefs: {
            'overcharged_staff_level': 4,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 10, // 75ms
            'userHp': 7,
            'pcScore': 43,
            'total': 43,
            // Force Stage 3 Metal Wizard (100% Metal). Player plays Wood (scissors) -> loses every round!
            'enemy_stage': 3,
            'pcHp': 300,
          },
        );
        addTearDown(hpController.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: hpController,
            child: MaterialApp(
              key: const ValueKey('hp_app'),
              theme: ThemeData.dark(useMaterial3: true),
              home: const GameScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final woodBtn = find.byKey(const ValueKey('hand_button_scissors'));
        final hpGesture = await tester.startGesture(tester.getCenter(woodBtn));
        // Initial press: 7 -> 6 HP. Rapid tick at 250ms: 6 -> 5 HP -> safety brake triggers!
        await tester.pump(const Duration(milliseconds: 100));
        expect(hpController.userHp, 6);
        await tester.pump(const Duration(milliseconds: 160));
        expect(hpController.userHp, 5);
        // Hold for another 500ms: must NOT fire more rounds or drop below 5 HP
        await tester.pump(const Duration(milliseconds: 500));
        expect(hpController.userHp, 5);
        await hpGesture.up();
        await tester.pump();

        // Case B: Boss defeated (enemyHp == 0 -> halts immediately)
        final bossController = await _createController(
          prefs: {
            'overcharged_staff_level': 4,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 10, // 75ms
            'enemy_stage': 3, // 100% Metal -> Fire (rock) beats Metal!
            'pcHp': 2,
            'userScore': 298,
            'total': 298,
            'mana_upgrade_level': 300,
          },
        );
        addTearDown(bossController.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: bossController,
            child: MaterialApp(
              key: const ValueKey('boss_app'),
              theme: ThemeData.dark(useMaterial3: true),
              home: const GameScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fireBtn = find.byKey(const ValueKey('hand_button_rock'));
        final bossGesture = await tester.startGesture(tester.getCenter(fireBtn));
        await tester.pump(const Duration(milliseconds: 100)); // 2 -> 1 HP
        expect(bossController.enemyHp, 1);
        await tester.pump(const Duration(milliseconds: 160)); // 1 -> 0 HP
        expect(bossController.enemyHp, 0);
        expect(bossController.totalRounds, 300);
        await tester.pump(const Duration(milliseconds: 300));
        expect(bossController.totalRounds, 300);
        await bossGesture.up();
        await tester.pumpAndSettle();

        // Case C: Mana reaches 0 (remainingMana == 0 -> halts immediately)
        final manaController = await _createController(
          prefs: {
            'overcharged_staff_level': 4,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 10, // 75ms
            'total': 98, // 2 mana remaining out of 100
          },
        );
        addTearDown(manaController.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: manaController,
            child: MaterialApp(
              key: const ValueKey('mana_app'),
              theme: ThemeData.dark(useMaterial3: true),
              home: const GameScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final waterBtn = find.byKey(const ValueKey('hand_button_paper'));
        final manaGesture = await tester.startGesture(tester.getCenter(waterBtn));
        await tester.pump(const Duration(milliseconds: 100)); // 99 rounds (1 mana left)
        expect(manaController.remainingMana, 1);
        await tester.pump(const Duration(milliseconds: 160)); // 100 rounds (0 mana left)
        expect(manaController.remainingMana, 0);
        expect(manaController.totalRounds, 100);
        await tester.pump(const Duration(milliseconds: 300));
        expect(manaController.totalRounds, 100);
        await manaGesture.up();
        await tester.pumpAndSettle();
      },
    );
  });
}
