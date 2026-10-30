import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/depot/depot_xray.dart';
import 'package:tool_lab/tools/depot/market_data/onvista_api.dart';
import 'package:tool_lab/tools/depot/models/depot_asset_profile.dart';
import 'package:tool_lab/tools/depot/models/depot_fund_constituent.dart';
import 'package:tool_lab/tools/depot/models/depot_holding.dart';

DepotHolding _holding(String name, double value, {String? isin}) =>
    DepotHolding.fromJson('p', {
      'id': name,
      'asset': {'type': 'security', 'name': name, 'isin': isin},
      'position': {'currentValue': value},
    });

void main() {
  test('merges direct stocks with fund top holdings by ISIN', () {
    final apple = _holding('Apple', 100, isin: 'US0378331005');
    final etf = _holding('World ETF', 1000, isin: 'IE00B4L5Y983');
    final profiles = {
      'World ETF': DepotAssetProfile(
        constituents: const [
          DepotFundConstituent(
            name: 'Apple',
            isin: 'US0378331005',
            weight: 0.05,
          ),
          DepotFundConstituent(
            name: 'Nvidia',
            isin: 'US67066G1040',
            weight: 0.06,
          ),
        ],
        fetchedAt: DateTime(2026, 10, 1),
      ),
    };

    final xray = depotXRay(
      holdings: [apple, etf],
      profileOf: (holding) => profiles[holding.id],
      kindOf: (holding) => holding.kind,
    );

    expect(xray.hasLookThrough, isTrue);
    expect(xray.total, 1100);
    expect(xray.entries.first.name, 'Apple');
    expect(xray.entries.first.value, closeTo(150, 0.001));
    expect(xray.entries.first.sources, hasLength(2));
    expect(xray.entries[1].value, closeTo(60, 0.001));
    expect(xray.uncovered, closeTo(890, 0.001));
  });

  test('parses onvista breakdowns and drops cash buckets', () {
    final parsed = OnvistaApi.parseFundBreakdown({
      'countryBreakdown': {
        'list': [
          {'nameBreakdown': 'USA', 'investmentPct': 70.5},
          {'nameBreakdown': 'Japan', 'investmentPct': 6},
          {'nameBreakdown': 'Barmittel', 'investmentPct': 0.2},
        ],
      },
      'branchBreakdown': {
        'list': [
          {'nameBreakdown': 'IT/Telekommunikation', 'investmentPct': 40},
          {'nameBreakdown': 'Finanzen', 'investmentPct': 15},
        ],
      },
      'fundsHoldingList': {
        'list': [
          {
            'instrument': {'name': 'Apple', 'isin': 'US0378331005'},
            'investmentPct': 5.4,
          },
          {
            'instrument': {'name': 'Nvidia', 'isin': 'US67066G1040'},
            'investmentPct': 5.8,
          },
        ],
      },
    });

    expect(parsed, isNotNull);
    expect(parsed!.countryShares.keys, ['USA', 'Japan']);
    expect(parsed.countryShares['USA'], closeTo(0.705, 0.0001));
    expect(parsed.sectorShares.keys, ['Technology', 'Financial Services']);
    expect(parsed.constituents.first.name, 'Nvidia');
    expect(parsed.constituents.first.isin, 'US67066G1040');
  });
}
