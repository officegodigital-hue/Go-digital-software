import 'package:admin_web/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Admin dashboard loads successfully',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const AdminWebApp(),
      );

      await tester.pump();

      expect(
        find.text('Dashboard Overview'),
        findsOneWidget,
      );

      expect(
        find.text('Attendance Tracker'),
        findsOneWidget,
      );
    },
  );
}     