import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_format.dart';
import '../depot_xray.dart';
import 'depot_holding_avatar.dart';
import 'depot_kind_badge.dart';

/// The portfolio looked through its funds: largest underlying companies, each
/// expanding to the positions that hold it.
class DepotXRayCard extends StatefulWidget {
  final DepotXRay xray;
  final DepotFormat format;

  const DepotXRayCard({super.key, required this.xray, required this.format});

  static const int topCount = 20;

  @override
  State<DepotXRayCard> createState() => _DepotXRayCardState();
}

class _DepotXRayCardState extends State<DepotXRayCard> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final xray = widget.xray;
    final format = widget.format;
    if (!xray.hasLookThrough || xray.total <= 0) return const SizedBox.shrink();
    final entries = _showAll
        ? xray.entries
        : xray.entries.take(DepotXRayCard.topCount).toList();
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.depotXRayTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(l10n.depotXRayNote, style: hint),
        const SizedBox(height: 8),
        for (final entry in entries)
          _XRayTile(
            key: ValueKey(entry.key),
            entry: entry,
            total: xray.total,
            format: format,
          ),
        if (xray.entries.length > DepotXRayCard.topCount)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(
                _showAll
                    ? l10n.depotXRayShowLess
                    : l10n.depotXRayShowAll(xray.entries.length),
              ),
            ),
          ),
        if (xray.uncovered > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                Icon(Icons.more_horiz, size: 18, color: theme.hintColor),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.depotXRayUncovered, style: hint)),
                Text(
                  format.percent(
                    xray.uncovered / xray.total * 100,
                    signed: false,
                  ),
                  style: hint,
                ),
                const SizedBox(width: 12),
                Text(format.money(xray.uncovered), style: hint),
              ],
            ),
          ),
      ],
    );
  }
}

class _XRayTile extends StatelessWidget {
  final DepotXRayEntry entry;
  final double total;
  final DepotFormat format;

  const _XRayTile({
    super.key,
    required this.entry,
    required this.total,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    return ExpansionTile(
      key: PageStorageKey('depot-xray-${entry.key}'),
      dense: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.fromLTRB(46, 0, 8, 8),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: DepotHoldingAvatar(
        name: entry.name,
        colorSeed: entry.key,
        size: 28,
      ),
      title: Text(
        entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(l10n.depotXRaySources(entry.sources.length), style: hint),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            format.percent(entry.value / total * 100, signed: false),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(format.money(entry.value), style: hint),
        ],
      ),
      children: [
        for (final source in entry.sources)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  DepotKindBadge.icon(source.kind),
                  size: 16,
                  color: theme.hintColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.holding.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        source.fundWeight == null
                            ? l10n.depotXRayDirect
                            : l10n.depotXRayFundShare(
                                format.percent(
                                  source.fundWeight! * 100,
                                  signed: false,
                                ),
                              ),
                        style: hint,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  format.money(source.value),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
