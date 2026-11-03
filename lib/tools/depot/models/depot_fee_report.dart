import 'depot_transaction.dart';

typedef DepotFeeTrade = ({DepotTransaction trade, double volume, double rate});

typedef DepotBrokerFees = ({String? broker, double fees, double volume});

/// Fees of one calendar year in one booking currency.
class DepotFeeReport {
  final String currency;
  final double buyFees;
  final double sellFees;
  final double otherFees;
  final int buys;
  final int sells;
  final int others;
  final int freeTrades;
  final double tradeVolume;
  final List<DepotBrokerFees> brokers;
  final List<DepotFeeTrade> priciest;
  final double? previousTotal;

  const DepotFeeReport({
    required this.currency,
    required this.buyFees,
    required this.sellFees,
    required this.otherFees,
    required this.buys,
    required this.sells,
    required this.others,
    required this.freeTrades,
    required this.tradeVolume,
    required this.brokers,
    required this.priciest,
    required this.previousTotal,
  });

  static const int _priciestCount = 3;

  double get total => buyFees + sellFees + otherFees;
  double get tradeFees => buyFees + sellFees;
  int get trades => buys + sells;
  double? get averagePerTrade => trades == 0 ? null : tradeFees / trades;

  /// Trade fees in percent of the traded volume.
  double? get ratePercent =>
      tradeVolume <= 0 ? null : tradeFees / tradeVolume * 100;

  /// Reports with any fee in [year], by currency; empty when nothing was paid.
  static List<DepotFeeReport> forYear(
    Iterable<DepotTransaction> transactions,
    int year,
  ) {
    final current = <String, List<DepotTransaction>>{};
    final previous = <String, double>{};
    for (final transaction in transactions) {
      final currency = transaction.currency.trim().toUpperCase();
      if (currency.isEmpty) continue;
      final y = transaction.datetime.year;
      if (y == year) {
        current.putIfAbsent(currency, () => []).add(transaction);
      } else if (y == year - 1) {
        previous.update(
          currency,
          (total) => total + transaction.fee.abs(),
          ifAbsent: () => transaction.fee.abs(),
        );
      }
    }
    final reports = [
      for (final entry in current.entries)
        _build(entry.key, entry.value, previous[entry.key]),
    ]..removeWhere((report) => report.total <= 0);
    return reports..sort((a, b) => a.currency.compareTo(b.currency));
  }

  static DepotFeeReport _build(
    String currency,
    List<DepotTransaction> transactions,
    double? previousTotal,
  ) {
    var buyFees = 0.0, sellFees = 0.0, otherFees = 0.0, volume = 0.0;
    var buys = 0, sells = 0, others = 0, free = 0;
    final brokers = <String?, ({double fees, double volume})>{};
    final trades = <DepotFeeTrade>[];
    for (final transaction in transactions) {
      final fee = transaction.fee.abs();
      final isTrade =
          transaction.type == DepotTransactionType.buy ||
          transaction.type == DepotTransactionType.sell;
      if (!isTrade) {
        if (fee > 0) {
          otherFees += fee;
          others++;
        }
        continue;
      }
      if (transaction.type == DepotTransactionType.buy) {
        buyFees += fee;
        buys++;
      } else {
        sellFees += fee;
        sells++;
      }
      if (fee == 0) free++;
      final tradeVolume = _volume(transaction);
      volume += tradeVolume;
      final broker = transaction.broker?.trim();
      final key = broker == null || broker.isEmpty ? null : broker;
      final sum = brokers[key];
      brokers[key] = (
        fees: (sum?.fees ?? 0) + fee,
        volume: (sum?.volume ?? 0) + tradeVolume,
      );
      if (fee > 0 && tradeVolume > 0) {
        trades.add((
          trade: transaction,
          volume: tradeVolume,
          rate: fee / tradeVolume * 100,
        ));
      }
    }
    trades.sort((a, b) => b.rate.compareTo(a.rate));
    return DepotFeeReport(
      currency: currency,
      buyFees: buyFees,
      sellFees: sellFees,
      otherFees: otherFees,
      buys: buys,
      sells: sells,
      others: others,
      freeTrades: free,
      tradeVolume: volume,
      brokers: [
        for (final entry in brokers.entries)
          (
            broker: entry.key,
            fees: entry.value.fees,
            volume: entry.value.volume,
          ),
      ]..sort((a, b) => b.fees.compareTo(a.fees)),
      priciest: trades.take(_priciestCount).toList(),
      previousTotal: previousTotal,
    );
  }

  static double _volume(DepotTransaction transaction) {
    final volume = (transaction.shares * transaction.price).abs();
    return volume > 0 ? volume : transaction.amount.abs();
  }
}
