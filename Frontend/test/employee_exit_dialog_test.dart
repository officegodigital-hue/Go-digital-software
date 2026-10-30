import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:godigital_portal/hrms_admin/features/employees/employee_exit_dialog.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({'auth_token': 'test-token'}),
  );
  Future<void> open(WidgetTester tester, {bool inactive = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showEmployeeExitDialog(
                context,
                7,
                inactive: inactive,
                name: 'Employee',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('exit automatically uses yesterday and requires a reason', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Choose last working date *'), findsNothing);
    expect(find.textContaining('(yesterday, India time)'), findsOneWidget);
    await tester.tap(find.text('Preview exit'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an exit reason.'), findsOneWidget);
    expect(find.text('Confirm exit'), findsNothing);
  });
  testWidgets('reactivation uses today without choosing or sending a date', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });
    await http.runWithClient(() async {
      await open(tester, inactive: true);
      expect(find.text('Choose employment start date *'), findsNothing);
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.textContaining('(today, India time)'), findsOneWidget);
      await tester.tap(find.text('Confirm reactivation'));
      await tester.pumpAndSettle();
      expect(requests.single.url.path, endsWith('/employees/7/reactivate'));
      expect(jsonDecode(requests.single.body), isEmpty);
      expect(find.text('Reactivate Employee'), findsNothing);
    }, () => client);
  });
  testWidgets(
    'preview shows salary without task handover, and conflicts block confirmation',
    (tester) async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'conflicts': [
                {
                  'source': 'attendance_records',
                  'id': 9,
                  'date': '2026-10-29',
                  'resolved': false,
                },
              ],
              'pending': [
                {'source': 'task_assignments', 'id': 12},
              ],
              'salary': [
                {
                  'periodStart': '2026-10-01',
                  'periodEnd': '2026-10-31',
                  'eligibleWorkingDays': 15,
                  'workingDays': 25,
                  'netPayLabel': '₹18,000',
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      await http.runWithClient(() async {
        await open(tester);
        await tester.enterText(find.byType(TextField), 'Left the office');
        await tester.tap(find.text('Preview exit'));
        await tester.pumpAndSettle();
        expect(
          jsonDecode(requests.single.body).containsKey('lastWorkingDate'),
          isFalse,
        );
        expect(requests.single.url.path, endsWith('/employees/7/exit-preview'));
        expect(requests.single.headers['Authorization'], 'Bearer test-token');
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.textContaining('Pending responsibilities'), findsNothing);
        expect(find.textContaining('Handover'), findsNothing);
        expect(find.textContaining('₹18,000'), findsOneWidget);
        final confirm = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Confirm exit'),
        );
        expect(confirm.onPressed, isNull);
        expect(find.text('Resolve'), findsOneWidget);
      }, () => client);
    },
  );
}
