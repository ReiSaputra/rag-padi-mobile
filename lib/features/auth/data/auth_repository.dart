// lib/features/auth/data/auth_repository.dart

import '../../../core/api_client.dart';
import 'auth_models.dart';

class AuthRepository {
  final _dio = ApiClient.instance.dio;

  /// POST /auth/register
  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/auth/register',
      data: {'name': name, 'email': email, 'password': password},
    );
    return AuthResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /auth/login
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /auth/me
  Future<UserInfo> me() async {
    final res = await _dio.get('/auth/me');
    return UserInfo.fromJson(res.data as Map<String, dynamic>);
  }

  /// PUT /auth/me — update nama/email dan/atau password.
  /// Semua parameter opsional: kirim hanya yang ingin diubah.
  /// Kalau mau ganti password, [currentPassword] wajib diisi dan harus
  /// cocok dengan password saat ini (divalidasi di backend).
  Future<UserInfo> updateProfile({
    String? name,
    String? email,
    String? currentPassword,
    String? newPassword,
  }) async {
    final data = <String, dynamic>{
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (currentPassword != null) 'current_password': currentPassword,
      if (newPassword != null) 'new_password': newPassword,
    };
    final res = await _dio.put('/auth/me', data: data);
    return UserInfo.fromJson(res.data as Map<String, dynamic>);
  }
}