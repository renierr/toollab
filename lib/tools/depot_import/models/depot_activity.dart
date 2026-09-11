enum DepotBank { dkb, ing, unknown }

enum DepotActivityType { buy, sell, dividend }

extension DepotActivityTypeCsv on DepotActivityType {
  String get parqetValue => switch (this) {
    DepotActivityType.buy => 'Buy',
    DepotActivityType.sell => 'Sell',
    DepotActivityType.dividend => 'Dividend',
  };
}

/// Something the parser could not resolve on its own. Every issue is
/// recoverable by hand in the review table before the CSV is written.
enum DepotParseIssue {
  noText,
  unknownType,
  missingIsin,
  missingDate,
  missingShares,
  missingPrice,
  missingAmount,
  missingFxRate,
  amountMismatch,
}

/// One Parqet activity, always in EUR. Foreign-currency documents are
/// converted with the `Devisenkurs` printed in the document itself.
class DepotActivity {
  final DepotActivityType type;
  final DateTime? date;
  final String isin;
  final String? wkn;
  final String securityName;
  final double shares;
  final double price;
  final double amount;
  final double tax;
  final double fee;

  /// Currency the document stated its values in, before conversion.
  final String sourceCurrency;

  /// Units of [sourceCurrency] per 1 EUR, as printed in the document.
  final double? fxRate;

  const DepotActivity({
    required this.type,
    required this.date,
    required this.isin,
    required this.wkn,
    required this.securityName,
    required this.shares,
    required this.price,
    required this.amount,
    required this.tax,
    required this.fee,
    this.sourceCurrency = 'EUR',
    this.fxRate,
  });

  bool get isForeignCurrency => sourceCurrency != 'EUR';

  DepotActivity copyWith({
    DepotActivityType? type,
    DateTime? date,
    String? isin,
    String? wkn,
    String? securityName,
    double? shares,
    double? price,
    double? amount,
    double? tax,
    double? fee,
    String? sourceCurrency,
    double? fxRate,
  }) {
    return DepotActivity(
      type: type ?? this.type,
      date: date ?? this.date,
      isin: isin ?? this.isin,
      wkn: wkn ?? this.wkn,
      securityName: securityName ?? this.securityName,
      shares: shares ?? this.shares,
      price: price ?? this.price,
      amount: amount ?? this.amount,
      tax: tax ?? this.tax,
      fee: fee ?? this.fee,
      sourceCurrency: sourceCurrency ?? this.sourceCurrency,
      fxRate: fxRate ?? this.fxRate,
    );
  }
}

/// A single imported PDF: what was parsed out of it, what went wrong, and the
/// raw text it was parsed from (kept so a miss can be diagnosed in the UI).
class ParsedStatement {
  final String id;
  final String fileName;
  final DepotBank bank;
  final DepotActivity? activity;
  final List<DepotParseIssue> issues;
  final String rawText;
  final bool edited;
  final bool selected;

  const ParsedStatement({
    required this.id,
    required this.fileName,
    required this.bank,
    required this.activity,
    required this.issues,
    required this.rawText,
    this.edited = false,
    this.selected = true,
  });

  bool get isExportable =>
      activity != null &&
      !issues.contains(DepotParseIssue.missingIsin) &&
      activity!.date != null;

  ParsedStatement copyWith({
    DepotActivity? activity,
    List<DepotParseIssue>? issues,
    bool? edited,
    bool? selected,
  }) {
    return ParsedStatement(
      id: id,
      fileName: fileName,
      bank: bank,
      activity: activity ?? this.activity,
      issues: issues ?? this.issues,
      rawText: rawText,
      edited: edited ?? this.edited,
      selected: selected ?? this.selected,
    );
  }
}
