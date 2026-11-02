import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_format.dart';
import '../depot_overlap.dart';
import 'depot_overlap_dialog.dart';
import 'depot_overlap_matrix.dart';
import 'depot_overlap_pair_tile.dart';

/// How much the open ETFs and funds hold the same companies.
class DepotOverlapCard extends StatefulWidget {
  final DepotOverlap overlap;
  final DepotFormat format;

  const DepotOverlapCard({
    super.key,
    required this.overlap,
    required this.format,
  });

  static const int topCount = 5;

  // Past this many funds a cell gets too small to read on a phone.
  static const int maxMatrixFunds = 8;

  @override
  State<DepotOverlapCard> createState() => _DepotOverlapCardState();
}

class _DepotOverlapCardState extends State<DepotOverlapCard> {
  bool _showAll = false;

  void _open(DepotOverlapPair pair) =>
      DepotOverlapDialog.show(context, pair, widget.format);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final overlap = widget.overlap;
    if (!overlap.hasPairs) return const SizedBox.shrink();
    final pairs = _showAll
        ? overlap.pairs
        : overlap.pairs.take(DepotOverlapCard.topCount).toList();
    final funds = overlap.funds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.depotOverlapTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          l10n.depotOverlapNote,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 12),
        if (funds >= 3 && funds <= DepotOverlapCard.maxMatrixFunds) ...[
          DepotOverlapMatrix(
            overlap: overlap,
            format: widget.format,
            onSelect: _open,
          ),
          const SizedBox(height: 12),
        ],
        for (final pair in pairs)
          DepotOverlapPairTile(
            key: ValueKey('${pair.a.key}|${pair.b.key}'),
            pair: pair,
            format: widget.format,
            onTap: () => _open(pair),
          ),
        if (overlap.pairs.length > DepotOverlapCard.topCount)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(
                _showAll
                    ? l10n.depotXRayShowLess
                    : l10n.depotXRayShowAll(overlap.pairs.length),
              ),
            ),
          ),
      ],
    );
  }
}
