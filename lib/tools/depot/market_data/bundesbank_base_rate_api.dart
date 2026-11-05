import 'dart:async';
import 'dart:math' as math;

import 'package:tool_lab/services/app_http_client.dart';

typedef BundesbankBaseRate = ({DateTime date, double rate});

/// The base rate of the advance lump sum (§ 203 BewG), worked out from the
/// Bundesbank's yield curve the way the BMF announces it: the par yield of a
/// 15-year federal bond with annual coupons on the year's first trading day.
class BundesbankBaseRateApi {
  BundesbankBaseRateApi._();

  // Svensson zero rates of listed federal securities, every maturity.
  static final Uri _series = Uri.parse(
    'https://api.statistiken.bundesbank.de/rest/data/BBSIS/'
    'D.I.ZST.ZI.EUR.S1311.B.A604..R.A.A._Z._Z.A',
  );
  static const _timeout = Duration(seconds: 20);

  /// Null while the Bundesbank has no curve for [year] yet.
  static Future<BundesbankBaseRate?> fetch(int year) async {
    final client = await AppHttpClient.client;
    final res = await client
        .get(
          _series.replace(
            queryParameters: {
              'startPeriod': '$year-01-01',
              'endPeriod': '$year-01-15',
            },
          ),
          headers: const {
            'Accept': 'application/vnd.sdmx.data+csv;version=1.0.0',
          },
        )
        .timeout(_timeout);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw StateError('Bundesbank: HTTP ${res.statusCode}');
    }
    return parse(res.body);
  }

  /// Rate of the earliest day with the whole curve up to 15 years, rounded
  /// to two decimals of a percent like the BMF figure.
  static BundesbankBaseRate? parse(String csv) {
    final lines = csv.split(RegExp(r'\r?\n')).where((l) => l.contains(';'));
    if (lines.isEmpty) throw const FormatException('Bundesbank: no CSV');
    final header = lines.first.replaceFirst('﻿', '').split(';');
    final maturityAt = header.indexOf('BBK_SEIS_MATURITY');
    final dateAt = header.indexOf('TIME_PERIOD');
    final valueAt = header.indexOf('OBS_VALUE');
    if (maturityAt < 0 || dateAt < 0 || valueAt < 0) {
      throw const FormatException('Bundesbank: unexpected columns');
    }

    final curves = <DateTime, Map<int, double>>{};
    final maturity = RegExp(r'^R(\d\d)XX$');
    for (final line in lines.skip(1)) {
      final cells = line.split(';');
      if (cells.length <= math.max(maturityAt, math.max(dateAt, valueAt))) {
        continue;
      }
      final years = maturity.firstMatch(cells[maturityAt])?.group(1);
      final date = DateTime.tryParse(cells[dateAt]);
      final value = double.tryParse(cells[valueAt]);
      if (years == null || date == null || value == null) continue;
      curves.putIfAbsent(date, () => {})[int.parse(years)] = value / 100;
    }

    final days = curves.keys.toList()..sort();
    for (final day in days) {
      final curve = curves[day]!;
      if (![for (var t = 1; t <= 15; t++) t].every(curve.containsKey)) {
        continue;
      }
      var discounts = 0.0;
      var last = 0.0;
      for (var t = 1; t <= 15; t++) {
        last = math.pow(1 + curve[t]!, -t).toDouble();
        discounts += last;
      }
      final par = (1 - last) / discounts;
      return (date: day, rate: (par * 10000).round() / 10000);
    }
    return null;
  }
}
