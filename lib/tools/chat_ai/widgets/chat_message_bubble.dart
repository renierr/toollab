import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/markdown_view.dart';
import '../chat_models.dart';
import '../config.dart';
import '../deepseek/deepseek_attachment.dart';
import 'chat_bubble_shell.dart';
import 'chat_citation.dart';
import 'chat_thoughts.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  /// Shown above replies, so it is clear who answered.
  final String modelName;

  /// The reply is still streaming, so its thoughts stay open.
  final bool live;

  /// Lets the reply span the full row.
  final bool expand;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.modelName,
    this.live = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);
    final accentColor = ChatAiTool.config.accentColor;

    return ChatBubbleShell(
      fromUser: isUser,
      expand: expand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isUser ? AppLocalizations.of(context).chatAiYou : modelName,
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
          if (message.fileNames.isNotEmpty) ...[
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                for (final name in message.fileNames)
                  _FileChip(name: name, fromUser: isUser),
              ],
            ),
            const SizedBox(height: 8.0),
          ],
          if (message.thinking case final thinking? when thinking.isNotEmpty)
            ChatThoughts(text: thinking, live: live && message.content.isEmpty),
          if (isUser)
            SelectableText(
              message.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            )
          else if (message.content.isNotEmpty)
            MarkdownView(
              data: message.content,
              selectable: true,
              accentColor: accentColor,
              inlineSyntaxes: [CitationSyntax.instance],
              builders: {
                CitationSyntax.tag: CitationBuilder(
                  citations: message.citations,
                  color: accentColor,
                ),
              },
              // The style sheet replaces the inherited scaler, so pass it on.
              scale: MediaQuery.textScalerOf(context).scale(1),
            ),
        ],
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  final String name;
  final bool fromUser;

  const _FileChip({required this.name, required this.fromUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: fromUser
            ? scheme.onPrimaryContainer.withValues(alpha: 0.1)
            : scheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: fromUser
              ? scheme.onPrimaryContainer.withValues(alpha: 0.2)
              : scheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            DeepSeekAttachment.isImageName(name)
                ? Icons.image_outlined
                : Icons.insert_drive_file_outlined,
            color: fromUser ? scheme.onPrimaryContainer : scheme.primary,
          ),
          const SizedBox(width: 8.0),
          Flexible(
            child: Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: fromUser ? scheme.onPrimaryContainer : scheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
