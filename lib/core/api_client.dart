// lib/core/api_client.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'constants.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  // BUG-015 fix: sebelumnya kalau token JWT ditolak backend (401) — entah
  // karena expired, JWT_SECRET diganti (lihat BUG-012), atau user memanggil
  // /auth/logout-all dari device lain — app tetap "diam" menampilkan
  // Beranda yang rusak (setiap provider gagal fetch dengan error 401 yang
  // membingungkan), tanpa pernah mengarahkan user kembali ke halaman Login.
  //
  // onUnauthorized diisi oleh main.dart saat startup (biasanya memanggil
  // authProvider.notifier.logout()). Dipanggil otomatis oleh interceptor di
  // bawah setiap kali ADA request yang ditolak dengan status 401, dari
  // endpoint mana pun.
  void Function()? onUnauthorized;

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
          InterceptorsWrapper(
            onError: (error, handler) {
              if (error.response?.statusCode == 401) {
                onUnauthorized?.call();
              }
              // Tetap teruskan error apa adanya — kode yang sudah ada (try/catch
              // di halaman-halaman) tidak perlu diubah, tetap dapat exception
              // untuk ditangani lokal (misal tampilkan snackbar) SEKALIGUS
              // logout otomatis terjadi di background.
              handler.next(error);
            },
          ),
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
