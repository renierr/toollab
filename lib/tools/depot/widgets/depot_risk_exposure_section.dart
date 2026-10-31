import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../depot_risk.dart';
import 'depot_info_row.dart';
import 'depot_risk_contribution_row.dart';

class DepotRiskExposureSection extends StatelessWidget {
  final String title;
  final DepotRiskBreakdown breakdown;
  final DepotFormat format;
  final bool isSector;
  final Map<String, String> portfolioNames;

  const DepotRiskExposureSection({
    super.key,
    required this.title,
    required this.breakdown,
    required this.format,
    this.isSector = false,
    this.portfolioNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final exposure = breakdown.largest;
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final contributors =
        exposure?.contributors ?? const <DepotRiskContribution>[];
    final remaining = contributors
        .skip(3)
        .fold<double>(0, (v, item) => v + item.weight);
    final name = exposure == null
        ? null
        : isSector
        ? DepotPortfolioLabels.sector(l10n, exposure.name)
        : exposure.name;
    final summary = exposure == null
        ? l10n.depotRiskNoExposure
        : '$name · ${format.percent(exposure.weight, signed: false)}';
    final coverage = l10n.depotRiskCoverage(
      format.percent(breakdown.coverage, signed: false),
    );
    return ExpansionTile(
      key: PageStorageKey(
        isSector ? 'depot-risk-sector' : 'depot-risk-country',
      ),
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(title),
      subtitle: Text('$summary · $coverage', style: hint),
      children: [
        for (final item in contributors.take(3))
          DepotRiskContributionRow(
            contribution: item,
            format: format,
            portfolioNames: portfolioNames,
          ),
        if (remaining > 0)
          DepotInfoRow(
            padding: const EdgeInsets.symmetric(vertical: 4),
            title: Text(l10n.depotRiskOtherContributors),
            trailing: Text(
              format.percent(remaining, signed: false),
              textAlign: TextAlign.end,
            ),
          ),
        if (breakdown.missingWeight >= 0.005)
          _CoverageGroup(
            key: PageStorageKey(
              isSector
                  ? 'depot-risk-sector-missing'
                  : 'depot-risk-country-missing',
            ),
            title: l10n.depotRiskMissingData,
            contributions: breakdown.missingSecurities,
            format: format,
            portfolioNames: portfolioNames,
          ),
        if (breakdown.otherWeight >= 0.005)
          _CoverageGroup(
            key: PageStorageKey(
              isSector ? 'depot-risk-sector-other' : 'depot-risk-country-other',
            ),
            title: l10n.depotRiskOtherAssets,
            contributions: breakdown.otherAssets,
            format: format,
            portfolioNames: portfolioNames,
          ),
        if (breakdown.missingWeight >= 0.005 || breakdown.otherWeight >= 0.005)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(l10n.depotRiskCoverageNote, style: hint),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(l10n.depotRiskExposureNote, style: hint),
        ),
      ],
    );
  }
}

class _CoverageGroup extends StatelessWidget {
  final String title;
  final List<DepotRiskContribution> contributions;
  final DepotFormat format;
  final Map<String, String> portfolioNames;

  const _CoverageGroup({
    super.key,
    required this.title,
    required this.contributions,
    required this.format,
    required this.portfolioNames,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = contributions.fold<double>(0, (v, item) => v + item.weight);
    final remaining = contributions
        .skip(3)
        .fold<double>(0, (v, item) => v + item.weight);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text('$title · ${format.percent(total, signed: false)}'),
      children: [
        for (final item in contributions.take(3))
          DepotRiskContributionRow(
            contribution: item,
            format: format,
            portfolioNames: portfolioNames,
          ),
        if (remaining >= 0.005)
          DepotInfoRow(
            padding: const EdgeInsets.symmetric(vertical: 4),
            title: Text(l10n.depotRiskOtherContributors),
            trailing: Text(
              format.percent(remaining, signed: false),
              textAlign: TextAlign.end,
            ),
          ),
      ],
    );
  }
}
