import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/l10n/app_localization_delegates.dart';
import 'package:tool_lab/tools/chat_ai/widgets/chat_session_info.dart';
import 'package:tool_lab/tools/chat_ai/chat_history_groups.dart';
import 'package:tool_lab/tools/chat_ai/chat_models.dart';

void main() {
  final now = DateTime(2026, 11, 14, 10);

  ChatHistoryAge ageOf(DateTime date) => ChatHistoryGroup.of(date, now).age;

  test('chats fall into calendar day buckets', () {
    expect(ageOf(DateTime(2026, 11, 14, 0, 5)), ChatHistoryAge.today);
    expect(ageOf(DateTime(2026, 11, 13, 23, 59)), ChatHistoryAge.yesterday);
    expect(ageOf(DateTime(2026, 11, 8)), ChatHistoryAge.lastWeek);
    expect(ageOf(DateTime(2026, 11, 7)), ChatHistoryAge.lastMonth);
    expect(ageOf(DateTime(2026, 10, 16)), ChatHistoryAge.lastMonth);
    final old = ChatHistoryGroup.of(DateTime(2026, 10, 15), now);
    expect(old.age, ChatHistoryAge.month);
    expect(old.month, DateTime(2026, 10));
  });

  test('a heading opens each group once', () {
    ChatSession session(int id, DateTime updated) => ChatSession(
      id: id,
      title: '$id',
      createdAt: 0,
      updatedAt: updated.millisecondsSinceEpoch,
    );
    final entries = ChatHistoryGroup.withHeadings([
      session(1, DateTime(2026, 11, 14, 9)),
      session(2, DateTime(2026, 11, 14, 8)),
      session(3, DateTime(2026, 9, 20)),
      session(4, DateTime(2026, 9, 2)),
      session(5, DateTime(2025, 9, 2)),
    ], now);
    expect(
      entries.map(
        (e) => e is ChatHistoryGroup ? e.month?.toString() ?? e.age.name : '·',
      ),
      [
        'today',
        '·',
        '·',
        DateTime(2026, 9).toString(),
        '·',
        '·',
        DateTime(2025, 9).toString(),
        '·',
      ],
    );
  });

  testWidgets('info line names the model, start and length', (tester) async {
    final start = DateTime.now().subtract(const Duration(days: 40));
    ChatMessage message(int id, DateTime at) => ChatMessage(
      id: id,
      sessionId: 1,
      role: id.isOdd ? 'user' : 'model',
      content: 'x',
      createdAt: at.millisecondsSinceEpoch,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatSessionInfo(
            backend: ChatBackend.deepseek,
            messages: [
              message(1, start),
              message(2, start.add(const Duration(hours: 2))),
            ],
          ),
        ),
      ),
    );
    for (final part in ['DeepSeek', 'Started', 'last active', '2 messages']) {
      expect(find.textContaining(part, findRichText: true), findsOneWidget);
    }
  });
}
