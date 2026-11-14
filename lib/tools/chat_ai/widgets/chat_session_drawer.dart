import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import '../chat_ai_state.dart';
import '../chat_history_groups.dart';
import '../chat_models.dart';
import 'chat_session_info.dart';

class ChatSessionDrawer extends StatelessWidget {
  const ChatSessionDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatAiState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final entries = ChatHistoryGroup.withHeadings(state.backendSessions, now);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.toolNameChatAi,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: l10n.chatAiNewChat,
                    onPressed: () {
                      state.createNewSession();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            if (state.syncingHistory)
              const LinearProgressIndicator(minHeight: 1)
            else
              const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) => switch (entries[index]) {
                  final ChatHistoryGroup group => _HistoryHeading(
                    group: group,
                    first: index == 0,
                  ),
                  final ChatSession session => _SessionTile(
                    session: session,
                    selected: session.id == state.currentSessionId,
                    now: now,
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryHeading extends StatelessWidget {
  final ChatHistoryGroup group;
  final bool first;

  const _HistoryHeading({required this.group, required this.first});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final label = switch (group.age) {
      ChatHistoryAge.today => l10n.chatAiHistoryToday,
      ChatHistoryAge.yesterday => l10n.chatAiHistoryYesterday,
      ChatHistoryAge.lastWeek => l10n.chatAiHistoryLastWeek,
      ChatHistoryAge.lastMonth => l10n.chatAiHistoryLastMonth,
      ChatHistoryAge.month => DateFormat.yMMMM(locale).format(group.month!),
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(16.0, first ? 12.0 : 20.0, 16.0, 4.0),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final bool selected;
  final DateTime now;

  const _SessionTile({
    required this.session,
    required this.selected,
    required this.now,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.read<ChatAiState>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ResponsiveAlertDialog(
        title: Text(l10n.chatAiDeleteSession),
        content: Text(l10n.chatAiDeleteSessionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirm == true) await state.deleteSession(session.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final updated = DateTime.fromMillisecondsSinceEpoch(session.updatedAt);
    final muted = theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onSecondaryTap: () => _confirmDelete(context),
      child: ListTile(
        selected: selected,
        title: Text(
          session.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                ChatSessionInfo.stamp(l10n, locale, updated, now),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ),
            if (selected)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18.0),
                color: theme.colorScheme.error,
                tooltip: l10n.chatAiDeleteSession,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32.0,
                  height: 28.0,
                ),
                onPressed: () => _confirmDelete(context),
              ),
          ],
        ),
        onTap: () {
          context.read<ChatAiState>().selectSession(session.id);
          Navigator.of(context).pop();
        },
        onLongPress: () => _confirmDelete(context),
      ),
    );
  }
}
