import 'dart:math' as math;

import 'models/depot_holding.dart';
import 'models/depot_transaction.dart';

/// A running savings plan, inferred from equal buys in consecutive months.
class DepotSavingsPlan {
  final String portfolioId;
  final String holdingId;
  final String holdingName;
  final String currency;
  final double rate;

  /// Typical day of the month the plan runs on.
  final int day;
  final DateTime since;
  final int runs;

  /// Start of an earlier plan phase in the same holding, when there was one.
  final DateTime? firstPlanStart;

  /// The next run, or the overdue one when [overdue].
  final DateTime expected;
  final bool overdue;

  const DepotSavingsPlan({
    required this.portfolioId,
    required this.holdingId,
    required this.holdingName,
    required this.currency,
    required this.rate,
    required this.day,
    required this.since,
    required this.runs,
    required this.firstPlanStart,
    required this.expected,
    required this.overdue,
  });

  String get key => DepotHoldingPerformance.keyOf(portfolioId, holdingId);
}

class DepotSavingsPlans {
  /// Running plans, by day of the month.
  final List<DepotSavingsPlan> plans;

  /// All-time buys per currency, split into plan runs (ended plans included)
  /// and everything else.
  final Map<String, double> invested;
  final Map<String, double> oneOff;

  const DepotSavingsPlans._({
    required this.plans,
    required this.invested,
    required this.oneOff,
  });

  static const empty = DepotSavingsPlans._(plans: [], invested: {}, oneOff: {});

  static const int _minRuns = 3;
  static const int _minGrace = 5;
  static const int _maxGrace = 10;

  /// Plans whose days lie this close run as one batch.
  static const int _batchDays = 3;

  bool get isEmpty => plans.isEmpty;

  Map<String, double> get monthly => sum(plans);

  List<DepotSavingsPlan> get overdue => [
    for (final plan in plans)
      if (plan.overdue) plan,
  ];

  /// The plans due first, all within a few days of each other.
  List<DepotSavingsPlan> get next {
    final pending = [
      for (final plan in plans)
        if (!plan.overdue) plan,
    ]..sort((a, b) => a.expected.compareTo(b.expected));
    if (pending.isEmpty) return const [];
    final until = pending.first.expected.add(const Duration(days: _batchDays));
    return [
      for (final plan in pending)
        if (!plan.expected.isAfter(until)) plan,
    ];
  }

  List<List<DepotSavingsPlan>> get batches {
    final result = <List<DepotSavingsPlan>>[];
    for (final plan in plans) {
      if (result.isEmpty || plan.day - result.last.first.day > _batchDays) {
        result.add([plan]);
      } else {
        result.last.add(plan);
      }
    }
    return result;
  }

  DepotSavingsPlan? of(DepotHolding holding) {
    for (final plan in plans) {
      if (plan.key == holding.key) return plan;
    }
    return null;
  }

  /// Monthly rate per currency.
  static Map<String, double> sum(Iterable<DepotSavingsPlan> plans) {
    final result = <String, double>{};
    for (final plan in plans) {
      result.update(
        plan.currency,
        (v) => v + plan.rate,
        ifAbsent: () => plan.rate,
      );
    }
    return result;
  }

  factory DepotSavingsPlans.detect(
    Iterable<DepotTransaction> transactions,
    DateTime now,
  ) {
    final byHolding = <(String, String), List<DepotTransaction>>{};
    final totals = <String, double>{};
    for (final t in transactions) {
      if (t.type != DepotTransactionType.buy || t.amount <= 0) continue;
      byHolding.putIfAbsent((t.portfolioId, t.holdingId), () => []).add(t);
      totals.update(t.currency, (v) => v + t.amount, ifAbsent: () => t.amount);
    }

    final plans = <DepotSavingsPlan>[];
    final invested = <String, double>{};
    for (final buys in byHolding.values) {
      final phases = [
        for (final chain in _chains(buys))
          if (chain.runs.length >= _minRuns) chain,
      ];
      if (phases.isEmpty) continue;
      for (final phase in phases) {
        for (final run in phase.runs) {
          invested.update(
            run.currency,
            (v) => v + run.amount,
            ifAbsent: () => run.amount,
          );
        }
      }
      final firstStart = phases
          .map((p) => p.runs.first.datetime.toLocal())
          .reduce((a, b) => a.isBefore(b) ? a : b);
      for (final phase in phases) {
        if (_plan(phase, firstStart, now) case final plan?) plans.add(plan);
      }
    }
    plans.sort((a, b) {
      final byDay = a.day.compareTo(b.day);
      return byDay != 0 ? byDay : a.holdingName.compareTo(b.holdingName);
    });

    return DepotSavingsPlans._(
      plans: plans,
      invested: invested,
      oneOff: {
        for (final MapEntry(:key, :value) in totals.entries)
          key: value - (invested[key] ?? 0),
      },
    );
  }

  static int _monthOf(DateTime date) => date.year * 12 + date.month - 1;

  static DateTime _dateIn(int month, int day) {
    final year = month ~/ 12;
    final m = month % 12 + 1;
    final last = DateTime(year, m + 1, 0).day;
    return DateTime(year, m, math.min(day, last));
  }

  // Broker amounts drift by fractions of a cent around the plan rate.
  static bool _sameRate(double amount, double rate) =>
      (amount - rate).abs() <= math.max(0.05, rate * 0.01);

  /// Runs of one buy per consecutive month at the same amount; a month
  /// without a matching buy ends a run.
  static List<_Chain> _chains(List<DepotTransaction> buys) {
    final sorted = [...buys]..sort((a, b) => a.datetime.compareTo(b.datetime));
    final all = <_Chain>[];
    var open = <_Chain>[];
    var i = 0;
    while (i < sorted.length) {
      final month = _monthOf(sorted[i].datetime.toLocal());
      final inMonth = <DepotTransaction>[];
      while (i < sorted.length &&
          _monthOf(sorted[i].datetime.toLocal()) == month) {
        inMonth.add(sorted[i++]);
      }
      final next = <_Chain>[];
      for (final chain in open) {
        if (chain.lastMonth != month - 1) continue;
        final index = inMonth.indexWhere(
          (t) =>
              t.currency == chain.currency && _sameRate(t.amount, chain.rate),
        );
        if (index < 0) continue;
        chain.runs.add(inMonth.removeAt(index));
        chain.lastMonth = month;
        next.add(chain);
      }
      for (final t in inMonth) {
        final chain = _Chain(t, month);
        all.add(chain);
        next.add(chain);
      }
      open = next;
    }
    return all;
  }

  static DepotSavingsPlan? _plan(
    _Chain chain,
    DateTime firstStart,
    DateTime now,
  ) {
    final runs = chain.runs;
    final recent = runs.skip(math.max(0, runs.length - 12));
    final days = [for (final t in recent) t.datetime.toLocal().day]..sort();
    final day = days[days.length ~/ 2];
    final spread = days.map((d) => (d - day).abs()).reduce(math.max);
    final grace = Duration(days: (spread + 2).clamp(_minGrace, _maxGrace));
    final today = DateTime(now.year, now.month, now.day);

    var missed = 0;
    for (var m = chain.lastMonth + 1; m <= _monthOf(now); m++) {
      if (today.isAfter(_dateIn(m, day).add(grace))) missed++;
    }
    // Two missed months: the plan was stopped, not delayed.
    if (missed >= 2) return null;

    final amounts = [for (final t in recent) t.amount]..sort();
    final rate = (amounts[amounts.length ~/ 2] * 100).round() / 100;
    final since = runs.first.datetime.toLocal();
    final first = runs.first;
    return DepotSavingsPlan(
      portfolioId: first.portfolioId,
      holdingId: first.holdingId,
      holdingName: first.holdingName,
      currency: first.currency,
      rate: rate,
      day: day,
      since: since,
      runs: runs.length,
      firstPlanStart: _monthOf(firstStart) < _monthOf(since)
          ? firstStart
          : null,
      expected: _dateIn(chain.lastMonth + 1, day),
      overdue: missed == 1,
    );
  }
}

class _Chain {
  final double rate;
  final String currency;
  final List<DepotTransaction> runs;
  int lastMonth;

  _Chain(DepotTransaction first, this.lastMonth)
    : rate = first.amount,
      currency = first.currency,
      runs = [first];
}
