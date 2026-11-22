import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../../depot_format.dart';
import '../../simulation/depot_sim_engine.dart';
import '../../simulation/depot_sim_inputs.dart';
import '../depot_info_row.dart';

/// When net dividends alone would pay the spending gap, saving until then.
class DepotSimDividendCard extends StatelessWidget {
  final DepotSimResult result;
  final DepotSimInputs inputs;
  final DepotFormat format;

  const DepotSimDividendCard({
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
    final bold = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.bold,
    );
    String age(int? value) => value == null
        ? l10n.depotSimAgeBeyond(inputs.endAge)
        : l10n.depotSimAgeValue(value);
    final coverage = result.gapNow > 0
        ? result.dividendsNow / result.gapNow * 100
        : null;

    Widget info(String label, String value) => DepotInfoRow(
      padding: const EdgeInsets.symmetric(vertical: 6),
      title: Text(label, style: theme.textTheme.bodyMedium),
      trailing: Text(value, style: bold, textAlign: TextAlign.end),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.depotSimDividendsTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            info(
              l10n.depotSimDividendsNow,
              format.money(result.dividendsNow / 12),
            ),
            if (coverage != null)
              info(
                l10n.depotSimDividendsCoverage,
                format.percent(coverage, signed: false),
              ),
            info(
              l10n.depotSimDividendsAgeMedian,
              age(result.dividendAgeMedian),
            ),
            info(l10n.depotSimDividendsAgeLate, age(result.dividendAgeLate)),
            const SizedBox(height: 8),
            Text(l10n.depotSimDividendsHint, style: hint),
          ],
        ),
      ),
    );
  }
}
