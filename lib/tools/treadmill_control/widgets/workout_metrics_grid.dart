import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../treadmill_control_state.dart';
import '../treadmill_control_colors.dart';
import '../treadmill_session.dart';
import '../../../../l10n/app_localizations.dart';
import 'heart_rate_chart_dialog.dart';

class WorkoutMetricsGrid extends StatelessWidget {
  final bool isLandscape;

  const WorkoutMetricsGrid({super.key, required this.isLandscape});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TreadmillControlState>();
    final l10n = AppLocalizations.of(context);

    final String speedStr = state.speed.toStringAsFixed(1);
    final String inclineStr = state.incline.toStringAsFixed(1);
    final String hrStr = state.heartRate > 0 ? '${state.heartRate}' : '--';

    final int hours = state.elapsedTime ~/ 3600;
    final int minutes = (state.elapsedTime % 3600) ~/ 60;
    final int seconds = state.elapsedTime % 60;
    final String durationStr =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final String distanceStr = state.distance.toStringAsFixed(2);
    final String caloriesStr = '${state.calories}';

    final rollingLimit = DateTime.now().subtract(const Duration(minutes: 5));
    final rollingHistory = state.hrmHistory
        .where((p) => p.timestamp.isAfter(rollingLimit))
        .toList();

    final lastTime = state.dataPoints.isEmpty
        ? 0
        : state.dataPoints.last.timestamp;
    final recentSpeedPoints = state.dataPoints
        .where((p) => p.timestamp >= lastTime - 300)
        .toList();

    final speedCard = _MetricCard(
      label: l10n.speedLabel,
      value: speedStr,
      unit: 'km/h',
      color: TreadmillColors.cyanMetric,
      icon: Icons.speed,
      isLarge: true,
      backgroundPainter: recentSpeedPoints.length >= 2
          ? SpeedChartPainter(
              points: recentSpeedPoints,
              lineColor: TreadmillColors.cyanMetric,
            )
          : null,
    );

    final hrCard = _MetricCard(
      label: l10n.hrLabel,
      value: hrStr,
      unit: 'bpm',
      color: TreadmillColors.redMetric,
      icon: Icons.favorite,
      isLarge: true,
      pulse:
          state.heartRate > 0 && state.workoutStatus == WorkoutStatus.running,
      backgroundPainter: rollingHistory.length >= 2
          ? HeartRateChartPainter(
              history: rollingHistory,
              lineColor: TreadmillColors.redMetric,
            )
          : null,
      onTap: state.hrmHistory.isNotEmpty
          ? () {
              showDialog(
                context: context,
                builder: (context) => const HeartRateChartDialog(),
              );
            }
          : null,
    );

    final inclineCard = _MetricCard(
      label: l10n.inclineLabel,
      value: inclineStr,
      unit: '%',
      color: Colors.orange,
      icon: Icons.trending_up,
    );

    final timeCard = _MetricCard(
      label: l10n.elapsedTime,
      value: durationStr,
      unit: '',
      color: TreadmillColors.amberMetric,
      icon: Icons.timer,
    );

    final distanceCard = _MetricCard(
      label: l10n.distance,
      value: distanceStr,
      unit: 'km',
      color: Colors.green,
      icon: Icons.map,
    );

    final caloriesCard = _MetricCard(
      label: l10n.calories,
      value: caloriesStr,
      unit: 'kcal',
      color: TreadmillColors.greenMetric,
      icon: Icons.local_fire_department,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool narrow = constraints.maxWidth < 360;

        if (isLandscape) {
          final int crossCount = narrow ? 1 : 2;
          final double ratio = narrow ? 4.5 : 2.5;
          return GridView.count(
            crossAxisCount: crossCount,
            childAspectRatio: ratio,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              speedCard,
              hrCard,
              inclineCard,
              timeCard,
              distanceCard,
              caloriesCard,
            ],
          );
        } else {
          if (narrow) {
            return Column(
              children: [
                speedCard,
                const SizedBox(height: 8),
                hrCard,
                const SizedBox(height: 8),
                inclineCard,
                const SizedBox(height: 8),
                timeCard,
                const SizedBox(height: 8),
                distanceCard,
                const SizedBox(height: 8),
                caloriesCard,
              ],
            );
          } else {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: speedCard),
                    const SizedBox(width: 8),
                    Expanded(child: hrCard),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [inclineCard, timeCard, distanceCard, caloriesCard],
                ),
              ],
            );
          }
        }
      },
    );
  }
}

class _MetricCard extends StatefulWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;
  final bool isLarge;
  final bool pulse;
  final CustomPainter? backgroundPainter;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
    this.isLarge = false,
    this.pulse = false,
    this.backgroundPainter,
    this.onTap,
  });

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.pulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _MetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.pulse && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget cardContent = Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.color.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          if (widget.backgroundPainter != null)
            Positioned.fill(
              child: CustomPaint(painter: widget.backgroundPainter),
            ),
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.15);
                  return Transform.scale(
                    scale: widget.pulse ? scale : 1.0,
                    child: Icon(
                      widget.icon,
                      color: widget.color,
                      size: widget.isLarge ? 28 : 22,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                        fontSize: widget.isLarge ? 12 : 10,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            widget.value,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: widget.isLarge ? 24 : 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.unit.isNotEmpty) ...[
                          const SizedBox(width: 2),
                          Text(
                            widget.unit,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: widget.isLarge ? 12 : 9,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

class SpeedChartPainter extends CustomPainter {
  final List<WorkoutDataPoint> points;
  final Color lineColor;

  SpeedChartPainter({required this.points, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final List<double> smoothedSpeeds = [];
    const int windowSize = 3;
    for (int i = 0; i < points.length; i++) {
      double sum = 0;
      int count = 0;
      for (int w = i - windowSize ~/ 2; w <= i + windowSize ~/ 2; w++) {
        if (w >= 0 && w < points.length) {
          sum += points[w].speed;
          count++;
        }
      }
      smoothedSpeeds.add(sum / count);
    }

    double minSpd = smoothedSpeeds.reduce((a, b) => a < b ? a : b);
    double maxSpd = smoothedSpeeds.reduce((a, b) => a > b ? a : b);

    if (maxSpd == minSpd) {
      maxSpd += 2;
      minSpd = max(0.0, minSpd - 2);
    }
    final double range = maxSpd - minSpd;

    final path = Path();
    final List<Offset> pts = [];
    final double stepX = size.width / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final double x = i * stepX;
      final double normalizedY = (smoothedSpeeds[i] - minSpd) / range;
      final double y = size.height - (normalizedY * (size.height - 8) + 4);
      pts.add(Offset(x, y));
    }

    path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
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
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.15),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant SpeedChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class HeartRateChartPainter extends CustomPainter {
  final List<HeartRateHistoryPoint> history;
  final Color lineColor;

  HeartRateChartPainter({required this.history, required this.lineColor});

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

    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    double minHr = smoothedHrs.reduce((a, b) => a < b ? a : b);
    double maxHr = smoothedHrs.reduce((a, b) => a > b ? a : b);

    if (maxHr == minHr) {
      maxHr += 10;
      minHr -= 10;
    }
    final double hrRange = maxHr - minHr;

    final path = Path();
    final List<Offset> points = [];
    final double stepX = size.width / (history.length - 1);

    for (int i = 0; i < history.length; i++) {
      final double x = i * stepX;
      final double normalizedY = (smoothedHrs[i] - minHr) / hrRange;
      final double y = size.height - (normalizedY * (size.height - 8) + 4);
      points.add(Offset(x, y));
    }

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
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.15),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HeartRateChartPainter oldDelegate) {
    return oldDelegate.history != history;
  }
}
