import 'package:health_connector/health_connector.dart' as hc;
// ignore: implementation_imports
import 'package:health_connector_core/src/models/health_data_types/health_data_type_capabilities/readable_health_data_type.dart'
    as core;

/// Health Connect data types this app can read, keyed by the plugin's stable
/// `HealthDataType.id`.
///
/// The id is used everywhere a type is persisted - the selection table, import
/// progress, the sync token scope - because `HealthDataType.dataTypeMap` resolves
/// it back to the type object. The previous code keyed on
/// `runtimeType.toString()`, which is neither stable across plugin versions nor
/// reversible.
class HealthConnectTypes {
  HealthConnectTypes._();

  /// Enabled on a fresh install: the types the dashboard actually renders.
  /// Everything else is discovered and left off, so a first import does not pull
  /// a decade of data the user never asked for.
  static const defaults = {
    'steps',
    'distance',
    'active_calories_burned',
    'heart_rate_series',
    'heart_rate',
    'resting_heart_rate',
    'weight',
    'body_fat_percentage',
    'oxygen_saturation',
    'heart_rate_variability_rmssd',
    'respiratory_rate',
    'sleep_session',
    'exercise_session',
    'speed_series',
  };

  static Iterable<core.ReadableInTimeRangeHealthDataType> readable() {
    return hc.HealthDataType.healthConnectDataTypes
        .whereType<core.ReadableInTimeRangeHealthDataType>();
  }

  static String idOf(Object type) => (type as hc.HealthDataType).id;

  /// Built from the public type list rather than the plugin's own
  /// `dataTypeMap`, which is marked internal.
  static final Map<String, hc.HealthDataType> _byId = {
    for (final type in hc.HealthDataType.healthConnectDataTypes) type.id: type,
  };

  /// Resolves persisted ids back to type objects, dropping ids this plugin
  /// version no longer knows.
  static List<hc.HealthDataType> resolve(Iterable<String> ids) =>
      ids.map((id) => _byId[id]).whereType<hc.HealthDataType>().toList();
}
