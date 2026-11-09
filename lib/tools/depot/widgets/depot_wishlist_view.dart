import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../depot_wishlist_state.dart';
import 'depot_wishlist_add_dialog.dart';
import 'depot_wishlist_detail_dialog.dart';
import 'depot_wishlist_row.dart';

class DepotWishlistView extends StatefulWidget {
  final GlobalKey captureKey;

  const DepotWishlistView({super.key, required this.captureKey});

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

    return ReadableScrollPadding(
      builder: (context, inset) => Column(
        children: [
          Padding(
            padding: inset + const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: const _CurrencySwitch(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: state.refresh,
              child: RepaintBoundary(
                key: widget.captureKey,
                child: ColoredBox(
                  color: theme.scaffoldBackgroundColor,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (state.isRefreshing)
                        SliverPadding(
                          padding: inset,
                          sliver: const SliverToBoxAdapter(
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        ),
                      if (items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding:
                                inset +
                                const EdgeInsets.fromLTRB(32, 16, 32, 48),
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
                                  onPressed: () =>
                                      DepotWishlistAddDialog.show(context),
                                  icon: const Icon(Icons.add),
                                  label: Text(l10n.depotWishlistAdd),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: inset + const EdgeInsets.only(bottom: 24),
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
                                  state.quoteFor(item.symbol)?.currency ??
                                      item.currency,
                                ),
                                logoBytes: state.logoFor(item.symbol),
                                failed: state.failed.contains(item.symbol),
                                onTap: () => DepotWishlistDetailDialog.show(
                                  context,
                                  item,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => state.setShowEuro(!state.showEuro),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      l10n.depotWishlistShowEuro,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Tooltip(
                    message: l10n.depotWishlistEuroSwitchHint,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: theme.hintColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // FittedBox shrinks the layout size too, unlike Transform.scale.
            SizedBox(
              width: 40,
              height: 28,
              child: FittedBox(
                child: Switch(
                  value: state.showEuro,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: state.setShowEuro,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
