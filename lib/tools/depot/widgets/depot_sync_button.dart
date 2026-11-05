import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_portfolio_state.dart';

class DepotSyncButton extends StatelessWidget {
  const DepotSyncButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<DepotPortfolioState>();
    if (!state.isConnected && !state.hasData) return const SizedBox.shrink();
    final syncing = state.isSyncing;

    return IconButton(
      icon: syncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync_outlined),
      tooltip: l10n.depotSyncNow,
      onPressed: syncing ? null : state.sync,
    );
  }
}
