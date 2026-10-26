import '../models/depot_dividend.dart';
import '../models/depot_holding.dart';
import '../models/depot_transaction.dart';

enum DepotDividendStatus {
  /// Booked in Parqet.
  booked,

  /// Ex-date passed while shares were held, the payment date too, but
  /// nothing was booked.
  missing,

  /// Ex-date known from the data source, payment still ahead.
  upcoming,

  /// Extrapolated from the payment rhythm.
  projected,
}

class DepotDividendEntry {
  final DepotHolding? holding;
  final String name;
  final String colorSeed;

  /// Booking date, or the estimated payment date.
  final DateTime date;
  final DateTime? exDate;
  final double gross;
  final double net;

  /// Per share in [currency], the listing currency.
  final double? perShare;
  final String? currency;
  final double? shares;
  final DepotDividendStatus status;

  /// Amount carried over from the previous payment.
  final bool amountEstimated;

  const DepotDividendEntry({
    required this.holding,
    required this.name,
    required this.colorSeed,
    required this.date,
    required this.gross,
    required this.net,
    required this.status,
    this.exDate,
    this.perShare,
    this.currency,
    this.shares,
    this.amountEstimated = false,
  });

  bool get isBooked => status == DepotDividendStatus.booked;
}

class DepotDividendTotals {
  final double booked;
  final double missing;
  final double expected;

  const DepotDividendTotals({
    this.booked = 0,
    this.missing = 0,
    this.expected = 0,
  });

  double get total => booked + missing + expected;

  DepotDividendTotals operator +(DepotDividendEntry e) => DepotDividendTotals(
    booked: booked + (e.status == DepotDividendStatus.booked ? e.net : 0),
    missing: missing + (e.status == DepotDividendStatus.missing ? e.net : 0),
    expected:
        expected +
        (e.status == DepotDividendStatus.upcoming ||
                e.status == DepotDividendStatus.projected
            ? e.net
            : 0),
  );
}

class DepotDividendPosition {
  final DepotHolding holding;
  final DepotDividendFrequency? frequency;
  final DepotDividendEvent? lastEvent;
  final String? currency;
  final DepotDividendEntry? next;
  final double receivedNet12m;
  final double expectedGross12m;
  final double expectedNet12m;

  const DepotDividendPosition({
    required this.holding,
    required this.frequency,
    required this.lastEvent,
    required this.currency,
    required this.next,
    required this.receivedNet12m,
    required this.expectedGross12m,
    required this.expectedNet12m,
  });

  /// Expected gross payout of the next twelve months against today's value.
  double? get yieldPercent => holding.currentValue <= 0 || expectedGross12m <= 0
      ? null
      : expectedGross12m / holding.currentValue * 100;
}

/// Booked, missing, announced and projected dividends of a set of holdings.
class DepotDividendCalendar {
  final DateTime today;

  /// Oldest first.
  final List<DepotDividendEntry> entries;

  /// Largest expected payer first.
  final List<DepotDividendPosition> positions;
  final double openValue;

  const DepotDividendCalendar._({
    required this.today,
    required this.entries,
    required this.positions,
    required this.openValue,
  });

  static const _bookingWindowBefore = Duration(days: 5);
  static const _bookingWindowAfter = Duration(days: 75);
  static const _missingLookback = Duration(days: 180);
  static const _defaultPayOffset = 14;

  static const _shareIn = {
    DepotTransactionType.buy,
    DepotTransactionType.transferIn,
  };
  static const _shareOut = {
    DepotTransactionType.sell,
    DepotTransactionType.transferOut,
  };

  DateTime get _yearAgo => DateTime(today.year - 1, today.month, today.day);
  DateTime get _yearAhead => DateTime(today.year + 1, today.month, today.day);

  List<DepotDividendEntry> get missing => [
    for (final e in entries)
      if (e.status == DepotDividendStatus.missing) e,
  ];

  double get receivedNet12m => _sum(
    (e) => e.isBooked && !e.date.isBefore(_yearAgo) && !e.date.isAfter(today),
  );

  double get receivedNetThisYear =>
      _sum((e) => e.isBooked && e.date.year == today.year);

  double get expectedNet12m => _sum(_isExpected12m);

  double get missingNet => _sum((e) => e.status == DepotDividendStatus.missing);

  /// Expected gross payout of the next twelve months against the open value.
  double? get forwardYield {
    if (openValue <= 0) return null;
    var gross = 0.0;
    for (final e in entries) {
      if (_isExpected12m(e)) gross += e.gross;
    }
    return gross <= 0 ? null : gross / openValue * 100;
  }

  bool _isExpected12m(DepotDividendEntry e) =>
      (e.status == DepotDividendStatus.upcoming ||
          e.status == DepotDividendStatus.projected) &&
      !e.date.isBefore(today) &&
      e.date.isBefore(_yearAhead);

  double _sum(bool Function(DepotDividendEntry) test) {
    var sum = 0.0;
    for (final e in entries) {
      if (test(e)) sum += e.net;
    }
    return sum;
  }

  List<DepotDividendTotals> months(int year) {
    final result = List.filled(12, const DepotDividendTotals());
    for (final e in entries) {
      if (e.date.year == year) result[e.date.month - 1] += e;
    }
    return result;
  }

  /// Every year from the first booking to the end of the projection.
  Map<int, DepotDividendTotals> get years {
    if (entries.isEmpty) return const {};
    final result = <int, DepotDividendTotals>{
      for (var y = entries.first.date.year; y <= entries.last.date.year; y++)
        y: const DepotDividendTotals(),
    };
    for (final e in entries) {
      result[e.date.year] = result[e.date.year]! + e;
    }
    return result;
  }

  List<DepotDividendEntry> entriesIn(int year, int month) => [
    for (final e in entries)
      if (e.date.year == year && e.date.month == month) e,
  ];

  static String _holdingKey(String portfolioId, String holdingId) =>
      '$portfolioId/$holdingId';

  static DepotDividendCalendar build({
    required List<DepotHolding> holdings,
    required List<DepotTransaction> transactions,
    required Map<String, DepotDividendAsset> assets,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final yearAgo = DateTime(today.year - 1, today.month, today.day);
    final yearAhead = DateTime(today.year + 1, today.month, today.day);
    final byKey = {
      for (final h in holdings) _holdingKey(h.portfolioId, h.id): h,
    };
    final txByHolding = <String, List<DepotTransaction>>{};
    for (final t in transactions) {
      txByHolding
          .putIfAbsent(_holdingKey(t.portfolioId, t.holdingId), () => [])
          .add(t);
    }
    for (final list in txByHolding.values) {
      list.sort((a, b) => a.datetime.compareTo(b.datetime));
    }

    final entries = <DepotDividendEntry>[];
    var grossSum = 0.0;
    var netSum = 0.0;
    for (final t in transactions) {
      if (t.type != DepotTransactionType.dividend) continue;
      final holding = byKey[_holdingKey(t.portfolioId, t.holdingId)];
      grossSum += t.amount;
      netSum += t.amountNet;
      entries.add(
        DepotDividendEntry(
          holding: holding,
          name: holding?.name ?? t.holdingName,
          colorSeed: holding?.identifier ?? t.holdingId,
          date: t.datetime,
          gross: t.amount,
          net: t.amountNet,
          shares: t.shares == 0 ? null : t.shares,
          status: DepotDividendStatus.booked,
        ),
      );
    }
    final globalNetRatio = grossSum > 0
        ? (netSum / grossSum).clamp(0.0, 1.0)
        : 1.0;

    // Ex-date to booking offsets, matched per holding, so a projected payment
    // lands where this broker usually books it.
    final matches = <String, Map<DepotDividendEvent, DepotTransaction>>{};
    final allOffsets = <int>[];
    for (final h in holdings) {
      final asset = assets[h.identifier];
      if (asset == null) continue;
      final booked = [
        for (final t
            in txByHolding[_holdingKey(h.portfolioId, h.id)] ??
                const <DepotTransaction>[])
          if (t.type == DepotTransactionType.dividend) t,
      ];
      final used = <DepotTransaction>{};
      final matched = <DepotDividendEvent, DepotTransaction>{};
      for (final event in asset.events) {
        final from = event.exDate.subtract(_bookingWindowBefore);
        final to = event.exDate.add(_bookingWindowAfter);
        for (final t in booked) {
          if (used.contains(t) ||
              t.datetime.isBefore(from) ||
              t.datetime.isAfter(to)) {
            continue;
          }
          used.add(t);
          matched[event] = t;
          final offset = t.datetime.difference(event.exDate).inDays;
          if (offset >= 0) allOffsets.add(offset);
          break;
        }
      }
      matches[_holdingKey(h.portfolioId, h.id)] = matched;
    }
    final globalOffset = _median(allOffsets) ?? _defaultPayOffset;

    final positions = <DepotDividendPosition>[];
    var openValue = 0.0;
    for (final h in holdings) {
      if (!h.isSold) openValue += h.currentValue;
      final key = _holdingKey(h.portfolioId, h.id);
      final asset = assets[h.identifier];
      final txs = txByHolding[key] ?? const <DepotTransaction>[];
      final matched = matches[key] ?? const {};

      var hGross = 0.0;
      var hNet = 0.0;
      for (final t in txs) {
        if (t.type != DepotTransactionType.dividend) continue;
        hGross += t.amount;
        hNet += t.amountNet;
      }
      final netRatio = hGross > 0
          ? (hNet / hGross).clamp(0.0, 1.0)
          : globalNetRatio;
      final offsets = [
        for (final e in matched.entries)
          if (!e.value.datetime.isBefore(e.key.exDate))
            e.value.datetime.difference(e.key.exDate).inDays,
      ];
      final payOffset = Duration(days: _median(offsets) ?? globalOffset);

      final moves = [
        for (final t in txs)
          if (_shareIn.contains(t.type) || _shareOut.contains(t.type)) t,
      ];
      double sharesAt(DateTime date) {
        if (moves.isEmpty) return h.shares;
        var shares = 0.0;
        for (final t in moves) {
          if (!t.datetime.isBefore(date)) break;
          shares += _shareIn.contains(t.type)
              ? t.shares.abs()
              : -t.shares.abs();
        }
        return shares;
      }

      final own = <DepotDividendEntry>[];
      DepotDividendEntry expected({
        required DateTime exDate,
        required DateTime payDate,
        required double perShare,
        required double shares,
        required DepotDividendStatus status,
        bool amountEstimated = false,
      }) {
        final gross = perShare * shares * asset!.fxRate;
        return DepotDividendEntry(
          holding: h,
          name: h.name,
          colorSeed: h.identifier ?? h.id,
          date: payDate,
          exDate: exDate,
          gross: gross,
          net: gross * netRatio,
          perShare: perShare,
          currency: asset.currency,
          shares: shares,
          status: status,
          amountEstimated: amountEstimated,
        );
      }

      final events = asset?.events ?? const <DepotDividendEvent>[];
      final earliest = h.earliestActivity;
      for (final event in events) {
        if (matched.containsKey(event)) continue;
        if (event.exDate.isBefore(today.subtract(_missingLookback))) continue;
        if (earliest != null && event.exDate.isBefore(earliest)) continue;
        final shares = event.exDate.isAfter(today)
            ? h.shares
            : sharesAt(event.exDate);
        if (shares <= 0) continue;
        final payDate = event.exDate.add(payOffset);
        own.add(
          expected(
            exDate: event.exDate,
            payDate: payDate,
            perShare: event.amount,
            shares: shares,
            status: payDate.isBefore(today)
                ? DepotDividendStatus.missing
                : DepotDividendStatus.upcoming,
          ),
        );
      }

      final last = events.isEmpty ? null : events.last;
      final frequency = DepotDividendFrequency.of(events);
      final open = !h.isSold && h.shares > 0;
      var lastExDate = last?.exDate;
      double estimate(DateTime exDate) =>
          (frequency == DepotDividendFrequency.semiannual
              ? _perShareFor(events, exDate)
              : null) ??
          last!.amount;

      final announced = asset?.nextExDate;
      if (open &&
          last != null &&
          announced != null &&
          !announced.isBefore(today) &&
          !events.any(
            (e) => e.exDate.difference(announced).inDays.abs() <= 3,
          )) {
        own.add(
          expected(
            exDate: announced,
            payDate: asset?.nextPayDate ?? announced.add(payOffset),
            perShare: estimate(announced),
            shares: h.shares,
            status: DepotDividendStatus.upcoming,
            amountEstimated: true,
          ),
        );
        lastExDate = announced;
      }

      // No projection once the rhythm has clearly been broken.
      if (open &&
          last != null &&
          lastExDate != null &&
          frequency != null &&
          frequency != DepotDividendFrequency.irregular &&
          today.difference(last.exDate).inDays < frequency.days * 1.6 + 30) {
        for (var k = 1; ; k++) {
          final exDate = _addDays(lastExDate, frequency.days * k);
          final payDate = exDate.add(payOffset);
          if (!payDate.isBefore(yearAhead)) break;
          if (payDate.isBefore(today)) continue;
          own.add(
            expected(
              exDate: exDate,
              payDate: payDate,
              perShare: estimate(exDate),
              shares: h.shares,
              status: DepotDividendStatus.projected,
              amountEstimated: true,
            ),
          );
        }
      }
      entries.addAll(own);

      var expectedGross = 0.0;
      var expectedNet = 0.0;
      DepotDividendEntry? next;
      for (final e in own) {
        if (e.status == DepotDividendStatus.missing) continue;
        if (e.date.isBefore(today) || !e.date.isBefore(yearAhead)) continue;
        expectedGross += e.gross;
        expectedNet += e.net;
        if (next == null || e.date.isBefore(next.date)) next = e;
      }
      var received = 0.0;
      for (final t in txs) {
        if (t.type == DepotTransactionType.dividend &&
            !t.datetime.isBefore(yearAgo) &&
            !t.datetime.isAfter(now)) {
          received += t.amountNet;
        }
      }
      if (h.isSold && received == 0) continue;
      if (expectedGross == 0 && received == 0 && events.isEmpty) continue;
      positions.add(
        DepotDividendPosition(
          holding: h,
          frequency: frequency,
          lastEvent: last,
          currency: asset?.currency,
          next: next,
          receivedNet12m: received,
          expectedGross12m: expectedGross,
          expectedNet12m: expectedNet,
        ),
      );
    }

    entries.sort((a, b) => a.date.compareTo(b.date));
    positions.sort((a, b) {
      final byExpected = b.expectedNet12m.compareTo(a.expectedNet12m);
      return byExpected != 0
          ? byExpected
          : b.receivedNet12m.compareTo(a.receivedNet12m);
    });
    return DepotDividendCalendar._(
      today: today,
      entries: entries,
      positions: positions,
      openValue: openValue,
    );
  }

  /// The amount paid about a year before [exDate], so interim and final
  /// dividends keep their own size.
  static double? _perShareFor(
    List<DepotDividendEvent> events,
    DateTime exDate,
  ) {
    final target = DateTime(exDate.year - 1, exDate.month, exDate.day);
    DepotDividendEvent? best;
    var bestGap = 46;
    for (final e in events) {
      final gap = e.exDate.difference(target).inDays.abs();
      if (gap < bestGap) {
        best = e;
        bestGap = gap;
      }
    }
    return best?.amount;
  }

  static DateTime _addDays(DateTime date, double days) =>
      DateTime(date.year, date.month, date.day + days.round());

  static int? _median(List<int> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }
}
