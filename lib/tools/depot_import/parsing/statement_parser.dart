import '../models/depot_activity.dart';
import 'activity_type_parser.dart';
import 'amount_parser.dart';
import 'bank_detector.dart';
import 'cost_parser.dart';
import 'fx_parser.dart';
import 'german_format.dart';
import 'price_parser.dart';
import 'quantity_parser.dart';
import 'security_parser.dart';
import 'statement_date_parser.dart';
import 'statement_text.dart';

/// Runs the field parsers over one statement and reconciles what they found
/// into a single EUR activity, recording anything that stayed unresolved.
class DepotStatementParser {
  DepotStatementParser._();

  static ParsedStatement parse({
    required String id,
    required String fileName,
    required String rawText,
  }) {
    final text = StatementText(rawText);
    final bank = BankDetector.detect(text);

    if (text.lines.isEmpty) {
      return ParsedStatement(
        id: id,
        fileName: fileName,
        bank: bank,
        activity: null,
        issues: const [DepotParseIssue.noText],
        rawText: rawText,
      );
    }

    final issues = <DepotParseIssue>[];
    final type = ActivityTypeParser.parse(rawText);
    if (type == null) issues.add(DepotParseIssue.unknownType);
    final resolvedType = type ?? DepotActivityType.buy;

    final isin = SecurityParser.isin(rawText);
    if (isin.isEmpty) issues.add(DepotParseIssue.missingIsin);

    final date = StatementDateParser.parse(text, resolvedType);
    if (date == null) issues.add(DepotParseIssue.missingDate);

    final shares = QuantityParser.parse(text);
    if (shares == null || shares == 0) {
      issues.add(DepotParseIssue.missingShares);
    }

    final fx = FxParser.parse(text);
    final converter = _EurConverter(fx);

    final priceMoney = PriceParser.parse(text, resolvedType);
    final grossMoney = AmountParser.gross(text);
    final totalMoney = AmountParser.total(text);

    final fee = converter.sum(CostParser.fees(text));
    final tax = converter.sum(CostParser.taxes(text));

    final gross = converter.convert(grossMoney)?.abs();
    final total = converter.convert(totalMoney)?.abs();
    var price = converter.convert(priceMoney)?.abs();

    final amount =
        _grossFromTotal(total, resolvedType, fee, tax) ??
        _product(price, shares) ??
        gross;
    if (amount == null) issues.add(DepotParseIssue.missingAmount);

    price ??= _derivePrice(amount, shares);
    if (price == null) issues.add(DepotParseIssue.missingPrice);

    final sourceCurrency = _sourceCurrency([priceMoney, grossMoney]);
    if (sourceCurrency != 'EUR' && fx == null) {
      issues.add(DepotParseIssue.missingFxRate);
    }

    if (_mismatches(price, shares, amount)) {
      issues.add(DepotParseIssue.amountMismatch);
    }

    return ParsedStatement(
      id: id,
      fileName: fileName,
      bank: bank,
      activity: DepotActivity(
        type: resolvedType,
        date: date,
        isin: isin,
        wkn: SecurityParser.wkn(rawText),
        securityName: SecurityParser.name(text, isin),
        shares: shares ?? 0,
        price: price ?? 0,
        amount: amount ?? 0,
        tax: tax,
        fee: fee,
        sourceCurrency: sourceCurrency,
        fxRate: sourceCurrency == 'EUR' ? null : fx?.perEur(sourceCurrency),
      ),
      issues: issues,
      rawText: rawText,
    );
  }

  static double? _derivePrice(double? total, double? shares) {
    if (total == null || shares == null || shares == 0) return null;
    return total / shares;
  }

  /// Parqet's `amount` is the position value before costs, while the statement
  /// books the money that moved: costs are added on a buy and withheld on a
  /// payout. Rebuilding it from the booked total keeps the cents exact instead
  /// of multiplying a rounded per-share rate.
  static double? _grossFromTotal(
    double? total,
    DepotActivityType type,
    double fee,
    double tax,
  ) {
    if (total == null) return null;
    return type == DepotActivityType.buy
        ? total - fee - tax
        : total + fee + tax;
  }

  static double? _product(double? price, double? shares) =>
      price == null || shares == null ? null : price * shares;

  static String _sourceCurrency(List<Money?> values) {
    for (final money in values) {
      if (money != null && money.currency != 'EUR') return money.currency;
    }
    return 'EUR';
  }

  /// Cross-check: the gross amount should be the per-share rate times the
  /// quantity. A mismatch means a label was read from the wrong column.
  static bool _mismatches(double? price, double? shares, double? amount) {
    if (price == null || shares == null || amount == null) return false;
    final tolerance = (amount.abs() * 0.01).clamp(0.05, 25.0);
    return (price * shares - amount).abs() > tolerance;
  }
}

/// Converts a document value into EUR using only the rate the document itself
/// printed — the tool never reaches the network for a rate.
class _EurConverter {
  final FxRate? fx;

  const _EurConverter(this.fx);

  double? convert(Money? money) {
    if (money == null) return null;
    if (money.currency == 'EUR') return money.value;
    if (fx == null) return null;
    return money.value / fx!.perEur(money.currency);
  }

  double sum(Iterable<Money> monies) {
    double total = 0;
    for (final money in monies) {
      total += convert(money) ?? 0;
    }
    return total;
  }
}
