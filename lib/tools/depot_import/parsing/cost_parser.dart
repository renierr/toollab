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
  /// tax base line repeats an amount that is not itself a tax.
  static const _taxExcluding = [
    'anrechenbar',
    'erstattungsfähig',
    'rückforderbar',
    'freistellungsauftrag',
    'steuerpflichtig',
    'bemessungsgrundlage',
  ];

  static Money fees(StatementText text) => Money(
    text.sumOf(_feeLabels, excluding: _feeExcluding),
    text.currencyOf(_feeLabels),
  );

  static Money taxes(StatementText text) => Money(
    text.sumOf(_taxLabels, excluding: _taxExcluding),
    text.currencyOf(_taxLabels),
  );
}
