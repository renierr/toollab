import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../chat_ai_state.dart';
import '../deepseek/deepseek_login_actions.dart';

enum _AccountAction { copyToken, setToken, signOut }

class DeepSeekAccountMenu extends StatelessWidget {
  const DeepSeekAccountMenu({super.key});

  Future<void> _onSelected(BuildContext context, _AccountAction action) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<ChatAiState>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    switch (action) {
      case _AccountAction.copyToken:
        final token = state.deepSeekAccount?.token;
        if (token == null) return;
        await Clipboard.setData(ClipboardData(text: token));
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.chatAiDeepSeekTokenCopied)),
        );
      case _AccountAction.setToken:
        final error = await DeepSeekLoginActions.pasteToken(context);
        if (error != null) {
          messenger?.showSnackBar(SnackBar(content: Text(error)));
        }
      case _AccountAction.signOut:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => ResponsiveAlertDialog(
            title: Text(l10n.chatAiDeepSeekSignOut),
            content: Text(l10n.chatAiDeepSeekSignOutConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(l10n.chatAiDeepSeekSignOut),
              ),
            ],
          ),
        );
        if (confirmed == true) await state.signOutDeepSeek();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<ChatAiState>();
    final account = state.deepSeekAccount;
    if (account == null) return const SizedBox.shrink();
    final name = account.name;
    return PopupMenuButton<_AccountAction>(
      icon: const Icon(Icons.account_circle_outlined),
      tooltip: name == null
          ? l10n.chatAiBackendDeepSeek
          : l10n.chatAiDeepSeekSignedInAs(name),
      enabled: !state.isGenerating,
      onSelected: (action) => _onSelected(context, action),
      itemBuilder: (context) => [
        if (name != null)
          PopupMenuItem(
            enabled: false,
            child: Text(l10n.chatAiDeepSeekSignedInAs(name)),
          ),
        PopupMenuItem(
          value: _AccountAction.copyToken,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.copy),
            title: Text(l10n.chatAiDeepSeekCopyToken),
          ),
        ),
        PopupMenuItem(
          value: _AccountAction.setToken,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.key_outlined),
            title: Text(l10n.chatAiDeepSeekSetToken),
          ),
        ),
        PopupMenuItem(
          value: _AccountAction.signOut,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: Text(l10n.chatAiDeepSeekSignOut),
          ),
        ),
      ],
    );
  }
}
