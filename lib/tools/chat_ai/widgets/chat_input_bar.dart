import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import '../config.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isGenerating;
  final bool enabled;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.isGenerating,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final accentColor = ChatAiTool.config.accentColor;

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: l10n.chatAiInputPlaceholder,
                    border: InputBorder.none,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (enabled && !isGenerating) {
                      onSend();
                    }
                  },
                  enabled: enabled && !isGenerating,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: isGenerating || !enabled
                  ? theme.colorScheme.surfaceContainerHighest
                  : accentColor,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: isGenerating || !enabled ? null : onSend,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: isGenerating
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: isGenerating || !enabled
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.3,
                                )
                              : Colors.white,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
