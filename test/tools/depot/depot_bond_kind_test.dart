import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';

DepotHolding _holding(String name) => DepotHolding(
  id: name,
  portfolioId: 'p',
  name: name,
  assetType: DepotAssetType.security,
  shares: 0,
  purchasePrice: 0,
  purchaseValue: 0,
  currentPrice: 0,
  currentValue: 0,
  isSold: false,
  unrealizedGain: 0,
  unrealizedReturn: 0,
  realizedGain: 0,
  dividends: 0,
  fees: 0,
  taxes: 0,
);

void main() {
  test('bond names are told apart from stocks and bond ETFs', () {
    for (final name in [
      '4,375% Apple Anleihe (2045)',
      'Apple Inc. DL-Notes 2015(15/45)',
      'Bundesrep.Deutschland Anl.v.2014(2046)',
    ]) {
      expect(_holding(name).kind, DepotHoldingKind.bond, reason: name);
    }
    expect(
      _holding('iShares Core Euro Corporate Bond UCITS ETF').kind,
      DepotHoldingKind.etf,
    );
    expect(_holding('Apple Inc.').kind, DepotHoldingKind.stock);
  });

  test('coupon and maturity come from the name', () {
    final apple = _holding('4,375% Apple Anleihe (2045)');
    expect(apple.couponRate, 4.375);
    expect(apple.maturityYear, 2045);
    expect(_holding('Apple Inc. DL-Notes 2015(15/45)').maturityYear, 2045);
    expect(_holding('Apple Inc.').couponRate, isNull);
  });
}
