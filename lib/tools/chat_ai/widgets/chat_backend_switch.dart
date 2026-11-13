import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../chat_ai_state.dart';
import '../chat_models.dart';

class ChatBackendSwitch extends StatelessWidget {
  const ChatBackendSwitch({super.key});

  static IconData iconFor(ChatBackend backend) => switch (backend) {
    ChatBackend.nano => Icons.smartphone,
    ChatBackend.deepseek => Icons.cloud_outlined,
  };

  static String modelName(ChatBackend backend) => switch (backend) {
    ChatBackend.nano => 'Gemini Nano',
    ChatBackend.deepseek => 'DeepSeek',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<ChatAiState>();
    return ReadableWidth(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: SegmentedButton<ChatBackend>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: ChatBackend.nano,
              icon: Icon(iconFor(ChatBackend.nano)),
              label: Text(l10n.chatAiModeLocal),
              tooltip: l10n.chatAiBackendNano,
            ),
            ButtonSegment(
              value: ChatBackend.deepseek,
              icon: Icon(iconFor(ChatBackend.deepseek)),
              label: Text(modelName(ChatBackend.deepseek)),
              tooltip: l10n.chatAiBackendDeepSeek,
            ),
          ],
          selected: {state.backend},
          onSelectionChanged: state.isGenerating
              ? null
              : (selection) => state.setBackend(selection.first),
        ),
      ),
    );
  }
}
