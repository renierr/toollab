import '../models/depot_activity.dart';
import 'statement_text.dart';

/// Which broker issued the statement. Only used for display and for picking
/// the right fallbacks — the field parsers share one label vocabulary.
class BankDetector {
  BankDetector._();

  static const _dkbMarkers = [
    'deutsche kreditbank',
    'dkb.de',
    'bylad',
    'dkb ag',
  ];
  static const _ingMarkers = [
    'ing-diba',
    'ing diba',
    'ingddeff',
    'www.ing.de',
    'ing bank',
  ];
  static const _postbankMarkers = [
    'deutsche postbank',
    'postbank.de',
    'pbnkdeff',
    'postbank – eine niederlassung',
    'postbank - eine niederlassung',
  ];

  static DepotBank detect(StatementText text) {
    if (text.containsAny(_dkbMarkers)) return DepotBank.dkb;
    if (text.containsAny(_ingMarkers)) return DepotBank.ing;
    if (text.containsAny(_postbankMarkers)) return DepotBank.postbank;
    if (text.contains('dkb')) return DepotBank.dkb;
    if (text.contains('postbank')) return DepotBank.postbank;
    // Whole word only: "ing" is inside "Holding", "Accumulating", ...
    if (text.lines.any(_ingWord.hasMatch)) return DepotBank.ing;
    return DepotBank.unknown;
  }

  static final _ingWord = RegExp(r'\bing\b', caseSensitive: false);
}
