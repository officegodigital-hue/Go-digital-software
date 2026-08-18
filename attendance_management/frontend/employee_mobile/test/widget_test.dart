import 'package:employee_mobile/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Employee login screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const AttendanceApp());

    expect(find.text('Welcome back'), findsOneWidget);

    expect(find.text('Sign In'), findsOneWidget);

    expect(find.text('Email Address'), findsOneWidget);
  });
}
