import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class ChatSystemPromptDialog extends StatefulWidget {
  final String currentPrompt;
  final String defaultPrompt;

  const ChatSystemPromptDialog({
    super.key,
    required this.currentPrompt,
    required this.defaultPrompt,
  });

  @override
  State<ChatSystemPromptDialog> createState() => _ChatSystemPromptDialogState();
}

class _ChatSystemPromptDialogState extends State<ChatSystemPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentPrompt.isNotEmpty
          ? widget.currentPrompt
          : widget.defaultPrompt,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ResponsiveAlertDialog(
      title: Text(l10n.chatAiSystemPromptTitle),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.chatAiSystemPromptDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: _controller,
                maxLines: 6,
                minLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: widget.defaultPrompt,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            setState(() {
              _controller.text = widget.defaultPrompt;
            });
          },
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(l10n.commonReset),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(_controller.text.trim());
          },
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text(l10n.commonSave),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }
}
