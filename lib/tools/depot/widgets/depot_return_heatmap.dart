import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/theme/theme.dart';

import '../depot_format.dart';
import '../models/depot_monthly_returns.dart';

/// Months as columns, years as rows, each cell colored by its return.
class DepotReturnHeatmap extends StatelessWidget {
  final DepotMonthlyReturns returns;
  final DepotFormat format;

  const DepotReturnHeatmap({
    super.key,
    required this.returns,
    required this.format,
  });

  static const double _labelWidth = 36;
  static const double _totalWidth = 52;
  static const double _gap = 2;

  /// A month at this return or beyond gets the full color.
  static const double _fullColorAt = 8;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final small = theme.textTheme.labelSmall;
    final hint = small?.copyWith(color: theme.hintColor);
    final monthInitial = DateFormat('MMMMM', locale);
    final monthName = DateFormat.yMMM(locale);
    final number = NumberFormat('0.0', locale);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - _labelWidth - _totalWidth) / 12 - _gap;
        final roomy = cellWidth >= 30;
        return Column(
          children: [
            Row(
              children: [
                const SizedBox(width: _labelWidth),
                for (var m = 1; m <= 12; m++)
                  Expanded(
                    child: Text(
                      monthInitial.format(DateTime(2000, m)),
                      textAlign: TextAlign.center,
                      style: hint,
                    ),
                  ),
                const SizedBox(width: _totalWidth),
              ],
            ),
            const SizedBox(height: 4),
            for (final year in returns.years)
              Padding(
                padding: const EdgeInsets.only(bottom: _gap),
                child: Row(
                  children: [
                    SizedBox(
                      width: _labelWidth,
                      child: Text(
                        '${year.year}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    for (var m = 0; m < 12; m++)
                      Expanded(
                        child: _Cell(
                          value: year.months[m],
                          label: roomy && year.months[m] != null
                              ? number.format(year.months[m])
                              : null,
                          tooltip: switch (year.months[m]) {
                            final v? =>
                              '${monthName.format(DateTime(year.year, m + 1))}: '
                                  '${format.percent(v)}',
                            null => null,
                          },
                        ),
                      ),
                    SizedBox(
                      width: _totalWidth,
                      child: Text(
                        switch (year.total) {
                          final v? => format.percent(v),
                          null => '',
                        },
                        textAlign: TextAlign.end,
                        style: small?.copyWith(
                          color: DepotFormat.gainColor(year.total ?? 0),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  final double? value;
  final String? label;
  final String? tooltip;

  const _Cell({required this.value, this.label, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = value;
    final color = v == null
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
        : (v < 0 ? AppTheme.statusRed : AppTheme.statusGreen).withValues(
            alpha:
                0.15 +
                0.85 * (v.abs() / DepotReturnHeatmap._fullColorAt).clamp(0, 1),
          );
    final cell = Container(
      height: 22,
      margin: const EdgeInsets.symmetric(
        horizontal: DepotReturnHeatmap._gap / 2,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: label == null
          ? null
          : FittedBox(
              child: Text(
                label!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
    );
    final message = tooltip;
    return message == null
        ? cell
        : Tooltip(
            message: message,
            triggerMode: TooltipTriggerMode.tap,
            child: cell,
          );
  }
}
