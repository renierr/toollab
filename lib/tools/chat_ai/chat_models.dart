import 'dart:typed_data';

/// A chat conversation. Built from a `chat_sessions` row.
class ChatSession {
  final int id;
  final String title;
  final int createdAt;
  final int updatedAt;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSession.fromMap(Map<String, dynamic> map) => ChatSession(
    id: map['id'] as int? ?? 0,
    title: map['title'] as String? ?? '',
    createdAt: map['created_at'] as int? ?? 0,
    updatedAt: map['updated_at'] as int? ?? 0,
  );
}

/// One message in a session. Built from a `chat_messages` row.
class ChatMessage {
  final int id;
  final int sessionId;
  final String role;
  final String content;
  final Uint8List? imageData;
  final String? fileName;
  final String? fileContent;
  final int createdAt;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.imageData,
    this.fileName,
    this.fileContent,
    required this.createdAt,
  });

  bool get isUser => role == 'user';
  bool get hasAttachedFile => fileName != null && fileContent != null;

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'] as int? ?? 0,
    sessionId: map['session_id'] as int? ?? 0,
    role: map['role'] as String? ?? 'model',
    content: map['content'] as String? ?? '',
    imageData: map['image_data'] as Uint8List?,
    fileName: map['file_name'] as String?,
    fileContent: map['file_content'] as String?,
    createdAt: map['created_at'] as int? ?? 0,
  );
}
