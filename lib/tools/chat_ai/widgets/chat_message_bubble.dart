import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/markdown_view.dart';
import '../chat_models.dart';
import '../config.dart';
import 'chat_bubble_shell.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);
    final accentColor = ChatAiTool.config.accentColor;

    return ChatBubbleShell(
      fromUser: isUser,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isUser ? 'You' : 'AI',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isUser
                  ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4.0),
          if (message.imageData != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Image.memory(message.imageData!, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8.0),
          ],
          if (message.fileName != null) ...[
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.1,
                      )
                    : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: isUser
                      ? theme.colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.2,
                        )
                      : theme.colorScheme.outline.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.insert_drive_file_outlined,
                    color: isUser
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8.0),
                  Flexible(
                    child: Text(
                      message.fileName!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isUser
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8.0),
          ],
          if (isUser)
            SelectableText(
              message.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            )
          else
            MarkdownView(
              data: message.content,
              selectable: true,
              accentColor: accentColor,
            ),
        ],
      ),
    );
  }
}
