import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../chat_ai_state.dart';

class DeepSeekOptionsBar extends StatelessWidget {
  const DeepSeekOptionsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<ChatAiState>();
    final enabled = !state.isGenerating;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          FilterChip(
            avatar: const Icon(Icons.psychology_outlined, size: 18),
            label: Text(l10n.chatAiDeepThink),
            selected: state.deepSeekThinking,
            showCheckmark: false,
            onSelected: enabled ? state.setDeepSeekThinking : null,
          ),
          FilterChip(
            avatar: const Icon(Icons.travel_explore, size: 18),
            label: Text(l10n.chatAiDeepSeekSearch),
            selected: state.deepSeekSearch,
            showCheckmark: false,
            onSelected: enabled ? state.setDeepSeekSearch : null,
          ),
        ],
      ),
    );
  }
}
