import 'package:flutter_test/flutter_test.dart';
import 'package:fsegn_study_groups/core/env/app_config.dart';
import 'package:fsegn_study_groups/data/services/supabase_service.dart';

void main() {
  test('App loads configuration, selects Live Supabase mode, and reaches backend', () async {
    // 1. Initialize environment
    await AppConfig.initialize();

    // 2. Verify keys are loaded and non-placeholder
    expect(
      AppConfig.hasValidSupabaseKeys,
      isTrue,
      reason: 'AppConfig should detect valid Supabase configuration in .env',
    );

    // 3. Verify Live Supabase mode is selected (NOT demo mode)
    expect(
      AppConfig.isDemoMode,
      isFalse,
      reason: 'App should select Live Supabase mode, not demo mode',
    );

    // 4. Test backend reachability without printing keys or modifying database
    await SupabaseService.initialize();
    expect(SupabaseService.isInitialized, isTrue);

    // Read-only query to check connectivity (does NOT create users or groups)
    final response = await SupabaseService.client
        .from('study_groups')
        .select('id, subject, topic')
        .limit(1);

    expect(response, isA<List<dynamic>>());
  });
}
