import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../services/token_storage_service.dart';

class ApiClient {
  ApiClient._() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        responseType: ResponseType.json,
        contentType: Headers.jsonContentType,
        headers: <String, dynamic>{'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest:
            (RequestOptions options, RequestInterceptorHandler handler) async {
              try {
                final hasAuthorizationHeader = options.headers.containsKey(
                  'Authorization',
                );

                if (!hasAuthorizationHeader) {
                  final token = await TokenStorageService.instance
                      .getAccessToken();

                  if (token != null && token.trim().isNotEmpty) {
                    options.headers['Authorization'] = 'Bearer ${token.trim()}';
                  }
                }

                handler.next(options);
              } catch (error) {
                handler.next(options);
              }
            },
        onResponse:
            (Response<dynamic> response, ResponseInterceptorHandler handler) {
              handler.next(response);
            },
        onError: (DioException error, ErrorInterceptorHandler handler) {
          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();

  factory ApiClient() => instance;

  late final Dio dio;
}
