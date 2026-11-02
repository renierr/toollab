import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../depot_colors.dart';
import '../depot_format.dart';
import '../depot_overlap.dart';
import '../models/depot_holding.dart';
import 'depot_holding_avatar.dart';

/// Heatmap of every fund pair; a cell opens that pair.
class DepotOverlapMatrix extends StatelessWidget {
  final DepotOverlap overlap;
  final DepotFormat format;
  final ValueChanged<DepotOverlapPair> onSelect;

  const DepotOverlapMatrix({
    super.key,
    required this.overlap,
    required this.format,
    required this.onSelect,
  });

  static const double _avatarSize = 24;
  static const double _nameWidth = 140;
  static const double _minCell = 34;
  static const double _maxCell = 56;

  @override
  Widget build(BuildContext context) {
    final funds = overlap.funds;
    final strongest = overlap.pairs.isEmpty ? 0.0 : overlap.pairs.first.overlap;
    final compact = NumberFormat.percentPattern(
      Localizations.localeOf(context).toString(),
    )..maximumFractionDigits = 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showNames = width - _nameWidth >= funds.length * _minCell;
        final labelWidth = showNames ? _nameWidth : _avatarSize + 8;
        final cell = ((width - labelWidth) / funds.length).clamp(0.0, _maxCell);
        if (cell < _minCell) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(width: labelWidth),
                for (final fund in funds)
                  SizedBox(
                    width: cell,
                    height: _avatarSize + 8,
                    child: Center(child: _FundAvatar(fund: fund)),
                  ),
              ],
            ),
            for (final row in funds)
              Row(
                children: [
                  SizedBox(
                    width: labelWidth,
                    height: cell,
                    child: _RowLabel(fund: row, showName: showNames),
                  ),
                  for (final column in funds)
                    SizedBox.square(
                      dimension: cell,
                      child: row.key == column.key
                          ? const _DiagonalCell()
                          : _OverlapCell(
                              pair: overlap.pairOf(row, column)!,
                              strongest: strongest,
                              label: compact,
                              format: format,
                              onTap: onSelect,
                            ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _FundAvatar extends StatelessWidget {
  final DepotHolding fund;

  const _FundAvatar({required this.fund});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: fund.name,
    child: DepotHoldingAvatar(
      name: fund.name,
      colorSeed: fund.identifier ?? fund.id,
      size: DepotOverlapMatrix._avatarSize,
    ),
  );
}

class _RowLabel extends StatelessWidget {
  final DepotHolding fund;
  final bool showName;

  const _RowLabel({required this.fund, required this.showName});

  @override
  Widget build(BuildContext context) {
    if (!showName) return Center(child: _FundAvatar(fund: fund));
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          _FundAvatar(fund: fund),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              fund.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalCell extends StatelessWidget {
  const _DiagonalCell();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(1.5),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );
}

class _OverlapCell extends StatelessWidget {
  final DepotOverlapPair pair;
  final double strongest;
  final NumberFormat label;
  final DepotFormat format;
  final ValueChanged<DepotOverlapPair> onTap;

  const _OverlapCell({
    required this.pair,
    required this.strongest,
    required this.label,
    required this.format,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = strongest > 0 ? pair.overlap / strongest : 0.0;
    final alpha = 0.1 + 0.75 * t;
    final base = DepotColors.overlap(pair.level);
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Tooltip(
        message:
            '${pair.a.name}\n${pair.b.name}\n'
            '${format.percent(pair.overlap * 100, signed: false)}',
        child: Material(
          color: base.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(6),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onTap(pair),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    label.format(pair.overlap),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
