import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/env/app_config.dart';

/// Service managing the Supabase client connection.
class SupabaseService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    if (AppConfig.hasValidSupabaseKeys) {
      try {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          publishableKey: AppConfig.supabaseAnonKey,
        );
        _initialized = true;
      } catch (e) {
        // If live initialization fails (e.g. invalid URL formatting), log and remain uninitialized
        _initialized = false;
      }
    }
  }

  static bool get isInitialized => _initialized;

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'Supabase is not initialized. Running in Local Demo Mode.',
      );
    }
    return Supabase.instance.client;
  }
}
