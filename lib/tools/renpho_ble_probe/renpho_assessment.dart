import 'dart:math' as math;

import 'renpho_body_metrics.dart';

enum RenphoRating { low, optimal, elevated, high }

enum RenphoAssessmentMetric {
  bmi,
  bodyFat,
  visceralFat,
  bodyWater,
  skeletalMuscleIndex,
  segmentMuscle,
  symmetry,
}

class RenphoAssessmentEntry {
  final RenphoAssessmentMetric metric;
  final String value;
  final String reference;
  final RenphoRating rating;

  const RenphoAssessmentEntry({
    required this.metric,
    required this.value,
    required this.reference,
    required this.rating,
  });
}

/// Population reference ranges, not a diagnosis: BMI from the WHO classes,
/// body fat from the ACE ranges, the visceral score from the scale's own 1-14
/// scale, and the muscle index from the EWGSOP2 sarcopenia cut-offs.
List<RenphoAssessmentEntry> renphoAssessment(RenphoDerived derived) {
  final measurement = derived.measurement;
  final male = measurement.profileSex == 'male';
  final segments = derived.segments;
  final weakest = segments
      .map((values) => values.muscleOfStandardPercent)
      .reduce(math.min);
  final asymmetry = math.max(
    _difference(derived, RenphoSegment.leftArm, RenphoSegment.rightArm),
    _difference(derived, RenphoSegment.leftLeg, RenphoSegment.rightLeg),
  );

  return [
    RenphoAssessmentEntry(
      metric: RenphoAssessmentMetric.bmi,
      value: derived.bmi.toStringAsFixed(1),
      reference: '18.5 – 24.9',
      rating: _band(derived.bmi, 18.5, 25, 30),
    ),
    RenphoAssessmentEntry(
      metric: RenphoAssessmentMetric.bodyFat,
      value: '${measurement.bodyFatPercent.toStringAsFixed(1)} %',
      reference: male ? '8 – 19.9 %' : '21 – 32.9 %',
      rating: male
          ? _band(measurement.bodyFatPercent, 8, 20, 25)
          : _band(measurement.bodyFatPercent, 21, 33, 39),
    ),
    RenphoAssessmentEntry(
      metric: RenphoAssessmentMetric.visceralFat,
      value: '${measurement.visceralFat}',
      reference: '1 – 9',
      rating: measurement.visceralFat < 10
          ? RenphoRating.optimal
          : measurement.visceralFat < 15
          ? RenphoRating.elevated
          : RenphoRating.high,
    ),
    RenphoAssessmentEntry(
      metric: RenphoAssessmentMetric.bodyWater,
      value: '${derived.bodyWaterPercent.toStringAsFixed(1)} %',
      reference: male ? '50 – 65 %' : '45 – 60 %',
      rating: male
          ? _band(derived.bodyWaterPercent, 50, 65.1, 200)
          : _band(derived.bodyWaterPercent, 45, 60.1, 200),
    ),
    RenphoAssessmentEntry(
      metric: RenphoAssessmentMetric.skeletalMuscleIndex,
      value: '${derived.skeletalMuscleIndex.toStringAsFixed(1)} kg/m²',
      reference: male ? '≥ 7.0 kg/m²' : '≥ 5.5 kg/m²',
      rating: derived.skeletalMuscleIndex < (male ? 7.0 : 5.5)
          ? RenphoRating.low
          : RenphoRating.optimal,
    ),
    RenphoAssessmentEntry(
      metric: RenphoAssessmentMetric.segmentMuscle,
      value: '${weakest.toStringAsFixed(0)} %',
      reference: '≥ 90 %',
      rating: weakest >= 90 ? RenphoRating.optimal : RenphoRating.low,
    ),
    RenphoAssessmentEntry(
      metric: RenphoAssessmentMetric.symmetry,
      value: '${asymmetry.toStringAsFixed(1)} %',
      reference: '< 10 %',
      rating: asymmetry < 10 ? RenphoRating.optimal : RenphoRating.elevated,
    ),
  ];
}

/// Muscle mass difference between two sides, as a percentage of the stronger.
double _difference(RenphoDerived derived, RenphoSegment a, RenphoSegment b) {
  final left = derived.segment(a).muscleMassKg;
  final right = derived.segment(b).muscleMassKg;
  final larger = math.max(left, right);
  if (larger <= 0) return 0;
  return 100 * (left - right).abs() / larger;
}

RenphoRating _band(double value, double low, double high, double veryHigh) =>
    value < low
    ? RenphoRating.low
    : value < high
    ? RenphoRating.optimal
    : value < veryHigh
    ? RenphoRating.elevated
    : RenphoRating.high;
