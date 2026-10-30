import 'auth_storage.dart';

// Read the current session for each handshake, including reconnects.
Future<void> authenticateSocket(void Function(Map) callback) async {
  String? token;
  try {
    token = await AuthStorage.getString('auth_token');
  } catch (_) {
    // Missing session storage must not allow an unauthenticated connection.
  }
  callback(
    token == null || token.isEmpty ? <String, dynamic>{} : {'token': token},
  );
}
