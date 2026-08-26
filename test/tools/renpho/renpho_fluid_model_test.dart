import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/renpho_ble_probe/renpho_body_metrics.dart';
import 'package:tool_lab/tools/renpho_ble_probe/renpho_fluid_model.dart';
import 'package:tool_lab/tools/renpho_ble_probe/renpho_independent_analysis.dart';
import 'package:tool_lab/tools/renpho_ble_probe/renpho_measurement.dart';

/// Whole-body magnitudes of a real 66.5 kg / 173 cm male scan: the arm, trunk
/// and leg impedances this scale reports sum to 518.3 Ω at 20 kHz and 464.0 Ω
/// at 100 kHz.
RenphoMeasurement _scan({
  double weightKg = 66.5,
  String sex = 'male',
  Map<String, double>? impedance,
}) => RenphoMeasurement(
  uid: 'test',
  measuredAt: DateTime(2026, 1, 1),
  weightKg: weightKg,
  bmi: 22.2,
  bodyFatPercent: 11.8,
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
  profileSex: sex,
  profileHeightCm: 173,
  profileAge: 50,
);

void main() {
  late RenphoIndependentAnalysis analysis;
  late RenphoFluidModel fluid;

  setUp(() {
    analysis = RenphoIndependentAnalysis(RenphoDerived(_scan()));
    fluid = analysis.fluidModel!;
  });

  group('Cole endpoints', () {
    test('R0 sits above the 20 kHz magnitude and R∞ below the 100 kHz one', () {
      expect(fluid.resistanceAtZeroHz, greaterThan(518.3));
      expect(fluid.resistanceAtInfinity, lessThan(464.0));
      expect(fluid.resistanceAtInfinity, greaterThan(0));
    });

    test('the solved endpoints reproduce both measured magnitudes', () {
      expect(fluid.magnitudeAt(20), closeTo(518.3, 0.01));
      expect(fluid.magnitudeAt(100), closeTo(464.05, 0.01));
      expect(fluid.resistanceRatio, inInclusiveRange(1.2, 2.0));
    });

    test('a deeper dispersion means a larger resistance ratio', () {
      final flat = RenphoFluidModel.solve(
        impedance20: 500,
        impedance100: 495,
        heightCm: 173,
        weightKg: 66.5,
        male: true,
      )!;
      final steep = RenphoFluidModel.solve(
        impedance20: 500,
        impedance100: 400,
        heightCm: 173,
        weightKg: 66.5,
        male: true,
      )!;
      expect(flat.resistanceRatio, lessThan(steep.resistanceRatio));
      expect(flat.intracellularWaterL, lessThan(steep.intracellularWaterL));
    });
  });

  group('fluid volumes', () {
    test('ECW and ICW are physiological and ICW is the larger compartment', () {
      expect(fluid.extracellularWaterL, inInclusiveRange(14.0, 21.0));
      expect(fluid.intracellularWaterL, inInclusiveRange(20.0, 30.0));
      expect(fluid.intracellularWaterL, greaterThan(fluid.extracellularWaterL));
    });

    test('TBW is the sum of both compartments', () {
      expect(
        fluid.totalBodyWaterL,
        closeTo(fluid.extracellularWaterL + fluid.intracellularWaterL, 1e-12),
      );
    });

    test('the extracellular ratio lands near the reference band', () {
      expect(fluid.extracellularRatio, inInclusiveRange(0.36, 0.45));
    });

    test('TBW agrees with Kushner-Schoeller within a litre', () {
      expect(
        (fluid.totalBodyWaterL - analysis.totalBodyWaterL).abs(),
        lessThan(1.0),
      );
    });
  });

  group('composition by the hydration route', () {
    test('FFM is TBW over the hydration constant', () {
      expect(
        fluid.fatFreeMassKg,
        closeTo(fluid.totalBodyWaterL / RenphoFluidModel.leanHydration, 1e-12),
      );
    });

    test('FFM and fat mass add up to body weight', () {
      expect(fluid.fatFreeMassKg + fluid.fatMassKg, closeTo(66.5, 1e-9));
    });

    test('FFM agrees with Sun 2003 within 3 kg', () {
      expect(
        (fluid.fatFreeMassKg - analysis.fatFreeMassKg).abs(),
        lessThan(3.0),
      );
    });

    test('body fat percent is plausible for this scan', () {
      expect(fluid.bodyFatPercent, inInclusiveRange(5.0, 25.0));
    });

    test('a heavier body at the same impedance reads more fat', () {
      final heavier = RenphoIndependentAnalysis(
        RenphoDerived(_scan(weightKg: 90)),
      ).fluidModel!;
      expect(heavier.fatMassKg, greaterThan(fluid.fatMassKg));
      expect(heavier.bodyFatPercent, greaterThan(fluid.bodyFatPercent));
    });

    test('the female constants give a different, still plausible split', () {
      final female = RenphoIndependentAnalysis(
        RenphoDerived(_scan(sex: 'female')),
      ).fluidModel!;
      expect(female.extracellularWaterL, inInclusiveRange(14.0, 21.0));
      expect(female.extracellularRatio, inInclusiveRange(0.36, 0.48));
      expect(female.fatFreeMassKg, isNot(closeTo(fluid.fatFreeMassKg, 1e-6)));
    });
  });

  group('refusals', () {
    test('no model without impedance', () {
      final blank = RenphoIndependentAnalysis(
        RenphoDerived(_scan(impedance: const {})),
      );
      expect(blank.fluidModel, isNull);
    });

    test('no model when the pair carries no dispersion', () {
      expect(
        RenphoFluidModel.solve(
          impedance20: 400,
          impedance100: 400,
          heightCm: 173,
          weightKg: 66.5,
          male: true,
        ),
        isNull,
      );
      expect(
        RenphoFluidModel.solve(
          impedance20: 400,
          impedance100: 420,
          heightCm: 173,
          weightKg: 66.5,
          male: true,
        ),
        isNull,
      );
    });

    test('no model without a profile', () {
      expect(
        RenphoFluidModel.solve(
          impedance20: 518.3,
          impedance100: 464.0,
          heightCm: 0,
          weightKg: 66.5,
          male: true,
        ),
        isNull,
      );
    });
  });
}
