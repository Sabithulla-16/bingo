import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supabase/supabase_provider.dart';

/// Centralized service managing tactile haptic feedback and real audio playback,
/// adhering to the user's active audio and haptics preferences.
class FeedbackService {
  final Ref _ref;
  final AudioPlayer _audioPlayer;

  FeedbackService(this._ref, {AudioPlayer? audioPlayer})
    : _audioPlayer = audioPlayer ?? AudioPlayer() {
    try {
      _audioPlayer.setReleaseMode(ReleaseMode.stop).catchError((_) {});
    } catch (_) {}
  }

  bool get _hapticsEnabled =>
      _ref.read(playerPreferencesProvider).hapticsEnabled;

  bool get _soundsEnabled =>
      _ref.read(playerPreferencesProvider).soundEffectsEnabled;

  /// Internal audio player invoking real WAV sound assets with fallback resilience.
  Future<void> _playSound(String assetFileName) async {
    if (!_soundsEnabled) return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/$assetFileName'));
    } catch (_) {
      // Fallback to platform click in headless/test environments
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Triggered on subtle interactions like cell selection, button tap, or tile swap.
  Future<void> lightTap() async {
    if (_hapticsEnabled) {
      await HapticFeedback.lightImpact();
    }
    await _playSound('tap.wav');
  }

  /// Triggered on primary gameplay actions such as calling an uncalled number.
  Future<void> callNumber() async {
    if (_hapticsEnabled) {
      await HapticFeedback.mediumImpact();
    }
    await _playSound('call.wav');
  }

  /// Triggered when a player claims an achieved B-I-N-G-O line or daubs a completed row.
  Future<void> claimLine() async {
    if (_hapticsEnabled) {
      await HapticFeedback.heavyImpact();
    }
    await _playSound('line.wav');
  }

  /// Celebratory vibration and fanfare alert when 5 lines are struck and match is won.
  Future<void> victoryBingo() async {
    if (_hapticsEnabled) {
      await HapticFeedback.vibrate();
    }
    await _playSound('bingo.wav');
  }

  /// Error or invalid interaction warning (e.g. attempting to tap an already called cell).
  Future<void> errorAlert() async {
    if (_hapticsEnabled) {
      await HapticFeedback.selectionClick();
    }
  }

  void dispose() {
    try {
      _audioPlayer.dispose();
    } catch (_) {}
  }
}

/// Riverpod provider for the global feedback service.
final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  final service = FeedbackService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
