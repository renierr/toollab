import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

/// Manual login with the `userToken` copied from a browser, for systems
/// without a WebView or a login the WebView cannot finish.
class DeepSeekTokenDialog extends StatefulWidget {
  const DeepSeekTokenDialog({super.key});

  static Future<String?> show(BuildContext context) => showDialog<String>(
    context: context,
    builder: (_) => const DeepSeekTokenDialog(),
  );

  @override
  State<DeepSeekTokenDialog> createState() => _DeepSeekTokenDialogState();
}

class _DeepSeekTokenDialogState extends State<DeepSeekTokenDialog>
    with DisposeCleanup {
  final TextEditingController _token = TextEditingController();

  @override
  void initState() {
    super.initState();
    onDispose(_token.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final token = _token.text.trim();
    return ResponsiveAlertDialog(
      scrollable: true,
      title: Text(l10n.chatAiDeepSeekPasteToken),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.chatAiDeepSeekTokenHelp),
          const SizedBox(height: 16),
          TextField(
            controller: _token,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'userToken',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: token.isEmpty
              ? null
              : () => Navigator.of(context).pop(token),
          child: Text(l10n.chatAiDeepSeekLoginButton),
        ),
      ],
    );
  }
}
