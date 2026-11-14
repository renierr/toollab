import 'dart:convert';
import 'dart:typed_data';

/// Who answers a chat: Gemini Nano on the device or the DeepSeek web account.
enum ChatBackend {
  nano,
  deepseek;

  static ChatBackend fromName(String? name) =>
      ChatBackend.values.where((b) => b.name == name).firstOrNull ?? nano;
}

/// A chat conversation. Built from a `chat_sessions` row.
class ChatSession {
  final int id;
  final String title;
  final int createdAt;
  final int updatedAt;
  final ChatBackend backend;

  /// The DeepSeek conversation id and the reply the next message answers.
  final String? remoteId;
  final int? remoteParentId;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.backend = ChatBackend.nano,
    this.remoteId,
    this.remoteParentId,
  });

  factory ChatSession.fromMap(Map<String, dynamic> map) => ChatSession(
    id: map['id'] as int? ?? 0,
    title: map['title'] as String? ?? '',
    createdAt: map['created_at'] as int? ?? 0,
    updatedAt: map['updated_at'] as int? ?? 0,
    backend: ChatBackend.fromName(map['backend'] as String?),
    remoteId: map['remote_id'] as String?,
    remoteParentId: map['remote_parent_id'] as int?,
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
  final String? thinking;
  final int createdAt;

  /// Web sources a DeepSeek reply cites as `[citation:N]`.
  final List<ChatCitation> citations;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.imageData,
    this.fileName,
    this.fileContent,
    this.thinking,
    required this.createdAt,
    this.citations = const [],
  });

  bool get isUser => role == 'user';
  bool get hasAttachedFile => fileName != null && fileContent != null;

  /// A DeepSeek message can carry several files, stored one name per line.
  List<String> get fileNames => fileName?.split('\n') ?? const [];

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'] as int? ?? 0,
    sessionId: map['session_id'] as int? ?? 0,
    role: map['role'] as String? ?? 'model',
    content: map['content'] as String? ?? '',
    imageData: map['image_data'] as Uint8List?,
    fileName: map['file_name'] as String?,
    fileContent: map['file_content'] as String?,
    thinking: map['thinking'] as String?,
    createdAt: map['created_at'] as int? ?? 0,
    citations: ChatCitation.decodeList(map['citations'] as String?),
  );
}

/// A search result a reply cites; [index] is the `N` of `[citation:N]`.
class ChatCitation {
  final int index;
  final String url;
  final String title;
  final String snippet;
  final String siteName;

  const ChatCitation({
    required this.index,
    required this.url,
    this.title = '',
    this.snippet = '',
    this.siteName = '',
  });

  static ChatCitation? fromJson(Object? json) {
    if (json is! Map) return null;
    final index = json['cite_index'];
    final url = json['url'];
    if (index is! num || url is! String || url.isEmpty) return null;
    return ChatCitation(
      index: index.toInt(),
      url: url,
      title: json['title'] as String? ?? '',
      snippet: json['snippet'] as String? ?? '',
      siteName: json['site_name'] as String? ?? '',
    );
  }

  static List<ChatCitation> fromJsonList(Object? json) => [
    if (json is List)
      for (final item in json) ?fromJson(item),
  ];

  Map<String, Object> toJson() => {
    'cite_index': index,
    'url': url,
    'title': title,
    'snippet': snippet,
    'site_name': siteName,
  };

  static String? encodeList(List<ChatCitation> citations) => citations.isEmpty
      ? null
      : jsonEncode([for (final c in citations) c.toJson()]);

  static List<ChatCitation> decodeList(String? text) {
    if (text == null || text.isEmpty) return const [];
    try {
      return fromJsonList(jsonDecode(text));
    } on FormatException {
      return const [];
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ChatCitation &&
      other.index == index &&
      other.url == url &&
      other.title == title &&
      other.snippet == snippet &&
      other.siteName == siteName;

  @override
  int get hashCode => Object.hash(index, url, title, snippet, siteName);
}
