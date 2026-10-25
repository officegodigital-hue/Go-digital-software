import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:godigital_portal/hrms_employee/pages/extra_hours_page.dart';
import 'package:godigital_portal/services/auth_service.dart';

void main() {
  for (final width in [430.0, 1400.0]) {
    testWidgets('extra hours loads and submits at width $width', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'auth_token': 'test'});
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var posts = 0;
      var loads = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            ChangeNotifierProvider(
              create: (_) => AuthService(),
              child: MaterialApp(home: const EmployeeExtraHoursPage()),
            ),
          );
          await tester.pumpAndSettle();
          expect(loads, 1);
          final label = find
              .text(width < 600 ? 'Log Extra Hours' : 'Log Hours')
              .first;
          await tester.tap(label);
          await tester.pumpAndSettle();
          expect(find.text('Submit'), findsOneWidget);
          await tester.tap(find.text('Submit'));
          await tester.pumpAndSettle();
          expect(posts, 1);
          expect(find.text('Enter valid hours'), findsOneWidget);
          expect(find.text('Submit'), findsOneWidget);
          await tester.tap(find.text('Submit'));
          await tester.pumpAndSettle();
          expect(posts, 2);
          expect(loads, 2);
          expect(find.text('Extra hours logged successfully!'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/extra-hours/log')) {
            posts++;
            final body = jsonDecode(request.body);
            expect(body.containsKey('actual_out'), isFalse);
            expect(body.containsKey('regular_out'), isFalse);
            return http.Response(
              jsonEncode({
                'success': posts > 1,
                'message': 'Enter valid hours',
              }),
              posts > 1 ? 200 : 400,
            );
          }
          if (request.url.path.endsWith('/extra-hours/dashboard')) loads++;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'rows': [],
                'metrics': {
                  'total_year': '2h 30m',
                  'this_month_hours': '2h 30m',
                  'this_month_detail': '1 session',
                },
              },
            }),
            200,
          );
        }),
      );
    });
  }
}
