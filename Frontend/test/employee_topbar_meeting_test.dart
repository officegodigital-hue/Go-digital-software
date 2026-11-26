import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godigital_portal/core/constants/employee_role.dart';
import 'package:godigital_portal/core/widgets/employee_topbar.dart';
import 'package:godigital_portal/screens/employee_dashboard/notification_page.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmployeeSession extends AuthService {
  _EmployeeSession([this.name = 'Ravi', this.id = 7]);

  final String name;
  final int id;

  @override
  Map<String, dynamic> get user => {'id': id, 'fullName': name};
}

void main() {
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channels = [
      MethodChannel('xyz.luan/audioplayers.global'),
      MethodChannel('xyz.luan/audioplayers.global/events'),
      MethodChannel('xyz.luan/audioplayers'),
    ];
    final playerEvents = <MethodChannel>[];
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'create') {
          final playerId = (call.arguments as Map)['playerId'];
          final events = MethodChannel(
            'xyz.luan/audioplayers/events/$playerId',
          );
          messenger.setMockMethodCallHandler(events, (_) async => null);
          playerEvents.add(events);
        }
        return null;
      });
    }
    addTearDown(() {
      for (final channel in [...channels, ...playerEvents]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
  });

  for (final width in [390.0, 1200.0]) {
    testWidgets('task and meeting indicators at ${width.toInt()} px', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var status = 'SCHEDULED';
      final client = MockClient((request) async {
        final path = request.url.path;
        final Object result;
        if (path.endsWith('/workspace-tasks/running')) {
          result = {
            'running': {'task': 'Review design', 'elapsedSecs': 120},
            'totalSecs': 120,
            'workingSecsWithMeetings': status == 'COMPLETED' ? 121 : 120,
            'workingRemainingSecs': status == 'ACTIVE' ? 1 : 0,
          };
        } else if (path.endsWith('/chat/meetings/live/Ravi')) {
          result = {
            'data': [
              {'title': 'Project kickoff', 'status': status},
            ],
          };
        } else {
          return http.Response('{}', 404);
        }
        return http.Response(jsonEncode(result), 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthService>(
            create: (_) => _EmployeeSession(),
            child: const MaterialApp(
              home: Scaffold(body: EmployeeTopbar(role: EmployeeRole.designer)),
            ),
          ),
        );
        await tester.pump();
        final task = width < 450
            ? find.byTooltip('Task running: Review design')
            : find.text('Review design');
        final meeting = find.byTooltip('Meeting live\nProject kickoff');

        expect(task, findsOneWidget);
        expect(meeting, findsNothing);

        status = 'ACTIVE';
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(task, findsOneWidget);
        expect(meeting, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1100)),
        );
        await tester.pump(const Duration(seconds: 1));
        final total = width < 450
            ? find.text('00:02:01')
            : find.text('Today Working Hours: 00h 02m 01s');
        expect(total, findsOneWidget);

        status = 'COMPLETED';
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(meeting, findsNothing);
        expect(task, findsOneWidget);
        expect(total, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    });
  }

  testWidgets('organizer actions update an open participant topbar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(2400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const organizer = ValueKey('organizer chat');
    const participant = ValueKey('participant chat');
    var status = 'Scheduled';
    final client = MockClient((request) async {
      final path = request.url.path;
      Object result = {};
      if (path.endsWith('/chat/Organizer') || path.endsWith('/chat/Ravi')) {
        result = {
          'meetings': [
            {
              'id': 1,
              'title': 'Project kickoff',
              'host_name': 'Organizer',
              'status': status,
              'can_manage': path.endsWith('/Organizer'),
            },
          ],
        };
      } else if (request.method == 'POST' &&
          path.endsWith('/meetings/1/start')) {
        status = 'Active';
        result = {'success': true};
      } else if (request.method == 'PATCH' &&
          path.endsWith('/meetings/1/status')) {
        status = jsonDecode(request.body)['status'] as String;
        result = {'success': true, 'message': 'Meeting completed'};
      } else if (path.endsWith('/chat/meetings/live/Ravi')) {
        result = {
          'data': [
            {'title': 'Project kickoff', 'status': status.toUpperCase()},
          ],
        };
      } else {
        return http.Response('{}', 404);
      }
      return http.Response(jsonEncode(result), 200);
    });

    Finder inChat(Key key, String text) =>
        find.descendant(of: find.byKey(key), matching: find.text(text));

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Expanded(
                  child: ChangeNotifierProvider<AuthService>(
                    create: (_) => _EmployeeSession('Organizer', 1),
                    child: const NotificationsScreen(key: organizer),
                  ),
                ),
                Expanded(
                  child: ChangeNotifierProvider<AuthService>(
                    create: (_) => _EmployeeSession(),
                    child: const Column(
                      children: [
                        EmployeeTopbar(role: EmployeeRole.designer),
                        Expanded(child: NotificationsScreen(key: participant)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(inChat(organizer, 'Meetings'));
      await tester.tap(inChat(participant, 'Meetings'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(inChat(organizer, 'Start'), findsOneWidget);
      expect(inChat(participant, 'Project kickoff'), findsOneWidget);
      expect(inChat(participant, 'Start'), findsNothing);
      final indicator = find.byTooltip('Meeting live\nProject kickoff');
      expect(indicator, findsNothing);

      await tester.tap(inChat(organizer, 'Start'));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(indicator, findsOneWidget);
      expect(inChat(organizer, 'Complete'), findsOneWidget);
      expect(inChat(participant, 'Complete'), findsNothing);

      await tester.tap(inChat(organizer, 'Complete'));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(indicator, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });
}
