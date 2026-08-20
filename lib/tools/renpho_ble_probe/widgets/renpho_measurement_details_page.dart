import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/data_row.dart';
import 'package:tool_lab/widgets/info_card.dart';

import '../renpho_body_metrics.dart';
import '../renpho_measurement.dart';
import 'renpho_metrics_grid.dart';
import 'renpho_segment_table.dart';

/// Everything one scan yields, separated by where each figure comes from —
/// measured, exact arithmetic, the Renpho model, or an independent equation.
class RenphoMeasurementDetailsPage extends StatelessWidget {
  final RenphoMeasurement measurement;

  const RenphoMeasurementDetailsPage({super.key, required this.measurement});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final derived = RenphoDerived(measurement);

    // A pushed sub-page sits outside the GoRouter tree, so it uses a plain
    // AppBar rather than ToolLayout, whose back button resolves a router state.
    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat.yMMMd(
            locale,
          ).add_Hm().format(measurement.measuredAt.toLocal()),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RenphoMetricsGrid(measurement: measurement),
          const SizedBox(height: 16),
          InfoCard(
            icon: Icons.sensors,
            title: l10n.renphoSectionReported,
            child: Column(
              children: [
                InfoRow(
                  label: l10n.renphoMetricWeight,
                  value: '${measurement.weightKg.toStringAsFixed(2)} kg',
                ),
                InfoRow(
                  label: l10n.renphoMetricBmiOnScale,
                  value: measurement.bmi.toStringAsFixed(1),
                ),
                InfoRow(
                  label: l10n.renphoMetricBodyFat,
                  value: '${measurement.bodyFatPercent.toStringAsFixed(1)} %',
                ),
                InfoRow(
                  label: l10n.renphoMetricMuscle,
                  value: '${measurement.musclePercent.toStringAsFixed(1)} %',
                ),
                InfoRow(
                  label: l10n.renphoMetricVisceralFat,
                  value: '${measurement.visceralFat}',
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.renphoSectionReportedHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InfoCard(
            icon: Icons.calculate_outlined,
            title: l10n.renphoSectionExact,
            child: Column(
              children: [
                InfoRow(
                  label: l10n.renphoMetricBmi,
                  value: derived.bmi.toStringAsFixed(1),
                ),
                InfoRow(
                  label: l10n.renphoMetricFatMass,
                  value: '${derived.fatMassKg.toStringAsFixed(2)} kg',
                ),
                InfoRow(
                  label: l10n.renphoMetricFatFreeMass,
                  value: '${derived.fatFreeMassKg.toStringAsFixed(2)} kg',
                ),
                InfoRow(
                  label: l10n.renphoMetricSkeletalMuscleMass,
                  value:
                      '${derived.skeletalMuscleMassKg.toStringAsFixed(2)} kg',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InfoCard(
            icon: Icons.auto_graph,
            title: l10n.renphoSectionModel,
            titleColor: derived.modelCalibrated ? null : AppTheme.statusAmber,
            child: Column(
              children: [
                if (!derived.modelCalibrated) ...[
                  Text(
                    l10n.renphoModelUncalibrated,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.statusAmber,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                InfoRow(
                  label: l10n.renphoMetricBodyWater,
                  value:
                      '${derived.bodyWaterPercent.toStringAsFixed(1)} %  '
                      '(${derived.bodyWaterMassKg.toStringAsFixed(2)} kg)',
                ),
                InfoRow(
                  label: l10n.renphoMetricProtein,
                  value:
                      '${derived.proteinPercent.toStringAsFixed(1)} %  '
                      '(${derived.proteinMassKg.toStringAsFixed(2)} kg)',
                ),
                InfoRow(
                  label: l10n.renphoMetricLeanSoftTissue,
                  value:
                      '${derived.leanSoftTissueKg.toStringAsFixed(2)} kg  '
                      '(${derived.leanSoftTissuePercent.toStringAsFixed(1)} %)',
                ),
                InfoRow(
                  label: l10n.renphoMetricSubcutaneousFat,
                  value:
                      '${derived.subcutaneousFatPercent.toStringAsFixed(1)} %',
                ),
                InfoRow(
                  label: l10n.renphoMetricBoneMass,
                  value: '${derived.boneMassKg.toStringAsFixed(2)} kg',
                ),
                InfoRow(
                  label: l10n.renphoMetricBmr,
                  value: '${derived.bmrRenphoKcal.round()} kcal/d',
                ),
                InfoRow(
                  label: l10n.renphoMetricBodyScore,
                  value: derived.bodyScore.round().toString(),
                ),
                InfoRow(
                  label: l10n.renphoMetricBodyType,
                  value: derived.bodyType.toString(),
                ),
                InfoRow(
                  label: l10n.renphoMetricObesityDegree,
                  value: '${derived.obesityDegreePercent} %',
                ),
                InfoRow(
                  label: l10n.renphoMetricWeightControl,
                  value:
                      '${derived.weightControlKg >= 0 ? '+' : ''}'
                      '${derived.weightControlKg.toStringAsFixed(1)} kg',
                ),
                InfoRow(
                  label: l10n.renphoMetricTargetWeight,
                  value: '${derived.targetWeightKg.toStringAsFixed(2)} kg',
                ),
                InfoRow(
                  label: l10n.renphoMetricSmi,
                  value:
                      '${derived.skeletalMuscleIndex.toStringAsFixed(1)} kg/m²',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InfoCard(
            icon: Icons.accessibility_new_outlined,
            title: l10n.renphoSectionSegments,
            child: RenphoSegmentTable(derived: derived),
          ),
          const SizedBox(height: 12),
          InfoCard(
            icon: Icons.electric_bolt_outlined,
            title: l10n.renphoSectionImpedance,
            child: Column(
              children: [
                InfoRow(
                  label: l10n.renphoWholeBody20,
                  value: '${derived.wholeBodyImpedance20.toStringAsFixed(1)} Ω',
                ),
                InfoRow(
                  label: l10n.renphoWholeBody100,
                  value:
                      '${derived.wholeBodyImpedance100.toStringAsFixed(1)} Ω',
                ),
                InfoRow(
                  label: l10n.renphoImpedanceRatio,
                  value: derived.impedanceRatio.toStringAsFixed(3),
                ),
                InfoRow(
                  label: l10n.renphoArmDifference,
                  value:
                      '${derived.armImpedanceDifference.toStringAsFixed(1)} Ω',
                ),
                InfoRow(
                  label: l10n.renphoLegDifference,
                  value:
                      '${derived.legImpedanceDifference.toStringAsFixed(1)} Ω',
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.renphoImpedanceHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InfoCard(
            icon: Icons.local_fire_department_outlined,
            title: l10n.renphoSectionEnergy,
            child: Column(
              children: [
                InfoRow(
                  label: 'Mifflin-St Jeor',
                  value: '${derived.bmrMifflinKcal.round()} kcal/d',
                ),
                InfoRow(
                  label: 'Katch-McArdle',
                  value: '${derived.bmrKatchMcArdleKcal.round()} kcal/d',
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.renphoEnergyHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (derived.publishedEstimates.isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoCard(
              icon: Icons.school_outlined,
              title: l10n.renphoSectionPublished,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      headingRowHeight: 36,
                      dataRowMinHeight: 34,
                      dataRowMaxHeight: 40,
                      columns: [
                        DataColumn(label: Text(l10n.renphoEquation)),
                        const DataColumn(label: Text('100 kHz'), numeric: true),
                        const DataColumn(label: Text('50 kHz'), numeric: true),
                        const DataColumn(label: Text('20 kHz'), numeric: true),
                      ],
                      rows: [
                        for (final estimate in derived.publishedEstimates)
                          DataRow(
                            cells: [
                              DataCell(Text(estimate.equation)),
                              DataCell(
                                Text(
                                  '${estimate.at100kHz.toStringAsFixed(1)} ${estimate.unit}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${estimate.at50kHz.toStringAsFixed(1)} ${estimate.unit}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${estimate.at20kHz.toStringAsFixed(1)} ${estimate.unit}',
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.renphoPublishedHint(
                      derived.interpolatedImpedance50.toStringAsFixed(1),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          InfoCard(
            icon: Icons.info_outline,
            title: l10n.renphoSectionRecord,
            child: Column(
              children: [
                InfoRow(
                  label: l10n.renphoProfileName,
                  value: measurement.profileName,
                ),
                InfoRow(
                  label: l10n.renphoProfileSex,
                  value: measurement.profileSex == 'male'
                      ? l10n.renphoSexMale
                      : l10n.renphoSexFemale,
                ),
                InfoRow(
                  label: l10n.renphoProfileHeight,
                  value: '${measurement.profileHeightCm.toStringAsFixed(1)} cm',
                ),
                InfoRow(
                  label: l10n.renphoAgeAtScan,
                  value: '${measurement.profileAge}',
                ),
                InfoRow(
                  label: l10n.renphoSource,
                  value: measurement.stored
                      ? l10n.renphoSourceStored
                      : l10n.renphoSourceLive,
                ),
                if (measurement.packetHex.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _RawPacket(hex: measurement.packetHex),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RawPacket extends StatelessWidget {
  final String hex;

  const _RawPacket({required this.hex});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.renphoRawPacket,
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              tooltip: l10n.renphoCopyPacket,
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: hex));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.renphoPacketCopied)),
                  );
                }
              },
            ),
          ],
        ),
        SelectableText(
          hex,
          style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
