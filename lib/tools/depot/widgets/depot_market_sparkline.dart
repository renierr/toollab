import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/sparkline.dart';

import '../models/market_quote.dart';

class DepotMarketSparkline extends StatefulWidget {
  final String symbol;
  final String currency;
  final List<MarketPricePoint> points;

  const DepotMarketSparkline({
    super.key,
    required this.symbol,
    required this.currency,
    required this.points,
  });

  @override
  State<DepotMarketSparkline> createState() => _DepotMarketSparklineState();
}

class _DepotMarketSparklineState extends State<DepotMarketSparkline> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = marketPointsInLast24Hours(widget.points, DateTime.now());
    if (points.length < 2) return const SizedBox.shrink();
    final change = points.last.close - points.first.close;
    final color = change > 0
        ? AppTheme.statusGreen
        : change < 0
        ? AppTheme.statusRed
        : Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Tooltip(
        message: AppLocalizations.of(
          context,
        ).depotHoldingDayTrend(widget.symbol, widget.currency),
        child: SizedBox(
          width: 64,
          height: 30,
          child: Sparkline(
            values: [for (final point in points) point.close],
            color: color,
            strokeWidth: 1.5,
          ),
        ),
      ),
    );
  }
}
