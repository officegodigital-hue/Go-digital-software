import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:godigital_portal/hrms_admin/features/approvals/approvals_page.dart';
import 'package:godigital_portal/services/auth_service.dart';

void main() {
  for (final size in [(430.0, 1.0), (500.0, 1.3)]) {
    testWidgets('Approvals keeps dimensions and positions at ${size.$1}/${size.$2}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(size.$1, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await http.runWithClient(() async {
        await tester.pumpWidget(ChangeNotifierProvider(
          create: (_) => AuthService(),
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(size.$2)),
              child: child!,
            ),
            home: const ApprovalsPage(),
          ),
        ));
        await tester.pumpAndSettle();
        final cards = find.byWidgetPredicate((w) => w is Container && w.constraints?.maxHeight == 80);
        expect(cards, findsNWidgets(3));
        for (final element in cards.evaluate()) {
          expect(tester.getSize(find.byWidget(element.widget)).height, 80);
        }
        final buttons = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MainTabBtn');
        final first = tester.getRect(buttons.at(0));
        final second = tester.getRect(buttons.at(1));
        expect(first.left, 16);
        expect(second.left - first.right, 10);
        expect(second.top, first.top);
        expect(second.height, first.height);
        expect(second.right, lessThanOrEqualTo(size.$1 - 16));
        expect(find.byWidgetPredicate((w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => MockClient((request) async => http.Response(jsonEncode({
        'success': true,
        'data': {'items': [], 'employees': [], 'kpis': {'pending': 0, 'approved': 12, 'rejected': 2}},
      }), 200, headers: {'content-type': 'application/json'})));
    });
  }
}
