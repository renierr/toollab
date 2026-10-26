import 'package:flutter/material.dart';

import '../depot_colors.dart';
import '../dividends/depot_dividend_calendar.dart';

/// Booked, missing and expected amounts stacked, scaled against [maxTotal].
class DepotDividendStackBar extends StatelessWidget {
  final DepotDividendTotals totals;
  final double maxTotal;
  final Axis axis;
  final double thickness;

  const DepotDividendStackBar({
    super.key,
    required this.totals,
    required this.maxTotal,
    required this.axis,
    required this.thickness,
  });

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.08);
    final horizontal = axis == Axis.horizontal;
    final parts = [
      (totals.booked, DepotColors.dividendBooked),
      (totals.missing, DepotColors.dividendMissing),
      (totals.expected, DepotColors.dividendExpected),
    ];
    final filled = maxTotal <= 0 ? 0.0 : (totals.total / maxTotal).clamp(0, 1);
    final segments = [
      for (final (value, color) in parts)
        if (value > 0)
          Expanded(
            flex: (value / totals.total * 1000).round().clamp(1, 1000),
            child: ColoredBox(color: color),
          ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(thickness / 2),
      child: SizedBox(
        width: horizontal ? double.infinity : thickness,
        height: horizontal ? thickness : double.infinity,
        child: ColoredBox(
          color: track,
          child: FractionallySizedBox(
            alignment: horizontal
                ? Alignment.centerLeft
                : Alignment.bottomCenter,
            widthFactor: horizontal ? filled.toDouble() : 1,
            heightFactor: horizontal ? 1 : filled.toDouble(),
            child: horizontal
                ? Row(
                    // Without the stretch the segments get a loose cross
                    // axis and collapse to zero thickness.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: segments,
                  )
                // Booked at the bottom, expected on top.
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: segments.reversed.toList(),
                  ),
          ),
        ),
      ),
    );
  }
}
