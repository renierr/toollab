import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/metric_tile.dart';

import '../../depot_format.dart';
import '../../simulation/depot_sim_engine.dart';
import '../../simulation/depot_sim_inputs.dart';

class DepotSimKpis extends StatelessWidget {
  final DepotSimResult result;
  final DepotSimInputs inputs;
  final DepotSimStrategy strategy;
  final DepotFormat format;

  const DepotSimKpis({
    super.key,
    required this.result,
    required this.inputs,
    required this.strategy,
    required this.format,
  });

  static Color successColor(double success, double target) => success >= target
      ? AppTheme.statusGreen
      : success >= target - 0.15
      ? AppTheme.statusAmber
      : AppTheme.statusRed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final outcome = result.outcome(strategy);
    final earliest = result.earliestAge;
    final depletion = outcome.earlyDepletionAge;
    final target = format.percent(inputs.targetSuccess * 100, signed: false);

    return MetricGrid(
      children: [
        MetricTile(
          label: l10n.depotSimSuccess(result.retireAge),
          value: format.percent(outcome.success * 100, signed: false),
          icon: Icons.verified_outlined,
          color: successColor(outcome.success, inputs.targetSuccess),
          compact: true,
        ),
        MetricTile(
          label: l10n.depotSimEarliestAge(target),
          value: earliest == null ? '–' : l10n.depotSimAgeValue(earliest),
          icon: Icons.flag_outlined,
          color: AppTheme.accentBlue,
          compact: true,
        ),
        MetricTile(
          label: l10n.depotSimAtRetirement,
          value: format.money(outcome.medianAtRetirement),
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.accentGreen,
          compact: true,
        ),
        MetricTile(
          label: l10n.depotSimLastsUntil,
          value: depletion == null
              ? l10n.depotSimAgeBeyond(inputs.endAge)
              : l10n.depotSimAgeValue(depletion),
          icon: Icons.hourglass_bottom,
          color: depletion == null ? AppTheme.statusGreen : AppTheme.statusRed,
          compact: true,
        ),
      ],
    );
  }
}
