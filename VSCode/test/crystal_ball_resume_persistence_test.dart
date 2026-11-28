import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';

class _FakePlayGamesClient implements PlayGamesClient {
  String? mockPlayerName = 'TestHero';
  String? mockPlayerId = 'player_crystal_ball_test';
  final Map<String, String?> _cloudSavesByPlayer = {};
  int loadCallCount = 0;

  String? get cloudPayload => _cloudSavesByPlayer[mockPlayerId ?? ''];
  set cloudPayload(String? value) {
    _cloudSavesByPlayer[mockPlayerId ?? ''] = value;
  }

  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => mockPlayerName;

  @override
  Future<String?> getPlayerID() async => mockPlayerId;

  @override
  Future<String?> saveGame({required String data, required String name}) async {
    _cloudSavesByPlayer[mockPlayerId ?? ''] = data;
    return 'success';
  }

  @override
  Future<String?> loadGame({required String name}) async {
    loadCallCount++;
    return _cloudSavesByPlayer[mockPlayerId ?? ''];
  }
}

Future<({
  GameController controller,
  StorageService storage,
  LocalizationService localization,
  _FakePlayGamesClient client,
  PlayGamesService playGames,
})> _createSetup({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'musicEnabled': false,
    'soundEnabled': false,
    'vibrationEnabled': false,
    'animationsEnabled': false,
    'has_seen_story_intro': true,
    'unlockedCrystalBall': true,
    'showCrystalBall': true,
    'unlockedCrystalBallPlus': true,
    'showCrystalBallPlus': true,
    'unlockedNewHands': true,
    'showNewHands': true,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();
  final localization = LocalizationService();
  await localization.load();
  final client = _FakePlayGamesClient();
  final playGames = PlayGamesService(storage: storage, client: client);
  final controller = GameController(
    storage: storage,
    localization: localization,
    audio: AudioService(),
    playGames: playGames,
  );
  return (
    controller: controller,
    storage: storage,
    localization: localization,
    client: client,
    playGames: playGames,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Crystal Ball & Turn 0 prediction stability across resume and reload', () {
    test(
      'Guardian Robot Turn 0 crystalBallMove and crystalBallPlusMoves stay locked across repeated AppLifecycleState.resumed cloud syncs',
      () async {
        final env = await _createSetup(
          prefs: {
            'enemy_stage': 1,
            'total': 0,
            'userScore': 0,
            'pcScore': 0,
          },
        );
        addTearDown(env.controller.dispose);

        // Seed an equal cloud save snapshot (same state as local Turn 0)
        env.client.cloudPayload = CloudSaveData.fromStorage(
          env.storage,
        ).toJsonString();
        await env.playGames.initialize();

        final initialMove = env.controller.crystalBallMove;
        final initialPlusMoves = List<HandMove>.from(
          env.controller.crystalBallPlusMoves,
        );
        expect(initialMove, isNotNull);
        expect(initialPlusMoves, isNotEmpty);
        expect(env.storage.pendingCrystalBallMove, initialMove);

        // Simulate 20 consecutive screenshot / resume cycles that trigger
        // PlayGamesService.handleAppResumed() -> loadAndResolveCloudSave() -> onCloudDataRestored.
        final loadsBefore = env.client.loadCallCount;
        for (int i = 0; i < 20; i++) {
          env.controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
          env.controller.didChangeAppLifecycleState(AppLifecycleState.paused);
          env.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
          // Flush async silent sign-in & cloud save resolution
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          expect(
            env.controller.crystalBallMove,
            initialMove,
            reason: 'Turn 0 enemy move re-rolled on resume cycle $i',
          );
          expect(
            env.controller.crystalBallPlusMoves,
            initialPlusMoves,
            reason: 'Crystal Ball+ hint changed on resume cycle $i',
          );
        }
        expect(env.client.loadCallCount, greaterThan(loadsBefore));

        // Verify Guardian Robot actually executes the locked Turn 0 move on Turn 1
        final chosenCounter = initialPlusMoves.first;
        env.controller.playTurn(chosenCounter);
        expect(env.controller.currentComputerMove, initialMove);
        expect(env.controller.lastWinner, RoundWinner.user);
        expect(
          env.storage.pendingCrystalBallMove,
          env.controller.crystalBallMove,
        );
      },
    );

    test(
      'Persists Turn 0 crystalBallMove across cold controller restarts',
      () async {
        final env = await _createSetup(
          prefs: {
            'enemy_stage': 1,
            'total': 0,
          },
        );
        final lockedMove = env.controller.crystalBallMove;
        final lockedPlus = List<HandMove>.from(
          env.controller.crystalBallPlusMoves,
        );
        expect(lockedMove, isNotNull);
        expect(env.storage.pendingCrystalBallMove, lockedMove);
        env.controller.dispose();

        // Recreate GameController multiple times from the same StorageService
        for (int i = 0; i < 15; i++) {
          final reloaded = GameController(
            storage: env.storage,
            localization: env.localization,
            audio: AudioService(),
          );
          expect(
            reloaded.crystalBallMove,
            lockedMove,
            reason: 'Cold restart $i changed pending Turn 0 move',
          );
          expect(reloaded.crystalBallPlusMoves, lockedPlus);
          reloaded.dispose();
        }
      },
    );

    test(
      'Temple High Master (Stage 5 pure random) stays locked across AppLifecycleState.resumed',
      () async {
        final env = await _createSetup(
          prefs: {
            'enemy_stage': 5,
            'enemy_max_hp': 350,
            'pcHp': 350,
            'total': 0,
          },
        );
        addTearDown(env.controller.dispose);

        env.client.cloudPayload = CloudSaveData.fromStorage(
          env.storage,
        ).toJsonString();
        await env.playGames.initialize();

        final lockedMove = env.controller.crystalBallMove;
        expect(lockedMove, isNotNull);

        for (int i = 0; i < 20; i++) {
          env.controller.didChangeAppLifecycleState(AppLifecycleState.paused);
          env.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          expect(env.controller.crystalBallMove, lockedMove);
        }
      },
    );

    test(
      'Toggling Markov Recalibrator or New Skin at Turn 0 does not re-roll crystalBallMove',
      () async {
        final env = await _createSetup(
          prefs: {
            'enemy_stage': 2,
            'enemy_max_hp': 200,
            'pcHp': 200,
            'current_week': 10,
            'unlockedMarkovRecalibrator': true,
            'showMarkovRecalibrator': false,
            'unlockedNewSkin': true,
            'showNewSkin': false,
          },
        );
        addTearDown(env.controller.dispose);

        final lockedMove = env.controller.crystalBallMove;
        expect(lockedMove, isNotNull);

        for (int i = 0; i < 10; i++) {
          env.controller.toggleMarkovRecalibrator(i.isEven);
          expect(env.controller.crystalBallMove, lockedMove);
        }

        for (int i = 0; i < 10; i++) {
          env.controller.toggleShowNewSkin(i.isEven);
          expect(env.controller.crystalBallMove, lockedMove);
        }
      },
    );

    test(
      'Cloud restore with a different battle state recomputes a valid crystalBallMove for the restored battle',
      () async {
        final env = await _createSetup(
          prefs: {
            'enemy_stage': 1,
            'total': 0,
            'userScore': 0,
            'pcScore': 0,
          },
        );
        addTearDown(env.controller.dispose);

        // Force local pending move to Fire at Turn 0
        await env.storage.setPendingCrystalBallMove(HandMove.fire);
        env.controller.crystalBallMove = HandMove.fire;

        // Cloud save from another device has higher progression mid-battle:
        // Stage 1 Guardian Robot, lastUserMove = Fire, matrix predicts Fire -> Fire,
        // so Guardian Robot MUST counter Fire with Water (not stale Fire!).
        final remoteCloud = CloudSaveData.fromStorage(env.storage);
        final upgradedCloud = CloudSaveData(
          updatedAtMillis: DateTime.now().millisecondsSinceEpoch + 60000,
          fireOrbs: remoteCloud.fireOrbs + 500,
          waterOrbs: remoteCloud.waterOrbs + 500,
          woodOrbs: remoteCloud.woodOrbs + 500,
          earthOrbs: remoteCloud.earthOrbs + 500,
          metalOrbs: remoteCloud.metalOrbs + 500,
          enemyStage: 1,
          enemyMaxHp: 100,
          userScore: 5,
          pcScore: 0,
          total: 5,
          userHp: 50,
          pcHp: 75,
          lastUserMoveId: HandMove.fire.id,
          lastComputerMoveId: HandMove.wood.id,
          unlockedNewHands: true,
          showNewHands: true,
          unlockedCrystalBall: true,
          showCrystalBall: true,
          unlockedCrystalBallPlus: true,
          showCrystalBallPlus: true,
          markovMatrix5: const [
            [4, 0, 0, 0, 0], // Fire -> Fire (count 4) => counter is Water
            [0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0],
          ],
        );
        env.client.cloudPayload = upgradedCloud.toJsonString();

        await env.playGames.initialize();

        expect(env.controller.totalRounds, 5);
        expect(env.controller.lastUserMove, HandMove.fire);
        expect(env.controller.predictedUserMoves, [HandMove.fire]);
        expect(env.controller.crystalBallMove, HandMove.water);
        expect(env.storage.pendingCrystalBallMove, HandMove.water);
      },
    );
  });
}
