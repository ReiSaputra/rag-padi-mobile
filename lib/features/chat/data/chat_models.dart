// lib/features/chat/data/chat_models.dart

// ── Chat Message ──────────────────────────────────────────────────────────────
class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final String createdAt;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: json['role'] as String,
    content: json['content'] as String,
    createdAt: json['created_at'] as String,
  );
}

// ── Chat Detail Response ──────────────────────────────────────────────────────
class ChatDetailResponse {
  final String sessionId;
  final String jawaban;
  final List<ChatMessage> history;

  const ChatDetailResponse({
    required this.sessionId,
    required this.jawaban,
    required this.history,
  });

  factory ChatDetailResponse.fromJson(Map<String, dynamic> json) =>
      ChatDetailResponse(
        sessionId: json['session_id'] as String,
        jawaban: json['jawaban'] as String,
        history: (json['history'] as List<dynamic>)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── New Chat Response (dari /chat/new) ────────────────────────────────────────
class NewChatResponse {
  final String sessionId;
  final String jawaban;
  final String createdAt;

  const NewChatResponse({
    required this.sessionId,
    required this.jawaban,
    required this.createdAt,
  });

  factory NewChatResponse.fromJson(Map<String, dynamic> json) =>
      NewChatResponse(
        sessionId: json['session_id'] as String,
        jawaban: json['jawaban'] as String,
        createdAt: json['created_at'] as String,
      );
}
