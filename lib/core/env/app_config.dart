import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application configuration and environment variable loader.
/// Automatically detects if valid Supabase credentials are present,
/// and falls back gracefully to Local Demo Mode when unconfigured.
class AppConfig {
  /// For web, return to the exact page hosting this app (including a GitHub
  /// Pages repository path). Native apps use the registered deep link.
  static String get authRedirectUrl {
    if (kIsWeb) {
      return Uri.base.origin + Uri.base.path;
    }
    return 'tn.ucar.fsegnstudygroups://login-callback';
  }

  static String? _supabaseUrl;
  static String? _supabaseAnonKey;
  static bool _isLoaded = false;

  static Future<void> initialize() async {
    if (_isLoaded) return;
    try {
      await dotenv.load(fileName: '.env');
      _supabaseUrl =
          (dotenv.env['SUPABASE_URL'] ?? dotenv.env['SUPABASE_PROJECT_URL'])
              ?.trim();
      _supabaseAnonKey = (dotenv.env['SUPABASE_ANON_KEY'] ??
              dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
              dotenv.env['SUPABASE_KEY'])
          ?.trim();
    } catch (_) {
      // .env missing or failed to load; default to Demo Mode
      _supabaseUrl = null;
      _supabaseAnonKey = null;
    }
    _isLoaded = true;
  }

  static String get supabaseUrl => _supabaseUrl ?? '';
  static String get supabaseAnonKey => _supabaseAnonKey ?? '';

  /// Returns true if valid live Supabase credentials are configured.
  static bool get hasValidSupabaseKeys {
    if (_supabaseUrl == null || _supabaseAnonKey == null) return false;
    if (_supabaseUrl!.isEmpty || _supabaseAnonKey!.isEmpty) return false;
    if (_supabaseUrl!.contains('your-project-ref') ||
        _supabaseAnonKey!.contains('your-anon-public-key') ||
        _supabaseAnonKey!.contains('your-publishable-key')) {
      return false;
    }
    return _supabaseUrl!.startsWith('http://') ||
        _supabaseUrl!.startsWith('https://');
  }

  /// True when running in offline/demo mode without live Supabase.
  static bool get isDemoMode => !hasValidSupabaseKeys;

  /// Supabase Free Tier Documentation Notice (Directive #5).
  static const String freeTierNotice =
      'Supabase Free Tier: Ongoing cost is \$0. Projects pause after 7 days of '
      'inactivity and can be resumed manually in your Supabase dashboard.';
}
