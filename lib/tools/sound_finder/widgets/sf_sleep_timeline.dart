import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/sleep_stage_style.dart';

import '../audio/db_scale.dart';
import '../audio/sleep_chunk_analyzer.dart';
import '../sleep_labels.dart';
import '../sleep_player.dart';
import '../sleep_session_data.dart';
import '../sleep_session_store.dart';
import '../sleep_sessions_state.dart';
import '../sound_finder_colors.dart';

/// Night overview: one bar per chunk (height = peak dB, color = category).
/// Any tap or horizontal drag selects the nearest chunk, so even 2 px wide
/// bars are reachable by touch.
class SfSleepTimeline extends StatelessWidget {
  const SfSleepTimeline({super.key, required this.session});

  static const double _height = 170;
  static const double _leftPad = 34;

  final SleepSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.read<SleepSessionsState>();
    final data = session.data;
    final (_, health, selected) = context
        .select<
          SleepSessionsState,
          (Set<SleepSoundCategory?>, List<SleepStageBand>, int?)
        >(
          (s) => (
            s.filter(session.id),
            s.healthStages(session.id),
            s.selectedIndex(session.id),
          ),
        );
    final visible = state.visibleIndices(session);
    final player = context.read<SleepPlayer>();
    final playingHere = context.select<SleepPlayer, bool>(
      (p) => p.sessionId == session.id,
    );

    void pick(double dx, double width) {
      final index = _nearest(data, visible, dx, width);
      if (index != null) state.select(session, index);
    }

    final categories = {for (final e in data.events) e.analysis?.category};
    final stages = {for (final b in health) b.kind};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return MouseRegion(
                onHover: playingHere
                    ? null
                    : (e) => pick(e.localPosition.dx, width),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => pick(d.localPosition.dx, width),
                  onHorizontalDragStart: (d) => pick(d.localPosition.dx, width),
                  onHorizontalDragUpdate: (d) =>
                      pick(d.localPosition.dx, width),
                  child: CustomPaint(
                    size: Size(width, _height),
                    painter: _TimelinePainter(
                      data: data,
                      visible: visible.toSet(),
                      health: health,
                      selectedIndex: selected,
                      playhead: playingHere ? player.playhead : null,
                      labelColor: theme.colorScheme.onSurface,
                      playheadColor: theme.colorScheme.primary,
                      thresholdLabel: l10n.sfSleepThresholdShort,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 2,
          children: [
            for (final c in [...SleepSoundCategory.values, null])
              if (categories.contains(c))
                _LegendDot(color: c.color, label: c.label(l10n)),
            for (final k in SleepStageKind.values)
              if (stages.contains(k))
                _LegendDot(color: k.color, label: k.label(l10n)),
          ],
        ),
      ],
    );
  }

  static int? _nearest(
    SleepSessionData data,
    List<int> visible,
    double dx,
    double width,
  ) {
    final candidates = visible.isEmpty
        ? List.generate(data.events.length, (i) => i)
        : visible;
    if (candidates.isEmpty) return null;
    final total = _totalMs(data);
    final plotW = math.max(1.0, width - _leftPad);
    final t = ((dx - _leftPad) / plotW).clamp(0.0, 1.0) * total;
    final start = data.startedAt.millisecondsSinceEpoch;
    int? best;
    var bestDist = double.infinity;
    for (final i in candidates) {
      final e = data.events[i];
      final s = (e.startedAt.millisecondsSinceEpoch - start).toDouble();
      final en = (e.endedAt.millisecondsSinceEpoch - start).toDouble();
      final d = t < s ? s - t : (t > en ? t - en : 0.0);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  static double _totalMs(SleepSessionData data) => math.max(
    1000.0,
    data.endedAt.difference(data.startedAt).inMilliseconds.toDouble(),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.data,
    required this.visible,
    required this.health,
    required this.selectedIndex,
    required this.playhead,
    required this.labelColor,
    required this.playheadColor,
    required this.thresholdLabel,
  }) : super(repaint: playhead);

  static const double _bottomPad = 26;
  static const int _minDb = -60;
  static const double _stageStrip = 5;

  final SleepSessionData data;
  final Set<int> visible;
  final List<SleepStageBand> health;
  final int? selectedIndex;
  final ValueListenable<DateTime?>? playhead;
  final Color labelColor;
  final Color playheadColor;
  final String thresholdLabel;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = SfSleepTimeline._leftPad;
    final start = data.startedAt;
    final total = SfSleepTimeline._totalMs(data);
    final plotW = size.width - leftPad;
    final plotH = size.height - _bottomPad;
    double xOf(DateTime t) =>
        leftPad +
        (t.difference(start).inMilliseconds / total).clamp(0.0, 1.0) * plotW;
    double yOf(double db) =>
        plotH - ((db - _minDb) / -_minDb).clamp(0.0, 1.0) * (plotH - 4);

    final tp = TextPainter(textDirection: TextDirection.ltr);
    void label(String text, Offset at, {double size = 10, Color? color}) {
      tp.text = TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: color ?? labelColor,
        ),
      );
      tp.layout();
      tp.paint(canvas, at);
    }

    final gridPaint = Paint()..color = labelColor.withValues(alpha: 0.12);
    for (var db = _minDb; db <= 0; db += 15) {
      final y = yOf(db.toDouble());
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      label('$db', Offset(2, y - 6));
    }

    for (final b in health) {
      final x0 = xOf(b.start);
      final x1 = xOf(b.end);
      canvas.drawRect(
        Rect.fromLTRB(x0, 0, x1, plotH),
        Paint()..color = b.kind.color.withValues(alpha: 0.16),
      );
      canvas.drawRect(
        Rect.fromLTRB(x0, 0, x1, _stageStrip),
        Paint()..color = b.kind.color,
      );
    }

    final gapPaint = Paint()..color = labelColor.withValues(alpha: 0.05);
    var cursor = start;
    for (final e in [...data.events, null]) {
      final next = e?.startedAt ?? data.endedAt;
      if (next.difference(cursor).inSeconds > 30) {
        canvas.drawRect(
          Rect.fromLTRB(xOf(cursor), 0, xOf(next), plotH),
          gapPaint,
        );
      }
      if (e != null) cursor = e.endedAt;
    }

    final thrDb = ampToDb(data.threshold);
    final thrY = yOf(thrDb);
    final thrPaint = Paint()
      ..color = SoundFinderColors.sleepThreshold.withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    for (var dx = leftPad; dx < size.width; dx += 10) {
      canvas.drawLine(
        Offset(dx, thrY),
        Offset(math.min(dx + 6, size.width), thrY),
        thrPaint,
      );
    }
    label(
      thresholdLabel,
      Offset(leftPad + 2, thrY - 12),
      size: 9,
      color: SoundFinderColors.sleepThreshold,
    );

    final basePaint = Paint()..color = labelColor.withValues(alpha: 0.4);
    canvas.drawLine(
      Offset(leftPad, plotH),
      Offset(size.width, plotH),
      basePaint,
    );
    label('dB', const Offset(2, 0));

    final stepSec = switch (total / 1000) {
      <= 600 => 60,
      <= 3600 => 300,
      <= 4 * 3600 => 900,
      <= 12 * 3600 => 1800,
      _ => 3600,
    };
    for (var s = 0; s * 1000 <= total; s += stepSec) {
      final x = leftPad + (s * 1000 / total) * plotW;
      canvas.drawLine(Offset(x, plotH - 6), Offset(x, plotH), basePaint);
      final hh = (s ~/ 3600).toString().padLeft(2, '0');
      final mm = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
      label('$hh:$mm', Offset(x + 1, plotH + 2));
    }
    label(
      sleepClock(start, seconds: false),
      Offset(leftPad, plotH + 13),
      size: 9,
    );
    tp.text = TextSpan(
      text: sleepClock(data.endedAt, seconds: false),
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: labelColor,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset(size.width - tp.width - 2, plotH + 13));

    final dense = data.events.length > 60;
    final dotPaint = Paint()
      ..color = labelColor.withValues(alpha: 0.25)
      ..strokeWidth = 0.8;
    for (var i = 0; i < data.events.length; i++) {
      final e = data.events[i];
      final x0 = xOf(e.startedAt);
      final w = math.max(2.0, xOf(e.endedAt) - x0);
      final top = yOf(e.peakDb.clamp(_minDb.toDouble(), 0));
      final shown = visible.contains(i);
      final color = (e.analysis?.category).color;
      canvas.drawRect(
        Rect.fromLTRB(x0, top, x0 + w, plotH),
        Paint()..color = color.withValues(alpha: shown ? 0.85 : 0.15),
      );
      if (!dense && shown) {
        for (var y = 0.0; y < top; y += 6) {
          canvas.drawLine(
            Offset(x0, y),
            Offset(x0, math.min(y + 3, top)),
            dotPaint,
          );
        }
      }
    }

    final sel = selectedIndex;
    if (sel != null && sel >= 0 && sel < data.events.length) {
      final e = data.events[sel];
      final x0 = xOf(e.startedAt);
      final w = math.max(2.0, xOf(e.endedAt) - x0);
      final top = yOf(e.peakDb.clamp(_minDb.toDouble(), 0));
      final cx = x0 + w / 2;
      canvas.drawLine(
        Offset(cx, 0),
        Offset(cx, plotH),
        Paint()
          ..color = labelColor.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
      canvas.drawRect(
        Rect.fromLTRB(x0 - 2, top - 2, x0 + w + 2, plotH),
        Paint()
          ..color = labelColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final marker = Path()
        ..moveTo(cx - 6, 0)
        ..lineTo(cx + 6, 0)
        ..lineTo(cx, 8)
        ..close();
      canvas.drawPath(marker, Paint()..color = labelColor);
    }

    final head = playhead?.value;
    if (head != null) {
      final x = xOf(head);
      final p = Paint()
        ..color = playheadColor
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, 0), Offset(x, plotH), p);
      canvas.drawCircle(Offset(x, plotH), 4, p);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.data != data ||
      !setEquals(old.visible, visible) ||
      old.health != health ||
      old.selectedIndex != selectedIndex ||
      old.playhead != playhead ||
      old.labelColor != labelColor;
}
