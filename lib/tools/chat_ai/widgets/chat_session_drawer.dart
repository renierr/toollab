import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import '../chat_ai_state.dart';

class ChatSessionDrawer extends StatelessWidget {
  const ChatSessionDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatAiState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

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
                      Navigator.of(context).pop(); // Close drawer
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: state.sessions.length,
                itemBuilder: (context, index) {
                  final session = state.sessions[index];
                  final isSelected = session.id == state.currentSessionId;

                  return ListTile(
                    selected: isSelected,
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isSelected
                        ? IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.error,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => ResponsiveAlertDialog(
                                  title: Text(l10n.chatAiDeleteSession),
                                  content: Text(
                                    l10n.chatAiDeleteSessionConfirm,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: Text(l10n.commonCancel),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            theme.colorScheme.error,
                                      ),
                                      child: Text(l10n.commonDelete),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await state.deleteSession(session.id);
                              }
                            },
                          )
                        : null,
                    onTap: () {
                      state.selectSession(session.id);
                      Navigator.of(context).pop(); // Close drawer
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
