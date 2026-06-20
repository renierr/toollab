import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/markdown_view.dart';
import '../config.dart';

class ChatMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;

  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message['role'] == 'user';
    final theme = Theme.of(context);
    final accentColor = ChatAiTool.config.accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          decoration: BoxDecoration(
            color: isUser
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16.0),
              topRight: const Radius.circular(16.0),
              bottomLeft: isUser ? const Radius.circular(16.0) : Radius.zero,
              bottomRight: isUser ? Radius.zero : const Radius.circular(16.0),
            ),
          ),
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isUser ? 'You' : 'AI',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isUser
                      ? theme.colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.7,
                        )
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4.0),
              if (isUser)
                SelectableText(
                  message['content'] as String,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                )
              else
                MarkdownView(
                  data: message['content'] as String,
                  selectable: true,
                  accentColor: accentColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
