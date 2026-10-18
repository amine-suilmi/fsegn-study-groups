import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/env/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/services/supabase_service.dart';
import 'data/repositories/auth_repository.dart';
import 'ui/features/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize French date formatting symbols for the student calendar.
  await initializeDateFormatting('fr_FR', null);

  // Load environment and Supabase session before the auth gate is built.
  await AppConfig.initialize();
  await SupabaseService.initialize();

  // Render the app before making the optional profile request to Supabase.
  runApp(const FsegnStudyGroupsApp());
  unawaited(
    AuthRepository.instance.initialize().catchError((Object error) {
      debugPrint('Initial profile loading failed: $error');
    }),
  );
}

class FsegnStudyGroupsApp extends StatelessWidget {
  const FsegnStudyGroupsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FSEGN Study Groups',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}
