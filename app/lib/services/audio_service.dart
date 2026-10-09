import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioService {
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();

  bool soundEnabled = true;
  bool vibrationEnabled = true;

  Future<void> init() async {
    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
  }

  void playVibrate() {
    if (vibrationEnabled) {
      HapticFeedback.mediumImpact();
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
    if (vibrationEnabled) {
      HapticFeedback.lightImpact();
    }
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

  void dispose() {
    _sfxPlayer.dispose();
    _bgmPlayer.dispose();
  }
}
