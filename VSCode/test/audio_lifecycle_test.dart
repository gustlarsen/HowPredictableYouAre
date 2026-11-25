import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
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

class _SpyAudioPlayerClient implements AudioPlayerClient {
  PlayerState _state = PlayerState.stopped;
  int playCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;
  int disposeCount = 0;
  ReleaseMode? lastReleaseMode;
  Source? lastSource;

  @override
  PlayerState get state => _state;

  @override
  Future<void> setAudioContext(AudioContext ctx) async {}

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {
    lastReleaseMode = releaseMode;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> play(Source source) async {
    playCount++;
    lastSource = source;
    _state = PlayerState.playing;
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    _state = PlayerState.paused;
  }

  @override
  Future<void> resume() async {
    resumeCount++;
    _state = PlayerState.playing;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _state = PlayerState.stopped;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    _state = PlayerState.disposed;
  }
}

class _TestPlayGamesClient implements PlayGamesClient {
  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'TestPlayer';

  @override
  Future<String?> getPlayerID() async => 'test_player_1';

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

  group('AudioService App Lifecycle Tests', () {
    testWidgets(
      'pauses background music on AppLifecycleState.paused and resumes existing player on AppLifecycleState.resumed',
      (WidgetTester tester) async {
        final bgmPlayer = _SpyAudioPlayerClient();
        final sfxPlayer = _SpyAudioPlayerClient();
        final audio = AudioService(bgmPlayer: bgmPlayer, sfxPlayer: sfxPlayer);
        addTearDown(audio.dispose);

        await audio.init();
        expect(audio.isObserverRegistered, isTrue);

        await audio.startMusic();
        expect(bgmPlayer.playCount, 1);
        expect(bgmPlayer.state, PlayerState.playing);
        expect(audio.wasPlayingBeforeBackground, isFalse);

        // Minimize / lock screen
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        expect(bgmPlayer.pauseCount, 1);
        expect(bgmPlayer.state, PlayerState.paused);
        expect(audio.wasPlayingBeforeBackground, isTrue);
        expect(audio.isMusicPlaying, isFalse);

        // Return to foreground
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(bgmPlayer.resumeCount, 1);
        expect(bgmPlayer.playCount, 1); // Did not spawn/restart duplicate audio
        expect(bgmPlayer.state, PlayerState.playing);
        expect(audio.wasPlayingBeforeBackground, isFalse);
        expect(audio.isMusicPlaying, isTrue);
      },
    );

    testWidgets(
      'pauses once across inactive -> hidden -> paused sequence and resumes once on resumed',
      (WidgetTester tester) async {
        final bgmPlayer = _SpyAudioPlayerClient();
        final sfxPlayer = _SpyAudioPlayerClient();
        final audio = AudioService(bgmPlayer: bgmPlayer, sfxPlayer: sfxPlayer);
        addTearDown(audio.dispose);

        await audio.init();
        await audio.startMusic();
        expect(bgmPlayer.state, PlayerState.playing);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        expect(bgmPlayer.pauseCount, 1);
        expect(bgmPlayer.state, PlayerState.paused);
        expect(audio.wasPlayingBeforeBackground, isTrue);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(bgmPlayer.resumeCount, 1);
        expect(bgmPlayer.playCount, 1);
        expect(bgmPlayer.state, PlayerState.playing);
        expect(audio.wasPlayingBeforeBackground, isFalse);
      },
    );

    testWidgets(
      'pauses on AppLifecycleState.hidden directly and resumes on AppLifecycleState.resumed',
      (WidgetTester tester) async {
        final bgmPlayer = _SpyAudioPlayerClient();
        final sfxPlayer = _SpyAudioPlayerClient();
        final audio = AudioService(bgmPlayer: bgmPlayer, sfxPlayer: sfxPlayer);
        addTearDown(audio.dispose);

        await audio.init();
        await audio.startMusic();

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pump();

        expect(bgmPlayer.pauseCount, 1);
        expect(bgmPlayer.state, PlayerState.paused);
        expect(audio.wasPlayingBeforeBackground, isTrue);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(bgmPlayer.resumeCount, 1);
        expect(bgmPlayer.playCount, 1);
        expect(bgmPlayer.state, PlayerState.playing);
        expect(audio.wasPlayingBeforeBackground, isFalse);
      },
    );

    testWidgets(
      'does not start or resume background music when muted in settings',
      (WidgetTester tester) async {
        final bgmPlayer = _SpyAudioPlayerClient();
        final sfxPlayer = _SpyAudioPlayerClient();
        final audio = AudioService(bgmPlayer: bgmPlayer, sfxPlayer: sfxPlayer);
        addTearDown(audio.dispose);

        audio.musicEnabled = false;
        await audio.init();
        await audio.startMusic();

        expect(bgmPlayer.playCount, 0);
        expect(bgmPlayer.state, PlayerState.stopped);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        expect(bgmPlayer.pauseCount, 0);
        expect(audio.wasPlayingBeforeBackground, isFalse);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(bgmPlayer.resumeCount, 0);
        expect(bgmPlayer.playCount, 0);
        expect(bgmPlayer.state, PlayerState.stopped);
      },
    );

    testWidgets(
      'does not resume if background music is muted while app is in background',
      (WidgetTester tester) async {
        final bgmPlayer = _SpyAudioPlayerClient();
        final sfxPlayer = _SpyAudioPlayerClient();
        final audio = AudioService(bgmPlayer: bgmPlayer, sfxPlayer: sfxPlayer);
        addTearDown(audio.dispose);

        await audio.init();
        await audio.startMusic();
        expect(bgmPlayer.state, PlayerState.playing);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(bgmPlayer.pauseCount, 1);
        expect(audio.wasPlayingBeforeBackground, isTrue);

        // User setting becomes muted while backgrounded
        audio.musicEnabled = false;

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(bgmPlayer.resumeCount, 0);
        expect(bgmPlayer.playCount, 1);
        expect(bgmPlayer.state, PlayerState.paused);
        expect(audio.wasPlayingBeforeBackground, isFalse);
      },
    );

    testWidgets(
      'does not resume music that was already explicitly paused before backgrounding',
      (WidgetTester tester) async {
        final bgmPlayer = _SpyAudioPlayerClient();
        final sfxPlayer = _SpyAudioPlayerClient();
        final audio = AudioService(bgmPlayer: bgmPlayer, sfxPlayer: sfxPlayer);
        addTearDown(audio.dispose);

        await audio.init();
        await audio.startMusic();
        await audio.pauseMusic();
        expect(bgmPlayer.pauseCount, 1);
        expect(bgmPlayer.state, PlayerState.paused);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(bgmPlayer.pauseCount, 1);
        expect(audio.wasPlayingBeforeBackground, isFalse);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(bgmPlayer.resumeCount, 0);
        expect(bgmPlayer.state, PlayerState.paused);
      },
    );

    testWidgets(
      'defers startMusic requested while backgrounded and removes observer on dispose',
      (WidgetTester tester) async {
        final bgmPlayer = _SpyAudioPlayerClient();
        final sfxPlayer = _SpyAudioPlayerClient();
        final audio = AudioService(bgmPlayer: bgmPlayer, sfxPlayer: sfxPlayer);

        await audio.init();
        expect(audio.isObserverRegistered, isTrue);

        // Background first, then request startMusic
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await audio.startMusic();

        expect(bgmPlayer.playCount, 0);
        expect(audio.wasPlayingBeforeBackground, isTrue);

        // Returning to foreground starts music once
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(bgmPlayer.playCount, 1);
        expect(bgmPlayer.state, PlayerState.playing);

        // Dispose removes WidgetsBindingObserver
        audio.dispose();
        expect(audio.isObserverRegistered, isFalse);
        expect(bgmPlayer.disposeCount, 1);
        expect(sfxPlayer.disposeCount, 1);

        // Lifecycle transitions after dispose do not invoke player methods
        final pausesBefore = bgmPlayer.pauseCount;
        final resumesBefore = bgmPlayer.resumeCount;
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(bgmPlayer.pauseCount, pausesBefore);
        expect(bgmPlayer.resumeCount, resumesBefore);
      },
    );
  });

  group('HowPredictableApp Background Music Lifecycle Integration Tests', () {
    Future<({GameController controller, _SpyAudioPlayerClient bgmPlayer, AudioService audio})>
    createAppHarness({
      required WidgetTester tester,
      bool musicEnabled = true,
      bool hasSeenIntro = true,
    }) async {
      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': hasSeenIntro,
        'animationsEnabled': false,
        'musicEnabled': musicEnabled,
      });
      final storage = StorageService();
      await storage.init();

      final localization = LocalizationService();
      await tester.runAsync(() => localization.load());

      final bgmPlayer = _SpyAudioPlayerClient();
      final sfxPlayer = _SpyAudioPlayerClient();
      final audio = AudioService(bgmPlayer: bgmPlayer, sfxPlayer: sfxPlayer);
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

      return (controller: controller, bgmPlayer: bgmPlayer, audio: audio);
    }

    testWidgets(
      'pauses and resumes background music cleanly even when a modal dialog (Settings) is open',
      (WidgetTester tester) async {
        final harness = await createAppHarness(
          tester: tester,
          musicEnabled: true,
          hasSeenIntro: true,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: harness.controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(harness.bgmPlayer.playCount, 1);
        expect(harness.bgmPlayer.state, PlayerState.playing);

        // Open Settings dialog so WorldMapScreen is no longer the current ModalRoute
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('settings_background_music_tile')), findsOneWidget);

        // Minimize app while dialog is open
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        expect(harness.bgmPlayer.pauseCount, 1);
        expect(harness.bgmPlayer.state, PlayerState.paused);
        expect(harness.audio.wasPlayingBeforeBackground, isTrue);

        // Return to app -> resumes once without spawning duplicate audio
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(harness.bgmPlayer.resumeCount, 1);
        expect(harness.bgmPlayer.playCount, 1);
        expect(harness.bgmPlayer.state, PlayerState.playing);
        expect(harness.audio.wasPlayingBeforeBackground, isFalse);
      },
    );

    testWidgets(
      'respects Background Music mute toggle in Settings across pause and resume',
      (WidgetTester tester) async {
        final harness = await createAppHarness(
          tester: tester,
          musicEnabled: true,
          hasSeenIntro: true,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: harness.controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(harness.bgmPlayer.playCount, 1);
        expect(harness.bgmPlayer.state, PlayerState.playing);

        // Mute background music via controller/settings
        harness.controller.toggleMusic(false);
        await tester.pump();

        expect(harness.controller.musicEnabled, isFalse);
        expect(harness.bgmPlayer.stopCount, 1);
        expect(harness.bgmPlayer.state, PlayerState.stopped);

        // Minimize and return -> must remain muted/stopped
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(harness.bgmPlayer.pauseCount, 0);
        expect(harness.bgmPlayer.resumeCount, 0);
        expect(harness.bgmPlayer.playCount, 1);
        expect(harness.bgmPlayer.state, PlayerState.stopped);
      },
    );

    testWidgets(
      'pauses and resumes background music while on IntroStoryScreen',
      (WidgetTester tester) async {
        final harness = await createAppHarness(
          tester: tester,
          musicEnabled: true,
          hasSeenIntro: false,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: harness.controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pump();

        expect(harness.bgmPlayer.playCount, 1);
        expect(harness.bgmPlayer.state, PlayerState.playing);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pump();
        expect(harness.bgmPlayer.pauseCount, 1);
        expect(harness.bgmPlayer.state, PlayerState.paused);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(harness.bgmPlayer.resumeCount, 1);
        expect(harness.bgmPlayer.playCount, 1);
        expect(harness.bgmPlayer.state, PlayerState.playing);
      },
    );
  });

  group('AudioService Princess Scream & BGM Coexistence Tests', () {
    testWidgets(
      'pauses worldMap BGM while princess_scream.mid plays and smoothly resumes worldMap afterward',
      (WidgetTester tester) async {
        final bgmPlayer = _SpyAudioPlayerClient();
        final sfxPlayer = _SpyAudioPlayerClient();
        final audio = AudioService(
          bgmPlayer: bgmPlayer,
          sfxPlayer: sfxPlayer,
          fadeDuration: const Duration(milliseconds: 240),
          fadeSteps: 4,
          princessScreamDuration: const Duration(milliseconds: 1600),
        );
        addTearDown(audio.dispose);

        await audio.init();
        await audio.playTrack(BgmTrack.worldMap, fade: false);
        expect(bgmPlayer.state, PlayerState.playing);
        expect(bgmPlayer.playCount, 1);

        await audio.playPrincessScream();
        expect(audio.isPrincessScreamPlaying, isTrue);
        expect(audio.isBgmDuckPausedForScream, isTrue);
        expect(bgmPlayer.pauseCount, 1);
        expect(bgmPlayer.state, PlayerState.paused);
        expect(sfxPlayer.playCount, 1);
        expect(sfxPlayer.lastReleaseMode, ReleaseMode.release);
        expect(
          (sfxPlayer.lastSource as AssetSource).path,
          AudioService.princessScreamAssetPath,
        );

        // Pump halfway through scream -> BGM remains paused so Android MIDI voices don't drop
        await tester.pump(const Duration(milliseconds: 900));
        expect(audio.isPrincessScreamPlaying, isTrue);
        expect(bgmPlayer.state, PlayerState.paused);

        // Complete scream duration + fade-in -> worldMap resumes smoothly without restarting
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump(const Duration(milliseconds: 300));
        expect(audio.isPrincessScreamPlaying, isFalse);
        expect(audio.isBgmDuckPausedForScream, isFalse);
        expect(bgmPlayer.resumeCount, 1);
        expect(bgmPlayer.playCount, 1);
        expect(bgmPlayer.state, PlayerState.playing);
        expect(audio.currentBgmVolume, closeTo(AudioService.targetBgmVolume, 0.001));
      },
    );

    testWidgets(
      'stops scream early and restores worldMap BGM when pop-up is dismissed before scream ends',
      (WidgetTester tester) async {
        final bgmPlayer = _SpyAudioPlayerClient();
        final sfxPlayer = _SpyAudioPlayerClient();
        final audio = AudioService(
          bgmPlayer: bgmPlayer,
          sfxPlayer: sfxPlayer,
          fadeDuration: const Duration(milliseconds: 200),
          fadeSteps: 4,
          princessScreamDuration: const Duration(milliseconds: 1600),
        );
        addTearDown(audio.dispose);

        await audio.init();
        await audio.playTrack(BgmTrack.worldMap, fade: false);
        await audio.playPrincessScream();
        expect(audio.isPrincessScreamPlaying, isTrue);
        expect(bgmPlayer.state, PlayerState.paused);

        await tester.pump(const Duration(milliseconds: 400));
        unawaited(audio.finishPrincessScreamAndRestoreBgm());
        await tester.pump(const Duration(milliseconds: 300));

        expect(audio.isPrincessScreamPlaying, isFalse);
        expect(sfxPlayer.state, PlayerState.stopped);
        expect(bgmPlayer.resumeCount, 1);
        expect(bgmPlayer.state, PlayerState.playing);
      },
    );

    testWidgets(
      'interrupting battle -> worldMap fade transition loads worldMap instead of resuming battle after scream',
      (WidgetTester tester) async {
        final bgmPlayer = _SpyAudioPlayerClient();
        final sfxPlayer = _SpyAudioPlayerClient();
        final audio = AudioService(
          bgmPlayer: bgmPlayer,
          sfxPlayer: sfxPlayer,
          fadeDuration: const Duration(milliseconds: 240),
          fadeSteps: 4,
          princessScreamDuration: const Duration(milliseconds: 1200),
        );
        addTearDown(audio.dispose);

        await audio.init();
        await audio.playTrack(BgmTrack.battle, fade: false);
        expect(audio.loadedTrack, BgmTrack.battle);

        // Start fading from battle -> worldMap, then trigger scream mid-fade-out
        final switchFuture = audio.playTrack(BgmTrack.worldMap);
        await tester.pump(const Duration(milliseconds: 80));
        expect(audio.loadedTrack, BgmTrack.battle);
        expect(audio.currentTrack, BgmTrack.worldMap);

        await audio.playPrincessScream();
        await switchFuture;
        expect(bgmPlayer.state, PlayerState.paused);
        expect(audio.isPrincessScreamPlaying, isTrue);

        // Let scream finish and worldMap fade in
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(audio.isPrincessScreamPlaying, isFalse);
        expect(audio.loadedTrack, BgmTrack.worldMap);
        expect((bgmPlayer.lastSource as AssetSource).path, 'audio/world_map.mid');
        expect(bgmPlayer.state, PlayerState.playing);
      },
    );

    testWidgets(
      'respects soundEnabled=false, musicEnabled=false, and background lifecycle states',
      (WidgetTester tester) async {
        final bgmPlayer = _SpyAudioPlayerClient();
        final sfxPlayer = _SpyAudioPlayerClient();
        final audio = AudioService(
          bgmPlayer: bgmPlayer,
          sfxPlayer: sfxPlayer,
          fadeDuration: const Duration(milliseconds: 160),
          fadeSteps: 4,
          princessScreamDuration: const Duration(milliseconds: 1200),
        );
        addTearDown(audio.dispose);

        await audio.init();
        await audio.playTrack(BgmTrack.worldMap, fade: false);

        // 1. Sound muted -> does NOT play scream and does NOT pause BGM
        audio.soundEnabled = false;
        await audio.playPrincessScream();
        expect(sfxPlayer.playCount, 0);
        expect(audio.isPrincessScreamPlaying, isFalse);
        expect(bgmPlayer.pauseCount, 0);
        expect(bgmPlayer.state, PlayerState.playing);

        // 2. Backgrounded mid-scream -> stops scream immediately and resumes BGM on foreground
        audio.soundEnabled = true;
        await audio.playPrincessScream();
        expect(sfxPlayer.playCount, 1);
        expect(audio.isPrincessScreamPlaying, isTrue);
        expect(bgmPlayer.pauseCount, 1);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(audio.isPrincessScreamPlaying, isFalse);
        expect(sfxPlayer.state, PlayerState.stopped);
        expect(audio.wasPlayingBeforeBackground, isTrue);

        // Scream requested while backgrounded is ignored
        await audio.playPrincessScream();
        expect(sfxPlayer.playCount, 1);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(bgmPlayer.resumeCount, 1);
        expect(bgmPlayer.state, PlayerState.playing);

        // 3. Music muted + sound enabled -> plays scream, leaves BGM stopped afterward
        audio.musicEnabled = false;
        await audio.stopMusic();
        await audio.playPrincessScream();
        expect(sfxPlayer.playCount, 2);
        expect(audio.isPrincessScreamPlaying, isTrue);

        await tester.pump(const Duration(milliseconds: 1300));
        expect(audio.isPrincessScreamPlaying, isFalse);
        expect(bgmPlayer.state, PlayerState.stopped);
      },
    );
  });
}
