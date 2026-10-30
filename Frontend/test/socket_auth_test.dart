import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:godigital_portal/services/auth_storage.dart';
import 'package:godigital_portal/services/socket_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Socket authentication reloads storage instead of using a stale login',
    () async {
      SharedPreferences.setMockInitialValues({'auth_token': 'first-session'});
      AuthStorage.cachedToken = 'stale-session';
      final first = Completer<Map>();
      await authenticateSocket(first.complete);
      expect(await first.future, {'token': 'first-session'});
      await AuthStorage.remove('auth_token');
      final signedOut = Completer<Map>();
      await authenticateSocket(signedOut.complete);
      expect(await signedOut.future, isEmpty);
    },
  );

  test(
    'Live socket connects, uses the new login on reconnect, and rejects logout',
    () async {
      // Isolated local server: no application database, tasks, or accounts are changed.
      final server = await Process.start('node', [
        '-e',
        r'''
const { Server } = require('socket.io');
const http = require('http').createServer();
const io = new Server(http);
io.use((socket, next) => ['first-session', 'next-session'].includes(socket.handshake.auth.token)
  ? next() : next(new Error('Login required')));
io.on('connection', socket => socket.emit('session_checked', socket.handshake.auth.token));
http.listen(0, '127.0.0.1', () => console.log(http.address().port));
''',
      ], workingDirectory: '../backend');
      addTearDown(() async {
        server.kill();
        await server.exitCode;
      });
      final port = await server.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 10));
      SharedPreferences.setMockInitialValues({'auth_token': 'first-session'});
      final socket = io.io(
        'http://127.0.0.1:$port',
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableForceNew()
            .disableAutoConnect()
            .disableReconnection()
            .setAuthFn(authenticateSocket)
            .build(),
      );
      addTearDown(socket.dispose);
      Future<dynamic> nextEvent(String event) {
        final result = Completer<dynamic>();
        socket.once(event, result.complete);
        return result.future.timeout(const Duration(seconds: 10));
      }

      var checked = nextEvent('session_checked');
      socket.connect();
      expect(await checked, 'first-session');
      socket.disconnect();
      await AuthStorage.setString('auth_token', 'next-session');
      checked = nextEvent('session_checked');
      socket.connect();
      expect(await checked, 'next-session');
      socket.disconnect();
      await AuthStorage.remove('auth_token');
      final rejected = nextEvent('connect_error');
      socket.connect();
      expect((await rejected).toString(), contains('Login required'));
      expect(socket.connected, isFalse);
    },
  );

  test(
    'All 19 affected live-update connections use the authentication callback',
    () {
      var connections = 0;
      for (final file in Directory(
        'lib/screens',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync().replaceAll(
          RegExp(r'^\s*//.*$', multiLine: true),
          '',
        );
        if (!source.contains('.setAuthFn(authenticateSocket)')) continue;
        for (final match in RegExp(r'\b(?:IO|io)\.io\(').allMatches(source)) {
          final options = source.substring(match.end).split('.build()').first;
          expect(
            options,
            contains('.setAuthFn(authenticateSocket)'),
            reason: file.path,
          );
          connections++;
        }
      }
      expect(connections, 19);
    },
  );
}
