import 'german_format.dart';
import 'statement_text.dart';

/// Order costs and withheld taxes, each summed over every line that names one.
/// Both end up in their own Parqet column, so they are kept apart.
class CostParser {
  CostParser._();

  static const _feeLabels = [
    'Provision',
    'Handelsentgelt',
    'Transaktionsentgelt',
    'Maklercourtage',
    'Courtage',
    'Börsenentgelt',
    'Entgelte',
    'Fremde Spesen',
    'Fremde Auslagen',
    'Fremde Abwicklungsgebühr',
    'Abwicklungsgebühr',
    'Börsengebühr',
    'Handelsplatzgebühr',
    'Handelsplatzentgelt',
    'Börsenplatzabhängige',
    'Xetra-Entgelt',
    'Orderentgelt',
    'Grundgebühr',
    'Übertragungs-/Liefergebühr',
    'Umschreibeentgelt',
    'Clearing-Entgelt',
    'Lagerstellengebühr',
    'Depotgebühr',
  ];
  static const _feeExcluding = [
    'keine',
    'rabatt',
    'ermäßigung',
    'erstattung',
    'befreit',
    'summe',
  ];

  static const _taxLabels = [
    'Kapitalertragsteuer',
    'Kapitalertragssteuer',
    'Kapitalertragsteue',
    'Solidaritätszuschlag',
    'Kirchensteuer',
    'Quellensteuer',
    'QuSt',
    'Abgeltungsteuer',
    'Transaktionssteuer',
  ];

  /// Creditable or refundable withholding is not money the broker kept, and a
  /// tax base line ("Berechnungsgrundlage für die Kapitalertragsteuer")
  /// repeats an amount that is not itself a tax. The last group is prose —
  /// "Keine Fondsausgangsquellensteuer" names a tax only to say none was
  /// taken, and carries no amount for the lookahead to find on its line.
  static const _taxExcluding = [
    'anrechenbar',
    'angerechn',
    'erstattungsfähig',
    'rückforderbar',
    'freistellungsauftrag',
    'steuerpfl',
    'bemessungsgrundlage',
    'berechnungsgrundlage',
    'keine',
    'doppelbesteuerungsabkommen',
    'bescheinigung',
  ];

  static List<Money> fees(StatementText text) =>
      text.moniesOf(_feeLabels, excluding: _feeExcluding);

  static List<Money> taxes(StatementText text) =>
      text.moniesOf(_taxLabels, excluding: _taxExcluding);
}
