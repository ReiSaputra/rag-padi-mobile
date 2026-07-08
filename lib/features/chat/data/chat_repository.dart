// lib/features/chat/data/chat_repository.dart

import '../../../core/api_client.dart';
import 'chat_models.dart';

class ChatRepository {
  final _dio = ApiClient.instance.dio;

  /// POST /chat/new — buat sesi chat mandiri
  Future<NewChatResponse> newChat(String message) async {
    final res = await _dio.post('/chat/new', data: {'message': message});
    return NewChatResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /chat/{session_id} — ambil history sesi TANPA kirim pesan baru
  Future<ChatDetailResponse> fetchDetail(String sessionId) async {
    final res = await _dio.get('/chat/$sessionId');
    return ChatDetailResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /chat/{session_id} — kirim pesan lanjutan
  Future<ChatDetailResponse> sendMessage(
    String sessionId,
    String message,
  ) async {
    final res = await _dio.post('/chat/$sessionId', data: {'message': message});
    return ChatDetailResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// DELETE /chat/{session_id} — hapus sesi chat beserta seluruh pesannya
  Future<void> deleteChat(String sessionId) async {
    await _dio.delete('/chat/$sessionId');
  }
}
