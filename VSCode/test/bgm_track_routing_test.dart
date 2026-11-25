import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/full_screen_spyglass_view.dart';
import 'package:how_predictable/views/dialogs/observatory_dialog.dart';
import 'package:how_predictable/views/dialogs/royal_castle_dialog.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';
import 'package:how_predictable/views/dialogs/watchtower_spyglass_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/screens/world_map_screen.dart';

class _RecordingBgmPlayer implements AudioPlayerClient {
  PlayerState _state = PlayerState.stopped;
  int playCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;
  int disposeCount = 0;
  ReleaseMode? lastReleaseMode;
  Source? lastSource;
  final List<String> playedAssetPaths = [];
  final List<double> volumeHistory = [];
  final List<String> eventLog = [];

  @override
  PlayerState get state => _state;

  @override
  Future<void> setAudioContext(AudioContext ctx) async {}

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {
    lastReleaseMode = releaseMode;
  }

  @override
  Future<void> setVolume(double volume) async {
    volumeHistory.add(volume);
    eventLog.add('vol:${volume.toStringAsFixed(3)}');
  }

  @override
  Future<void> play(Source source) async {
    playCount++;
    lastSource = source;
    _state = PlayerState.playing;
    if (source is AssetSource) {
      playedAssetPaths.add(source.path);
      eventLog.add('play:${source.path}');
    }
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    _state = PlayerState.paused;
    eventLog.add('pause');
  }

  @override
  Future<void> resume() async {
    resumeCount++;
    _state = PlayerState.playing;
    eventLog.add('resume');
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _state = PlayerState.stopped;
    eventLog.add('stop');
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    _state = PlayerState.disposed;
    eventLog.add('dispose');
  }
}

class _TestPlayGamesClient implements PlayGamesClient {
  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'BgmTester';

  @override
  Future<String?> getPlayerID() async => 'bgm_tester_1';

  @override
  Future<String?> saveGame({
    required String data,
    required String name,
  }) async => 'success';

  @override
  Future<String?> loadGame({required String name}) async => null;
}

class _NoOpAdMobClient implements AdMobClient {
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
  }) async {}

  @override
  Future<bool> showRewarded({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onDismissed,
    required VoidCallback onFailedToShow,
  }) async => false;

  @override
  void disposeRewarded() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BgmTrack Assets & AudioService Smooth Fade Unit Tests', () {
    test('all 5 BgmTrack MIDI assets exist in the asset bundle with valid SMF headers', () async {
      expect(BgmTrack.worldMap.assetPath, 'audio/world_map.mid');
      expect(BgmTrack.sacredTemple.assetPath, 'audio/sacred_temple.mid');
      expect(BgmTrack.royalCastle.assetPath, 'audio/royal_castle.mid');
      expect(BgmTrack.watchTower.assetPath, 'audio/watch_tower.mid');
      expect(BgmTrack.battle.assetPath, 'audio/battle.mid');

      for (final track in BgmTrack.values) {
        final data = await rootBundle.load('assets/${track.assetPath}');
        expect(data.lengthInBytes, greaterThan(64), reason: track.assetPath);
        final header = String.fromCharCodes(data.buffer.asUint8List(0, 4));
        expect(header, 'MThd', reason: '${track.assetPath} must be valid SMF');
      }
    });

    testWidgets(
      'smoothly fades volume down, switches source in loop mode, and fades back up without duplicate restarts',
      (WidgetTester tester) async {
        final bgm = _RecordingBgmPlayer();
        final sfx = _RecordingBgmPlayer();
        final audio = AudioService(
          bgmPlayer: bgm,
          sfxPlayer: sfx,
          fadeDuration: const Duration(milliseconds: 260),
          fadeSteps: 4,
        );
        addTearDown(audio.dispose);

        await audio.init();
        await audio.playTrack(BgmTrack.worldMap);

        expect(audio.currentTrack, BgmTrack.worldMap);
        expect(audio.loadedTrack, BgmTrack.worldMap);
        expect(bgm.playCount, 1);
        expect(bgm.lastReleaseMode, ReleaseMode.loop);
        expect(bgm.playedAssetPaths, ['audio/world_map.mid']);

        // Calling playTrack with the already active track must NOT restart
        await audio.playTrack(BgmTrack.worldMap);
        expect(bgm.playCount, 1);
        expect(bgm.playedAssetPaths, ['audio/world_map.mid']);

        // Switch to Sacred Temple -> must ramp volume down to 0, switch source, then ramp back up to 0.55
        bgm.eventLog.clear();
        bgm.volumeHistory.clear();
        unawaited(audio.playTrack(BgmTrack.sacredTemple));

        // Pump through fade-out + source swap + fade-in
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 100));

        expect(audio.currentTrack, BgmTrack.sacredTemple);
        expect(audio.loadedTrack, BgmTrack.sacredTemple);
        expect(bgm.playCount, 2);
        expect(bgm.lastReleaseMode, ReleaseMode.loop);
        expect(bgm.playedAssetPaths, [
          'audio/world_map.mid',
          'audio/sacred_temple.mid',
        ]);

        final playIndex = bgm.eventLog.indexOf('play:audio/sacred_temple.mid');
        expect(playIndex, greaterThan(0));

        // Volumes logged before play must descend smoothly to 0.0
        final volsBeforePlay = bgm.eventLog
            .sublist(0, playIndex)
            .where((e) => e.startsWith('vol:'))
            .map((e) => double.parse(e.substring(4)))
            .toList();
        expect(volsBeforePlay.length, greaterThanOrEqualTo(4));
        expect(volsBeforePlay.first, lessThan(AudioService.targetBgmVolume));
        expect(volsBeforePlay.last, closeTo(0.0, 0.001));

        // Volumes logged after play must ascend smoothly back to targetBgmVolume (0.55)
        final volsAfterPlay = bgm.eventLog
            .sublist(playIndex + 1)
            .where((e) => e.startsWith('vol:'))
            .map((e) => double.parse(e.substring(4)))
            .toList();
        expect(volsAfterPlay.length, greaterThanOrEqualTo(4));
        expect(volsAfterPlay.first, greaterThan(0.0));
        expect(volsAfterPlay.last, closeTo(AudioService.targetBgmVolume, 0.001));
        expect(audio.currentBgmVolume, closeTo(AudioService.targetBgmVolume, 0.001));
      },
    );

    testWidgets(
      'cancelling back to the currently loaded track mid-fade-out restores volume without restarting',
      (WidgetTester tester) async {
        final bgm = _RecordingBgmPlayer();
        final sfx = _RecordingBgmPlayer();
        final audio = AudioService(
          bgmPlayer: bgm,
          sfxPlayer: sfx,
          fadeDuration: const Duration(milliseconds: 260),
          fadeSteps: 4,
        );
        addTearDown(audio.dispose);

        await audio.init();
        await audio.playTrack(BgmTrack.worldMap);
        expect(bgm.playCount, 1);

        // Start transitioning to Royal Castle, advance partway through fade-out
        unawaited(audio.playTrack(BgmTrack.royalCastle));
        await tester.pump(const Duration(milliseconds: 140));
        expect(bgm.playCount, 1); // Still fading out worldMap, hasn't loaded royalCastle yet
        expect(audio.currentBgmVolume, lessThan(AudioService.targetBgmVolume));

        // Immediately return to World Map before fade-out completes
        unawaited(audio.playTrack(BgmTrack.worldMap));
        await tester.pump(const Duration(milliseconds: 400));

        expect(audio.currentTrack, BgmTrack.worldMap);
        expect(audio.loadedTrack, BgmTrack.worldMap);
        expect(bgm.playCount, 1); // Never restarted world_map.mid!
        expect(audio.currentBgmVolume, closeTo(AudioService.targetBgmVolume, 0.001));
      },
    );

    testWidgets(
      'honors mute across all 5 tracks and starts the active track when unmuted, and preserves track across background pause/resume',
      (WidgetTester tester) async {
        final bgm = _RecordingBgmPlayer();
        final sfx = _RecordingBgmPlayer();
        final audio = AudioService(
          bgmPlayer: bgm,
          sfxPlayer: sfx,
          fadeDuration: const Duration(milliseconds: 260),
          fadeSteps: 4,
        );
        addTearDown(audio.dispose);

        audio.musicEnabled = false;
        await audio.init();

        for (final track in BgmTrack.values) {
          await audio.playTrack(track);
        }
        expect(bgm.playCount, 0);
        expect(audio.currentTrack, BgmTrack.battle);

        // Unmuting plays the track corresponding to the active screen (battle)
        audio.musicEnabled = true;
        await audio.startMusic();
        expect(bgm.playCount, 1);
        expect(bgm.playedAssetPaths, ['audio/battle.mid']);

        // Switch to watchTower, then minimize and resume app
        unawaited(audio.playTrack(BgmTrack.watchTower));
        await tester.pump(const Duration(milliseconds: 700));
        expect(audio.loadedTrack, BgmTrack.watchTower);
        expect(bgm.playedAssetPaths.last, 'audio/watch_tower.mid');

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(bgm.pauseCount, 1);
        expect(bgm.state, PlayerState.paused);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        expect(bgm.resumeCount, 1);
        expect(bgm.playCount, 2); // Resumed watchTower without restarting
        expect(bgm.state, PlayerState.playing);
        expect(audio.currentBgmVolume, closeTo(AudioService.targetBgmVolume, 0.001));
      },
    );
  });

  group('Automatic BGM Routing Across WorldMap, Location Dialogs, Spyglass & Battle', () {
    Future<({GameController controller, _RecordingBgmPlayer bgm, AudioService audio})>
    createAppHarness({
      required WidgetTester tester,
      bool musicEnabled = true,
    }) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        'has_shown_week0_scream_warning': true,
        'animationsEnabled': false,
        'musicEnabled': musicEnabled,
        'soundEnabled': false,
        'vibrationEnabled': false,
      });
      final storage = StorageService();
      await storage.init();

      final localization = LocalizationService();
      await tester.runAsync(() => localization.load());

      final bgm = _RecordingBgmPlayer();
      final sfx = _RecordingBgmPlayer();
      final audio = AudioService(
        bgmPlayer: bgm,
        sfxPlayer: sfx,
        fadeDuration: const Duration(milliseconds: 240),
        fadeSteps: 4,
      );
      await audio.init();

      final playGames = PlayGamesService(
        storage: storage,
        client: _TestPlayGamesClient(),
      );
      final adService = AdService(client: _NoOpAdMobClient());

      final controller = GameController(
        storage: storage,
        localization: localization,
        audio: audio,
        playGames: playGames,
        adService: adService,
      );

      addTearDown(() {
        controller.dispose();
        audio.dispose();
      });

      return (controller: controller, bgm: bgm, audio: audio);
    }

    Future<void> pumpFadeComplete(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets(
      'routes music cleanly across WorldMap -> SacredTemple -> RoyalCastle -> WatchTower (+ FullScreenSpyglassView) -> Battle -> WorldMap',
      (WidgetTester tester) async {
        final harness = await createAppHarness(tester: tester);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: harness.controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. World Map active -> plays world_map.mid once without duplicate restart
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(harness.audio.currentTrack, BgmTrack.worldMap);
        expect(harness.audio.loadedTrack, BgmTrack.worldMap);
        expect(harness.bgm.playCount, 1);
        expect(harness.bgm.playedAssetPaths, ['audio/world_map.mid']);

        // 2. Open Sacred Temple -> switches to sacred_temple.mid, closing restores world_map.mid
        await tester.tap(find.byKey(const ValueKey('landmark_sacred_temple')));
        await tester.pumpAndSettle();
        await pumpFadeComplete(tester);
        expect(find.byType(SacredTempleDialog), findsOneWidget);
        expect(harness.audio.currentTrack, BgmTrack.sacredTemple);
        expect(harness.audio.loadedTrack, BgmTrack.sacredTemple);
        expect(harness.bgm.playedAssetPaths.last, 'audio/sacred_temple.mid');

        await tester.tap(find.byKey(const ValueKey('shop_close_button')));
        await tester.pumpAndSettle();
        await pumpFadeComplete(tester);
        expect(find.byType(SacredTempleDialog), findsNothing);
        expect(harness.audio.currentTrack, BgmTrack.worldMap);
        expect(harness.audio.loadedTrack, BgmTrack.worldMap);
        expect(harness.bgm.playedAssetPaths.last, 'audio/world_map.mid');

        // 3. Open Royal Castle -> switches to royal_castle.mid, closing restores world_map.mid
        await tester.tap(find.byKey(const ValueKey('landmark_royal_castle')));
        await tester.pumpAndSettle();
        await pumpFadeComplete(tester);
        expect(find.byType(RoyalCastleDialog), findsOneWidget);
        expect(harness.audio.currentTrack, BgmTrack.royalCastle);
        expect(harness.audio.loadedTrack, BgmTrack.royalCastle);
        expect(harness.bgm.playedAssetPaths.last, 'audio/royal_castle.mid');

        await tester.tap(find.byKey(const ValueKey('royal_castle_close_button')));
        await tester.pumpAndSettle();
        await pumpFadeComplete(tester);
        expect(find.byType(RoyalCastleDialog), findsNothing);
        expect(harness.audio.currentTrack, BgmTrack.worldMap);
        expect(harness.audio.loadedTrack, BgmTrack.worldMap);
        expect(harness.bgm.playedAssetPaths.last, 'audio/world_map.mid');

        // 4. Open Watch Tower -> switches to watch_tower.mid and keeps playing seamlessly through Spyglass & FullScreenSpyglassView
        await tester.tap(find.byKey(const ValueKey('landmark_telescope_tower')));
        await tester.pumpAndSettle();
        await pumpFadeComplete(tester);
        expect(find.byType(ObservatoryDialog), findsOneWidget);
        expect(harness.audio.currentTrack, BgmTrack.watchTower);
        expect(harness.audio.loadedTrack, BgmTrack.watchTower);
        expect(harness.bgm.playedAssetPaths.last, 'audio/watch_tower.mid');

        final playCountInWatchTower = harness.bgm.playCount;

        // Open Princess Spyglass modal
        await tester.tap(find.byKey(const ValueKey('observatory_spy_princess_button')));
        await tester.pumpAndSettle();
        expect(find.byType(WatchtowerSpyglassDialog), findsOneWidget);
        expect(harness.audio.currentTrack, BgmTrack.watchTower);
        expect(harness.bgm.playCount, playCountInWatchTower);

        // Expand into FullScreenSpyglassView -> must NOT restart watch_tower.mid
        await tester.tap(find.byKey(const ValueKey('watchtower_spyglass_lens_tap')));
        await tester.pumpAndSettle();
        expect(find.byType(FullScreenSpyglassView), findsOneWidget);
        expect(harness.audio.currentTrack, BgmTrack.watchTower);
        expect(harness.bgm.playCount, playCountInWatchTower);

        // Close FullScreenSpyglassView -> still inside Watch Tower, must stay watch_tower.mid
        await tester.tap(find.byKey(const ValueKey('full_screen_spyglass_close_button')));
        await tester.pumpAndSettle();
        expect(find.byType(FullScreenSpyglassView), findsNothing);
        expect(harness.audio.currentTrack, BgmTrack.watchTower);
        expect(harness.bgm.playCount, playCountInWatchTower);

        // Close WatchtowerSpyglassDialog -> still inside Watch Tower
        await tester.tap(find.byKey(const ValueKey('watchtower_spyglass_close_button')));
        await tester.pumpAndSettle();
        expect(harness.audio.currentTrack, BgmTrack.watchTower);
        expect(harness.bgm.playCount, playCountInWatchTower);

        // Close ObservatoryDialog (Watch Tower) -> restores world_map.mid
        await tester.tap(find.byKey(const ValueKey('observatory_close_button')));
        await tester.pumpAndSettle();
        await pumpFadeComplete(tester);
        expect(find.byType(ObservatoryDialog), findsNothing);
        expect(harness.audio.currentTrack, BgmTrack.worldMap);
        expect(harness.audio.loadedTrack, BgmTrack.worldMap);
        expect(harness.bgm.playedAssetPaths.last, 'audio/world_map.mid');

        // 5. Enter Metal Wizard's Lair (GameScreen Battle) -> switches to battle.mid
        await tester.tap(find.byKey(const ValueKey('landmark_metal_wizard_lair')));
        await tester.pumpAndSettle();
        await pumpFadeComplete(tester);
        expect(find.byType(GameScreen), findsOneWidget);
        expect(harness.audio.currentTrack, BgmTrack.battle);
        expect(harness.audio.loadedTrack, BgmTrack.battle);
        expect(harness.bgm.playedAssetPaths.last, 'audio/battle.mid');

        // Pop GameScreen back to WorldMapScreen -> restores world_map.mid
        final navState = tester.state<NavigatorState>(find.byType(Navigator));
        navState.pop();
        await tester.pumpAndSettle();
        await pumpFadeComplete(tester);
        expect(find.byType(GameScreen), findsNothing);
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(harness.audio.currentTrack, BgmTrack.worldMap);
        expect(harness.audio.loadedTrack, BgmTrack.worldMap);
        expect(harness.bgm.playedAssetPaths.last, 'audio/world_map.mid');
      },
    );

    testWidgets(
      'muted setting suppresses playback during dialog and battle routing and starts the current screen track on unmute',
      (WidgetTester tester) async {
        final harness = await createAppHarness(
          tester: tester,
          musicEnabled: false,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: harness.controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(harness.bgm.playCount, 0);
        expect(harness.audio.currentTrack, BgmTrack.worldMap);

        // Open Royal Castle while muted -> currentTrack updates, zero playback
        await tester.tap(find.byKey(const ValueKey('landmark_royal_castle')));
        await tester.pumpAndSettle();
        expect(harness.audio.currentTrack, BgmTrack.royalCastle);
        expect(harness.bgm.playCount, 0);

        // Unmute while inside Royal Castle -> immediately plays royal_castle.mid
        harness.controller.toggleMusic(true);
        await tester.pump();
        expect(harness.bgm.playCount, 1);
        expect(harness.bgm.playedAssetPaths, ['audio/royal_castle.mid']);

        // Close Royal Castle -> fades back to world_map.mid
        await tester.tap(find.byKey(const ValueKey('royal_castle_close_button')));
        await tester.pumpAndSettle();
        await pumpFadeComplete(tester);
        expect(harness.audio.currentTrack, BgmTrack.worldMap);
        expect(harness.bgm.playedAssetPaths.last, 'audio/world_map.mid');
      },
    );
  });
}
