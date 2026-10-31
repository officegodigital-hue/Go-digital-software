import 'package:provider/provider.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:godigital_portal/services/waiting_alert_service.dart';

class _EmployeeAuth extends AuthService {
  bool signedIn = true;
  @override
  bool get isAuthenticated => signedIn;
  @override
  String? get userId => '7';
  @override
  String? get userType => 'employee';
  void signOut() {
    signedIn = false;
    notifyListeners();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'auth_token': 'test-session'});
  });
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
  }

  Position position() => Position(
    latitude: 13,
    longitude: 80,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  testWidgets(
    'one popup survives route replacement, validates reason, retries failures, and stops signals',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      var alertId = 1, signals = 0, stops = 0, submissions = 0;
      var failSubmit = true;
      final client = MockClient((request) async {
        if (request.headers['authorization'] != 'Bearer test-session')
          throw StateError('Missing authentication');
        Object? data;
        if (request.url.path.endsWith('/settings'))
          data = {'field_ping_interval_minutes': 1};
        if (request.url.path.endsWith('/hybrid-session'))
          data = {'isHybrid': true, 'isActive': false};
        if (request.url.path.endsWith('/field-waiting-alert') && alertId > 0)
          data = {'id': alertId, 'waiting_minutes': 1};
        if (request.method == 'POST') {
          submissions++;
          if (jsonDecode(request.body)['reason'] != 'Waiting for client')
            throw StateError('Incorrect reason');
          if (failSubmit)
            return http.Response(
              jsonEncode({'success': false, 'message': 'Try again'}),
              500,
            );
          alertId = 0;
        }
        return http.Response(jsonEncode({'success': true, 'data': data}), 200);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: key,
            home: const Scaffold(body: Text('Dashboard')),
          ),
        );
        final service = WaitingAlertService(
          navigatorKey: key,
          startSignal: () async {
            signals++;
          },
          stopSignal: () async {
            stops++;
          },
        );
        key.currentState!.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Another page')),
          ),
        );
        service.start();
        await flush(tester);
        expect(
          find.text("You've been waiting — please explain"),
          findsOneWidget,
        );
        await service.refresh();
        expect(signals, 1);
        await tester.tap(find.text('Submit'));
        await flush(tester);
        expect(submissions, 0);
        expect(find.text('Enter a reason for waiting.'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Waiting for client');
        await tester.tap(find.text('Submit'));
        await flush(tester);
        expect(find.textContaining('Try again'), findsOneWidget);
        expect(stops, 0);
        failSubmit = false;
        await tester.tap(find.text('Submit'));
        await flush(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(stops, greaterThanOrEqualTo(1));
        alertId = 2;
        await service.refresh();
        await flush(tester);
        expect(signals, 2);
        service.stop();
        await flush(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(stops, greaterThanOrEqualTo(2));
        await tester.pumpWidget(const SizedBox());
        await flush(tester);
      }, () => client);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'GPS and alert polling continue after leaving tracking and while a reason dialog is open',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      var gpsCalls = 0, pings = 0, alertChecks = 0;
      var active = true;
      final client = MockClient((request) async {
        final path = request.url.path;
        Object? data;
        if (path.endsWith('/hybrid-session'))
          data = {'id': 4, 'isHybrid': true, 'isActive': active};
        if (path.endsWith('/settings'))
          data = {'field_ping_interval_minutes': 1};
        if (path.endsWith('/ping')) pings++;
        if (path.endsWith('/field-waiting-alert')) {
          alertChecks++;
          data = {'id': 8, 'waiting_minutes': 1};
        }
        return http.Response(jsonEncode({'success': true, 'data': data}), 200);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: key,
            home: const Scaffold(body: Text('Tracking')),
          ),
        );
        final service = WaitingAlertService(
          navigatorKey: key,
          now: tester.binding.clock.now,
          currentPosition: () async {
            gpsCalls++;
            return position();
          },
          startSignal: () async {},
          stopSignal: () async {},
        );
        key.currentState!.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Leave')),
          ),
        );
        service.start();
        await flush(tester);
        expect(pings, 1);
        expect(find.byType(AlertDialog), findsOneWidget);
        // A route change and an open popup must not suspend GPS collection.
        await tester.pump(const Duration(minutes: 1));
        await flush(tester);
        expect(gpsCalls, 2);
        expect(pings, 2);
        expect(alertChecks, 1);
        active = false;
        await service.refresh();
        await flush(tester);
        expect(pings, 2);
        service.stop();
        await flush(tester);
        await tester.pumpWidget(const SizedBox());
        await flush(tester);
      }, () => client);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
  testWidgets(
    'app-level checker survives page replacement and stops after logout',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      final auth = _EmployeeAuth();
      var checks = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/hybrid-session')) {
          checks++;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'isHybrid': true, 'isActive': false},
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'data': request.url.path.endsWith('/settings')
                ? {'field_ping_interval_minutes': 1}
                : null,
          }),
          200,
        );
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthService>.value(
            value: auth,
            child: MaterialApp(
              navigatorKey: key,
              builder: (_, child) =>
                  WaitingAlertHost(navigatorKey: key, child: child!),
              home: const Scaffold(body: Text('Dashboard')),
            ),
          ),
        );
        await flush(tester);
        expect(checks, 1);
        final service = key.currentContext!.read<WaitingAlertService>();
        key.currentState!.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Tracking')),
          ),
        );
        await flush(tester);
        expect(
          identical(service, key.currentContext!.read<WaitingAlertService>()),
          isTrue,
        );
        await tester.pump(const Duration(minutes: 1));
        await flush(tester);
        expect(checks, 2);
        auth.signOut();
        await flush(tester);
        await tester.pump(const Duration(minutes: 1));
        await flush(tester);
        expect(checks, 2);
        await tester.pumpWidget(const SizedBox());
        await flush(tester);
      }, () => client);
      auth.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
  testWidgets(
    'poll interval follows admin changes with no one-minute fallback',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      var minutes = 2, checks = 0;
      final client = MockClient((request) async {
        Object? data;
        if (request.url.path.endsWith('/hybrid-session')) {
          checks++;
          data = {'isHybrid': true, 'isActive': false};
        }
        if (request.url.path.endsWith('/settings'))
          data = {'field_ping_interval_minutes': minutes};
        return http.Response(jsonEncode({'success': true, 'data': data}), 200);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(navigatorKey: key, home: const Scaffold()),
        );
        final service = WaitingAlertService(
          navigatorKey: key,
          startSignal: () async {},
          stopSignal: () async {},
        );
        service.start();
        await flush(tester);
        expect(checks, 1);
        await tester.pump(const Duration(minutes: 1));
        await flush(tester);
        expect(checks, 1);
        minutes = 5;
        await tester.pump(const Duration(minutes: 1));
        await flush(tester);
        expect(checks, 2);
        await tester.pump(const Duration(minutes: 4));
        await flush(tester);
        expect(checks, 2);
        await tester.pump(const Duration(minutes: 1));
        await flush(tester);
        expect(checks, 3);
        service.stop();
        await tester.pumpWidget(const SizedBox());
        await flush(tester);
      }, () => client);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
