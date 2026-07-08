// lib/features/auth/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import '../../../core/api_client.dart';
import '../../home/providers/home_provider.dart';
import '../../chat/providers/chat_provider.dart';

// ── Storage key ───────────────────────────────────────────────────────────────
const _kToken = 'auth_token';
const _kUserId = 'auth_user_id';
const _kName = 'auth_name';
const _kEmail = 'auth_email';

// ── State: informasi user yang sedang login ───────────────────────────────────
class AuthState {
  final bool isLoggedIn;
  final String? token;
  final int? userId;
  final String? name;
  final String? email;

  const AuthState({
    required this.isLoggedIn,
    this.token,
    this.userId,
    this.name,
    this.email,
  });

  const AuthState.initial() : this(isLoggedIn: false);

  AuthState copyWith({
    bool? isLoggedIn,
    String? token,
    int? userId,
    String? name,
    String? email,
  }) => AuthState(
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    token: token ?? this.token,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    email: email ?? this.email,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AsyncValue<AuthState>> {
  final Ref _ref;
  final AuthRepository _repo;
  final FlutterSecureStorage _storage;

  AuthNotifier(this._ref, this._repo, this._storage)
    : super(const AsyncValue.loading()) {
    _restoreSession();
  }

  // BUG-004 (fixed): ProviderScope membungkus seluruh app, jadi provider
  // seperti historyProvider/sensorProvider/analyzeProvider/chatDetailProvider
  // TIDAK otomatis reset saat ganti user — cache data user lama bisa
  // "nyangkut" dan tampil ke user baru sampai widget-nya di-refresh manual.
  // Invalidate semua provider yang scope-nya per-user di sini.
  void _clearUserScopedProviders() {
    _ref.invalidate(historyProvider);
    _ref.invalidate(sensorProvider);
    _ref.invalidate(analyzeProvider);
    _ref.invalidate(chatDetailProvider);
  }

  /// Restore sesi dari secure storage saat app dibuka
  Future<void> _restoreSession() async {
    try {
      final token = await _storage.read(key: _kToken);
      final userId = await _storage.read(key: _kUserId);
      final name = await _storage.read(key: _kName);
      final email = await _storage.read(key: _kEmail);

      if (token != null && userId != null) {
        // Inject token ke Dio
        ApiClient.instance.setToken(token);
        state = AsyncValue.data(
          AuthState(
            isLoggedIn: true,
            token: token,
            userId: int.tryParse(userId),
            name: name,
            email: email,
          ),
        );
      } else {
        state = const AsyncValue.data(AuthState.initial());
      }
    } catch (e, st) {
      state = const AsyncValue.data(AuthState.initial());
    }
  }

  /// Simpan token + info user ke storage + state
  Future<void> _persistSession(AuthResponse res) async {
    await _storage.write(key: _kToken, value: res.token);
    await _storage.write(key: _kUserId, value: res.userId.toString());
    await _storage.write(key: _kName, value: res.name);
    await _storage.write(key: _kEmail, value: res.email);

    // Inject token ke Dio untuk semua request selanjutnya
    ApiClient.instance.setToken(res.token);

    // Pastikan tidak ada cache data milik user sebelumnya yang terbawa,
    // terutama kalau user login-logout-login ganti akun tanpa restart app.
    _clearUserScopedProviders();

    state = AsyncValue.data(
      AuthState(
        isLoggedIn: true,
        token: res.token,
        userId: res.userId,
        name: res.name,
        email: res.email,
      ),
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    // Hanya daftar ke server. TIDAK auto-login — RegisterPage yang akan
    // mengarahkan user kembali ke halaman Login secara eksplisit.
    await _repo.register(name: name, email: email, password: password);
  }

  Future<void> login({required String email, required String password}) async {
    // Tidak set state=loading di sini — biar tidak memicu _AuthGate
    // menampilkan splash/menghapus widget LoginPage di tengah proses.
    // Kalau gagal, exception dibiarkan lempar ke pemanggil (LoginPage),
    // BUKAN ditelan jadi AsyncValue.error di sini.
    final res = await _repo.login(email: email, password: password);
    await _persistSession(res); // state hanya berubah SEKALI, saat sukses
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    ApiClient.instance.clearToken();
    _clearUserScopedProviders();
    state = const AsyncValue.data(AuthState.initial());
  }

  /// Update nama/email/password user yang sedang login.
  /// Melempar exception ke pemanggil (ProfilePage) kalau gagal, supaya UI
  /// bisa tampilkan pesan error tanpa mengubah state auth secara keliru.
  Future<void> updateProfile({
    String? name,
    String? email,
    String? currentPassword,
    String? newPassword,
  }) async {
    final updated = await _repo.updateProfile(
      name: name,
      email: email,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    await _storage.write(key: _kName, value: updated.name);
    await _storage.write(key: _kEmail, value: updated.email);

    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(name: updated.name, email: updated.email),
      );
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _storageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(),
);

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<AuthState>>(
  (ref) {
    return AuthNotifier(
      ref,
      ref.watch(authRepositoryProvider),
      ref.watch(_storageProvider),
    );
  },
);