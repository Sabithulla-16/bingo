import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supabase/supabase_provider.dart';

/// Centralized service managing tactile haptic feedback and sound triggers,
/// adhering to the user's active audio and haptics preferences.
class FeedbackService {
  final Ref _ref;

  FeedbackService(this._ref);

  bool get _hapticsEnabled =>
      _ref.read(playerPreferencesProvider).hapticsEnabled;

  bool get _soundsEnabled =>
      _ref.read(playerPreferencesProvider).soundEffectsEnabled;

  /// Triggered on subtle interactions like cell selection, button tap, or tile swap.
  Future<void> lightTap() async {
    if (_hapticsEnabled) {
      await HapticFeedback.lightImpact();
    }
    if (_soundsEnabled) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  /// Triggered on primary gameplay actions such as calling an uncalled number.
  Future<void> callNumber() async {
    if (_hapticsEnabled) {
      await HapticFeedback.mediumImpact();
    }
    if (_soundsEnabled) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  /// Triggered when a player claims an achieved B-I-N-G-O line or daubs a completed row.
  Future<void> claimLine() async {
    if (_hapticsEnabled) {
      await HapticFeedback.heavyImpact();
    }
    if (_soundsEnabled) {
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  /// Celebratory vibration and alert when 5 lines are struck and match is won.
  Future<void> victoryBingo() async {
    if (_hapticsEnabled) {
      await HapticFeedback.vibrate();
    }
    if (_soundsEnabled) {
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  /// Error or invalid interaction warning (e.g. attempting to tap an already called cell).
  Future<void> errorAlert() async {
    if (_hapticsEnabled) {
      await HapticFeedback.selectionClick();
    }
  }
}

/// Riverpod provider for the global feedback service.
final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService(ref);
});
