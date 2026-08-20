import 'dart:math' as math;

import 'renpho_measurement.dart';

/// Everything derivable from one scan.
///
/// The scale itself reports only weight, BMI, body fat, muscle, the visceral
/// score and ten segment impedances. Every other figure the Renpho app shows is
/// computed, and so is computed here.
///
/// Three tiers, kept apart on purpose:
///  * exact arithmetic — fat mass, fat-free mass, BMI, segment sums;
///  * the Renpho model — coefficients recovered from 144 cloud records of one
///    profile, so [modelCalibrated] says whether that profile is this one;
///  * published equations — peer-reviewed, profile-independent, and calibrated
///    against different reference methods, so they read a few kilograms apart.
class RenphoDerived {
  final RenphoMeasurement measurement;

  RenphoDerived(this.measurement);

  double get _weight => measurement.weightKg;
  double get _bodyFat => measurement.bodyFatPercent;
  double get _muscle => measurement.musclePercent;
  double get _heightM => measurement.profileHeightCm / 100;

  // Exact arithmetic.
  double get bmi => _weight / (_heightM * _heightM);
  double get fatMassKg => _weight * _bodyFat / 100;
  double get fatFreeMassKg => _weight - fatMassKg;
  double get skeletalMuscleMassKg => _weight * _muscle / 100;

  // Renpho model, whole body. Constants fixed by interval intersection over
  // every cloud record: no other scale factor fits all of their roundings.
  double get subcutaneousFatPercent => 0.71782 * _bodyFat;
  double get boneMassKg => 0.067 * fatFreeMassKg;

  double get bodyWaterPercent =>
      39.56483 - 0.05272 * _weight - 0.31522 * _bodyFat + 0.64686 * _muscle;
  double get bodyWaterMassKg => bodyWaterPercent * _weight / 100;
  double get proteinPercent =>
      13.11305 - 0.01381 * _weight - 0.11097 * _bodyFat + 0.13529 * _muscle;
  double get proteinMassKg => proteinPercent * _weight / 100;
  double get leanSoftTissuePercent => bodyWaterPercent + proteinPercent;
  double get leanSoftTissueKg => leanSoftTissuePercent * _weight / 100;

  double get bmrRenphoKcal =>
      -107.6043 + 18.2086 * _weight - 6.7841 * _bodyFat + 12.2708 * _muscle;
  double get bodyScore =>
      -48.7489 + 0.9416 * _weight + 0.7384 * _bodyFat + 1.1539 * _muscle;

  int get bodyType => bmi >= _bmiStandard ? 4 : 3;
  int get obesityDegreePercent =>
      (100 * _weight / (_bmiStandard * _heightM * _heightM)).round();
  double get weightControlKg => _standardFatMassKg - fatMassKg;
  double get targetWeightKg => _weight + weightControlKg;

  // Renpho model, per segment. Each mass is
  // c0 + c1 * whole-body mass + c2 * g100 + c3 * g20, where g = 1000 / Z and
  // the whole-body mass is the skeletal muscle mass for muscle, fat mass for
  // fat.
  static const _segmentModels = <String, List<double>>{
    'laMuscleMass': [-0.506920, 0.096235, 0.386486, -0.251491],
    'raMuscleMass': [-0.492507, 0.095598, 0.337750, -0.195353],
    'llMuscleMass': [0.073889, 0.289224, -0.408007, 0.448080],
    'rlMuscleMass': [0.071002, 0.288208, -0.414355, 0.463571],
    'tMuscleMass': [1.776501, 0.713288, 0.000004, 0.001205],
    'laBodyFatMass': [-0.116489, 0.080812, -0.423178, 0.395069],
    'raBodyFatMass': [-0.129243, 0.080885, -0.398037, 0.370356],
    'llBodyFatMass': [0.335702, 0.134983, -0.284365, 0.339794],
    'rlBodyFatMass': [0.325931, 0.135254, -0.290263, 0.347911],
    'tBodyFatMass': [-0.345557, 0.549869, 0.013932, -0.013862],
  };
  static const _segmentImpedance = <RenphoSegment, String>{
    RenphoSegment.leftArm: 'HandL',
    RenphoSegment.rightArm: 'HandR',
    RenphoSegment.leftLeg: 'FootL',
    RenphoSegment.rightLeg: 'FootR',
    RenphoSegment.trunk: 'Body',
  };

  /// Reference values the cloud keeps per profile. They are constants for the
  /// calibration profile and cannot be derived from a measurement.
  static const _standardFatMassKg = 9.9;
  static const _bmiStandard = 22.0;
  static const _standardFatMassBySegment = <RenphoSegment, double>{
    RenphoSegment.leftArm: 0.64,
    RenphoSegment.rightArm: 0.64,
    RenphoSegment.leftLeg: 1.65,
    RenphoSegment.rightLeg: 1.65,
    RenphoSegment.trunk: 4.21,
  };

  RenphoSegmentValues segment(RenphoSegment segment) {
    final key = _segmentImpedance[segment]!;
    final muscleMass = _segmentModel(
      _segmentModels['${segment.prefix}MuscleMass']!,
      skeletalMuscleMassKg,
      key,
    );
    final fatMass = _segmentModel(
      _segmentModels['${segment.prefix}BodyFatMass']!,
      fatMassKg,
      key,
    );
    final muscleStandard = switch (segment) {
      RenphoSegment.leftArm ||
      RenphoSegment.rightArm => 1.67218 + 0.020106 * _weight,
      RenphoSegment.leftLeg ||
      RenphoSegment.rightLeg => 4.46854 + 0.059393 * _weight,
      RenphoSegment.trunk => 13.11771 + 0.165364 * _weight,
    };
    return RenphoSegmentValues(
      segment: segment,
      muscleMassKg: muscleMass,
      muscleOfStandardPercent: 100 * muscleMass / muscleStandard,
      fatMassKg: fatMass,
      fatOfStandardPercent: 100 * fatMass / _standardFatMassBySegment[segment]!,
      impedance20: measurement.impedance['z20$key'] ?? 0,
      impedance100: measurement.impedance['z100$key'] ?? 0,
    );
  }

  List<RenphoSegmentValues> get segments => [
    for (final value in RenphoSegment.values) segment(value),
  ];

  double _segmentModel(List<double> c, double wholeBodyMass, String key) {
    final z100 = measurement.impedance['z100$key'] ?? 0;
    final z20 = measurement.impedance['z20$key'] ?? 0;
    if (z100 <= 0 || z20 <= 0) return 0;
    return c[0] +
        c[1] * wholeBodyMass +
        c[2] * (1000 / z100) +
        c[3] * (1000 / z20);
  }

  /// Appendicular skeletal muscle over height squared.
  double get skeletalMuscleIndex {
    final limbs = [
      RenphoSegment.leftArm,
      RenphoSegment.rightArm,
      RenphoSegment.leftLeg,
      RenphoSegment.rightLeg,
    ].fold<double>(0, (sum, value) => sum + segment(value).muscleMassKg);
    return limbs / (_heightM * _heightM);
  }

  /// Arm + torso + leg path approximation, not an extra scale measurement.
  double get wholeBodyImpedance20 => _wholeBody('z20');
  double get wholeBodyImpedance100 => _wholeBody('z100');

  /// A recognised extracellular-water and cell-integrity proxy, computable
  /// only because this scale exposes both frequencies.
  double get impedanceRatio => wholeBodyImpedance20 <= 0
      ? 0
      : wholeBodyImpedance100 / wholeBodyImpedance20;

  double _wholeBody(String prefix) {
    double at(String key) => measurement.impedance['$prefix$key'] ?? 0;
    return at('Body') +
        (at('HandL') + at('HandR')) / 2 +
        (at('FootL') + at('FootR')) / 2;
  }

  double get armImpedanceDifference =>
      ((measurement.impedance['z100HandL'] ?? 0) -
              (measurement.impedance['z100HandR'] ?? 0))
          .abs();

  double get legImpedanceDifference =>
      ((measurement.impedance['z100FootL'] ?? 0) -
              (measurement.impedance['z100FootR'] ?? 0))
          .abs();

  // Standard, profile-independent resting-energy estimates.
  double get bmrMifflinKcal {
    final base =
        10 * _weight +
        6.25 * measurement.profileHeightCm -
        5 * measurement.profileAge;
    return measurement.profileSex == 'male' ? base + 5 : base - 161;
  }

  double get bmrKatchMcArdleKcal => 370 + 21.6 * fatFreeMassKg;

  /// What the Health Connect export uses. Katch-McArdle rides on the measured
  /// fat-free mass, so it stays honest for a profile the Renpho model was never
  /// fitted to.
  double get bmrForExportKcal =>
      modelCalibrated ? bmrRenphoKcal : bmrKatchMcArdleKcal;

  /// Whether the Renpho model's fitted coefficients were derived from a profile
  /// like this one. Sex and height are folded into every intercept, so a
  /// different body reads those fields as indicative at best.
  bool get modelCalibrated =>
      measurement.profileSex == calibrationSex &&
      (measurement.profileHeightCm - calibrationHeightCm).abs() < 2.0;

  static const calibrationSex = 'male';
  static const calibrationHeightCm = 173.0;

  /// Peer-reviewed equations, for cross-checking only. All are specified for
  /// 50 kHz resistance; this scale measures 20 and 100 kHz magnitude and no
  /// reactance, so the 50 kHz figure is a linear interpolation and the weakest
  /// assumption here.
  List<RenphoPublishedEstimate> get publishedEstimates {
    final h2 = measurement.profileHeightCm * measurement.profileHeightCm;
    final male = measurement.profileSex == 'male';
    final z20 = wholeBodyImpedance20;
    final z100 = wholeBodyImpedance100;
    final z50 = z20 + (z100 - z20) * 30 / 80;
    if (z20 <= 0 || z100 <= 0) return const [];

    double tbw(double z) => male
        ? 0.396 * h2 / z + 0.143 * _weight + 8.399
        : 0.382 * h2 / z + 0.105 * _weight + 8.315;
    double ffm(double z) => male
        ? -10.68 + 0.65 * h2 / z + 0.26 * _weight + 0.02 * z
        : -9.53 + 0.69 * h2 / z + 0.17 * _weight + 0.02 * z;
    double smm(double z) =>
        0.401 * h2 / z +
        (male ? 3.825 : 0) -
        0.071 * measurement.profileAge +
        5.102;

    return [
      for (final entry in <(String, String, double Function(double))>[
        ('Kushner-Schoeller 1986', 'L', tbw),
        ('Sun 2003', 'kg', ffm),
        ('Janssen 2000', 'kg', smm),
      ])
        RenphoPublishedEstimate(
          equation: entry.$1,
          unit: entry.$2,
          at100kHz: entry.$3(z100),
          at50kHz: entry.$3(z50),
          at20kHz: entry.$3(z20),
        ),
    ];
  }

  /// The interpolated 50 kHz whole-body impedance the published equations use.
  double get interpolatedImpedance50 =>
      wholeBodyImpedance20 +
      (wholeBodyImpedance100 - wholeBodyImpedance20) * 30 / 80;
}

enum RenphoSegment {
  leftArm('la'),
  rightArm('ra'),
  leftLeg('ll'),
  rightLeg('rl'),
  trunk('t');

  final String prefix;
  const RenphoSegment(this.prefix);
}

class RenphoSegmentValues {
  final RenphoSegment segment;
  final double muscleMassKg;
  final double muscleOfStandardPercent;
  final double fatMassKg;
  final double fatOfStandardPercent;
  final double impedance20;
  final double impedance100;

  const RenphoSegmentValues({
    required this.segment,
    required this.muscleMassKg,
    required this.muscleOfStandardPercent,
    required this.fatMassKg,
    required this.fatOfStandardPercent,
    required this.impedance20,
    required this.impedance100,
  });

  double get impedanceRatio =>
      impedance20 <= 0 ? 0 : impedance100 / impedance20;
}

class RenphoPublishedEstimate {
  final String equation;
  final String unit;
  final double at100kHz;
  final double at50kHz;
  final double at20kHz;

  const RenphoPublishedEstimate({
    required this.equation,
    required this.unit,
    required this.at100kHz,
    required this.at50kHz,
    required this.at20kHz,
  });
}

/// Clamps a value into the range Health Connect accepts, so one implausible
/// reading cannot make the whole batch bounce.
double renphoClamp(double value, double min, double max) =>
    math.min(math.max(value, min), max);
