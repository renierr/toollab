import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_state.dart';
import '../depot_wishlist_state.dart';

/// Adds a held security to the wishlist by its ISIN, or opens the wishlist
/// when it is already there.
class DepotWishlistHoldingButton extends StatelessWidget {
  final String isin;
  final String name;

  const DepotWishlistHoldingButton({
    super.key,
    required this.isin,
    required this.name,
  });

  Future<void> _add(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).depotWishlistAddFailed;
    final added = await context.read<DepotWishlistState>().addIsin(
      isin,
      name: name,
    );
    if (!added) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (listed, adding) = context.select<DepotWishlistState, (bool, bool)>(
      (state) => (state.containsIsin(isin), state.isAddingIsin(isin)),
    );
    if (listed) {
      return TextButton.icon(
        onPressed: () => context.read<DepotState>().setTab(DepotTab.wishlist),
        icon: const Icon(Icons.bookmark_added),
        label: Text(l10n.depotHoldingInWishlist),
      );
    }
    return TextButton.icon(
      onPressed: adding ? null : () => _add(context),
      icon: adding
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.bookmark_add_outlined),
      label: Text(l10n.depotHoldingAddToWishlist),
    );
  }
}
