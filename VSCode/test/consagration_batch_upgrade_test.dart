import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/billing_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';

class _TestAdClient implements AdMobClient {
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
  int saveCount = 0;

  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'ConsagrationTester';

  @override
  Future<String?> getPlayerID() async => 'consagration_tester_1';

  @override
  Future<String?> saveGame({
    required String data,
    required String name,
  }) async {
    saveCount++;
    savedPayload = data;
    return 'success';
  }

  @override
  Future<String?> loadGame({required String name}) async => savedPayload;
}

Future<({
  GameController controller,
  StorageService storage,
  _TestPlayGamesClient? pgClient,
})> _createHarness({
  Map<String, Object> prefs = const {},
  String language = 'en',
  bool withPlayGames = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_story_intro': true,
    'animationsEnabled': false,
    'musicEnabled': false,
    'soundEnabled': false,
    'current_week': 1,
    'language': language,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();
  final localization = LocalizationService();
  await localization.load();
  localization.setLanguage(language);

  final adService = AdService(client: _TestAdClient());
  await adService.initialize(
    adsRemoved: storage.unlockedAds && storage.removeAdsEnabled,
  );

  _TestPlayGamesClient? pgClient;
  PlayGamesService? playGames;
  if (withPlayGames) {
    pgClient = _TestPlayGamesClient();
    playGames = PlayGamesService(storage: storage, client: pgClient);
    await playGames.signIn();
  }

  final controller = GameController(
    storage: storage,
    localization: localization,
    audio: AudioService(),
    adService: adService,
    billingService: BillingService(),
    playGames: playGames,
  );
  return (controller: controller, storage: storage, pgClient: pgClient);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Consagration Room Batch Upgrades & Hero Peak Guard', () {
    test(
      '1. Progressive cost summation for 10x, 100x, and MAX sums level-by-level (never unitCost * N) and guards zero-cost loops',
      () async {
        final h = await _createHarness(
          prefs: {
            'hp_upgrade_level': 733,
            'mana_upgrade_level': 1010,
            'orbs_fire': 500000,
            'orbs_water': 500000,
            'orbs_wood': 500000,
          },
        );
        final controller = h.controller;
        addTearDown(controller.dispose);

        // At Lv. 733: cost is 2 + 733~/2 = 368.
        // 10x from 733: 368 + 369*2 + 370*2 + 371*2 + 372*2 + 373 = 3705 (not 3680).
        expect(GameController.maxHpUpgradeCostForLevel(733).fire, 368);
        final hp10Cost = controller.costForMaxHpLevels(10);
        expect(hp10Cost.fire, 3705);
        expect(hp10Cost.water, 3705);
        expect(hp10Cost.wood, 3705);
        expect(hp10Cost.fire, isNot(368 * 10));

        // 100x from 733 matches exact loop sum
        int expectedHp100 = 0;
        for (int i = 0; i < 100; i++) {
          expectedHp100 += GameController.maxHpUpgradeCostForLevel(733 + i).fire;
        }
        final hp100Cost = controller.costForMaxHpLevels(100);
        expect(hp100Cost.fire, expectedHp100);
        expect(hp100Cost.fire, greaterThan(368 * 100));

        // At Lv. 1010: cost is 3 + 1010~/2 = 508.
        // 10x from 1010: 508*2 + 509*2 + 510*2 + 511*2 + 512*2 = 5100 (not 5080).
        expect(GameController.maxManaUpgradeCostForLevel(1010).fire, 508);
        final mana10Cost = controller.costForMaxManaLevels(10);
        expect(mana10Cost.fire, 5100);
        expect(mana10Cost.fire, isNot(508 * 10));

        // Asymmetric orb limit: limited by lowest of Fire/Water/Wood
        controller.fireOrbs = 10000;
        controller.waterOrbs = 1150; // enough for Lv. 733 (368) + 734 (369) + 735 (369) = 1106 (< 1150), 4th (370) -> 1476
        controller.woodOrbs = 10000;
        final maxHp = controller.maxAffordableHpUpgrade();
        expect(maxHp.levels, 3);
        expect(maxHp.totalCost.fire, 368 + 369 + 369);
        expect(maxHp.totalCost.water, 1106);

        // Zero-cost edge case respects maxBatchSearchLimit without hanging
        final zeroEdge = controller.calculateMaxAffordableUpgrade(
          currentLevel: 0,
          costForLevel: (_) => const ElementalCost(),
        );
        expect(zeroEdge.levels, GameController.maxBatchSearchLimit);
        expect(zeroEdge.totalCost, const ElementalCost());
      },
    );

    test(
      '2. Atomic batch purchase updates levels, peaks, userHp, turn0 orbs, StorageService and sends 1 Cloud Save',
      () async {
        final h = await _createHarness(
          prefs: {
            'orbs_fire': 10000,
            'orbs_water': 10000,
            'orbs_wood': 10000,
            'turn0_orbs_fire': 10000,
            'turn0_orbs_water': 10000,
            'turn0_orbs_wood': 10000,
            'hp_upgrade_level': 10,
            'mana_upgrade_level': 5,
            'peak_hp_upgrade_level': 10,
            'peak_mana_upgrade_level': 5,
          },
          withPlayGames: true,
        );
        final controller = h.controller;
        final pgClient = h.pgClient!;
        addTearDown(controller.dispose);

        final expectedHp100Cost = controller.costForMaxHpLevels(100);
        final savesBefore = pgClient.saveCount;

        expect(controller.upgradeMaxHpBatch(100), isTrue);
        expect(controller.hpUpgradeLevel, 110);
        expect(controller.peakHpUpgradeLevel, 110);
        expect(controller.playerMaxHp, 50 + 110);
        expect(controller.userHp, 50 + 110);
        expect(controller.fireOrbs, 10000 - expectedHp100Cost.fire);
        expect(controller.waterOrbs, 10000 - expectedHp100Cost.water);
        expect(controller.woodOrbs, 10000 - expectedHp100Cost.wood);
        expect(controller.turn0FireOrbs, 10000 - expectedHp100Cost.fire);

        // Single Cloud Save write for the entire 100x batch
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(pgClient.saveCount, savesBefore + 1);
        final cloud = CloudSaveData.tryParse(pgClient.savedPayload)!;
        expect(cloud.hpUpgradeLevel, 110);
        expect(cloud.peakHpUpgradeLevel, 110);
        expect(cloud.fireOrbs, 10000 - expectedHp100Cost.fire);

        // Reload StorageService from disk to verify atomic persistence
        final reloaded = StorageService();
        await reloaded.init();
        expect(reloaded.hpUpgradeLevel, 110);
        expect(reloaded.peakHpUpgradeLevel, 110);
        expect(reloaded.userHp, 160);
        expect(reloaded.fireOrbs, 10000 - expectedHp100Cost.fire);

        // Mana MAX batch upgrade
        final maxMana = controller.maxAffordableManaUpgrade();
        expect(maxMana.levels, greaterThan(0));
        expect(controller.upgradeMaxManaBatch(maxMana.levels), isTrue);
        expect(controller.manaUpgradeLevel, 5 + maxMana.levels);
        expect(controller.peakManaUpgradeLevel, 5 + maxMana.levels);
        expect(controller.remainingMana, 100 + 5 + maxMana.levels);
        // Should not afford even 1 more level
        expect(controller.maxAffordableManaUpgrade().levels, 0);
      },
    );

    testWidgets(
      '3. Header selector fits cleanly on 360dp, updates previews/costs live, executes 1x/10x directly, and confirms 100x/MAX with exact balances',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Enough orbs for > 100 levels at Lv. 733 HP and Lv. 1010 Mana
        // Cost for 100 HP at 733 is ~39,250; for 100 Mana at 1010 is ~53,250
        final h = await _createHarness(
          prefs: {
            'hp_upgrade_level': 733,
            'mana_upgrade_level': 1010,
            'peak_hp_upgrade_level': 733,
            'peak_mana_upgrade_level': 1010,
            'orbs_fire': 60000,
            'orbs_water': 60000,
            'orbs_wood': 60000,
          },
        );
        final controller = h.controller;
        addTearDown(controller.dispose);

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
        expect(tester.takeException(), isNull);

        // All 4 pills sit on a single horizontal row inside 360dp
        const pillKeys = [
          ValueKey('consagration_batch_1x'),
          ValueKey('consagration_batch_10x'),
          ValueKey('consagration_batch_100x'),
          ValueKey('consagration_batch_max'),
        ];
        final firstY = tester.getTopLeft(find.byKey(pillKeys.first)).dy;
        for (final key in pillKeys) {
          expect(find.byKey(key), findsOneWidget);
          expect(tester.getTopLeft(find.byKey(key)).dy, closeTo(firstY, 1.0));
          expect(
            tester.getBottomRight(find.byKey(key)).dx,
            lessThanOrEqualTo(360),
          );
        }

        // 1x preserves existing format
        expect(find.text('+1 Max HP'), findsOneWidget);
        expect(find.text('Lv. 733 • 783 → 784 HP'), findsOneWidget);
        expect(find.text('+1 Max Mana Pool'), findsOneWidget);
        expect(find.text('Lv. 1010 • 1110 → 1111 MANA'), findsOneWidget);

        // Switch to 10x -> both cards update live with exact progressive cost
        await tester.tap(find.byKey(const ValueKey('consagration_batch_10x')));
        await tester.pumpAndSettle();
        expect(find.text('+10 Max HP'), findsOneWidget);
        expect(find.text('Lv. 733 → 743 • 783 → 793 HP'), findsOneWidget);
        expect(find.text('+10 Max Mana Pool'), findsOneWidget);
        expect(find.text('Lv. 1010 → 1020 • 1110 → 1120 MANA'), findsOneWidget);
        expect(find.text('3,705'), findsNWidgets(3));
        expect(find.text('5,100'), findsNWidgets(3));

        // Tap 10x HP -> executes immediately without confirmation dialog and shows floating indicator
        await tester.tap(find.byKey(const ValueKey('shop_upgrade_max_hp_button')));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const ValueKey('consagration_confirm_dialog')), findsNothing);
        expect(find.byKey(const ValueKey('consagration_hp_floating_gain')), findsOneWidget);
        expect(find.text('+10 HP!'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(controller.hpUpgradeLevel, 743);
        expect(controller.fireOrbs, 60000 - 3705);

        // Switch to 100x -> HP 100x affordable, Mana 100x affordable -> tap HP opens confirm dialog
        await tester.tap(find.byKey(const ValueKey('consagration_batch_100x')));
        await tester.pumpAndSettle();
        expect(find.text('+100 Max HP'), findsOneWidget);
        expect(find.text('Lv. 743 → 843 • 793 → 893 HP'), findsOneWidget);

        final hp100Cost = controller.costForMaxHpLevels(100);
        final orbsBeforeConfirm = controller.fireOrbs;

        await tester.tap(find.byKey(const ValueKey('shop_upgrade_max_hp_button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('consagration_confirm_dialog')),
          findsOneWidget,
        );
        expect(
          find.text('+100 Levels • Lv. 743 → Lv. 843 • 793 → 893 HP'),
          findsOneWidget,
        );
        final expectedCostText =
            '${hp100Cost.fire ~/ 1000},${(hp100Cost.fire % 1000).toString().padLeft(3, '0')}';
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('consagration_confirm_cost')),
            matching: find.text(expectedCostText),
          ),
          findsNWidgets(3),
        );

        // Cancel leaves orbs & level untouched
        await tester.tap(
          find.byKey(const ValueKey('consagration_confirm_cancel_button')),
        );
        await tester.pumpAndSettle();
        expect(controller.hpUpgradeLevel, 743);
        expect(controller.fireOrbs, orbsBeforeConfirm);

        // Switch to MAX -> displays exact affordable count for both stats
        await tester.tap(find.byKey(const ValueKey('consagration_batch_max')));
        await tester.pumpAndSettle();
        final expectedMaxHp = controller.maxAffordableHpUpgrade();
        final expectedMaxMana = controller.maxAffordableManaUpgrade();
        expect(expectedMaxHp.levels, greaterThan(100));
        expect(find.text('+${expectedMaxHp.levels} Max HP'), findsOneWidget);
        expect(find.text('+${expectedMaxMana.levels} Max Mana Pool'), findsOneWidget);

        // Tap MAX HP -> confirm dialog shows exact levels, cost, and remaining balance
        await tester.tap(find.byKey(const ValueKey('shop_upgrade_max_hp_button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('consagration_confirm_dialog')),
          findsOneWidget,
        );
        final remainingAfterMax = controller.fireOrbs - expectedMaxHp.totalCost.fire;
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('consagration_confirm_remaining')),
            matching: find.textContaining('$remainingAfterMax'),
          ),
          findsNWidgets(3),
        );

        await tester.tap(
          find.byKey(const ValueKey('consagration_confirm_submit_button')),
        );
        await tester.pumpAndSettle();
        expect(controller.hpUpgradeLevel, 743 + expectedMaxHp.levels);
        expect(controller.fireOrbs, remainingAfterMax);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '4. Unclaimed Hall of Heroes warning banner, pre-purchase intercept dialog, Go to Hall of Heroes navigation, and Buy Anyway',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final h = await _createHarness(
          prefs: {
            'hp_upgrade_level': 2,
            'mana_upgrade_level': 3,
            'peak_hp_upgrade_level': 15,
            'peak_mana_upgrade_level': 12,
            'hall_of_heroes_claim_available': true,
            'orbs_fire': 500,
            'orbs_water': 500,
            'orbs_wood': 500,
          },
        );
        final controller = h.controller;
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: Builder(
                builder: (rootContext) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog<void>(
                        context: rootContext,
                        builder: (_) => SacredTempleDialog(
                          controller: controller,
                          initialWing: TempleWing.consagration,
                        ),
                      );
                    },
                    child: const Text('Open Temple'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Temple'));
        await tester.pumpAndSettle();

        // Contextual banner is visible at top of Consagration Room
        expect(
          find.byKey(const ValueKey('consagration_heroes_warning_banner')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Lv. 15'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Lv. 12'),
          findsOneWidget,
        );

        // Tap HP while below peak -> Pre-Purchase Guard Dialog intercepts
        await tester.tap(find.byKey(const ValueKey('shop_upgrade_max_hp_button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('consagration_heroes_guard_dialog')),
          findsOneWidget,
        );
        expect(controller.hpUpgradeLevel, 2);

        // Buy Anyway continues into purchase (1x -> purchases 1 level)
        await tester.tap(
          find.byKey(const ValueKey('consagration_heroes_guard_buy_anyway_button')),
        );
        await tester.pumpAndSettle();
        expect(controller.hpUpgradeLevel, 3);

        // Tap Mana while below peak -> Guard Dialog -> Go to Hall of Heroes closes Temple and opens RoyalCastleDialog on Heroes wing
        final manaBtn = find.byKey(const ValueKey('shop_upgrade_max_mana_button'));
        await tester.ensureVisible(manaBtn);
        await tester.pumpAndSettle();
        await tester.tap(manaBtn);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('consagration_heroes_guard_dialog')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('consagration_heroes_guard_go_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('sacred_temple_dialog')), findsNothing);
        expect(find.byKey(const ValueKey('royal_castle_dialog')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('castle_wing_hall_of_heroes')),
          findsOneWidget,
        );

        // Close Castle, re-open Temple, and verify banner button also navigates to Hall of Heroes
        await tester.tap(find.byKey(const ValueKey('royal_castle_close_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Temple'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('consagration_heroes_banner_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('sacred_temple_dialog')), findsNothing);
        expect(
          find.byKey(const ValueKey('castle_wing_hall_of_heroes')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '5. Smart pill dimming, +0 MAX prompt & unaffordable SnackBar Transform Orbs shortcut, and press-and-hold on 1x/10x',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final h = await _createHarness(
          prefs: {
            'orbs_fire': 1,
            'orbs_water': 1,
            'orbs_wood': 1,
            'orbs_earth': 30,
            'orbs_metal': 30,
          },
        );
        final controller = h.controller;
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: Scaffold(
              body: SacredTempleDialog(
                controller: controller,
                initialWing: TempleWing.consagration,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 10x and 100x are dimmed/disabled when unaffordable for both stats
        final pill10x = tester.widget<InkWell>(
          find.byKey(const ValueKey('consagration_batch_10x')),
        );
        final pill100x = tester.widget<InkWell>(
          find.byKey(const ValueKey('consagration_batch_100x')),
        );
        expect(pill10x.onTap, isNull);
        expect(pill100x.onTap, isNull);

        // MAX remains active and shows +0 Max HP / +0 Max Mana Pool + Transform Orbs prompt
        await tester.tap(find.byKey(const ValueKey('consagration_batch_max')));
        await tester.pumpAndSettle();
        expect(find.text('+0 Max HP'), findsOneWidget);
        expect(find.text('+0 Max Mana Pool'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('consagration_transform_prompt')),
          findsOneWidget,
        );

        // Tapping Transform Orbs switches directly to Transform wing
        await tester.tap(
          find.byKey(const ValueKey('consagration_transform_orbs_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('temple_wing_transmute')),
          findsOneWidget,
        );

        // Switch back to Consagration with enough orbs for press-and-hold 1x
        controller.fireOrbs = 12;
        controller.waterOrbs = 12;
        controller.woodOrbs = 12;
        await tester.tap(find.byKey(const ValueKey('temple_tab_consagration')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('consagration_batch_1x')));
        await tester.pumpAndSettle();

        final hpCardCenter = tester.getCenter(
          find.byKey(const ValueKey('shop_upgrade_max_hp_card')),
        );
        final gesture = await tester.startGesture(hpCardCenter);
        await tester.pump(const Duration(milliseconds: 900));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(controller.hpUpgradeLevel, greaterThanOrEqualTo(2));
        expect(tester.takeException(), isNull);
      },
    );

    test(
      '6. All new Consagration batch & Hall of Heroes warning localization keys exist across en, pt, es, de',
      () async {
        final rawJson = await rootBundle.loadString(
          'assets/data/stringsHowPredict.json',
        );
        final map = json.decode(rawJson) as Map<String, dynamic>;

        const newKeys = [
          'upgrade_max_hp_batch_title',
          'upgrade_max_hp_batch_desc',
          'upgrade_max_mana_batch_title',
          'upgrade_max_mana_batch_desc',
          'consagration_confirm_title',
          'consagration_confirm_levels_gained',
          'consagration_confirm_total_cost',
          'consagration_confirm_remaining_balance',
          'consagration_confirm_cancel',
          'consagration_confirm_action',
          'consagration_max_hp_stat_name',
          'consagration_max_mana_stat_name',
          'consagration_heroes_banner_title',
          'consagration_heroes_banner_both',
          'consagration_heroes_banner_hp',
          'consagration_heroes_banner_mana',
          'consagration_heroes_banner_cta',
          'consagration_heroes_guard_title',
          'consagration_heroes_guard_body',
          'consagration_heroes_guard_go_cta',
          'consagration_heroes_guard_buy_anyway',
          'consagration_transform_orbs_btn',
          'consagration_transform_orbs_hint',
          'consagration_floating_hp_gain',
          'consagration_floating_mana_gain',
        ];

        for (final lang in ['en', 'pt', 'es', 'de']) {
          for (final key in newKeys) {
            final flatKey = '${lang}_$key';
            final value = map[flatKey];
            expect(value, isA<String>(), reason: 'Missing $flatKey');
            expect(
              (value as String).trim(),
              isNotEmpty,
              reason: 'Empty $flatKey',
            );
          }
        }
      },
    );
  });
}
