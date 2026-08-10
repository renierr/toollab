/// How a metric collapses to one number per day in `health_daily`.
enum HealthAggregation {
  /// Summed over the day: steps, distance, energy.
  total,

  /// Averaged over the day, with lo/hi kept: heart rate, SpO2.
  average,

  /// Last measurement of the day wins: weight, height, BMI.
  latest,
}

/// Storage shape, which decides the fact table a metric lands in.
enum HealthMetricShape {
  /// A measurement at an instant. Lands in `health_point`.
  point,

  /// A value spanning a range. Lands in `health_interval`.
  interval,
}

class HealthMetricSpec {
  final String key;
  final String unit;
  final HealthAggregation aggregation;
  final HealthMetricShape shape;

  /// True for series-backed metrics, where one Health Connect record carries
  /// many samples. They skip pairwise duplicate detection: their measurements
  /// already collapse on the `health_point` primary key, so comparing carrier
  /// records against each other costs the most and finds nothing.
  final bool dense;

  const HealthMetricSpec({
    required this.key,
    required this.unit,
    required this.aggregation,
    required this.shape,
    this.dense = false,
  });
}

/// Every metric the importer can produce. Keys are stable and are what
/// `health_metric` interns to an integer, so a rename is a migration.
class HealthMetrics {
  HealthMetrics._();

  static const heartRate = 'heart_rate';
  static const restingHeartRate = 'resting_heart_rate';
  static const speed = 'speed';
  static const cadence = 'cadence';
  static const power = 'power';
  static const weight = 'weight';
  static const bodyFat = 'body_fat';
  static const boneMass = 'bone_mass';
  static const bodyWaterMass = 'body_water_mass';
  static const leanBodyMass = 'lean_body_mass';
  static const bmi = 'bmi';
  static const height = 'height';
  static const oxygenSaturation = 'oxygen_saturation';
  static const hrvRmssd = 'hrv_rmssd';
  static const respiratoryRate = 'respiratory_rate';
  static const bloodPressure = 'blood_pressure';
  static const bloodGlucose = 'blood_glucose';
  static const bodyTemperature = 'body_temperature';

  static const steps = 'steps';
  static const distance = 'distance';
  static const activeEnergy = 'active_energy';
  static const totalEnergy = 'total_energy';
  static const floors = 'floors';
  static const elevationGained = 'elevation_gained';
  static const hydration = 'hydration';
  static const wheelchairPushes = 'wheelchair_pushes';

  static const List<HealthMetricSpec> all = [
    HealthMetricSpec(
      key: heartRate,
      unit: 'bpm',
      aggregation: HealthAggregation.average,
      shape: HealthMetricShape.point,
      dense: true,
    ),
    HealthMetricSpec(
      key: restingHeartRate,
      unit: 'bpm',
      aggregation: HealthAggregation.average,
      shape: HealthMetricShape.point,
    ),
    HealthMetricSpec(
      key: speed,
      unit: 'km/h',
      aggregation: HealthAggregation.average,
      shape: HealthMetricShape.point,
      dense: true,
    ),
    HealthMetricSpec(
      key: cadence,
      unit: 'rpm',
      aggregation: HealthAggregation.average,
      shape: HealthMetricShape.point,
      dense: true,
    ),
    HealthMetricSpec(
      key: power,
      unit: 'W',
      aggregation: HealthAggregation.average,
      shape: HealthMetricShape.point,
      dense: true,
    ),
    HealthMetricSpec(
      key: weight,
      unit: 'kg',
      aggregation: HealthAggregation.latest,
      shape: HealthMetricShape.point,
    ),
    HealthMetricSpec(
      key: bodyFat,
      unit: '%',
      aggregation: HealthAggregation.latest,
      shape: HealthMetricShape.point,
    ),
    HealthMetricSpec(
      key: boneMass,
      unit: 'kg',
      aggregation: HealthAggregation.latest,
      shape: HealthMetricShape.point,
    ),
    HealthMetricSpec(
      key: bodyWaterMass,
      unit: 'kg',
      aggregation: HealthAggregation.latest,
      shape: HealthMetricShape.point,
    ),
    HealthMetricSpec(
      key: leanBodyMass,
      unit: 'kg',
      aggregation: HealthAggregation.latest,
      shape: HealthMetricShape.point,
    ),
    HealthMetricSpec(
      key: bmi,
      unit: '',
      aggregation: HealthAggregation.latest,
      shape: HealthMetricShape.point,
    ),
    HealthMetricSpec(
      key: height,
      unit: 'cm',
      aggregation: HealthAggregation.latest,
      shape: HealthMetricShape.point,
    ),
    HealthMetricSpec(
      key: oxygenSaturation,
      unit: '%',
      aggregation: HealthAggregation.average,
      shape: HealthMetricShape.point,
    ),
    HealthMetricSpec(
      key: hrvRmssd,
      unit: 'ms',
      aggregation: HealthAggregation.average,
      shape: HealthMetricShape.point,
    ),
    HealthMetricSpec(
      key: respiratoryRate,
      unit: '/min',
      aggregation: HealthAggregation.average,
      shape: HealthMetricShape.point,
    ),
    // v is systolic, v2 is diastolic: the only paired metric so far.
    HealthMetricSpec(
      key: bloodPressure,
      unit: 'mmHg',
      aggregation: HealthAggregation.latest,
      shape: HealthMetricShape.point,
    ),
    HealthMetricSpec(
      key: bloodGlucose,
      unit: 'mmol/L',
      aggregation: HealthAggregation.average,
      shape: HealthMetricShape.point,
    ),
    HealthMetricSpec(
      key: bodyTemperature,
      unit: 'C',
      aggregation: HealthAggregation.average,
      shape: HealthMetricShape.point,
    ),
    HealthMetricSpec(
      key: steps,
      unit: 'count',
      aggregation: HealthAggregation.total,
      shape: HealthMetricShape.interval,
    ),
    HealthMetricSpec(
      key: distance,
      unit: 'km',
      aggregation: HealthAggregation.total,
      shape: HealthMetricShape.interval,
    ),
    HealthMetricSpec(
      key: activeEnergy,
      unit: 'kcal',
      aggregation: HealthAggregation.total,
      shape: HealthMetricShape.interval,
    ),
    HealthMetricSpec(
      key: totalEnergy,
      unit: 'kcal',
      aggregation: HealthAggregation.total,
      shape: HealthMetricShape.interval,
    ),
    HealthMetricSpec(
      key: floors,
      unit: 'count',
      aggregation: HealthAggregation.total,
      shape: HealthMetricShape.interval,
    ),
    HealthMetricSpec(
      key: elevationGained,
      unit: 'm',
      aggregation: HealthAggregation.total,
      shape: HealthMetricShape.interval,
    ),
    HealthMetricSpec(
      key: hydration,
      unit: 'L',
      aggregation: HealthAggregation.total,
      shape: HealthMetricShape.interval,
    ),
    HealthMetricSpec(
      key: wheelchairPushes,
      unit: 'count',
      aggregation: HealthAggregation.total,
      shape: HealthMetricShape.interval,
    ),
  ];

  static final Map<String, HealthMetricSpec> byKey = {
    for (final spec in all) spec.key: spec,
  };

  static HealthMetricSpec? spec(String key) => byKey[key];
}
