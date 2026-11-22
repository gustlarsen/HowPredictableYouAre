import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/theme/app_theme.dart';
import 'package:how_predictable/views/dialogs/settings_dialog.dart';
import 'package:how_predictable/views/dialogs/teleport_confirm_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/screens/world_map_screen.dart';
import 'package:how_predictable/views/widgets/rpg_teleport_portal_icon.dart';

class _TeleportTestPlayGamesClient implements PlayGamesClient {
  String? savedPayload;
  int saveCount = 0;

  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'PortalCleric';

  @override
  Future<String?> getPlayerID() async => 'player_portal_1';

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

  group('Teleport Portal AppBar Button, Dialog & Week Progression Tests', () {
    testWidgets(
      'GameScreen AppBar replaces Shopping Cart with fixed-size Teleport button, Cancel keeps player in battle, and Confirm returns to WorldMapScreen with orbs kept, Mana/HP reset, and +1 Week',
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
          'soundEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final localization = LocalizationService();
        await tester.runAsync(() => localization.load());

        final fakeClient = _TeleportTestPlayGamesClient();
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        await playGames.signIn();
        fakeClient.saveCount = 0;

        final controller = GameController(
          storage: storage,
          localization: localization,
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

        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(controller.currentWeek, 1);

        // Enter battle via Metal Wizard's Lair
        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GameScreen), findsOneWidget);

        // Shopping Cart is removed; Teleport Portal button is present with fixed 36x36 / 28x28 size
        expect(find.byIcon(Icons.shopping_cart_outlined), findsNothing);
        final teleportBtn = find.byKey(const ValueKey('teleport_portal_button'));
        final teleportIcon = find.byType(RpgTeleportPortalIcon);
        expect(teleportBtn, findsOneWidget);
        expect(teleportIcon, findsOneWidget);
        expect(tester.getSize(teleportBtn), equals(const Size(36.0, 36.0)));
        expect(tester.getSize(teleportIcon), equals(const Size(34.0, 34.0)));

        // Play 2 rounds: 1 win (+1 Fire Orb) and 1 loss (-1 Player HP)
        controller.crystalBallMove = HandMove.rock;
        await tester.tap(find.byKey(const ValueKey('hand_button_paper')));
        await tester.pumpAndSettle();
        controller.crystalBallMove = HandMove.paper;
        await tester.tap(find.byKey(const ValueKey('hand_button_rock')));
        await tester.pumpAndSettle();

        expect(controller.totalRounds, 2);
        expect(controller.remainingMana, 98);
        expect(controller.fireOrbs, 1);
        expect(controller.userHp, 49);
        expect(controller.computerHp, 99);

        // Tap Teleport -> opens TeleportConfirmDialog
        await tester.tap(teleportBtn);
        await tester.pumpAndSettle();

        expect(find.byType(TeleportConfirmDialog), findsOneWidget);
        expect(find.text('Teleport to World Map?'), findsOneWidget);
        expect(find.text('+1 Week will pass'), findsOneWidget);
        expect(find.text('Collected Elemental Orbs are kept'), findsOneWidget);

        // Check "Don't show this again" then tap Cancel -> must stay in battle and NOT persist suppression
        await tester.tap(
          find.byKey(const ValueKey('teleport_dont_show_again_checkbox')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('teleport_cancel_button')));
        await tester.pumpAndSettle();

        expect(find.byType(TeleportConfirmDialog), findsNothing);
        expect(find.byType(GameScreen), findsOneWidget);
        expect(controller.currentWeek, 1);
        expect(controller.totalRounds, 2);
        expect(controller.remainingMana, 98);
        expect(controller.confirmBattleTeleport, isTrue);
        expect(storage.confirmBattleTeleport, isTrue);

        // Tap Teleport again -> dialog still appears; tap Teleport without checking checkbox
        await tester.tap(teleportBtn);
        await tester.pumpAndSettle();
        expect(find.byType(TeleportConfirmDialog), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('teleport_confirm_button')));
        await tester.pumpAndSettle();

        // Returned smoothly to WorldMapScreen, Week advanced 1 -> 2, orbs preserved, battle reset cleanly
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(find.byType(GameScreen), findsNothing);
        expect(controller.currentWeek, 2);
        expect(storage.currentWeek, 2);
        expect(find.text('Week 2 / 40'), findsOneWidget);

        expect(controller.fireOrbs, 1);
        expect(storage.fireOrbs, 1);
        expect(controller.totalRounds, 0);
        expect(controller.remainingMana, 100);
        expect(controller.userHp, 50);
        expect(controller.computerHp, 100);
        expect(controller.userScore, 0);
        expect(controller.pcScore, 0);
        expect(controller.confirmBattleTeleport, isTrue);

        // Cloud Save persisted Week 2 and Orbs
        expect(fakeClient.saveCount, greaterThanOrEqualTo(1));
        final cloud = CloudSaveData.tryParse(fakeClient.savedPayload)!;
        expect(cloud.currentWeek, 2);
        expect(cloud.fireOrbs, 1);
      },
    );

    testWidgets(
      'Checking "Don\'t show this again" bypasses dialog on subsequent Teleport taps, and SettingsDialog toggle restores confirmation',
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
          'soundEnabled': false,
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
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Enter battle, earn +1 Water Orb, check "Don't show this again", and confirm Teleport
        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();

        controller.crystalBallMove = HandMove.paper;
        await tester.tap(find.byKey(const ValueKey('hand_button_scissors')));
        await tester.pumpAndSettle();
        expect(controller.waterOrbs, 1);

        await tester.tap(find.byKey(const ValueKey('teleport_portal_button')));
        await tester.pumpAndSettle();
        expect(find.byType(TeleportConfirmDialog), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('teleport_dont_show_again_checkbox')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('teleport_confirm_button')));
        await tester.pumpAndSettle();

        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(controller.currentWeek, 2);
        expect(controller.waterOrbs, 1);
        expect(controller.confirmBattleTeleport, isFalse);
        expect(storage.confirmBattleTeleport, isFalse);

        // 2. Re-enter battle -> tapping Teleport skips confirmation dialog immediately!
        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GameScreen), findsOneWidget);

        controller.crystalBallMove = HandMove.scissors;
        await tester.tap(find.byKey(const ValueKey('hand_button_rock')));
        await tester.pumpAndSettle();
        expect(controller.woodOrbs, 1);

        await tester.tap(find.byKey(const ValueKey('teleport_portal_button')));
        await tester.pumpAndSettle();

        expect(find.byType(TeleportConfirmDialog), findsNothing);
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(controller.currentWeek, 3);
        expect(find.text('Week 3 / 40'), findsOneWidget);
        expect(controller.waterOrbs, 1);
        expect(controller.woodOrbs, 1);
        expect(controller.remainingMana, 100);
        expect(controller.userHp, 50);

        // 3. Re-enable confirmation via SettingsDialog toggle ("Confirm Battle Teleport")
        await tester.tap(
          find.byKey(const ValueKey('world_map_settings_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SettingsDialog), findsOneWidget);

        final confirmTile = find.byKey(
          const ValueKey('settings_confirm_teleport_tile'),
        );
        await tester.ensureVisible(confirmTile);
        await tester.pumpAndSettle();
        expect(find.text('Confirm Battle Teleport'), findsOneWidget);
        await tester.tap(confirmTile);
        await tester.pumpAndSettle();

        expect(controller.confirmBattleTeleport, isTrue);
        expect(storage.confirmBattleTeleport, isTrue);

        await tester.tap(find.byKey(const ValueKey('settings_ok_button')));
        await tester.pumpAndSettle();

        // 4. Re-enter battle -> Teleport prompt is shown again
        await tester.tap(
          find.byKey(const ValueKey('landmark_metal_wizard_lair')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('teleport_portal_button')));
        await tester.pumpAndSettle();
        expect(find.byType(TeleportConfirmDialog), findsOneWidget);
      },
    );

    testWidgets(
      'TeleportConfirmDialog adapts cleanly to Light Mode warm parchment and Dark Mode surfaces',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'darkMode': false,
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
        addTearDown(controller.dispose);

        const lightPalette = AppPalette(isDark: false);

        // Light Mode check
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: Scaffold(
              body: TeleportConfirmDialog(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final lightDialog = tester.widget<Dialog>(find.byType(Dialog));
        expect(lightDialog.backgroundColor, lightPalette.dialogSurface);
        final lightMsgCard = tester.widget<Container>(
          find.byKey(const ValueKey('teleport_confirm_message_card')),
        );
        expect(
          (lightMsgCard.decoration! as BoxDecoration).color,
          lightPalette.dialogCardSurface,
        );
        final lightTitle = tester.widget<Text>(
          find.text('Teleport to World Map?'),
        );
        expect(lightTitle.style?.color, lightPalette.primaryText);

        // Dark Mode check
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: TeleportConfirmDialog(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final darkDialog = tester.widget<Dialog>(find.byType(Dialog));
        expect(darkDialog.backgroundColor, const Color(0xFF14161D));
      },
    );

    test(
      'resetAllProgress resets confirmBattleTeleport to true, CloudSaveData round-trips it, and en/pt/es/de localizations are present',
      () async {
        SharedPreferences.setMockInitialValues({
          'confirm_battle_teleport': false,
          'current_week': 5,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final localization = LocalizationService();
        await localization.load();

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
        );
        addTearDown(controller.dispose);

        expect(controller.confirmBattleTeleport, isFalse);
        expect(controller.skipTeleportConfirm, isTrue);

        // CloudSaveData round-trip
        final snapshot = CloudSaveData.fromStorage(storage);
        expect(snapshot.confirmBattleTeleport, isFalse);
        final parsed = CloudSaveData.tryParse(snapshot.toJsonString())!;
        expect(parsed.confirmBattleTeleport, isFalse);

        // Starting a brand-new campaign resets confirmation preference back to true and week to 0
        await controller.resetAllProgress();
        expect(controller.confirmBattleTeleport, isTrue);
        expect(controller.skipTeleportConfirm, isFalse);
        expect(storage.confirmBattleTeleport, isTrue);
        expect(controller.currentWeek, 0);

        // Localization keys across en, pt, es, de
        const keys = [
          'teleport_tooltip',
          'teleport_confirm_title',
          'teleport_confirm_body',
          'teleport_confirm_week_badge',
          'teleport_confirm_orbs_kept',
          'teleport_dont_show_again',
          'teleport_cancel',
          'teleport_confirm_action',
          'settings_confirm_teleport',
        ];
        for (final lang in ['en', 'pt', 'es', 'de']) {
          localization.setLanguage(lang);
          for (final key in keys) {
            final translated = localization.t(key);
            expect(
              translated,
              isNot(key),
              reason: 'Missing $lang translation for $key',
            );
            expect(translated.trim(), isNotEmpty);
          }
        }
      },
    );
  });
}
