import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../chat_ai_state.dart';
import '../chat_models.dart';
import 'chat_model_picker.dart';

/// The model picker and, for DeepSeek, its DeepThink and search toggles.
class ChatOptionsBar extends StatelessWidget {
  const ChatOptionsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<ChatAiState>();
    final enabled = !state.isGenerating;
    final deepSeek = state.backend == ChatBackend.deepseek;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Labels go before anything would wrap onto a second line.
          final cramped = constraints.maxWidth < 440;
          // Scrolls rather than overflows under a very large system font.
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChatModelPicker(compact: cramped),
                if (deepSeek) ...[
                  const SizedBox(width: 8),
                  _OptionChip(
                    icon: Icons.psychology_outlined,
                    label: l10n.chatAiDeepThink,
                    compact: cramped,
                    selected: state.deepSeekThinking,
                    onSelected: enabled ? state.setDeepSeekThinking : null,
                  ),
                  const SizedBox(width: 8),
                  _OptionChip(
                    icon: Icons.travel_explore,
                    label: l10n.chatAiDeepSeekSearch,
                    compact: cramped,
                    selected: state.deepSeekSearch,
                    onSelected: enabled ? state.setDeepSeekSearch : null,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const _OptionChip({
    required this.icon,
    required this.label,
    required this.compact,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final chip = FilterChip(
      avatar: Icon(icon, size: 18),
      label: compact
          ? const SizedBox.shrink()
          : Text(label, maxLines: 1, softWrap: false),
      labelPadding: compact ? EdgeInsets.zero : null,
      selected: selected,
      showCheckmark: false,
      onSelected: onSelected,
    );
    return compact ? Tooltip(message: label, child: chip) : chip;
  }
}
