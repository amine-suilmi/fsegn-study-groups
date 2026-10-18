import 'package:flutter_test/flutter_test.dart';
import 'package:fsegn_study_groups/main.dart';
import 'package:fsegn_study_groups/data/repositories/auth_repository.dart';

void main() {
  testWidgets('FSEGN Study Groups Smoke Test - Renders App Successfully', (
    WidgetTester tester,
  ) async {
    await AuthRepository.instance.initialize();
    await tester.pumpWidget(const FsegnStudyGroupsApp());
    await tester.pump();

    // Verify app renders with title and navigation components
    expect(find.text('FSEGN Study Groups'), findsOneWidget);
  });
}
