import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:godigital_portal/hrms_admin/features/dashboard/dashboard_page.dart';

void main() {
  testWidgets('Dashboard counters fit the reported constraints without resizing cards', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
      await tester.pumpAndSettle();
      final metrics = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MobileDashboardMetric');
      expect(metrics, findsNWidgets(5));
      final cards = metrics.evaluate().map((element) => element.widget).toList();
      expect(tester.takeException(), isNull);

      // Isolate the existing cards at the exact reported inner size: 45.2 x 58.
      // Other dashboard controls are deliberately outside this regression test.
      tester.view.physicalSize = const Size(400, 900);
      for (final scale in [1.2, 1.3, 1.5, 2.0]) {
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(body: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                cards[i],
              ],
            ]),
          )),
        ));
        await tester.pumpAndSettle();
        for (var i = 0; i < 5; i++) {
          expect(tester.getSize(metrics.at(i)).height, 80);
          expect(tester.getSize(metrics.at(i)).width, closeTo(67.2, .01));
        }
        expect(tester.takeException(), isNull, reason: 'text scale $scale');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient((request) async => http.Response(jsonEncode({
      'success': true,
      'data': {
        'employees': [], 'overrides': [],
        'kpis': {'totalEmployees': 29, 'present': 13, 'late': 3, 'absent': 13, 'workingDays': 24},
      },
    }), 200, headers: {'content-type': 'application/json'})));
  });
}
