import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service responsible for verifying real network and backend reachability.
class ConnectivityService {
  final Future<bool> Function()? _customChecker;

  const ConnectivityService([this._customChecker]);

  /// Pings reliable hostnames to verify real internet connectivity.
  Future<bool> isConnected() async {
    final customChecker = _customChecker;
    if (customChecker != null) {
      return customChecker();
    }

    // Default to true during unit/widget tests unless explicitly overridden
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }

    try {
      final result = await InternetAddress.lookup(
        'supabase.co',
      ).timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

/// Global provider for network connectivity checking.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return const ConnectivityService();
});
