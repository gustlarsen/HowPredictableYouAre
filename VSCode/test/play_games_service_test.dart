import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? cloudPayload;
  int saveCallCount = 0;
  int loadCallCount = 0;
  int signInCallCount = 0;

  FakePlayGamesClient({
    this.shouldSucceedSignIn = true,
    this.mockPlayerName = 'MasterHand99',
    this.mockPlayerId = 'gpg_987654321',
    this.cloudPayload,
  });

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
    cloudPayload = data;
    return 'success';
  }

  @override
  Future<String?> loadGame({required String name}) async {
    loadCallCount++;
    return cloudPayload;
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
      'Sign-in, Switch Account, and Sign-out transition PlayGamesService state accurately',
      () async {
        SharedPreferences.setMockInitialValues({'musicEnabled': false});
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakePlayGamesClient(
          shouldSucceedSignIn: true,
          mockPlayerName: 'CloudHero',
          mockPlayerId: 'player_001',
        );
        final playGames = PlayGamesService(
          storage: storage,
          client: fakeClient,
        );

        expect(playGames.isSignedIn, isFalse);
        expect(playGames.syncStatus, CloudSyncStatus.offline);

        // Sign in
        final signedIn = await playGames.signIn();
        expect(signedIn, isTrue);
        expect(playGames.isSignedIn, isTrue);
        expect(playGames.playerName, 'CloudHero');
        expect(playGames.playerID, 'player_001');
        expect(playGames.syncStatus, CloudSyncStatus.synced);

        // Switch account to a second player profile
        fakeClient.mockPlayerName = 'SecondAccount';
        fakeClient.mockPlayerId = 'player_002';
        final switched = await playGames.switchAccount();
        expect(switched, isTrue);
        expect(playGames.isSignedIn, isTrue);
        expect(playGames.playerName, 'SecondAccount');
        expect(playGames.playerID, 'player_002');
        expect(playGames.syncStatus, CloudSyncStatus.synced);

        // Sign out
        await playGames.signOut();
        expect(playGames.isSignedIn, isFalse);
        expect(playGames.playerName, isNull);
        expect(playGames.playerID, isNull);
        expect(playGames.syncStatus, CloudSyncStatus.offline);
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
      },
    );
  });

  group('SettingsDialog Player Profile UI Tests', () {
    testWidgets(
      'Displays disconnected state, signs in to show connected profile card, copies Player ID, and confirms Switch Account / Sign Out',
      (WidgetTester tester) async {
        String? clipboardContent;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                final args = call.arguments as Map<dynamic, dynamic>;
                clipboardContent = args['text'] as String?;
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
          mockPlayerId: 'gpg_id_4242',
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

        // Disconnected state: shows "Sign in with Google Play" button & "Offline" badge
        expect(
          find.byKey(const ValueKey('play_games_sign_in_button')),
          findsOneWidget,
        );
        expect(find.text('Sign in with Google Play'), findsOneWidget);
        expect(find.text('Offline'), findsOneWidget);

        // Tap "Sign in with Google Play"
        await tester.tap(
          find.byKey(const ValueKey('play_games_sign_in_button')),
        );
        await tester.pumpAndSettle();

        // Connected state: shows playerName, playerID, copy button, Synced status, Switch Account, and Sign Out
        expect(
          find.byKey(const ValueKey('play_games_profile_card')),
          findsOneWidget,
        );
        expect(find.text('OracleSlayer'), findsOneWidget);
        expect(find.text('ID: gpg_id_4242'), findsOneWidget);
        expect(find.text('Synced'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('play_games_switch_account_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('play_games_sign_out_button')),
          findsOneWidget,
        );

        // Tap copy icon next to Player ID -> copies ID to clipboard and shows SnackBar
        await tester.tap(
          find.byKey(const ValueKey('play_games_copy_id_button')),
        );
        await tester.pumpAndSettle();
        expect(clipboardContent, equals('gpg_id_4242'));
        expect(find.text('Player ID copied: gpg_id_4242'), findsOneWidget);

        // Tap "Switch Account" -> shows confirmation dialog warning about offline progression
        fakeClient.mockPlayerName = 'NewChallenger';
        fakeClient.mockPlayerId = 'gpg_id_9999';
        await tester.tap(
          find.byKey(const ValueKey('play_games_switch_account_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Switch Account?'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('confirm_switch_account_button')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('confirm_switch_account_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('NewChallenger'), findsOneWidget);
        expect(find.text('ID: gpg_id_9999'), findsOneWidget);

        // Tap "Sign Out" -> shows confirmation dialog warning about offline progression
        await tester.tap(
          find.byKey(const ValueKey('play_games_sign_out_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sign Out?'), findsOneWidget);
        // Cancel first -> stays connected
        await tester.tap(
          find.byKey(const ValueKey('account_confirm_cancel_button')),
        );
        await tester.pumpAndSettle();
        expect(playGames.isSignedIn, isTrue);

        // Tap "Sign Out" again and confirm -> returns to disconnected state
        await tester.tap(
          find.byKey(const ValueKey('play_games_sign_out_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('confirm_sign_out_button')),
        );
        await tester.pumpAndSettle();

        expect(playGames.isSignedIn, isFalse);
        expect(
          find.byKey(const ValueKey('play_games_sign_in_button')),
          findsOneWidget,
        );
        expect(find.text('Offline'), findsOneWidget);
      },
    );
  });
}

