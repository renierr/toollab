enum DepotSimSource {
  world('^990100-USD-STRD'),
  sp500('^GSPC'),
  depot(null),
  manual(null);

  /// Yahoo symbol of a price index with monthly history since 1985.
  final String? symbol;
  const DepotSimSource(this.symbol);

  static DepotSimSource fromName(Object? name) => values.firstWhere(
    (s) => s.name == name,
    orElse: () => DepotSimSource.world,
  );
}

enum DepotSimStrategy { fixed, guardrails }

/// What the user enters; null money fields fall back to the depot's figures.
class DepotSimInputs {
  final int age;
  final int retireAge;
  final int endAge;
  final int pensionAge;

  /// Monthly, in today's money.
  final double expenses;
  final double pension;
  final double? savings;
  final double? startValue;

  /// Fractions per year.
  final double inflation;
  final double? dividendYield;
  final double taxRate;
  final double? partialExemption;
  final double returnAdjustment;
  final double manualReturn;
  final double manualVolatility;
  final double targetSuccess;
  final DepotSimSource source;

  const DepotSimInputs({
    this.age = 40,
    this.retireAge = 55,
    this.endAge = 95,
    this.pensionAge = 67,
    this.expenses = 2500,
    this.pension = 1500,
    this.savings,
    this.startValue,
    this.inflation = 0.02,
    this.dividendYield,
    this.taxRate = 0.26375,
    this.partialExemption,
    this.returnAdjustment = 0,
    this.manualReturn = 0.06,
    this.manualVolatility = 0.16,
    this.targetSuccess = 0.9,
    this.source = DepotSimSource.world,
  });

  DepotSimInputs copyWith({
    int? age,
    int? retireAge,
    int? endAge,
    int? pensionAge,
    double? expenses,
    double? pension,
    double? Function()? savings,
    double? Function()? startValue,
    double? inflation,
    double? Function()? dividendYield,
    double? taxRate,
    double? Function()? partialExemption,
    double? returnAdjustment,
    double? manualReturn,
    double? manualVolatility,
    double? targetSuccess,
    DepotSimSource? source,
  }) => DepotSimInputs(
    age: age ?? this.age,
    retireAge: retireAge ?? this.retireAge,
    endAge: endAge ?? this.endAge,
    pensionAge: pensionAge ?? this.pensionAge,
    expenses: expenses ?? this.expenses,
    pension: pension ?? this.pension,
    savings: savings != null ? savings() : this.savings,
    startValue: startValue != null ? startValue() : this.startValue,
    inflation: inflation ?? this.inflation,
    dividendYield: dividendYield != null ? dividendYield() : this.dividendYield,
    taxRate: taxRate ?? this.taxRate,
    partialExemption: partialExemption != null
        ? partialExemption()
        : this.partialExemption,
    returnAdjustment: returnAdjustment ?? this.returnAdjustment,
    manualReturn: manualReturn ?? this.manualReturn,
    manualVolatility: manualVolatility ?? this.manualVolatility,
    targetSuccess: targetSuccess ?? this.targetSuccess,
    source: source ?? this.source,
  );

  Map<String, Object?> toJson() => {
    'age': age,
    'retireAge': retireAge,
    'endAge': endAge,
    'pensionAge': pensionAge,
    'expenses': expenses,
    'pension': pension,
    'savings': savings,
    'startValue': startValue,
    'inflation': inflation,
    'dividendYield': dividendYield,
    'taxRate': taxRate,
    'partialExemption': partialExemption,
    'returnAdjustment': returnAdjustment,
    'manualReturn': manualReturn,
    'manualVolatility': manualVolatility,
    'targetSuccess': targetSuccess,
    'source': source.name,
  };

  factory DepotSimInputs.fromJson(Map<String, dynamic> json) {
    const d = DepotSimInputs();
    int i(String key, int fallback) => (json[key] as num?)?.toInt() ?? fallback;
    double n(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    double? o(String key) => (json[key] as num?)?.toDouble();
    return DepotSimInputs(
      age: i('age', d.age),
      retireAge: i('retireAge', d.retireAge),
      endAge: i('endAge', d.endAge),
      pensionAge: i('pensionAge', d.pensionAge),
      expenses: n('expenses', d.expenses),
      pension: n('pension', d.pension),
      savings: o('savings'),
      startValue: o('startValue'),
      inflation: n('inflation', d.inflation),
      dividendYield: o('dividendYield'),
      taxRate: n('taxRate', d.taxRate),
      partialExemption: o('partialExemption'),
      returnAdjustment: n('returnAdjustment', d.returnAdjustment),
      manualReturn: n('manualReturn', d.manualReturn),
      manualVolatility: n('manualVolatility', d.manualVolatility),
      targetSuccess: n('targetSuccess', d.targetSuccess),
      source: DepotSimSource.fromName(json['source']),
    );
  }
}

/// Figures read from the synced depot that prefill the inputs.
class DepotSimDepotData {
  final double value;

  /// Net invested capital, the cost basis of [value].
  final double invested;
  final double monthlySavings;
  final double dividendYield;
  final double partialExemption;
  final double taxAllowance;

  /// Time-weighted monthly price returns, oldest first, fractions.
  final List<double> monthlyReturns;

  const DepotSimDepotData({
    required this.value,
    required this.invested,
    required this.monthlySavings,
    required this.dividendYield,
    required this.partialExemption,
    required this.taxAllowance,
    required this.monthlyReturns,
  });
}
