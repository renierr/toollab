import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../depot_format.dart';
import '../models/depot_wishlist.dart';

/// One year of closes as a bare line: no axes, no interaction.
class DepotWishlistChart extends StatelessWidget {
  final List<DepotWishlistPoint> points;
  final DepotFormat format;
  final Color color;
  final double height;

  const DepotWishlistChart({
    super.key,
    required this.points,
    required this.format,
    required this.color,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = [for (final point in points) point.close];
    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '—',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
      );
    }
    final high = values.reduce(math.max);
    final low = values.reduce(math.min);
    final date = DateFormat.MMMd(Localizations.localeOf(context).toString());
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.hintColor,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(format.axisMoney(high), style: labelStyle),
            Text(format.axisMoney(low), style: labelStyle),
          ],
        ),
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _WishlistChartPainter(
              values: values,
              color: color,
              gridColor: theme.dividerColor.withValues(alpha: 0.35),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(date.format(points.first.date), style: labelStyle),
            Text(date.format(points.last.date), style: labelStyle),
          ],
        ),
      ],
    );
  }
}

class _WishlistChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color gridColor;

  const _WishlistChartPainter({
    required this.values,
    required this.color,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;
    final high = values.reduce(math.max);
    final low = values.reduce(math.min);
    final span = high - low;
    final stepX = size.width / (values.length - 1);
    final scaleY = span == 0 ? 0.0 : size.height / span;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = stepX * i;
      final y = span == 0
          ? size.height / 2
          : size.height - (values[i] - low) * scaleY;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final fraction in [0.25, 0.5, 0.75]) {
      final y = size.height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_WishlistChartPainter old) =>
      !identical(old.values, values) ||
      old.color != color ||
      old.gridColor != gridColor;
}
