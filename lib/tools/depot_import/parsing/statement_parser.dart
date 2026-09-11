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

    final fee = converter.convert(CostParser.fees(text)) ?? 0;
    final tax = converter.convert(CostParser.taxes(text)) ?? 0;

    final gross = converter.convert(grossMoney)?.abs();
    var amount = converter.convert(totalMoney)?.abs();
    var price = converter.convert(priceMoney)?.abs();

    price ??= _derivePrice(gross ?? amount, shares);
    if (price == null) issues.add(DepotParseIssue.missingPrice);

    amount ??= _deriveAmount(gross, resolvedType, fee, tax);
    if (amount == null) issues.add(DepotParseIssue.missingAmount);

    final sourceCurrency = _sourceCurrency([priceMoney, grossMoney]);
    if (sourceCurrency != 'EUR' && fx == null) {
      issues.add(DepotParseIssue.missingFxRate);
    }

    if (_mismatches(resolvedType, price, shares, amount, fee, tax)) {
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

  static double? _deriveAmount(
    double? gross,
    DepotActivityType type,
    double fee,
    double tax,
  ) {
    if (gross == null) return null;
    return type == DepotActivityType.buy
        ? gross + fee + tax
        : gross - fee - tax;
  }

  static String _sourceCurrency(List<Money?> values) {
    for (final money in values) {
      if (money != null && money.currency != 'EUR') return money.currency;
    }
    return 'EUR';
  }

  /// Cross-check: the booked amount should be the position value plus or minus
  /// the costs. A mismatch means a label was read from the wrong column.
  static bool _mismatches(
    DepotActivityType type,
    double? price,
    double? shares,
    double? amount,
    double fee,
    double tax,
  ) {
    if (price == null || shares == null || amount == null) return false;
    final expected = type == DepotActivityType.buy
        ? price * shares + fee + tax
        : price * shares - fee - tax;
    final tolerance = (amount.abs() * 0.01).clamp(0.05, 25.0);
    return (expected - amount).abs() > tolerance;
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
}
