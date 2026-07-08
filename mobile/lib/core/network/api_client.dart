library;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'backend_config.dart';

const _kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  late Dio _dio;
  final _secure = const FlutterSecureStorage();
  String _currentUrl;
  bool _switched = false;

  ApiClient() : _currentUrl = _kBaseUrl.isNotEmpty ? _kBaseUrl : primaryApiUrl {
    _initDio();
  }

  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: _currentUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _secure.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (!_switched && (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.connectionError)) {
          _switched = true;
          _currentUrl = fallbackApiUrl;
          _initDio();
          try {
            final retryOptions = error.requestOptions;
            final response = await _dio.fetch(retryOptions);
            handler.resolve(response);
            return;
          } catch (_) {}
        }
        handler.next(error);
      },
    ));
  }

  Future<Response> post(String path, Map<String, dynamic> data) =>
      _dio.post(path, data: data);

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> put(String path, Map<String, dynamic> data) =>
      _dio.put(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);
}
