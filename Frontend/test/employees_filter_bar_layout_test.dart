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
  for (final width in [1920.0, 1600.0, 900.0, 430.0]) {
    testWidgets(
      'Employees filter bar fills the width and keeps its actions at $width',
      (tester) async {
        SharedPreferences.setMockInitialValues({'auth_token': 'filter-test'});
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [],
                'departments': ['Design'],
                'total': 0,
                'kpis': {'total': 6, 'active': 5, 'inactive': 1},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
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
          final bar = find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_Filters',
          );
          final kpis = find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_EmployeeKpis',
          );
          final barRect = tester.getRect(bar);
          final kpiRect = tester.getRect(kpis);
          expect(barRect.left, closeTo(kpiRect.left, .1));
          expect(barRect.right, closeTo(kpiRect.right, .1));
          final search = find.descendant(
            of: bar,
            matching: find.byType(TextField),
          );
          final searchRect = tester.getRect(search);
          if (width >= 600) {
            final filters = find.descendant(
              of: bar,
              matching: find.byType(DropdownButtonFormField<String>),
            );
            expect(filters, findsNWidgets(3));
            expect(searchRect.height, 48);
            for (final element in filters.evaluate()) {
              final fieldRect = tester.getRect(find.byWidget(element.widget));
              expect(fieldRect.height, 48);
              if (width >= 1280) expect(fieldRect.bottom, searchRect.bottom);
            }
            if (width >= 1280) {
              expect(barRect.height, lessThan(105));
              final reset = tester.getRect(find.byTooltip('Reset filters'));
              expect(reset.right, closeTo(barRect.right - 16, .1));
              expect(reset.height, 48);
              expect(reset.bottom, searchRect.bottom);
            }
          } else {
            expect(
              searchRect.height,
              60,
              reason: 'Existing mobile layout is preserved',
            );
          }
          await tester.ensureVisible(search);
          await tester.enterText(search, 'Ravi');
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          http.Request lastList() => requests.lastWhere(
            (request) => request.url.path.endsWith('/hrms/employees'),
          );
          expect(lastList().url.queryParameters['search'], 'Ravi');
          if (width >= 600) {
            final status = find
                .descendant(
                  of: bar,
                  matching: find.byType(DropdownButtonFormField<String>),
                )
                .at(1);
            await tester.ensureVisible(status);
            await tester.pumpAndSettle();
            await tester.tap(status);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Active').last);
            await tester.pumpAndSettle();
            expect(lastList().url.queryParameters['status'], 'Active');
          }
          final reset = width >= 600
              ? find.byTooltip('Reset filters')
              : find.descendant(of: bar, matching: find.text('Reset'));
          await tester.ensureVisible(reset);
          await tester.pumpAndSettle();
          await tester.tap(reset);
          await tester.pumpAndSettle();
          expect(lastList().url.queryParameters['search'], '');
          expect(lastList().url.queryParameters['status'], 'All Status');
          expect(tester.widget<TextField>(search).controller!.text, isEmpty);
          expect(requests.every((request) => request.method == 'GET'), true);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }, () => client);
      },
    );
  }
}
