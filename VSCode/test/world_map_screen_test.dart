import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/inventory_dialog.dart';
import 'package:how_predictable/views/dialogs/observatory_dialog.dart';
import 'package:how_predictable/views/dialogs/settings_dialog.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';
import 'package:how_predictable/views/dialogs/story_gallery_dialog.dart';
import 'package:how_predictable/views/dialogs/throne_room_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/screens/world_map_screen.dart';
import 'package:how_predictable/views/widgets/rpg_backpack_icon.dart';

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
        key: ValueKey('world_map_test_banner'),
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

class _TestPlayGamesClient implements PlayGamesClient {
  String? savedPayload;
  int saveCount = 0;

  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'MapHero';

  @override
  Future<String?> getPlayerID() async => 'player_map_hero_1';

  @override
  Future<String?> saveGame({
    required String data,
    required String name,
  }) async {
    savedPayload = data;
    saveCount++;
    return 'success';
  }

  @override
  Future<String?> loadGame({required String name}) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorldMapScreen Hub & 100-Round Campaign Loop Tests', () {
    testWidgets(
      'App launches directly onto WorldMapScreen with unobstructed top, 9:16 map canvas, bottom-left HUD above AdMob banner, and zero overlap with Sacred Temple',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
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

        final adService = AdService(client: _TestAdMobClient());
        await adService.initialize(adsRemoved: false);

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
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

        // Launched directly onto WorldMapScreen (not GameScreen)
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(find.byType(GameScreen), findsNothing);
        expect(find.byType(AppBar), findsNothing);
        expect(
          find.byKey(const ValueKey('world_map_aspect_canvas')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('world_map_background_image')),
          findsOneWidget,
        );

        // Bottom-left HUD cluster rendered in bottom-left area above bottom banner
        final hudFinder = find.byKey(const ValueKey('world_map_bottom_left_hud'));
        final bannerFinder = find.byKey(
          const ValueKey('bottom_banner_ad_container'),
        );
        final templeFinder = find.byKey(
          const ValueKey('landmark_sacred_temple'),
        );
        expect(hudFinder, findsOneWidget);
        expect(bannerFinder, findsOneWidget);
        expect(templeFinder, findsOneWidget);

        expect(find.text('Week 1 / 40'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('backpack_inventory_button')),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('backpack_inventory_button'))),
          equals(const Size(36.0, 36.0)),
        );
        expect(
          tester.getSize(find.byType(RpgBackpackIcon)),
          equals(const Size(28.0, 28.0)),
        );
        expect(
          find.byKey(const ValueKey('world_map_settings_button')),
          findsOneWidget,
        );

        final hudRect = tester.getRect(hudFinder);
        final bannerRect = tester.getRect(bannerFinder);
        final templeRect = tester.getRect(templeFinder);

        // Bottom-left placement: left half of screen, >= 8px above bottom banner
        expect(hudRect.left, lessThan(40.0));
        expect(hudRect.center.dx, lessThan(390.0 * 0.5));
        expect(hudRect.top, greaterThan(844.0 * 0.5));
        expect(bannerRect.top - hudRect.bottom, greaterThanOrEqualTo(8.0));

        // Zero overlap with Sacred Temple on bottom-right
        expect(hudRect.overlaps(templeRect), isFalse);
        expect(hudRect.right, lessThanOrEqualTo(templeRect.left));

        // Tapping Backpack opens InventoryDialog; 7 taps grants QA orbs
        await tester.tap(find.byKey(const ValueKey('backpack_inventory_button')));
        await tester.pumpAndSettle();
        expect(find.byType(InventoryDialog), findsOneWidget);
        for (var i = 0; i < 6; i++) {
          await tester.tap(
            find.byKey(const ValueKey('inventory_header_backpack_icon')),
          );
        }
        await tester.pumpAndSettle();
        expect(controller.fireOrbs, GameController.qaShortcutOrbBonus);

        await tester.tap(find.byKey(const ValueKey('inventory_close_button')));
        await tester.pumpAndSettle();

        // Tapping Settings opens SettingsDialog
        await tester.tap(find.byKey(const ValueKey('world_map_settings_button')));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsDialog), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('settings_ok_button')));
        await tester.pumpAndSettle();

        // Unlocking Remove Ads (costs 2000 Fire) hides bottom banner cleanly
        controller.unlockAds();
        await tester.pumpAndSettle();
        expect(bannerFinder, findsNothing);

        // Wait for QA bonus SnackBar to dismiss before tapping bottom-left Gift Box
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // Gift Box unlocked & enabled appears in bottom-left HUD
        controller.giftBoxUnlocked = true;
        controller.giftBoxEnabled = true;
        controller.notifyListeners();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('gift_box_button')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('gift_box_button')));
        await tester.pump();
        expect(
          controller.fireOrbs,
          GameController.qaShortcutOrbBonus -
              GameController.costRemoveAds.fire +
              GameController.periodicGiftOrbBonus,
        );
      },
    );

    testWidgets(
      '4 landmarks stay centered inside locked 9:16 coordinate space across screen sizes and localize across en, pt, es, de',
      (WidgetTester tester) async {
        for (final size in const [Size(360, 640), Size(390, 844), Size(800, 600)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          SharedPreferences.setMockInitialValues({
            'has_seen_story_intro': true,
            'animationsEnabled': false,
            'musicEnabled': false,
          });
          final storage = StorageService();
          await storage.init();

          final localization = LocalizationService();
          await tester.runAsync(() => localization.load());

          final controller = GameController(
            storage: storage,
            localization: localization,
            audio: AudioService(),
          );

          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: controller,
              child: const HowPredictableApp(),
            ),
          );
          await tester.pumpAndSettle();

          final canvasRect = tester.getRect(
            find.byKey(const ValueKey('world_map_aspect_canvas')),
          );
          expect(
            canvasRect.width / canvasRect.height,
            closeTo(9.0 / 16.0, 0.01),
          );

          void expectPinAt(String key, Offset normalized) {
            final center = tester.getCenter(find.byKey(ValueKey(key)));
            expect(
              center.dx,
              closeTo(canvasRect.left + canvasRect.width * normalized.dx, 1.5),
            );
            expect(
              center.dy,
              closeTo(canvasRect.top + canvasRect.height * normalized.dy, 1.5),
            );
          }

          expectPinAt(
            'landmark_metal_wizard_lair',
            WorldMapScreen.metalWizardLairPos,
          );
          expectPinAt(
            'landmark_telescope_tower',
            WorldMapScreen.telescopeTowerPos,
          );
          expectPinAt('landmark_royal_castle', WorldMapScreen.royalCastlePos);
          expectPinAt('landmark_sacred_temple', WorldMapScreen.sacredTemplePos);

          // Verify localized badges in en, pt, es, de
          if (size == const Size(390, 844)) {
            expect(find.text("Metal Wizard's Lair"), findsOneWidget);
            expect(find.text('Telescope Tower'), findsOneWidget);
            expect(find.text('Royal Castle'), findsOneWidget);
            expect(find.text('Sacred Temple'), findsOneWidget);

            controller.setLanguage('pt');
            await tester.pumpAndSettle();
            expect(find.text('Covil do Mago de Metal'), findsOneWidget);
            expect(find.text('Torre do Telescópio'), findsOneWidget);
            expect(find.text('Castelo Real'), findsOneWidget);
            expect(find.text('Templo Sagrado'), findsOneWidget);

            controller.setLanguage('es');
            await tester.pumpAndSettle();
            expect(find.text('Guarida del Mago de Metal'), findsOneWidget);
            expect(find.text('Torre del Telescopio'), findsOneWidget);
            expect(find.text('Castillo Real'), findsOneWidget);
            expect(find.text('Templo Sagrado'), findsOneWidget);

            controller.setLanguage('de');
            await tester.pumpAndSettle();
            expect(find.text('Versteck des Metallmagiers'), findsOneWidget);
            expect(find.text('Teleskopturm'), findsOneWidget);
            expect(find.text('Königsschloss'), findsOneWidget);
            expect(find.text('Heiliger Tempel'), findsOneWidget);
          }

          controller.dispose();
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Tapping Metal Wizard\'s Lair opens fresh 100-round battle, Teleport exits advancing +1 week, and completing 100 rounds returns to WorldMapScreen and increments week + cloud save',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
          // Pre-populate stale round progress to verify Lair starts fresh 100 Mana
          'total': 42,
          'userScore': 20,
          'pcScore': 22,
        });
        final storage = StorageService();
        await storage.init();

        final fakePlayGamesClient = _TestPlayGamesClient();
        final playGames = PlayGamesService(
          storage: storage,
          client: fakePlayGamesClient,
        );
        await playGames.signIn();
        fakePlayGamesClient.saveCount = 0;

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.currentWeek, 1);
        expect(find.text('Week 1 / 40'), findsOneWidget);

        // 1. Tap Metal Wizard's Lair -> launches fresh 100-round battle (100 Mana)
        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GameScreen), findsOneWidget);
        expect(find.byKey(const ValueKey('game_retreat_button')), findsNothing);
        expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
        expect(controller.totalRounds, 0);
        expect(controller.remainingMana, 100);

        // Play 1 round then tap Teleport button in AppBar -> returns to map, week advances 1 -> 2
        await tester.tap(find.byKey(const ValueKey('hand_button_rock')));
        await tester.pumpAndSettle();
        expect(controller.totalRounds, 1);

        await tester.tap(find.byKey(const ValueKey('teleport_portal_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('teleport_confirm_button')));
        await tester.pumpAndSettle();

        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(find.byType(GameScreen), findsNothing);
        expect(controller.currentWeek, 2);
        expect(storage.currentWeek, 2);
        expect(find.text('Week 2 / 40'), findsOneWidget);

        // 2. Re-enter Metal Wizard's Lair -> fresh 100-round battle again
        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();
        expect(controller.totalRounds, 0);
        expect(controller.remainingMana, 100);

        // Complete all 100 rounds without dropping to 0 HP
        for (var i = 0; i < 100; i++) {
          controller.playTurn(controller.crystalBallMove ?? HandMove.rock);
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.totalRounds, 100);
        expect(controller.remainingMana, 0);
        expect(
          find.text('+1 Week Passed — Returning to the Kingdom Map'),
          findsOneWidget,
        );
        final returnBtn = find.byKey(
          const ValueKey('battle_return_to_map_button'),
        );
        expect(returnBtn, findsOneWidget);

        // Tap Return to Map -> pops back to WorldMapScreen and increments Week 2 -> 3
        await tester.tap(returnBtn);
        await tester.pumpAndSettle();

        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(find.byType(GameScreen), findsNothing);
        expect(controller.currentWeek, 3);
        expect(storage.currentWeek, 3);
        expect(find.text('Week 3 / 40'), findsOneWidget);

        // Persisted in CloudSaveData
        expect(fakePlayGamesClient.saveCount, greaterThanOrEqualTo(1));
        final cloud = CloudSaveData.tryParse(fakePlayGamesClient.savedPayload)!;
        expect(cloud.currentWeek, 3);
      },
    );

    testWidgets(
      'Tapping Telescope Tower, Royal Castle, and Sacred Temple opens their respective dialogs',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
          'current_week': 10,
        });
        final storage = StorageService();
        await storage.init();

        final localization = LocalizationService();
        await tester.runAsync(() => localization.load());

        final adService = AdService(client: _TestAdMobClient());
        await adService.initialize(adsRemoved: false);

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
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

        // 1. Telescope Tower -> ObservatoryDialog + Story Log
        await tester.tap(
          find.byKey(const ValueKey('landmark_telescope_tower')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ObservatoryDialog), findsOneWidget);
        expect(find.text('Telescope Observatory'), findsOneWidget);
        expect(find.text("Star-Gazer's Strategy Hints"), findsOneWidget);
        expect(find.text('Markov Insight'), findsOneWidget);

        final storyLogBtn = find.byKey(
          const ValueKey('observatory_story_log_button'),
        );
        await tester.ensureVisible(storyLogBtn);
        await tester.pumpAndSettle();
        await tester.tap(storyLogBtn);
        await tester.pumpAndSettle();
        expect(find.byType(StoryGalleryDialog), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(StoryGalleryDialog),
            matching: find.text('Ok'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('observatory_close_button')));
        await tester.pumpAndSettle();
        expect(find.byType(ObservatoryDialog), findsNothing);

        // 2. Royal Castle -> 5-Wing RoyalCastleDialog with King's Throne Room & Week 1, 10, 40 milestones
        await tester.tap(find.byKey(const ValueKey('landmark_royal_castle')));
        await tester.pumpAndSettle();

        expect(find.byType(RoyalCastleDialog), findsOneWidget);
        expect(find.text("King's Throne Room"), findsOneWidget);
        expect(find.text('Week 10 / 40'), findsWidgets);
        expect(
          find.textContaining("Archmage's warning echoes across the realm"),
          findsOneWidget,
        );
        expect(find.text('Week 1 — Royal Summons'), findsOneWidget);
        expect(find.text("Week 10 — Archmage's Warning"), findsOneWidget);
        expect(find.text('Week 40 — The Final Deadline'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('royal_castle_close_button')));
        await tester.pumpAndSettle();
        expect(find.byType(RoyalCastleDialog), findsNothing);

        // 3. Sacred Temple -> Altar of Offerings (ShopDialog + Rewarded Ad prayer +50 Orbs)
        await tester.tap(find.byKey(const ValueKey('landmark_sacred_temple')));
        await tester.pumpAndSettle();

        expect(find.byType(ShopDialog), findsOneWidget);
        expect(find.text('Altar of Offerings'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('shop_watch_rewarded_ad_button')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('shop_watch_rewarded_ad_button')),
        );
        await tester.pumpAndSettle();
        expect(controller.fireOrbs, 50);
        expect(controller.metalOrbs, 50);

        await tester.tap(find.byKey(const ValueKey('shop_close_button')));
        await tester.pumpAndSettle();
        expect(find.byType(ShopDialog), findsNothing);
      },
    );

    test(
      'CloudSaveData round-trips currentWeek and resetAllProgress resets week back to 1',
      () async {
        SharedPreferences.setMockInitialValues({
          'current_week': 12,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
        );
        addTearDown(controller.dispose);

        expect(controller.currentWeek, 12);
        final snapshot = CloudSaveData.fromStorage(storage);
        expect(snapshot.currentWeek, 12);

        final parsed = CloudSaveData.tryParse(snapshot.toJsonString())!;
        expect(parsed.currentWeek, 12);

        await controller.resetAllProgress();
        expect(controller.currentWeek, 1);
        expect(storage.currentWeek, 1);
      },
    );
  });
}
