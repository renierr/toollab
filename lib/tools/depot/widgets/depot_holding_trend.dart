import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../depot_holding_trend_state.dart';
import '../models/depot_holding.dart';
import '../models/depot_holding_trend.dart';
import 'depot_market_sparkline.dart';

class DepotHoldingTrendView extends StatefulWidget {
  final DepotHolding holding;

  const DepotHoldingTrendView({super.key, required this.holding});

  @override
  State<DepotHoldingTrendView> createState() => _DepotHoldingTrendViewState();
}

class _DepotHoldingTrendViewState extends State<DepotHoldingTrendView> {
  ScrollPosition? _position;
  bool _scheduled = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted && _visible()) {
        context.read<DepotHoldingTrendState>().ensure(
          widget.holding,
          visible: _visible,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_schedule);
      _position = position;
      _position?.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void didUpdateWidget(covariant DepotHoldingTrendView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (DepotHoldingTrendState.keyOf(oldWidget.holding) !=
        DepotHoldingTrendState.keyOf(widget.holding)) {
      _schedule();
    }
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted && _visible()) {
        context.read<DepotHoldingTrendState>().ensure(
          widget.holding,
          visible: _visible,
        );
      }
    });
  }

  bool _visible() {
    if (!mounted) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final position = _position;
    if (position == null || !position.hasViewportDimension) {
      return position == null;
    }
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return false;
    final top = viewport.getOffsetToReveal(box, 0).offset;
    return top < position.pixels + position.viewportDimension &&
        top + (box.size.height > 0 ? box.size.height : 1) > position.pixels;
  }

  @override
  void dispose() {
    _position?.removeListener(_schedule);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trend = context.select<DepotHoldingTrendState, DepotHoldingTrend?>(
      (state) => state.trendFor(widget.holding),
    );
    if (trend == null) return const SizedBox.shrink();
    return DepotMarketSparkline(
      symbol: trend.symbol,
      currency: trend.currency,
      points: trend.points,
    );
  }
}
