// lib/core/api_error.dart
//
// Helper untuk menerjemahkan exception hasil panggilan API jadi pesan yang
// enak dibaca user, dan untuk mengecek status code tertentu (mis. 404)
// tanpa perlu tiap halaman melakukan e.toString().contains('404') sendiri
// (rawan salah kalau pesan errornya kebetulan mengandung angka itu).
//
// Prioritas pesan:
//   1. Field "detail" dari body respons backend (FastAPI HTTPException
//      selalu mengirim ini) — supaya pesan di UI SAMA PERSIS dengan yang
//      backend maksud (mis. "Password minimal 8 karakter."), bukan cuma
//      "Error 400" yang tidak jelas.
//   2. Untuk 422 (validation error Pydantic), formatnya beda: list of
//      {loc, msg, type} — ambil msg dari item pertama.
//   3. Fallback ke pesan generik per status code.
//   4. Fallback terakhir: e.toString().

import 'package:dio/dio.dart';

String apiErrorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;

    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'].toString();
        }
      }
    }

    switch (e.response?.statusCode) {
      case 429:
        return 'Terlalu banyak percobaan dalam waktu singkat. Coba lagi beberapa saat lagi.';
      case 401:
        return 'Sesi kamu berakhir. Silakan login kembali.';
      case 404:
        return 'Data tidak ditemukan.';
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Gagal terhubung ke server. Periksa koneksi kamu.';
    }
  }
  return e.toString();
}

/// True kalau exception ini spesifik 404 Not Found — dipakai untuk
/// membedakan "belum ada data" (bukan error sungguhan) dari error lain.
bool isNotFoundError(Object e) =>
    e is DioException && e.response?.statusCode == 404;