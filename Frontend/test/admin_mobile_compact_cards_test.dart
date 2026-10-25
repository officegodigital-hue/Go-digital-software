import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:godigital_portal/hrms_admin/features/clock_logs/clock_logs_page.dart' as clock;
import 'package:godigital_portal/hrms_admin/features/employees/employees_page.dart' as employees;
import 'package:godigital_portal/hrms_admin/features/payroll/payroll_page.dart' as payroll;
import 'package:godigital_portal/hrms_admin/shared/widgets/admin_top_nav.dart';
import 'package:godigital_portal/services/auth_service.dart';

void main() {
  for (final page in [
    (const clock.ClockLogsPage(), '_MobileMetric', 78.0, true),
    (const employees.EmployeesPage(), '_EmployeeKpi', 80.0, false),
    (const payroll.PayrollPage(), '_PayrollKpi', 80.0, false),
  ]) {
    testWidgets('${page.$2} preserves card size without overflowing', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await http.runWithClient(() async {
        await tester.pumpWidget(ChangeNotifierProvider(
          create: (_) => AuthService(),
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(.5)), child: child!,
            ),
            home: page.$1,
          ),
        ));
        await tester.pumpAndSettle();
        final metrics = find.byWidgetPredicate((w) => w.runtimeType.toString() == page.$2);
        final cards = metrics.evaluate().map((e) => e.widget).toList();
        expect(cards, isNotEmpty);
        expect(tester.takeException(), isNull);
        for (final scale in [1.2, 1.3, 1.5, 2.0]) {
          await tester.pumpWidget(MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!,
            ),
            home: Scaffold(body: Align(alignment: Alignment.topLeft,
              child: SizedBox(width: cards.length * 67.2 + (cards.length - 1) * 8,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    if (page.$4) cards[i] else Expanded(child: cards[i]),
                  ],
                ]),
              ),
            )),
          ));
          await tester.pumpAndSettle();
          for (var i = 0; i < cards.length; i++) {
            expect(tester.getSize(metrics.at(i)).height, page.$3);
            expect(tester.getSize(metrics.at(i)).width, closeTo(67.2, .01));
          }
          expect(tester.takeException(), isNull, reason: 'text scale $scale');
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => MockClient((request) async => http.Response(jsonEncode({
        'success': true, 'data': {'items': [], 'employees': [], 'kpis': {'totalPayrollLabel': '₹1,20,000'}},
      }), 200, headers: {'content-type': 'application/json'})));
    });
  }

  testWidgets('mobile dock keeps its size, shows seven icons, and opens Payroll', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: const Scaffold(bottomNavigationBar: AdminMobileBottomNav(activeRoute: '/admin/approvals')),
      routes: {'/admin/payroll': (_) => const Scaffold(body: Text('Payroll destination'))},
    ));
    expect(find.byType(Icon), findsNWidgets(7));
    for (final item in AdminTopNav.items) {
      expect(find.text(item.$1), findsNothing);
      expect(find.byTooltip(item.$1), findsOneWidget);
    }
    expect(find.byWidgetPredicate((w) => w is Container && w.constraints?.maxHeight == 74), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Payroll'));
    await tester.pumpAndSettle();
    expect(find.text('Payroll destination'), findsOneWidget);
  });
}
