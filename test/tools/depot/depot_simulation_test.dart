import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/depot/depot_simulation_state.dart';
import 'package:tool_lab/tools/depot/simulation/depot_sim_engine.dart';
import 'package:tool_lab/tools/depot/simulation/depot_sim_inputs.dart';

DepotSimParams _params({
  int age = 40,
  int retireAge = 60,
  int endAge = 90,
  int pensionAge = 67,
  double expenses = 24000,
  double pension = 0,
  double savings = 0,
  double startValue = 500000,
  double invested = 500000,
  double inflation = 0,
  double dividendYield = 0,
  double taxRate = 0,
  double manualReturn = 0.05,
  double manualVolatility = 0,
  List<double> yearReturns = const [],
  int runs = 400,
}) => DepotSimParams(
  age: age,
  retireAge: retireAge,
  endAge: endAge,
  pensionAge: pensionAge,
  expenses: expenses,
  pension: pension,
  savings: savings,
  startValue: startValue,
  invested: invested,
  inflation: inflation,
  dividendYield: dividendYield,
  taxRate: taxRate,
  partialExemption: 0,
  taxAllowance: 0,
  returnAdjustment: 0,
  targetSuccess: 0.9,
  yearReturns: yearReturns,
  manualReturn: manualReturn,
  manualVolatility: manualVolatility,
  runs: runs,
);

void main() {
  test('year windows compound twelve consecutive months', () {
    final windows = DepotSimParams.yearWindows(List.filled(13, 0.01));
    expect(windows, hasLength(2));
    expect(windows.first, closeTo(0.126825, 1e-6));
    expect(DepotSimParams.yearWindows(List.filled(11, 0.01)), isEmpty);
  });

  test('without volatility every run follows the expected path', () {
    final result = DepotSimEngine.run(_params(expenses: 0));
    expect(result.fixed.success, 1);
    final band = result.fixed.bands.last;
    expect(band.p10, closeTo(band.p90, 1e-6));
    expect(band.p50, closeTo(500000 * 1.05.pow(50), 1));
    expect(result.expected.last, closeTo(band.p50, 1));
  });

  test('spending far above the depot runs out right after retiring', () {
    final result = DepotSimEngine.run(
      _params(retireAge: 40, expenses: 200000, manualReturn: 0),
    );
    expect(result.fixed.success, 0);
    expect(result.fixed.earlyDepletionAge, 42);
    expect(result.earliestAge, 88);
  });

  test('a later retirement or a richer start only helps', () {
    final returns = [-0.3, -0.1, 0.05, 0.1, 0.2, 0.3];
    final poor = DepotSimEngine.run(
      _params(startValue: 300000, invested: 300000, yearReturns: returns),
    );
    final rich = DepotSimEngine.run(
      _params(startValue: 900000, invested: 900000, yearReturns: returns),
    );
    expect(rich.fixed.success, greaterThanOrEqualTo(poor.fixed.success));
    expect(rich.earliestAge, isNotNull);
    expect(rich.earliestAge!, lessThanOrEqualTo(poor.earliestAge ?? 1000));
  });

  test('guardrails cut spending and last at least as often', () {
    final result = DepotSimEngine.run(
      _params(
        retireAge: 45,
        expenses: 30000,
        yearReturns: [-0.35, -0.15, 0.02, 0.08, 0.15, 0.25],
      ),
    );
    expect(
      result.guardrails.success,
      greaterThanOrEqualTo(result.fixed.success),
    );
    expect(result.guardrails.worstSpending, lessThan(1));
    expect(result.fixed.worstSpending, 1);
  });

  test('a pension closes the gap', () {
    final without = DepotSimEngine.run(
      _params(retireAge: 50, pensionAge: 60, expenses: 40000, manualReturn: 0),
    );
    final withPension = DepotSimEngine.run(
      _params(
        retireAge: 50,
        pensionAge: 60,
        expenses: 40000,
        pension: 40000,
        manualReturn: 0,
      ),
    );
    expect(without.fixed.earlyDepletionAge, 62);
    expect(withPension.fixed.success, 1);
  });

  test('tax on gains needs larger sales', () {
    final untaxed = DepotSimEngine.run(
      _params(retireAge: 40, endAge: 55, invested: 100000, manualReturn: 0),
    );
    final taxed = DepotSimEngine.run(
      _params(
        retireAge: 40,
        endAge: 55,
        invested: 100000,
        taxRate: 0.25,
        manualReturn: 0,
      ),
    );
    expect(taxed.fixed.bands.last.p50, lessThan(untaxed.fixed.bands.last.p50));
  });

  test('dividends cover the gap once the depot is large enough', () {
    final result = DepotSimEngine.run(
      _params(
        startValue: 400000,
        dividendYield: 0.04,
        expenses: 24000,
        savings: 12000,
        manualReturn: 0.03,
      ),
    );
    expect(result.dividendsNow, closeTo(16000, 1e-6));
    expect(result.gapNow, 24000);
    expect(result.dividendAgeMedian, isNotNull);
    expect(result.dividendAgeMedian!, greaterThan(40));
    expect(result.dividendAgeLate, result.dividendAgeMedian);
  });

  test('inputs survive a JSON round trip', () {
    const inputs = DepotSimInputs(
      age: 35,
      savings: 800,
      source: DepotSimSource.manual,
      partialExemption: 0.3,
    );
    final back = DepotSimInputs.fromJson(inputs.toJson());
    expect(back.age, 35);
    expect(back.savings, 800);
    expect(back.startValue, isNull);
    expect(back.source, DepotSimSource.manual);
    expect(back.partialExemption, 0.3);
    expect(back.copyWith(savings: () => null).savings, isNull);
  });

  test('monthly returns skip gaps in the closes', () {
    expect(DepotSimulationState.monthlyReturnsOf([100, 110, 0, 99, 99]), [
      closeTo(0.1, 1e-9),
      0,
    ]);
  });
}

extension on double {
  double pow(int n) {
    var result = 1.0;
    for (var i = 0; i < n; i++) {
      result *= this;
    }
    return result;
  }
}
