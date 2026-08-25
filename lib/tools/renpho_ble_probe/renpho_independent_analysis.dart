import 'dart:math' as math;

import 'renpho_assessment.dart';
import 'renpho_body_metrics.dart';

/// A second opinion on one scan, computed from the raw segment impedances
/// alone.
///
/// The scale hands over ten magnitudes — five body segments at 20 and 100 kHz —
/// and its own body composition. Everything here rebuilds the composition from
/// those magnitudes with published, profile-independent equations, so the two
/// can be held side by side and the places where they disagree become visible.
///
/// Three deliberate choices, each of them the weak point of a different part of
/// the result:
///
///  * **50 kHz is reconstructed, not measured.** Every validated BIA equation
///    is specified for 50 kHz resistance. Between 20 and 100 kHz the magnitude
///    falls along the Cole dispersion, which is close to linear in log
///    frequency, so the reconstruction interpolates there rather than in
///    frequency itself. See [renphoImpedance50].
///  * **Magnitude stands in for resistance.** The scale reports no reactance,
///    so no phase angle and no true extracellular/intracellular split can be
///    computed. At 50 kHz the reactance is small enough that |Z| runs a few
///    percent above R, which biases every lean estimate slightly low.
///  * **Segment masses are a distribution, not five separate measurements.**
///    The absolute scale comes from the whole-body Sun 2003 equation; the split
///    between segments comes from the volume-conductor model, in which a
///    segment's conducting volume goes with its length squared over its
///    impedance. No per-segment resistivity constant is invented.
class RenphoIndependentAnalysis {
  final RenphoDerived derived;

  RenphoIndependentAnalysis(this.derived);

  double get _weight => derived.measurement.weightKg;
  double get _heightCm => derived.measurement.profileHeightCm;
  double get _heightM => _heightCm / 100;
  int get _age => derived.measurement.profileAge;
  bool get _male => derived.measurement.profileSex == 'male';

  /// Segment length along the path the current actually takes: hand grip to
  /// shoulder, foot plate to hip, hip to shoulder. Fractions of standing height
  /// from the Drillis & Contini anthropometric table as tabulated by Winter.
  static const _armLengthFraction = 0.380;
  static const _legLengthFraction = 0.530;
  static const _trunkLengthFraction = 0.288;

  /// Share of body mass carried by each segment, same source. The trunk share
  /// includes the head, which carries little fat — one reason the trunk fat
  /// figure is the softest number on the page.
  static const _massFraction = <RenphoSegment, double>{
    RenphoSegment.leftArm: 0.050,
    RenphoSegment.rightArm: 0.050,
    RenphoSegment.leftLeg: 0.161,
    RenphoSegment.rightLeg: 0.161,
    RenphoSegment.trunk: 0.578,
  };

  static const _impedanceKey = <RenphoSegment, String>{
    RenphoSegment.leftArm: 'HandL',
    RenphoSegment.rightArm: 'HandR',
    RenphoSegment.leftLeg: 'FootL',
    RenphoSegment.rightLeg: 'FootR',
    RenphoSegment.trunk: 'Body',
  };

  double segmentLengthCm(RenphoSegment segment) => switch (segment) {
    RenphoSegment.leftArm ||
    RenphoSegment.rightArm => _heightCm * _armLengthFraction,
    RenphoSegment.leftLeg ||
    RenphoSegment.rightLeg => _heightCm * _legLengthFraction,
    RenphoSegment.trunk => _heightCm * _trunkLengthFraction,
  };

  double segmentImpedance20(RenphoSegment segment) =>
      derived.measurement.impedance['z20${_impedanceKey[segment]}'] ?? 0;

  double segmentImpedance100(RenphoSegment segment) =>
      derived.measurement.impedance['z100${_impedanceKey[segment]}'] ?? 0;

  double segmentImpedance50(RenphoSegment segment) => renphoImpedance50(
    segmentImpedance20(segment),
    segmentImpedance100(segment),
  );

  /// True once every segment carries both frequencies. A plain weigh-in has no
  /// impedance at all, and half a scan is worse than none here.
  bool get usable => RenphoSegment.values.every(
    (segment) =>
        segmentImpedance20(segment) > 0 && segmentImpedance100(segment) > 0,
  );

  double get wholeBodyImpedance50 => renphoImpedance50(
    derived.wholeBodyImpedance20,
    derived.wholeBodyImpedance100,
  );

  /// The linear-in-frequency reading the same two points would give. Shown next
  /// to the Cole reconstruction because the gap between them is the honest size
  /// of the assumption.
  double get wholeBodyImpedance50Linear =>
      derived.wholeBodyImpedance20 +
      (derived.wholeBodyImpedance100 - derived.wholeBodyImpedance20) * 30 / 80;

  double get _index => _heightCm * _heightCm / wholeBodyImpedance50;

  /// Sun et al. 2003 — NHANES III, referenced against a four-compartment model.
  double get fatFreeMassKg {
    if (!usable) return 0;
    final z = wholeBodyImpedance50;
    return _male
        ? -10.68 + 0.65 * _index + 0.26 * _weight + 0.02 * z
        : -9.53 + 0.69 * _index + 0.17 * _weight + 0.02 * z;
  }

  /// Kushner & Schoeller 1986 — deuterium-dilution referenced.
  double get totalBodyWaterL => !usable
      ? 0
      : _male
      ? 0.396 * _index + 0.143 * _weight + 8.399
      : 0.382 * _index + 0.105 * _weight + 8.315;

  /// Janssen et al. 2000 — MRI-referenced whole-body skeletal muscle.
  double get skeletalMuscleMassKg =>
      !usable ? 0 : 0.401 * _index + (_male ? 3.825 : 0) - 0.071 * _age + 5.102;

  double get fatMassKg => math.max(_weight - fatFreeMassKg, 0);
  double get bodyFatPercent => _weight <= 0 ? 0 : 100 * fatMassKg / _weight;
  double get bodyWaterPercent =>
      _weight <= 0 ? 0 : 100 * totalBodyWaterL / _weight;

  /// Water as a share of the fat-free mass. Hydration of lean tissue is close
  /// to a biological constant near 73 %, so a figure far off that says the two
  /// equations disagree about this body rather than that the body is dry.
  double get hydrationOfLeanPercent =>
      fatFreeMassKg <= 0 ? 0 : 100 * totalBodyWaterL / fatFreeMassKg;

  /// Fat-free and fat mass normalised by height, the way BMI normalises weight.
  /// Reference bands from Schutz et al. 2002 (FFMI) and Kelly et al. 2009 (FMI).
  double get fatFreeMassIndex => fatFreeMassKg / (_heightM * _heightM);
  double get fatMassIndex => fatMassKg / (_heightM * _heightM);

  List<RenphoSegmentEstimate> get segments {
    if (!usable) return const [];
    final volumeIndex = <RenphoSegment, double>{
      for (final segment in RenphoSegment.values)
        segment:
            math.pow(segmentLengthCm(segment), 2) / segmentImpedance50(segment),
    };
    final total = volumeIndex.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    return [
      for (final segment in RenphoSegment.values)
        _estimate(segment, total <= 0 ? 0 : volumeIndex[segment]! / total),
    ];
  }

  RenphoSegmentEstimate _estimate(RenphoSegment segment, double share) {
    final lean = fatFreeMassKg * share;
    final scale = derived.segment(segment);
    return RenphoSegmentEstimate(
      segment: segment,
      lengthCm: segmentLengthCm(segment),
      impedance20: segmentImpedance20(segment),
      impedance50: segmentImpedance50(segment),
      impedance100: segmentImpedance100(segment),
      leanMassKg: lean,
      fatMassKg: math.max(_weight * _massFraction[segment]! - lean, 0),
      scaleMuscleMassKg: scale.muscleMassKg,
      scaleFatMassKg: scale.fatMassKg,
    );
  }

  double get appendicularLeanMassKg => segments
      .where((estimate) => estimate.segment != RenphoSegment.trunk)
      .fold<double>(0, (sum, estimate) => sum + estimate.leanMassKg);

  /// Appendicular lean mass over height squared — the EWGSOP2 sarcopenia index.
  double get appendicularLeanMassIndex =>
      appendicularLeanMassKg / (_heightM * _heightM);

  /// Largest left/right lean difference, as a share of the stronger side.
  double get asymmetryPercent {
    final byId = {
      for (final estimate in segments) estimate.segment: estimate.leanMassKg,
    };
    double pair(RenphoSegment a, RenphoSegment b) {
      final left = byId[a] ?? 0;
      final right = byId[b] ?? 0;
      final larger = math.max(left, right);
      return larger <= 0 ? 0 : 100 * (left - right).abs() / larger;
    }

    return math.max(
      pair(RenphoSegment.leftArm, RenphoSegment.rightArm),
      pair(RenphoSegment.leftLeg, RenphoSegment.rightLeg),
    );
  }

  /// How far the most deviant segment's 100/20 kHz ratio sits from this body's
  /// own mean. A within-subject comparison on purpose: there is no published
  /// population band for this scale's frequency pair, but a segment that
  /// conducts unlike the rest of the same body is still worth seeing.
  double get conductionSpreadPercent {
    final ratios = [
      for (final estimate in segments)
        if (estimate.impedanceRatio > 0) estimate.impedanceRatio,
    ];
    if (ratios.length < 2) return 0;
    final mean = ratios.reduce((a, b) => a + b) / ratios.length;
    if (mean <= 0) return 0;
    return ratios
        .map((ratio) => 100 * (ratio - mean).abs() / mean)
        .reduce(math.max);
  }

  List<RenphoComparison> get comparisons => !usable
      ? const []
      : [
          RenphoComparison(
            metric: RenphoComparisonMetric.fatFreeMass,
            unit: 'kg',
            scaleValue: derived.fatFreeMassKg,
            ownValue: fatFreeMassKg,
          ),
          RenphoComparison(
            metric: RenphoComparisonMetric.fatMass,
            unit: 'kg',
            scaleValue: derived.fatMassKg,
            ownValue: fatMassKg,
          ),
          RenphoComparison(
            metric: RenphoComparisonMetric.bodyFatPercent,
            unit: '%',
            scaleValue: derived.measurement.bodyFatPercent,
            ownValue: bodyFatPercent,
          ),
          RenphoComparison(
            metric: RenphoComparisonMetric.skeletalMuscleMass,
            unit: 'kg',
            scaleValue: derived.skeletalMuscleMassKg,
            ownValue: skeletalMuscleMassKg,
          ),
          RenphoComparison(
            metric: RenphoComparisonMetric.bodyWater,
            unit: 'L',
            scaleValue: derived.bodyWaterMassKg,
            ownValue: totalBodyWaterL,
          ),
          RenphoComparison(
            metric: RenphoComparisonMetric.muscleIndex,
            unit: 'kg/m²',
            scaleValue: derived.skeletalMuscleIndex,
            ownValue: appendicularLeanMassIndex,
          ),
        ];

  /// Mean absolute deviation between the scale and this analysis over the mass
  /// comparisons. Percentages and indices are left out — they would count the
  /// same disagreement twice.
  double get agreementDeviationPercent {
    final masses = comparisons
        .where((row) => row.unit == 'kg' || row.unit == 'L')
        .toList();
    if (masses.isEmpty) return 0;
    return masses.map((row) => row.deviationPercent).reduce((a, b) => a + b) /
        masses.length;
  }

  List<RenphoFinding> get findings {
    if (!usable) return const [];
    final bmi = derived.bmi;
    final visceral = derived.measurement.visceralFat;
    final asmiFloor = _male ? 7.0 : 5.5;
    return [
      RenphoFinding(
        kind: RenphoFindingKind.bmi,
        value: bmi.toStringAsFixed(1),
        reference: '18.5 – 24.9',
        rating: _band(bmi, 18.5, 25, 30),
      ),
      RenphoFinding(
        kind: RenphoFindingKind.bodyFat,
        value: '${bodyFatPercent.toStringAsFixed(1)} %',
        reference: _male ? '8 – 19.9 %' : '21 – 32.9 %',
        rating: _male
            ? _band(bodyFatPercent, 8, 20, 25)
            : _band(bodyFatPercent, 21, 33, 39),
      ),
      RenphoFinding(
        kind: RenphoFindingKind.fatMassIndex,
        value: '${fatMassIndex.toStringAsFixed(1)} kg/m²',
        reference: _male ? '3 – 6 kg/m²' : '5 – 9 kg/m²',
        rating: _male
            ? _band(fatMassIndex, 3, 6, 9)
            : _band(fatMassIndex, 5, 9, 13),
      ),
      RenphoFinding(
        kind: RenphoFindingKind.fatFreeMassIndex,
        value: '${fatFreeMassIndex.toStringAsFixed(1)} kg/m²',
        reference: _male ? '16.7 – 19.8 kg/m²' : '14.6 – 16.8 kg/m²',
        rating: _male
            ? _band(fatFreeMassIndex, 16.7, 19.9, 1000)
            : _band(fatFreeMassIndex, 14.6, 16.9, 1000),
      ),
      RenphoFinding(
        kind: RenphoFindingKind.muscleIndex,
        value: '${appendicularLeanMassIndex.toStringAsFixed(1)} kg/m²',
        reference: '≥ ${asmiFloor.toStringAsFixed(1)} kg/m²',
        rating: appendicularLeanMassIndex < asmiFloor
            ? RenphoRating.low
            : RenphoRating.optimal,
      ),
      RenphoFinding(
        kind: RenphoFindingKind.visceralFat,
        value: '$visceral',
        reference: '1 – 9',
        rating: visceral < 10
            ? RenphoRating.optimal
            : visceral < 15
            ? RenphoRating.elevated
            : RenphoRating.high,
      ),
      RenphoFinding(
        kind: RenphoFindingKind.hydration,
        value: '${hydrationOfLeanPercent.toStringAsFixed(1)} %',
        reference: '70 – 76 %',
        rating: _band(hydrationOfLeanPercent, 70, 76.1, 82),
      ),
      RenphoFinding(
        kind: RenphoFindingKind.segmentBalance,
        value: '${asymmetryPercent.toStringAsFixed(1)} %',
        reference: '< 10 %',
        rating: asymmetryPercent < 10
            ? RenphoRating.optimal
            : asymmetryPercent < 15
            ? RenphoRating.elevated
            : RenphoRating.high,
      ),
      RenphoFinding(
        kind: RenphoFindingKind.conductionSpread,
        value: '${conductionSpreadPercent.toStringAsFixed(1)} %',
        reference: '< 5 %',
        rating: conductionSpreadPercent < 5
            ? RenphoRating.optimal
            : RenphoRating.elevated,
      ),
      RenphoFinding(
        kind: RenphoFindingKind.agreement,
        value: '${agreementDeviationPercent.toStringAsFixed(1)} %',
        reference: '< 5 %',
        rating: agreementDeviationPercent < 5
            ? RenphoRating.optimal
            : agreementDeviationPercent < 10
            ? RenphoRating.elevated
            : RenphoRating.high,
      ),
    ];
  }

  /// The findings that describe the body, without the one that only describes
  /// how well the two calculations agree.
  List<RenphoFinding> get healthFindings => findings
      .where((finding) => finding.kind != RenphoFindingKind.agreement)
      .toList();

  /// A composite out of 100. Not a published index — a readable roll-up of how
  /// many of the findings sit inside their reference range, weighted by how far
  /// outside the rest are.
  int get compositeScore {
    final rated = healthFindings;
    if (rated.isEmpty) return 0;
    var score = 100.0;
    for (final finding in rated) {
      score += switch (finding.rating) {
        RenphoRating.optimal => 0,
        RenphoRating.low || RenphoRating.elevated => -8,
        RenphoRating.high => -16,
      };
    }
    return score.clamp(0, 100).round();
  }

  RenphoOverallStatus get overallStatus {
    final score = compositeScore;
    if (score >= 90) return RenphoOverallStatus.excellent;
    if (score >= 75) return RenphoOverallStatus.good;
    if (score >= 55) return RenphoOverallStatus.fair;
    return RenphoOverallStatus.attention;
  }

  int get findingsInRange => healthFindings
      .where((finding) => finding.rating == RenphoRating.optimal)
      .length;
}

class RenphoSegmentEstimate {
  final RenphoSegment segment;
  final double lengthCm;
  final double impedance20;
  final double impedance50;
  final double impedance100;
  final double leanMassKg;
  final double fatMassKg;
  final double scaleMuscleMassKg;
  final double scaleFatMassKg;

  const RenphoSegmentEstimate({
    required this.segment,
    required this.lengthCm,
    required this.impedance20,
    required this.impedance50,
    required this.impedance100,
    required this.leanMassKg,
    required this.fatMassKg,
    required this.scaleMuscleMassKg,
    required this.scaleFatMassKg,
  });

  double get impedanceRatio =>
      impedance20 <= 0 ? 0 : impedance100 / impedance20;

  /// The scale reports skeletal muscle, this analysis reports lean tissue, and
  /// lean tissue is the larger of the two by definition. The gap is therefore
  /// expected to be positive; its size is what says something.
  double get leanMinusMuscleKg => leanMassKg - scaleMuscleMassKg;

  double get fatDeviationPercent => scaleFatMassKg <= 0
      ? 0
      : 100 * (fatMassKg - scaleFatMassKg) / scaleFatMassKg;
}

enum RenphoComparisonMetric {
  fatFreeMass,
  fatMass,
  bodyFatPercent,
  skeletalMuscleMass,
  bodyWater,
  muscleIndex,
}

class RenphoComparison {
  final RenphoComparisonMetric metric;
  final String unit;
  final double scaleValue;
  final double ownValue;

  const RenphoComparison({
    required this.metric,
    required this.unit,
    required this.scaleValue,
    required this.ownValue,
  });

  double get delta => ownValue - scaleValue;

  double get deviationPercent =>
      scaleValue == 0 ? 0 : 100 * (delta / scaleValue).abs();

  int get decimals => unit == 'kg' || unit == 'L' ? 2 : 1;
}

enum RenphoFindingKind {
  bmi,
  bodyFat,
  fatMassIndex,
  fatFreeMassIndex,
  muscleIndex,
  visceralFat,
  hydration,
  segmentBalance,
  conductionSpread,
  agreement,
}

class RenphoFinding {
  final RenphoFindingKind kind;
  final String value;
  final String reference;
  final RenphoRating rating;

  const RenphoFinding({
    required this.kind,
    required this.value,
    required this.reference,
    required this.rating,
  });
}

enum RenphoOverallStatus { excellent, good, fair, attention }

RenphoRating _band(double value, double low, double high, double veryHigh) =>
    value < low
    ? RenphoRating.low
    : value < high
    ? RenphoRating.optimal
    : value < veryHigh
    ? RenphoRating.elevated
    : RenphoRating.high;

/// The studies every figure in this analysis comes from. Citations, not prose —
/// they read the same in every language.
const renphoReferenceList = <String>[
  'Sun S.S. et al., Am J Clin Nutr 2003 — fat-free mass from bioimpedance (NHANES III)',
  'Kushner R.F., Schoeller D.A., Am J Clin Nutr 1986 — total body water from bioimpedance',
  'Janssen I. et al., J Appl Physiol 2000 — whole-body skeletal muscle from bioimpedance',
  'Cruz-Jentoft A.J. et al., Age Ageing 2019 (EWGSOP2) — sarcopenia cut-offs for the muscle index',
  'Schutz Y. et al., Int J Obes 2002 — fat-free mass index reference bands',
  'Kelly T.L. et al., PLoS One 2009 — fat mass index reference bands (NHANES)',
  'Winter D.A., Biomechanics and Motor Control of Human Movement — segment lengths and mass fractions',
  'Organ L.W. et al., J Appl Physiol 1994 — segmental volume-conductor model of bioimpedance',
  'WHO Technical Report Series 894 — BMI classification',
  'American Council on Exercise — body fat percentage ranges',
];
