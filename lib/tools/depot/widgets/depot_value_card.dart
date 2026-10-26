import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_format.dart';
import '../depot_portfolio_state.dart';
import '../models/depot_holding.dart';
import '../models/depot_summary.dart';
import 'depot_allocation_view.dart';
import 'depot_value_chart.dart';

/// Portfolio value chart and allocation of one period in a single card.
class DepotValueCard extends StatefulWidget {
  final List<DepotChartPoint> points;
  final DepotRangeChange? change;
  final Map<DepotHoldingKind, double> allocation;
  final DepotFormat format;

  /// An intraday range says more in the figures than in the plot, so the
  /// chart starts folded while the change labels stay visible.
  final bool collapseChart;

  const DepotValueCard({
    super.key,
    required this.points,
    required this.change,
    required this.allocation,
    required this.format,
    this.collapseChart = false,
  });

  @override
  State<DepotValueCard> createState() => _DepotValueCardState();
}

class _DepotValueCardState extends State<DepotValueCard> {
  late bool _chartOpen = !widget.collapseChart;

  @override
  void didUpdateWidget(covariant DepotValueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapseChart != widget.collapseChart) {
      _chartOpen = !widget.collapseChart;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final change = widget.change;
    final allocation = widget.allocation.values.fold<double>(
      0,
      (a, b) => a + b,
    );

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
                    value: widget.format.money(
                      change.valueChange,
                      signed: true,
                    ),
                    color: DepotFormat.gainColor(change.valueChange),
                  ),
                  _ChangeLabel(
                    label: l10n.depotChartGain,
                    value: widget.format.money(change.gain, signed: true),
                    color: DepotFormat.gainColor(change.gain),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (widget.collapseChart && !_chartOpen)
              _ChartToggle(
                label: l10n.depotChartShow,
                icon: Icons.expand_more,
                onPressed: () => setState(() => _chartOpen = true),
              )
            else ...[
              DepotValueChart(points: widget.points, format: widget.format),
              if (widget.collapseChart)
                _ChartToggle(
                  label: l10n.depotChartHide,
                  icon: Icons.expand_less,
                  onPressed: () => setState(() => _chartOpen = false),
                ),
            ],
            if (allocation > 0) ...[
              const Divider(height: 24),
              DepotAllocationView(
                allocation: widget.allocation,
                format: widget.format,
              ),
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

class _ChartToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ChartToggle({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
    ),
  );
}
