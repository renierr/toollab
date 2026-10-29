import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../models/depot_holding.dart';

const double _outerRadius = 0.44;
const double _strokeWidth = 0.16;
const double _popDistance = 0.045;

class DepotWeightDonut extends StatefulWidget {
  final List<DepotHolding> holdings;
  final DepotFormat format;

  const DepotWeightDonut({
    super.key,
    required this.holdings,
    required this.format,
  });

  @override
  State<DepotWeightDonut> createState() => _DepotWeightDonutState();
}

class _DepotWeightDonutState extends State<DepotWeightDonut> {
  ({String id, String portfolioId})? _selected;

  void _select(
    Offset position,
    double size,
    List<DepotHolding> holdings,
    double total,
  ) {
    final delta = position - Offset(size / 2, size / 2);
    var start = 0.0;
    for (final holding in holdings) {
      final sweep = 2 * math.pi * holding.currentValue / total;
      if (_selected == (id: holding.id, portfolioId: holding.portfolioId)) {
        final middle = start + sweep / 2 - math.pi / 2;
        final shifted =
            delta -
            Offset(math.cos(middle), math.sin(middle)) * (size * _popDistance);
        final angle = _angle(shifted);
        if (shifted.distance <= size * (_outerRadius + 0.012) &&
            shifted.distance >= size * (_outerRadius - _strokeWidth - 0.012) &&
            angle >= start &&
            angle < start + sweep) {
          return;
        }
        break;
      }
      start += sweep;
    }
    final distance = delta.distance;
    final radius = size * _outerRadius;
    if (distance > radius || distance < radius - size * _strokeWidth) {
      _clear();
      return;
    }
    final angle = _angle(delta);
    var end = 0.0;
    for (final holding in holdings) {
      end += 2 * math.pi * holding.currentValue / total;
      if (angle < end) {
        final key = (id: holding.id, portfolioId: holding.portfolioId);
        if (_selected != key) setState(() => _selected = key);
        return;
      }
    }
    _clear();
  }

  double _angle(Offset delta) =>
      (math.atan2(delta.dy, delta.dx) + math.pi / 2 + 2 * math.pi) %
      (2 * math.pi);

  void _clear() {
    if (_selected != null) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.holdings
        .where((h) => !h.isSold && h.currentValue > 0)
        .toList();
    final total = open.fold<double>(0, (sum, h) => sum + h.currentValue);
    if (total <= 0) return const SizedBox.shrink();
    DepotHolding? selected;
    for (final holding in open) {
      if (_selected == (id: holding.id, portfolioId: holding.portfolioId)) {
        selected = holding;
        break;
      }
    }
    final format = widget.format;
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) => MouseRegion(
              onHover: (event) => _select(
                event.localPosition,
                constraints.maxWidth,
                open,
                total,
              ),
              onExit: (_) => _clear(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _select(
                  details.localPosition,
                  constraints.maxWidth,
                  open,
                  total,
                ),
                child: CustomPaint(
                  painter: _WeightPainter(open, total, _selected),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(constraints.maxWidth * 0.2),
                      child: selected == null
                          ? FittedBox(child: Text(format.money(total)))
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  selected.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelMedium,
                                ),
                                FittedBox(
                                  child: Text(
                                    format.percent(
                                      selected.currentValue / total * 100,
                                      signed: false,
                                    ),
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                                FittedBox(
                                  child: Text(
                                    format.money(selected.currentValue),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeightPainter extends CustomPainter {
  final List<DepotHolding> holdings;
  final double total;
  final ({String id, String portfolioId})? selected;

  _WeightPainter(this.holdings, this.total, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.shortestSide;
    final stroke = width * _strokeWidth;
    final radius = width * _outerRadius - stroke / 2;
    final arc = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: radius,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    for (final selectedPass in [false, true]) {
      var start = -math.pi / 2;
      for (final (index, holding) in holdings.indexed) {
        final sweep = 2 * math.pi * holding.currentValue / total;
        final isSelected =
            selected == (id: holding.id, portfolioId: holding.portfolioId);
        if (isSelected == selectedPass) {
          final gap = holdings.length == 1
              ? 0.0
              : math.min(0.018, sweep * 0.25);
          final middle = start + sweep / 2;
          final shift = isSelected
              ? Offset(math.cos(middle), math.sin(middle)) *
                    (width * _popDistance)
              : Offset.zero;
          paint
            ..color = DepotColors.weight(index, holdings.length)
            ..strokeWidth = isSelected ? stroke * 1.08 : stroke;
          canvas.drawArc(
            arc.shift(shift),
            start + gap / 2,
            sweep - gap,
            false,
            paint,
          );
        }
        start += sweep;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeightPainter oldDelegate) =>
      oldDelegate.holdings != holdings ||
      oldDelegate.total != total ||
      oldDelegate.selected != selected;
}
