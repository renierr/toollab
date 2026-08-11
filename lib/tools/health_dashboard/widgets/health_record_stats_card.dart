import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../health_record.dart';
import '../health_value_format.dart';
import 'health_record_stat_item.dart';

class HealthRecordStatsCard extends StatelessWidget {
  final HealthRecord record;

  /// Naming and unit for metrics whose number is stored under the generic
  /// `value` key - speed, power, temperature and anything else the catalog does
  /// not map to a named field. Without this they rendered nothing at all.
  final String? fallbackLabel;
  final String? fallbackUnit;

  const HealthRecordStatsCard({
    super.key,
    required this.record,
    this.fallbackLabel,
    this.fallbackUnit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final val = record.value;
    final items = <Widget>[];

    if (val['distanceKm'] case final num dist) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.directions_run_rounded,
          color: AppTheme.accentTeal,
          label: l10n.healthDashboardDistance,
          value: healthValue(dist, 'km'),
        ),
      );
    }
    if (val['calories'] case final num cal) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.local_fire_department_rounded,
          color: AppTheme.accentAmber,
          label: l10n.healthDashboardCalories,
          value: healthValue(cal, 'kcal'),
        ),
      );
    }
    if (val['averageHeartRate'] case final num avgHr) {
      final maxHr = (val['maximumHeartRate'] as num?)?.round();
      items.add(
        HealthRecordStatItem(
          icon: Icons.favorite_outline_rounded,
          color: AppTheme.accentRed,
          label: l10n.healthDashboardHeartRate,
          value: maxHr != null
              ? '${healthValue(avgHr, 'bpm')} (max $maxHr)'
              : healthValue(avgHr, 'bpm'),
        ),
      );
    }
    if (val['averageSpeedKmh'] case final num speed) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.speed_rounded,
          color: AppTheme.accentBlue,
          label: l10n.healthDashboardSpeed,
          value: healthValue(speed, 'km/h'),
        ),
      );
    }
    if (val['count'] case final num count) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.directions_walk_rounded,
          color: AppTheme.accentGreen,
          label: l10n.healthDashboardCount,
          value: healthValue(count, 'count'),
        ),
      );
    }
    if (val['kilograms'] case final num kg) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.monitor_weight_outlined,
          color: AppTheme.accentPurple,
          label: l10n.healthDashboardWeight,
          value: healthValue(kg, 'kg'),
        ),
      );
    }
    if (val['bpm'] case final num bpm) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.favorite_outline_rounded,
          color: AppTheme.accentRed,
          label: l10n.healthDashboardHeartRate,
          value: healthValue(bpm, 'bpm'),
        ),
      );
    }
    if (val['systolicMmhg'] case final num sys) {
      final dia = (val['diastolicMmhg'] as num?)?.round();
      items.add(
        HealthRecordStatItem(
          icon: Icons.monitor_heart_outlined,
          color: AppTheme.accentRed,
          label: l10n.healthDashboardBloodPressure,
          value: dia == null
              ? healthValue(sys, 'mmHg')
              : '${sys.round()}/$dia mmHg',
        ),
      );
    }
    if (val['percent'] case final num pct) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.percent_rounded,
          color: AppTheme.accentBlue,
          label: l10n.healthDashboardPercentage,
          value: healthValue(pct, '%'),
        ),
      );
    }
    if (val['floors'] case final num fl) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.stairs_rounded,
          color: AppTheme.accentTeal,
          label: l10n.healthDashboardFloors,
          value: healthValue(fl, 'count'),
        ),
      );
    }
    if (val['minutes'] case final num min) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.timer_outlined,
          color: AppTheme.accentBlue,
          label: l10n.healthDashboardDuration,
          value: healthValue(min, 'min'),
        ),
      );
    }
    if (val['rmssdMs'] case final num rmssd) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.monitor_heart_rounded,
          color: AppTheme.accentPurple,
          label: l10n.healthDashboardHrv,
          value: healthValue(rmssd, 'ms'),
        ),
      );
    }
    if (val['vo2Max'] case final num vo2) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.fitness_center_rounded,
          color: AppTheme.accentGreen,
          label: l10n.healthDashboardVo2Max,
          value: healthValue(vo2, 'mL/kg/min'),
        ),
      );
    }
    if (val['respiratoryRate'] case final num resp) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.air_rounded,
          color: AppTheme.accentBlue,
          label: l10n.healthDashboardRespiratoryRate,
          value: healthValue(resp, 'rpm'),
        ),
      );
    }
    if (val['bloodGlucoseMgl'] case final num glucose) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.bloodtype_outlined,
          color: AppTheme.accentRed,
          label: l10n.healthDashboardBloodGlucose,
          value: healthValue(glucose, 'mg/dL'),
        ),
      );
    }
    if (val['bmr'] case final num bmrVal) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.local_fire_department_outlined,
          color: AppTheme.accentAmber,
          label: l10n.healthDashboardBmr,
          value: healthValue(bmrVal, 'kcal/day'),
        ),
      );
    }

    if (val['centimeters'] case final num centimeters) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.height_rounded,
          color: AppTheme.accentTeal,
          label: l10n.healthDashboardHeight,
          value: healthValue(centimeters, 'cm'),
        ),
      );
    }
    if (val['liters'] case final num liters) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.water_drop_outlined,
          color: AppTheme.accentBlue,
          label: l10n.healthDashboardHydration,
          value: healthValue(liters, 'L'),
        ),
      );
    }
    if (val['bmi'] case final num bmi) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.straighten_rounded,
          color: AppTheme.accentPurple,
          label: l10n.healthDashboardBmi,
          value: healthNumber(bmi, 'BMI'),
        ),
      );
    }
    if (items.isEmpty) {
      if (_fallbackValue(val) case final num generic) {
        items.add(
          HealthRecordStatItem(
            icon: Icons.insights_rounded,
            color: AppTheme.accentBlue,
            label: fallbackLabel ?? l10n.healthDashboardData,
            value: healthValue(generic, fallbackUnit ?? ''),
          ),
        );
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 24, runSpacing: 16, children: items),
      ),
    );
  }

  /// The first number in the record, so an unmapped metric still shows one.
  num? _fallbackValue(Map<String, dynamic> val) {
    if (val['value'] case final num value) return value;
    for (final entry in val.entries) {
      if (entry.value case final num value) return value;
    }
    return null;
  }
}
