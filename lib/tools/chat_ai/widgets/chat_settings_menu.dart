import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/text_size_sheet.dart';

import '../chat_ai_state.dart';
import 'chat_system_prompt_dialog.dart';

enum _ChatSetting { textSize, systemPrompt }

/// One app bar entry for the chat settings, so a phone's bar keeps room for
/// the title.
class ChatSettingsMenu extends StatelessWidget {
  const ChatSettingsMenu({super.key});

  Future<void> _editSystemPrompt(BuildContext context) async {
    final state = context.read<ChatAiState>();
    final newPrompt = await showDialog<String?>(
      context: context,
      builder: (context) => ChatSystemPromptDialog(
        currentPrompt: state.customSystemPrompt,
        defaultPrompt: ChatAiState.defaultSystemPrompt,
      ),
    );
    if (newPrompt != null) await state.updateSystemPrompt(newPrompt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_ChatSetting>(
      icon: const Icon(Icons.settings_outlined),
      tooltip: l10n.commonSettings,
      onSelected: (setting) => switch (setting) {
        _ChatSetting.textSize => TextSizeSheet.show<ChatAiState>(
          context,
          title: l10n.chatAiTextSize,
          percentOf: (state) => state.textPercent,
          onChanged: (state, percent) => state.setTextPercent(percent),
          minPercent: ChatAiState.minTextPercent,
          maxPercent: ChatAiState.maxTextPercent,
          step: ChatAiState.textPercentStep,
        ),
        _ChatSetting.systemPrompt => _editSystemPrompt(context),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _ChatSetting.textSize,
          child: ListTile(
            leading: const Icon(Icons.format_size),
            title: Text(l10n.chatAiTextSize),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _ChatSetting.systemPrompt,
          child: ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.chatAiSystemPromptTitle),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
