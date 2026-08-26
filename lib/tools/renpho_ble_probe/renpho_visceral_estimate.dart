import 'dart:math' as math;

/// How much fat sits deep in the abdomen, estimated rather than measured.
///
/// A scale with four foot and two hand electrodes sends current through the
/// trunk as one conductor. Nothing in that path separates fat around the organs
/// from fat under the skin, so no consumer scale measures visceral tissue — the
/// device's own 1–59 rating is an index built from the same handful of numbers
/// everything else comes from, and so is this one.
///
/// What this adds is an estimate that can be inspected: an anthropometric
/// regression on age, BMI and trunk fat mass, with trunk fat coming from the
/// segmental impedance model rather than from a body-shape assumption. That is
/// where bioimpedance actually enters. The explicit impedance term below moves
/// the result by about 3 cm² and barely varies between scans of one person, so
/// this index is anthropometric in all but name. Treat it as a trend line, not
/// a measurement, and never as a diagnosis.
class RenphoVisceralEstimate {
  /// Estimated cross-sectional visceral fat area at the navel, the quantity CT
  /// and MRI report. 100 cm² is the classic metabolic-risk threshold.
  final double areaCm2;

  /// The area binned into the 1–30 index the bands below are defined on. Not
  /// the scale's own 1–59 rating and not comparable to it — same idea, different
  /// arbitrary scale.
  final int rating;

  const RenphoVisceralEstimate({required this.areaCm2, required this.rating});

  static const _ageCoefficient = 0.37;
  static const _bmiCoefficient = 3.78;
  static const _trunkFatCoefficient = 1.85;

  /// Weighs the whole-body volume-conductor index. Deliberately whole-body: the
  /// coefficient is sized for a `H²/Z` near 60, which is what a hand-to-foot
  /// path gives. Feeding it a trunk impedance of ~13 Ω instead makes the term
  /// −115 cm², larger than everything else in the equation put together, and
  /// the estimate collapses onto its floor for every body including an obese
  /// one.
  static const _impedanceIndexCoefficient = 0.05;
  static const _intercept = 55.0;

  /// Below this the regression is extrapolating past its own floor; there is
  /// always some visceral tissue.
  static const _minimumAreaCm2 = 10.0;

  static const _areaPerRatingPoint = 10.0;
  static const _maximumRating = 30;
  static const _optimalCeiling = 9;
  static const _elevatedCeiling = 14;

  /// Null when any input is missing, rather than an estimate built on zeroes.
  static RenphoVisceralEstimate? from({
    required int age,
    required double bmi,
    required double trunkFatKg,
    required double heightCm,
    required double wholeBodyImpedance50,
  }) {
    if (age <= 0 ||
        bmi <= 0 ||
        heightCm <= 0 ||
        wholeBodyImpedance50 <= 0 ||
        trunkFatKg < 0) {
      return null;
    }
    final area = math.max(
      _ageCoefficient * age +
          _bmiCoefficient * bmi +
          _trunkFatCoefficient * trunkFatKg -
          _impedanceIndexCoefficient *
              (heightCm * heightCm / wholeBodyImpedance50) -
          _intercept,
      _minimumAreaCm2,
    );
    return RenphoVisceralEstimate(
      areaCm2: area,
      rating: (area / _areaPerRatingPoint).round().clamp(1, _maximumRating),
    );
  }

  RenphoVisceralBand get band => rating <= _optimalCeiling
      ? RenphoVisceralBand.optimal
      : rating <= _elevatedCeiling
      ? RenphoVisceralBand.elevated
      : RenphoVisceralBand.high;

  /// True once the estimate crosses the threshold the cardiometabolic
  /// literature is written around.
  bool get aboveRiskThreshold => areaCm2 >= 100;
}

enum RenphoVisceralBand { optimal, elevated, high }
