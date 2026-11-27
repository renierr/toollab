import '../models/depot_activity.dart';
import 'security_parser.dart';
import 'statement_parser.dart';

/// Trade Republic prints each position as one table row
/// ("Name 10 Stk. 38,25 EUR 382,50 EUR") and switches between decimal comma
/// and decimal point from one document to the next, so the label lookups the
/// other banks share do not fit.
///
/// Bonds follow Parqet's convention: shares are the nominal divided by 100 and
/// the price is EUR per 100 nominal, so a coupon's price is its rate in percent.
/// Accrued interest (Stückzinsen) is folded into the amount, paid on a buy and
/// received on a sale.
class TradeRepublicParser {
  TradeRepublicParser._();

  // A digit followed by "-" before a number is an ISO date ("2024-06-13").
  static const _number =
      r'(?<![\d.,]|\d-)(-)?(\d{1,3}(?: \d{3})+,\d{2}|\d{1,3}(?:[.,]\d{3})+(?:[.,]\d+)?(?!\d)|\d+(?:[.,]\d+)?(?!\d))';
  static const _unit = r'(Stk\.|Stücke?|[A-Z]{3})';

  static final _tradeRow = RegExp(
    '$_number $_unit $_number (%|[A-Z]{3}) $_number ([A-Z]{3})',
  );
  static final _incomeRow = RegExp(
    '$_number ([A-Z]{3}) $_number $_unit $_number (%|[A-Z]{3})',
  );
  static final _pieces = RegExp('$_number (Stk\\.|Stücke?)');
  static final _money = RegExp('$_number ([A-Z]{3})(?![A-Z/])');

  /// "1.0797 USD/EUR" and the older "1,102 EUR/USD" both mean USD per EUR.
  static final _fx = RegExp('$_number (?:([A-Z]{3})/EUR|EUR/([A-Z]{3}))');
  static final _isinLabel = RegExp(r'ISIN:?\s*');
  static final _rowNumber = RegExp(
    r'\b\d+\s+(Tilgung|Ausbuchung|Rückzahlung)\b',
    caseSensitive: false,
  );
  static final _correction = RegExp(r'korrektur des belegs|steuerkorrektur');

  static final _incomeHeadline = RegExp(
    r'^(dividende|zinszahlung|kupon\w*|(bar|ertrags)?aussch(ü|ue)ttung)\b',
  );
  static final _redemptionHeadline = RegExp(
    r'^(tilgung|r(ü|ue)ckzahlung|endf(ä|ae)lligkeit|repayment)$',
  );
  static final _sell = RegExp(r'\b(verkauf|sell)\b');
  static final _buy = RegExp(
    r'\b(kauf|buy)\b|ausf(ü|ue)hrung am|saveback|round ?up',
  );
  static final _tradeDate = RegExp(r'\bam (\d{2})\.(\d{2})\.(\d{4})');
  static final _germanDate = RegExp(r'\b(\d{2})\.(\d{2})\.(\d{4})\b');
  static final _isoDate = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');

  static ParsedStatement parse({
    required String id,
    required String fileName,
    required String rawText,
  }) {
    final lines = _lines(rawText);
    if (lines.isEmpty) {
      return ParsedStatement(
        id: id,
        fileName: fileName,
        bank: DepotBank.tradeRepublic,
        activity: null,
        issues: const [DepotParseIssue.noText],
        rawText: rawText,
      );
    }

    final text = lines.join('\n');
    final numbers = _Numbers.of(text);
    final kind = _kind(lines);
    final type = switch (kind) {
      _Kind.income => DepotActivityType.dividend,
      _Kind.redemption => DepotActivityType.sell,
      _Kind.sell => DepotActivityType.sell,
      _Kind.buy => DepotActivityType.buy,
      null => DepotActivityType.buy,
    };

    final isin = _firstIsin(text);
    final block = _positionBlock(lines);
    final isBond = block.header.contains('NOMINALE');
    final billing = _Billing.read(lines, numbers);
    final booking = _booking(lines, numbers);

    double? quantity;
    double? rowPrice;
    double? rowAmount;
    var rowCurrency = 'EUR';
    // Some payout advices print the ISIN between amount and quantity.
    var nameText =
        (isin.isEmpty ? block.body : block.body.replaceAll(isin, ' '))
            .replaceAll(_isinLabel, ' ')
            .replaceAll(RegExp(r'\s{2,}'), ' ');

    // Older payout advices print the trade layout: quantity, rate, amount.
    final incomeRow = kind == _Kind.income
        ? _incomeRow.firstMatch(nameText)
        : null;
    final row = incomeRow ?? _tradeRow.firstMatch(nameText);
    if (row != null) {
      if (incomeRow != null) {
        rowAmount = numbers.parse(row, 1);
        rowCurrency = row.group(3)!;
        quantity = numbers.parse(row, 4);
      } else {
        quantity = numbers.parse(row, 1);
        rowPrice = numbers.parse(row, 4);
        rowAmount = numbers.parse(row, 7);
        rowCurrency = row.group(9)!;
      }
      nameText = nameText.replaceFirst(row.group(0)!, ' ');
    } else {
      final pieces = _pieces.firstMatch(nameText);
      if (pieces != null) {
        quantity = numbers.parse(pieces, 1);
        nameText = nameText.replaceFirst(pieces.group(0)!, ' ');
      }
    }

    final tax = billing.tax < 0 ? 0.0 : billing.tax;
    final fee = billing.fee < 0 ? 0.0 : billing.fee;
    final total = booking.amount;

    double? amount;
    switch (type) {
      case DepotActivityType.dividend:
        amount = total == null ? billing.eurSubtotal : total + tax + fee;
      case DepotActivityType.buy:
        amount = rowCurrency == 'EUR' && rowAmount != null
            ? rowAmount - billing.accrued
            : total == null
            ? null
            : total - fee - tax;
      case DepotActivityType.sell:
        amount = rowCurrency == 'EUR' && rowAmount != null
            ? rowAmount + billing.accrued
            : billing.marketValue ?? (total == null ? null : total + fee + tax);
    }

    final shares = quantity == null
        ? null
        : isBond
        ? quantity / 100
        : quantity;
    final usesRowPrice =
        !isBond &&
        type != DepotActivityType.dividend &&
        rowCurrency == 'EUR' &&
        billing.accrued == 0;
    final price = usesRowPrice && rowPrice != null
        ? rowPrice
        : amount != null && shares != null && shares != 0
        ? amount / shares
        : null;

    final activity = DepotActivity(
      type: type,
      date: _date(kind, lines, booking.date),
      isin: isin,
      wkn: null,
      securityName: nameText
          .replaceFirst(_rowNumber, '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim(),
      shares: shares ?? 0,
      price: price ?? 0,
      amount: amount ?? 0,
      tax: tax,
      fee: fee,
      sourceCurrency: rowCurrency,
      fxRate: rowCurrency == 'EUR' ? null : billing.fx[rowCurrency],
      bookedTotal: total,
    );

    return ParsedStatement(
      id: id,
      fileName: fileName,
      bank: DepotBank.tradeRepublic,
      activity: activity,
      issues: [
        if (kind == null) DepotParseIssue.unknownType,
        ...DepotStatementParser.revalidate(activity),
      ],
      rawText: rawText,
    );
  }

  /// Page 2 explains the tax base and repeats every tax line, so only the
  /// settlement before it is read.
  static List<String> _lines(String raw) {
    final lines = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.replaceAll(' ', ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final cut = lines.indexWhere(
      (line) => line.toUpperCase().startsWith('STEUERLICHE BEHANDLUNG'),
    );
    return cut < 0 ? lines : lines.sublist(0, cut);
  }

  static _Kind? _kind(List<String> lines) {
    final lower = lines.map((l) => l.toLowerCase()).toList();
    if (lower.any(_correction.hasMatch)) return null;
    if (lower.any(_redemptionHeadline.hasMatch)) return _Kind.redemption;
    if (lower.any(_incomeHeadline.hasMatch)) return _Kind.income;
    if (!lower.any((l) => l.startsWith('wertpapierabrechnung'))) return null;
    final overview = lower.indexWhere((l) => l == 'übersicht');
    final sentence = overview >= 0 && overview + 1 < lower.length
        ? lower[overview + 1]
        : lower.join(' ');
    if (_sell.hasMatch(sentence)) return _Kind.sell;
    if (_buy.hasMatch(sentence)) return _Kind.buy;
    final headline = lower.firstWhere(
      (l) => l.startsWith('wertpapierabrechnung'),
    );
    return _buy.hasMatch(headline) || headline.contains('sparplan')
        ? _Kind.buy
        : null;
  }

  static String _firstIsin(String text) {
    for (final match in RegExp(
      r'\b[A-Z]{2}[A-Z0-9]{9}[0-9]\b',
    ).allMatches(text)) {
      if (SecurityParser.isValidIsin(match.group(0)!)) return match.group(0)!;
    }
    return SecurityParser.isin(text);
  }

  /// The table under "POSITION ANZAHL …" / "NR. BUCHUNG WERTPAPIER …", joined
  /// into one line: income rows break the name, amount and quantity apart.
  static ({String header, String body}) _positionBlock(List<String> lines) {
    final start = lines.indexWhere((line) {
      final upper = line.toUpperCase();
      return (upper.startsWith('POSITION') &&
              (upper.contains('ANZAHL') || upper.contains('NOMINALE'))) ||
          upper.startsWith('NR. BUCHUNG');
    });
    if (start < 0) return (header: '', body: '');
    final body = <String>[];
    for (var i = start + 1; i < lines.length; i++) {
      final upper = lines[i].toUpperCase();
      if (upper.startsWith('GESAMT') ||
          upper == 'ABRECHNUNG' ||
          upper.startsWith('BUCHUNG')) {
        break;
      }
      body.add(lines[i]);
    }
    return (header: lines[start].toUpperCase(), body: body.join(' '));
  }

  /// The money that moved on the clearing account and its date.
  static ({double? amount, DateTime? date}) _booking(
    List<String> lines,
    _Numbers numbers,
  ) {
    final start = lines.lastIndexWhere((line) {
      final upper = line.toUpperCase();
      return upper == 'BUCHUNG' || upper == 'GELDBUCHUNG';
    });
    if (start < 0) return (amount: null, date: null);
    for (var i = start + 1; i < lines.length && i <= start + 3; i++) {
      final monies = _money.allMatches(lines[i]).toList();
      if (monies.isEmpty) continue;
      final value = numbers.parse(monies.last, 1);
      return (amount: value?.abs(), date: _anyDate(lines[i]));
    }
    return (amount: null, date: null);
  }

  static DateTime? _date(
    _Kind? kind,
    List<String> lines,
    DateTime? bookingDate,
  ) {
    if (kind == _Kind.buy || kind == _Kind.sell) {
      for (final line in lines) {
        final match = _tradeDate.firstMatch(line);
        if (match != null) return _ymd(match, 3, 2, 1);
      }
    }
    if (bookingDate != null) return bookingDate;
    for (final line in lines) {
      if (line.toUpperCase().contains('DATUM')) {
        final date = _anyDate(line);
        if (date != null) return date;
      }
    }
    return null;
  }

  static DateTime? _anyDate(String line) {
    final german = _germanDate.firstMatch(line);
    if (german != null) return _ymd(german, 3, 2, 1);
    final iso = _isoDate.firstMatch(line);
    if (iso != null) return _ymd(iso, 1, 2, 3);
    return null;
  }

  static DateTime? _ymd(RegExpMatch m, int y, int mo, int d) {
    final month = int.parse(m.group(mo)!);
    final day = int.parse(m.group(d)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(int.parse(m.group(y)!), month, day);
  }
}

enum _Kind { buy, sell, income, redemption }

/// Reads numbers in whichever decimal style the document uses. "1.019" is a
/// thousand nineteen in a decimal-comma document and one point zero nineteen
/// in a decimal-point one; every other shape decides itself.
class _Numbers {
  final bool decimalComma;

  const _Numbers(this.decimalComma);

  factory _Numbers.of(String text) {
    final comma = RegExp(r'\d,\d{2} [A-Z]{3}\b').allMatches(text).length;
    final point = RegExp(r'\d\.\d{2} [A-Z]{3}\b').allMatches(text).length;
    return _Numbers(comma >= point);
  }

  /// Group [index] holds the digits and the group before it the sign.
  double? parse(RegExpMatch match, int index) {
    final digits = match.group(index + 1);
    if (digits == null) return null;
    final value = _value(digits.replaceAll(' ', ''));
    if (value == null) return null;
    return match.group(index) == '-' ? -value : value;
  }

  double? _value(String s) {
    final dot = s.lastIndexOf('.');
    final comma = s.lastIndexOf(',');
    String normalized;
    if (dot >= 0 && comma >= 0) {
      normalized = dot > comma
          ? s.replaceAll(',', '')
          : s.replaceAll('.', '').replaceAll(',', '.');
    } else if (comma >= 0) {
      normalized = ','.allMatches(s).length == 1
          ? s.replaceAll(',', '.')
          : s.replaceAll(',', '');
    } else if (dot >= 0) {
      final single = '.'.allMatches(s).length == 1;
      final thousands = !single || (s.length - dot - 1 == 3 && decimalComma);
      normalized = thousands ? s.replaceAll('.', '') : s;
    } else {
      normalized = s;
    }
    return double.tryParse(normalized);
  }
}

/// The ABRECHNUNG section: costs, withheld taxes, accrued interest and the
/// rate a foreign payout was converted at. Deductions are printed negative,
/// so [fee] and [tax] are the negated sums.
class _Billing {
  final double fee;
  final double tax;
  final double accrued;
  final double? marketValue;
  final double? eurSubtotal;

  /// Units of a currency per 1 EUR, keyed by currency.
  final Map<String, double> fx;

  const _Billing({
    required this.fee,
    required this.tax,
    required this.accrued,
    required this.marketValue,
    required this.eurSubtotal,
    required this.fx,
  });

  static _Billing read(List<String> lines, _Numbers numbers) {
    final start = lines.indexWhere((line) {
      final upper = line.toUpperCase();
      return upper == 'ABRECHNUNG' || upper == 'BILLING';
    });
    final section = <String>[];
    if (start >= 0) {
      for (var i = start + 1; i < lines.length; i++) {
        final upper = lines[i].toUpperCase();
        if (upper == 'BUCHUNG' ||
            upper == 'GELDBUCHUNG' ||
            upper == 'BOOKING') {
          break;
        }
        section.add(lines[i]);
      }
    }

    final fx = <String, double>{};
    for (final line in section) {
      for (final m in TradeRepublicParser._fx.allMatches(line)) {
        final rate = numbers.parse(m, 1);
        if (rate != null && rate > 0) fx[m.group(3) ?? m.group(4)!] = rate;
      }
    }

    double fee = 0;
    double tax = 0;
    double accrued = 0;
    double? marketValue;
    double? eurSubtotal;
    for (final line in section) {
      final lower = line.toLowerCase();
      final monies = TradeRepublicParser._money.allMatches(line).toList();
      if (monies.isEmpty) continue;
      final last = monies.last;
      final raw = numbers.parse(last, 1);
      if (raw == null) continue;
      final currency = last.group(3)!;
      final rate = currency == 'EUR' ? 1.0 : fx[currency];
      if (rate == null) continue;
      final eur = raw / rate;

      if (lower.startsWith('gesamt') ||
          lower.startsWith('summe') ||
          lower.startsWith('total') ||
          lower.startsWith('position')) {
        continue;
      }
      if (lower.contains('zwischensumme')) {
        if (currency == 'EUR') eurSubtotal = raw;
      } else if (lower.contains('kurswert') || lower.contains('market value')) {
        marketValue = raw.abs();
      } else if (lower.contains('stückzins')) {
        accrued += eur;
      } else if (lower.contains('steuer') || lower.contains('solidarit')) {
        tax -= eur;
      } else {
        fee -= eur;
      }
    }

    return _Billing(
      fee: fee,
      tax: tax,
      accrued: accrued,
      marketValue: marketValue,
      eurSubtotal: eurSubtotal,
      fx: fx,
    );
  }
}
