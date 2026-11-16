import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/popup_menu_tile.dart';

import '../chat_ai_state.dart';
import '../chat_models.dart';

/// A small chip naming who answers; it opens a menu to switch models.
class ChatModelPicker extends StatelessWidget {
  /// Shows only the icon, for a cramped row.
  final bool compact;

  const ChatModelPicker({super.key, this.compact = false});

  static IconData iconFor(ChatBackend backend) => switch (backend) {
    ChatBackend.nano => Icons.smartphone,
    ChatBackend.deepseek => Icons.cloud_outlined,
  };

  static String modelName(ChatBackend backend) => switch (backend) {
    ChatBackend.nano => 'Gemini Nano',
    ChatBackend.deepseek => 'DeepSeek',
  };

  static String _shortName(AppLocalizations l10n, ChatBackend backend) =>
      switch (backend) {
        ChatBackend.nano => l10n.chatAiModeLocal,
        ChatBackend.deepseek => modelName(backend),
      };

  static String _description(AppLocalizations l10n, ChatBackend backend) =>
      switch (backend) {
        ChatBackend.nano => l10n.chatAiBackendNano,
        ChatBackend.deepseek => l10n.chatAiBackendDeepSeek,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final backend = context.select<ChatAiState, ChatBackend>((s) => s.backend);
    final busy = context.select<ChatAiState, bool>((s) => s.isGenerating);

    return PopupMenuButton<ChatBackend>(
      enabled: !busy,
      tooltip: _description(l10n, backend),
      initialValue: backend,
      onSelected: context.read<ChatAiState>().setBackend,
      itemBuilder: (context) => [
        for (final option in ChatBackend.values)
          PopupMenuItem(
            value: option,
            child: PopupMenuTile(
              leading: Icon(iconFor(option)),
              title: Text(_description(l10n, option)),
              trailing: option == backend ? const Icon(Icons.check) : null,
            ),
          ),
      ],
      child: Container(
        height: 32.0,
        padding: const EdgeInsets.only(left: 10.0, right: 4.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconFor(backend), size: 18.0, color: scheme.primary),
            if (!compact) ...[
              const SizedBox(width: 6.0),
              Text(
                _shortName(l10n, backend),
                maxLines: 1,
                softWrap: false,
                style: theme.textTheme.labelLarge,
              ),
            ],
            Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
