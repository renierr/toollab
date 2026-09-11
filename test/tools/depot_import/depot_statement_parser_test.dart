import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/depot_import/models/depot_activity.dart';
import 'package:tool_lab/tools/depot_import/parsing/statement_parser.dart';

/// A synthetic DKB "Dividendengutschrift" in the layout their PDFs use, with
/// invented figures. It carries the two traps that broke the tax column: a
/// "Berechnungsgrundlage" base line that is not itself a tax, and the page-2
/// "Nachrichtlich" pot overview whose year-to-date balances sit under a bare
/// "Quellensteuer" heading.
///
/// 10,00 USD gross at 1,2500 = 8,00 EUR, less 1,20 withholding, 0,80
/// Kapitalertragsteuer and 0,04 Solidaritätszuschlag = 5,96 EUR paid out.
const _dividend = '''
Deutsche Kreditbank AG
10919 Berlin                                              Seite 1
                                        Depotnummer       100000001
                                        Abrechnungsnr.    111111111
                                        Datum             02.09.2026

Dividendengutschrift

Nominale          Wertpapierbezeichnung        ISIN            (WKN)
Stück 10          MUSTER CORP.                 US1234567890    (A1B2C3)
                  REG. SHARES CLASS A DL -,0001

Zahlbarkeitstag   01.09.2026        Dividende pro Stück       1,00     USD
Bestandsstichtag  10.08.2026        Herkunftsland                      USA
Ex-Tag            11.08.2026        Art der Dividende   Quartalsdividende
Devisenkurs       EUR / USD 1,2500
Devisenkursdatum  02.09.2026

Dividendengutschrift                          10,00   USD         8,00+ EUR
Umrechnung in EUR                              8,00   EUR
Einbehaltene Quellensteuer 15 % auf 10,00 USD                     1,20-  EUR
Anrechenbare Quellensteuer 15 % auf 8,00 EUR   1,20   EUR
Kapitalertragsteuerpflichtige Dividende        8,00   EUR

Verrechnete anrechenbare ausländische Quellensteuer
(Verhältnis 100/25) auf 1,20 EUR               4,80 - EUR
Berechnungsgrundlage für die Kapitalertragsteuer 3,20 EUR
Kapitalertragsteuer 25 % auf 3,20 EUR                             0,80-  EUR
Solidaritätszuschlag 5,5 % auf 0,80 EUR                           0,04-  EUR

Ausmachender Betrag                                               5,96+ EUR

Lagerstelle CLEARSTREAM BANKING EUROPE (849000 / 40030000)
Keine Steuerbescheinigung.
                                                          Seite 2

Nachrichtlich die Übersicht Ihrer Verrechnungs- und Steuertopfsalden zum
Zeitpunkt der Erstellung der Abrechnung.

                       Verrechnungstöpfe 2026            Berechnungsgrundlage
                                                         der gezahlten Steuern
 Euro       Aktien   Sonstige    Sparer-   anrechenbare   Aktien und Sonstige
                             Pauschbetrag  Quellensteuer
 Vorher     500,00       0,00       0,00           0,00              1.000,00
 Ertrag                                            1,20
              0,00       0,00       0,00           1,20-                 3,20
 Nachher    500,00       0,00       0,00           0,00              1.003,20
''';

/// A synthetic ING "Ertragsgutschrift" in their layout, with invented figures.
/// It differs from DKB everywhere that matters: the quantity precedes its unit
/// ("Nominale 100,00 Stück"), the ISIN sits on a line of its own with the name
/// labelled below it, the Ex-Tag is printed above the Zahltag, and the rate per
/// share is repeated after partial exemption.
///
/// 50,00 USD gross at 1,250000 = 40,00 EUR, less 7,00 Kapitalertragsteuer and
/// 0,38 Solidaritätszuschlag = 32,62 EUR paid out.
const _ingForeignDividend = '''
ING-DiBa AG · 60628 Frankfurt am Main

                                    Direkt-Depot Nr.:    9000000001
                                    Datum:               04.09.2026
                                    Seite:               1 von 2

Ertragsgutschrift

ISIN (WKN)                          IE00B1234567 (A1B2C3)
Wertpapierbezeichnung               Muster ETF Global Equity
                                    Reg. Shs 1D USD Dis. oN

Nominale                               100,00 Stück
Ertragsausschüttung per Stück          0,50 USD
Ausschüttung mit Teilfreist. per Stück 0,35 USD
Ex-Tag                                 19.08.2026
Zahltag                                03.09.2026
Brutto                              USD                        50,00
Zwischensumme                       USD                        50,00
Umg. z. Dev.-Kurs (1,250000)        EUR                        40,00
Kapitalertragsteuer 25,00%          EUR                         7,00
Solidaritätszuschlag 5,50%          EUR                         0,38
Gesamtbetrag zu Ihren Gunsten       EUR                        32,62

Valuta                              03.09.2026
Keine Fondsausgangsquellensteuer

ISIN (WKN) IE00B1234567 (A1B2C3)

Ausschüttung gem §2 Abs. 11 InvStG                40,00 EUR
abzgl. Teilfreistellungsbetrag 30,00 %            12,00 EUR
Ertragsausschüttung nach Teilfreistellung         28,00 EUR
KapSt-pflichtiger Kapitalertrag                   28,00 EUR
Bemessungsgrundlage für KapSt vor QuSt            28,00 EUR
Bemessungsgrundlage für KapSt                     28,00 EUR
Sparer-Pauschbetrag vor Ertrag                     0,00 EUR
''';

/// The same layout paying in EUR, with treaty withholding deducted on the
/// front page and offset against the pot on page 2.
///
/// 100,00 EUR gross, less 15,00 Quellensteuer, 2,50 Kapitalertragsteuer and
/// 0,13 Solidaritätszuschlag = 82,37 EUR paid out.
const _ingWithholdingDividend = '''
ING-DiBa AG · 60628 Frankfurt am Main

                                    Direkt-Depot Nr.:    9000000001
                                    Datum:               09.09.2026

Ertragsgutschrift

ISIN (WKN)                          NL0011111117 (A2B3C4)
Wertpapierbezeichnung               Muster Dividend Fund
                                    Aandelen oop toonder o.N.

Nominale                               200,00 Stück
Zins-/Dividendensatz                   0,50 EUR
Ausschüttung mit Teilfreist. per Stück 0,35 EUR
Ex-Tag                                 02.09.2026
Zahltag                                09.09.2026
Brutto                              EUR                       100,00
QuSt 15,00 %                        EUR                        15,00
Kapitalertragsteuer 25,00%          EUR                         2,50
Solidaritätszuschlag 5,50%          EUR                         0,13
Gesamtbetrag zu Ihren Gunsten       EUR                        82,37

Valuta                              09.09.2026
Quellensteuer laut Doppelbesteuerungsabkommen (DBA).

ISIN (WKN) NL0011111117 (A2B3C4)

Ausschüttung gem §2 Abs. 11 InvStG               100,00 EUR
abzgl. Teilfreistellungsbetrag 30,00 %            30,00 EUR
Ertragsausschüttung nach Teilfreistellung         70,00 EUR
Anrechenbare ausländische Quellensteuer           15,00 EUR
KapSt-pflichtiger Kapitalertrag                   70,00 EUR
Mit Verrechnungstopf ausländ. Quellenst. verrechnet  -15,00 EUR
Bemessungsgrundlage für KapSt vor QuSt            70,00 EUR
Auf Kapitalertrag angerechn. ausl. QuSt           60,00 EUR
Bemessungsgrundlage für KapSt                     10,00 EUR
''';

/// The ING "Dividendengutschrift" layout for a share paying in a foreign
/// currency: the treaty withholding is deducted in USD, before the conversion,
/// while the German taxes below it are already EUR.
///
/// 50,00 USD gross at 1,250000 = 40,00 EUR, less 7,50 USD withholding (6,00
/// EUR), 4,00 Kapitalertragsteuer and 0,22 Solidaritätszuschlag = 29,78 EUR.
const _ingUsdWithholdingDividend = '''
ING-DiBa AG · 60628 Frankfurt am Main

                                    Direkt-Depot Nr.:    9000000001
                                    Datum:               11.09.2026

Dividendengutschrift

ISIN (WKN)                          US1234567899 (A4B5C6)
Wertpapierbezeichnung               Muster Health Corp
                                    Registered Shares DL 1

Nominale                               40,00 Stück
Zins-/Dividendensatz                   1,25 USD
Ex-Tag                                 25.08.2026
Zahltag                                08.09.2026
Brutto                              USD                        50,00
QuSt 15,00 % (EUR 6,00)             USD                         7,50
Zwischensumme                       USD                        42,50
Umg. z. Dev.-Kurs (1,250000)        EUR                        34,00
Kapitalertragsteuer 25,00%          EUR                         4,00
Solidaritätszuschlag 5,50%          EUR                         0,22
Gesamtbetrag zu Ihren Gunsten       EUR                        29,78

Valuta                              08.09.2026
Quellensteuer laut Doppelbesteuerungsabkommen (DBA).

ISIN (WKN) US1234567899 (A4B5C6)

Anrechenbare ausländische Quellensteuer            6,00 EUR
KapSt-pflichtiger Kapitalertrag                   40,00 EUR
Mit Verrechnungstopf ausländ. Quellenst. verrechnet  -6,00 EUR
Bemessungsgrundlage für KapSt vor QuSt            40,00 EUR
''';

/// An ING "Wertpapierabrechnung" for a savings-plan buy: a fractional quantity
/// behind its unit, and the booked total labelled "Endbetrag zu Ihren Lasten".
///
/// 7,81250 units at 32,00 EUR = 250,00 EUR debited, no costs.
const _ingSavingsPlanBuy = '''
ING-DiBa AG · 60628 Frankfurt am Main

                                    Direkt-Depot Nr.:    9000000001
                                    Datum:               16.04.2026

Wertpapierabrechnung                Kauf aus Sparplan
Ordernummer                         100000001.001
ISIN (WKN)                          IE00B7654321 (A3B4C5)
Wertpapierbezeichnung               Muster Develop.World U.ETF
                                    Registered Shares USD Dis.oN

Nominale                            Stück                    7,81250
Kurs                                EUR                         32,00
Handelsplatz                        Xetra
Ausführungstag / -zeit              15.04.2026 um 09:04:00 Uhr
Kurswert                            EUR                        250,00
Zwischensumme                       EUR                        250,00
Endbetrag zu Ihren Lasten           EUR                        250,00

Valuta                              17.04.2026
''';

/// A synthetic DKB "Ausschüttung Investmentfonds", the fund-distribution
/// layout. It abbreviates where the dividend layout spells things out: the
/// rate is "pro St." and the taxable base is "Kapitalertragsteuerpfl.", which
/// reads as a tax label unless the abbreviation is recognised.
///
/// 40,00 EUR distributed, less 7,00 Kapitalertragsteuer and 0,38
/// Solidaritätszuschlag = 32,62 EUR paid out.
const _fundDistribution = '''
Deutsche Kreditbank AG
10919 Berlin
                                        Depotnummer       100000001
                                        Datum             02.09.2026

Ausschüttung Investmentfonds

Nominale            Wertpapierbezeichnung          ISIN            (WKN)
Stück 20            MUSTER INDEX FONDS             LU1234567890    (A0B1C2)
                    INHABER-ANTEILE 1D O.N.

Zahlbarkeitstag     03.09.2026      Ausschüttung pro St.      2,000000000   EUR
Bestandsstichtag    18.08.2026      mit Teilfreistellung (Aktien-
Ex-Tag              19.08.2026      fonds)                    1,400000000 EUR
Geschäftsjahr       01.01.2026 - 31.12.2026   Herkunftsland         Luxemburg

Ausschüttung                                                      40,00+ EUR
davon steuerfreier Anteil wg. Teilfreistellung     12,00   EUR
Kapitalertragsteuerpfl. Ertrag nach Teilfreistellung  28,00   EUR

Berechnungsgrundlage für die Kapitalertragsteuer   28,00   EUR

Kapitalertragsteuer 25 % auf 28,00 EUR                             7,00-  EUR
Solidaritätszuschlag 5,5 % auf 7,00 EUR                            0,38-  EUR
Ausmachender Betrag                                               32,62+ EUR

Lagerstelle Clearstream Banking Lux (849133 / 64003)
Keine Steuerbescheinigung.
Nachrichtlich die Übersicht Ihrer Verrechnungs- und Steuertopfsalden zum
Zeitpunkt der Erstellung der Abrechnung.

                       Verrechnungstöpfe 2026            Berechnungsgrundlage
                                                         der gezahlten Steuern
 Euro       Aktien   Sonstige    Sparer-   anrechenbare   Aktien und Sonstige
                             Pauschbetrag  Quellensteuer
 Vorher     500,00       0,00       0,00           0,00              2.000,00
 Ertrag       0,00       0,00       0,00           0,00                 28,00
 Nachher    500,00       0,00       0,00           0,00              2.028,00
''';

void main() {
  group('DKB dividend statement', () {
    final parsed = DepotStatementParser.parse(
      id: 'x',
      fileName: 'dividend.pdf',
      rawText: _dividend,
    );

    test('sums only the taxes actually withheld', () {
      final activity = parsed.activity!;

      expect(activity.tax, closeTo(2.04, 0.005));
      expect(activity.fee, 0);
      expect(activity.amount, closeTo(8.00, 0.005));
      expect(parsed.issues, isEmpty);
    });

    test(
      'reads the position and converts the USD price at the printed rate',
      () {
        final activity = parsed.activity!;

        expect(parsed.bank, DepotBank.dkb);
        expect(activity.type, DepotActivityType.dividend);
        expect(activity.date, DateTime(2026, 9, 1));
        expect(activity.isin, 'US1234567890');
        expect(activity.wkn, 'A1B2C3');
        expect(activity.securityName, 'MUSTER CORP.');
        expect(activity.shares, 10);
        expect(activity.sourceCurrency, 'USD');
        expect(activity.fxRate, closeTo(1.25, 0.00005));
        expect(activity.price, closeTo(0.80, 0.0001));
      },
    );
  });

  group('ING dividend statement', () {
    final foreign = DepotStatementParser.parse(
      id: 'y',
      fileName: 'ertrag.pdf',
      rawText: _ingForeignDividend,
    );
    final withholding = DepotStatementParser.parse(
      id: 'z',
      fileName: 'ertrag.pdf',
      rawText: _ingWithholdingDividend,
    );

    test('reads the quantity that precedes its unit', () {
      expect(foreign.activity!.shares, 100);
      expect(withholding.activity!.shares, 200);
    });

    test('books on the Zahltag, not the Ex-Tag printed above it', () {
      expect(foreign.activity!.date, DateTime(2026, 9, 3));
      expect(withholding.activity!.date, DateTime(2026, 9, 9));
    });

    test('takes the name from the label below the lone ISIN line', () {
      final activity = foreign.activity!;

      expect(foreign.bank, DepotBank.ing);
      expect(activity.isin, 'IE00B1234567');
      expect(activity.wkn, 'A1B2C3');
      expect(activity.securityName, 'Muster ETF Global Equity');
    });

    test('converts the per-share rate at the Dev.-Kurs, ignoring the partially '
        'exempt rate', () {
      final activity = foreign.activity!;

      expect(activity.sourceCurrency, 'USD');
      expect(activity.fxRate, closeTo(1.25, 0.00005));
      expect(activity.price, closeTo(0.40, 0.0001));
      expect(activity.tax, closeTo(7.38, 0.005));
      expect(activity.amount, closeTo(40.00, 0.005));
      expect(foreign.issues, isEmpty);
    });

    test('adds treaty withholding to the tax without the page-2 offsets', () {
      final activity = withholding.activity!;

      expect(activity.price, closeTo(0.50, 0.0001));
      expect(activity.tax, closeTo(17.63, 0.005));
      expect(activity.amount, closeTo(100.00, 0.005));
      expect(withholding.issues, isEmpty);
    });
  });

  group('ING foreign-currency withholding', () {
    final parsed = DepotStatementParser.parse(
      id: 'q',
      fileName: 'dividende.pdf',
      rawText: _ingUsdWithholdingDividend,
    );

    test('converts each withheld tax at the currency of its own line', () {
      final activity = parsed.activity!;

      expect(activity.sourceCurrency, 'USD');
      expect(activity.tax, closeTo(10.22, 0.005));
      expect(activity.amount, closeTo(40.00, 0.005));
      expect(activity.price, closeTo(1.00, 0.0001));
      expect(parsed.issues, isEmpty);
    });
  });

  group('ING savings-plan buy', () {
    final parsed = DepotStatementParser.parse(
      id: 'b',
      fileName: 'abrechnung.pdf',
      rawText: _ingSavingsPlanBuy,
    );

    test('books the execution day at the fractional quantity', () {
      final activity = parsed.activity!;

      expect(activity.type, DepotActivityType.buy);
      expect(activity.date, DateTime(2026, 4, 15));
      expect(activity.shares, closeTo(7.8125, 0.000005));
      expect(activity.price, closeTo(32.00, 0.0001));
      expect(activity.amount, closeTo(250.00, 0.005));
      expect(activity.tax, 0);
      expect(activity.fee, 0);
      expect(parsed.issues, isEmpty);
    });
  });

  group('DKB fund distribution', () {
    final parsed = DepotStatementParser.parse(
      id: 'f',
      fileName: 'ausschuettung.pdf',
      rawText: _fundDistribution,
    );

    test('does not read the abbreviated taxable base as a tax', () {
      final activity = parsed.activity!;

      expect(activity.tax, closeTo(7.38, 0.005));
      expect(activity.amount, closeTo(40.00, 0.005));
      expect(parsed.issues, isEmpty);
    });

    test('reads the rate abbreviated as "pro St."', () {
      final activity = parsed.activity!;

      expect(activity.shares, 20);
      expect(activity.price, closeTo(2.00, 0.0001));
      expect(activity.isin, 'LU1234567890');
      expect(activity.wkn, 'A0B1C2');
      expect(activity.securityName, 'MUSTER INDEX FONDS');
      expect(activity.date, DateTime(2026, 9, 3));
    });
  });

  group('revalidate after manual edit', () {
    DepotActivity activity({
      double shares = 10,
      double price = 32,
      double amount = 320,
      String isin = 'US1234567890',
      DateTime? date,
      String sourceCurrency = 'EUR',
      double? fxRate,
    }) => DepotActivity(
      type: DepotActivityType.buy,
      date: date ?? DateTime(2026, 9, 1),
      isin: isin,
      wkn: null,
      securityName: 'Muster',
      shares: shares,
      price: price,
      amount: amount,
      tax: 0,
      fee: 0,
      sourceCurrency: sourceCurrency,
      fxRate: fxRate,
    );

    test('clean activity has no issues', () {
      expect(DepotStatementParser.revalidate(activity()), isEmpty);
    });

    test('flags a newly introduced total mismatch', () {
      final issues = DepotStatementParser.revalidate(
        activity(amount: 300),
      );
      expect(issues, contains(DepotParseIssue.amountMismatch));
    });

    test('tolerates cent rounding but not euro deviations', () {
      expect(
        DepotStatementParser.revalidate(activity(amount: 320.04)),
        isEmpty,
      );
      expect(
        DepotStatementParser.revalidate(activity(amount: 321)),
        contains(DepotParseIssue.amountMismatch),
      );
    });

    test('reports missing fields from zeroed values', () {
      final issues = DepotStatementParser.revalidate(
        activity(shares: 0, price: 0, amount: 0, isin: ''),
      );
      expect(issues, contains(DepotParseIssue.missingIsin));
      expect(issues, contains(DepotParseIssue.missingShares));
      expect(issues, contains(DepotParseIssue.missingPrice));
      expect(issues, contains(DepotParseIssue.missingAmount));
    });

    test('flags a foreign currency without a rate', () {
      final issues = DepotStatementParser.revalidate(
        activity(sourceCurrency: 'USD'),
      );
      expect(issues, contains(DepotParseIssue.missingFxRate));
    });
  });
}
