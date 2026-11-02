import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../depot_allocation.dart';
import '../depot_allocation_state.dart';
import '../depot_allocation_sync.dart';
import '../depot_colors.dart';
import '../depot_format.dart';
import '../depot_overlap.dart';
import '../depot_portfolio_labels.dart';
import '../depot_portfolio_state.dart';
import '../depot_region.dart';
import '../depot_xray.dart';
import '../models/depot_holding.dart';
import 'depot_connect_card.dart';
import 'depot_overlap_card.dart';
import 'depot_section_nav.dart';
import 'depot_share_breakdown.dart';
import 'depot_weight_list.dart';
import 'depot_xray_card.dart';

enum _Section { positions, xray, overlap, region, sector, industry, kind }

/// Region, sector and industry split of the open positions.
class DepotAllocationTabView extends StatefulWidget {
  const DepotAllocationTabView({super.key});

  @override
  State<DepotAllocationTabView> createState() => _DepotAllocationTabViewState();
}

class _DepotAllocationTabViewState extends State<DepotAllocationTabView> {
  static const int _maxIndustryEntries = 8;
  static const String _otherIndustries = '\u0000other';

  // How far below the viewport top a section heading still counts as current.
  static const double _activeSlack = 24;

  final Map<_Section, GlobalKey> _keys = {
    for (final section in _Section.values) section: GlobalKey(),
  };
  _Section? _active;
  bool _jumping = false;

  Future<void> _jumpTo(_Section section) async {
    final target = _keys[section]!.currentContext;
    if (target == null) return;
    setState(() => _active = section);
    _jumping = true;
    try {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } finally {
      _jumping = false;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (_jumping ||
        notification.depth != 0 ||
        notification is! ScrollUpdateNotification) {
      return false;
    }
    final viewport = notification.context?.findRenderObject();
    if (viewport is! RenderBox) return false;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final atEnd = notification.metrics.extentAfter < 1;
    _Section? current;
    for (final MapEntry(key: section, value: key) in _keys.entries) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy - viewportTop;
      if (atEnd || top <= _activeSlack || current == null) current = section;
    }
    if (current != null && current != _active) {
      setState(() => _active = current);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final portfolio = context.watch<DepotPortfolioState>();
    final allocation = context.watch<DepotAllocationState>();

    if (!portfolio.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!portfolio.isConnected && !portfolio.hasData) {
      return const DepotConnectCard();
    }

    final holdings = portfolio.holdings;
    final open = [
      for (final holding in holdings)
        if (!holding.isSold && holding.currentValue > 0) holding,
    ];
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => allocation.ensureLoaded(),
    );

    final format = DepotFormat.of(context, portfolio.currency);
    final sectors = depotAllocationBreakdown(
      holdings: holdings,
      profileOf: allocation.profileOf,
      dimension: DepotAllocationDimension.sector,
    );
    final regions = depotAllocationBreakdown(
      holdings: holdings,
      profileOf: allocation.profileOf,
      dimension: DepotAllocationDimension.region,
    );
    final industries = depotAllocationBreakdown(
      holdings: holdings,
      profileOf: allocation.profileOf,
      dimension: DepotAllocationDimension.industry,
    );
    final kinds = <DepotHoldingKind, double>{};
    for (final holding in open) {
      kinds.update(
        allocation.kindOf(holding),
        (value) => value + holding.currentValue,
        ifAbsent: () => holding.currentValue,
      );
    }
    final xray = depotXRay(
      holdings: open,
      profileOf: allocation.profileOf,
      kindOf: allocation.kindOf,
    );
    final overlap = depotOverlap(
      holdings: open,
      profileOf: allocation.profileOf,
      kindOf: allocation.kindOf,
    );

    final links = open.isEmpty
        ? const <DepotSectionLink<_Section>>[]
        : [
            DepotSectionLink(
              id: _Section.positions,
              label: l10n.depotAllocationPositions,
              icon: Icons.donut_large_outlined,
            ),
            if (xray.hasLookThrough)
              DepotSectionLink(
                id: _Section.xray,
                label: l10n.depotXRayTitle,
                icon: Icons.manage_search_outlined,
              ),
            if (overlap.hasPairs)
              DepotSectionLink(
                id: _Section.overlap,
                label: l10n.depotOverlapTitle,
                icon: Icons.join_inner_outlined,
              ),
            DepotSectionLink(
              id: _Section.region,
              label: l10n.depotAllocationByRegion,
              icon: Icons.public_outlined,
            ),
            DepotSectionLink(
              id: _Section.sector,
              label: l10n.depotAllocationBySector,
              icon: Icons.pie_chart_outline,
            ),
            DepotSectionLink(
              id: _Section.industry,
              label: l10n.depotAllocationByIndustry,
              icon: Icons.factory_outlined,
            ),
            DepotSectionLink(
              id: _Section.kind,
              label: l10n.depotAllocationByKind,
              icon: Icons.category_outlined,
            ),
          ];

    // A Column, not a lazy ListView: a jump target below the fold must be
    // built for ensureVisible to find it.
    final content = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (allocation.isFetching)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          Text(
            l10n.depotAllocationSourceNote,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          if (open.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                l10n.depotAllocationEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            )
          else ...[
            KeyedSubtree(
              key: _keys[_Section.positions],
              child: DepotWeightList(
                holdings: open,
                format: format,
                kindOf: allocation.kindOf,
                constituentsOf: (holding) =>
                    allocation.profileOf(holding)?.constituents ?? const [],
              ),
            ),
            const SizedBox(height: 24),
            if (xray.hasLookThrough) ...[
              KeyedSubtree(
                key: _keys[_Section.xray],
                child: DepotXRayCard(xray: xray, format: format),
              ),
              const SizedBox(height: 24),
            ],
            if (overlap.hasPairs) ...[
              KeyedSubtree(
                key: _keys[_Section.overlap],
                child: DepotOverlapCard(overlap: overlap, format: format),
              ),
              const SizedBox(height: 24),
            ],
            DepotShareBreakdown(
              key: _keys[_Section.region],
              title: l10n.depotAllocationByRegion,
              entries: _entries(
                context,
                regions,
                (key) => DepotPortfolioLabels.region(
                  l10n,
                  DepotRegion.values.byName(key),
                ),
              ),
              format: format,
            ),
            const SizedBox(height: 24),
            DepotShareBreakdown(
              key: _keys[_Section.sector],
              title: l10n.depotAllocationBySector,
              entries: _entries(
                context,
                sectors,
                (key) => DepotPortfolioLabels.sector(l10n, key),
              ),
              format: format,
            ),
            const SizedBox(height: 24),
            DepotShareBreakdown(
              key: _keys[_Section.industry],
              title: l10n.depotAllocationByIndustry,
              entries: _entries(
                context,
                _trimIndustries(industries),
                (key) => key == _otherIndustries
                    ? l10n.depotAllocationOtherIndustries
                    : key,
              ),
              format: format,
            ),
            const SizedBox(height: 24),
            DepotShareBreakdown(
              key: _keys[_Section.kind],
              title: l10n.depotAllocationByKind,
              entries: [
                for (final entry in kinds.entries)
                  if (entry.value > 0)
                    DepotShareEntry(
                      label: DepotPortfolioLabels.kinds(l10n, entry.key),
                      value: entry.value,
                      color: DepotColors.kind(entry.key),
                    ),
              ]..sort((a, b) => b.value.compareTo(a.value)),
              format: format,
            ),
          ],
        ],
      ),
    );

    return ReadableWidth(
      child: Column(
        children: [
          if (links.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: DepotSectionNav<_Section>(
                links: links,
                active: _active ?? links.first.id,
                onSelect: _jumpTo,
              ),
            ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: RefreshIndicator(
                onRefresh: () => syncDepotAllocation(portfolio, allocation),
                child: content,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DepotShareEntry> _entries(
    BuildContext context,
    Map<String?, double> values,
    String Function(String key) labelOf,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return [
      for (final entry in values.entries)
        if (entry.value > 0)
          DepotShareEntry(
            label: entry.key == null
                ? l10n.depotAllocationUnclassified
                : labelOf(entry.key!),
            value: entry.value,
            color: entry.key == null
                ? theme.hintColor.withValues(alpha: 0.6)
                : DepotColors.holding(entry.key!),
          ),
    ];
  }

  Map<String?, double> _trimIndustries(Map<String?, double> industries) {
    if (industries.length <= _maxIndustryEntries) return industries;
    final entries = industries.entries.toList();
    final kept = entries.take(_maxIndustryEntries - 1);
    final rest = entries.skip(_maxIndustryEntries - 1);
    return {
      for (final entry in kept) entry.key: entry.value,
      _otherIndustries: rest.fold<double>(0, (sum, entry) => sum + entry.value),
    };
  }
}
