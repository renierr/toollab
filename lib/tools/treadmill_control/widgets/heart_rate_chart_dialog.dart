import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../treadmill_control_state.dart';
import '../../../../widgets/responsive_alert_dialog.dart';

class HeartRateChartDialog extends StatelessWidget {
  const HeartRateChartDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = context.watch<TreadmillControlState>();
    final history = state.hrmHistory;

    if (history.isEmpty) {
      return const ResponsiveAlertDialog(
        title: Text('Heart Rate History'),
        content: Text('No heart rate data recorded yet.'),
      );
    }

    final limit = DateTime.now().subtract(const Duration(minutes: 5));
    final rollingHistory = history
        .where((p) => p.timestamp.isAfter(limit))
        .toList();

    final current = history.last.heartRate;
    final minVal = history.map((p) => p.heartRate).reduce(min);
    final maxVal = history.map((p) => p.heartRate).reduce(max);
    final avgVal =
        history.map((p) => p.heartRate).reduce((a, b) => a + b) /
        history.length;

    final totalDuration = history.last.timestamp.difference(
      history.first.timestamp,
    );
    String durationStr = '';
    if (totalDuration.inHours > 0) {
      durationStr += '${totalDuration.inHours}h ';
    }
    if (totalDuration.inMinutes > 0 || totalDuration.inHours > 0) {
      durationStr += '${totalDuration.inMinutes % 60}m ';
    }
    durationStr += '${totalDuration.inSeconds % 60}s';

    return ResponsiveAlertDialog(
      title: const Text('Heart Rate History'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stats (Overall Session)
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _StatItem(
                  label: 'Current',
                  value: '$current bpm',
                  color: Colors.red,
                ),
                _StatItem(
                  label: 'Average',
                  value: '${avgVal.round()} bpm',
                  color: Colors.blue,
                ),
                _StatItem(
                  label: 'Max',
                  value: '$maxVal bpm',
                  color: Colors.orange,
                ),
                _StatItem(
                  label: 'Min',
                  value: '$minVal bpm',
                  color: Colors.green,
                ),
                _StatItem(
                  label: 'Duration',
                  value: durationStr,
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // The Detailed Graph (Rolling 5m Window)
            Container(
              height: 220,
              padding: const EdgeInsets.only(right: 8, top: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark ? Colors.white24 : Colors.black12),
                ),
              ),
              child: rollingHistory.length < 2
                  ? const Center(
                      child: Text(
                        'Accumulating data for chart...',
                        style: TextStyle(fontSize: 12),
                      ),
                    )
                  : CustomPaint(
                      painter: DetailedHeartRateChartPainter(
                        history: rollingHistory,
                        lineColor: Colors.red,
                        isDark: isDark,
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class DetailedHeartRateChartPainter extends CustomPainter {
  final List<HeartRateHistoryPoint> history;
  final Color lineColor;
  final bool isDark;

  DetailedHeartRateChartPainter({
    required this.history,
    required this.lineColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    // Apply moving average smoothing
    final List<double> smoothedHrs = [];
    const int windowSize = 5;
    for (int i = 0; i < history.length; i++) {
      double sum = 0;
      int count = 0;
      for (int w = i - windowSize ~/ 2; w <= i + windowSize ~/ 2; w++) {
        if (w >= 0 && w < history.length) {
          sum += history[w].heartRate;
          count++;
        }
      }
      smoothedHrs.add(sum / count);
    }

    double minHr = smoothedHrs.reduce((a, b) => a < b ? a : b);
    double maxHr = smoothedHrs.reduce((a, b) => a > b ? a : b);

    minHr = (minHr - 10).clamp(30.0, 220.0);
    maxHr = (maxHr + 10).clamp(40.0, 220.0);
    if (maxHr == minHr) {
      maxHr += 20;
      minHr -= 20;
    }
    final double hrRange = maxHr - minHr;

    const gridLines = 4;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i <= gridLines; i++) {
      final double fraction = i / gridLines;
      final double y = size.height - (fraction * (size.height - 24) + 12);
      final int hrVal = (minHr + fraction * hrRange).round();

      canvas.drawLine(Offset(40, y), Offset(size.width, y), gridPaint);

      textPainter.text = TextSpan(
        text: '$hrVal',
        style: TextStyle(
          color: (isDark ? Colors.white70 : Colors.black54),
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(8, y - 6));
    }

    final double stepX = (size.width - 40) / (history.length - 1);
    final List<Offset> points = [];

    for (int i = 0; i < history.length; i++) {
      final double x = 40 + i * stepX;
      final double normalizedY = (smoothedHrs[i] - minHr) / hrRange;
      final double y = size.height - (normalizedY * (size.height - 24) + 12);
      points.add(Offset(x, y));
    }

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(40, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(40, 0, size.width - 40, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    final lastPoint = points.last;
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    final dotOutlinePaint = Paint()
      ..color = isDark ? Colors.white : Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(lastPoint, 5.0, dotPaint);
    canvas.drawCircle(lastPoint, 5.0, dotOutlinePaint);
  }

  @override
  bool shouldRepaint(covariant DetailedHeartRateChartPainter oldDelegate) {
    return oldDelegate.history != history;
  }
}
