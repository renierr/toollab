import 'dart:math' as math;

import 'renpho_assessment.dart';
import 'renpho_body_metrics.dart';
import 'renpho_fluid_model.dart';
import 'renpho_visceral_estimate.dart';

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
///    impedance, weighted per segment because trunk tissue does not conduct
///    like limb muscle. Fat is distributed by its own anthropometric ratios,
///    not by subtracting lean from a segment's assumed weight. Both splits sum
///    back to the whole-body figure exactly.
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

  /// Weight on each segment's volume-conductor index. A limb is a long muscle
  /// bundle in line with the current; the trunk is short, wide and full of
  /// organs and fluid, so at ~12 Ω the raw L²/Z reads far more conducting
  /// volume there than there is lean tissue. Dampening it keeps the trunk from
  /// swallowing two thirds of the fat-free mass.
  static const _leanIndexFactor = <RenphoSegment, double>{
    RenphoSegment.leftArm: 1.0,
    RenphoSegment.rightArm: 1.0,
    RenphoSegment.leftLeg: 1.0,
    RenphoSegment.rightLeg: 1.0,
    RenphoSegment.trunk: 0.30,
  };

  /// Where the trunk's share of fat-free mass is allowed to land. Trunk plus
  /// head carries about half of it in DXA reference data, and no impedance
  /// this low can be trusted to say otherwise, so the dampened index sets the
  /// value inside the band and the band sets it outside.
  static const _trunkLeanShareMin = 0.50;
  static const _trunkLeanShareMax = 0.58;

  /// Share of whole-body fat mass per segment, from DXA regional reference
  /// distributions. Trunk includes the head. Both sets sum to 1, so segmental
  /// fat adds back up to total fat by construction.
  static const _fatFractionMale = <RenphoSegment, double>{
    RenphoSegment.leftArm: 0.048,
    RenphoSegment.rightArm: 0.048,
    RenphoSegment.leftLeg: 0.152,
    RenphoSegment.rightLeg: 0.152,
    RenphoSegment.trunk: 0.600,
  };
  static const _fatFractionFemale = <RenphoSegment, double>{
    RenphoSegment.leftArm: 0.055,
    RenphoSegment.rightArm: 0.055,
    RenphoSegment.leftLeg: 0.190,
    RenphoSegment.rightLeg: 0.190,
    RenphoSegment.trunk: 0.510,
  };

  /// How strongly a left/right lean difference tilts that pair's fat the other
  /// way. Half strength: the sides differ in fat, but not by the full lean gap.
  static const _fatAsymmetryCoupling = 0.5;

  /// Non-muscle share of appendicular lean mass — limb bone mineral and skin.
  /// What separates appendicular lean tissue from skeletal muscle.
  static const _limbNonMuscleFraction = 0.067;

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

  /// Trunk fat as this analysis distributes it — the one per-scan input to the
  /// visceral estimate that carries impedance rather than body size.
  double get trunkFatMassKg => segments
      .where((estimate) => estimate.segment == RenphoSegment.trunk)
      .fold<double>(0, (sum, estimate) => sum + estimate.fatMassKg);

  /// An estimate, not a measurement — see [RenphoVisceralEstimate]. Kept out of
  /// the rated findings and the composite score: the scale's own visceral
  /// rating already sits there, and the two are the same guess twice.
  RenphoVisceralEstimate? get visceralEstimate => !usable
      ? null
      : RenphoVisceralEstimate.from(
          age: _age,
          bmi: derived.bmi,
          trunkFatKg: trunkFatMassKg,
          heightCm: _heightCm,
          wholeBodyImpedance50: wholeBodyImpedance50,
        );

  /// The same scan read as a dual-frequency measurement instead of a
  /// reconstructed single-frequency one. Null when the pair cannot carry the
  /// model. Everything else on this class stays on the 50 kHz route, so the
  /// two can be printed side by side.
  RenphoFluidModel? get fluidModel => !usable
      ? null
      : RenphoFluidModel.solve(
          impedance20: derived.wholeBodyImpedance20,
          impedance100: derived.wholeBodyImpedance100,
          heightCm: _heightCm,
          weightKg: _weight,
          male: _male,
        );

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
    final lean = _leanBySegment();
    final fat = _fatBySegment(lean);
    return [
      for (final segment in RenphoSegment.values)
        _estimate(segment, lean[segment]!, fat[segment]!),
    ];
  }

  /// Whole-body fat-free mass split over the weighted volume-conductor index,
  /// with the trunk held to its physiological band and the limbs sharing
  /// whatever is left in proportion to their own indices. Sums to
  /// [fatFreeMassKg] whichever way the band bites.
  Map<RenphoSegment, double> _leanBySegment() {
    final index = <RenphoSegment, double>{
      for (final segment in RenphoSegment.values)
        segment:
            _leanIndexFactor[segment]! *
            math.pow(segmentLengthCm(segment), 2) /
            segmentImpedance50(segment),
    };
    final total = index.values.fold<double>(0, (sum, value) => sum + value);
    final limbIndex = total - index[RenphoSegment.trunk]!;
    if (total <= 0 || limbIndex <= 0) {
      return {for (final segment in RenphoSegment.values) segment: 0};
    }
    final trunkShare = (index[RenphoSegment.trunk]! / total).clamp(
      _trunkLeanShareMin,
      _trunkLeanShareMax,
    );
    return {
      for (final segment in RenphoSegment.values)
        segment: segment == RenphoSegment.trunk
            ? fatFreeMassKg * trunkShare
            : fatFreeMassKg * (1 - trunkShare) * index[segment]! / limbIndex,
    };
  }

  /// Whole-body fat mass spread over the anthropometric fat ratios, then tilted
  /// within each limb pair so the leaner side carries the smaller share. Never
  /// a subtraction: a segment's fat no longer depends on how much lean the
  /// impedance model happened to put there.
  Map<RenphoSegment, double> _fatBySegment(Map<RenphoSegment, double> lean) {
    final fraction = _male ? _fatFractionMale : _fatFractionFemale;
    final fat = <RenphoSegment, double>{
      for (final segment in RenphoSegment.values)
        segment: fatMassKg * fraction[segment]!,
    };
    for (final pair in const [
      (RenphoSegment.leftArm, RenphoSegment.rightArm),
      (RenphoSegment.leftLeg, RenphoSegment.rightLeg),
    ]) {
      final pairFat = fat[pair.$1]! + fat[pair.$2]!;
      final pairLean = lean[pair.$1]! + lean[pair.$2]!;
      if (pairFat <= 0 || pairLean <= 0) continue;
      final leanShare = lean[pair.$1]! / pairLean;
      final fatShare = 0.5 + _fatAsymmetryCoupling * (0.5 - leanShare);
      fat[pair.$1] = pairFat * fatShare;
      fat[pair.$2] = pairFat * (1 - fatShare);
    }
    return fat;
  }

  RenphoSegmentEstimate _estimate(
    RenphoSegment segment,
    double lean,
    double fat,
  ) {
    final scale = derived.segment(segment);
    return RenphoSegmentEstimate(
      segment: segment,
      lengthCm: segmentLengthCm(segment),
      impedance20: segmentImpedance20(segment),
      impedance50: segmentImpedance50(segment),
      impedance100: segmentImpedance100(segment),
      leanMassKg: lean,
      fatMassKg: fat,
      scaleMuscleMassKg: scale.muscleMassKg,
      scaleFatMassKg: scale.fatMassKg,
    );
  }

  /// Lean tissue in the four limbs, from limb impedances only — the trunk's
  /// very low impedance never enters the ratio these four are split by.
  double get appendicularLeanMassKg => segments
      .where((estimate) => estimate.segment != RenphoSegment.trunk)
      .fold<double>(0, (sum, estimate) => sum + estimate.leanMassKg);

  /// Appendicular skeletal muscle mass: limb lean tissue less limb bone and
  /// skin. This, not fat-free mass, is what a DXA sarcopenia report calls ASM.
  double get appendicularSkeletalMuscleMassKg =>
      appendicularLeanMassKg * (1 - _limbNonMuscleFraction);

  /// ASMM over height squared — the EWGSOP2 sarcopenia index.
  double get appendicularSkeletalMuscleIndex =>
      appendicularSkeletalMuscleMassKg / (_heightM * _heightM);

  /// Kim et al. 2002 — whole-body skeletal muscle predicted from appendicular
  /// lean tissue. Reaches the same figure as Janssen by a different route, so
  /// the gap between the two says whether the limb split holds up.
  double get skeletalMuscleMassFromLimbsKg => !usable
      ? 0
      : 1.13 * appendicularSkeletalMuscleMassKg -
            0.02 * _age +
            (_male ? 0.61 : 0) +
            0.97;

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
            ownValue: appendicularSkeletalMuscleIndex,
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
        value: '${appendicularSkeletalMuscleIndex.toStringAsFixed(1)} kg/m²',
        reference: '≥ ${asmiFloor.toStringAsFixed(1)} kg/m²',
        rating: appendicularSkeletalMuscleIndex < asmiFloor
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
  'Kim J. et al., Am J Clin Nutr 2002 — skeletal muscle from appendicular lean soft tissue',
  'Cole K.S., J Gen Physiol 1940 — the dispersion the 20/100 kHz pair is resolved against',
  'De Lorenzo A. et al., J Appl Physiol 1997 — Hanai mixture model for extra- and intracellular water',
  'Examination Committee of Criteria for Obesity Disease in Japan, Circ J 2002 — the 100 cm² visceral fat threshold',
  'Cruz-Jentoft A.J. et al., Age Ageing 2019 (EWGSOP2) — sarcopenia cut-offs for the muscle index',
  'Schutz Y. et al., Int J Obes 2002 — fat-free mass index reference bands',
  'Kelly T.L. et al., PLoS One 2009 — fat mass index bands and DXA regional fat distribution (NHANES)',
  'Winter D.A., Biomechanics and Motor Control of Human Movement — segment lengths and mass fractions',
  'Organ L.W. et al., J Appl Physiol 1994 — segmental volume-conductor model of bioimpedance',
  'WHO Technical Report Series 894 — BMI classification',
  'American Council on Exercise — body fat percentage ranges',
];
