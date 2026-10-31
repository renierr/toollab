import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_format.dart';
import '../depot_xray.dart';
import 'depot_info_row.dart';

class DepotRiskUnderlyingSection extends StatelessWidget {
  final DepotXRay xray;
  final DepotFormat format;
  final Map<String, String> portfolioNames;

  const DepotRiskUnderlyingSection({
    super.key,
    required this.xray,
    required this.format,
    this.portfolioNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    return ExpansionTile(
      key: const PageStorageKey('depot-risk-underlying'),
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(l10n.depotRiskUnderlying),
      children: [
        for (final entry in xray.entries.take(3))
          _UnderlyingRow(
            entry: entry,
            total: xray.total,
            format: format,
            portfolioNames: portfolioNames,
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(l10n.depotRiskUnderlyingNote, style: hint),
        ),
      ],
    );
  }
}

class _UnderlyingRow extends StatelessWidget {
  final DepotXRayEntry entry;
  final double total;
  final DepotFormat format;
  final Map<String, String> portfolioNames;

  const _UnderlyingRow({
    required this.entry,
    required this.total,
    required this.format,
    required this.portfolioNames,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final names = entry.sources
        .take(3)
        .map((source) {
          final portfolio = portfolioNames[source.holding.portfolioId];
          return '${source.holding.name}${portfolio == null ? '' : ' ($portfolio)'}';
        })
        .join(', ');
    return DepotInfoRow(
      padding: const EdgeInsets.symmetric(vertical: 4),
      title: Text(entry.name),
      subtitle: Text(
        l10n.depotRiskVia('$names${entry.sources.length > 3 ? ' …' : ''}'),
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      ),
      trailing: Text(
        format.percent(entry.value / total * 100, signed: false),
        textAlign: TextAlign.end,
      ),
    );
  }
}
