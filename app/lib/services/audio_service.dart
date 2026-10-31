import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  AudioPlayer? _sfxPlayer;
  AudioPlayer? _bgmPlayer;

  bool soundEnabled = true;
  bool musicEnabled = true;
  bool vibrationEnabled = true;

  Future<void> init() async {
    _sfxPlayer ??= AudioPlayer();
    _bgmPlayer ??= AudioPlayer();
    try {
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer!.setVolume(0.55);
    } on Exception catch (error) {
      debugPrint('Could not initialize audio: $error');
    }
  }

  void playVibrate() {
    if (vibrationEnabled) {
      HapticFeedback.vibrate();
    }
  }

  Future<void> playWin() async {
    playVibrate();
    if (!soundEnabled) return;
    try {
      await _sfxPlayer?.play(AssetSource('audio/attack.wav'));
    } on Exception catch (error) {
      debugPrint('Could not play win sound: $error');
    }
  }

  Future<void> playDefeat() async {
    playVibrate();
    if (!soundEnabled) return;
    try {
      await _sfxPlayer?.play(AssetSource('audio/defeat.wav'));
    } on Exception catch (error) {
      debugPrint('Could not play defeat sound: $error');
    }
  }

  Future<void> playDraw() async {
    playVibrate();
    if (!soundEnabled) return;
    try {
      await _sfxPlayer?.play(AssetSource('audio/draw.wav'));
    } on Exception catch (error) {
      debugPrint('Could not play draw sound: $error');
    }
  }

  Future<void> startMusic() async {
    if (!musicEnabled) return;
    try {
      await _bgmPlayer?.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer?.play(AssetSource('audio/battle.wav'));
    } on Exception catch (error) {
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
