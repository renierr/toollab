import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/depot/depot_overlap.dart';
import 'package:tool_lab/tools/depot/models/depot_asset_profile.dart';
import 'package:tool_lab/tools/depot/models/depot_fund_constituent.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';

DepotHolding _holding(String name, double value, {String? isin}) =>
    DepotHolding.fromJson('p', {
      'id': name,
      'asset': {'type': 'security', 'name': name, 'isin': isin},
      'position': {'currentValue': value},
    });

DepotAssetProfile _fund(Map<String, double> weights) => DepotAssetProfile(
  constituents: [
    for (final entry in weights.entries)
      DepotFundConstituent(
        name: entry.key,
        isin: entry.key,
        weight: entry.value,
      ),
  ],
  fetchedAt: DateTime(2026, 10, 1),
);

void main() {
  test('scores each fund pair by the smaller shared weight', () {
    final world = _holding('World ETF', 3000);
    final sp500 = _holding('S&P 500 ETF', 2000);
    final em = _holding('EM ETF', 1000);
    final apple = _holding('Apple', 500, isin: 'AAPL');
    final profiles = {
      world.id: _fund({'AAPL': 0.05, 'MSFT': 0.04, 'NVDA': 0.045}),
      sp500.id: _fund({'AAPL': 0.07, 'MSFT': 0.065, 'AMZN': 0.04}),
      em.id: _fund({'TSMC': 0.09, 'TCEHY': 0.04}),
    };

    final overlap = depotOverlap(
      holdings: [em, apple, sp500, world],
      profileOf: (holding) => profiles[holding.id],
      kindOf: (holding) =>
          holding.id == 'Apple' ? DepotHoldingKind.stock : DepotHoldingKind.etf,
    );

    expect(overlap.funds.map((f) => f.id), [world.id, sp500.id, em.id]);
    expect(overlap.pairs, hasLength(3));
    final top = overlap.pairs.first;
    expect({top.a.id, top.b.id}, {world.id, sp500.id});
    expect(top.overlap, closeTo(0.09, 0.0001));
    expect(top.level, DepotOverlapLevel.moderate);
    expect(top.shared.first.key, 'AAPL');
    expect(top.shared.first.heldDirectly, isTrue);
    expect(top.coverageA, closeTo(0.135, 0.0001));
    expect(overlap.pairOf(em, world)!.overlap, 0);
    expect(overlap.pairOf(em, world)!.shared, isEmpty);
  });

  test('needs two funds with published holdings for a pair', () {
    final world = _holding('World ETF', 3000);
    final gold = _holding('Physical Gold ETC', 500);
    final overlap = depotOverlap(
      holdings: [world, gold],
      profileOf: (holding) => holding == world ? _fund({'AAPL': 0.05}) : null,
      kindOf: (holding) => holding.kind,
    );

    expect(overlap.funds, hasLength(1));
    expect(overlap.hasPairs, isFalse);
  });
}
