import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:godigital_portal/hrms_admin/features/employees/employees_page.dart';

void main() {
  for (final initial in ['Active', 'Inactive']) {
    testWidgets('Edit status from $initial uses the employment workflow', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
      tester.view.physicalSize = const Size(2200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      var status = initial;
      final target = initial == 'Active' ? 'Inactive' : 'Active';
      final client = MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        Object data = <String, dynamic>{};
        if (request.method == 'GET' && path.endsWith('/hrms/employees')) {
          data = {
            'items': [
              {
                'id': 1,
                'employeeUserId': 7,
                'name': 'Ravi',
                'employeeCode': 'EMP7',
                'department': 'Engineering',
                'workMode': 'Office',
                'salary': '₹30,000',
                'status': status,
              },
            ],
            'departments': ['Engineering'],
            'total': 1,
            'kpis': {
              'total': 1,
              'active': status == 'Active' ? 1 : 0,
              'inactive': status == 'Inactive' ? 1 : 0,
              'onLeave': 0,
            },
          };
        } else if (request.method == 'PUT') {
          expect(jsonDecode(request.body)['status'], initial);
        } else if (path.endsWith('/exit-preview')) {
          data = {'conflicts': [], 'salary': []};
        } else if (path.endsWith('/exit') || path.endsWith('/reactivate')) {
          status = target;
        }
        return http.Response(
          jsonEncode({'success': true, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => AuthService(),
            child: const MaterialApp(home: EmployeesPage()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Edit').first);
        await tester.pumpAndSettle();
        final dropdown = find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField<String> &&
              w.decoration.labelText == 'Employment status',
        );
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text(target).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            initial == 'Active' ? 'Deactivate Ravi' : 'Reactivate Ravi',
          ),
          findsOneWidget,
        );
        expect(requests.where((r) => r.method == 'PUT').length, 1);
        if (initial == 'Active') {
          await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Resigned');
          await tester.tap(find.text('Preview exit'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Confirm exit'));
        } else {
          await tester.tap(find.text('Confirm reactivation'));
        }
        await tester.pumpAndSettle();
        expect(status, target);
        expect(
          requests.any(
            (r) => r.url.path.endsWith(
              initial == 'Active' ? '/exit' : '/reactivate',
            ),
          ),
          isTrue,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }, () => client);
    });
  }
}
