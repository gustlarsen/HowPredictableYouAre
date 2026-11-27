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
      'Purchasing Levels 1–6 deducts exact elemental orb costs and updates speed tiers & intervals',
      () async {
        final controller = await _createController(
          prefs: {
            'orbs_fire': 8000,
            'orbs_water': 8000,
            'orbs_wood': 8000,
            'orbs_earth': 4000,
            'orbs_metal': 4000,
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
        expect(controller.fireOrbs, 7900);
        expect(controller.waterOrbs, 7900);
        expect(controller.woodOrbs, 7900);
        expect(controller.earthOrbs, 4000);
        expect(controller.metalOrbs, 4000);
        expect(controller.selectOverchargedStaffSpeed(2), isFalse);

        // Level 2: 250 Fire + 250 Water + 250 Wood -> auto-selects 2x (375ms)
        expect(controller.unlockOrUpgradeOverchargedStaff(), isTrue);
        expect(controller.overchargedStaffLevel, 2);
        expect(controller.overchargedStaffSelectedSpeed, 2);
        expect(controller.overchargedStaffIntervalMs, 375);
        expect(controller.fireOrbs, 7650);
        expect(controller.waterOrbs, 7650);
        expect(controller.woodOrbs, 7650);
        expect(controller.selectOverchargedStaffSpeed(1), isTrue);
        expect(controller.overchargedStaffIntervalMs, 750);
        expect(controller.selectOverchargedStaffSpeed(5), isFalse);

        // Level 3: 500 F/W/W + 200 E/M -> auto-selects 5x (150ms)
        expect(controller.unlockOrUpgradeOverchargedStaff(), isTrue);
        expect(controller.overchargedStaffLevel, 3);
        expect(controller.overchargedStaffSelectedSpeed, 5);
        expect(controller.overchargedStaffIntervalMs, 150);
        expect(controller.fireOrbs, 7150);
        expect(controller.waterOrbs, 7150);
        expect(controller.woodOrbs, 7150);
        expect(controller.earthOrbs, 3800);
        expect(controller.metalOrbs, 3800);
        expect(controller.selectOverchargedStaffSpeed(10), isFalse);

        // Level 4: 1,000 F/W/W + 500 E/M -> auto-selects 10x (75ms)
        expect(controller.unlockOrUpgradeOverchargedStaff(), isTrue);
        expect(controller.overchargedStaffLevel, 4);
        expect(controller.overchargedStaffSelectedSpeed, 10);
        expect(controller.overchargedStaffIntervalMs, 75);
        expect(controller.fireOrbs, 6150);
        expect(controller.waterOrbs, 6150);
        expect(controller.woodOrbs, 6150);
        expect(controller.earthOrbs, 3300);
        expect(controller.metalOrbs, 3300);
        expect(controller.selectOverchargedStaffSpeed(20), isFalse);

        // Level 5: 2,000 F/W/W + 1,000 E/M -> auto-selects 20x (38ms)
        expect(controller.unlockOrUpgradeOverchargedStaff(), isTrue);
        expect(controller.overchargedStaffLevel, 5);
        expect(controller.overchargedStaffSelectedSpeed, 20);
        expect(controller.overchargedStaffIntervalMs, 38);
        expect(controller.fireOrbs, 4150);
        expect(controller.waterOrbs, 4150);
        expect(controller.woodOrbs, 4150);
        expect(controller.earthOrbs, 2300);
        expect(controller.metalOrbs, 2300);
        expect(controller.selectOverchargedStaffSpeed(30), isFalse);

        // Level 6 MAX: 3,500 F/W/W + 2,000 E/M -> auto-selects 30x (25ms)
        expect(controller.unlockOrUpgradeOverchargedStaff(), isTrue);
        expect(controller.overchargedStaffLevel, 6);
        expect(controller.overchargedStaffSelectedSpeed, 30);
        expect(controller.overchargedStaffIntervalMs, 25);
        expect(controller.fireOrbs, 650);
        expect(controller.waterOrbs, 650);
        expect(controller.woodOrbs, 650);
        expect(controller.earthOrbs, 300);
        expect(controller.metalOrbs, 300);
        expect(controller.nextOverchargedStaffUpgradeCost, isNull);
        expect(controller.unlockOrUpgradeOverchargedStaff(), isFalse);

        // Free switching among all 6 unlocked speeds
        for (final speed in const [1, 2, 5, 10, 20, 30]) {
          expect(controller.selectOverchargedStaffSpeed(speed), isTrue);
          expect(controller.overchargedStaffSelectedSpeed, speed);
        }

        // Storage persistence check
        expect(controller.storage.overchargedStaffLevel, 6);
        expect(controller.storage.overchargedStaffEnabled, isTrue);
        expect(controller.storage.overchargedStaffSelectedSpeed, 30);
      },
    );

    test(
      'CloudSaveData serializes, compares, and restores Overcharged Staff Levels 1–6 and 30x speed',
      () async {
        final controller = await _createController(
          prefs: {
            'overcharged_staff_level': 6,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 30,
          },
        );
        addTearDown(controller.dispose);

        final snapshot = CloudSaveData.fromStorage(controller.storage);
        expect(snapshot.overchargedStaffLevel, 6);
        expect(snapshot.overchargedStaffEnabled, isTrue);
        expect(snapshot.overchargedStaffSelectedSpeed, 30);

        final parsed = CloudSaveData.tryParse(snapshot.toJsonString());
        expect(parsed, isNotNull);
        expect(parsed!.overchargedStaffLevel, 6);
        expect(parsed.overchargedStaffEnabled, isTrue);
        expect(parsed.overchargedStaffSelectedSpeed, 30);
        expect(
          parsed.hasHigherProgressionOrOrbsThan(const CloudSaveData()),
          isTrue,
        );

        SharedPreferences.setMockInitialValues({});
        final freshStorage = StorageService();
        await freshStorage.init();
        await parsed.applyToStorage(freshStorage);
        expect(freshStorage.overchargedStaffLevel, 6);
        expect(freshStorage.overchargedStaffEnabled, isTrue);
        expect(freshStorage.overchargedStaffSelectedSpeed, 30);
      },
    );

    test(
      'Relic Chamber captures and restores Overcharged Staff along with its unlocked level up to Lv. 6 across defeat & resetAllProgress',
      () async {
        final playGamesClient = _TestPlayGamesClient();
        final controller = await _createController(
          playGamesClient: playGamesClient,
          prefs: {
            'overcharged_staff_level': 5,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 20,
            'current_week': 12,
          },
        );
        addTearDown(controller.dispose);

        // Permadeath defeat -> captures 'overcharged_staff:5' in Relic Chamber
        await controller.applyPermadeathReset(
          cause: PermadeathCause.battleDefeat,
        );
        expect(controller.overchargedStaffLevel, 0);
        expect(controller.overchargedStaffEnabled, isFalse);
        expect(controller.storedRelicOverchargedStaffLevel, 5);
        expect(
          controller.availableRelicChamberArtifacts,
          contains(ShopUpgradeArtifact.overchargedStaff),
        );

        // Restore via Relic Chamber -> restores Lv. 5 and unlocks 20x speed
        final restored = await controller.watchAdToRestoreRelics();
        expect(restored, isTrue);
        expect(controller.overchargedStaffLevel, 5);
        expect(controller.overchargedStaffEnabled, isTrue);
        expect(controller.overchargedStaffSelectedSpeed, 20);
        expect(controller.relicChamberStoredUpgrades, isEmpty);

        // Upgrade to Lv. 6 and use resetAllProgress -> captures 'overcharged_staff:6'
        controller.addAllOrbs(4000);
        expect(controller.unlockOrUpgradeOverchargedStaff(), isTrue);
        expect(controller.overchargedStaffLevel, 6);
        await controller.resetAllProgress();
        expect(controller.overchargedStaffLevel, 0);
        expect(controller.storedRelicOverchargedStaffLevel, 6);

        final restoredLv6 = await controller.watchAdToRestoreRelics();
        expect(restoredLv6, isTrue);
        expect(controller.overchargedStaffLevel, 6);
        expect(controller.overchargedStaffSelectedSpeed, 30);
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
        'ShopDialog purchases Lv 1-6 on 360dp width, renders 1x/2x/5x/10x/20x/30x single-row pills without overflow, locks, toggle dimming, and MAX badge (${isDark ? "Dark" : "Light"} Mode)',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 760);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final controller = await _createController(
            prefs: {
              'darkMode': isDark,
              'orbs_fire': 8000,
              'orbs_water': 8000,
              'orbs_wood': 8000,
              'orbs_earth': 4000,
              'orbs_metal': 4000,
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
          await tester.tap(
            find.byKey(const ValueKey('altar_reveal_collect_button')),
          );
          await tester.pumpAndSettle();
          expect(controller.overchargedStaffLevel, 1);
          expect(controller.overchargedStaffEnabled, isTrue);
          expect(controller.overchargedStaffSelectedSpeed, 1);

          // Speed row visible with all 6 pills aligned on a single horizontal row & 5 lock icons
          expect(
            find.byKey(const ValueKey('overcharged_staff_speed_row')),
            findsOneWidget,
          );
          final pillYCenters = <int>{
            for (final speed in const [1, 2, 5, 10, 20, 30])
              tester
                  .getCenter(
                    find.byKey(ValueKey('overcharged_staff_speed_${speed}x')),
                  )
                  .dy
                  .round(),
          };
          expect(pillYCenters.length, 1);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('overcharged_staff_speed_row')),
              matching: find.byIcon(Icons.lock_rounded),
            ),
            findsNWidgets(5),
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

          // Purchase Level 2 -> auto-selects 2x, 4 locks remain (5x, 10x, 20x, 30x)
          await tester.ensureVisible(upgradeBtn);
          await tester.pumpAndSettle();
          await tester.tap(upgradeBtn);
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('altar_reveal_collect_button')),
          );
          await tester.pumpAndSettle();
          expect(controller.overchargedStaffLevel, 2);
          expect(controller.overchargedStaffSelectedSpeed, 2);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('overcharged_staff_speed_row')),
              matching: find.byIcon(Icons.lock_rounded),
            ),
            findsNWidgets(4),
          );

          // Switch back to 1x
          final speed1x = find.byKey(const ValueKey('overcharged_staff_speed_1x'));
          await tester.ensureVisible(speed1x);
          await tester.pumpAndSettle();
          await tester.tap(speed1x);
          await tester.pumpAndSettle();
          expect(controller.overchargedStaffSelectedSpeed, 1);

          // Purchase Level 3 -> 5x auto-selected, 3 locks remain
          await tester.ensureVisible(upgradeBtn);
          await tester.pumpAndSettle();
          await tester.tap(upgradeBtn);
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('altar_reveal_collect_button')),
          );
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
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('overcharged_staff_speed_row')),
              matching: find.byIcon(Icons.lock_rounded),
            ),
            findsNWidgets(3),
          );

          // Purchase Level 4 -> 10x auto-selected, 2 locks remain (20x, 30x)
          await tester.ensureVisible(upgradeBtn);
          await tester.pumpAndSettle();
          await tester.tap(upgradeBtn);
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('altar_reveal_collect_button')),
          );
          await tester.pumpAndSettle();
          expect(controller.overchargedStaffLevel, 4);
          expect(controller.overchargedStaffSelectedSpeed, 10);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('overcharged_staff_speed_row')),
              matching: find.byIcon(Icons.lock_rounded),
            ),
            findsNWidgets(2),
          );

          // Purchase Level 5 -> 20x auto-selected, 1 lock remains (30x)
          await tester.ensureVisible(upgradeBtn);
          await tester.pumpAndSettle();
          await tester.tap(upgradeBtn);
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('altar_reveal_collect_button')),
          );
          await tester.pumpAndSettle();
          expect(controller.overchargedStaffLevel, 5);
          expect(controller.overchargedStaffSelectedSpeed, 20);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('overcharged_staff_speed_row')),
              matching: find.byIcon(Icons.lock_rounded),
            ),
            findsNWidgets(1),
          );

          // Purchase Level 6 MAX -> 30x auto-selected, MAX badge rendered, 0 locks
          await tester.ensureVisible(upgradeBtn);
          await tester.pumpAndSettle();
          await tester.tap(upgradeBtn);
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('altar_reveal_collect_button')),
          );
          await tester.pumpAndSettle();
          expect(controller.overchargedStaffLevel, 6);
          expect(controller.overchargedStaffSelectedSpeed, 30);
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

    testWidgets('RoyalCastleDialog Relic Chamber shows Overcharged Staff with its level up to Lv. 6', (
      WidgetTester tester,
    ) async {
      final controller = await _createController(
        prefs: {
          'relic_chamber_upgrades': ['overcharged_staff:6'],
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
      expect(find.text('Overcharged Staff (Lv. 6)'), findsOneWidget);
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
      'Hold at 20x (38ms) on Random and 30x (25ms) on Fire rapid-fires at exact intervals and stops on release',
      (WidgetTester tester) async {
        // Part A: 20x (38ms) on Random button
        final controller20x = await _createController(
          prefs: {
            'overcharged_staff_level': 5,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 20, // 38ms
            'unlockedRandom': true,
            'showRandom': true,
            'mana_upgrade_level': 100,
          },
        );
        addTearDown(controller20x.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller20x,
            child: MaterialApp(
              key: const ValueKey('app_20x'),
              theme: ThemeData.dark(useMaterial3: true),
              home: const GameScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final randomBtn = find.byKey(const ValueKey('random_move_button'));
        final randomGesture = await tester.startGesture(tester.getCenter(randomBtn));
        await tester.pump(const Duration(milliseconds: 255)); // 1 initial + 1 rapid at 250ms = 2
        expect(controller20x.totalRounds, 2);
        await tester.pump(const Duration(milliseconds: 38));
        expect(controller20x.totalRounds, 3);
        await tester.pump(const Duration(milliseconds: 38));
        expect(controller20x.totalRounds, 4);
        await tester.pump(const Duration(milliseconds: 38));
        expect(controller20x.totalRounds, 5);
        await randomGesture.up();
        await tester.pump(const Duration(milliseconds: 200));
        expect(controller20x.totalRounds, 5);

        // Part B: 30x (25ms) on Fire button
        final controller30x = await _createController(
          prefs: {
            'overcharged_staff_level': 6,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 30, // 25ms
            'mana_upgrade_level': 100,
          },
        );
        addTearDown(controller30x.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller30x,
            child: MaterialApp(
              key: const ValueKey('app_30x'),
              theme: ThemeData.dark(useMaterial3: true),
              home: const GameScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fireBtn = find.byKey(const ValueKey('hand_button_rock'));
        final fireGesture = await tester.startGesture(tester.getCenter(fireBtn));
        await tester.pump(const Duration(milliseconds: 255)); // 1 initial + 1 rapid at 250ms = 2
        expect(controller30x.totalRounds, 2);
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 25));
        }
        expect(controller30x.totalRounds, 6);
        await fireGesture.up();
        await tester.pump(const Duration(milliseconds: 200));
        expect(controller30x.totalRounds, 6);
      },
    );

    testWidgets(
      '10x (75ms) and 30x (25ms) rapid-fire throttle light haptics and attack SFX to at most once every ~120ms',
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

        int sfxCalls = 0;
        final audioService = AudioService();
        audioService.onSfxTriggeredForTest = () => sfxCalls++;

        final controller = await _createController(
          audioService: audioService,
          prefs: {
            'overcharged_staff_level': 6,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 30, // 25ms (40 shots/sec)
            'vibrationEnabled': true,
            'soundEnabled': true,
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
        // Advance through 250ms threshold + 10 intervals of 25ms (t = 250..500ms -> 11 rapid ticks)
        await tester.pump(const Duration(milliseconds: 250));
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 25));
        }
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 200));

        // 12 rounds total (1 initial + 11 rapid ticks at 25ms intervals),
        // but 120ms cooldown throttles rapid haptics to 3 (250ms, 375ms, 500ms)
        // and SFX to 4 (1 initial + 3 rapid-fire throttled triggers).
        expect(controller.totalRounds, 12);
        expect(rapidVibrationCalls.length, 3);
        expect(sfxCalls, 4);
      },
    );

    testWidgets(
      'Safety brake stops 30x rapid-fire immediately when playerHp <= 5, when enemyHp == 0, or when remainingMana == 0',
      (WidgetTester tester) async {
        // Case A: Critical HP protection at 30x (playerHp drops to 5 -> halts immediately)
        final hpController = await _createController(
          prefs: {
            'overcharged_staff_level': 6,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 30, // 25ms
            'userHp': 9,
            'pcScore': 41,
            'total': 41,
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
        // Initial press: 9 -> 8 HP. 250ms: 8 -> 7, 275ms: 7 -> 6, 300ms: 6 -> 5 (safety brake!)
        await tester.pump(const Duration(milliseconds: 100));
        expect(hpController.userHp, 8);
        await tester.pump(const Duration(milliseconds: 155)); // 255ms -> 7 HP
        expect(hpController.userHp, 7);
        await tester.pump(const Duration(milliseconds: 25)); // 280ms -> 6 HP
        expect(hpController.userHp, 6);
        await tester.pump(const Duration(milliseconds: 25)); // 305ms -> 5 HP (halted!)
        expect(hpController.userHp, 5);
        // Hold for another 300ms (12 more 25ms intervals): must NOT drop below 5 HP
        for (int i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 25));
        }
        expect(hpController.userHp, 5);
        await hpGesture.up();
        await tester.pump();

        // Case B: Boss defeated at 30x (enemyHp == 0 -> halts immediately)
        final bossController = await _createController(
          prefs: {
            'overcharged_staff_level': 6,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 30, // 25ms
            'enemy_stage': 3,
            // Inverse mode (Lose-Stay on Metal) keeps Wizard casting Metal for 3 losses
            'metal_wizard_ai_state':
                '{"currentMoveId":5,"strategyMode":"inverse","consecutiveLosses":0,"scriptedQueueIds":[],"tenLossStage":0}',
            'pcHp': 3,
            'userScore': 297,
            'total': 297,
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
        await tester.pump(const Duration(milliseconds: 100)); // 3 -> 2 HP
        expect(bossController.enemyHp, 2);
        await tester.pump(const Duration(milliseconds: 155)); // 255ms -> 1 HP
        expect(bossController.enemyHp, 1);
        await tester.pump(const Duration(milliseconds: 25)); // 280ms -> 0 HP (halted!)
        expect(bossController.enemyHp, 0);
        expect(bossController.totalRounds, 300);
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 25));
        }
        expect(bossController.totalRounds, 300);
        await bossGesture.up();
        await tester.pumpAndSettle();

        // Case C: Mana reaches 0 at 30x (remainingMana == 0 -> halts immediately)
        final manaController = await _createController(
          prefs: {
            'overcharged_staff_level': 6,
            'overcharged_staff_enabled': true,
            'overcharged_staff_selected_speed': 30, // 25ms
            'total': 97, // 3 mana remaining out of 100
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
        await tester.pump(const Duration(milliseconds: 100)); // 98 rounds (2 mana left)
        expect(manaController.remainingMana, 2);
        await tester.pump(const Duration(milliseconds: 155)); // 99 rounds (1 mana left)
        expect(manaController.remainingMana, 1);
        await tester.pump(const Duration(milliseconds: 25)); // 100 rounds (0 mana left!)
        expect(manaController.remainingMana, 0);
        expect(manaController.totalRounds, 100);
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 25));
        }
        expect(manaController.totalRounds, 100);
        await manaGesture.up();
        await tester.pumpAndSettle();
      },
    );
  });
}
