import 'dart:math' as math;
import 'dart:typed_data';

import 'depot_sim_inputs.dart';

/// Everything one simulation needs, resolved; yearly money in today's terms.
class DepotSimParams {
  final int age;
  final int retireAge;
  final int endAge;
  final int pensionAge;
  final double expenses;
  final double pension;
  final double savings;
  final double startValue;
  final double invested;
  final double inflation;
  final double dividendYield;
  final double taxRate;
  final double partialExemption;
  final double taxAllowance;
  final double returnAdjustment;
  final double targetSuccess;

  /// Yearly price returns to draw from; empty draws from [manualReturn] and
  /// [manualVolatility] instead.
  final List<double> yearReturns;
  final double manualReturn;
  final double manualVolatility;
  final int runs;
  final int seed;

  const DepotSimParams({
    required this.age,
    required this.retireAge,
    required this.endAge,
    required this.pensionAge,
    required this.expenses,
    required this.pension,
    required this.savings,
    required this.startValue,
    required this.invested,
    required this.inflation,
    required this.dividendYield,
    required this.taxRate,
    required this.partialExemption,
    required this.taxAllowance,
    required this.returnAdjustment,
    required this.targetSuccess,
    this.yearReturns = const [],
    this.manualReturn = 0.06,
    this.manualVolatility = 0.16,
    this.runs = 5000,
    this.seed = 42,
  });

  int get years => endAge - age;

  /// Monthly figures in, yearly out; [monthlyReturns] is what the source
  /// offers, ignored for [DepotSimSource.manual].
  factory DepotSimParams.of(
    DepotSimInputs inputs,
    DepotSimDepotData depot, {
    List<double> monthlyReturns = const [],
    int runs = 5000,
  }) {
    final age = inputs.age.clamp(0, 100);
    final endAge = math.max(inputs.endAge, age + 1);
    return DepotSimParams(
      age: age,
      retireAge: inputs.retireAge.clamp(age, endAge),
      endAge: endAge,
      pensionAge: inputs.pensionAge,
      expenses: inputs.expenses * 12,
      pension: inputs.pension * 12,
      savings: (inputs.savings ?? depot.monthlySavings) * 12,
      startValue: inputs.startValue ?? depot.value,
      invested: inputs.startValue == null ? depot.invested : inputs.startValue!,
      inflation: inputs.inflation,
      dividendYield: inputs.dividendYield ?? depot.dividendYield,
      taxRate: inputs.taxRate,
      partialExemption: inputs.partialExemption ?? depot.partialExemption,
      taxAllowance: depot.taxAllowance,
      returnAdjustment: inputs.returnAdjustment,
      targetSuccess: inputs.targetSuccess,
      yearReturns: inputs.source == DepotSimSource.manual
          ? const []
          : yearWindows(monthlyReturns),
      manualReturn: inputs.manualReturn,
      manualVolatility: inputs.manualVolatility,
      runs: runs,
    );
  }

  /// Every run of twelve consecutive months, compounded: overlapping blocks
  /// keep the momentum and crashes within a year intact.
  static List<double> yearWindows(List<double> monthly) {
    if (monthly.length < 12) return const [];
    final result = <double>[];
    for (var start = 0; start + 12 <= monthly.length; start++) {
      var growth = 1.0;
      for (var i = start; i < start + 12; i++) {
        growth *= 1 + monthly[i];
      }
      result.add(growth - 1);
    }
    return result;
  }

  /// Net of tax after the saver's allowance and the partial exemption.
  double netDividends(double value) {
    final gross = value * dividendYield;
    final taxable = gross * (1 - partialExemption) - taxAllowance;
    return gross - math.max(0, taxable) * taxRate;
  }
}

typedef DepotSimBand = ({
  double p10,
  double p25,
  double p50,
  double p75,
  double p90,
});

class DepotSimOutcome {
  final double success;

  /// One in ten runs is out of money by this age; null when fewer are.
  final int? earlyDepletionAge;

  /// Real value at each age from the start age to the end age.
  final List<DepotSimBand> bands;
  final double medianAtRetirement;
  final double medianEnd;

  /// Lowest spending as a share of the plan in the worst tenth of runs.
  final double worstSpending;

  const DepotSimOutcome({
    required this.success,
    required this.earlyDepletionAge,
    required this.bands,
    required this.medianAtRetirement,
    required this.medianEnd,
    required this.worstSpending,
  });
}

class DepotSimResult {
  final int age;
  final int retireAge;
  final int pensionAge;
  final DepotSimOutcome fixed;
  final DepotSimOutcome guardrails;

  /// Real value with the expected return every year.
  final List<double> expected;
  final double expectedReturn;

  /// Earliest retirement age that reaches the target success with fixed
  /// withdrawals; null when none up to the end age does.
  final int? earliestAge;

  /// Age from which net dividends alone pay the spending gap while still
  /// saving: in half of the runs, and in nine out of ten.
  final int? dividendAgeMedian;
  final int? dividendAgeLate;
  final double dividendsNow;
  final double gapNow;
  final int runs;

  const DepotSimResult({
    required this.age,
    required this.retireAge,
    required this.pensionAge,
    required this.fixed,
    required this.guardrails,
    required this.expected,
    required this.expectedReturn,
    required this.earliestAge,
    required this.dividendAgeMedian,
    required this.dividendAgeLate,
    required this.dividendsNow,
    required this.gapNow,
    required this.runs,
  });

  DepotSimOutcome outcome(DepotSimStrategy strategy) => switch (strategy) {
    DepotSimStrategy.fixed => fixed,
    DepotSimStrategy.guardrails => guardrails,
  };
}

typedef _Run = ({int? depleted, double minSpending, int? dividendAge});

class DepotSimEngine {
  DepotSimEngine._();

  static const _sweepRuns = 1000;

  static DepotSimResult run(DepotSimParams p) {
    final years = p.years;
    final returns = _draw(p, years);
    final fixed = _outcome(p, returns, DepotSimStrategy.fixed);
    final guardrails = _outcome(p, returns, DepotSimStrategy.guardrails);

    final expectedReturn = _expectedReturn(p);
    final flat = Float64List(years)..fillRange(0, years, expectedReturn);
    final expected = Float64List(years + 1);
    _simulate(
      p,
      flat,
      0,
      retireAge: p.retireAge,
      strategy: DepotSimStrategy.fixed,
      values: expected,
    );

    final dividendAges = <int?>[
      for (var run = 0; run < p.runs; run++)
        _simulate(
          p,
          returns,
          run,
          retireAge: p.endAge + 1,
          strategy: DepotSimStrategy.fixed,
        ).dividendAge,
    ];

    return DepotSimResult(
      age: p.age,
      retireAge: p.retireAge,
      pensionAge: p.pensionAge,
      fixed: fixed,
      guardrails: guardrails,
      expected: expected,
      expectedReturn: expectedReturn,
      earliestAge: _earliestAge(p, returns),
      dividendAgeMedian: _ageQuantile(dividendAges, 0.5),
      dividendAgeLate: _ageQuantile(dividendAges, 0.9),
      dividendsNow: p.netDividends(p.startValue),
      gapNow: math.max(0, p.expenses - (p.age >= p.pensionAge ? p.pension : 0)),
      runs: p.runs,
    );
  }

  static double _expectedReturn(DepotSimParams p) {
    if (p.yearReturns.isEmpty) {
      final (mu, _) = _logNormal(p);
      return math.exp(mu) - 1 + p.returnAdjustment;
    }
    var logSum = 0.0;
    for (final r in p.yearReturns) {
      logSum += math.log(1 + r);
    }
    return math.exp(logSum / p.yearReturns.length) - 1 + p.returnAdjustment;
  }

  static (double, double) _logNormal(DepotSimParams p) {
    final mean = 1 + p.manualReturn;
    final sigma2 = math.log(
      1 + p.manualVolatility * p.manualVolatility / (mean * mean),
    );
    return (math.log(mean) - sigma2 / 2, math.sqrt(sigma2));
  }

  static Float64List _draw(DepotSimParams p, int years) {
    final random = math.Random(p.seed);
    final out = Float64List(p.runs * years);
    final pool = p.yearReturns;
    final (mu, sigma) = _logNormal(p);
    for (var i = 0; i < out.length; i++) {
      final double r;
      if (pool.isNotEmpty) {
        r = pool[random.nextInt(pool.length)];
      } else {
        // Box-Muller.
        final u = 1 - random.nextDouble();
        final z =
            math.sqrt(-2 * math.log(u)) *
            math.cos(2 * math.pi * random.nextDouble());
        r = math.exp(mu + sigma * z) - 1;
      }
      out[i] = math.max(-0.99, r + p.returnAdjustment);
    }
    return out;
  }

  static DepotSimOutcome _outcome(
    DepotSimParams p,
    Float64List returns,
    DepotSimStrategy strategy,
  ) {
    final years = p.years;
    final values = Float64List(p.runs * (years + 1));
    final depleted = <int?>[];
    final spending = Float64List(p.runs);
    for (var run = 0; run < p.runs; run++) {
      final r = _simulate(
        p,
        returns,
        run,
        retireAge: p.retireAge,
        strategy: strategy,
        values: values,
        offset: run * (years + 1),
      );
      depleted.add(r.depleted);
      spending[run] = r.minSpending;
    }

    final bands = <DepotSimBand>[];
    final column = Float64List(p.runs);
    for (var t = 0; t <= years; t++) {
      for (var run = 0; run < p.runs; run++) {
        column[run] = values[run * (years + 1) + t];
      }
      column.sort();
      bands.add((
        p10: _quantile(column, 0.1),
        p25: _quantile(column, 0.25),
        p50: _quantile(column, 0.5),
        p75: _quantile(column, 0.75),
        p90: _quantile(column, 0.9),
      ));
    }
    spending.sort();
    return DepotSimOutcome(
      success: depleted.where((d) => d == null).length / p.runs,
      earlyDepletionAge: _ageQuantile(depleted, 0.1),
      bands: bands,
      medianAtRetirement: bands[p.retireAge - p.age].p50,
      medianEnd: bands.last.p50,
      worstSpending: _quantile(spending, 0.1),
    );
  }

  static int? _earliestAge(DepotSimParams p, Float64List returns) {
    final runs = math.min(p.runs, _sweepRuns);
    for (var retireAge = p.age; retireAge < p.endAge; retireAge++) {
      var ok = 0;
      for (var run = 0; run < runs; run++) {
        final r = _simulate(
          p,
          returns,
          run,
          retireAge: retireAge,
          strategy: DepotSimStrategy.fixed,
        );
        if (r.depleted == null) ok++;
      }
      if (ok / runs >= p.targetSuccess) return retireAge;
    }
    return null;
  }

  /// One life from [DepotSimParams.age] to the end age in yearly steps:
  /// price return, dividends taxed and reinvested while working, then the
  /// spending gap paid from dividends first and the rest by selling.
  static _Run _simulate(
    DepotSimParams p,
    Float64List returns,
    int run, {
    required int retireAge,
    required DepotSimStrategy strategy,
    Float64List? values,
    int offset = 0,
  }) {
    final years = p.years;
    var value = p.startValue;
    var basis = math.max(0.0, p.invested);
    var prices = 1.0;
    var factor = 1.0;
    double? startRate;
    var minSpending = 1.0;
    int? depleted;
    int? dividendAge;
    values?[offset] = value;

    for (var t = 0; t < years; t++) {
      final age = p.age + t;
      final gap = math.max(
        0.0,
        p.expenses - (age >= p.pensionAge ? p.pension : 0),
      );
      if (value > 0) {
        final dividends = value * p.dividendYield;
        value = math.max(0, value * (1 + returns[run * years + t]));
        final taxableDividends = dividends * (1 - p.partialExemption);
        final netDividends =
            dividends -
            math.max(0, taxableDividends - p.taxAllowance) * p.taxRate;
        final allowance = math.max(0.0, p.taxAllowance - taxableDividends);

        if (age < retireAge) {
          if (dividendAge == null && netDividends >= gap * prices) {
            dividendAge = age;
          }
          final added = p.savings * prices + netDividends;
          value += added;
          basis += added;
        } else {
          final need = gap * prices * factor;
          if (netDividends >= need) {
            value += netDividends - need;
            basis += netDividends - need;
          } else {
            final rest = need - netDividends;
            final gainShare = value > 0
                ? math.max(0.0, 1 - basis / value)
                : 0.0;
            final taxedShare = gainShare * (1 - p.partialExemption);
            final sale = rest * taxedShare <= allowance
                ? rest
                : (rest - p.taxRate * allowance) / (1 - p.taxRate * taxedShare);
            if (sale >= value) {
              value = 0;
              basis = 0;
              depleted = age;
            } else {
              basis -= sale * basis / value;
              value -= sale;
            }
          }
          if (strategy == DepotSimStrategy.guardrails &&
              need > 0 &&
              value > 0) {
            final rate = need / value;
            startRate ??= rate;
            if (rate > startRate * 1.2) {
              factor *= 0.9;
            } else if (rate < startRate * 0.8) {
              factor = math.min(1, factor * 1.1);
            }
            if (p.expenses > 0) {
              minSpending = math.min(
                minSpending,
                1 - gap * (1 - factor) / p.expenses,
              );
            }
          }
        }
      }
      prices *= 1 + p.inflation;
      values?[offset + t + 1] = value / prices;
    }
    return (
      depleted: depleted,
      minSpending: minSpending,
      dividendAge: dividendAge,
    );
  }

  static double _quantile(Float64List sorted, double q) {
    if (sorted.isEmpty) return 0;
    final position = q * (sorted.length - 1);
    final low = position.floor();
    final high = position.ceil();
    return sorted[low] + (sorted[high] - sorted[low]) * (position - low);
  }

  /// Ages where the event never happened count as never; null when the
  /// quantile falls among those.
  static int? _ageQuantile(List<int?> ages, double q) {
    if (ages.isEmpty) return null;
    final known = ages.whereType<int>().toList()..sort();
    final index = (q * ages.length).ceil() - 1;
    return index < known.length ? known[math.max(0, index)] : null;
  }
}
