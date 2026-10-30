import 'package:flutter/material.dart';

import '../depot_format.dart';
import '../models/depot_fund_constituent.dart';
import '../models/depot_holding.dart';
import 'depot_constituent_list.dart';
import 'depot_holding_avatar.dart';
import 'depot_kind_badge.dart';

/// One position's share of the portfolio. A fund with known top holdings
/// expands to list them.
class DepotWeightRow extends StatefulWidget {
  final DepotHolding holding;
  final DepotHoldingKind kind;
  final double share;
  final double barFraction;
  final Color barColor;
  final List<DepotFundConstituent> constituents;
  final DepotFormat format;

  const DepotWeightRow({
    super.key,
    required this.holding,
    required this.kind,
    required this.share,
    required this.barFraction,
    required this.barColor,
    required this.constituents,
    required this.format,
  });

  @override
  State<DepotWeightRow> createState() => _DepotWeightRowState();
}

class _DepotWeightRowState extends State<DepotWeightRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final holding = widget.holding;
    final expandable = widget.constituents.isNotEmpty;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              DepotHoldingAvatar(
                name: holding.name,
                colorSeed: holding.identifier ?? holding.id,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holding.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    DepotKindBadge(kind: widget.kind),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.format.percent(widget.share * 100, signed: false),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.format.money(holding.currentValue),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
              if (expandable)
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more, color: theme.hintColor),
                ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) => Container(
              height: 4,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
              child: SizedBox(
                height: 4,
                width: constraints.maxWidth * widget.barFraction,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.barColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          if (expandable && _expanded)
            DepotConstituentList(
              constituents: widget.constituents,
              fundValue: holding.currentValue,
              format: widget.format,
            ),
        ],
      ),
    );

    if (!expandable) return row;
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: row,
      ),
    );
  }
}
