/// A conversation in the account's history.
class DeepSeekRemoteSession {
  final String id;
  final String title;
  final int updatedAt;

  const DeepSeekRemoteSession({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  static DeepSeekRemoteSession? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    return DeepSeekRemoteSession(
      id: id,
      title: json['title'] as String? ?? '',
      updatedAt: _millis(json['updated_at']),
    );
  }
}

class DeepSeekHistoryMessage {
  final int id;
  final bool fromUser;
  final String text;
  final String thinking;
  final int insertedAt;

  const DeepSeekHistoryMessage({
    required this.id,
    required this.fromUser,
    required this.text,
    required this.thinking,
    required this.insertedAt,
  });
}

/// The messages of one conversation along its current branch; edits and
/// regenerated replies leave other branches the web app can switch to.
class DeepSeekHistory {
  final List<DeepSeekHistoryMessage> messages;

  /// The reply the next message continues from.
  final int? currentMessageId;

  const DeepSeekHistory({required this.messages, this.currentMessageId});

  factory DeepSeekHistory.fromJson(Map<String, dynamic> json) {
    final byId = <int, Map<String, dynamic>>{};
    final raw = json['chat_messages'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map<String, dynamic>) continue;
        final id = (item['message_id'] as num?)?.toInt();
        if (id != null) byId[id] = item;
      }
    }
    final session = json['chat_session'];
    var current = session is Map
        ? (session['current_message_id'] as num?)?.toInt()
        : null;
    if (current == null || !byId.containsKey(current)) {
      current = byId.isEmpty ? null : byId.keys.reduce((a, b) => a > b ? a : b);
    }

    final branch = <DeepSeekHistoryMessage>[];
    final seen = <int>{};
    for (int? id = current; id != null && seen.add(id);) {
      final item = byId[id];
      if (item == null) break;
      branch.add(_message(id, item));
      id = (item['parent_id'] as num?)?.toInt();
    }
    return DeepSeekHistory(
      messages: branch.reversed.toList(),
      currentMessageId: current,
    );
  }

  static DeepSeekHistoryMessage _message(int id, Map<String, dynamic> item) {
    final text = StringBuffer();
    final thinking = StringBuffer();
    final fragments = item['fragments'];
    if (fragments is List) {
      for (final fragment in fragments) {
        if (fragment is! Map) continue;
        final content = fragment['content'];
        if (content is! String) continue;
        switch (fragment['type']) {
          case 'THINK':
            thinking.write(content);
          case 'REQUEST' || 'RESPONSE':
            text.write(content);
        }
      }
    }
    return DeepSeekHistoryMessage(
      id: id,
      fromUser: item['role'] == 'USER',
      text: text.toString(),
      thinking: thinking.toString(),
      insertedAt: _millis(item['inserted_at']),
    );
  }
}

/// The API sends times as fractional Unix seconds.
int _millis(Object? seconds) => seconds is num ? (seconds * 1000).round() : 0;
