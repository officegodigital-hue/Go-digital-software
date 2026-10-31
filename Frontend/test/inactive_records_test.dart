import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:godigital_portal/hrms_admin/features/employees/employees_page.dart';
import 'package:godigital_portal/hrms_admin/features/employees/employee_records_panel.dart';
import 'package:godigital_portal/hrms_admin/features/employees/employee_profile_page.dart';
import 'package:godigital_portal/hrms_admin/features/employees/employee_records_widgets.dart';

const summaries = [
  {
    'employeeUserId': 7,
    'name': 'Ravi Kumar',
    'employeeCode': 'EMP007',
    'department': 'Design',
    'workMode': 'Hybrid',
    'isActive': false,
    'lastWorkingDate': '2026-10-28',
    'reason': 'Resigned for a new opportunity',
    'settlementStatus': 'Review required',
  },
  {
    'employeeUserId': 8,
    'name': 'Priya Sharma',
    'employeeCode': 'EMP008',
    'department': 'Human Resources',
    'workMode': 'Office',
    'isActive': false,
    'lastWorkingDate': '2026-10-20',
    'reason': 'Personal reasons',
    'settlementStatus': 'Settled',
  },
  {
    'employeeUserId': 9,
    'name': 'Arun Babu',
    'employeeCode': 'EMP009',
    'department': 'Marketing',
    'workMode': 'Office',
    'isActive': true,
    'lastWorkingDate': '2026-10-10',
    'latestJoiningDate': '2026-10-30',
    'reason': 'Career break',
    'settlementStatus': 'Settled',
  },
];

Map<String, dynamic> detail(bool active) => {
  'employee': {
    'id': 7,
    'full_name': 'Ravi Kumar',
    'joining_date': '2026-01-05',
    'is_active': active ? 1 : 0,
  },
  'profile': {
    'employee_code': 'EMP007',
    'department': 'Design',
    'work_mode': 'Hybrid',
  },
  'exits': [
    {
      'id': 4,
      'last_working_date': '2026-10-28',
      'disabled_at': '2026-10-29 10:00:00',
      'reason': 'Resigned for a new opportunity',
      'settlement_status': 'Review required',
      'changed_by_name': 'Admin Joel',
      'created_by': 1,
    },
  ],
  'periods': [
    {'started_on': '2026-01-05', 'ended_on': '2026-10-28'},
    if (active) {'started_on': '2026-10-30', 'ended_on': null},
  ],
  'history': [
    {
      'source': 'attendance_records',
      'records': [
        {
          'id': 3,
          'attendance_date': '2026-10-28',
          'attendance_status': 'present',
          'check_in_at': '2026-10-28 09:30:00',
        },
      ],
    },
    {'source': 'employee_leaves', 'records': []},
  ],
  'payroll': [
    {
      'id': 21,
      'pay_month': 10,
      'pay_year': 2026,
      'status': 'pending',
      'net_pay': 26400,
      'period_start': '2026-10-01',
      'period_end': '2026-10-31',
    },
  ],
  'finalSalary': [
    {
      'exitId': 4,
      'payYear': 2026,
      'payMonth': 10,
      'periodStart': '2026-10-01',
      'periodEnd': '2026-10-31',
      'monthlySalary': 30000,
      'dailyRate': 1200,
      'eligibleWorkingDays': 23,
      'lopDays': 1,
      'netPayLabel': '₹26,400',
    },
  ],
  'audit': [
    {
      'id': 1,
      'action': 'EXIT',
      'created_at': '2026-10-29 10:00:00',
      'admin_name': 'Admin Joel',
    },
  ],
  'adjustments': [],
  'exitDateRequired': false,
};

Map<String, dynamic> overview(int id, bool active) => {
  'employee': {
    'id': 1,
    'employeeUserId': id,
    'name': id == 9 ? 'Arun Babu' : 'Ravi Kumar',
    'employeeCode': id == 9 ? 'EMP009' : 'EMP007',
    'department': 'Design',
    'workMode': 'Hybrid',
    'status': active || id == 9 ? 'Active' : 'Inactive',
  },
  'summary': {
    'workingDays': 24,
    'paidDays': 22,
    'present': 21,
    'late': 1,
    'absent': 2,
    'lopDays': 2,
    'permissions': 1,
    'netPayLabel': '₹26,400',
    'payrollStatus': 'pending',
  },
  'dailyAttendance': [
    {
      'date': '2026-10-28',
      'weekday': 'Wed',
      'checkIn': '09:30 AM',
      'checkOut': '06:30 PM',
      'workedLabel': '8h 00m',
      'breakLabel': '60m',
      'status': 'present',
    },
  ],
  'leaves': [
    {
      'type': 'Leave',
      'fromDate': '2026-10-15',
      'toDate': '2026-10-15',
      'durationDays': 1,
      'reason': 'Family appointment',
      'status': 'approved',
      'appliedOn': '2026-10-14',
      'reviewedBy': 'Admin Joel',
    },
  ],
  'payrollHistory': [
    {
      'id': 21,
      'year': 2026,
      'month': 10,
      'monthLabel': 'October 2026',
      'workingDays': 24,
      'paidDays': 22,
      'lopDays': 2,
      'periodStart': '2026-10-01',
      'periodEnd': '2026-10-31',
      'salaryLabel': '₹30,000',
      'deductionsLabel': '₹3,600',
      'netPayLabel': '₹26,400',
      'status': 'pending',
    },
  ],
};

final previewDirectory = Platform.environment['RECORDS_PREVIEW_DIR'];
Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (previewDirectory == null) return;
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '$previewDirectory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({'auth_token': 'test-token'}),
  );
  for (final width in [1600.0, 430.0]) {
    testWidgets(
      'Inactive Records works with search, rejoined history and existing actions at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final captureKey = GlobalKey();
        final previewFont = Platform.environment['RECORDS_PREVIEW_FONT'];
        if (previewFont != null) {
          await tester.runAsync(() async {
            final loader = FontLoader('RecordPreview')
              ..addFont(
                File(
                  previewFont,
                ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
              );
            await loader.load();
            final icons = FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
            await icons.load();
          });
        }
        var active = false;
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          Object? data;
          if (path.endsWith('/hrms/employees'))
            data = {
              'items': [
                {
                  'id': 1,
                  'employeeUserId': 7,
                  'name': 'Ravi Kumar',
                  'employeeCode': 'EMP007',
                  'department': 'Design',
                  'workMode': 'Hybrid',
                  'salary': '₹30,000',
                  'status': active ? 'Active' : 'Inactive',
                },
              ],
              'departments': ['Design'],
              'total': 1,
              'kpis': {
                'total': 1,
                'inactive': active ? 0 : 1,
                'active': active ? 1 : 0,
              },
            };
          if (path.endsWith('/employees/records'))
            data = {
              'items': summaries
                  .map(
                    (row) => row['employeeUserId'] == 7 && active
                        ? {
                            ...row,
                            'isActive': true,
                            'latestJoiningDate': '2026-10-30',
                          }
                        : row,
                  )
                  .toList(),
            };
          if (path.endsWith('/7/lifecycle')) data = detail(active);
          if (path.endsWith('/0/profile'))
            data = overview(
              int.parse(request.url.queryParameters['employeeUserId']!),
              active,
            );
          if (path.endsWith('/reactivate')) {
            active = true;
            data = {'startDate': '2026-10-30'};
          }
          return http.Response(
            jsonEncode({'success': true, 'data': data ?? {}}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        Future<void> tapText(String text) async {
          final finder = find.text(text).first;
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        await http.runWithClient(() async {
          await tester.pumpWidget(
            ChangeNotifierProvider(
              create: (_) => AuthService(),
              child: RepaintBoundary(
                key: captureKey,
                child: MaterialApp(
                  theme: previewFont == null
                      ? null
                      : ThemeData(fontFamily: 'RecordPreview'),
                  home: const EmployeesPage(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Inactive Records'), findsOneWidget);
          expect(
            requests.any((r) => r.url.path.endsWith('/employees/records')),
            false,
          );
          await tapText('Inactive Records');
          await capture(tester, captureKey, 'inactive-records-$width');
          expect(find.text('Ravi Kumar'), findsOneWidget);
          expect(find.text('Priya Sharma'), findsOneWidget);
          expect(find.text('Arun Babu'), findsNothing);
          expect(
            requests
                .where((r) => r.url.path.endsWith('/employees/records'))
                .single
                .headers['authorization'],
            'Bearer test-token',
          );
          final search = find.descendant(
            of: find.byType(EmployeeRecordsPanel),
            matching: find.byType(TextField),
          );
          await tester.ensureVisible(search);
          await tester.enterText(search, 'EMP008');
          await tester.pumpAndSettle();
          expect(find.text('Priya Sharma'), findsOneWidget);
          expect(find.text('Ravi Kumar'), findsNothing);
          await tester.enterText(search, '');
          await tester.pumpAndSettle();
          await tapText('Rejoined Employees');
          expect(find.text('Arun Babu'), findsOneWidget);
          expect(find.text('Ravi Kumar'), findsNothing);
          if (width >= 850) {
            await tapText('View Record');
            expect(find.byType(EmployeeProfilePage), findsOneWidget);
            expect(find.text('Arun Babu'), findsOneWidget);
            expect(find.text('Employee overview'), findsOneWidget);
            expect(
              requests
                  .lastWhere((r) => r.url.path.endsWith('/0/profile'))
                  .url
                  .queryParameters['employeeUserId'],
              '9',
            );
            await tester.tap(find.byIcon(Icons.arrow_back));
            await tester.pumpAndSettle();
          }
          await tapText('Currently Inactive');
          if (width >= 850) {
            await tapText('View Record');
            expect(find.byType(EmployeeProfilePage), findsOneWidget);
            expect(find.text('Employee overview'), findsOneWidget);
            expect(find.text('Inactive'), findsOneWidget);
            expect(find.text('09:30 AM'), findsOneWidget);
            final profileRequest = requests.lastWhere(
              (r) => r.url.path.endsWith('/0/profile'),
            );
            expect(profileRequest.url.queryParameters['employeeUserId'], '7');
            expect(
              profileRequest.headers['authorization'],
              'Bearer test-token',
            );
            await capture(tester, captureKey, 'existing-employee-overview');
            await tapText('Leaves & Permissions');
            expect(find.textContaining('Family appointment'), findsOneWidget);
            await tapText('Payroll History');
            expect(find.text('₹26,400'), findsAtLeastNWidgets(1));
            expect(find.text('October 2026'), findsAtLeastNWidgets(1));
            await tester.tap(find.byIcon(Icons.chevron_left).first);
            await tester.pumpAndSettle();
            final previous = DateTime(
              DateTime.now().year,
              DateTime.now().month - 1,
            );
            expect(
              requests
                  .lastWhere((r) => r.url.path.endsWith('/0/profile'))
                  .url
                  .queryParameters['month'],
              previous.month.toString(),
            );
            await tester.tap(find.byIcon(Icons.arrow_back));
            await tester.pumpAndSettle();
          }
          // Settlement keeps its explicit, existing menu; View Record uses the shared overview.
          final employeesTab = find.descendant(
            of: find.byType(RecordTabs).first,
            matching: find.text('Employees'),
          );
          await tester.ensureVisible(employeesTab);
          await tester.pumpAndSettle();
          await tester.tap(employeesTab);
          await tester.pumpAndSettle();
          final menu = find
              .byTooltip(width < 600 ? 'Employee actions' : 'More')
              .first;
          await tester.ensureVisible(menu);
          await tester.pumpAndSettle();
          await tester.tap(menu);
          await tester.pumpAndSettle();
          await tapText('History and settlement');
          expect(find.text('Employee record'), findsOneWidget);
          expect(find.textContaining('Admin Joel'), findsOneWidget);
          await capture(tester, captureKey, 'employee-record-$width');
          await tapText('Employment History');
          expect(find.text('Original employment'), findsOneWidget);
          await tapText('Salary');
          expect(find.text('Review payment'), findsOneWidget);
          await capture(tester, captureKey, 'employee-salary-$width');
          await tapText('Review payment');
          expect(find.text('Review final salary'), findsOneWidget);
          await tapText('Cancel');
          expect(requests.any((r) => r.method == 'PATCH'), false);
          await tapText('Reactivate Employee');
          expect(find.textContaining('(today, India time)'), findsOneWidget);
          expect(find.byType(DatePickerDialog), findsNothing);
          await tapText('Confirm reactivation');
          expect(active, true);
          expect(
            jsonDecode(
              requests
                  .where((r) => r.url.path.endsWith('/reactivate'))
                  .single
                  .body,
            ),
            isEmpty,
          );
          expect(find.text('Rejoined'), findsOneWidget);
          await tapText('Employment History');
          expect(find.text('Rejoined • period 2'), findsOneWidget);
          expect(find.text('Original employment'), findsOneWidget);
          final back = find.widgetWithIcon(
            TextButton,
            Icons.arrow_back_rounded,
          );
          await tester.ensureVisible(back);
          await tester.pumpAndSettle();
          await tester.tap(back);
          await tester.pumpAndSettle();
          await tapText('Inactive Records');
          expect(find.byType(EmployeeRecordsPanel), findsOneWidget);
          expect(find.text('Ravi Kumar'), findsNothing);
          await tapText('Rejoined Employees');
          expect(find.text('Ravi Kumar'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }, () => client);
      },
    );
  }

  testWidgets(
    'Records retry, department and settlement filters work without writes',
    (tester) async {
      tester.view.physicalSize = const Size(1500, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        calls++;
        if (calls == 1)
          return http.Response(
            jsonEncode({'success': false, 'message': 'Connection interrupted'}),
            503,
          );
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'items': summaries},
          }),
          200,
        );
      });
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: EmployeeRecordsPanel(onOpenRecord: (_, _) async {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Records could not be loaded'), findsOneWidget);
        await tap(find.text('Try again'));
        expect(find.text('Ravi Kumar'), findsOneWidget);
        expect(find.text('Priya Sharma'), findsOneWidget);
        Future<void> select(String current, String value) async {
          await tap(
            find.widgetWithText(DropdownButtonFormField<String>, current),
          );
          await tap(find.text(value).last);
        }

        await select('All Departments', 'Design');
        expect(find.text('Ravi Kumar'), findsOneWidget);
        expect(find.text('Priya Sharma'), findsNothing);
        await select('Design', 'All Departments');
        await select('All Settlements', 'Completed');
        expect(find.text('Priya Sharma'), findsOneWidget);
        expect(find.text('Ravi Kumar'), findsNothing);
        await select('Completed', 'Pending');
        expect(find.text('Ravi Kumar'), findsOneWidget);
        expect(find.text('Priya Sharma'), findsNothing);
        await select('Pending', 'Exit date required');
        expect(find.text('No inactive records found'), findsOneWidget);
        expect(calls, 2);
        expect(requests.every((request) => request.method == 'GET'), true);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }, () => client);
    },
  );
}
