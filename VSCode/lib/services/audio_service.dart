import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Abstraction over [AudioPlayer] so [AudioService] uses the official
/// `audioplayers` plugin in production while remaining deterministically
/// testable in unit and widget tests.
abstract class AudioPlayerClient {
  PlayerState get state;
  Future<void> setAudioContext(AudioContext ctx);
  Future<void> setReleaseMode(ReleaseMode releaseMode);
  Future<void> setVolume(double volume);
  Future<void> play(Source source);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

/// Default production implementation of [AudioPlayerClient] backed by
/// the official `audioplayers` [AudioPlayer].
class DefaultAudioPlayerClient implements AudioPlayerClient {
  final AudioPlayer _player;

  DefaultAudioPlayerClient([AudioPlayer? player])
      : _player = player ?? AudioPlayer();

  @override
  PlayerState get state => _player.state;

  @override
  Future<void> setAudioContext(AudioContext ctx) =>
      _player.setAudioContext(ctx);

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) =>
      _player.setReleaseMode(releaseMode);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> play(Source source) => _player.play(source);

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

/// Background music tracks routed across the World Map, location hubs, and battles.
enum BgmTrack {
  worldMap('audio/world_map.mid'),
  sacredTemple('audio/sacred_temple.mid'),
  royalCastle('audio/royal_castle.mid'),
  watchTower('audio/watch_tower.mid'),
  battle('audio/battle.mid');

  final String assetPath;
  const BgmTrack(this.assetPath);
}

class AudioService with WidgetsBindingObserver {
  static const MethodChannel vibratorChannel = MethodChannel(
    'com.gustlarsen.howpredictable/vibrator',
  );

  static const int winVibrationDurationMs = 100;
  static const int drawVibrationDurationMs = 250;
  static const int defeatVibrationDurationMs = 500;
  static const int defaultVibrationDurationMs = 100;
  static const int tapVibrationDurationMs = 40;
  static const int rapidFireHapticDurationMs = 25;
  static const Duration rapidFireHapticMinInterval = Duration(milliseconds: 120);
  static const Duration rapidFireSfxMinInterval = Duration(milliseconds: 120);

  static const double targetBgmVolume = 0.55;
  static const Duration defaultFadeDuration = Duration(milliseconds: 260);
  static const int defaultFadeSteps = 8;
  static const String princessScreamAssetPath = 'audio/princess_scream.mid';
  static const Duration defaultPrincessScreamDuration = Duration(
    milliseconds: 1700,
  );

  final Duration _fadeDuration;
  final int _fadeSteps;
  final Duration _princessScreamDuration;

  AudioPlayerClient? _sfxPlayer;
  AudioPlayerClient? _bgmPlayer;
  bool _isObserverRegistered = false;
  bool _isDisposed = false;
  bool _isAppInBackground = false;
  bool _isMusicPlaying = false;
  bool _hasLoadedMusicSource = false;
  bool _wasPlayingBeforeBackground = false;
  bool _isPrincessScreamPlaying = false;
  bool _resumeBgmAfterScream = false;
  int _screamToken = 0;
  Timer? _screamRestoreTimer;
  BgmTrack _currentTrack = BgmTrack.worldMap;
  BgmTrack? _loadedTrack;
  BgmTrack? _activeTransitionTrack;
  double _currentBgmVolume = targetBgmVolume;
  int _transitionToken = 0;
  Timer? _fadeTimer;
  Completer<void>? _fadeStepCompleter;
  bool _isRapidFireHapticOnCooldown = false;
  Timer? _rapidFireHapticCooldownTimer;
  bool _isRapidFireSfxOnCooldown = false;
  Timer? _rapidFireSfxCooldownTimer;

  @visibleForTesting
  VoidCallback? onSfxTriggeredForTest;

  @visibleForTesting
  bool get wasPlayingBeforeBackground => _wasPlayingBeforeBackground;

  @visibleForTesting
  bool get isMusicPlaying => _isMusicPlaying;

  @visibleForTesting
  bool get isObserverRegistered => _isObserverRegistered;

  @visibleForTesting
  bool get isPrincessScreamPlaying => _isPrincessScreamPlaying;

  @visibleForTesting
  bool get isBgmDuckPausedForScream => _resumeBgmAfterScream;

  /// The logical BGM track currently selected for the active screen or modal.
  BgmTrack get currentTrack => _currentTrack;

  @visibleForTesting
  BgmTrack? get loadedTrack => _loadedTrack;

  @visibleForTesting
  double get currentBgmVolume => _currentBgmVolume;

  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool vibrationEnabled = true;

  bool get soundEnabled => _soundEnabled;
  set soundEnabled(bool value) {
    _soundEnabled = value;
    if (!value && (_isPrincessScreamPlaying || _resumeBgmAfterScream)) {
      unawaited(finishPrincessScreamAndRestoreBgm());
    }
  }

  bool get musicEnabled => _musicEnabled;
  set musicEnabled(bool value) {
    _musicEnabled = value;
    if (!value) {
      _wasPlayingBeforeBackground = false;
      _resumeBgmAfterScream = false;
      _transitionToken++;
      _activeTransitionTrack = null;
      _cancelFadeTimer();
    }
  }

  AudioService({
    AudioPlayerClient? sfxPlayer,
    AudioPlayerClient? bgmPlayer,
    Duration fadeDuration = defaultFadeDuration,
    int fadeSteps = defaultFadeSteps,
    Duration princessScreamDuration = defaultPrincessScreamDuration,
  }) : _sfxPlayer = sfxPlayer,
       _bgmPlayer = bgmPlayer,
       _fadeDuration = fadeDuration,
       _fadeSteps = fadeSteps < 1 ? 1 : fadeSteps,
       _princessScreamDuration = princessScreamDuration;

  Future<void> init({bool observeAppLifecycle = true}) async {
    _isDisposed = false;
    _sfxPlayer ??= DefaultAudioPlayerClient();
    _bgmPlayer ??= DefaultAudioPlayerClient();
    if (observeAppLifecycle && !_isObserverRegistered) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _isObserverRegistered = true;
      } catch (_) {
        // Ignore if WidgetsBinding is not initialized (e.g. pure Dart tests).
      }
    }
    final audioContext = AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
      ),
    );
    try {
      await _bgmPlayer!.setAudioContext(audioContext);
      await _sfxPlayer!.setAudioContext(audioContext);
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _setBgmVolume(targetBgmVolume);
      await _sfxPlayer!.setVolume(1.0);
    } catch (error) {
      debugPrint('Could not initialize audio: $error');
    }
  }

  Future<void> _setBgmVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    _currentBgmVolume = clamped;
    await _bgmPlayer?.setVolume(clamped);
  }

  void _cancelFadeTimer() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    final completer = _fadeStepCompleter;
    _fadeStepCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _waitFadeStep(Duration delay) {
    _cancelFadeTimer();
    final completer = Completer<void>();
    _fadeStepCompleter = completer;
    _fadeTimer = Timer(delay, () {
      _fadeTimer = null;
      if (identical(_fadeStepCompleter, completer)) {
        _fadeStepCompleter = null;
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }

  bool _shouldAbortTransition(int token) {
    if (token != _transitionToken || _isDisposed) {
      return true;
    }
    if (!musicEnabled) {
      _isMusicPlaying = false;
      return true;
    }
    if (_isAppInBackground) {
      _isMusicPlaying = false;
      _wasPlayingBeforeBackground = true;
      return true;
    }
    return false;
  }

  Future<bool> _rampBgmVolume({
    required double from,
    required double to,
    required Duration duration,
    required int token,
  }) async {
    final steps = _fadeSteps;
    final stepMs = (duration.inMilliseconds / steps).round();
    final stepDelay = Duration(milliseconds: stepMs < 1 ? 1 : stepMs);

    for (int i = 1; i <= steps; i++) {
      await _waitFadeStep(stepDelay);
      if (_shouldAbortTransition(token)) {
        return false;
      }
      final t = i / steps;
      final nextVolume = (from + (to - from) * t).clamp(0.0, 1.0);
      await _setBgmVolume(nextVolume);
      if (_shouldAbortTransition(token)) {
        return false;
      }
    }
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(handleAppLifecycleState(state));
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    if (_isDisposed) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      final wasAlreadyInBackground = _isAppInBackground;
      _isAppInBackground = true;
      final isCurrentlyPlaying =
          _isMusicPlaying ||
          _activeTransitionTrack != null ||
          (!wasAlreadyInBackground && _bgmPlayer?.state == PlayerState.playing);
      _transitionToken++;
      _activeTransitionTrack = null;
      _cancelFadeTimer();
      if (_isPrincessScreamPlaying) {
        _screamToken++;
        _screamRestoreTimer?.cancel();
        _screamRestoreTimer = null;
        _isPrincessScreamPlaying = false;
        try {
          await _sfxPlayer?.stop();
        } catch (error) {
          debugPrint('Could not stop princess scream on background: $error');
        }
      }
      if (_resumeBgmAfterScream) {
        _resumeBgmAfterScream = false;
        _wasPlayingBeforeBackground = true;
      }
      if (isCurrentlyPlaying) {
        _wasPlayingBeforeBackground = true;
        _isMusicPlaying = false;
        try {
          await _bgmPlayer?.pause();
        } catch (error) {
          debugPrint('Could not pause background music: $error');
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      _isAppInBackground = false;
      if (_wasPlayingBeforeBackground) {
        _wasPlayingBeforeBackground = false;
        if (!musicEnabled || _bgmPlayer == null) return;
        final canResumeSameTrack =
            _loadedTrack == _currentTrack &&
            (_bgmPlayer!.state == PlayerState.paused || _hasLoadedMusicSource);
        if (canResumeSameTrack) {
          _isMusicPlaying = true;
          try {
            await _setBgmVolume(targetBgmVolume);
            await _bgmPlayer!.resume();
            if (_isDisposed || !musicEnabled) {
              _isMusicPlaying = false;
              await _bgmPlayer!.stop();
            } else if (_isAppInBackground) {
              _isMusicPlaying = false;
              _wasPlayingBeforeBackground = true;
              await _bgmPlayer!.pause();
            }
          } catch (error) {
            _isMusicPlaying = false;
            debugPrint('Could not resume background music: $error');
          }
        } else {
          await playTrack(_currentTrack, fade: false);
        }
      }
    }
  }

  Future<void> vibrate({
    int durationMs = defaultVibrationDurationMs,
    Future<void> Function()? fallback,
  }) async {
    if (!vibrationEnabled) return;
    try {
      await vibratorChannel.invokeMethod<void>('vibrate', {
        'duration': durationMs,
      });
    } on MissingPluginException {
      try {
        if (fallback != null) {
          await fallback();
        } else {
          await HapticFeedback.vibrate();
        }
      } catch (_) {}
    } catch (_) {
      try {
        if (fallback != null) {
          await fallback();
        } else {
          await HapticFeedback.vibrate();
        }
      } catch (_) {}
    }
  }

  void playVibrate({int durationMs = defaultVibrationDurationMs}) {
    vibrate(
      durationMs: durationMs,
      fallback: HapticFeedback.mediumImpact,
    );
  }

  void playTapVibrate() {
    vibrate(
      durationMs: tapVibrationDurationMs,
      fallback: HapticFeedback.selectionClick,
    );
  }

  /// Light haptic feedback throttled to at most once every ~120ms so 10x/20x/30x rapid-fire stays crisp.
  void playRapidFireHaptic() {
    if (!vibrationEnabled || _isRapidFireHapticOnCooldown) return;
    _isRapidFireHapticOnCooldown = true;
    _rapidFireHapticCooldownTimer?.cancel();
    _rapidFireHapticCooldownTimer = Timer(rapidFireHapticMinInterval, () {
      _isRapidFireHapticOnCooldown = false;
      _rapidFireHapticCooldownTimer = null;
    });
    vibrate(
      durationMs: rapidFireHapticDurationMs,
      fallback: HapticFeedback.lightImpact,
    );
  }

  bool _consumeRapidFireSfxSlot({required bool throttleSfx}) {
    if (_isDisposed || !soundEnabled) return false;
    if (!throttleSfx) return true;
    if (_isRapidFireSfxOnCooldown) return false;
    _isRapidFireSfxOnCooldown = true;
    _rapidFireSfxCooldownTimer?.cancel();
    _rapidFireSfxCooldownTimer = Timer(rapidFireSfxMinInterval, () {
      _isRapidFireSfxOnCooldown = false;
      _rapidFireSfxCooldownTimer = null;
    });
    return true;
  }

  void playWinVibrate() {
    vibrate(
      durationMs: winVibrationDurationMs,
      fallback: HapticFeedback.lightImpact,
    );
  }

  void playDefeatVibrate() {
    vibrate(
      durationMs: defeatVibrationDurationMs,
      fallback: HapticFeedback.heavyImpact,
    );
  }

  void playDrawVibrate() {
    vibrate(
      durationMs: drawVibrationDurationMs,
      fallback: HapticFeedback.mediumImpact,
    );
  }

  Future<void> playWin({bool vibrate = true, bool throttleSfx = false}) async {
    if (vibrate) {
      playWinVibrate();
    }
    if (!_consumeRapidFireSfxSlot(throttleSfx: throttleSfx)) return;
    onSfxTriggeredForTest?.call();
    try {
      await _sfxPlayer?.stop();
      await _sfxPlayer?.play(AssetSource('audio/attack.mid'));
    } catch (error) {
      debugPrint('Could not play win sound: $error');
    }
  }

  Future<void> playDefeat({bool vibrate = true, bool throttleSfx = false}) async {
    if (vibrate) {
      playDefeatVibrate();
    }
    if (!_consumeRapidFireSfxSlot(throttleSfx: throttleSfx)) return;
    onSfxTriggeredForTest?.call();
    try {
      await _sfxPlayer?.stop();
      await _sfxPlayer?.play(AssetSource('audio/defeat.mid'));
    } catch (error) {
      debugPrint('Could not play defeat sound: $error');
    }
  }

  Future<void> playDraw({bool vibrate = true, bool throttleSfx = false}) async {
    if (vibrate) {
      playDrawVibrate();
    }
    if (!_consumeRapidFireSfxSlot(throttleSfx: throttleSfx)) return;
    onSfxTriggeredForTest?.call();
    try {
      await _sfxPlayer?.stop();
      await _sfxPlayer?.play(AssetSource('audio/draw.mid'));
    } catch (error) {
      debugPrint('Could not play draw sound: $error');
    }
  }

  /// Plays a soft magical chime/transmutation audio effect when a comic cutscene opens.
  Future<void> playStoryChime() async {
    playTapVibrate();
    if (_isDisposed || !soundEnabled) return;
    try {
      await _sfxPlayer?.stop();
      await _sfxPlayer?.play(AssetSource('audio/chime.wav'));
    } catch (error) {
      debugPrint('Could not play story chime sound: $error');
    }
  }

  /// Plays light/medium haptic feedback and transmutation chime SFX on Royal Alchemy exchange.
  Future<void> playAlchemyTransmute() async {
    playWinVibrate();
    if (_isDisposed || !soundEnabled) return;
    try {
      await _sfxPlayer?.stop();
      await _sfxPlayer?.play(AssetSource('audio/chime.wav'));
    } catch (error) {
      debugPrint('Could not play alchemy transmute sound: $error');
    }
  }

  /// Plays haptic and soft chime feedback for Consagration upgrades,
  /// throttled to ~120ms intervals during continuous press-and-hold.
  Future<void> playConsagrationTick({bool throttle = false}) async {
    if (throttle) {
      playRapidFireHaptic();
    } else {
      playWinVibrate();
    }
    if (!_consumeRapidFireSfxSlot(throttleSfx: throttle)) return;
    onSfxTriggeredForTest?.call();
    try {
      await _sfxPlayer?.stop();
      await _sfxPlayer?.play(AssetSource('audio/chime.wav'));
    } catch (error) {
      debugPrint('Could not play consagration sound: $error');
    }
  }

  /// Plays the synthetic princess scream `.mid` once when the Week 1 scream warning appears.
  ///
  /// Temporarily pauses active/transitioning BGM so Android's native MIDI synthesizer
  /// does not drop voices across two simultaneous `.mid` files, then smoothly restores
  /// [currentTrack] (e.g. `worldMap`) once the scream completes or the dialog is dismissed.
  Future<void> playPrincessScream() async {
    playTapVibrate();
    if (_isDisposed || !soundEnabled || _isAppInBackground) return;
    onSfxTriggeredForTest?.call();

    final screamToken = ++_screamToken;
    _screamRestoreTimer?.cancel();
    _screamRestoreTimer = null;

    final shouldPauseBgm =
        musicEnabled &&
        (_isMusicPlaying ||
            _activeTransitionTrack != null ||
            _bgmPlayer?.state == PlayerState.playing);
    _resumeBgmAfterScream = _resumeBgmAfterScream || shouldPauseBgm;

    if (shouldPauseBgm) {
      _transitionToken++;
      _activeTransitionTrack = null;
      _cancelFadeTimer();
      _isMusicPlaying = false;
      try {
        await _bgmPlayer?.pause();
      } catch (error) {
        debugPrint('Could not pause BGM for princess scream: $error');
      }
    }

    if (_isDisposed ||
        !soundEnabled ||
        _isAppInBackground ||
        screamToken != _screamToken) {
      if (!_isDisposed &&
          !_isAppInBackground &&
          screamToken == _screamToken &&
          _resumeBgmAfterScream &&
          musicEnabled) {
        _resumeBgmAfterScream = false;
        await _restoreBgmWithSmoothFadeIn();
      }
      return;
    }

    try {
      await _sfxPlayer?.stop();
      await _sfxPlayer?.setReleaseMode(ReleaseMode.release);
      await _sfxPlayer?.setVolume(1.0);
      _isPrincessScreamPlaying = true;
      await _sfxPlayer?.play(AssetSource(princessScreamAssetPath));
    } catch (error) {
      _isPrincessScreamPlaying = false;
      debugPrint('Could not play princess scream sound: $error');
      if (_resumeBgmAfterScream &&
          !_isDisposed &&
          musicEnabled &&
          !_isAppInBackground) {
        _resumeBgmAfterScream = false;
        await _restoreBgmWithSmoothFadeIn();
      }
      return;
    }

    if (_isDisposed ||
        !soundEnabled ||
        _isAppInBackground ||
        screamToken != _screamToken) {
      _isPrincessScreamPlaying = false;
      try {
        await _sfxPlayer?.stop();
      } catch (_) {}
      if (_isAppInBackground && _resumeBgmAfterScream) {
        _resumeBgmAfterScream = false;
        _wasPlayingBeforeBackground = true;
      }
      return;
    }

    _screamRestoreTimer = Timer(_princessScreamDuration, () {
      unawaited(_finishPrincessScreamAndRestoreBgm(screamToken));
    });
  }

  /// Stops an active princess scream early (e.g. when the player dismisses the
  /// Week 1 scream warning pop-up or mutes sound) and smoothly resumes BGM if needed.
  Future<void> finishPrincessScreamAndRestoreBgm() async {
    if (!_isPrincessScreamPlaying && !_resumeBgmAfterScream) return;
    final token = ++_screamToken;
    await _finishPrincessScreamAndRestoreBgm(
      token,
      stopSfxIfPlaying: true,
    );
  }

  Future<void> _finishPrincessScreamAndRestoreBgm(
    int token, {
    bool stopSfxIfPlaying = false,
  }) async {
    if (token != _screamToken) return;
    _screamRestoreTimer?.cancel();
    _screamRestoreTimer = null;

    final wasPlayingScream = _isPrincessScreamPlaying;
    _isPrincessScreamPlaying = false;

    if (stopSfxIfPlaying && wasPlayingScream) {
      try {
        await _sfxPlayer?.stop();
      } catch (error) {
        debugPrint('Could not stop princess scream sound: $error');
      }
    }

    final shouldRestore = _resumeBgmAfterScream;
    _resumeBgmAfterScream = false;
    if (!shouldRestore || _isDisposed || !musicEnabled) {
      return;
    }
    if (_isAppInBackground) {
      _wasPlayingBeforeBackground = true;
      return;
    }
    await _restoreBgmWithSmoothFadeIn();
  }

  Future<void> _restoreBgmWithSmoothFadeIn() async {
    if (_isDisposed || !musicEnabled || _bgmPlayer == null) return;
    if (_isAppInBackground) {
      _wasPlayingBeforeBackground = true;
      return;
    }
    if (_isMusicPlaying &&
        _loadedTrack == _currentTrack &&
        _bgmPlayer!.state == PlayerState.playing) {
      return;
    }

    final canResumeSameTrack =
        _loadedTrack == _currentTrack &&
        (_bgmPlayer!.state == PlayerState.paused || _hasLoadedMusicSource);

    final token = ++_transitionToken;
    _cancelFadeTimer();
    _activeTransitionTrack = _currentTrack;
    _wasPlayingBeforeBackground = false;

    try {
      final shouldFade = _fadeDuration > Duration.zero;
      if (!canResumeSameTrack) {
        await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
        if (_shouldAbortTransition(token)) return;
        await _setBgmVolume(shouldFade ? 0.0 : targetBgmVolume);
        if (_shouldAbortTransition(token)) return;
        _isMusicPlaying = true;
        await _bgmPlayer!.play(AssetSource(_currentTrack.assetPath));
        _hasLoadedMusicSource = true;
        _loadedTrack = _currentTrack;
      } else {
        await _setBgmVolume(shouldFade ? 0.0 : targetBgmVolume);
        if (_shouldAbortTransition(token)) return;
        _isMusicPlaying = true;
        await _bgmPlayer!.resume();
      }

      if (_isDisposed || !musicEnabled) {
        _isMusicPlaying = false;
        await _bgmPlayer!.stop();
        return;
      }
      if (_isAppInBackground) {
        _isMusicPlaying = false;
        _wasPlayingBeforeBackground = true;
        await _bgmPlayer!.pause();
        return;
      }
      if (token != _transitionToken) return;

      if (shouldFade) {
        await _rampBgmVolume(
          from: 0.0,
          to: targetBgmVolume,
          duration: _fadeDuration,
          token: token,
        );
      }
    } catch (error) {
      if (token == _transitionToken) {
        _isMusicPlaying = false;
      }
      debugPrint('Could not restore background music after scream: $error');
    } finally {
      if (token == _transitionToken &&
          _activeTransitionTrack == _currentTrack) {
        _activeTransitionTrack = null;
      }
    }
  }

  /// Switches background music to [track] with a smooth fade-out / fade-in transition.
  ///
  /// - If [track] is already active and playing (or currently transitioning in),
  ///   keeps it playing seamlessly without restarting from bar 1.
  /// - Always updates [currentTrack] even if muted or backgrounded so unmuting
  ///   or foregrounding resumes the right track.
  Future<void> playTrack(BgmTrack track, {bool fade = true}) async {
    if (_isDisposed) return;

    final isAlreadyPlayingSameTrack =
        _currentTrack == track &&
        (_activeTransitionTrack == track ||
            (_loadedTrack == track &&
                _isMusicPlaying &&
                _bgmPlayer?.state == PlayerState.playing));

    _currentTrack = track;

    if (!musicEnabled) return;
    if (_isAppInBackground) {
      _wasPlayingBeforeBackground = true;
      return;
    }
    if (_isPrincessScreamPlaying) {
      _resumeBgmAfterScream = true;
      return;
    }
    if (_bgmPlayer == null) return;
    if (isAlreadyPlayingSameTrack) return;

    // If we were mid-fade-out from `track` and cancelled back to `track`,
    // keep the loaded source playing without restarting and restore volume.
    if (_loadedTrack == track &&
        _hasLoadedMusicSource &&
        _bgmPlayer!.state == PlayerState.playing) {
      final token = ++_transitionToken;
      _cancelFadeTimer();
      _activeTransitionTrack = track;
      _isMusicPlaying = true;
      _wasPlayingBeforeBackground = false;
      try {
        if (fade &&
            _fadeDuration > Duration.zero &&
            _currentBgmVolume < targetBgmVolume) {
          await _rampBgmVolume(
            from: _currentBgmVolume,
            to: targetBgmVolume,
            duration: _fadeDuration,
            token: token,
          );
        } else {
          await _setBgmVolume(targetBgmVolume);
        }
      } catch (error) {
        debugPrint('Could not restore background music volume: $error');
      } finally {
        if (token == _transitionToken && _activeTransitionTrack == track) {
          _activeTransitionTrack = null;
        }
      }
      return;
    }

    final shouldFade =
        fade &&
        _fadeDuration > Duration.zero &&
        (_isMusicPlaying || _bgmPlayer!.state == PlayerState.playing) &&
        _loadedTrack != null &&
        _loadedTrack != track;

    final token = ++_transitionToken;
    _cancelFadeTimer();
    _activeTransitionTrack = track;
    _wasPlayingBeforeBackground = false;

    try {
      if (shouldFade) {
        final fadeOutDone = await _rampBgmVolume(
          from: _currentBgmVolume,
          to: 0.0,
          duration: _fadeDuration,
          token: token,
        );
        if (!fadeOutDone) return;
      }

      if (_shouldAbortTransition(token)) return;

      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      if (_shouldAbortTransition(token)) return;

      if (shouldFade) {
        await _setBgmVolume(0.0);
      } else {
        await _setBgmVolume(targetBgmVolume);
      }
      if (_shouldAbortTransition(token)) return;

      _isMusicPlaying = true;
      await _bgmPlayer!.play(AssetSource(track.assetPath));
      _hasLoadedMusicSource = true;
      _loadedTrack = track;

      if (_isDisposed || !musicEnabled) {
        _isMusicPlaying = false;
        _wasPlayingBeforeBackground = false;
        _hasLoadedMusicSource = false;
        _loadedTrack = null;
        if (_activeTransitionTrack == track) {
          _activeTransitionTrack = null;
        }
        await _bgmPlayer!.stop();
        return;
      }
      if (_isAppInBackground) {
        _isMusicPlaying = false;
        _wasPlayingBeforeBackground = true;
        if (_activeTransitionTrack == track) {
          _activeTransitionTrack = null;
        }
        await _bgmPlayer!.pause();
        return;
      }
      if (token != _transitionToken) return;

      if (shouldFade) {
        await _rampBgmVolume(
          from: 0.0,
          to: targetBgmVolume,
          duration: _fadeDuration,
          token: token,
        );
      }
    } catch (error) {
      if (token == _transitionToken) {
        _isMusicPlaying = false;
        _activeTransitionTrack = null;
      }
      debugPrint('Could not play background music (${track.assetPath}): $error');
    } finally {
      if (token == _transitionToken && _activeTransitionTrack == track) {
        _activeTransitionTrack = null;
      }
    }
  }

  Future<void> startMusic() => playTrack(_currentTrack, fade: false);

  Future<void> stopMusic() async {
    final wasActive =
        _isMusicPlaying ||
        _hasLoadedMusicSource ||
        _activeTransitionTrack != null ||
        _bgmPlayer?.state == PlayerState.playing ||
        _bgmPlayer?.state == PlayerState.paused;
    _transitionToken++;
    _activeTransitionTrack = null;
    _cancelFadeTimer();
    _isMusicPlaying = false;
    _wasPlayingBeforeBackground = false;
    _resumeBgmAfterScream = false;
    _hasLoadedMusicSource = false;
    _loadedTrack = null;
    _currentBgmVolume = targetBgmVolume;
    if (!wasActive) return;
    try {
      await _bgmPlayer?.stop();
    } catch (error) {
      debugPrint('Could not stop background music: $error');
    }
  }

  Future<void> pauseMusic() async {
    _transitionToken++;
    _activeTransitionTrack = null;
    _cancelFadeTimer();
    _isMusicPlaying = false;
    _resumeBgmAfterScream = false;
    try {
      await _bgmPlayer?.pause();
    } catch (error) {
      debugPrint('Could not pause background music: $error');
    }
  }

  Future<void> resumeMusic() async {
    if (_isDisposed || !musicEnabled) return;
    if (_isAppInBackground) {
      _wasPlayingBeforeBackground = true;
      return;
    }
    if (_isPrincessScreamPlaying) {
      _resumeBgmAfterScream = true;
      return;
    }
    if (_bgmPlayer == null) return;
    if (_isMusicPlaying &&
        _loadedTrack == _currentTrack &&
        _bgmPlayer!.state == PlayerState.playing) {
      return;
    }
    try {
      final canResumeSameTrack =
          _loadedTrack == _currentTrack &&
          (_bgmPlayer!.state == PlayerState.paused || _hasLoadedMusicSource);
      if (canResumeSameTrack) {
        _isMusicPlaying = true;
        await _setBgmVolume(targetBgmVolume);
        await _bgmPlayer!.resume();
        if (_isDisposed || !musicEnabled) {
          _isMusicPlaying = false;
          await _bgmPlayer!.stop();
        } else if (_isAppInBackground) {
          _isMusicPlaying = false;
          _wasPlayingBeforeBackground = true;
          await _bgmPlayer!.pause();
        }
      } else {
        await playTrack(_currentTrack, fade: false);
      }
    } catch (error) {
      _isMusicPlaying = false;
      debugPrint('Could not resume background music: $error');
    }
  }

  void dispose() {
    _isDisposed = true;
    _transitionToken++;
    _activeTransitionTrack = null;
    _cancelFadeTimer();
    _screamToken++;
    _screamRestoreTimer?.cancel();
    _screamRestoreTimer = null;
    _isPrincessScreamPlaying = false;
    _resumeBgmAfterScream = false;
    if (_isObserverRegistered) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
      _isObserverRegistered = false;
    }
    _wasPlayingBeforeBackground = false;
    _isMusicPlaying = false;
    _hasLoadedMusicSource = false;
    _loadedTrack = null;
    _rapidFireHapticCooldownTimer?.cancel();
    _rapidFireHapticCooldownTimer = null;
    _isRapidFireHapticOnCooldown = false;
    _rapidFireSfxCooldownTimer?.cancel();
    _rapidFireSfxCooldownTimer = null;
    _isRapidFireSfxOnCooldown = false;
    _sfxPlayer?.dispose();
    _bgmPlayer?.dispose();
  }
}
