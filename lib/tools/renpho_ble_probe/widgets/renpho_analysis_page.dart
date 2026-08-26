import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/data_row.dart';
import 'package:tool_lab/widgets/info_card.dart';

import '../renpho_analysis_labels.dart';
import '../renpho_body_metrics.dart';
import '../renpho_colors.dart';
import '../renpho_independent_analysis.dart';
import '../renpho_measurement.dart';
import 'renpho_analysis_segment_table.dart';
import 'renpho_comparison_table.dart';
import 'renpho_finding_row.dart';
import 'renpho_fluid_model_card.dart';

/// The scan rebuilt from its raw impedances with published equations, and the
/// places where that reading and the scale's own disagree.
class RenphoAnalysisPage extends StatelessWidget {
  final RenphoMeasurement measurement;

  const RenphoAnalysisPage({super.key, required this.measurement});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final analysis = RenphoIndependentAnalysis(RenphoDerived(measurement));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.renphoAnalysisTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat.yMMMd(
                  locale,
                ).add_Hm().format(measurement.measuredAt.toLocal()),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
      body: !analysis.usable
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.renphoAnalysisUnavailable,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _OverallCard(analysis: analysis),
                const SizedBox(height: 12),
                InfoCard(
                  icon: Icons.rule_outlined,
                  title: l10n.renphoAnalysisFindings,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final finding in analysis.findings)
                        RenphoFindingRow(
                          label: finding.kind.label(l10n),
                          value: finding.value,
                          reference: finding.reference,
                          rating: finding.rating,
                          guidance: finding.kind.guidance(l10n),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  icon: Icons.science_outlined,
                  title: l10n.renphoAnalysisWholeBody,
                  child: Column(
                    children: [
                      InfoRow(
                        label: l10n.renphoMetricFatFreeMass,
                        value:
                            '${analysis.fatFreeMassKg.toStringAsFixed(2)} kg',
                      ),
                      InfoRow(
                        label: l10n.renphoMetricFatMass,
                        value:
                            '${analysis.fatMassKg.toStringAsFixed(2)} kg  '
                            '(${analysis.bodyFatPercent.toStringAsFixed(1)} %)',
                      ),
                      InfoRow(
                        label: l10n.renphoMetricSkeletalMuscleMass,
                        value:
                            '${analysis.skeletalMuscleMassKg.toStringAsFixed(2)} kg',
                      ),
                      InfoRow(
                        label: l10n.renphoMetricTotalBodyWater,
                        value:
                            '${analysis.totalBodyWaterL.toStringAsFixed(2)} L  '
                            '(${analysis.bodyWaterPercent.toStringAsFixed(1)} %)',
                      ),
                      InfoRow(
                        label: l10n.renphoMetricSkeletalMuscleFromLimbs,
                        value:
                            '${analysis.skeletalMuscleMassFromLimbsKg.toStringAsFixed(2)} kg',
                      ),
                      InfoRow(
                        label: l10n.renphoMetricAppendicularLeanMass,
                        value:
                            '${analysis.appendicularLeanMassKg.toStringAsFixed(2)} kg',
                      ),
                      InfoRow(
                        label: l10n.renphoMetricAppendicularMuscleMass,
                        value:
                            '${analysis.appendicularSkeletalMuscleMassKg.toStringAsFixed(2)} kg',
                      ),
                      InfoRow(
                        label: l10n.renphoMetricAppendicularMuscleIndex,
                        value:
                            '${analysis.appendicularSkeletalMuscleIndex.toStringAsFixed(1)} kg/m²',
                      ),
                      InfoRow(
                        label: l10n.renphoMetricFatFreeMassIndex,
                        value:
                            '${analysis.fatFreeMassIndex.toStringAsFixed(1)} kg/m²',
                      ),
                      InfoRow(
                        label: l10n.renphoMetricFatMassIndex,
                        value:
                            '${analysis.fatMassIndex.toStringAsFixed(1)} kg/m²',
                      ),
                    ],
                  ),
                ),
                if (analysis.fluidModel case final fluid?) ...[
                  const SizedBox(height: 12),
                  RenphoFluidModelCard(analysis: analysis, model: fluid),
                ],
                const SizedBox(height: 12),
                InfoCard(
                  icon: Icons.graphic_eq,
                  title: l10n.renphoAnalysisFrequency,
                  child: Column(
                    children: [
                      InfoRow(
                        label: l10n.renphoWholeBody20,
                        value:
                            '${analysis.derived.wholeBodyImpedance20.toStringAsFixed(1)} Ω',
                      ),
                      InfoRow(
                        label: l10n.renphoAnalysisZ50Cole,
                        value:
                            '${analysis.wholeBodyImpedance50.toStringAsFixed(1)} Ω',
                      ),
                      InfoRow(
                        label: l10n.renphoAnalysisZ50Linear,
                        value:
                            '${analysis.wholeBodyImpedance50Linear.toStringAsFixed(1)} Ω',
                      ),
                      InfoRow(
                        label: l10n.renphoWholeBody100,
                        value:
                            '${analysis.derived.wholeBodyImpedance100.toStringAsFixed(1)} Ω',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.renphoAnalysisFrequencyHint,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  icon: Icons.accessibility_new_outlined,
                  title: l10n.renphoAnalysisSegments,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RenphoAnalysisSegmentTable(estimates: analysis.segments),
                      const SizedBox(height: 8),
                      Text(
                        l10n.renphoAnalysisSegmentsHint,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  icon: Icons.compare_arrows,
                  title: l10n.renphoAnalysisComparison,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RenphoComparisonTable(comparisons: analysis.comparisons),
                      const SizedBox(height: 8),
                      Text(
                        l10n.renphoAnalysisComparisonHint,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  icon: Icons.school_outlined,
                  title: l10n.renphoAnalysisMethod,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.renphoAnalysisMethodText,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      for (final reference in renphoReferenceList)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '· $reference',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.renphoReportDisclaimer,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  final RenphoIndependentAnalysis analysis;

  const _OverallCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = RenphoColors.overall(analysis.overallStatus);

    return InfoCard(
      icon: Icons.health_and_safety_outlined,
      title: l10n.renphoAnalysisOverall,
      titleColor: color,
      borderColor: color.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${analysis.compositeScore}',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    analysis.overallStatus.label(l10n),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    l10n.renphoAnalysisSummary(
                      analysis.findingsInRange,
                      analysis.healthFindings.length,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: analysis.compositeScore / 100,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.renphoAnalysisScoreHint, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
