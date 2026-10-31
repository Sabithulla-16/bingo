import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/errors/error_logger.dart';
import '../core/widgets/global_error_boundary.dart';
import '../data/supabase/supabase_service.dart';
import 'bingo_app.dart';

/// Initializes foundational dependencies, installs global error handlers,
/// and launches the application.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Global Flutter framework error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    ErrorLogger.logUnhandled(
      details.exception,
      details.stack ?? StackTrace.current,
      source: 'FlutterError',
    );
  };

  // 2. Global platform dispatcher asynchronous error handling
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    ErrorLogger.logUnhandled(error, stack, source: 'PlatformDispatcher');
    return true; // Prevents process crash
  };

  // 3. User-friendly widget crash fallback screen (never showing red crash screen)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return GlobalErrorBoundaryWidget(details: details);
  };

  // Enforce vertical portrait orientation for mobile gameplay
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Supabase client
  await SupabaseService.initialize();

  runApp(const ProviderScope(child: BingoApp()));
}
