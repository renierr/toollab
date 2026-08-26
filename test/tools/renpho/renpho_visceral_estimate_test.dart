import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/renpho_ble_probe/renpho_body_metrics.dart';
import 'package:tool_lab/tools/renpho_ble_probe/renpho_independent_analysis.dart';
import 'package:tool_lab/tools/renpho_ble_probe/renpho_measurement.dart';
import 'package:tool_lab/tools/renpho_ble_probe/renpho_visceral_estimate.dart';

RenphoMeasurement _scan({
  double weightKg = 66.5,
  double bodyFatPercent = 11.8,
  Map<String, double>? impedance,
}) => RenphoMeasurement(
  uid: 'test',
  measuredAt: DateTime(2026, 1, 1),
  weightKg: weightKg,
  bmi: weightKg / (1.73 * 1.73),
  bodyFatPercent: bodyFatPercent,
  musclePercent: 50.0,
  visceralFat: 1,
  impedance:
      impedance ??
      const {
        'z20Body': 15.3,
        'z20HandL': 288.0,
        'z20HandR': 283.2,
        'z20FootL': 216.6,
        'z20FootR': 218.2,
        'z100Body': 11.5,
        'z100HandL': 260.0,
        'z100HandR': 254.8,
        'z100FootL': 194.7,
        'z100FootR': 195.6,
      },
  profileName: 'Test',
  profileSex: 'male',
  profileHeightCm: 173,
  profileAge: 50,
);

RenphoVisceralEstimate _at({
  int age = 50,
  double bmi = 22.2,
  double trunkFatKg = 6.11,
  double impedance = 486.7,
}) => RenphoVisceralEstimate.from(
  age: age,
  bmi: bmi,
  trunkFatKg: trunkFatKg,
  heightCm: 173,
  wholeBodyImpedance50: impedance,
)!;

void main() {
  group('the lean reference body', () {
    test('lands in a plausible visceral area, well under the threshold', () {
      final estimate = _at();
      expect(estimate.areaCm2, inInclusiveRange(30.0, 80.0));
      expect(estimate.aboveRiskThreshold, isFalse);
      expect(estimate.band, RenphoVisceralBand.optimal);
    });

    test('does not sit on the clamp floor', () {
      // The whole point of the fix: a real body must produce a real number,
      // not the 10 cm² minimum every time.
      expect(_at().areaCm2, greaterThan(10.0));
    });
  });

  group('discrimination', () {
    test('area rises with BMI, trunk fat and age', () {
      final base = _at();
      expect(_at(bmi: 28.4).areaCm2, greaterThan(base.areaCm2));
      expect(_at(trunkFatKg: 14.3).areaCm2, greaterThan(base.areaCm2));
      expect(_at(age: 70).areaCm2, greaterThan(base.areaCm2));
    });

    test('an obese body crosses the 100 cm² threshold and rates high', () {
      final obese = _at(bmi: 40.1, trunkFatKg: 30.2);
      expect(obese.aboveRiskThreshold, isTrue);
      expect(obese.rating, greaterThanOrEqualTo(15));
      expect(obese.band, RenphoVisceralBand.high);
    });

    test('an overweight body reads between the two', () {
      final overweight = _at(bmi: 33.4, trunkFatKg: 21.0);
      expect(overweight.band, RenphoVisceralBand.elevated);
      expect(overweight.rating, inInclusiveRange(10, 14));
    });
  });

  group('rating and bands', () {
    test('the rating is the area in tens, bounded to 1 – 30', () {
      final estimate = _at(bmi: 33.4, trunkFatKg: 21.0);
      expect(estimate.rating, (estimate.areaCm2 / 10).round());
      expect(_at(bmi: 12, trunkFatKg: 0).rating, 1);
      expect(_at(bmi: 90, trunkFatKg: 90).rating, 30);
    });

    test('band boundaries fall at 9/10 and 14/15', () {
      for (final estimate in [
        for (var bmi = 15.0; bmi < 60; bmi += 0.25) _at(bmi: bmi),
      ]) {
        final expected = estimate.rating <= 9
            ? RenphoVisceralBand.optimal
            : estimate.rating <= 14
            ? RenphoVisceralBand.elevated
            : RenphoVisceralBand.high;
        expect(estimate.band, expected);
      }
    });

    test('area never falls below the 10 cm² floor', () {
      expect(_at(age: 1, bmi: 1, trunkFatKg: 0).areaCm2, 10.0);
    });
  });

  group('wiring', () {
    test('the analysis feeds it trunk fat from the segmental split', () {
      final analysis = RenphoIndependentAnalysis(RenphoDerived(_scan()));
      expect(analysis.trunkFatMassKg, closeTo(analysis.fatMassKg * 0.6, 1e-9));
      expect(
        analysis.visceralEstimate!.areaCm2,
        closeTo(
          _at(trunkFatKg: analysis.trunkFatMassKg).areaCm2,
          0.5, // the analysis uses its own BMI and Z50, not the rounded ones
        ),
      );
    });

    test('a fatter scan of the same body estimates more visceral fat', () {
      final lean = RenphoIndependentAnalysis(
        RenphoDerived(_scan()),
      ).visceralEstimate!;
      final heavy = RenphoIndependentAnalysis(
        RenphoDerived(_scan(weightKg: 95, bodyFatPercent: 32)),
      ).visceralEstimate!;
      expect(heavy.areaCm2, greaterThan(lean.areaCm2));
    });

    test('no estimate without impedance', () {
      final blank = RenphoIndependentAnalysis(
        RenphoDerived(_scan(impedance: const {})),
      );
      expect(blank.visceralEstimate, isNull);
    });

    test('no estimate without a profile age', () {
      expect(
        RenphoVisceralEstimate.from(
          age: 0,
          bmi: 22.2,
          trunkFatKg: 6.11,
          heightCm: 173,
          wholeBodyImpedance50: 486.7,
        ),
        isNull,
      );
    });
  });
}
