import 'package:flutter_test/flutter_test.dart';

import 'offline_test_support.dart';
import 'package:tool_lab/tools/depot/models/depot_activity.dart';
import 'package:tool_lab/tools/depot/parqet/parqet_activity_upload.dart';
import 'package:tool_lab/tools/depot/parqet_csv.dart';
import 'package:tool_lab/tools/depot/parsing/statement_parser.dart';

// Synthetic Trade Republic statements in their layout, with invented figures.

/// 5.000 EUR nominal at 99,20 % = 4.960,00 EUR, plus 41,10 accrued interest
/// and 1,00 fee = 5.002,10 EUR debited.
const _bondBuy = '''
TRADE REPUBLIC BANK GMBH  BRUNNENSTRASSE 19-21  10119 BERLIN
Max Muster SEITE 1 von 1
Musterweg 1 DATUM 02.03.2026
12345 Musterstadt AUFTRAG 1a2b-3c4d
AUSFÜHRUNG 5e6f-7a8b
DEPOT 1234567890
WERTPAPIERABRECHNUNG
ÜBERSICHT
Market-Order Kauf am 02.03.2026, um 10:15 Uhr (Europe/Berlin).
Der Kontrahent der Transaktion ist Lang & Schwarz TradeCenter AG & Co. KG.
POSITION NOMINALE PREIS BETRAG
Musterbank AG 5.000 EUR 99,20 % 4.960,00 EUR
MTN v.2024(2030)
ISIN: DE0001141802
GESAMT 4.960,00 EUR
ABRECHNUNG
POSITION BETRAG
Fremdkostenzuschlag -1,00 EUR
Stückzinsen -41,10 EUR
Kapitalertragsteuer 0,00 EUR
Solidaritätszuschlag 0,00 EUR
GESAMT -5.002,10 EUR
BUCHUNG
VERRECHNUNGSKONTO WERTSTELLUNG BETRAG
DE00100000000000000000 2026-03-04 -5.002,10 EUR
Musterbank AG MTN v.2024(2030) in Girosammelverwahrung in Deutschland
Trade Republic Bank GmbH www.traderepublic.com Sitz der Gesellschaft: Berlin
''';

/// 5000.00 EUR nominal at 5.000 % = 250.00 EUR, less 62.50 + 3.43 tax.
const _coupon = '''
TRADE REPUBLIC BANK GMBH  BRUNNENSTRASSE 19-21  10119 BERLIN
Max Muster SEITE 1 von 1
Musterweg 1 DATUM 16.09.2026
12345 Musterstadt DEPOT 1234567890
ZINSZAHLUNG
ÜBERSICHT
Zinszahlung mit Ex-Datum 14.09.2026.
POSITION NOMINALE COUPON BETRAG
Musterbank AG 2030 250.00 EUR
5000.00 EUR 5.000 %
DE0001141802
GESAMT 250.00 EUR
ABRECHNUNG
POSITION BETRAG
Zwischensumme 250.00 EUR
Kapitalertragssteuer -62.50 EUR
Solidaritätszuschlag -3.43 EUR
GESAMT 184.07 EUR
BUCHUNG
VERRECHNUNGSKONTO DATUM DER ZAHLUNG BETRAG
DE00100000000000000000 15.09.2026 184.07 EUR
Trade Republic Bank GmbH www.traderepublic.com Sitz der Gesellschaft: Berlin
''';

/// Austrian branch layout: thousands grouped by a space, ISO booking date.
const _savingsPlan = '''
TRADE REPUBLIC BANK GMBH, BRANCH AUSTRIA  KÄRNTNER RING 5-7  1010 WIEN, ÖSTERREICH
Max Muster SEITE 1 von 1
Musterweg 1 DATUM 02.10.2026
1010 Wien AUSFÜHRUNG 9a9a-1b1b
DEPOT 1234567890
WERTPAPIERABRECHNUNG SPARPLAN
ÜBERSICHT
Sparplanausführung am 02.10.2026 an der Lang und Schwarz Exchange.
POSITION ANZAHL DURCHSCHNITTSKURS BETRAG
Muster World USD (Acc) 20 Stk. 62,50 EUR 1 250,00 EUR
ISIN: US0378331005
GESAMT 1 250,00 EUR
ABRECHNUNG
POSITION BETRAG
Abwicklungspauschale -1,00 EUR
GESAMT -1 251,00 EUR
BUCHUNG
VERRECHNUNGSKONTO WERTSTELLUNG BETRAG
AT000000000000000000 2026-10-13 -1 251,00 EUR
''';

/// 25.00 USD gross at 1.2500 = 20.00 EUR: 3.00 EUR US withholding, 1.32
/// German tax, 15.68 EUR paid out. Page 2 repeats the taxes.
const _usdDividend = '''
TRADE REPUBLIC BANK GMBH  BRUNNENSTRASSE 19-21  10119 BERLIN
Max Muster SEITE 1 von 2
Musterweg 1 DATUM 15.08.2026
12345 Musterstadt DEPOT 1234567890
DIVIDENDE
ÜBERSICHT
Dividende mit Ex-Datum 10.08.2026.
POSITION ANZAHL ERTRAG BETRAG
Muster Inc. 25.00 USD
100.000000 Stücke 0.25 USD
US0378331005
GESAMT 25.00 USD
ABRECHNUNG
POSITION BETRAG
Quellensteuer für US-Emittenten -3.75 USD
Zwischensumme 21.25 USD
Zwischensumme 1.2500 USD/EUR 17.00 EUR
Kapitalertragsteuer 1.2500 USD/EUR -1.25 EUR
Solidaritätszuschlag 1.2500 USD/EUR -0.07 EUR
GESAMT 15.68 EUR
BUCHUNG
VERRECHNUNGSKONTO DATUM DER ZAHLUNG BETRAG
DE00100000000000000000 14.08.2026 15.68 EUR
TRADE REPUBLIC BANK GMBH  BRUNNENSTRASSE 19-21  10119 BERLIN
Max Muster SEITE 2 von 2
STEUERLICHE BEHANDLUNG
BERECHNUNG DER STEUERN BETRAG
Kapitalertragsteuer -1,25 EUR
Solidaritätszuschlag -0,07 EUR
''';

/// A USD bond in the current layout: name, ISIN and figures on separate
/// lines, no printed rate. 2.000 USD at 80,00 % = 1.600 USD = 1.454,55 EUR,
/// so the rate is 1,1000 USD per EUR.
const _usdBondBuy = '''
TRADE REPUBLIC BANK GMBH BRUNNENSTRASSE 19-21 10119 BERLIN
DATUM 01.10.2026
Trade Republic Bank GmbH
www.traderepublic.com Sitz der Gesellschaft: Berlin
SEITE 1 von 2
WERTPAPIERABRECHNUNG
ÜBERSICHT
Market-Order BUY am 01.10.2026 um 11:54 (Europe/Berlin).
POSITION NOMINALE PREIS BETRAG
Mai 2045
ISIN: US037833BH21
2.000 USD 80,00 % 1.454,55 EUR
GESAMT 1.454,55 EUR
ABRECHNUNG
POSITION BETRAG
Abwicklungspauschale -1,00 EUR
Stückzinsen -9,09 EUR
Kapitalertragsteuer 0,00 EUR
Solidaritätszuschlag 0,00 EUR
GESAMT -1.464,64 EUR
BUCHUNG
VERRECHNUNGSKONTO WERTSTELLUNG BETRAG
DE00100000000000000000 2026-10-05 -1.464,64 EUR
''';

/// 2000.00 USD at 2.5000 % = 50.00 USD = 40.00 EUR at 1.2500.
const _usdCoupon = '''
TRADE REPUBLIC BANK GMBH BRUNNENSTRASSE 19-21 10119 BERLIN
DATUM 13.11.2026
Trade Republic Bank GmbH
www.traderepublic.com Sitz der Gesellschaft: Berlin
ZINSZAHLUNG
ÜBERSICHT
Zinszahlung mit Ex-Datum 13.11.2026.
POSITION NOMINALE COUPON BETRAG
Mai 2045
US037833BH21 2000.00 USD 2.5000 % 50.00 USD
GESAMT 50.00 USD
ABRECHNUNG
POSITION BETRAG
Zwischensumme 50.00 USD
Zwischensumme 1.2500 USD/EUR 40.00 EUR
Kapitalertragsteuer 1.2500 USD/EUR -10.00 EUR
Solidaritätszuschlag 1.2500 USD/EUR -0.55 EUR
GESAMT 29.45 EUR
BUCHUNG
VERRECHNUNGSKONTO DATUM DER ZAHLUNG BETRAG
DE00100000000000000000 13.11.2026 29.45 EUR
''';

const _taxCorrection = '''
TRADE REPUBLIC BANK GMBH  BRUNNENSTRASSE 19-21  10119 BERLIN
DEPOT 1234567890
WERTPAPIERABRECHNUNG
Korrektur des Belegs 1a2b-3c4d vom 17.01.2026
ÜBERSICHT
Limit-Order Verkauf am 17.01.2026, um 16:05 Uhr (Europe/Berlin).
POSITION ANZAHL PREIS
Muster Index EUR (Acc) 200 Stk. 26 EUR
ISIN: US0378331005
STEUERKORREKTUREN
POSITION BETRAG
Kapitalertragsteuer 156,80 EUR
GESAMT 156,80 EUR
''';

DepotActivity _parse(String text) {
  final parsed = DepotStatementParser.parse(
    id: 'x',
    fileName: 'tr.pdf',
    rawText: text,
  );
  expect(parsed.bank, DepotBank.tradeRepublic);
  return parsed.activity!;
}

void main() {
  blockDepotNetwork();

  group('Trade Republic bond buy', () {
    test('books nominal / 100 as shares and the price per 100 nominal', () {
      final a = _parse(_bondBuy);

      expect(a.type, DepotActivityType.buy);
      expect(a.date, DateTime(2026, 3, 2));
      expect(a.isin, 'DE0001141802');
      expect(a.securityName, 'Musterbank AG MTN v.2024(2030)');
      expect(a.shares, closeTo(50, 1e-9));
      expect(a.fee, closeTo(1.00, 0.005));
      expect(a.tax, 0);
    });

    test('adds the accrued interest paid to the amount', () {
      final a = _parse(_bondBuy);

      expect(a.amount, closeTo(5001.10, 0.005));
      expect(a.price, closeTo(100.022, 0.0005));
      expect(a.bookedTotal, closeTo(5002.10, 0.005));
      expect(DepotStatementParser.revalidate(a), isEmpty);
    });
  });

  group('Trade Republic coupon', () {
    test('is a dividend whose price is the coupon rate', () {
      final a = _parse(_coupon);

      expect(a.type, DepotActivityType.dividend);
      expect(a.date, DateTime(2026, 9, 15));
      expect(a.securityName, 'Musterbank AG 2030');
      expect(a.shares, closeTo(50, 1e-9));
      expect(a.price, closeTo(5.0, 1e-9));
      expect(a.amount, closeTo(250.00, 0.005));
      expect(a.tax, closeTo(65.93, 0.005));
      expect(DepotStatementParser.revalidate(a), isEmpty);
    });
  });

  group('Trade Republic savings plan', () {
    test('reads space-grouped thousands and the execution day', () {
      final a = _parse(_savingsPlan);

      expect(a.type, DepotActivityType.buy);
      expect(a.date, DateTime(2026, 10, 2));
      expect(a.shares, 20);
      expect(a.price, closeTo(62.50, 1e-9));
      expect(a.amount, closeTo(1250.00, 0.005));
      expect(a.bookedTotal, closeTo(1251.00, 0.005));
      expect(DepotStatementParser.revalidate(a), isEmpty);
    });
  });

  group('Trade Republic foreign dividend', () {
    test('converts the withholding and ignores the page-2 tax repeat', () {
      final a = _parse(_usdDividend);

      expect(a.date, DateTime(2026, 8, 14));
      expect(a.securityName, 'Muster Inc.');
      expect(a.shares, 100);
      expect(a.amount, closeTo(20.00, 0.005));
      expect(a.tax, closeTo(4.32, 0.005));
      expect(a.price, closeTo(0.20, 0.0001));
      expect(a.sourceCurrency, 'USD');
      expect(a.fxRate, closeTo(1.25, 1e-9));
      expect(DepotStatementParser.revalidate(a), isEmpty);
    });
  });

  group('Trade Republic USD bond', () {
    ParsedStatement parse(String text) =>
        DepotStatementParser.parse(id: 'x', fileName: 'tr.pdf', rawText: text);

    test('implies the rate of a buy from nominal, price and EUR amount', () {
      final a = _parse(_usdBondBuy);

      expect(a.isBond, isTrue);
      expect(a.shares, closeTo(20, 1e-9));
      expect(a.amount, closeTo(1463.64, 0.005));
      expect(a.sourceCurrency, 'USD');
      expect(a.fxRate, closeTo(1.1, 1e-5));
      expect(DepotStatementParser.revalidate(a), isEmpty);
    });

    test('sends the buy to Parqet in USD per 100 nominal', () {
      final body = ParqetActivityUpload.body(parse(_usdBondBuy));

      expect(body['currency'], 'USD');
      expect(body['broker'], 'trade_republic');
      expect(body['shares'], closeTo(20, 1e-9));
      expect(body['price'] as double, closeTo(80.50, 0.001));
      expect(body['fee'] as double, closeTo(1.10, 0.0001));
    });

    test('sends the coupon in USD at its rate in percent', () {
      final statement = parse(_usdCoupon);
      final body = ParqetActivityUpload.body(statement);

      expect(statement.activity!.type, DepotActivityType.dividend);
      expect(statement.issues, isEmpty);
      expect(body['currency'], 'USD');
      expect(body['shares'], closeTo(20, 1e-9));
      expect(body['price'] as double, closeTo(2.5, 1e-9));
      expect(body['tax'] as double, closeTo(13.1875, 1e-9));
    });

    test('writes the bond in USD and other rows in EUR to the CSV', () {
      final csv = ParqetCsv.build([
        _parse(_usdBondBuy),
        _parse(_savingsPlan),
      ]).trim().split('\n');

      expect(csv[1], endsWith(';US037833BH21;USD'));
      final row = csv[1].split(';');
      expect(double.parse(row[1]), closeTo(80.50, 0.001));
      expect(row[2], '20');
      expect(double.parse(row[3]), closeTo(1610, 0.01));
      expect(csv[2], endsWith(';EUR'));
    });
  });

  test('flags a tax correction instead of reading it as a trade', () {
    final parsed = DepotStatementParser.parse(
      id: 'x',
      fileName: 'tr.pdf',
      rawText: _taxCorrection,
    );

    expect(parsed.issues, contains(DepotParseIssue.unknownType));
  });
}
