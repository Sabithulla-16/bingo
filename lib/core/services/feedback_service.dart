import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supabase/supabase_provider.dart';
import '../../features/store/data/store_repository.dart';

/// Centralized service managing tactile haptic feedback and real audio playback,
/// adhering to the user's active audio and haptics preferences.
class FeedbackService {
  final Ref _ref;
  final AudioPlayer _sfxPlayer;
  final AudioPlayer _victoryPlayer;
  DateTime? _lastVictoryPlayedAt;

  FeedbackService(
    this._ref, {
    AudioPlayer? audioPlayer,
    AudioPlayer? victoryPlayer,
  }) : _sfxPlayer = audioPlayer ?? AudioPlayer(),
       _victoryPlayer = victoryPlayer ?? AudioPlayer() {
    try {
      _sfxPlayer.setReleaseMode(ReleaseMode.stop).catchError((_) {});
      _victoryPlayer.setReleaseMode(ReleaseMode.stop).catchError((_) {});
    } catch (_) {}
  }

  bool get _hapticsEnabled =>
      _ref.read(playerPreferencesProvider).hapticsEnabled;

  bool get _soundsEnabled =>
      _ref.read(playerPreferencesProvider).soundEffectsEnabled;

  String get _soundPackKey {
    try {
      return _ref.read(playerCustomizationProvider).soundPackKey;
    } catch (_) {
      return 'classic';
    }
  }

  @visibleForTesting
  DateTime? get lastVictoryPlayedAt => _lastVictoryPlayedAt;

  /// Internal audio player invoking real WAV sound assets with fallback resilience.
  Future<void> _playSound(String assetFileName, {AudioPlayer? player}) async {
    if (!_soundsEnabled) return;
    final activePlayer = player ?? _sfxPlayer;
    try {
      await activePlayer.stop();
      await activePlayer.play(AssetSource('audio/$assetFileName'));
    } catch (_) {
      // Fallback to platform click in headless/test environments
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Triggered on subtle interactions like cell selection, button tap, or tile swap.
  /// Uses the preserved sound asset `tap.wav`.
  Future<void> lightTap() async {
    if (_hapticsEnabled) {
      await HapticFeedback.lightImpact();
    }
    await _playSound('tap.wav');
  }

  /// Triggered on primary gameplay actions such as calling an uncalled number.
  /// Uses the equipped sound pack asset for human and bot turns.
  Future<void> callNumber() async {
    if (_hapticsEnabled) {
      await HapticFeedback.mediumImpact();
    }
    final pack = _soundPackKey;
    if (pack == 'arcade' || pack == 'celebration') {
      await _playSound('number_call.wav');
    } else {
      await _playSound('call.wav');
    }
  }

  /// Triggered when a player claims an achieved B-I-N-G-O line or daubs a completed row.
  /// Uses the equipped sound pack asset for human and bot line claims.
  Future<void> claimLine() async {
    if (_hapticsEnabled) {
      await HapticFeedback.heavyImpact();
    }
    final pack = _soundPackKey;
    if (pack == 'arcade' || pack == 'celebration') {
      await _playSound('line_strike.wav');
    } else {
      await _playSound('line.wav');
    }
  }

  /// Celebratory vibration and upgraded fanfare alert when 5 lines are struck and match is won.
  /// Plays equipped victory sound via a dedicated player to prevent overlap or interruption.
  /// Protected against duplicate triggers from repeated network events.
  Future<void> victoryBingo() async {
    final now = DateTime.now();
    if (_lastVictoryPlayedAt != null &&
        now.difference(_lastVictoryPlayedAt!) < const Duration(seconds: 4)) {
      // Prevent duplicate playback from repeated network/state events
      return;
    }
    _lastVictoryPlayedAt = now;

    if (_hapticsEnabled) {
      await HapticFeedback.vibrate();
    }
    final pack = _soundPackKey;
    if (pack == 'celebration' || pack == 'arcade') {
      await _playSound('bingo_victory.wav', player: _victoryPlayer);
    } else {
      await _playSound('bingo.wav', player: _victoryPlayer);
    }
  }

  /// Standalone victory announcement voice cue (`bingo_voice.wav`).
  /// Maintained as a separate voice cue without playing simultaneously with victory.
  Future<void> bingoVoice() async {
    await _playSound('bingo_voice.wav', player: _victoryPlayer);
  }

  /// Convenience aliases
  Future<void> celebration() => victoryBingo();
  Future<void> victory() => victoryBingo();
  Future<void> lineStrike() => claimLine();

  /// Error or invalid interaction warning (e.g. attempting to tap an already called cell).
  Future<void> errorAlert() async {
    if (_hapticsEnabled) {
      await HapticFeedback.selectionClick();
    }
  }

  void dispose() {
    try {
      _sfxPlayer.dispose();
      _victoryPlayer.dispose();
    } catch (_) {}
  }
}

/// Riverpod provider for the global feedback service.
final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  final service = FeedbackService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
