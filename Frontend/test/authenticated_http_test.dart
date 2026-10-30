import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as base;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:godigital_portal/services/api_config.dart';
import 'package:godigital_portal/services/authenticated_http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'auth_token': 'current-session',
    }),
  );
  test('internal API calls include the active session', () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer current-session');
      return base.Response('{}', 200);
    });
    await base.runWithClient(
      () => http.get(Uri.parse('${ApiConfig.baseUrl}/employees')),
      () => client,
    );
  });
  test(
    'external and similarly named paths never receive the session token',
    () async {
      final client = MockClient((request) async {
        expect(request.headers.containsKey('authorization'), false);
        return base.Response('{}', 200);
      });
      await base.runWithClient(() async {
        await http.get(Uri.parse('https://example.com/api/test'));
        await http.get(Uri.parse('${ApiConfig.baseUrl}-other/test'));
      }, () => client);
    },
  );
}
