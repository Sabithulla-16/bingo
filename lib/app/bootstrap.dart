import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/supabase/supabase_service.dart';
import 'bingo_app.dart';

/// Initializes foundational dependencies and launches the application.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce vertical portrait orientation for mobile gameplay
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Supabase client
  await SupabaseService.initialize();

  runApp(const ProviderScope(child: BingoApp()));
}
