import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/info_card.dart';

class PaperlessConnectionCard extends StatelessWidget {
  final String serverUrl;
  final String? username;
  final bool busy;
  final VoidCallback onTest;
  final VoidCallback onDisconnect;

  const PaperlessConnectionCard({
    super.key,
    required this.serverUrl,
    required this.username,
    required this.busy,
    required this.onTest,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return InfoCard(
      icon: Icons.link,
      title: l10n.paperlessConnected,
      titleColor: AppTheme.statusGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(serverUrl, style: theme.textTheme.bodyMedium),
          if (username != null)
            Text(
              l10n.paperlessSignedInAs(username!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton.icon(
                onPressed: busy ? null : onDisconnect,
                icon: const Icon(Icons.link_off),
                label: Text(l10n.paperlessDisconnect),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onTest,
                icon: const Icon(Icons.network_check),
                label: Text(l10n.paperlessTestConnection),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
