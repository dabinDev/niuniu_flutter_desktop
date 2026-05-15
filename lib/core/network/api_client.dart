import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/application/app_preferences_provider.dart';
import 'api_base_url.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final apiBaseUrl = ref.watch(
    appPreferencesProvider.select(
      (state) => state.valueOrNull?.apiBaseUrl ?? defaultApiBaseUrl,
    ),
  );
  final client = ApiClient(baseUrl: apiBaseUrl);
  ref.onDispose(client.close);
  return client;
});

class ApiClient {
  ApiClient({
    String? baseUrl,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: normalizeApiBaseUrl(baseUrl),
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 20),
          ),
        );

  final Dio _dio;

  String get baseUrl => _dio.options.baseUrl;

  Future<Map<String, dynamic>> getMap(String path) async {
    final response = await _dio.get<Map<String, dynamic>>(path);
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> getList(String path) async {
    final response = await _dio.get<List<dynamic>>(path);
    return response.data ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> postMap(
    String path, {
    Object? data,
    Duration? receiveTimeout,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      options: receiveTimeout == null
          ? null
          : Options(
              receiveTimeout: receiveTimeout,
            ),
    );
    return response.data ?? <String, dynamic>{};
  }

  void close() {
    _dio.close(force: true);
  }
}
