// lib/core/api_client.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'constants.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: kBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
          ),
        )
        ..interceptors.addAll([
          // SECURITY FIX: sebelumnya LogInterceptor aktif tanpa syarat, dengan
          // requestHeader default true — artinya header "Authorization: Bearer
          // <token>" ikut ter-print ke console/logcat di SETIAP request, di
          // build release sekalipun. Kalau device di-debug via adb logcat atau
          // ada crash reporter yang menangkap console log, JWT token bisa
          // bocor ke pihak lain.
          //
          // Sekarang: (1) hanya aktif di kDebugMode, TIDAK PERNAH di build
          // release; (2) requestHeader/responseHeader dimatikan eksplisit
          // supaya token tidak pernah ter-print meski sedang debug.
          if (kDebugMode)
            LogInterceptor(
              requestBody: true,
              responseBody: true,
              requestHeader: false,
              responseHeader: false,
            ),
        ]);

  Dio get dio => _dio;

  /// Inject JWT token ke setiap request
  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Hapus token saat logout
  void clearToken() {
    _dio.options.headers.remove('Authorization');
  }
}
