import 'package:flutter/material.dart';

import '../sleep_session_data.dart';
import 'sf_sleep_timeline.dart';

/// Start and end markers laid over [SfSleepTimeline]; a tap or drag moves the
/// nearer marker, and the part outside them is shaded as cut.
class SfSleepTrimMarkers extends StatefulWidget {
  const SfSleepTrimMarkers({
    super.key,
    required this.data,
    required this.from,
    required this.to,
    required this.onChanged,
  });

  final SleepSessionData data;
  final DateTime from;
  final DateTime to;
  final void Function(DateTime from, DateTime to) onChanged;

  @override
  State<SfSleepTrimMarkers> createState() => _SfSleepTrimMarkersState();
}

class _SfSleepTrimMarkersState extends State<SfSleepTrimMarkers> {
  bool _draggingStart = true;

  double _x(DateTime t, double width) {
    const left = SfSleepTimeline.plotLeft;
    final total = SfSleepTimeline.plotSpanMs(widget.data);
    final frac = t.difference(widget.data.startedAt).inMilliseconds / total;
    return left + frac.clamp(0.0, 1.0) * (width - left);
  }

  DateTime _time(double dx, double width) {
    const left = SfSleepTimeline.plotLeft;
    final total = SfSleepTimeline.plotSpanMs(widget.data);
    final frac = ((dx - left) / (width - left)).clamp(0.0, 1.0);
    return widget.data.startedAt.add(
      Duration(seconds: (frac * total / 1000).round()),
    );
  }

  void _grab(double dx, double width) {
    _draggingStart =
        (dx - _x(widget.from, width)).abs() <=
        (dx - _x(widget.to, width)).abs();
    _move(dx, width);
  }

  void _move(double dx, double width) {
    final t = _time(dx, width);
    if (_draggingStart) {
      widget.onChanged(t, widget.to);
    } else {
      widget.onChanged(widget.from, t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _grab(d.localPosition.dx, width),
          onHorizontalDragStart: (d) => _grab(d.localPosition.dx, width),
          onHorizontalDragUpdate: (d) => _move(d.localPosition.dx, width),
          child: CustomPaint(
            size: Size(width, constraints.maxHeight),
            painter: _MarkersPainter(
              startX: _x(widget.from, width),
              endX: _x(widget.to, width),
              cutColor: scheme.error,
              markerColor: scheme.primary,
              gripColor: scheme.onPrimary,
            ),
          ),
        );
      },
    );
  }
}

class _MarkersPainter extends CustomPainter {
  _MarkersPainter({
    required this.startX,
    required this.endX,
    required this.cutColor,
    required this.markerColor,
    required this.gripColor,
  });

  final double startX;
  final double endX;
  final Color cutColor;
  final Color markerColor;
  final Color gripColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = SfSleepTimeline.plotLeft;
    final plotH = size.height - SfSleepTimeline.plotBottomPad;
    final shade = Paint()..color = cutColor.withValues(alpha: 0.22);
    canvas.drawRect(Rect.fromLTRB(left, 0, startX, plotH), shade);
    canvas.drawRect(Rect.fromLTRB(endX, 0, size.width, plotH), shade);

    final line = Paint()
      ..color = markerColor
      ..strokeWidth = 2;
    final grip = Paint()
      ..color = gripColor
      ..strokeWidth = 1.2;
    for (final x in [startX, endX]) {
      canvas.drawLine(Offset(x, 0), Offset(x, plotH), line);
      final handle = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, plotH / 2), width: 12, height: 28),
        const Radius.circular(4),
      );
      canvas.drawRRect(handle, line);
      for (final dy in [-5.0, 0.0, 5.0]) {
        canvas.drawLine(
          Offset(x - 3, plotH / 2 + dy),
          Offset(x + 3, plotH / 2 + dy),
          grip,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MarkersPainter old) =>
      old.startX != startX ||
      old.endX != endX ||
      old.cutColor != cutColor ||
      old.markerColor != markerColor ||
      old.gripColor != gripColor;
}
