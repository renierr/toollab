import 'chat_models.dart';

enum ChatHistoryAge { today, yesterday, lastWeek, lastMonth, month }

/// The age bucket a chat is listed under in the history; older chats are
/// grouped by calendar [month].
class ChatHistoryGroup {
  final ChatHistoryAge age;
  final DateTime? month;

  const ChatHistoryGroup(this.age, [this.month]);

  factory ChatHistoryGroup.of(DateTime date, DateTime now) {
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(date.year, date.month, date.day)).inDays;
    if (days <= 0) return const ChatHistoryGroup(ChatHistoryAge.today);
    if (days == 1) return const ChatHistoryGroup(ChatHistoryAge.yesterday);
    if (days < 7) return const ChatHistoryGroup(ChatHistoryAge.lastWeek);
    if (days < 30) return const ChatHistoryGroup(ChatHistoryAge.lastMonth);
    return ChatHistoryGroup(
      ChatHistoryAge.month,
      DateTime(date.year, date.month),
    );
  }

  /// [sessions] newest first, with a heading before every new group.
  static List<Object> withHeadings(List<ChatSession> sessions, DateTime now) {
    final entries = <Object>[];
    ChatHistoryGroup? current;
    for (final session in sessions) {
      final group = ChatHistoryGroup.of(
        DateTime.fromMillisecondsSinceEpoch(session.updatedAt),
        now,
      );
      if (group != current) entries.add(current = group);
      entries.add(session);
    }
    return entries;
  }

  @override
  bool operator ==(Object other) =>
      other is ChatHistoryGroup && other.age == age && other.month == month;

  @override
  int get hashCode => Object.hash(age, month);
}
