import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'health_chart_tooltip.dart';
import 'health_session_overlay.dart';

export 'health_session_overlay.dart';

/// Curves over a session's span, with the sleep stage bar when there are stages.
///
/// A workout has no stages, so it uses the same widget with [stages] empty: the
/// stage bar and its lanes then collapse and only the curves remain.
class HealthSessionTimeline extends StatefulWidget {
  final int startTime;
  final int endTime;
  final List<Map<String, dynamic>> stages;

  /// Already filtered to what the legend has switched on.
  final List<HealthSessionOverlay> overlays;

  const HealthSessionTimeline({
    super.key,
    required this.startTime,
    required this.endTime,
    this.stages = const [],
    this.overlays = const [],
  });

  @override
  State<HealthSessionTimeline> createState() => _HealthSessionTimelineState();
}

class _HealthSessionTimelineState extends State<HealthSessionTimeline> {
  double? _markerX;

  List<HealthSessionOverlay> get _drawable =>
      widget.overlays.where((overlay) => overlay.isDrawable).toList();

  @override
  Widget build(BuildContext context) {
    final overlays = _drawable;
    final layout = _TimelineLayout(overlays.length, widget.stages.isNotEmpty);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: layout.height,
          child: MouseRegion(
            onHover: (event) =>
                setState(() => _markerX = event.localPosition.dx),
            onExit: (_) => setState(() => _markerX = null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  setState(() => _markerX = details.localPosition.dx),
              onHorizontalDragUpdate: (details) =>
                  setState(() => _markerX = details.localPosition.dx),
              // A touch has no hover to leave by, so the marker goes when the
              // finger does - otherwise the tooltip sits over the curves for the
              // rest of the visit. A mouse restores it on the next move.
              onTapUp: (_) => setState(() => _markerX = null),
              onTapCancel: () => setState(() => _markerX = null),
              onHorizontalDragEnd: (_) => setState(() => _markerX = null),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SessionTimelinePainter(
                        stages: widget.stages,
                        startTime: widget.startTime,
                        endTime: widget.endTime,
                        overlays: overlays,
                        layout: layout,
                        labelColor: Theme.of(context).hintColor,
                        markerX: _markerX,
                      ),
                    ),
                  ),
                  if (_markerX != null)
                    Positioned(
                      left: (_markerX! - 60).clamp(0.0, (width - 120).abs()),
                      top: 0,
                      child: _TimelineTooltip(
                        time: _formatTime(_timeAt(width)),
                        stage: _stageAtMarker(width),
                        readings: [
                          for (final overlay in overlays)
                            if (_nearest(overlay, _timeAt(width))
                                case final value?)
                              (
                                color: overlay.color,
                                text: _formatValue(value, overlay.unit),
                              ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _timeAt(double width) {
    final ratio = width <= 0 ? 0.0 : (_markerX! / width).clamp(0.0, 1.0);
    return widget.startTime +
        ((widget.endTime - widget.startTime) * ratio).round();
  }

  static double? _nearest(HealthSessionOverlay overlay, int timestamp) {
    if (overlay.samples.isEmpty) return null;
    final sample = overlay.samples.reduce(
      (closest, candidate) =>
          (candidate.t - timestamp).abs() < (closest.t - timestamp).abs()
          ? candidate
          : closest,
    );
    return sample.v;
  }

  String? _stageAtMarker(double width) {
    final timestamp = _timeAt(width);
    for (final stage in widget.stages) {
      final start = (stage['startTime'] as num?)?.toInt() ?? widget.startTime;
      final end = (stage['endTime'] as num?)?.toInt() ?? start;
      if (timestamp >= start && timestamp <= end) {
        return stage['type'] as String?;
      }
    }
    return null;
  }
}

/// Vertical bands, so the widget and the painter agree on where things sit.
class _TimelineLayout {
  final int overlayCount;
  final bool hasStages;

  const _TimelineLayout(this.overlayCount, this.hasStages);

  static const _top = 22.0;

  // One overlay lane is a range label, then the curve, then clear space. The
  // trailing gap is what keeps a curve's low point off whatever sits below it:
  // without it the baseline landed exactly on the stage bar's top edge, which is
  // why the line looked glued to the bar however tall the lane was.
  static const _overlayLabel = 15.0;
  static const _overlayCurve = 40.0;
  static const _overlayGap = 14.0;
  static const _overlayLane = _overlayLabel + _overlayCurve + _overlayGap;
  static const _bar = 28.0;
  static const _barGap = 14.0;
  static const _stageLane = 10.0;
  static const _stageGap = 4.0;
  static const _footer = 20.0;

  double get overlaysTop => _top;
  double get barTop => _top + overlayCount * _overlayLane;
  double get lanesTop => barTop + (hasStages ? _bar + _barGap : 0);
  double get lanesBottom =>
      lanesTop + (hasStages ? 4 * (_stageLane + _stageGap) : 0);
  double get height => lanesBottom + _footer;

  /// Zero line of a curve - the bottom of its band, above the trailing gap.
  double overlayBase(int index) =>
      _top + index * _overlayLane + _overlayLabel + _overlayCurve;
  double overlayLabelTop(int index) => _top + index * _overlayLane;
  double get overlayCurveHeight => _overlayCurve;
  double get barHeight => _bar;
  double get stageLaneHeight => _stageLane;
  double get stageLaneStride => _stageLane + _stageGap;
}

String _formatTime(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

/// Percent-style units read badly with decimals at this size; rates do not.
String _formatValue(double value, String unit) =>
    '${value.round()} $unit'.trimRight();

class _TimelineTooltip extends StatelessWidget {
  final String time;
  final String? stage;
  final List<HealthChartReading> readings;

  const _TimelineTooltip({
    required this.time,
    required this.stage,
    required this.readings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stageLabel = switch (stage) {
      'awake' => l10n.healthDashboardSleepAwake,
      'rem' => l10n.healthDashboardSleepRem,
      'light' => l10n.healthDashboardSleepLight,
      'deep' => l10n.healthDashboardSleepDeep,
      _ => null,
    };
    return HealthChartTooltip(
      title: time,
      titleTag: stageLabel == null
          ? null
          : (color: _stageColor(stage!), text: stageLabel),
      readings: readings,
    );
  }
}

Color _stageColor(String type) => switch (type) {
  'awake' => Colors.amber,
  'rem' => Colors.purple,
  'light' => Colors.lightBlue,
  'deep' => Colors.indigo,
  _ => Colors.blueGrey,
};

class _SessionTimelinePainter extends CustomPainter {
  final List<Map<String, dynamic>> stages;
  final int startTime;
  final int endTime;
  final List<HealthSessionOverlay> overlays;
  final _TimelineLayout layout;
  final Color labelColor;
  final double? markerX;

  const _SessionTimelinePainter({
    required this.stages,
    required this.startTime,
    required this.endTime,
    required this.overlays,
    required this.layout,
    required this.labelColor,
    this.markerX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final duration = endTime - startTime;
    if (duration <= 0) return;
    for (final stage in stages) {
      final start = (stage['startTime'] as num?)?.toInt() ?? startTime;
      final end = (stage['endTime'] as num?)?.toInt() ?? start;
      final type = stage['type'] as String? ?? '';
      final x = ((start - startTime) / duration).clamp(0.0, 1.0) * size.width;
      final width = ((end - start) / duration).clamp(0.0, 1.0) * size.width;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, layout.barTop, width, layout.barHeight),
          const Radius.circular(5),
        ),
        Paint()..color = _stageColor(type),
      );
    }
    for (var index = 0; index < overlays.length; index++) {
      _drawOverlay(canvas, size, duration, overlays[index], index);
    }
    _drawStageLanes(canvas, size, duration);
    if (markerX != null) {
      canvas.drawLine(
        Offset(markerX!.clamp(0.0, size.width), layout.overlaysTop),
        Offset(markerX!.clamp(0.0, size.width), layout.lanesBottom),
        Paint()
          ..color = labelColor
          ..strokeWidth = 1,
      );
    }
    _label(canvas, _formatTime(startTime), Offset(0, layout.lanesBottom + 2));
    _label(
      canvas,
      _formatTime(endTime),
      Offset(size.width, layout.lanesBottom + 2),
      alignRight: true,
    );
  }

  void _drawStageLanes(Canvas canvas, Size size, int duration) {
    if (stages.isEmpty) return;
    const types = ['awake', 'rem', 'light', 'deep'];
    for (var index = 0; index < types.length; index++) {
      final type = types[index];
      final top = layout.lanesTop + index * layout.stageLaneStride;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, top, size.width, layout.stageLaneHeight),
          const Radius.circular(3),
        ),
        Paint()..color = labelColor.withValues(alpha: 0.16),
      );
      for (final stage in stages) {
        if (stage['type'] != type) continue;
        final start = (stage['startTime'] as num?)?.toInt() ?? startTime;
        final end = (stage['endTime'] as num?)?.toInt() ?? start;
        final x = ((start - startTime) / duration).clamp(0.0, 1.0) * size.width;
        final width = ((end - start) / duration).clamp(0.0, 1.0) * size.width;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, top, width, layout.stageLaneHeight),
            const Radius.circular(3),
          ),
          Paint()..color = _stageColor(type),
        );
      }
    }
  }

  /// The curve plus the numbers behind it: without the range printed, a line
  /// scaled to its own minimum and maximum says nothing about the values.
  void _drawOverlay(
    Canvas canvas,
    Size size,
    int duration,
    HealthSessionOverlay overlay,
    int index,
  ) {
    final values = [for (final sample in overlay.samples) sample.v];
    if (values.length < 2) return;
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final range = (hi - lo).clamp(1.0, double.infinity);
    final base = layout.overlayBase(index);
    final height = layout.overlayCurveHeight;

    final path = Path();
    Offset? previous;
    for (final sample in overlay.samples) {
      final x =
          ((sample.t - startTime) / duration).clamp(0.0, 1.0) * size.width;
      final y = base - ((sample.v - lo) / range).clamp(0.0, 1.0) * height;
      final point = Offset(x, y);
      if (previous == null) {
        path.moveTo(point.dx, point.dy);
      } else {
        final controlX = (previous.dx + point.dx) / 2;
        path.cubicTo(
          controlX,
          previous.dy,
          controlX,
          point.dy,
          point.dx,
          point.dy,
        );
      }
      previous = point;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = overlay.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    _label(
      canvas,
      '${overlay.label}  ${lo.round()}–${hi.round()} ${overlay.unit}'
          .trimRight(),
      Offset(0, layout.overlayLabelTop(index)),
      color: overlay.color,
      size: 10,
    );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset offset, {
    bool alignRight = false,
    Color? color,
    double size = 11,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color ?? labelColor, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(alignRight ? offset.dx - painter.width : offset.dx, offset.dy),
    );
  }

  @override
  bool shouldRepaint(_SessionTimelinePainter oldDelegate) =>
      oldDelegate.stages != stages ||
      oldDelegate.overlays != overlays ||
      oldDelegate.startTime != startTime ||
      oldDelegate.endTime != endTime ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.markerX != markerX;
}
