import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godigital_portal/screens/employee_dashboard/notification_page.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final width in [390.0, 1200.0]) {
    testWidgets('meeting organizer actions at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final meeting = <String, dynamic>{
        'id': 1,
        'title': 'Project meeting',
        'meeting_link': 'https://example.test/meeting',
        'host_name': 'Admin',
        'status': 'Scheduled',
        'start_at': '2035-07-14 10:00:00',
        'end_at': '2035-07-14 10:30:00',
        'duration_mins': 30,
        'meeting_details': 'Initial agenda',
        'attendees': '["Ravi"]',
        'groups': '[]',
        'can_manage': true,
      };
      Map<String, dynamic>? saved;
      final client = MockClient((request) async {
        final path = request.url.path;
        var statusCode = 200;
        Object data = <String, dynamic>{};
        if (request.method == 'PATCH' && path.endsWith('/meetings/1')) {
          saved = jsonDecode(request.body) as Map<String, dynamic>;
          meeting['meeting_details'] = saved!['details'];
          data = {'success': true};
        } else if (request.method == 'POST' &&
            path.endsWith('/meetings/1/start')) {
          meeting['status'] = 'Active';
          data = {'success': true};
        } else if (request.method == 'PATCH' &&
            path.endsWith('/meetings/1/status')) {
          meeting['status'] = jsonDecode(request.body)['status'];
          data = {'success': true, 'message': 'Meeting completed'};
        } else if (path.endsWith('/meetings/scheduled')) {
          data = {
            'data': [meeting],
          };
        } else if (path.contains('/chat/')) {
          data = {
            'meetings': [meeting],
          };
        } else {
          statusCode = 404;
        }
        return http.Response(jsonEncode(data), statusCode);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => AuthService(),
            child: const MaterialApp(
              home: Scaffold(body: NotificationsScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Meetings').first);
        await tester.pumpAndSettle();

        expect(find.text('Project meeting'), findsOneWidget);
        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Complete'), findsNothing);
        expect(find.text('Reject'), findsNothing);

        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        expect(find.text('Edit Meeting'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'Initial agenda'),
          'Updated agenda',
        );
        await tester.tap(find.text('Update Meeting'));
        await tester.pumpAndSettle();
        expect(saved?['details'], 'Updated agenda');
        expect(saved?['attendees'], ['Ravi']);
        expect(saved?.containsKey('startAt'), isFalse);
        expect(find.text('Updated agenda'), findsOneWidget);

        await tester.tap(find.text('Start'));
        await tester.pumpAndSettle();
        expect(find.text('Start'), findsNothing);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Complete'), findsOneWidget);
        expect(find.text('Reject'), findsOneWidget);

        await tester.tap(find.text('Complete'));
        await tester.pumpAndSettle();
        expect(find.text('Completed'), findsOneWidget);
        expect(find.text('Complete'), findsNothing);
        expect(find.text('Reject'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }, () => client);
    });
  }
}
