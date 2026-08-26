import 'dart:math' as math;

/// Body water from the two frequencies the scale actually measures, without
/// going through a 50 kHz regression.
///
/// The 50 kHz route ([RenphoIndependentAnalysis]) reconstructs one magnitude
/// and feeds it to equations fitted on a population. This route uses both
/// magnitudes as they are: the 20/100 kHz pair pins down a Cole dispersion,
/// the dispersion gives the resistance the current would see at DC and at
/// infinite frequency, and the Hanai mixture model turns those two resistances
/// into extracellular and intracellular volumes. Fat-free mass then follows
/// from the hydration constant of lean tissue rather than from a regression.
///
/// Two assumptions do the work, and both are named as constants below:
///
///  * **The Cole shape is assumed, not fitted.** Two magnitudes cannot resolve
///    four Cole parameters, so the characteristic frequency and the dispersion
///    exponent are fixed at population-typical values and only R₀ and R∞ are
///    solved for. [_characteristicFrequencyKHz] and [_dispersionExponent] are
///    the whole assumption; R₀ barely moves when they are varied across their
///    literature range, R∞ does, and so does intracellular water.
///  * **Magnitude stands in for resistance.** Same limitation as everywhere
///    else here: no reactance is reported, so |Z| runs above R by the phase
///    angle. It biases the extracellular ratio a few points high, which is why
///    that ratio is reported but not rated.
class RenphoFluidModel {
  /// Resistance at DC, where current cannot cross a cell membrane and only the
  /// extracellular space conducts.
  final double resistanceAtZeroHz;

  /// Resistance at infinite frequency, where the membranes are transparent and
  /// both compartments conduct in parallel.
  final double resistanceAtInfinity;

  final double extracellularWaterL;
  final double intracellularWaterL;
  final double weightKg;

  const RenphoFluidModel({
    required this.resistanceAtZeroHz,
    required this.resistanceAtInfinity,
    required this.extracellularWaterL,
    required this.intracellularWaterL,
    required this.weightKg,
  });

  /// Whole-body Cole parameters. Fixed, because two magnitudes cannot resolve
  /// them alongside R₀ and R∞.
  static const _characteristicFrequencyKHz = 50.0;
  static const _dispersionExponent = 0.65;

  /// Hanai mixture constants, De Lorenzo et al. 1997 — the apparent
  /// resistivity of the extracellular compartment and the intra/extracellular
  /// resistivity ratio, both sex-specific.
  static const _mixtureConstantMale = 0.306;
  static const _mixtureConstantFemale = 0.316;
  static const _resistivityRatioMale = 3.82;
  static const _resistivityRatioFemale = 3.40;

  /// Water content of fat-free mass. Close to a biological constant, which is
  /// what makes the hydration route to fat-free mass possible at all.
  static const leanHydration = 0.732;

  /// Null when the pair cannot carry the model: a missing frequency, or a
  /// 100 kHz magnitude at or above the 20 kHz one, which no dispersion allows.
  static RenphoFluidModel? solve({
    required double impedance20,
    required double impedance100,
    required double heightCm,
    required double weightKg,
    required bool male,
  }) {
    if (impedance20 <= 0 ||
        impedance100 <= 0 ||
        impedance100 >= impedance20 ||
        heightCm <= 0 ||
        weightKg <= 0) {
      return null;
    }
    final (r0, rInf) = _coleEndpoints(impedance20, impedance100);
    if (r0 <= 0 || rInf <= 0) return null;

    final ecw =
        (male ? _mixtureConstantMale : _mixtureConstantFemale) *
        math.pow(heightCm * heightCm * math.sqrt(weightKg) / r0, 2 / 3);
    final icw = ecw * _intracellularRatio(r0 / rInf, male);
    return RenphoFluidModel(
      resistanceAtZeroHz: r0,
      resistanceAtInfinity: rInf,
      extracellularWaterL: ecw,
      intracellularWaterL: icw,
      weightKg: weightKg,
    );
  }

  /// R₀ and R∞ from the two magnitudes.
  ///
  /// With the Cole shape fixed, `Z(f) = R∞ + (R₀ − R∞)·G(f)` is linear in the
  /// two unknowns for a known complex `G`. Eliminating R∞ between the two
  /// magnitude equations leaves one equation in `D = R₀ − R∞`, and `R∞ > 0`
  /// caps `D` at `sqrt(Q/P)`, where the residual is negative while it is
  /// positive at `D → 0`. That is a guaranteed bracket, so a bisection cannot
  /// wander off the physical root the way a Newton step can.
  static (double, double) _coleEndpoints(double z20, double z100) {
    final (a, b) = _dispersionAt(20);
    final (c, d) = _dispersionAt(100);
    final p = (a * a + b * b) - (c * c + d * d);
    final q = z20 * z20 - z100 * z100;
    if (p <= 0 || q <= 0 || a <= c) return (0, 0);

    double rInfAt(double gap) => (q - gap * gap * p) / (2 * gap * (a - c));
    double residual(double gap) {
      final rInf = rInfAt(gap);
      return rInf * rInf +
          2 * rInf * gap * a +
          gap * gap * (a * a + b * b) -
          z20 * z20;
    }

    var low = 1e-9;
    var high = math.sqrt(q / p);
    for (var i = 0; i < 120; i++) {
      final mid = (low + high) / 2;
      if (residual(mid) > 0) {
        low = mid;
      } else {
        high = mid;
      }
    }
    final gap = (low + high) / 2;
    final rInf = rInfAt(gap);
    return (rInf + gap, rInf);
  }

  /// Real and imaginary part of `1 / (1 + (jf/fc)^α)` at one frequency.
  static (double, double) _dispersionAt(double frequencyKHz) {
    final magnitude = math.pow(
      frequencyKHz / _characteristicFrequencyKHz,
      _dispersionExponent,
    );
    final angle = _dispersionExponent * math.pi / 2;
    final real = 1 + magnitude * math.cos(angle);
    final imaginary = magnitude * math.sin(angle);
    final denominator = real * real + imaginary * imaginary;
    return (real / denominator, -imaginary / denominator);
  }

  /// Hanai's relation between the resistance ratio and the volume ratio:
  /// `(1 + x)^2.5 = (R₀/R∞)·(1 + κx)`, with x the intra/extracellular volume
  /// ratio. Monotonic in x, so bisection resolves it.
  static double _intracellularRatio(double resistanceRatio, bool male) {
    final kappa = male ? _resistivityRatioMale : _resistivityRatioFemale;
    var low = 0.0;
    var high = 10.0;
    for (var i = 0; i < 80; i++) {
      final mid = (low + high) / 2;
      if (math.pow(1 + mid, 2.5) < resistanceRatio * (1 + kappa * mid)) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2;
  }

  /// The magnitude this fitted dispersion predicts at one frequency. Feeding
  /// 20 and 100 kHz back in returns the two measured values, which is what the
  /// solver was asked for; anything in between is interpolation along the same
  /// curve the 50 kHz reconstruction assumes.
  double magnitudeAt(double frequencyKHz) {
    final (gr, gi) = _dispersionAt(frequencyKHz);
    final gap = resistanceAtZeroHz - resistanceAtInfinity;
    final real = resistanceAtInfinity + gap * gr;
    final imaginary = gap * gi;
    return math.sqrt(real * real + imaginary * imaginary);
  }

  double get totalBodyWaterL => extracellularWaterL + intracellularWaterL;

  /// Share of body water sitting outside the cells. Rises with fluid overload
  /// and with age. Reported against the 0.36 – 0.40 reference, but read the
  /// trend rather than the level: the level carries both assumptions above.
  double get extracellularRatio =>
      totalBodyWaterL <= 0 ? 0 : extracellularWaterL / totalBodyWaterL;

  /// Fat-free mass by the hydration route — no population regression involved.
  double get fatFreeMassKg => totalBodyWaterL / leanHydration;

  double get fatMassKg => math.max(weightKg - fatFreeMassKg, 0);

  double get bodyFatPercent => weightKg <= 0 ? 0 : 100 * fatMassKg / weightKg;

  /// How deep the dispersion is. A flat pair carries little information about
  /// the intracellular compartment, and this is what says so.
  double get resistanceRatio =>
      resistanceAtInfinity <= 0 ? 0 : resistanceAtZeroHz / resistanceAtInfinity;
}
