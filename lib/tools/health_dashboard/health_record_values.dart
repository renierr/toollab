import 'health_record.dart';

/// One dense sample: epoch millis and the value in the metric's stored unit.
/// The shape the sleep timeline's overlay curves are drawn from.
typedef HealthTimedValue = ({int t, double v});

/// Reads one number out of a record, including the two cases where the number
/// is not stored but derived from the record's span.
double? healthRecordValue(HealthRecord record, String key) {
  if (key == 'durationMinutes' &&
      (record.type == 'sleep.session' || record.type.startsWith('workout.'))) {
    return (record.endTime - record.startTime) / Duration.millisecondsPerMinute;
  }
  return (record.value[key] as num?)?.toDouble();
}

/// Naps are titled by the writing app; Health Connect has no flag for them.
bool healthRecordIsNap(HealthRecord record) {
  final title = (record.value['title'] as String?)?.toLowerCase() ?? '';
  return title.contains('nickerchen') || title.contains('nap');
}
