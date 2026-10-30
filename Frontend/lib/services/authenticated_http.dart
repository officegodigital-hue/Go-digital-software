// Attach the current session to internal API requests, including legacy pages.
import 'dart:convert';
import 'package:http/http.dart' as base;
import 'api_config.dart';
import 'auth_storage.dart';
export 'package:http/http.dart'
    hide get, post, put, patch, delete, MultipartRequest;

Future<Map<String, String>> _headers(
  Uri uri,
  Map<String, String>? headers,
) async {
  final result = <String, String>{...?headers};
  final api = Uri.base.resolve(ApiConfig.baseUrl);
  final target = Uri.base.resolveUri(uri);
  final apiPath = api.path.replaceFirst(RegExp(r'/$'), '');
  if (target.origin == api.origin &&
      (target.path == apiPath || target.path.startsWith('$apiPath/')) &&
      !result.keys.any((key) => key.toLowerCase() == 'authorization')) {
    final token = await AuthStorage.getString('auth_token');
    if (token != null && token.isNotEmpty)
      result['Authorization'] = 'Bearer $token';
  }
  return result;
}

Future<base.Response> get(Uri url, {Map<String, String>? headers}) async =>
    base.get(url, headers: await _headers(url, headers));
Future<base.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async => base.post(
  url,
  headers: await _headers(url, headers),
  body: body,
  encoding: encoding,
);
Future<base.Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async => base.put(
  url,
  headers: await _headers(url, headers),
  body: body,
  encoding: encoding,
);
Future<base.Response> patch(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async => base.patch(
  url,
  headers: await _headers(url, headers),
  body: body,
  encoding: encoding,
);
Future<base.Response> delete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async => base.delete(
  url,
  headers: await _headers(url, headers),
  body: body,
  encoding: encoding,
);

class MultipartRequest extends base.MultipartRequest {
  MultipartRequest(super.method, super.url);
  @override
  Future<base.StreamedResponse> send() async {
    headers.addAll(await _headers(url, headers));
    return super.send();
  }
}
