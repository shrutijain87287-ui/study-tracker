import 'package:flutter_test/flutter_test.dart';
import 'package:ca_inter_tracker/main.dart';

void main() {
  testWidgets('StudyTrackerApp launches smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const StudyTrackerApp());
    expect(find.byType(StudyTrackerApp), findsOneWidget);
  });
}
