import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_wishlist_state.dart';

class DepotWishlistRefreshButton extends StatelessWidget {
  const DepotWishlistRefreshButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<DepotWishlistState>();
    final refreshing = state.isRefreshing;

    return IconButton(
      icon: refreshing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      tooltip: l10n.depotWishlistRefresh,
      onPressed: refreshing ? null : () => state.refresh(),
    );
  }
}
