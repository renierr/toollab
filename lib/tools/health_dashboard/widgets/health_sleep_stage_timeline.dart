import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class HealthSleepStageTimeline extends StatefulWidget {
  final List<Map<String, dynamic>> stages;
  final int startTime;
  final int endTime;
  final List<Map<String, dynamic>> heartRateSamples;

  const HealthSleepStageTimeline({
    super.key,
    required this.stages,
    required this.startTime,
    required this.endTime,
    required this.heartRateSamples,
  });

  @override
  State<HealthSleepStageTimeline> createState() =>
      _HealthSleepStageTimelineState();
}

class _HealthSleepStageTimelineState extends State<HealthSleepStageTimeline> {
  double? _markerX;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      return SizedBox(
        height: 170,
        child: MouseRegion(
          onHover: (event) => setState(() => _markerX = event.localPosition.dx),
          onExit: (_) => setState(() => _markerX = null),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                setState(() => _markerX = details.localPosition.dx),
            onHorizontalDragUpdate: (details) =>
                setState(() => _markerX = details.localPosition.dx),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SleepStageTimelinePainter(
                      stages: widget.stages,
                      startTime: widget.startTime,
                      endTime: widget.endTime,
                      heartRateSamples: widget.heartRateSamples,
                      labelColor: Theme.of(context).hintColor,
                      markerX: _markerX,
                    ),
                  ),
                ),
                if (_markerX != null)
                  Positioned(
                    left: (_markerX! - 48).clamp(0.0, width - 96),
                    top: 0,
                    child: _TimelineTooltip(
                      time: _markerTime(width),
                      heartRate: _nearestHeartRate(width),
                      stage: _stageAtMarker(width),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  String _markerTime(double width) {
    final ratio = (_markerX! / width).clamp(0.0, 1.0);
    final timestamp =
        widget.startTime +
        ((widget.endTime - widget.startTime) * ratio).round();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  int? _nearestHeartRate(double width) {
    if (widget.heartRateSamples.isEmpty) return null;
    final ratio = (_markerX! / width).clamp(0.0, 1.0);
    final timestamp =
        widget.startTime +
        ((widget.endTime - widget.startTime) * ratio).round();
    final sample = widget.heartRateSamples.reduce((closest, candidate) {
      final closestTime = (closest['time'] as num?)?.toInt() ?? 0;
      final candidateTime = (candidate['time'] as num?)?.toInt() ?? 0;
      return (candidateTime - timestamp).abs() < (closestTime - timestamp).abs()
          ? candidate
          : closest;
    });
    return (sample['bpm'] as num?)?.round();
  }

  String? _stageAtMarker(double width) {
    final ratio = (_markerX! / width).clamp(0.0, 1.0);
    final timestamp =
        widget.startTime +
        ((widget.endTime - widget.startTime) * ratio).round();
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

class _TimelineTooltip extends StatelessWidget {
  final String time;
  final int? heartRate;
  final String? stage;

  const _TimelineTooltip({
    required this.time,
    required this.heartRate,
    required this.stage,
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
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              heartRate == null ? time : '$time · $heartRate bpm',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (stageLabel != null) ...[
              const SizedBox(width: 5),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _stageColor(stage!),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 3),
              Text(stageLabel, style: Theme.of(context).textTheme.labelSmall),
            ],
          ],
        ),
      ),
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

class _SleepStageTimelinePainter extends CustomPainter {
  final List<Map<String, dynamic>> stages;
  final int startTime;
  final int endTime;
  final List<Map<String, dynamic>> heartRateSamples;
  final Color labelColor;
  final double? markerX;

  const _SleepStageTimelinePainter({
    required this.stages,
    required this.startTime,
    required this.endTime,
    required this.heartRateSamples,
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
          Rect.fromLTWH(x, 48, width, 28),
          const Radius.circular(5),
        ),
        Paint()..color = _color(type),
      );
    }
    _drawHeartRate(canvas, size, duration);
    _drawStageLanes(canvas, size, duration);
    if (markerX != null) {
      canvas.drawLine(
        Offset(markerX!.clamp(0.0, size.width), 18),
        Offset(markerX!.clamp(0.0, size.width), 146),
        Paint()
          ..color = labelColor
          ..strokeWidth = 1,
      );
    }
    _label(canvas, _time(startTime), const Offset(0, 148));
    _label(canvas, _time(endTime), Offset(size.width, 148), alignRight: true);
  }

  void _drawStageLanes(Canvas canvas, Size size, int duration) {
    const types = ['awake', 'rem', 'light', 'deep'];
    for (var index = 0; index < types.length; index++) {
      final type = types[index];
      final top = 88.0 + index * 14;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, top, size.width, 10),
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
            Rect.fromLTWH(x, top, width, 10),
            const Radius.circular(3),
          ),
          Paint()..color = _color(type),
        );
      }
    }
  }

  void _drawHeartRate(Canvas canvas, Size size, int duration) {
    if (heartRateSamples.length < 2) return;
    final values = heartRateSamples
        .map((sample) => (sample['bpm'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    if (values.length < 2) return;
    final minBpm = values.reduce((a, b) => a < b ? a : b);
    final maxBpm = values.reduce((a, b) => a > b ? a : b);
    final range = (maxBpm - minBpm).clamp(5, double.infinity);
    final path = Path();
    Offset? previous;
    for (final sample in heartRateSamples) {
      final time = (sample['time'] as num?)?.toInt();
      final bpm = (sample['bpm'] as num?)?.toDouble();
      if (time == null || bpm == null) continue;
      final x = ((time - startTime) / duration).clamp(0.0, 1.0) * size.width;
      final y = 38 - ((bpm - minBpm) / range).clamp(0.0, 1.0) * 30;
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
        ..color = Colors.redAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  Color _color(String type) => _stageColor(type);

  String _time(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _label(
    Canvas canvas,
    String text,
    Offset offset, {
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(alignRight ? offset.dx - painter.width : offset.dx, offset.dy),
    );
  }

  @override
  bool shouldRepaint(_SleepStageTimelinePainter oldDelegate) =>
      oldDelegate.stages != stages ||
      oldDelegate.heartRateSamples != heartRateSamples ||
      oldDelegate.startTime != startTime ||
      oldDelegate.endTime != endTime ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.markerX != markerX;
}
