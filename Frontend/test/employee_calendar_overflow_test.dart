import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:godigital_portal/hrms_employee/pages/attendance_page.dart';
import 'package:godigital_portal/services/auth_service.dart';

void main() {
  testWidgets('calendar status and full check-in time fit without changing cell dimensions', (tester) async {
    SharedPreferences.setMockInitialValues({'auth_token': 'test'});
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => AuthService(),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(.5)), child: child!,
          ),
          home: const EmployeeAttendancePage(),
        ),
      ));
      await tester.pumpAndSettle();
      final marked = find.byWidgetPredicate((w) =>
          w.runtimeType.toString() == '_CalendarDay' &&
          ['P', 'LT', 'A'].contains((w as dynamic).status));
      expect(marked, findsNWidgets(3));
      final cells = marked.evaluate().map((e) => e.widget).toList();
      expect(tester.takeException(), isNull);
      for (final width in [320.0, 375.0, 430.0]) {
        tester.view.physicalSize = Size(width, 1000);
        for (final scale in [1.0, 1.3, 1.5]) {
          await tester.pumpWidget(MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!,
            ),
            home: Scaffold(body: SizedBox(width: width - 64,
              child: GridView.count(crossAxisCount: 7, childAspectRatio: .65,
                shrinkWrap: true, children: cells),
            )),
          ));
          await tester.pumpAndSettle();
          for (var i = 0; i < cells.length; i++) {
            final size = tester.getSize(marked.at(i));
            expect(size.width / size.height, closeTo(.65, .001));
          }
          expect(find.text('08:01 AM'), findsOneWidget);
          expect(find.text('02:53 PM'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'width $width, scale $scale');
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient((request) async => http.Response(jsonEncode({
      'success': true,
      'data': {'month_records': [
        {'work_date': '$month-01', 'attendance_status': 'present', 'clock_in_at': '$month-01 08:01:00'},
        {'work_date': '$month-02', 'attendance_status': 'late', 'is_late': true, 'clock_in_at': '$month-02 14:53:00'},
        {'work_date': '$month-03', 'attendance_status': 'absent', 'clock_in_at': '$month-03 04:44:00'},
      ], 'month_overview': {}, 'items': []},
    }), 200, headers: {'content-type': 'application/json'})));
  });
}
