import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_allocation_state.dart';
import '../depot_allocation_sync.dart';
import '../depot_portfolio_state.dart';

class DepotAllocationRefreshButton extends StatelessWidget {
  const DepotAllocationRefreshButton({super.key});

  @override
  Widget build(BuildContext context) {
    final portfolio = context.watch<DepotPortfolioState>();
    final allocation = context.watch<DepotAllocationState>();
    final busy = portfolio.isSyncing || allocation.isFetching;
    return IconButton(
      tooltip: AppLocalizations.of(context).depotAllocationRefresh,
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      onPressed: busy || !portfolio.isLoaded || !portfolio.isConnected
          ? null
          : () => syncDepotAllocation(portfolio, allocation),
    );
  }
}
