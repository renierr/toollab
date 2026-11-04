import 'models/depot_holding.dart';

/// Holding kinds with their own configurable details page.
enum DepotDetailsLinkKind {
  etf('https://www.finanzfluss.de/informer/etf/{isin}/'),
  etc('https://www.finanzfluss.de/informer/etf/{isin}/'),
  fund('https://www.finanzfluss.de/informer/fonds/{isin}/'),
  stock('https://app.parqet.com/aktie/{isin}');

  final String defaultTemplate;

  const DepotDetailsLinkKind(this.defaultTemplate);

  static DepotDetailsLinkKind? of(DepotHoldingKind kind) => switch (kind) {
    DepotHoldingKind.etf => etf,
    DepotHoldingKind.etc => etc,
    DepotHoldingKind.fund => fund,
    DepotHoldingKind.stock => stock,
    _ => null,
  };
}

/// Builds a holding's external details page URL from a user template.
class DepotDetailsLink {
  DepotDetailsLink._();

  static const List<String> placeholders = ['{isin}', '{symbol}', '{name}'];

  static final RegExp _placeholder = RegExp(r'\{(\w+)\}');

  /// Null when the template is invalid or uses a value the holding lacks.
  static Uri? build(String template, DepotHolding holding) {
    final values = <String, String?>{
      'isin': holding.isin,
      'symbol': holding.symbol,
      'name': holding.name,
    };
    var missing = false;
    final url = template.trim().replaceAllMapped(_placeholder, (match) {
      final key = match[1]!.toLowerCase();
      if (!values.containsKey(key)) return match[0]!;
      final value = values[key]?.trim();
      if (value == null || value.isEmpty) {
        missing = true;
        return '';
      }
      return Uri.encodeComponent(value);
    });
    if (missing || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) return null;
    return uri.isScheme('http') || uri.isScheme('https') ? uri : null;
  }
}
