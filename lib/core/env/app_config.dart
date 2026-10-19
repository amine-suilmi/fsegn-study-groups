import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application configuration and environment variable loader.
/// Automatically detects if valid Supabase credentials are present,
/// and falls back gracefully to Local Demo Mode when unconfigured.
class AppConfig {
  /// Android builds inject these at compile time so the values are available
  /// in release APKs even if the dotenv asset is not loaded by the platform.
  static const _buildSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _buildSupabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

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

    Map<String, String> dotenvValues = const {};
    try {
      await dotenv.load(fileName: '.env');
      dotenvValues = dotenv.env;
    } catch (_) {
      // The dotenv asset is optional when credentials are injected at build time.
    }

    final dotenvUrl =
        dotenvValues['SUPABASE_URL'] ?? dotenvValues['SUPABASE_PROJECT_URL'];
    final dotenvKey = dotenvValues['SUPABASE_ANON_KEY'] ??
        dotenvValues['SUPABASE_PUBLISHABLE_KEY'] ??
        dotenvValues['SUPABASE_KEY'];

    _supabaseUrl = _cleanValue(
      _buildSupabaseUrl.isNotEmpty ? _buildSupabaseUrl : dotenvUrl,
      const ['SUPABASE_URL', 'SUPABASE_PROJECT_URL'],
    );
    _supabaseAnonKey = _cleanValue(
      _buildSupabaseAnonKey.isNotEmpty ? _buildSupabaseAnonKey : dotenvKey,
      const [
        'SUPABASE_ANON_KEY',
        'SUPABASE_PUBLISHABLE_KEY',
        'SUPABASE_KEY',
      ],
    );

    _isLoaded = true;
  }

  /// Accept both a raw value and common copied forms like
  /// SUPABASE_URL=https://... or "https://...".
  static String? _cleanValue(String? value, List<String> variableNames) {
    if (value == null) return null;
    var cleaned = value.trim();

    for (final variableName in variableNames) {
      final prefix = '$variableName=';
      if (cleaned.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length).trim();
        break;
      }
    }

    if (cleaned.length >= 2) {
      final first = cleaned[0];
      final last = cleaned[cleaned.length - 1];
      if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
        cleaned = cleaned.substring(1, cleaned.length - 1).trim();
      }
    }

    return cleaned.isEmpty ? null : cleaned;
  }

  static String get supabaseUrl => _supabaseUrl ?? '';
  static String get supabaseAnonKey => _supabaseAnonKey ?? '';

  /// Returns true if valid Supabase credentials are configured.
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
