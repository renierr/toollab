import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// A thinking model's reasoning, folded away unless it is still streaming.
class ChatThoughts extends StatefulWidget {
  final String text;
  final bool live;

  const ChatThoughts({super.key, required this.text, this.live = false});

  @override
  State<ChatThoughts> createState() => _ChatThoughtsState();
}

class _ChatThoughtsState extends State<ChatThoughts> {
  bool? _expanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final expanded = _expanded ?? widget.live;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.live)
                    SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: muted,
                      ),
                    )
                  else
                    Icon(Icons.psychology_outlined, size: 18, color: muted),
                  const SizedBox(width: 6),
                  Text(
                    widget.live ? l10n.chatAiThinking : l10n.chatAiThoughts,
                    style: theme.textTheme.labelMedium?.copyWith(color: muted),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: muted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
              ),
              child: SelectableText(
                widget.text,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
        ],
      ),
    );
  }
}
