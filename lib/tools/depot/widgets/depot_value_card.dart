import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_format.dart';
import '../depot_portfolio_state.dart';
import '../models/depot_holding.dart';
import '../models/depot_summary.dart';
import 'depot_allocation_view.dart';
import 'depot_value_chart.dart';

/// Portfolio value chart and allocation of one period in a single card.
class DepotValueCard extends StatelessWidget {
  final List<DepotChartPoint> points;
  final DepotRangeChange? change;
  final Map<DepotHoldingKind, double> allocation;
  final DepotFormat format;

  final bool showChart;

  const DepotValueCard({
    super.key,
    required this.points,
    required this.change,
    required this.allocation,
    required this.format,
    this.showChart = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final change = this.change;
    final allocationTotal = allocation.values.fold<double>(0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.depotChartTitle, style: theme.textTheme.titleSmall),
            if (change != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _ChangeLabel(
                    label: l10n.depotChartChange,
                    value: format.money(change.valueChange, signed: true),
                    color: DepotFormat.gainColor(change.valueChange),
                  ),
                  _ChangeLabel(
                    label: l10n.depotChartGain,
                    value: format.money(change.gain, signed: true),
                    color: DepotFormat.gainColor(change.gain),
                  ),
                ],
              ),
            ],
            if (showChart) ...[
              const SizedBox(height: 12),
              DepotValueChart(points: points, format: format),
            ],
            if (allocationTotal > 0) ...[
              const Divider(height: 24),
              DepotAllocationView(allocation: allocation, format: format),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangeLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _ChangeLabel({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: TextStyle(color: theme.hintColor),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      style: theme.textTheme.bodyMedium,
    );
  }
}
