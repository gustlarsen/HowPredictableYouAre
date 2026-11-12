import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static const MethodChannel vibratorChannel = MethodChannel(
    'com.gustlarsen.howpredictable/vibrator',
  );

  static const int winVibrationDurationMs = 100;
  static const int drawVibrationDurationMs = 250;
  static const int defeatVibrationDurationMs = 500;
  static const int defaultVibrationDurationMs = 100;
  static const int tapVibrationDurationMs = 40;

  AudioPlayer? _sfxPlayer;
  AudioPlayer? _bgmPlayer;

  bool soundEnabled = true;
  bool musicEnabled = true;
  bool vibrationEnabled = true;

  Future<void> init() async {
    _sfxPlayer ??= AudioPlayer();
    _bgmPlayer ??= AudioPlayer();
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

  Future<void> playWin() async {
    playWinVibrate();
    if (!soundEnabled) return;
    try {
      await _sfxPlayer?.stop();
      await _sfxPlayer?.play(AssetSource('audio/attack.mid'));
    } catch (error) {
      debugPrint('Could not play win sound: $error');
    }
  }

  Future<void> playDefeat() async {
    playDefeatVibrate();
    if (!soundEnabled) return;
    try {
      await _sfxPlayer?.stop();
      await _sfxPlayer?.play(AssetSource('audio/defeat.mid'));
    } catch (error) {
      debugPrint('Could not play defeat sound: $error');
    }
  }

  Future<void> playDraw() async {
    playDrawVibrate();
    if (!soundEnabled) return;
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
    if (!soundEnabled) return;
    try {
      await _sfxPlayer?.stop();
      await _sfxPlayer?.play(AssetSource('audio/chime.wav'));
    } catch (error) {
      debugPrint('Could not play story chime sound: $error');
    }
  }

  Future<void> startMusic() async {
    if (!musicEnabled) return;
    try {
      await _bgmPlayer?.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer?.play(AssetSource('audio/battle.mid'));
    } catch (error) {
      debugPrint('Could not play background music: $error');
    }
  }

  Future<void> stopMusic() async {
    try {
      await _bgmPlayer?.stop();
    } on Exception catch (error) {
      debugPrint('Could not stop background music: $error');
    }
  }

  Future<void> pauseMusic() async {
    try {
      await _bgmPlayer?.pause();
    } on Exception catch (error) {
      debugPrint('Could not pause background music: $error');
    }
  }

  Future<void> resumeMusic() async {
    if (!musicEnabled) return;
    try {
      if (_bgmPlayer?.state == PlayerState.paused) {
        await _bgmPlayer?.resume();
      } else if (_bgmPlayer?.state != PlayerState.playing) {
        await startMusic();
      }
    } on Exception catch (error) {
      debugPrint('Could not resume background music: $error');
    }
  }

  void dispose() {
    _sfxPlayer?.dispose();
    _bgmPlayer?.dispose();
  }
}
