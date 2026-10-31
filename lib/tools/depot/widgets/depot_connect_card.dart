import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../config.dart';
import '../depot_portfolio_state.dart';
import 'depot_settings_page.dart';
import 'depot_sync_error_card.dart';

class DepotConnectCard extends StatelessWidget {
  const DepotConnectCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final error = context.watch<DepotPortfolioState>().error;

    return ReadableWidth(
      maxWidth: 520,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null) ...[
                DepotSyncErrorCard(error: error),
                const SizedBox(height: 24),
              ],
              Icon(
                Icons.pie_chart_outline,
                size: 64,
                color: DepotTool.config.accentColor,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.depotConnectTitle,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.depotConnectBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => DepotSettingsPage.open(context),
                icon: const Icon(Icons.link_outlined),
                label: Text(l10n.depotConnectAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
