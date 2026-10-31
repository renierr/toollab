import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_format.dart';
import '../depot_risk.dart';
import '../depot_xray.dart';
import 'depot_info_row.dart';
import 'depot_risk_contribution_row.dart';
import 'depot_risk_exposure_section.dart';
import 'depot_risk_underlying_section.dart';

class DepotRiskCard extends StatelessWidget {
  final DepotRisk risk;
  final DepotFormat format;
  final DepotXRay? xray;
  final String? periodLabel;
  final VoidCallback? onOpenAllocation;
  final Map<String, String> portfolioNames;

  const DepotRiskCard({
    super.key,
    required this.risk,
    required this.format,
    this.xray,
    this.periodLabel,
    this.onOpenAllocation,
    this.portfolioNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final first = risk.positions.firstOrNull;
    final firstPortfolio = first == null
        ? null
        : portfolioNames[first.holding.portfolioId];
    final underlying = xray;
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    return Card(
      child: ExpansionTile(
        key: const PageStorageKey('depot-risk'),
        title: Text(l10n.depotRiskTitle, style: theme.textTheme.titleSmall),
        subtitle: Text(
          first == null
              ? l10n.depotRiskNoPositions
              : l10n.depotRiskLargestSummary(
                  '${first.holding.name}${firstPortfolio == null ? '' : ' ($firstPortfolio)'}',
                  format.percent(first.weight, signed: false),
                ),
          style: hint,
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (first != null) ...[
            DepotInfoRow(
              title: Text(
                l10n.depotRiskTopThree,
                style: theme.textTheme.titleSmall,
              ),
              trailing: Text(format.percent(risk.topThree, signed: false)),
            ),
            for (final position in risk.positions)
              DepotRiskContributionRow(
                contribution: position,
                format: format,
                portfolioNames: portfolioNames,
              ),
            Text(l10n.depotRiskPortfolioWeights, style: hint),
            if (risk.crypto > 0)
              DepotInfoRow(
                padding: const EdgeInsets.only(top: 8),
                title: Text(l10n.depotRiskCrypto),
                trailing: Text(format.percent(risk.crypto, signed: false)),
              ),
            if (underlying != null && underlying.hasLookThrough)
              DepotRiskUnderlyingSection(
                xray: underlying,
                format: format,
                portfolioNames: portfolioNames,
              ),
            DepotRiskExposureSection(
              title: l10n.depotRiskCountry,
              breakdown: risk.country,
              format: format,
              portfolioNames: portfolioNames,
            ),
            DepotRiskExposureSection(
              title: l10n.depotRiskSector,
              breakdown: risk.sector,
              format: format,
              portfolioNames: portfolioNames,
              isSector: true,
            ),
            if (onOpenAllocation != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onOpenAllocation,
                  icon: const Icon(Icons.pie_chart_outline),
                  label: Text(l10n.depotRiskOpenAllocation),
                ),
              ),
          ],
          ExpansionTile(
            key: const PageStorageKey('depot-risk-value'),
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              periodLabel == null
                  ? l10n.depotRiskValueChanges
                  : l10n.depotRiskPeriod(periodLabel!),
            ),
            children: [
              if (risk.currentDrawdown case final value?)
                _RiskValue(
                  label: l10n.depotRiskCurrentDrawdown,
                  value: value,
                  format: format,
                ),
              if (risk.maxDrawdown case final value?)
                _RiskValue(
                  label: l10n.depotRiskMaxDrawdown,
                  value: value,
                  format: format,
                ),
              if (risk.bestDay case final value?)
                _RiskValue(
                  label: l10n.depotRiskBestDay,
                  value: value,
                  format: format,
                ),
              if (risk.worstDay case final value?)
                _RiskValue(
                  label: l10n.depotRiskWorstDay,
                  value: value,
                  format: format,
                ),
              if (risk.currentDrawdown == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.depotRiskNoHistory, style: hint),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.depotRiskValueNote, style: hint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskValue extends StatelessWidget {
  final String label;
  final double value;
  final DepotFormat format;

  const _RiskValue({
    required this.label,
    required this.value,
    required this.format,
  });

  @override
  Widget build(BuildContext context) => DepotInfoRow(
    padding: const EdgeInsets.symmetric(vertical: 3),
    title: Text(label),
    trailing: Text(
      format.percent(value, signed: false),
      textAlign: TextAlign.end,
    ),
  );
}
