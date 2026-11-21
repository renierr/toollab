import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/markdown_view.dart';
import '../chat_models.dart';
import '../config.dart';
import 'chat_bubble_shell.dart';
import 'chat_citation.dart';
import 'chat_file_chip.dart';
import 'chat_message_actions.dart';
import 'chat_thoughts.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  /// Shown above replies, so it is clear who answered.
  final String modelName;

  /// The reply is still streaming, so its thoughts stay open.
  final bool live;

  /// Lets the reply span the full row.
  final bool expand;

  static const int _longReplyChars = 800;

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

    final showActions = !live && message.content.trim().isNotEmpty;
    final content = Column(
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
        if (message.attachments.isNotEmpty) ...[
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              for (final file in message.attachments)
                ChatFileChip(file: file, fromUser: isUser),
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
    );

    return ChatBubbleShell(
      fromUser: isUser,
      expand: expand,
      child: showActions
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 72.0),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child: content,
                  ),
                ),
                Positioned(
                  right: -10.0,
                  bottom: -10.0,
                  child: ChatMessageActions(
                    text: message.content,
                    onScrollToStart:
                        !isUser && message.content.length > _longReplyChars
                        ? () => Scrollable.ensureVisible(
                            context,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          )
                        : null,
                    color: isUser
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            )
          : content,
    );
  }
}
