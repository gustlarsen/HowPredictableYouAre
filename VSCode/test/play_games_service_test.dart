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
          'diamonds': 120,
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
        expect(storage.diamonds, 120);
        expect(storage.unlockedReset, isTrue);
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
          diamonds: 650,
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
        expect(controller.diamonds, 650);
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
        expect(controller.diamonds, 0);
        expect(storage.diamonds, 0);
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
        // which has its own cloud save with 220 diamonds, unlockedRandom, and 'es' settings
        final account3Save = CloudSaveData(
          diamonds: 220,
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
        expect(controller.diamonds, 220);
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

        // 4. Switch back to Account 1 ('player_001') -> restores Account 1's 650 diamonds, unlocks, & 'pt' settings
        fakeClient.mockPlayerName = 'PlayerOne';
        fakeClient.mockPlayerId = 'player_001';

        controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(playGames.playerName, 'PlayerOne');
        expect(playGames.playerID, 'player_001');
        expect(controller.diamonds, 650);
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
      'Conflict resolution restores cloud save over local data when cloud holds higher diamond count or progression',
      () async {
        // Local has 50 diamonds and 0 unlocks
        SharedPreferences.setMockInitialValues({
          'diamonds': 50,
          'userScore': 2,
          'pcScore': 3,
          'total': 5,
          'unlockedReset': false,
          'unlockedAlgorithm': false,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        // Cloud has 750 diamonds, 2 unlocks, higher scores, and a populated Markov matrix
        final cloudSnapshot = CloudSaveData(
          diamonds: 750,
          userScore: 25,
          pcScore: 15,
          total: 40,
          unlockedReset: true,
          unlockedAlgorithm: true,
          showReset: true,
          showAlgorithm: true,
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

        expect(controller.diamonds, 750);
        expect(controller.userScore, 25);
        expect(controller.pcScore, 15);
        expect(controller.totalRounds, 40);
        expect(controller.unlockedReset, isTrue);
        expect(controller.unlockedAlgorithm, isTrue);
        expect(controller.showReset, isTrue);
        expect(controller.showAlgorithm, isTrue);
        expect(controller.currentUserMove, HandMove.paper);
        expect(controller.currentComputerMove, HandMove.rock);
        expect(controller.engine.matrix[0], [2, 5, 1]);
      },
    );

    test(
      'Conflict resolution keeps local data and backs up to cloud when local holds higher progression or diamond count',
      () async {
        // Local has 2000 diamonds and 3 unlocks
        SharedPreferences.setMockInitialValues({
          'diamonds': 2000,
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

        // Cloud has only 100 diamonds and 0 unlocks
        final staleCloudSnapshot = const CloudSaveData(
          diamonds: 100,
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
        expect(controller.diamonds, 2000);
        expect(controller.userScore, 30);
        expect(controller.unlockedReset, isTrue);
        expect(controller.unlockedPredictability, isTrue);
        expect(controller.unlockedRandom, isTrue);

        // Local progression was backed up to cloud
        expect(fakeClient.saveCallCount, greaterThanOrEqualTo(1));
        final savedToCloud = CloudSaveData.tryParse(fakeClient.cloudPayload)!;
        expect(savedToCloud.diamonds, 2000);
        expect(savedToCloud.unlockedCount, 3);
      },
    );

    test(
      'Triggers cloud save automatically whenever diamonds or purchases change',
      () async {
        SharedPreferences.setMockInitialValues({
          'diamonds': 500,
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

        // 1. Purchasing an item triggers a cloud save
        expect(controller.unlockReset(), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(fakeClient.saveCallCount, equals(initialSaves + 1));
        var syncedData = CloudSaveData.tryParse(fakeClient.cloudPayload)!;
        expect(syncedData.diamonds, 400);
        expect(syncedData.unlockedReset, isTrue);

        // 2. Claiming periodic gift (+5 diamonds) triggers a cloud save
        controller.claimGift();
        await Future<void>.delayed(Duration.zero);
        expect(fakeClient.saveCallCount, equals(initialSaves + 2));
        syncedData = CloudSaveData.tryParse(fakeClient.cloudPayload)!;
        expect(syncedData.diamonds, 405);

        // 3. Adding free diamonds triggers a cloud save
        controller.addFreeDiamonds(50);
        await Future<void>.delayed(Duration.zero);
        expect(fakeClient.saveCallCount, equals(initialSaves + 3));
        syncedData = CloudSaveData.tryParse(fakeClient.cloudPayload)!;
        expect(syncedData.diamonds, 455);

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
  });

  group('SettingsDialog Player Profile & Reset All Progress UI Tests', () {
    testWidgets(
      'Displays single Sign in with Google Play button when disconnected, and shows connected profile card with Player ID and NO copy button, Switch Account, or Sign Out buttons',
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

        // Connected state: shows playerName, playerID, Synced status,
        // and NO copy button, Switch Account button, or Sign Out button
        expect(
          find.byKey(const ValueKey('play_games_profile_card')),
          findsOneWidget,
        );
        expect(find.text('OracleSlayer'), findsOneWidget);
        expect(find.text('ID: player_4242'), findsOneWidget);
        expect(find.text('Synced'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('play_games_copy_id_button')),
          findsNothing,
        );
        expect(find.byIcon(Icons.copy_rounded), findsNothing);
        expect(
          find.byKey(const ValueKey('play_games_switch_account_button')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('play_games_sign_out_button')),
          findsNothing,
        );
        expect(find.text('Switch Account'), findsNothing);
        expect(find.text('Sign Out'), findsNothing);
      },
    );

    testWidgets(
      'Reset All Progress button in SettingsDialog asks for confirmation and resets all local and cloud progress so the user can restart fresh',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'diamonds': 800,
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

        expect(controller.diamonds, 800);
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
        expect(controller.diamonds, 800);
        expect(controller.unlockedReset, isTrue);

        // Tap Reset All Progress again and confirm
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('confirm_reset_progress_button')),
        );
        await tester.pumpAndSettle();

        // All progress is wiped locally and synced to cloud, while UI settings stay intact
        expect(controller.diamonds, 0);
        expect(storage.diamonds, 0);
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
        expect(cloudAfterReset.diamonds, 0);
        expect(cloudAfterReset.unlockedCount, 0);
        expect(cloudAfterReset.total, 0);
        expect(cloudAfterReset.darkMode, isFalse);
      },
    );

    testWidgets(
      'AppLifecycleState.resumed immediately detects OS-level account switch in Google Play Games app and updates UI diamonds, progress, and profile card',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'musicEnabled': false,
          'animationsEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final accountASave = const CloudSaveData(
          diamonds: 420,
          userScore: 10,
          pcScore: 5,
          total: 15,
          unlockedReset: true,
          showReset: true,
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
        await tester.pumpAndSettle();

        // AccountAlpha's 420 diamonds and Reset button are shown in the AppBar
        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text('420')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.restart_alt), findsOneWidget);

        // Simulate user switching to AccountBeta (no cloud save) in Google Play Games app while game is in background
        fakeClient.mockPlayerName = 'AccountBeta';
        fakeClient.mockPlayerId = 'player_beta';
        fakeClient.setCloudSaveForPlayer('player_beta', null);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        // UI immediately updates: diamonds reset to 0, Reset button disappears
        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text('0')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.restart_alt), findsNothing);
        expect(controller.diamonds, 0);
        expect(controller.unlockedReset, isFalse);

        // Open SettingsDialog -> shows AccountBeta's profile
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        expect(find.text('AccountBeta'), findsOneWidget);
        expect(find.text('ID: player_beta'), findsOneWidget);
      },
    );
  });
}

