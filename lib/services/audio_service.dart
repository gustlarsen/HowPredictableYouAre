import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioService {
  final bool enabledInEnvironment;
  AudioPlayer? _bgmPlayer;
  AudioPlayer? _sfxPlayer;

  AudioService({this.enabledInEnvironment = true});

  AudioPlayer get _bgm => _bgmPlayer ??= AudioPlayer();
  AudioPlayer get _sfx => _sfxPlayer ??= AudioPlayer();

  /// Starts `Player1` looping background track (`Battle.mid`, fallback `Battle.wav`).
  /// In Kodular `.scm`, `Player1` has `Loop: True` and `Volume: 1` (low volume).
  Future<void> startBattleMusic() async {
    if (!enabledInEnvironment) return;
    try {
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(0.15);
      try {
        await _bgm.play(AssetSource('Battle.mid'));
      } catch (_) {
        await _bgm.play(AssetSource('Battle.wav'));
      }
    } catch (_) {}
  }

  Future<void> stopBattleMusic() async {
    if (!enabledInEnvironment) return;
    try {
      await _bgm.stop();
    } catch (_) {}
  }

  /// Plays `Player2` round sound effect (`attack.mid`, `defeat.mid`, or `draw.mid`).
  Future<void> playEffect(String midiFileName) async {
    if (!enabledInEnvironment) return;
    try {
      await _sfx.setReleaseMode(ReleaseMode.stop);
      await _sfx.setVolume(1.0);
      try {
        await _sfx.play(AssetSource(midiFileName));
      } catch (_) {
        final wavFallback = midiFileName.replaceAll('.mid', '.wav');
        await _sfx.play(AssetSource(wavFallback));
      }
    } catch (_) {}
  }

  /// Replicates `Player1.Vibrate(milliseconds)`:
  /// - 100ms on User win
  /// - 250ms on Draw
  /// - 500ms on PC win
  Future<void> vibrate(int milliseconds) async {
    if (!enabledInEnvironment) return;
    try {
      if (milliseconds <= 150) {
        await HapticFeedback.lightImpact();
      } else if (milliseconds <= 300) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.heavyImpact();
      }
      await HapticFeedback.vibrate();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _bgmPlayer?.dispose();
      await _sfxPlayer?.dispose();
    } catch (_) {}
  }
}

