import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../../depot_format.dart';
import '../../depot_simulation_state.dart';
import '../../simulation/depot_sim_engine.dart';
import '../../simulation/depot_sim_inputs.dart';
import '../depot_mode_chips.dart';
import 'depot_sim_fan_chart.dart';

class DepotSimChartCard extends StatelessWidget {
  final DepotSimResult result;
  final DepotSimStrategy strategy;
  final DepotFormat format;

  const DepotSimChartCard({
    super.key,
    required this.result,
    required this.strategy,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.depotSimChartTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              l10n.depotSimChartHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 8),
            DepotModeChips<DepotSimStrategy>(
              selected: strategy,
              options: [
                (DepotSimStrategy.fixed, l10n.depotSimStrategyFixed),
                (DepotSimStrategy.guardrails, l10n.depotSimStrategyGuardrails),
              ],
              onSelected: context.read<DepotSimulationState>().setStrategy,
            ),
            const SizedBox(height: 12),
            DepotSimFanChart(
              result: result,
              outcome: result.outcome(strategy),
              format: format,
            ),
          ],
        ),
      ),
    );
  }
}
