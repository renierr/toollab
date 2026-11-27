import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/depot/dividends/depot_dividend_calendar.dart';
import 'package:tool_lab/tools/depot/market_data/onvista_api.dart';
import 'package:tool_lab/tools/depot/models/depot_dividend.dart';
import 'package:tool_lab/tools/depot/models/depot_etc_profile.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';
import 'package:tool_lab/tools/depot/widgets/depot_holding_avatar.dart';

DepotHolding _holding(String name, {double shares = 0}) => DepotHolding(
  id: name,
  portfolioId: 'p',
  name: name,
  assetType: DepotAssetType.security,
  isin: 'US037833BH21',
  shares: shares,
  purchasePrice: 0,
  purchaseValue: 0,
  currentPrice: 75,
  currentValue: shares * 75,
  isSold: false,
  unrealizedGain: 0,
  unrealizedReturn: 0,
  realizedGain: 0,
  dividends: 0,
  fees: 0,
  taxes: 0,
);

// Shape of onvista's bond snapshot, trimmed to the fields read.
Map<String, dynamic> _snapshot() => {
  'bondsBaseData': {
    'nameCouponPeriod': '6 Monate',
    'datetimeNextCoupon': '2027-05-13T12:00:00.000+00:00',
    'datetimeMaturity': '2045-05-13T12:00:00.000+00:00',
    'perpetual': false,
    'callable': true,
  },
  'bondsDetails': {'isoCurrency': 'USD', 'coupon': 4.375},
  'bondsFigures': {
    'yieldToMaturity': 6.18,
    'currentYield': 5.4,
    'modifyDuration': 8.69,
  },
  'bondsIssuer': {'name': 'Apple Inc.', 'nameCountry': 'USA'},
  'quote': {
    'unitType': 'PCT',
    'last': 81.49,
    'previousLast': 82.02,
    'highPrice1Year': 91.2,
    'lowPrice1Year': 78.8,
    'datetimeLast': '2026-11-27T21:00:31.592+00:00',
    'market': {'name': 'Baader Trading'},
  },
  'bondsCouponList': {
    'list': [
      for (final (start, end) in [
        ('2026-05-14', '2026-11-13'),
        ('2026-11-14', '2027-05-13'),
        ('2027-05-14', '2027-11-13'),
      ])
        {
          'coupon': 4.375,
          'datetimeStartCoupon': '${start}T00:00:00.000+00:00',
          'datetimeEndCoupon': '${end}T00:00:00.000+00:00',
        },
    ],
  },
};

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

  test('a bond avatar skips the coupon in its initials', () {
    expect(DepotHoldingAvatar.initials('4,375% Apple Anleihe (2045)'), 'AA');
    expect(DepotHoldingAvatar.initials('EUWAX Gold II'), 'EG');
    expect(DepotHoldingAvatar.initials('3M'), '3');
  });

  test('onvista derivative snapshot describes an ETC', () {
    final etc = OnvistaApi.parseEtc({
      'derivativesDetails': {
        'nameProductIssuer': 'Boerse Stuttgart ETC',
        'nameTypeSettlement': 'Physisch',
        'openEnded': true,
      },
      'derivativesFigure': {'spreadAskPct': 1.01},
      'derivativesUnderlyingList': {
        'list': [
          {
            'instrument': {'name': '100 GRAMM GOLD'},
            'quote': null,
          },
          {
            'instrument': {'name': 'Goldpreis'},
            'quote': {'last': 3653.9},
          },
        ],
      },
    }, DateTime(2026, 11, 28))!;
    expect(etc.issuer, 'Boerse Stuttgart ETC');
    expect(etc.underlying, 'Goldpreis');
    expect(etc.settlement, DepotEtcSettlement.physical);
    expect(etc.openEnded, isTrue);
    expect(etc.spreadPercent, 1.01);
  });

  test('coupon and maturity come from the name', () {
    final apple = _holding('4,375% Apple Anleihe (2045)');
    expect(apple.couponRate, 4.375);
    expect(apple.maturityYear, 2045);
    expect(_holding('Apple Inc. DL-Notes 2015(15/45)').maturityYear, 2045);
    expect(_holding('Apple Inc.').couponRate, isNull);
  });

  test('onvista snapshot gives terms, yields and the coupon schedule', () {
    final bond = OnvistaApi.parseBond(_snapshot(), DateTime(2026, 11, 28))!;
    final profile = bond.profile;
    expect(profile.issuer, 'Apple Inc.');
    expect(profile.country, 'USA');
    expect(profile.currency, 'USD');
    expect(profile.coupon, 4.375);
    expect(profile.couponMonths, 6);
    expect(profile.nextCoupon, DateTime(2027, 5, 13));
    expect(profile.maturity, DateTime(2045, 5, 13));
    expect(profile.callable, isTrue);
    expect(profile.yieldToMaturity, 6.18);
    expect(profile.pricePercent, 81.49);
    expect(bond.coupons.map((c) => c.exDate), [
      DateTime(2026, 11, 13),
      DateTime(2027, 5, 13),
      DateTime(2027, 11, 13),
    ]);
    expect(bond.coupons.first.amount, closeTo(2.1875, 1e-9));

    final quote = OnvistaApi.parseBondQuote(_snapshot())!;
    expect(quote.price, 81.49);
    expect(quote.currency, 'USD');
    expect(quote.yearHigh, 91.2);
  });

  test('the calendar lists a bond coupon on its payment date', () {
    final bond = OnvistaApi.parseBond(_snapshot(), DateTime(2026, 11, 28))!;
    final h = _holding('4,375% Apple Anleihe (2045)', shares: 200);
    final calendar = DepotDividendCalendar.build(
      holdings: [h],
      transactions: const [],
      assets: {
        'US037833BH21': DepotDividendAsset(
          key: 'US037833BH21',
          symbol: 'US037833BH21',
          currency: 'USD',
          fxCurrency: 'EUR',
          fxRate: 0.9,
          fetchedAt: DateTime(2026, 11, 28),
          events: bond.coupons,
        ),
      },
      currency: 'EUR',
      now: DateTime(2026, 11, 28),
    );
    final position = calendar.positions.single;
    expect(position.next?.date, DateTime(2027, 5, 13));
    expect(position.next?.gross, closeTo(200 * 2.1875 * 0.9, 1e-9));
    expect(position.frequency, DepotDividendFrequency.semiannual);
    expect(position.lastEvent?.exDate, DateTime(2026, 11, 13));
    expect(calendar.expected12m.map((e) => e.status), [
      DepotDividendStatus.upcoming,
      DepotDividendStatus.upcoming,
    ]);
    expect(calendar.missing.single.date, DateTime(2026, 11, 13));
  });
}
