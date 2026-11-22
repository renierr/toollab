import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../../depot_format.dart';
import '../../simulation/depot_sim_engine.dart';
import '../../simulation/depot_sim_inputs.dart';
import 'depot_sim_kpis.dart';

/// Fixed real withdrawals against guardrails, side by side.
class DepotSimStrategyCard extends StatelessWidget {
  final DepotSimResult result;
  final DepotSimInputs inputs;
  final DepotFormat format;

  const DepotSimStrategyCard({
    super.key,
    required this.result,
    required this.inputs,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final bold = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.bold,
    );
    String percent(double fraction) =>
        format.percent(fraction * 100, signed: false);
    String depletion(DepotSimOutcome o) => o.earlyDepletionAge == null
        ? l10n.depotSimAgeBeyond(inputs.endAge)
        : l10n.depotSimAgeValue(o.earlyDepletionAge!);

    TableRow row(
      String label,
      String fixed,
      String guardrails, {
      Color? a,
      Color? b,
    }) => TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Text(
          fixed,
          textAlign: TextAlign.end,
          style: bold?.copyWith(color: a),
        ),
        Text(
          guardrails,
          textAlign: TextAlign.end,
          style: bold?.copyWith(color: b),
        ),
      ],
    );

    final fixed = result.fixed;
    final guard = result.guardrails;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.depotSimStrategiesTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    const SizedBox.shrink(),
                    Text(
                      l10n.depotSimStrategyFixed,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium,
                    ),
                    Text(
                      l10n.depotSimStrategyGuardrails,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
                row(
                  l10n.depotSimRowSuccess,
                  percent(fixed.success),
                  percent(guard.success),
                  a: DepotSimKpis.successColor(
                    fixed.success,
                    inputs.targetSuccess,
                  ),
                  b: DepotSimKpis.successColor(
                    guard.success,
                    inputs.targetSuccess,
                  ),
                ),
                row(
                  l10n.depotSimRowLastsUntil,
                  depletion(fixed),
                  depletion(guard),
                ),
                row(
                  l10n.depotSimRowMedianEnd(inputs.endAge),
                  format.axisMoney(fixed.medianEnd),
                  format.axisMoney(guard.medianEnd),
                ),
                row(
                  l10n.depotSimRowWorstSpending,
                  percent(fixed.worstSpending),
                  percent(guard.worstSpending),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.depotSimStrategyFixedHint, style: hint),
            const SizedBox(height: 4),
            Text(l10n.depotSimStrategyGuardrailsHint, style: hint),
          ],
        ),
      ),
    );
  }
}
