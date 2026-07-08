// lib/features/chat/providers/chat_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';

// ── Repository ────────────────────────────────────────────────────────────────
final chatRepositoryProvider = Provider<ChatRepository>(
  (_) => ChatRepository(),
);

// ══════════════════════════════════════════════════════════════════════════════
// Chat Detail Notifier
// Menyimpan list pesan aktif dalam satu sesi
// ══════════════════════════════════════════════════════════════════════════════
class ChatDetailNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final ChatRepository _repo;
  String? _sessionId;

  ChatDetailNotifier(this._repo) : super(const AsyncValue.data([]));

  String? get sessionId => _sessionId;

  /// Inisialisasi dari sesi yang sudah ada (buka dari histori / setelah /analyze)
  void loadFromHistory(String sessionId, List<ChatMessage> messages) {
    _sessionId = sessionId;
    state = AsyncValue.data(List.from(messages));
  }

  Future<void> loadSession(String sessionId) async {
    _sessionId = sessionId;
    state = const AsyncValue.loading();
    try {
      final res = await _repo.fetchDetail(sessionId);
      state = AsyncValue.data(res.history);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Buat sesi chat mandiri baru (FAB '+')
  Future<void> startNewChat(String message) async {
    state = const AsyncValue.loading();
    try {
      final res = await _repo.newChat(message);
      _sessionId = res.sessionId;
      state = AsyncValue.data([
        ChatMessage(role: 'user', content: message, createdAt: res.createdAt),
        ChatMessage(
          role: 'assistant',
          content: res.jawaban,
          createdAt: res.createdAt,
        ),
      ]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Kirim pesan lanjutan dalam sesi aktif
  Future<void> sendMessage(String message) async {
    if (_sessionId == null) return;

    final now = DateTime.now().toIso8601String();
    final current = state.value ?? [];
    state = AsyncValue.data([
      ...current,
      ChatMessage(role: 'user', content: message, createdAt: now),
    ]);

    try {
      final res = await _repo.sendMessage(_sessionId!, message);
      state = AsyncValue.data(res.history);
    } catch (e, st) {
      // Rollback ke history sebelum optimistic update — ini yang akan
      // tetap terlihat di layar (bukan ditimpa AsyncValue.error).
      state = AsyncValue.data(current);
      // Lempar ulang supaya UI (ChatDetailPage._send) bisa tampilkan
      // snackbar error tanpa mengganti seluruh state chat jadi layar error.
      rethrow;
    }
  }

  void reset() {
    _sessionId = null;
    state = const AsyncValue.data([]);
  }
}

final chatDetailProvider =
    StateNotifierProvider<ChatDetailNotifier, AsyncValue<List<ChatMessage>>>((
      ref,
    ) {
      return ChatDetailNotifier(ref.watch(chatRepositoryProvider));
    });
