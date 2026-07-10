// lib/features/auth/data/auth_models.dart

class AuthResponse {
  final String token;
  final int userId;
  final String name;
  final String email;

  const AuthResponse({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    token: json['token'] as String,
    userId: json['user_id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
  );
}

class UserInfo {
  final int userId;
  final String name;
  final String email;
  final String createdAt;

  const UserInfo({
    required this.userId,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
    userId: json['user_id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    createdAt: json['created_at'] as String,
  );
}

/// Hasil PUT /auth/me. Membawa [token] baru HANYA kalau password baru saja
/// diganti (backend menaikkan token_version saat itu, jadi token lama
/// otomatis invalid — token baru ini menggantikannya supaya device sendiri
/// tidak ikut ter-logout paksa oleh perubahan yang dia lakukan sendiri).
class ProfileUpdateResponse {
  final UserInfo user;
  final String? token;

  const ProfileUpdateResponse({required this.user, this.token});

  factory ProfileUpdateResponse.fromJson(Map<String, dynamic> json) =>
      ProfileUpdateResponse(
        user: UserInfo.fromJson(json),
        token: json['token'] as String?,
      );
}