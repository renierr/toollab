import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/chat_ai/deepseek/deepseek_history.dart';

Map<String, dynamic> _message(
  int id,
  int? parent,
  String role,
  List<Map<String, String>> fragments,
) => {
  'message_id': id,
  'parent_id': parent,
  'role': role,
  'inserted_at': 1794607336.5 + id,
  'fragments': fragments,
};

void main() {
  test('follows the current branch', () {
    final history = DeepSeekHistory.fromJson({
      'chat_session': {'id': 's', 'current_message_id': 5},
      'chat_messages': [
        _message(1, null, 'USER', [
          {'type': 'REQUEST', 'content': 'Hi'},
        ]),
        _message(2, 1, 'ASSISTANT', [
          {'type': 'RESPONSE', 'content': 'old reply'},
        ]),
        _message(3, 1, 'ASSISTANT', [
          {'type': 'THINK', 'content': 'hmm'},
          {'type': 'RESPONSE', 'content': 'Hello'},
        ]),
        _message(4, 3, 'USER', [
          {'type': 'REQUEST', 'content': 'More'},
        ]),
        _message(5, 4, 'ASSISTANT', [
          {'type': 'SEARCH', 'content': 'ignored'},
          {'type': 'RESPONSE', 'content': 'Sure'},
        ]),
      ],
    });
    expect(history.currentMessageId, 5);
    expect(history.messages.map((m) => m.text), [
      'Hi',
      'Hello',
      'More',
      'Sure',
    ]);
    expect(history.messages.map((m) => m.fromUser), [true, false, true, false]);
    expect(history.messages[1].thinking, 'hmm');
    expect(history.messages.first.insertedAt, 1794607337500);
  });

  test('falls back to the newest message', () {
    final history = DeepSeekHistory.fromJson({
      'chat_session': {'id': 's'},
      'chat_messages': [
        _message(1, null, 'USER', [
          {'type': 'REQUEST', 'content': 'Hi'},
        ]),
        _message(2, 1, 'ASSISTANT', [
          {'type': 'RESPONSE', 'content': 'Yo'},
        ]),
      ],
    });
    expect(history.currentMessageId, 2);
    expect(history.messages, hasLength(2));
  });

  test('reads sessions', () {
    final session = DeepSeekRemoteSession.fromJson({
      'id': 'abc',
      'title': 'Katzen',
      'updated_at': 1794607336.195,
    });
    expect(session?.title, 'Katzen');
    expect(session?.updatedAt, 1794607336195);
    expect(DeepSeekRemoteSession.fromJson({'title': 'x'}), isNull);
  });
}
