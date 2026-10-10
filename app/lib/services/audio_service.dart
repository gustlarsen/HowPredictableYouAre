import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioService {
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();

  bool soundEnabled = true;
  bool vibrationEnabled = true;

  Future<void> init() async {
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    } catch (_) {}
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
      await _sfxPlayer.play(AssetSource('audio/attack.mid'));
    } catch (_) {
      // In environments with no midi synth, haptic feedback was provided
    }
  }

  Future<void> playDefeat() async {
    playVibrate();
    if (!soundEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/defeat.mid'));
    } catch (_) {
      // Graceful fallback
    }
  }

  Future<void> playDraw() async {
    playVibrate();
    if (!soundEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/draw.mid'));
    } catch (_) {
      // Graceful fallback
    }
  }

  Future<void> startMusic() async {
    if (!soundEnabled) return;
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource('audio/Battle.mid'));
    } catch (_) {
      // Graceful fallback
    }
  }

  Future<void> stopMusic() async {
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  Future<void> pauseMusic() async {
    try {
      await _bgmPlayer.pause();
    } catch (_) {}
  }

  Future<void> resumeMusic() async {
    if (!soundEnabled) return;
    try {
      if (_bgmPlayer.state == PlayerState.paused) {
        await _bgmPlayer.resume();
      } else if (_bgmPlayer.state != PlayerState.playing) {
        await startMusic();
      }
    } catch (_) {}
  }

  void dispose() {
    _sfxPlayer.dispose();
    _bgmPlayer.dispose();
  }
}
