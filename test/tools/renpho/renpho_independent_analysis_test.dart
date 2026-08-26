import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/renpho_ble_probe/renpho_body_metrics.dart';
import 'package:tool_lab/tools/renpho_ble_probe/renpho_independent_analysis.dart';
import 'package:tool_lab/tools/renpho_ble_probe/renpho_measurement.dart';

/// A 66.3 kg, 173 cm male with the impedance profile this scale reports: a
/// trunk near 12 Ω against limbs in the hundreds. The whole point of the
/// segmental model is that the trunk's two-orders-of-magnitude lower impedance
/// must not turn into two thirds of the fat-free mass.
RenphoMeasurement _scan() => RenphoMeasurement(
  uid: 'test',
  measuredAt: DateTime(2026, 1, 1),
  weightKg: 66.3,
  bmi: 22.2,
  bodyFatPercent: 15.0,
  musclePercent: 47.0,
  visceralFat: 6,
  impedance: const {
    'z20HandL': 273.9,
    'z100HandL': 246.6,
    'z20HandR': 270.8,
    'z100HandR': 243.7,
    'z20FootL': 231.5,
    'z100FootL': 208.3,
    'z20FootR': 228.3,
    'z100FootR': 205.5,
    'z20Body': 12.7,
    'z100Body': 11.5,
  },
  profileName: 'Test',
  profileSex: 'male',
  profileHeightCm: 173,
  profileAge: 35,
);

double _fat(RenphoIndependentAnalysis a, RenphoSegment segment) =>
    a.segments.firstWhere((e) => e.segment == segment).fatMassKg;

double _lean(RenphoIndependentAnalysis a, RenphoSegment segment) =>
    a.segments.firstWhere((e) => e.segment == segment).leanMassKg;

void main() {
  late RenphoIndependentAnalysis analysis;

  setUp(() => analysis = RenphoIndependentAnalysis(RenphoDerived(_scan())));

  group('segmental distribution', () {
    test('segmental fat-free mass adds back up to whole-body FFM', () {
      final sum = analysis.segments.fold<double>(
        0,
        (total, e) => total + e.leanMassKg,
      );
      expect(sum, closeTo(analysis.fatFreeMassKg, 1e-9));
    });

    test('segmental fat adds back up to whole-body fat mass', () {
      final sum = analysis.segments.fold<double>(
        0,
        (total, e) => total + e.fatMassKg,
      );
      expect(sum, closeTo(analysis.fatMassKg, 1e-9));
    });

    test('trunk carries about half the fat-free mass, not two thirds', () {
      final share =
          _lean(analysis, RenphoSegment.trunk) / analysis.fatFreeMassKg;
      expect(share, greaterThanOrEqualTo(0.45));
      expect(share, lessThanOrEqualTo(0.58));
    });

    test('segmental fat mass is physiologically distributed', () {
      expect(analysis.fatMassKg, closeTo(9.9, 0.6));
      expect(_fat(analysis, RenphoSegment.trunk), inInclusiveRange(4.0, 6.0));
      expect(_fat(analysis, RenphoSegment.leftLeg), inInclusiveRange(1.2, 1.6));
      expect(
        _fat(analysis, RenphoSegment.rightLeg),
        inInclusiveRange(1.2, 1.6),
      );
      expect(_fat(analysis, RenphoSegment.leftArm), inInclusiveRange(0.3, 0.5));
      expect(
        _fat(analysis, RenphoSegment.rightArm),
        inInclusiveRange(0.3, 0.5),
      );
    });

    test('no segment is left with negative or zero fat', () {
      for (final estimate in analysis.segments) {
        expect(estimate.fatMassKg, greaterThan(0));
        expect(estimate.leanMassKg, greaterThan(0));
      }
    });

    test('the leaner side of a pair carries the smaller share of pair fat', () {
      // The right leg has the lower impedance, so it holds more lean tissue.
      expect(
        _lean(analysis, RenphoSegment.rightLeg),
        greaterThan(_lean(analysis, RenphoSegment.leftLeg)),
      );
      expect(
        _fat(analysis, RenphoSegment.rightLeg),
        lessThan(_fat(analysis, RenphoSegment.leftLeg)),
      );
    });
  });

  group('appendicular muscle', () {
    test('ASMM is smaller than appendicular lean mass', () {
      expect(
        analysis.appendicularSkeletalMuscleMassKg,
        lessThan(analysis.appendicularLeanMassKg),
      );
    });

    test('ASMM equals the sum of the four limb lean masses less bone', () {
      final limbs = [
        RenphoSegment.leftArm,
        RenphoSegment.rightArm,
        RenphoSegment.leftLeg,
        RenphoSegment.rightLeg,
      ].fold<double>(0, (sum, s) => sum + _lean(analysis, s));
      expect(analysis.appendicularLeanMassKg, closeTo(limbs, 1e-9));
      expect(
        analysis.appendicularSkeletalMuscleMassKg,
        closeTo(limbs * 0.933, 1e-9),
      );
    });

    test('ASMI sits in the non-sarcopenic range for this body', () {
      expect(
        analysis.appendicularSkeletalMuscleIndex,
        inInclusiveRange(7.0, 11.0),
      );
    });

    test('Kim from limbs and Janssen whole-body agree within 2 kg', () {
      expect(
        (analysis.skeletalMuscleMassFromLimbsKg - analysis.skeletalMuscleMassKg)
            .abs(),
        lessThan(2.0),
      );
    });

    test('skeletal muscle stays below fat-free mass', () {
      expect(analysis.skeletalMuscleMassKg, lessThan(analysis.fatFreeMassKg));
      expect(
        analysis.skeletalMuscleMassFromLimbsKg,
        lessThan(analysis.fatFreeMassKg),
      );
    });
  });

  test('a scan without impedance yields no segments', () {
    final blank = RenphoIndependentAnalysis(
      RenphoDerived(
        RenphoMeasurement(
          uid: 'blank',
          measuredAt: DateTime(2026, 1, 1),
          weightKg: 66.3,
          bmi: 22.2,
          bodyFatPercent: 15,
          musclePercent: 47,
          visceralFat: 6,
          impedance: const {},
          profileName: 'Test',
          profileSex: 'male',
          profileHeightCm: 173,
          profileAge: 35,
        ),
      ),
    );
    expect(blank.usable, isFalse);
    expect(blank.segments, isEmpty);
    expect(blank.appendicularSkeletalMuscleMassKg, 0);
  });
}
