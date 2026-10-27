import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../depot_wishlist_state.dart';
import 'depot_wishlist_add_dialog.dart';
import 'depot_wishlist_detail_dialog.dart';
import 'depot_wishlist_row.dart';

class DepotWishlistView extends StatefulWidget {
  const DepotWishlistView({super.key});

  @override
  State<DepotWishlistView> createState() => _DepotWishlistViewState();
}

class _DepotWishlistViewState extends State<DepotWishlistView> {
  @override
  void initState() {
    super.initState();
    final state = context.read<DepotWishlistState>();
    WidgetsBinding.instance.addPostFrameCallback((_) => state.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<DepotWishlistState>();

    if (!state.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.loadFailed) {
      return Center(child: Text(l10n.depotWishlistLoadFailed));
    }

    final items = state.itemsByDayChange;

    return RefreshIndicator(
      onRefresh: state.refresh,
      child: ReadableWidth(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (state.isRefreshing)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              sliver: SliverList.list(
                children: const [_LocalOnlyNote(), _CurrencySwitch()],
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 16, 32, 48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star_outline,
                        size: 48,
                        color: theme.hintColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.depotWishlistEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.depotWishlistEmptyHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: () => DepotWishlistAddDialog.show(context),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.depotWishlistAdd),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 64),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return DepotWishlistRow(
                      item: item,
                      quote: state.quoteFor(item.symbol),
                      euroRate: state.displayEuroRate(
                        state.quoteFor(item.symbol)?.currency ?? item.currency,
                      ),
                      logoBytes: state.logoFor(item.symbol),
                      failed: state.failed.contains(item.symbol),
                      onTap: () =>
                          DepotWishlistDetailDialog.show(context, item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CurrencySwitch extends StatelessWidget {
  const _CurrencySwitch();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<DepotWishlistState>();
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(l10n.depotWishlistShowEuro),
      subtitle: Text(l10n.depotWishlistEuroSwitchHint),
      value: state.showEuro,
      onChanged: state.setShowEuro,
    );
  }
}

class _LocalOnlyNote extends StatelessWidget {
  const _LocalOnlyNote();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: theme.hintColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.depotWishlistLocalOnly,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
