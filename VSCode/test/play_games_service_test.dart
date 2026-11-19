import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/models/story_chapter.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';

class FakePlayGamesClient implements PlayGamesClient {
  bool shouldSucceedSignIn;
  String? mockPlayerName;
  String? mockPlayerId;
  final Map<String, String?> _cloudSavesByPlayer = {};
  int saveCallCount = 0;
  int loadCallCount = 0;
  int signInCallCount = 0;

  FakePlayGamesClient({
    this.shouldSucceedSignIn = true,
    this.mockPlayerName = 'MasterHand99',
    this.mockPlayerId = 'player_987654321',
    String? cloudPayload,
  }) {
    if (cloudPayload != null) {
      _cloudSavesByPlayer[mockPlayerId ?? ''] = cloudPayload;
    }
  }

  String? get cloudPayload => _cloudSavesByPlayer[mockPlayerId ?? ''];
  set cloudPayload(String? value) {
    _cloudSavesByPlayer[mockPlayerId ?? ''] = value;
  }

  String? cloudSaveForPlayer(String playerId) => _cloudSavesByPlayer[playerId];
  void setCloudSaveForPlayer(String playerId, String? payload) {
    _cloudSavesByPlayer[playerId] = payload;
  }

  @override
  Future<String?> signIn() async {
    signInCallCount++;
    if (!shouldSucceedSignIn) return null;
    return 'success';
  }

  @override
  Future<String?> getPlayerName() async => mockPlayerName;

  @override
  Future<String?> getPlayerID() async => mockPlayerId;

  @override
  Future<String?> saveGame({required String data, required String name}) async {
    saveCallCount++;
    _cloudSavesByPlayer[mockPlayerId ?? ''] = data;
    return 'success';
  }

  @override
  Future<String?> loadGame({required String name}) async {
    loadCallCount++;
    return _cloudSavesByPlayer[mockPlayerId ?? ''];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayGamesService Unit Tests', () {
    test(
      'Gracefully falls back to offline SharedPreferences cache when silent sign-in fails or is declined',
      () async {
        SharedPreferences.setMockInitialValues({
          'orbs_fire': 120,
          'orbs_water': 110,
          'unlockedReset': true,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakePlayGamesClient(shouldSucceedSignIn: false);
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );

        final connected = await playGames.initialize();

        expect(connected, isFalse);
        expect(playGames.isSignedIn, isFalse);
        expect(playGames.playerName, isNull);
        expect(playGames.playerID, isNull);
        expect(playGames.syncStatus, CloudSyncStatus.offline);
        expect(storage.fireOrbs, 120);
        expect(storage.waterOrbs, 110);
        expect(storage.unlockedReset, isTrue);
      },
    );

    test(
      'CloudSaveData.fromJson migrates legacy v1 diamonds payload cleanly into all 5 Elemental Orbs when orbs are 0',
      () {
        final legacyData = CloudSaveData.fromJson({
          'version': 1,
          'diamonds': 340,
          'userScore': 5,
        });
        expect(legacyData.fireOrbs, 340);
        expect(legacyData.waterOrbs, 340);
        expect(legacyData.woodOrbs, 340);
        expect(legacyData.earthOrbs, 340);
        expect(legacyData.metalOrbs, 340);
      },
    );

    test(
      'Multi-account Cloud Save isolation: isolates both gameplay progress and settings per account when active playerID changes',
      () async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
        });
        final storage = StorageService();
        await storage.init();

        final localization = LocalizationService();
        localization.setLanguage(storage.language);
        final audio = AudioService();

        final account1Save = CloudSaveData(
          fireOrbs: 650,
          waterOrbs: 600,
          woodOrbs: 550,
          earthOrbs: 400,
          metalOrbs: 350,
          userScore: 18,
          pcScore: 7,
          total: 25,
          unlockedReset: true,
          unlockedAlgorithm: true,
          showReset: true,
          showAlgorithm: true,
          hasSeenStoryReset: true,
          hasSeenStoryAlgorithm: true,
          lastUserMoveId: HandMove.scissors.id,
          lastComputerMoveId: HandMove.paper.id,
          markovMatrix3: const [
            [4, 2, 1],
            [1, 5, 2],
            [3, 1, 6],
          ],
          language: 'pt',
          darkMode: false,
          soundEnabled: false,
          musicEnabled: false,
          vibrationEnabled: false,
          animationsEnabled: false,
        );

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'PlayerOne',
          mockPlayerId: 'player_001',
          cloudPayload: account1Save.toJsonString(),
        );

        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: audio,
          playGames: playGames,
        );

        // 1. Sign in as Account 1 ('player_001')
        final signedIn = await playGames.initialize();
        expect(signedIn, isTrue);
        expect(playGames.isSignedIn, isTrue);
        expect(playGames.playerName, 'PlayerOne');
        expect(playGames.playerID, 'player_001');
        expect(playGames.lastPlayerID, 'player_001');
        expect(storage.lastPlayerId, 'player_001');
        expect(controller.fireOrbs, 650);
        expect(controller.waterOrbs, 600);
        expect(controller.woodOrbs, 550);
        expect(controller.earthOrbs, 400);
        expect(controller.metalOrbs, 350);
        expect(controller.userScore, 18);
        expect(controller.pcScore, 7);
        expect(controller.totalRounds, 25);
        expect(controller.unlockedReset, isTrue);
        expect(controller.unlockedAlgorithm, isTrue);
        expect(controller.showReset, isTrue);
        expect(controller.showAlgorithm, isTrue);
        expect(controller.currentUserMove, HandMove.scissors);
        expect(controller.currentComputerMove, HandMove.paper);
        expect(controller.engine.matrix[0], [4, 2, 1]);
        // Account 1's cloud settings are applied
        expect(storage.language, 'pt');
        expect(localization.currentLanguage, 'pt');
        expect(controller.darkMode, isFalse);
        expect(controller.soundEnabled, isFalse);
        expect(controller.musicEnabled, isFalse);
        expect(controller.vibrationEnabled, isFalse);
        expect(controller.animationsEnabled, isFalse);

        // 2. Switch accounts in OS / Google Play Games app to Account 2 ('player_002'),
        // which has NO cloud save (null), and return to the game (AppLifecycleState.resumed)
        fakeClient.mockPlayerName = 'FreshNewPlayer';
        fakeClient.mockPlayerId = 'player_002';
        fakeClient.setCloudSaveForPlayer('player_002', null);

        controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(playGames.isSignedIn, isTrue);
        expect(playGames.playerName, 'FreshNewPlayer');
        expect(playGames.playerID, 'player_002');
        expect(playGames.lastPlayerID, 'player_002');
        expect(storage.lastPlayerId, 'player_002');

        // Local gameplay progress must be completely wiped to 0 / false / empty
        expect(controller.totalOrbs, 0);
        expect(storage.totalOrbs, 0);
        expect(controller.userScore, 0);
        expect(controller.pcScore, 0);
        expect(controller.totalRounds, 0);
        expect(controller.unlockedReset, isFalse);
        expect(controller.unlockedAlgorithm, isFalse);
        expect(controller.showReset, isFalse);
        expect(controller.showAlgorithm, isFalse);
        expect(controller.hasSeenStoryReset, isFalse);
        expect(controller.hasSeenStoryAlgorithm, isFalse);
        expect(controller.currentUserMove, isNull);
        expect(controller.currentComputerMove, isNull);
        expect(controller.lastUserMove, isNull);
        expect(controller.lastWinner, isNull);
        expect(storage.getMarkovMatrix(3), isNull);
        expect(controller.engine.matrix, const [
          [0, 0, 0],
          [0, 0, 0],
          [0, 0, 0],
        ]);

        // UI settings must also be isolated and reset to fresh defaults for Account 2
        expect(storage.language, 'en');
        expect(localization.currentLanguage, 'en');
        expect(controller.soundEnabled, isTrue);
        expect(controller.musicEnabled, isTrue);
        expect(controller.vibrationEnabled, isTrue);
        expect(controller.darkMode, isTrue);
        expect(controller.animationsEnabled, isTrue);

        // 3. Switch in OS / Google Play Games app to Account 3 ('player_003'),
        // which has its own cloud save with 220 Fire Orbs, unlockedRandom, and 'es' settings
        final account3Save = CloudSaveData(
          fireOrbs: 220,
          waterOrbs: 180,
          woodOrbs: 150,
          userScore: 8,
          pcScore: 4,
          total: 12,
          unlockedRandom: true,
          showRandom: true,
          lastUserMoveId: HandMove.rock.id,
          lastComputerMoveId: HandMove.scissors.id,
          markovMatrix3: const [
            [1, 0, 2],
            [0, 3, 1],
            [2, 2, 0],
          ],
          language: 'es',
          darkMode: true,
          soundEnabled: true,
          musicEnabled: false,
          vibrationEnabled: false,
          animationsEnabled: true,
        );
        fakeClient.mockPlayerName = 'ThirdAccount';
        fakeClient.mockPlayerId = 'player_003';
        fakeClient.setCloudSaveForPlayer(
          'player_003',
          account3Save.toJsonString(),
        );

        controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(playGames.playerName, 'ThirdAccount');
        expect(playGames.playerID, 'player_003');
        expect(controller.fireOrbs, 220);
        expect(controller.waterOrbs, 180);
        expect(controller.woodOrbs, 150);
        expect(controller.userScore, 8);
        expect(controller.pcScore, 4);
        expect(controller.totalRounds, 12);
        expect(controller.unlockedRandom, isTrue);
        expect(controller.showRandom, isTrue);
        expect(controller.unlockedReset, isFalse);
        expect(controller.unlockedAlgorithm, isFalse);
        expect(controller.currentUserMove, HandMove.rock);
        expect(controller.currentComputerMove, HandMove.scissors);
        expect(controller.engine.matrix[1], [0, 3, 1]);
        expect(storage.language, 'es');
        expect(localization.currentLanguage, 'es');
        expect(controller.darkMode, isTrue);
        expect(controller.soundEnabled, isTrue);
        expect(controller.musicEnabled, isFalse);
        expect(controller.vibrationEnabled, isFalse);
        expect(controller.animationsEnabled, isTrue);

        // 4. Switch back to Account 1 ('player_001') -> restores Account 1's orbs, unlocks, & 'pt' settings
        fakeClient.mockPlayerName = 'PlayerOne';
        fakeClient.mockPlayerId = 'player_001';

        controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(playGames.playerName, 'PlayerOne');
        expect(playGames.playerID, 'player_001');
        expect(controller.fireOrbs, 650);
        expect(controller.waterOrbs, 600);
        expect(controller.userScore, 18);
        expect(controller.unlockedReset, isTrue);
        expect(controller.unlockedAlgorithm, isTrue);
        expect(controller.unlockedRandom, isFalse);
        expect(controller.engine.matrix[0], [4, 2, 1]);
        expect(storage.language, 'pt');
        expect(localization.currentLanguage, 'pt');
        expect(controller.darkMode, isFalse);
        expect(controller.soundEnabled, isFalse);
        expect(controller.musicEnabled, isFalse);
        expect(controller.vibrationEnabled, isFalse);
        expect(controller.animationsEnabled, isFalse);
      },
    );

    test(
      'Conflict resolution restores cloud save over local data when cloud holds higher orb count or progression',
      () async {
        // Local has 50 Fire Orbs and 0 unlocks
        SharedPreferences.setMockInitialValues({
          'orbs_fire': 50,
          'userScore': 2,
          'pcScore': 3,
          'total': 5,
          'unlockedReset': false,
          'unlockedAlgorithm': false,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        // Cloud has 750 Fire Orbs, 3 unlocks, higher scores, and a populated Markov matrix
        final cloudSnapshot = CloudSaveData(
          fireOrbs: 750,
          waterOrbs: 500,
          woodOrbs: 400,
          userScore: 25,
          pcScore: 15,
          total: 40,
          unlockedReset: true,
          unlockedAlgorithm: true,
          unlockedNewSkin: true,
          showReset: true,
          showAlgorithm: true,
          showNewSkin: true,
          lastUserMoveId: HandMove.paper.id,
          lastComputerMoveId: HandMove.rock.id,
          markovMatrix3: const [
            [2, 5, 1],
            [3, 1, 4],
            [0, 2, 6],
          ],
        );

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          cloudPayload: cloudSnapshot.toJsonString(),
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await playGames.initialize();

        expect(controller.fireOrbs, 750);
        expect(controller.waterOrbs, 500);
        expect(controller.woodOrbs, 400);
        expect(controller.userScore, 25);
        expect(controller.pcScore, 15);
        expect(controller.totalRounds, 40);
        expect(controller.unlockedReset, isTrue);
        expect(controller.unlockedAlgorithm, isTrue);
        expect(controller.unlockedNewSkin, isTrue);
        expect(controller.showReset, isTrue);
        expect(controller.showAlgorithm, isTrue);
        expect(controller.showNewSkin, isTrue);
        expect(controller.currentUserMove, HandMove.paper);
        expect(controller.currentComputerMove, HandMove.rock);
        expect(controller.engine.matrix[0], [2, 5, 1]);
      },
    );

    test(
      'Conflict resolution keeps local data and backs up to cloud when local holds higher progression or orb count',
      () async {
        // Local has 2000 Fire Orbs and 3 unlocks
        SharedPreferences.setMockInitialValues({
          'orbs_fire': 2000,
          'orbs_water': 1500,
          'userScore': 30,
          'pcScore': 10,
          'total': 40,
          'unlockedReset': true,
          'unlockedPredictability': true,
          'unlockedRandom': true,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        // Cloud has only 100 Fire Orbs and 0 unlocks
        final staleCloudSnapshot = const CloudSaveData(
          fireOrbs: 100,
          userScore: 1,
          pcScore: 1,
          total: 2,
        );

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          cloudPayload: staleCloudSnapshot.toJsonString(),
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await playGames.initialize();

        // Local progression must be preserved
        expect(controller.fireOrbs, 2000);
        expect(controller.waterOrbs, 1500);
        expect(controller.userScore, 30);
        expect(controller.unlockedReset, isTrue);
        expect(controller.unlockedPredictability, isTrue);
        expect(controller.unlockedRandom, isTrue);

        // Local progression was backed up to cloud
        expect(fakeClient.saveCallCount, greaterThanOrEqualTo(1));
        final savedToCloud = CloudSaveData.tryParse(fakeClient.cloudPayload)!;
        expect(savedToCloud.fireOrbs, 2000);
        expect(savedToCloud.waterOrbs, 1500);
        expect(savedToCloud.unlockedCount, 3);
      },
    );

    test(
      'Triggers cloud save automatically whenever orbs or purchases change',
      () async {
        SharedPreferences.setMockInitialValues({
          'orbs_fire': 500,
          'orbs_water': 500,
          'orbs_wood': 500,
          'giftBoxUnlocked': true,
          'giftBoxEnabled': true,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakePlayGamesClient(shouldSucceedSignIn: true);
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await playGames.initialize();
        final initialSaves = fakeClient.saveCallCount;

        // 1. Purchasing an item (Reset: 30 Fire + 30 Water + 30 Wood) triggers a cloud save
        expect(controller.unlockReset(), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(fakeClient.saveCallCount, equals(initialSaves + 1));
        var syncedData = CloudSaveData.tryParse(fakeClient.cloudPayload)!;
        expect(syncedData.fireOrbs, 470);
        expect(syncedData.waterOrbs, 470);
        expect(syncedData.woodOrbs, 470);
        expect(syncedData.unlockedReset, isTrue);

        // 2. Claiming periodic gift (+5 of each orb) triggers a cloud save
        controller.claimGift();
        await Future<void>.delayed(Duration.zero);
        expect(fakeClient.saveCallCount, equals(initialSaves + 2));
        syncedData = CloudSaveData.tryParse(fakeClient.cloudPayload)!;
        expect(syncedData.fireOrbs, 475);
        expect(syncedData.waterOrbs, 475);
        expect(syncedData.woodOrbs, 475);
        expect(syncedData.earthOrbs, 5);
        expect(syncedData.metalOrbs, 5);
        controller.cancelPendingTimers();

        // 3. Adding free orbs triggers a cloud save
        controller.addAllOrbs(50);
        await Future<void>.delayed(Duration.zero);
        expect(fakeClient.saveCallCount, equals(initialSaves + 3));
        syncedData = CloudSaveData.tryParse(fakeClient.cloudPayload)!;
        expect(syncedData.fireOrbs, 525);
        expect(syncedData.earthOrbs, 55);

        // 4. Changing settings triggers cloud saves for the signed-in account
        controller.setLanguage('de');
        controller.toggleDarkMode(false);
        controller.toggleSound();
        controller.toggleVibration(false);
        controller.toggleAnimations(false);
        await Future<void>.delayed(Duration.zero);
        syncedData = CloudSaveData.tryParse(fakeClient.cloudPayload)!;
        expect(syncedData.language, 'de');
        expect(syncedData.darkMode, isFalse);
        expect(syncedData.soundEnabled, isFalse);
        expect(syncedData.vibrationEnabled, isFalse);
        expect(syncedData.animationsEnabled, isFalse);
      },
    );

    test(
      'CloudSaveData syncs giftBoxUnlocked & giftBoxEnabled and migrates legacy saves cleanly',
      () async {
        // 1. Legacy cloud JSON without giftBoxUnlocked/giftBoxEnabled defaults both to false
        final legacyCloud = CloudSaveData.fromJson({
          'fireOrbs': 600,
          'waterOrbs': 600,
          'woodOrbs': 600,
          'earthOrbs': 600,
          'metalOrbs': 600,
          'userScore': 12,
          'pcScore': 8,
          'total': 20,
          'unlockedReset': true,
          'showReset': true,
        });
        expect(legacyCloud.giftBoxUnlocked, isFalse);
        expect(legacyCloud.giftBoxEnabled, isFalse);
        expect(legacyCloud.unlockedCount, 1);

        // 2. Active local save restores legacy cloud cleanly without losing orbs/scores
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'LegacyHero',
          mockPlayerId: 'player_legacy_gift',
          cloudPayload: legacyCloud.toJsonString(),
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await playGames.initialize();
        expect(controller.fireOrbs, 600);
        expect(controller.userScore, 12);
        expect(controller.unlockedReset, isTrue);
        expect(controller.giftBoxUnlocked, isFalse);
        expect(controller.giftBoxEnabled, isFalse);

        // 3. Purchasing & enabling Gift Box syncs both flags to cloud JSON
        expect(controller.unlockGiftBox(), isTrue);
        await Future<void>.delayed(Duration.zero);
        var synced = CloudSaveData.tryParse(fakeClient.cloudPayload)!;
        expect(synced.fireOrbs, 100);
        expect(synced.giftBoxUnlocked, isTrue);
        expect(synced.giftBoxEnabled, isFalse);
        expect(synced.unlockedCount, 2);

        controller.toggleGiftBox(true);
        await Future<void>.delayed(Duration.zero);
        synced = CloudSaveData.tryParse(fakeClient.cloudPayload)!;
        expect(synced.giftBoxUnlocked, isTrue);
        expect(synced.giftBoxEnabled, isTrue);

        // Round-trip via toJson / fromJson preserves both fields
        final roundTrip = CloudSaveData.fromJson(synced.toJson());
        expect(roundTrip.giftBoxUnlocked, isTrue);
        expect(roundTrip.giftBoxEnabled, isTrue);
      },
    );
  });

  group('SettingsDialog Player Profile & Reset All Progress UI Tests', () {
    testWidgets(
      'Displays single Sign in with Google Play button when disconnected, and shows connected profile card with copyable Player ID and NO Switch Account or Sign Out buttons',
      (WidgetTester tester) async {
        String? copiedClipboardText;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                final args = call.arguments as Map<dynamic, dynamic>;
                copiedClipboardText = args['text'] as String?;
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'musicEnabled': false,
          'animationsEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'OracleSlayer',
          mockPlayerId: 'player_4242',
          cloudPayload: const CloudSaveData(
            musicEnabled: false,
            animationsEnabled: false,
          ).toJsonString(),
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );

        // Open SettingsDialog
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();

        // Disconnected state: shows single "Sign in with Google Play" button & "Offline" badge
        expect(
          find.byKey(const ValueKey('play_games_sign_in_button')),
          findsOneWidget,
        );
        expect(find.text('Sign in with Google Play'), findsOneWidget);
        expect(find.text('Offline'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('play_games_switch_account_button')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('play_games_sign_out_button')),
          findsNothing,
        );

        // Tap "Sign in with Google Play"
        await tester.tap(
          find.byKey(const ValueKey('play_games_sign_in_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('play_games_profile_card')),
          findsOneWidget,
        );
        expect(find.text('OracleSlayer'), findsOneWidget);
        expect(find.text('ID: player_4242'), findsOneWidget);
        expect(find.text('Synced'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('play_games_copy_id_button')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
        expect(find.text('Switch Account'), findsNothing);
        expect(find.text('Sign Out'), findsNothing);

        // Tap copy button -> copies raw player ID to clipboard and shows "Player ID copied" SnackBar
        await tester.tap(
          find.byKey(const ValueKey('play_games_copy_id_button')),
        );
        await tester.pump();
        expect(copiedClipboardText, 'player_4242');
        expect(find.text('Player ID copied'), findsOneWidget);
      },
    );

    testWidgets(
      'Reset All Progress button in SettingsDialog asks for confirmation and resets all local and cloud progress so the user can restart fresh',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'orbs_fire': 800,
          'orbs_water': 800,
          'userScore': 20,
          'pcScore': 10,
          'total': 30,
          'unlockedReset': true,
          'showReset': true,
          'unlockedAlgorithm': true,
          'showAlgorithm': true,
          'musicEnabled': false,
          'animationsEnabled': false,
          'darkMode': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'ResetTester',
          mockPlayerId: 'player_reset',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await playGames.initialize();

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.fireOrbs, 800);
        expect(controller.unlockedReset, isTrue);
        expect(controller.unlockedAlgorithm, isTrue);

        // Open SettingsDialog
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();

        final resetBtn = find.byKey(
          const ValueKey('settings_reset_progress_button'),
        );
        await tester.ensureVisible(resetBtn);
        expect(resetBtn, findsOneWidget);
        expect(find.text('Reset All Progress'), findsOneWidget);

        // Tap Reset All Progress -> opens confirmation dialog; tap Cancel first
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();
        expect(find.text('Reset All Progress?'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('cancel_reset_progress_button')),
        );
        await tester.pumpAndSettle();
        expect(controller.fireOrbs, 800);
        expect(controller.unlockedReset, isTrue);

        // Tap Reset All Progress again and confirm
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('confirm_reset_progress_button')),
        );
        await tester.pumpAndSettle();

        // All progress is wiped locally and synced to cloud, while UI settings stay intact
        expect(controller.totalOrbs, 0);
        expect(storage.totalOrbs, 0);
        expect(controller.userScore, 0);
        expect(controller.pcScore, 0);
        expect(controller.totalRounds, 0);
        expect(controller.unlockedReset, isFalse);
        expect(controller.showReset, isFalse);
        expect(controller.unlockedAlgorithm, isFalse);
        expect(controller.showAlgorithm, isFalse);
        expect(controller.darkMode, isFalse);

        final cloudAfterReset =
            CloudSaveData.tryParse(fakeClient.cloudPayload)!;
        expect(cloudAfterReset.totalOrbs, 0);
        expect(cloudAfterReset.unlockedCount, 0);
        expect(cloudAfterReset.total, 0);
        expect(cloudAfterReset.darkMode, isFalse);
        expect(cloudAfterReset.hasSeenStoryIntro, isFalse);

        // Intro comic cutscene opens automatically as if opened for the first time
        expect(find.text("Prologue: The Master Hand's Shadow"), findsOneWidget);
        expect(find.text('Panel 1 / 4'), findsOneWidget);

        final nextBtnFinder = find.byKey(const ValueKey('story_next_button'));
        await tester.tap(nextBtnFinder); // Panel 2
        await tester.pumpAndSettle();
        await tester.tap(nextBtnFinder); // Panel 3
        await tester.pumpAndSettle();
        await tester.tap(nextBtnFinder); // Panel 4
        await tester.pumpAndSettle();
        await tester.tap(nextBtnFinder); // Finish cutscene
        await tester.pumpAndSettle();
        expect(find.text("Prologue: The Master Hand's Shadow"), findsNothing);
      },
    );

    testWidgets(
      'AppLifecycleState.resumed immediately detects OS-level account switch in Google Play Games app and updates UI orbs, progress, and profile card',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'musicEnabled': false,
          'animationsEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final accountASave = const CloudSaveData(
          fireOrbs: 420,
          waterOrbs: 300,
          userScore: 10,
          pcScore: 5,
          total: 15,
          unlockedReset: true,
          showReset: true,
          hasSeenStoryIntro: true,
        );

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'AccountAlpha',
          mockPlayerId: 'player_alpha',
          cloudPayload: accountASave.toJsonString(),
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await playGames.initialize();

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(controller.fireOrbs, 420);
        expect(find.byIcon(Icons.restart_alt), findsOneWidget);

        // Simulate user switching to AccountBeta in Google Play Games app while game is in background
        fakeClient.mockPlayerName = 'AccountBeta';
        fakeClient.mockPlayerId = 'player_beta';
        final accountBSave = const CloudSaveData(
          fireOrbs: 0,
          hasSeenStoryIntro: true,
        );
        fakeClient.setCloudSaveForPlayer(
          'player_beta',
          accountBSave.toJsonString(),
        );

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // UI immediately updates: orbs reset to 0, Reset button disappears
        expect(find.byIcon(Icons.restart_alt), findsNothing);
        expect(controller.totalOrbs, 0);
        expect(controller.unlockedReset, isFalse);

        // Open SettingsDialog -> shows AccountBeta's profile
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('AccountBeta'), findsOneWidget);
        expect(find.text('ID: player_beta'), findsOneWidget);
      },
    );
  });

  group('QA Tester Automatic 100,000 Elemental Orbs Bonus Grant Tests', () {
    test(
      '(a) Grants +100,000 of each Elemental Orb once on sign-in for matching tester IDs (Player 1 & Player 2) and case-insensitive playerName fallback, and saves to cloud',
      () async {
        // Test Player 1 by ID ("a_2116013489197419559")
        SharedPreferences.setMockInitialValues({
          'musicEnabled': false,
        });
        final storage1 = StorageService();
        await storage1.init();

        final fakeClient1 = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'gustlarsentester',
          mockPlayerId: 'a_2116013489197419559',
        );
        final playGames1 = PlayGamesService(
          storage: storage1,
          client: fakeClient1,
        );
        final controller1 = GameController(
          storage: storage1,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames1,
        );

        expect(controller1.totalOrbs, 0);
        expect(storage1.hasClaimedQaBonus, isFalse);

        final signedIn1 = await playGames1.initialize();
        expect(signedIn1, isTrue);
        expect(controller1.fireOrbs, 100000);
        expect(controller1.waterOrbs, 100000);
        expect(controller1.woodOrbs, 100000);
        expect(controller1.earthOrbs, 100000);
        expect(controller1.metalOrbs, 100000);
        expect(storage1.fireOrbs, 100000);
        expect(controller1.hasClaimedQaBonus, isTrue);
        expect(storage1.hasClaimedQaBonus, isTrue);
        expect(
          controller1.pendingQaBonusSnackBar,
          PlayGamesService.qaBonusSnackBarMessage,
        );

        final savedCloud1 =
            CloudSaveData.tryParse(fakeClient1.cloudPayload)!;
        expect(savedCloud1.fireOrbs, 100000);
        expect(savedCloud1.waterOrbs, 100000);
        expect(savedCloud1.woodOrbs, 100000);
        expect(savedCloud1.earthOrbs, 100000);
        expect(savedCloud1.metalOrbs, 100000);
        expect(savedCloud1.hasClaimedQaBonus, isTrue);

        // Spend some orbs on Player 1 before switching
        controller1.unlockReset(); // 30 Fire + 30 Water + 30 Wood
        expect(controller1.fireOrbs, 99970);
        final savedCloud1AfterSpend = CloudSaveData.tryParse(
          fakeClient1.cloudSaveForPlayer('a_2116013489197419559'),
        )!;
        expect(savedCloud1AfterSpend.fireOrbs, 99970);

        // Test Player 2 by ID ("g01804264806540615668") and when switching accounts on AppLifecycleState.resumed
        fakeClient1.mockPlayerName = 'gustlarsen';
        fakeClient1.mockPlayerId = 'g01804264806540615668';
        fakeClient1.setCloudSaveForPlayer('g01804264806540615668', null);

        // Resume app after OS account switch to Player 2
        await playGames1.handleAppResumed();
        expect(playGames1.playerID, 'g01804264806540615668');
        expect(controller1.fireOrbs, 100000);
        expect(controller1.metalOrbs, 100000);
        expect(storage1.fireOrbs, 100000);
        expect(storage1.hasClaimedQaBonus, isTrue);
        final savedCloud2 = CloudSaveData.tryParse(
          fakeClient1.cloudSaveForPlayer('g01804264806540615668'),
        )!;
        expect(savedCloud2.fireOrbs, 100000);
        expect(savedCloud2.hasClaimedQaBonus, isTrue);

        // Test case-insensitive playerName fallback ("GUSTLARSENTESTER") with a different ID
        SharedPreferences.setMockInitialValues({
          'musicEnabled': false,
        });
        final storageFallback = StorageService();
        await storageFallback.init();
        final fakeClientFallback = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'GUSTLARSENTESTER',
          mockPlayerId: 'unlisted_id_999',
        );
        final playGamesFallback = PlayGamesService(
          storage: storageFallback,
          client: fakeClientFallback,
        );
        final controllerFallback = GameController(
          storage: storageFallback,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGamesFallback,
        );

        await playGamesFallback.initialize();
        expect(controllerFallback.fireOrbs, 100000);
        expect(controllerFallback.metalOrbs, 100000);
        expect(storageFallback.hasClaimedQaBonus, isTrue);
      },
    );

    test(
      '(b) Prevents duplicate grants on subsequent sign-ins when hasClaimedQaBonus is already true in local storage or cloud save',
      () async {
        SharedPreferences.setMockInitialValues({
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'gustlarsentester',
          mockPlayerId: 'a_2116013489197419559',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        // First sign-in grants +100,000 of each Elemental Orb
        await playGames.initialize();
        expect(controller.fireOrbs, 100000);
        expect(storage.hasClaimedQaBonus, isTrue);
        expect(
          controller.consumePendingQaBonusSnackBar(),
          PlayGamesService.qaBonusSnackBarMessage,
        );

        // Tester spends orbs on Crystal Ball -> 96,500 Fire/Water/Wood & 97,500 Earth/Metal left
        expect(controller.unlockCrystalBall(), isTrue);
        expect(controller.fireOrbs, 96500);
        await Future<void>.delayed(Duration.zero);

        // Subsequent sign-in / app resume with local & cloud hasClaimedQaBonus = true
        await playGames.handleAppResumed();
        expect(controller.fireOrbs, 96500);
        expect(controller.pendingQaBonusSnackBar, isNull);

        // Fresh install on another device (local storage hasClaimedQaBonus = false,
        // but loaded cloud save has hasClaimedQaBonus = true and 96,500 Fire orbs)
        SharedPreferences.setMockInitialValues({
          'musicEnabled': false,
        });
        final freshDeviceStorage = StorageService();
        await freshDeviceStorage.init();
        expect(freshDeviceStorage.hasClaimedQaBonus, isFalse);

        final playGamesDevice2 = PlayGamesService(
          storage: freshDeviceStorage,
          client: fakeClient,
        );
        final controllerDevice2 = GameController(
          storage: freshDeviceStorage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGamesDevice2,
        );

        await playGamesDevice2.initialize();
        // Restores 96,500 from cloud without granting another 100,000
        expect(controllerDevice2.fireOrbs, 96500);
        expect(freshDeviceStorage.hasClaimedQaBonus, isTrue);
        expect(controllerDevice2.pendingQaBonusSnackBar, isNull);
      },
    );

    test(
      '(c) Preserves Elemental Orb balances on match reset (resetGame) and re-grants the +100,000 tester bonus only on full progression wipe (resetAllProgress)',
      () async {
        SharedPreferences.setMockInitialValues({
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'gustlarsen',
          mockPlayerId: 'g01804264806540615668',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        // Initial sign-in grants +100,000 of each Elemental Orb
        await playGames.initialize();
        expect(controller.fireOrbs, 100000);
        expect(storage.hasClaimedQaBonus, isTrue);
        controller.consumePendingQaBonusSnackBar();

        // Spend orbs on Crystal Ball & Crystal Ball Plus
        expect(controller.unlockCrystalBall(), isTrue);
        expect(controller.unlockCrystalBallPlus(), isTrue);
        expect(controller.fireOrbs, 91500);

        // 1. Trigger resetGame -> resets match state only, does NOT grant extra QA bonus
        controller.resetGame();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(controller.fireOrbs, 91500);
        expect(storage.fireOrbs, 91500);
        expect(storage.hasClaimedQaBonus, isTrue);
        expect(controller.pendingQaBonusSnackBar, isNull);

        // 2. Trigger full progression reset (resetAllProgress) -> wipes orbs to 0 & hasClaimedQaBonus to false,
        // syncs to cloud, and automatically re-grants +100,000 of each Elemental Orb
        await controller.resetAllProgress();
        expect(controller.fireOrbs, 100000);
        expect(controller.metalOrbs, 100000);
        expect(storage.fireOrbs, 100000);
        expect(storage.hasClaimedQaBonus, isTrue);
        expect(controller.pendingStoryChapter, StoryChapter.intro);
        expect(controller.hasSeenStoryIntro, isFalse);
        expect(storage.hasSeenStoryIntro, isFalse);
        expect(
          controller.consumePendingQaBonusSnackBar(),
          PlayGamesService.qaBonusSnackBarMessage,
        );

        final cloudAfterReset =
            CloudSaveData.tryParse(fakeClient.cloudPayload)!;
        expect(cloudAfterReset.fireOrbs, 100000);
        expect(cloudAfterReset.metalOrbs, 100000);
        expect(cloudAfterReset.hasClaimedQaBonus, isTrue);
        expect(cloudAfterReset.hasSeenStoryIntro, isFalse);
      },
    );

    testWidgets(
      'Shows QA Tester Bonus SnackBar in UI when QA tester signs in',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'musicEnabled': false,
          'animationsEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'gustlarsentester',
          mockPlayerId: 'a_2116013489197419559',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );

        await playGames.initialize();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text(PlayGamesService.qaBonusSnackBarMessage),
          findsOneWidget,
        );
        expect(controller.fireOrbs, 100000);
        expect(controller.metalOrbs, 100000);
      },
    );

    testWidgets(
      'Clicking TRY AGAIN after 100 rounds resets match stats without re-granting QA tester bonus orbs or showing SnackBar',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'musicEnabled': false,
          'animationsEnabled': false,
          'userScore': 50,
          'pcScore': 50,
          'total': 100,
          'orbs_fire': 100000,
          'orbs_water': 100000,
          'orbs_wood': 100000,
          'orbs_earth': 100000,
          'orbs_metal': 100000,
          'hasClaimedQaBonus': true,
        });
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'gustlarsentester',
          mockPlayerId: 'a_2116013489197419559',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await playGames.initialize();
        controller.consumePendingQaBonusSnackBar();

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('TRY AGAIN'), findsOneWidget);
        expect(controller.fireOrbs, 100000);

        await tester.tap(find.text('TRY AGAIN'));
        await tester.pumpAndSettle();

        expect(controller.totalRounds, 0);
        expect(controller.userScore, 0);
        expect(controller.pcScore, 0);
        expect(controller.fireOrbs, 100000);
        expect(
          find.text(PlayGamesService.qaBonusSnackBarMessage),
          findsNothing,
        );
      },
    );
  });

  group('Security & Anti-Breach Tests: QA Bonus Isolation & Non-Tester Protection', () {
    test(
      'isQaTester rejects lookalike, prefix, suffix, substring, empty, and normal player IDs and names',
      () {
        expect(PlayGamesService.isQaTester(playerId: 'a_2116013489197419559'), isTrue);
        expect(PlayGamesService.isQaTester(playerId: 'g01804264806540615668'), isTrue);
        expect(PlayGamesService.isQaTester(playerId: '  a_2116013489197419559  '), isTrue);
        expect(PlayGamesService.isQaTester(playerName: 'gustlarsentester'), isTrue);
        expect(PlayGamesService.isQaTester(playerName: 'gustlarsen'), isTrue);
        expect(PlayGamesService.isQaTester(playerName: 'GUSTLARSEN'), isTrue);
        expect(PlayGamesService.isQaTester(playerName: ' GustLarsenTester '), isTrue);

        final unauthorizedNames = [
          '',
          '   ',
          'not_gustlarsen',
          'fake_gustlarsentester',
          'gustlarsen_fan',
          'gustlarsentester1',
          'gustlarsentester_fake',
          'gustlarsen123',
          'agustlarsen',
          'agustlarsentester',
          'gust',
          'larsen',
          'tester',
          'gustlars',
          'Play Games Player',
          'GPG-PLAYER',
          'pro_gamer_2026',
        ];
        for (final name in unauthorizedNames) {
          expect(
            PlayGamesService.isQaTester(playerName: name),
            isFalse,
            reason: 'Failed to reject unauthorized playerName: "$name"',
          );
        }

        final unauthorizedIds = [
          '',
          '   ',
          'fake_a_2116013489197419559',
          'a_2116013489197419559_extra',
          '2116013489197419559',
          'g018042648065406156680',
          '1804264806540615668',
          '01804264806540615668',
          'player_987654321',
          'GPG-PLAYER',
        ];
        for (final id in unauthorizedIds) {
          expect(
            PlayGamesService.isQaTester(playerId: id),
            isFalse,
            reason: 'Failed to reject unauthorized playerId: "$id"',
          );
        }

        expect(PlayGamesService.isQaTester(), isFalse);
        expect(PlayGamesService.isQaTester(playerId: null, playerName: null), isFalse);
      },
    );

    test(
      'Normal signed-in player never receives QA bonus on sign-in, resume, or checkAndGrantQaBonusIfEligible',
      () async {
        SharedPreferences.setMockInitialValues({'musicEnabled': false});
        final storage = StorageService();
        await storage.init();
        await storage.setFireOrbs(25);

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'RandomPlayer123',
          mockPlayerId: 'player_random_555',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await playGames.initialize();
        expect(controller.fireOrbs, 25);
        expect(storage.fireOrbs, 25);
        expect(storage.hasClaimedQaBonus, isFalse);
        expect(controller.pendingQaBonusSnackBar, isNull);

        final granted = await playGames.checkAndGrantQaBonusIfEligible();
        expect(granted, isFalse);
        expect(controller.fireOrbs, 25);
        expect(storage.hasClaimedQaBonus, isFalse);
        expect(controller.pendingQaBonusSnackBar, isNull);

        await playGames.handleAppResumed();
        expect(controller.fireOrbs, 25);
        expect(storage.hasClaimedQaBonus, isFalse);
        expect(controller.pendingQaBonusSnackBar, isNull);
      },
    );

    test(
      'Offline / Guest player cannot receive QA bonus under any condition',
      () async {
        SharedPreferences.setMockInitialValues({'musicEnabled': false});
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: false,
          mockPlayerName: null,
          mockPlayerId: null,
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await playGames.initialize();
        expect(playGames.isSignedIn, isFalse);
        expect(controller.totalOrbs, 0);

        final granted = await playGames.checkAndGrantQaBonusIfEligible();
        expect(granted, isFalse);
        expect(controller.totalOrbs, 0);
        expect(storage.hasClaimedQaBonus, isFalse);
        expect(controller.pendingQaBonusSnackBar, isNull);
      },
    );

    test(
      'Normal player resetting all progress in SettingsDialog wipes to 0 orbs without receiving QA bonus',
      () async {
        SharedPreferences.setMockInitialValues({'musicEnabled': false});
        final storage = StorageService();
        await storage.init();
        await storage.setFireOrbs(120);

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'HonestGamer',
          mockPlayerId: 'player_honest_777',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await playGames.initialize();
        expect(controller.fireOrbs, 120);

        await controller.resetAllProgress();
        expect(controller.totalOrbs, 0);
        expect(storage.totalOrbs, 0);
        expect(storage.hasClaimedQaBonus, isFalse);
        expect(controller.pendingQaBonusSnackBar, isNull);

        final cloudSave = CloudSaveData.tryParse(fakeClient.cloudPayload)!;
        expect(cloudSave.totalOrbs, 0);
        expect(cloudSave.hasClaimedQaBonus, isFalse);
      },
    );

    test(
      'Local storage tampering with hasClaimedQaBonus=false cannot bypass tester check for normal players',
      () async {
        SharedPreferences.setMockInitialValues({
          'musicEnabled': false,
          'orbs_fire': 50,
          'hasClaimedQaBonus': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'CraftyPlayer',
          mockPlayerId: 'player_crafty_999',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await playGames.initialize();

        for (var i = 0; i < 5; i++) {
          await storage.setHasClaimedQaBonus(false);
          final res = await playGames.checkAndGrantQaBonusIfEligible();
          expect(res, isFalse);
          expect(controller.fireOrbs, 50);
          expect(controller.pendingQaBonusSnackBar, isNull);
        }
      },
    );

    test(
      'Loading forged cloud save payload cannot grant QA bonus to normal player',
      () async {
        final forgedPayload = const CloudSaveData(
          fireOrbs: 50,
          hasClaimedQaBonus: false,
          userScore: 10,
          pcScore: 10,
          total: 20,
          userHp: 100,
          pcHp: 100,
        ).toJsonString();

        SharedPreferences.setMockInitialValues({'musicEnabled': false});
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'VictimOrAttacker',
          mockPlayerId: 'player_non_qa_111',
          cloudPayload: forgedPayload,
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await playGames.initialize();
        expect(controller.fireOrbs, 50);
        expect(storage.hasClaimedQaBonus, isFalse);
        expect(controller.pendingQaBonusSnackBar, isNull);
      },
    );

    testWidgets(
      'Normal user clicking TRY AGAIN after 100 rounds retains orbs and never receives bonus',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'musicEnabled': false,
          'animationsEnabled': false,
          'userScore': 50,
          'pcScore': 50,
          'total': 100,
          'orbs_fire': 35,
          'hasClaimedQaBonus': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'NormalPlayer100Rounds',
          mockPlayerId: 'player_normal_100_rounds',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await playGames.initialize();

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('TRY AGAIN'), findsOneWidget);
        expect(controller.fireOrbs, 35);

        await tester.tap(find.text('TRY AGAIN'));
        await tester.pumpAndSettle();

        expect(controller.totalRounds, 0);
        expect(controller.userScore, 0);
        expect(controller.pcScore, 0);
        expect(controller.fireOrbs, 35);
        expect(
          find.text(PlayGamesService.qaBonusSnackBarMessage),
          findsNothing,
        );
      },
    );

    test(
      'QA tester repeating 100-round match resets and in-game resets never gains duplicate orbs',
      () async {
        SharedPreferences.setMockInitialValues({'musicEnabled': false});
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'gustlarsentester',
          mockPlayerId: 'a_2116013489197419559',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );

        await playGames.initialize();
        expect(controller.fireOrbs, 100000);
        controller.consumePendingQaBonusSnackBar();

        for (var match = 1; match <= 5; match++) {
          controller.totalRounds = 100;
          controller.userScore = 50;
          controller.pcScore = 50;

          controller.resetGame();
          await Future<void>.delayed(Duration.zero);

          expect(controller.totalRounds, 0);
          expect(controller.userScore, 0);
          expect(controller.fireOrbs, 100000);
          expect(storage.fireOrbs, 100000);
          expect(storage.hasClaimedQaBonus, isTrue);
          expect(controller.pendingQaBonusSnackBar, isNull);
        }
      },
    );
  });

  group('Slow / Failed Play Games Startup & Placeholder ID Guard Tests', () {
    test(
      'Rejects placeholder GPG-PLAYER and null/empty playerIDs without wiping local settings or triggering false account switch',
      () async {
        for (final invalidId in [null, '', '   ', 'GPG-PLAYER', 'gpg-player']) {
          SharedPreferences.setMockInitialValues({
            'has_seen_story_intro': true,
            'language': 'pt',
            'darkMode': false,
            'soundEnabled': false,
            'musicEnabled': false,
            'orbs_fire': 450,
            'unlockedReset': true,
            'last_player_id': 'g01804264806540615668',
          });
          final storage = StorageService();
          await storage.init();

          final localization = LocalizationService();
          localization.setLanguage(storage.language);

          final fakeClient = FakePlayGamesClient(
            shouldSucceedSignIn: true,
            mockPlayerName: 'gustlarsen',
            mockPlayerId: invalidId,
          );
          final playGames = PlayGamesService(
            storage: storage,
            client: fakeClient,
            maxAutoRetries: 0,
          );
          addTearDown(playGames.dispose);

          final controller = GameController(
            storage: storage,
            localization: localization,
            audio: AudioService(),
            playGames: playGames,
          );
          addTearDown(controller.dispose);

          final signedIn = await playGames.initialize();

          expect(signedIn, isFalse, reason: 'Should reject id="$invalidId"');
          expect(playGames.isSignedIn, isFalse);
          expect(playGames.playerID, isNull);
          expect(playGames.playerName, isNull);
          expect(playGames.syncStatus, CloudSyncStatus.offline);
          expect(storage.lastPlayerId, 'g01804264806540615668');
          expect(storage.language, 'pt');
          expect(localization.currentLanguage, 'pt');
          expect(controller.darkMode, isFalse);
          expect(controller.soundEnabled, isFalse);
          expect(controller.fireOrbs, 450);
          expect(controller.unlockedReset, isTrue);
          expect(controller.pendingQaBonusSnackBar, isNull);
        }
      },
    );

    test(
      'Ignores legacy GPG-PLAYER persisted in SharedPreferences so real sign-in does not trigger false account reset',
      () async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'language': 'de',
          'orbs_fire': 320,
          'unlockedReset': true,
          'musicEnabled': false,
          'last_player_id': 'GPG-PLAYER',
        });
        final storage = StorageService();
        await storage.init();

        expect(storage.lastPlayerId, isNull);
        await storage.setLastPlayerId('GPG-PLAYER');
        expect(storage.lastPlayerId, isNull);

        final localization = LocalizationService();
        localization.setLanguage(storage.language);

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'RealPlayer',
          mockPlayerId: 'player_real_777',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );
        addTearDown(playGames.dispose);

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
          playGames: playGames,
        );
        addTearDown(controller.dispose);

        final signedIn = await playGames.initialize();

        expect(signedIn, isTrue);
        expect(playGames.isSignedIn, isTrue);
        expect(playGames.playerID, 'player_real_777');
        expect(storage.lastPlayerId, 'player_real_777');
        expect(playGames.syncStatus, CloudSyncStatus.synced);
        expect(storage.language, 'de');
        expect(localization.currentLanguage, 'de');
        expect(controller.fireOrbs, 320);
        expect(controller.unlockedReset, isTrue);
      },
    );

    test(
      'Slow startup sign-in timeout falls back to Offline without overwriting settings and retries gracefully when network recovers',
      () async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'language': 'es',
          'orbs_fire': 180,
          'musicEnabled': false,
          'last_player_id': 'player_slow_net',
        });
        final storage = StorageService();
        await storage.init();

        final localization = LocalizationService();
        localization.setLanguage(storage.language);

        final slowClient = _SlowPlayGamesClient(
          delayFirstAttempt: const Duration(milliseconds: 120),
          mockPlayerName: 'RecoveredUser',
          mockPlayerId: 'player_slow_net',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: slowClient,
          silentAuthTimeout: const Duration(milliseconds: 30),
          retryBaseDelay: const Duration(milliseconds: 40),
          maxAutoRetries: 2,
        );
        addTearDown(playGames.dispose);

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
          playGames: playGames,
        );
        addTearDown(controller.dispose);

        final firstResult = await playGames.initialize();

        expect(firstResult, isFalse);
        expect(playGames.isSignedIn, isFalse);
        expect(playGames.playerID, isNull);
        expect(playGames.syncStatus, CloudSyncStatus.offline);
        expect(playGames.isRetryScheduled, isTrue);
        expect(storage.language, 'es');
        expect(localization.currentLanguage, 'es');
        expect(controller.fireOrbs, 180);

        // Wait for the scheduled graceful retry to run and succeed
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(playGames.isSignedIn, isTrue);
        expect(playGames.playerName, 'RecoveredUser');
        expect(playGames.playerID, 'player_slow_net');
        expect(playGames.syncStatus, CloudSyncStatus.synced);
        expect(storage.language, 'es');
        expect(localization.currentLanguage, 'es');
        expect(controller.fireOrbs, 180);
      },
    );

    testWidgets(
      'SettingsDialog shows Connecting... while startup auth is slow, then Offline (never GPG-PLAYER or Synced), preserving language',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'language': 'pt',
          'orbs_fire': 250,
          'musicEnabled': false,
          'animationsEnabled': false,
          'last_player_id': 'player_existing_pt',
        });
        final storage = StorageService();
        await storage.init();

        final localization = LocalizationService();
        await localization.load();
        localization.setLanguage(storage.language);

        final gate = Completer<String?>();
        final slowClient = _CompleterPlayGamesClient(
          signInGate: gate,
          mockPlayerName: 'gustlarsen',
          mockPlayerId: 'GPG-PLAYER',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: slowClient,
          retryBaseDelay: const Duration(seconds: 30),
          profileRetryDelay: Duration.zero,
          maxAutoRetries: 1,
        );
        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
          playGames: playGames,
        );
        addTearDown(() {
          controller.dispose();
          playGames.dispose();
        });

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pump();

        // Start silent initialization while network is still pending
        final initFuture = playGames.initialize();
        await tester.pump();

        // Open SettingsDialog while authentication is in progress
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pump();
        await tester.pump();

        // Should show Connecting... (both badge and disabled button), never Synced or GPG-PLAYER
        expect(find.text('Connecting...'), findsNWidgets(2));
        expect(find.text('Synced'), findsNothing);
        expect(find.textContaining('GPG-PLAYER'), findsNothing);
        expect(find.text('Português 🇧🇷'), findsOneWidget);

        // Complete sign-in where getPlayerID returns placeholder 'GPG-PLAYER'
        gate.complete('success');
        final ok = await initFuture;
        expect(ok, isFalse);
        await tester.pump();
        await tester.pump();

        // Should show Offline & Sign in button, preserve Portuguese, and never show GPG-PLAYER or Synced
        expect(find.text('Offline'), findsOneWidget);
        expect(find.text('Sign in with Google Play'), findsOneWidget);
        expect(find.text('Synced'), findsNothing);
        expect(find.textContaining('GPG-PLAYER'), findsNothing);
        expect(find.text('Português 🇧🇷'), findsOneWidget);
        expect(storage.language, 'pt');
        expect(controller.fireOrbs, 250);
      },
    );

    test(
      'PlayGamesService.signIn retries profile fetch when Play Games SDK is still initializing on the first getPlayerID attempt',
      () async {
        SharedPreferences.setMockInitialValues({
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final retryClient = _DelayedProfilePlayGamesClient(
          nullIdAttemptsBeforeReady: 2,
          mockPlayerName: 'DelayedProfilePlayer',
          mockPlayerId: 'player_ready_after_retry',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: retryClient,
          profileRetryDelay: const Duration(milliseconds: 10),
          maxProfileFetchAttempts: 3,
        );
        addTearDown(playGames.dispose);

        final ok = await playGames.signIn(silent: true);

        expect(ok, isTrue);
        // 2 failed attempts + 1 successful attempt in signIn + 1 verification in loadAndResolveCloudSave
        expect(retryClient.getPlayerIdCalls, 4);
        expect(playGames.isSignedIn, isTrue);
        expect(playGames.playerID, 'player_ready_after_retry');
        expect(playGames.playerName, 'DelayedProfilePlayer');
        expect(playGames.syncStatus, CloudSyncStatus.synced);
        expect(playGames.lastErrorCode, isNull);
      },
    );

    test(
      'PlayGamesService distinguishes SDK PlatformException errors from network/offline errors in signInDiagnosticMessage',
      () async {
        SharedPreferences.setMockInitialValues({
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final errorClient = _ThrowingPlayGamesClient(
          errorToThrow: PlatformException(
            code: 'failed_to_authenticate',
            message: '10: DEVELOPER_ERROR',
          ),
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: errorClient,
          maxAutoRetries: 0,
        );
        addTearDown(playGames.dispose);

        final ok = await playGames.signIn(silent: false);

        expect(ok, isFalse);
        expect(playGames.isSignedIn, isFalse);
        expect(playGames.lastErrorCode, 'failed_to_authenticate');
        expect(playGames.lastErrorMessage, '10: DEVELOPER_ERROR');
        expect(
          playGames.signInDiagnosticMessage,
          'Google Play Games sign-in failed [failed_to_authenticate]: 10: DEVELOPER_ERROR',
        );
        expect(
          playGames.signInDiagnosticMessage.contains('Offline mode'),
          isFalse,
        );

        // Now verify a genuine network error formats with an offline/network diagnostic
        errorClient.errorToThrow = PlatformException(
          code: 'network_error',
          message: '7: NETWORK_ERROR',
        );
        final okNet = await playGames.signIn(silent: false);
        expect(okNet, isFalse);
        expect(playGames.lastErrorCode, 'network_error');
        expect(
          playGames.signInDiagnosticMessage,
          'Could not connect to Google Play Games (Offline: 7: NETWORK_ERROR)',
        );
      },
    );

    test(
      'Manual signIn(silent: false) queued while silent startup signIn is in flight triggers a fresh sign-in attempt if silent fails',
      () async {
        SharedPreferences.setMockInitialValues({
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final firstGate = Completer<String?>();
        final queuedClient = _QueuedSignInPlayGamesClient(
          firstAttemptGate: firstGate,
          secondAttemptPlayerName: 'ManualRetryHero',
          secondAttemptPlayerId: 'player_manual_retry_42',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: queuedClient,
          profileRetryDelay: Duration.zero,
          maxAutoRetries: 0,
        );
        addTearDown(playGames.dispose);

        // Start silent sign-in on startup (in flight)
        final silentFuture = playGames.initialize();
        expect(playGames.isAuthenticating, isTrue);

        // User taps manual sign-in while silent sign-in is still in flight
        final manualFuture = playGames.signIn(silent: false);

        // Complete the first (silent) attempt as failed (null)
        firstGate.complete(null);

        final manualResult = await manualFuture;
        await silentFuture;

        expect(manualResult, isTrue);
        expect(queuedClient.signInCalls, 2);
        expect(playGames.isSignedIn, isTrue);
        expect(playGames.playerID, 'player_manual_retry_42');
        expect(playGames.playerName, 'ManualRetryHero');
      },
    );

    testWidgets(
      'SettingsDialog shows exact PlatformException diagnostic in SnackBar and allows tapping Offline badge or Sign in button to retry',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'musicEnabled': false,
          'animationsEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final localization = LocalizationService();
        await localization.load();

        final client = _ThrowingPlayGamesClient(
          errorToThrow: PlatformException(
            code: 'failed_to_authenticate',
            message: 'SIGN_IN_REQUIRED',
          ),
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: client,
          profileRetryDelay: Duration.zero,
          maxAutoRetries: 0,
        );
        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
          playGames: playGames,
        );
        addTearDown(() {
          controller.dispose();
          playGames.dispose();
        });

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pump();

        // Open SettingsDialog
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();

        expect(find.text('Offline'), findsOneWidget);
        final signInButtonFinder = find.byKey(
          const ValueKey('play_games_sign_in_button'),
        );
        expect(signInButtonFinder, findsOneWidget);

        // Tap "Sign in with Google Play" button -> fails with PlatformException
        await tester.tap(signInButtonFinder);
        await tester.pump();
        await tester.pump();

        // Diagnostic message must show the exact PlatformException code & message, NOT "Offline mode"
        expect(
          find.text(
            'Google Play Games sign-in failed [failed_to_authenticate]: SIGN_IN_REQUIRED',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Could not connect to Google Play Games (Offline mode)'),
          findsNothing,
        );

        // Now allow the next sign-in attempt to succeed when tapping the "Offline" status badge
        client.errorToThrow = null;
        client.mockPlayerName = 'BadgeTapPlayer';
        client.mockPlayerId = 'player_badge_tap_888';

        final syncBadgeFinder = find.byKey(
          const ValueKey('play_games_sync_status'),
        );
        await tester.tap(syncBadgeFinder);
        await tester.pumpAndSettle();

        expect(playGames.isSignedIn, isTrue);
        expect(find.text('Synced'), findsOneWidget);
        expect(find.text('BadgeTapPlayer'), findsOneWidget);
        expect(find.text('ID: player_badge_tap_888'), findsOneWidget);
      },
    );
  });
}

class _SlowPlayGamesClient implements PlayGamesClient {
  final Duration delayFirstAttempt;
  final String mockPlayerName;
  final String mockPlayerId;
  int _attempt = 0;

  _SlowPlayGamesClient({
    required this.delayFirstAttempt,
    required this.mockPlayerName,
    required this.mockPlayerId,
  });

  @override
  Future<String?> signIn() async {
    _attempt++;
    if (_attempt == 1) {
      await Future<void>.delayed(delayFirstAttempt);
    }
    return 'success';
  }

  @override
  Future<String?> getPlayerName() async => mockPlayerName;

  @override
  Future<String?> getPlayerID() async => mockPlayerId;

  @override
  Future<String?> saveGame({required String data, required String name}) async =>
      'success';

  @override
  Future<String?> loadGame({required String name}) async => null;
}

class _CompleterPlayGamesClient implements PlayGamesClient {
  final Completer<String?> signInGate;
  final String? mockPlayerName;
  final String? mockPlayerId;

  _CompleterPlayGamesClient({
    required this.signInGate,
    required this.mockPlayerName,
    required this.mockPlayerId,
  });

  @override
  Future<String?> signIn() => signInGate.future;

  @override
  Future<String?> getPlayerName() async => mockPlayerName;

  @override
  Future<String?> getPlayerID() async => mockPlayerId;

  @override
  Future<String?> saveGame({required String data, required String name}) async =>
      'success';

  @override
  Future<String?> loadGame({required String name}) async => null;
}

class _DelayedProfilePlayGamesClient implements PlayGamesClient {
  final int nullIdAttemptsBeforeReady;
  final String mockPlayerName;
  final String mockPlayerId;
  int getPlayerIdCalls = 0;

  _DelayedProfilePlayGamesClient({
    required this.nullIdAttemptsBeforeReady,
    required this.mockPlayerName,
    required this.mockPlayerId,
  });

  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => mockPlayerName;

  @override
  Future<String?> getPlayerID() async {
    getPlayerIdCalls++;
    if (getPlayerIdCalls <= nullIdAttemptsBeforeReady) {
      return null;
    }
    return mockPlayerId;
  }

  @override
  Future<String?> saveGame({required String data, required String name}) async =>
      'success';

  @override
  Future<String?> loadGame({required String name}) async => null;
}

class _ThrowingPlayGamesClient implements PlayGamesClient {
  Object? errorToThrow;
  String mockPlayerName = 'RecoveredPlayer';
  String mockPlayerId = 'player_recovered_1';

  _ThrowingPlayGamesClient({this.errorToThrow});

  @override
  Future<String?> signIn() async {
    final err = errorToThrow;
    if (err != null) {
      throw err;
    }
    return 'success';
  }

  @override
  Future<String?> getPlayerName() async => mockPlayerName;

  @override
  Future<String?> getPlayerID() async => mockPlayerId;

  @override
  Future<String?> saveGame({required String data, required String name}) async =>
      'success';

  @override
  Future<String?> loadGame({required String name}) async => null;
}

class _QueuedSignInPlayGamesClient implements PlayGamesClient {
  final Completer<String?> firstAttemptGate;
  final String secondAttemptPlayerName;
  final String secondAttemptPlayerId;
  int signInCalls = 0;

  _QueuedSignInPlayGamesClient({
    required this.firstAttemptGate,
    required this.secondAttemptPlayerName,
    required this.secondAttemptPlayerId,
  });

  @override
  Future<String?> signIn() {
    signInCalls++;
    if (signInCalls == 1) {
      return firstAttemptGate.future;
    }
    return Future<String?>.value('success');
  }

  @override
  Future<String?> getPlayerName() async => secondAttemptPlayerName;

  @override
  Future<String?> getPlayerID() async => secondAttemptPlayerId;

  @override
  Future<String?> saveGame({required String data, required String name}) async =>
      'success';

  @override
  Future<String?> loadGame({required String name}) async => null;
}

