import 'package:flutter/material.dart';

import '../health_record.dart';
import 'health_record_details_page.dart';
import 'health_source_badge.dart';

class HealthDataTile extends StatelessWidget {
  final HealthRecord record;

  const HealthDataTile({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(record.startTime);
    final dateStr =
        '${MaterialLocalizations.of(context).formatMediumDate(date)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
    final details = _details();
    return ListTile(
      leading: const Icon(Icons.health_and_safety_outlined),
      title: Text(record.value['dataType'] as String? ?? record.type),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr),
          if (details != null) Text(details),
          HealthSourceBadge(packageName: record.sourceName),
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HealthRecordDetailsPage(record: record),
        ),
      ),
    );
  }

  String? _details() {
    if (record.value['distanceKm'] case final num dist) {
      return '${dist.toStringAsFixed(2)} km';
    }
    if (record.value['calories'] case final num cal) {
      return '${cal.round()} kcal';
    }
    if (record.value['floors'] case final num floors) {
      return '${floors.round()} floors';
    }
    if (record.value['minutes'] case final num minutes) {
      return '${minutes.round()} min';
    }
    if (record.value['systolicMmhg'] case final num systolic) {
      final diastolic = (record.value['diastolicMmhg'] as num?)?.round();
      return diastolic == null
          ? '${systolic.round()} mmHg'
          : '${systolic.round()}/$diastolic mmHg';
    }
    if (record.value['percent'] case final num percent) {
      return '${percent.toStringAsFixed(1)} %';
    }
    if (record.value['rmssdMs'] case final num rmssd) {
      return 'HRV ${rmssd.toStringAsFixed(1)} ms';
    }
    if (record.value['vo2Max'] case final num vo2) {
      return 'VO2 Max ${vo2.toStringAsFixed(1)}';
    }
    if (record.value['bmi'] case final num bmi) {
      return 'BMI ${bmi.toStringAsFixed(1)}';
    }
    if (record.value['centimeters'] case final num centimeters) {
      return '${centimeters.toStringAsFixed(1)} cm';
    }
    if (record.value['liters'] case final num liters) {
      return '${liters.toStringAsFixed(2)} L';
    }
    return null;
  }
}
