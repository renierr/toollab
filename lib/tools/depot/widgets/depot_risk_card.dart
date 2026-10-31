import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_format.dart';
import '../depot_risk.dart';

class DepotRiskCard extends StatelessWidget {
  final DepotRisk risk;
  final DepotFormat format;

  const DepotRiskCard({super.key, required this.risk, required this.format});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rows = <(String, double)>[
      (l10n.depotRiskTopOne, risk.topOne),
      (l10n.depotRiskTopThree, risk.topThree),
      (l10n.depotRiskCrypto, risk.crypto),
      if (risk.currentDrawdown case final drawdown?)
        (l10n.depotRiskCurrentDrawdown, drawdown),
      if (risk.maxDrawdown case final drawdown?)
        (l10n.depotRiskMaxDrawdown, drawdown),
      if (risk.bestDay case final bestDay?) (l10n.depotRiskBestDay, bestDay),
      if (risk.worstDay case final worstDay?)
        (l10n.depotRiskWorstDay, worstDay),
      if (risk.country case final country?)
        ('${l10n.depotRiskCountry}: ${country.name}', country.weight),
      if (risk.sector case final sector?)
        ('${l10n.depotRiskSector}: ${sector.name}', sector.weight),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.depotRiskTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(format.percent(value, signed: false)),
                  ],
                ),
              ),
            if (risk.currentDrawdown != null ||
                risk.country != null ||
                risk.sector != null)
              Text(
                l10n.depotRiskDrawdownNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
