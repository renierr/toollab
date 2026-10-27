import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../depot_portfolio_labels.dart';
import '../depot_wishlist_state.dart';
import '../models/depot_wishlist.dart';
import 'depot_holding_avatar.dart';

/// Searches Yahoo Finance and adds one security to the local wishlist.
class DepotWishlistAddDialog extends StatefulWidget {
  const DepotWishlistAddDialog({super.key});

  static Future<void> show(BuildContext context) {
    context.read<DepotWishlistState>().clearSearch();
    return showDialog<void>(
      context: context,
      builder: (_) => const DepotWishlistAddDialog(),
    );
  }

  @override
  State<DepotWishlistAddDialog> createState() => _DepotWishlistAddDialogState();
}

class _DepotWishlistAddDialogState extends State<DepotWishlistAddDialog> {
  late final DepotWishlistState _state = context.read<DepotWishlistState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add(DepotWishlistSearchResult result) async {
    if (_state.isAdding(result.symbol)) return;
    final added = await _state.add(result);
    if (!mounted) return;
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).depotWishlistAddFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<DepotWishlistState>();
    // Leaves room for the title and actions on short screens.
    final height = (MediaQuery.sizeOf(context).height * 0.55).clamp(
      240.0,
      400.0,
    );

    return ResponsiveAlertDialog(
      title: Text(l10n.depotWishlistAddTitle),
      content: SizedBox(
        width: 420,
        height: height,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: state.search,
              decoration: InputDecoration(
                hintText: l10n.depotWishlistSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.commonClose,
                        onPressed: () {
                          _controller.clear();
                          state.clearSearch();
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _SearchResults(state: state, onAdd: _add),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  final DepotWishlistState state;
  final ValueChanged<DepotWishlistSearchResult> onAdd;

  const _SearchResults({required this.state, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (state.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.searchFailed) {
      return Center(
        child: Text(
          l10n.depotWishlistSearchFailed,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    if (state.query.trim().length < 2) {
      return Center(
        child: Text(
          l10n.depotWishlistSearchHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      );
    }
    if (state.results.isEmpty) {
      return Center(
        child: Text(
          l10n.depotWishlistNoResults,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return ListView.separated(
      itemCount: state.results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = state.results[index];
        final added = state.contains(result.symbol);
        return _SearchResultTile(
          result: result,
          added: added,
          pending: state.isAdding(result.symbol),
          onAdd: () => onAdd(result),
        );
      },
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final DepotWishlistSearchResult result;
  final bool added;
  final bool pending;
  final VoidCallback onAdd;

  const _SearchResultTile({
    required this.result,
    required this.added,
    required this.pending,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: DepotHoldingAvatar(
        name: result.name,
        colorSeed: result.symbol,
        size: 32,
      ),
      title: Text(
        result.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(
        [
          result.symbol,
          if (result.exchange.isNotEmpty) result.exchange,
          DepotPortfolioLabels.kind(l10n, result.kind),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: added
          ? Tooltip(
              message: l10n.depotWishlistAlreadyAdded,
              child: const Icon(Icons.check_circle_outline),
            )
          : pending
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: l10n.depotWishlistAdd,
              onPressed: onAdd,
            ),
      onTap: added || pending ? null : onAdd,
    );
  }
}
