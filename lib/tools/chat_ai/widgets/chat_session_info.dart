import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../chat_history_groups.dart';
import '../chat_models.dart';
import 'chat_model_picker.dart';

/// A muted line above a chat: who answers, when it started and was last
/// active, and how long it is.
class ChatSessionInfo extends StatelessWidget {
  final ChatBackend backend;
  final List<ChatMessage> messages;

  const ChatSessionInfo({
    super.key,
    required this.backend,
    required this.messages,
  });

  /// "Today 14:32", "Yesterday 09:10" or a full date and time.
  static String stamp(
    AppLocalizations l10n,
    String locale,
    DateTime time,
    DateTime now,
  ) {
    final clock = DateFormat.Hm(locale).format(time);
    return switch (ChatHistoryGroup.of(time, now).age) {
      ChatHistoryAge.today => '${l10n.chatAiHistoryToday} $clock',
      ChatHistoryAge.yesterday => '${l10n.chatAiHistoryYesterday} $clock',
      _ when time.year == now.year =>
        '${DateFormat.MMMd(locale).format(time)}, $clock',
      _ => '${DateFormat.yMMMd(locale).format(time)}, $clock',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final started = DateTime.fromMillisecondsSinceEpoch(
      messages.first.createdAt,
    );
    final last = DateTime.fromMillisecondsSinceEpoch(messages.last.createdAt);
    final muted = theme.colorScheme.onSurfaceVariant;

    final parts = [
      ChatModelPicker.modelName(backend),
      l10n.chatAiSessionStarted(stamp(l10n, locale, started, now)),
      if (last.difference(started).inMinutes >= 1)
        l10n.chatAiSessionLastActive(stamp(l10n, locale, last, now)),
      l10n.chatAiSessionMessages(messages.length),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
      child: Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 4.0),
                child: Icon(
                  ChatModelPicker.iconFor(backend),
                  size: 14.0,
                  color: muted,
                ),
              ),
            ),
            TextSpan(text: parts.join(' · ')),
          ],
        ),
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(color: muted),
      ),
    );
  }
}
