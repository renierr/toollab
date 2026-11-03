import 'package:flutter/material.dart';

import '../models/market_quote.dart';
import 'depot_market_sparkline.dart';

class DepotMarketSparklineStrip extends StatelessWidget {
  final String symbol;
  final String currency;
  final List<MarketPricePoint>? points;

  const DepotMarketSparklineStrip({
    super.key,
    required this.symbol,
    required this.currency,
    this.points,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    height: 24,
    child: points == null || points!.length < 2
        ? null
        : DepotMarketSparkline(
            symbol: symbol,
            currency: currency,
            points: points!,
            width: 148,
            prominent: true,
          ),
  );
}
