import 'dart:typed_data';
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
              if (message['image_data'] != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Image.memory(
                    message['image_data'] as Uint8List,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8.0),
              ],
              if (message['file_name'] != null) ...[
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
                          message['file_name'] as String,
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
