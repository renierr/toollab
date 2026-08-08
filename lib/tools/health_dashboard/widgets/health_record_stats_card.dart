import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../health_record.dart';
import 'health_record_stat_item.dart';

class HealthRecordStatsCard extends StatelessWidget {
  final HealthRecord record;

  const HealthRecordStatsCard({super.key, required this.record});

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
          value: '${dist.toStringAsFixed(2)} km',
        ),
      );
    }
    if (val['calories'] case final num cal) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.local_fire_department_rounded,
          color: AppTheme.accentAmber,
          label: l10n.healthDashboardCalories,
          value: '${cal.round()} kcal',
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
              ? '${avgHr.round()} bpm (max $maxHr)'
              : '${avgHr.round()} bpm',
        ),
      );
    }
    if (val['averageSpeedKmh'] case final num speed) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.speed_rounded,
          color: AppTheme.accentBlue,
          label: l10n.healthDashboardSpeed,
          value: '${speed.toStringAsFixed(1)} km/h',
        ),
      );
    }
    if (val['count'] case final num count) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.directions_walk_rounded,
          color: AppTheme.accentGreen,
          label: l10n.healthDashboardCount,
          value: '${count.round()}',
        ),
      );
    }
    if (val['kilograms'] case final num kg) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.monitor_weight_outlined,
          color: AppTheme.accentPurple,
          label: l10n.healthDashboardWeight,
          value: '${kg.toStringAsFixed(1)} kg',
        ),
      );
    }
    if (val['bpm'] case final num bpm) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.favorite_outline_rounded,
          color: AppTheme.accentRed,
          label: l10n.healthDashboardHeartRate,
          value: '${bpm.round()} bpm',
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
              ? '${sys.round()} mmHg'
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
          value: '${pct.toStringAsFixed(1)} %',
        ),
      );
    }
    if (val['floors'] case final num fl) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.stairs_rounded,
          color: AppTheme.accentTeal,
          label: l10n.healthDashboardFloors,
          value: '${fl.round()}',
        ),
      );
    }
    if (val['minutes'] case final num min) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.timer_outlined,
          color: AppTheme.accentBlue,
          label: l10n.healthDashboardDuration,
          value: '${min.round()} min',
        ),
      );
    }
    if (val['rmssdMs'] case final num rmssd) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.monitor_heart_rounded,
          color: AppTheme.accentPurple,
          label: 'HRV',
          value: '${rmssd.toStringAsFixed(1)} ms',
        ),
      );
    }
    if (val['vo2Max'] case final num vo2) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.fitness_center_rounded,
          color: AppTheme.accentGreen,
          label: 'VO2 Max',
          value: '${vo2.toStringAsFixed(1)} mL/kg/min',
        ),
      );
    }
    if (val['respiratoryRate'] case final num resp) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.air_rounded,
          color: AppTheme.accentBlue,
          label: 'Respiratory Rate',
          value: '${resp.toStringAsFixed(1)} rpm',
        ),
      );
    }
    if (val['bloodGlucoseMgl'] case final num glucose) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.bloodtype_outlined,
          color: AppTheme.accentRed,
          label: 'Blood Glucose',
          value: '${glucose.round()} mg/dL',
        ),
      );
    }
    if (val['bmr'] case final num bmrVal) {
      items.add(
        HealthRecordStatItem(
          icon: Icons.local_fire_department_outlined,
          color: AppTheme.accentAmber,
          label: 'BMR',
          value: '${bmrVal.round()} kcal/day',
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 24, runSpacing: 16, children: items),
      ),
    );
  }
}
