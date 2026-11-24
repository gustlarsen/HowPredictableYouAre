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

  AudioPlayerClient? _sfxPlayer;
  AudioPlayerClient? _bgmPlayer;
  bool _isObserverRegistered = false;
  bool _isDisposed = false;
  bool _isAppInBackground = false;
  bool _isMusicPlaying = false;
  bool _hasLoadedMusicSource = false;
  bool _wasPlayingBeforeBackground = false;
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

  bool soundEnabled = true;
  bool _musicEnabled = true;
  bool vibrationEnabled = true;

  bool get musicEnabled => _musicEnabled;
  set musicEnabled(bool value) {
    _musicEnabled = value;
    if (!value) {
      _wasPlayingBeforeBackground = false;
    }
  }

  AudioService({
    AudioPlayerClient? sfxPlayer,
    AudioPlayerClient? bgmPlayer,
  }) : _sfxPlayer = sfxPlayer,
       _bgmPlayer = bgmPlayer;

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
      await _bgmPlayer!.setVolume(0.55);
      await _sfxPlayer!.setVolume(1.0);
    } catch (error) {
      debugPrint('Could not initialize audio: $error');
    }
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
          (!wasAlreadyInBackground && _bgmPlayer?.state == PlayerState.playing);
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
        if (_bgmPlayer!.state == PlayerState.paused || _hasLoadedMusicSource) {
          _isMusicPlaying = true;
          try {
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
          await startMusic();
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

  Future<void> startMusic() async {
    if (_isDisposed || !musicEnabled) return;
    if (_isAppInBackground) {
      _wasPlayingBeforeBackground = true;
      return;
    }
    if (_bgmPlayer == null) return;
    if (_isMusicPlaying && _bgmPlayer!.state == PlayerState.playing) return;
    _wasPlayingBeforeBackground = false;
    _isMusicPlaying = true;
    try {
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      if (_isDisposed || !musicEnabled) {
        _isMusicPlaying = false;
        return;
      }
      if (_isAppInBackground) {
        _isMusicPlaying = false;
        _wasPlayingBeforeBackground = true;
        return;
      }
      await _bgmPlayer!.play(AssetSource('audio/battle.mid'));
      _hasLoadedMusicSource = true;
      if (_isDisposed || !musicEnabled) {
        _isMusicPlaying = false;
        _wasPlayingBeforeBackground = false;
        _hasLoadedMusicSource = false;
        await _bgmPlayer!.stop();
      } else if (_isAppInBackground) {
        _isMusicPlaying = false;
        _wasPlayingBeforeBackground = true;
        await _bgmPlayer!.pause();
      }
    } catch (error) {
      _isMusicPlaying = false;
      debugPrint('Could not play background music: $error');
    }
  }

  Future<void> stopMusic() async {
    final wasActive =
        _isMusicPlaying ||
        _hasLoadedMusicSource ||
        _bgmPlayer?.state == PlayerState.playing ||
        _bgmPlayer?.state == PlayerState.paused;
    _isMusicPlaying = false;
    _wasPlayingBeforeBackground = false;
    _hasLoadedMusicSource = false;
    if (!wasActive) return;
    try {
      await _bgmPlayer?.stop();
    } catch (error) {
      debugPrint('Could not stop background music: $error');
    }
  }

  Future<void> pauseMusic() async {
    _isMusicPlaying = false;
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
    if (_bgmPlayer == null) return;
    if (_isMusicPlaying && _bgmPlayer!.state == PlayerState.playing) return;
    try {
      if (_bgmPlayer!.state == PlayerState.paused || _hasLoadedMusicSource) {
        _isMusicPlaying = true;
        await _bgmPlayer!.resume();
        if (_isDisposed || !musicEnabled) {
          _isMusicPlaying = false;
          await _bgmPlayer!.stop();
        } else if (_isAppInBackground) {
          _isMusicPlaying = false;
          _wasPlayingBeforeBackground = true;
          await _bgmPlayer!.pause();
        }
      } else if (_bgmPlayer!.state != PlayerState.playing) {
        await startMusic();
      }
    } catch (error) {
      _isMusicPlaying = false;
      debugPrint('Could not resume background music: $error');
    }
  }

  void dispose() {
    _isDisposed = true;
    if (_isObserverRegistered) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
      _isObserverRegistered = false;
    }
    _wasPlayingBeforeBackground = false;
    _isMusicPlaying = false;
    _hasLoadedMusicSource = false;
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
