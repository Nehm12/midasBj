/**
 * Client HTTP pour communiquer avec l'API REST du backend.
 *
 * Utilise Dio avec :
 * - URL de base configurable (10.0.2.2 pour émulateur Android,
 *   localhost pour web/Linux)
 * - Timeouts de 10 secondes
 * - Intercepteur qui ajoute le token JWT depuis le stockage sécurisé
 */
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000/api/v1',
);

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  late final Dio _dio;
  final _secure = const FlutterSecureStorage();

  ApiClient() {
    // Sur le web, on utilise localhost car le navigateur tourne sur la machine
    final effectiveUrl = kIsWeb ? 'http://localhost:3000/api/v1' : _kBaseUrl;
    _dio = Dio(BaseOptions(
      baseUrl: effectiveUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    // Ajoute le token JWT à chaque requête
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _secure.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
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
