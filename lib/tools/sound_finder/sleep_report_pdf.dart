import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart' show DateFormat;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/sleep_stage_style.dart';

import 'audio/db_scale.dart';
import 'audio/sleep_chunk_analyzer.dart';
import 'sleep_labels.dart';
import 'sleep_session_data.dart';
import 'sleep_session_store.dart';
import 'sleep_sessions_state.dart' show SleepStageBand;
import 'sound_finder_colors.dart';

const _ink = PdfColor.fromInt(0xFF23272E);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _hairline = PdfColor.fromInt(0xFFD5D9E0);
const _paper = PdfColor.fromInt(0xFFF6F8FA);
const _grid = PdfColor.fromInt(0xFFE6E9EE);

/// Landscape night report: the timeline with sleep stages on one page, read
/// like the app's chart, then every sound event as a table.
Future<Uint8List> buildSleepReportPdf({
  required SleepSession session,
  required List<SleepStageBand> stages,
  required AppLocalizations l10n,
  required String locale,
}) async {
  final base = pw.Font.ttf(
    await rootBundle.load('assets/google_fonts/NotoSans-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/google_fonts/NotoSans-Bold.ttf'),
  );
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: base, bold: bold).copyWith(
      defaultTextStyle: pw.TextStyle(font: base, fontSize: 8.5, color: _ink),
    ),
  );
  final format = PdfPageFormat.a4.landscape.copyWith(
    marginLeft: 28,
    marginRight: 28,
    marginTop: 24,
    marginBottom: 24,
  );
  final night = _Night(session.data, stages);

  document.addPage(
    pw.MultiPage(
      pageFormat: format,
      footer: (context) => _footer(context, l10n),
      build: (context) => [
        _header(session.data, l10n, locale),
        pw.SizedBox(height: 8),
        _stats(session.data, l10n),
        pw.SizedBox(height: 10),
        _sectionTitle(l10n.sfSleepPdfTimeline),
        pw.SizedBox(height: 4),
        _NightChart(night: night, width: format.availableWidth, l10n: l10n),
        pw.SizedBox(height: 4),
        _legend(night, l10n),
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(flex: 4, child: _summary(night, l10n)),
            pw.SizedBox(width: 16),
            pw.Expanded(flex: 3, child: _categoryTable(night, l10n)),
            pw.SizedBox(width: 16),
            pw.Expanded(flex: 3, child: _stageTable(night, l10n)),
          ],
        ),
        if (night.events.isNotEmpty) ...[
          pw.NewPage(),
          _sectionTitle(l10n.sfSleepPdfEvents),
          pw.SizedBox(height: 6),
          _eventTable(night, l10n),
        ],
      ],
    ),
  );
  return document.save();
}

/// Everything the report derives from one night, computed once.
class _Night {
  _Night(this.data, this.stages)
    : events = data.events,
      categoryCounts = {for (final e in data.events) e.analysis?.category: 0},
      stageTime = {},
      stageEvents = {} {
    for (final e in events) {
      final c = e.analysis?.category;
      categoryCounts[c] = categoryCounts[c]! + 1;
      final stage = stageAt(e);
      if (stage != null) stageEvents[stage] = (stageEvents[stage] ?? 0) + 1;
    }
    for (final b in stages) {
      stageTime[b.kind] =
          (stageTime[b.kind] ?? Duration.zero) + b.end.difference(b.start);
    }
  }

  final SleepSessionData data;
  final List<SleepStageBand> stages;
  final List<SleepEvent> events;
  final Map<SleepSoundCategory?, int> categoryCounts;
  final Map<SleepStageKind, Duration> stageTime;
  final Map<SleepStageKind, int> stageEvents;

  Duration get stagedTime =>
      stageTime.values.fold(Duration.zero, (a, d) => a + d);

  SleepStageKind? stageAt(SleepEvent e) {
    final mid = e.startedAt.add(e.duration ~/ 2);
    for (final b in stages) {
      if (!mid.isBefore(b.start) && mid.isBefore(b.end)) return b.kind;
    }
    return null;
  }

  /// Lanes top to bottom like a hypnogram; generic "asleep" only when used.
  List<SleepStageKind> get lanes => stages.isEmpty
      ? const []
      : [
          for (final k in SleepStageKind.values)
            if (k != SleepStageKind.asleep || stageTime.containsKey(k)) k,
        ];
}

PdfColor _pdf(Color c) => PdfColor.fromInt(c.toARGB32());

/// [c] at [alpha] over white, so tints print the same on every viewer.
PdfColor _tint(PdfColor c, double alpha) => PdfColor(
  1 - (1 - c.red) * alpha,
  1 - (1 - c.green) * alpha,
  1 - (1 - c.blue) * alpha,
);

String _clock(DateTime t) => sleepClock(t, seconds: false);

pw.Widget _sectionTitle(String text) => pw.Text(
  text.toUpperCase(),
  style: pw.TextStyle(
    fontSize: 8,
    fontWeight: pw.FontWeight.bold,
    color: _muted,
    letterSpacing: .6,
  ),
);

pw.Widget _header(
  SleepSessionData data,
  AppLocalizations l10n,
  String locale,
) => pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.end,
  children: [
    pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            l10n.sfSleepPdfTitle,
            style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '${DateFormat.yMMMMEEEEd(locale).format(data.startedAt)} · '
            '${_clock(data.startedAt)} – ${_clock(data.endedAt)}',
            style: const pw.TextStyle(fontSize: 9.5, color: _muted),
          ),
        ],
      ),
    ),
    pw.Text(
      l10n.toolNameAudioLab,
      style: const pw.TextStyle(fontSize: 9, color: _muted),
    ),
  ],
);

pw.Widget _stats(SleepSessionData data, AppLocalizations l10n) {
  final events = data.events;
  final fields = <(String, String)>[
    (l10n.sfSleepDuration, sleepDuration(data.duration)),
    (l10n.sfSleepRecorded, sleepDuration(data.recordedDuration)),
    (l10n.sfSleepChunks, '${events.length}'),
    if (events.isNotEmpty) ...[
      (l10n.sfSleepLoudest, '${data.loudestDb.toStringAsFixed(1)} dB'),
      (l10n.sfSleepAverage, '${data.avgPeakDb.toStringAsFixed(1)} dB'),
      (l10n.sfSleepFirstEvent, _clock(events.first.startedAt)),
      (l10n.sfSleepLastEvent, _clock(events.last.startedAt)),
    ],
  ];
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 7),
    decoration: pw.BoxDecoration(
      color: _paper,
      border: pw.Border.all(color: _hairline),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Row(
      children: [
        for (final (label, value) in fields)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  label,
                  maxLines: 1,
                  style: const pw.TextStyle(fontSize: 6.5, color: _muted),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  value,
                  maxLines: 1,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// The app's night timeline drawn as vectors: stage lanes on top, then one
/// bar per chunk (height = peak dB, colour = category) over stage tints.
class _NightChart extends pw.StatelessWidget {
  _NightChart({required this.night, required this.width, required this.l10n});

  final _Night night;
  final double width;
  final AppLocalizations l10n;

  static const double _height = 230;
  static const double _leftPad = 40;
  static const double _axis = 16;
  static const double _lane = 8;
  static const double _laneGap = 2.5;
  static const int _minDb = -60;

  @override
  pw.Widget build(pw.Context context) {
    final data = night.data;
    final start = data.startedAt;
    final totalMs = math.max(
      1000,
      data.endedAt.difference(start).inMilliseconds,
    );
    final plotW = width - _leftPad;
    final lanes = night.lanes;
    final lanesH = lanes.isEmpty ? 0.0 : lanes.length * (_lane + _laneGap) + 6;
    final plotTop = _height - lanesH;
    final plotH = plotTop - _axis - 2;

    double xOf(DateTime t) =>
        _leftPad +
        (t.difference(start).inMilliseconds / totalMs).clamp(0.0, 1.0) * plotW;
    // Painter space: y grows upwards from the bottom edge.
    double yOf(double db) =>
        _axis + ((db - _minDb) / -_minDb).clamp(0.0, 1.0) * plotH;
    double laneY(int i) => _height - (i + 1) * (_lane + _laneGap);

    final ticks = _ticks(start, data.endedAt);
    final labels = <pw.Widget>[];
    void label(String text, double x, double y, {double size = 6.5}) =>
        labels.add(
          pw.Positioned(
            left: x,
            top: _height - y,
            child: pw.Text(
              text,
              style: pw.TextStyle(fontSize: size, color: _muted),
            ),
          ),
        );

    for (var db = _minDb; db <= 0; db += 15) {
      label('$db dB', 0, yOf(db.toDouble()) + 4);
    }
    for (var i = 0; i < lanes.length; i++) {
      label(lanes[i].label(l10n), 0, laneY(i) + _lane + 0.5, size: 6);
    }
    for (final t in ticks) {
      label(_clock(t), xOf(t) + 1.5, _axis - 2);
    }

    return pw.SizedBox(
      width: width,
      height: _height,
      child: pw.Stack(
        overflow: pw.Overflow.visible,
        children: [
          pw.CustomPaint(
            size: PdfPoint(width, _height),
            painter: (canvas, size) {
              for (final b in night.stages) {
                canvas
                  ..setFillColor(_tint(_pdf(b.kind.color), 0.13))
                  ..drawRect(
                    xOf(b.start),
                    _axis,
                    xOf(b.end) - xOf(b.start),
                    plotH,
                  )
                  ..fillPath();
              }

              canvas
                ..setStrokeColor(_grid)
                ..setLineWidth(.5);
              for (var db = _minDb; db <= 0; db += 15) {
                final y = yOf(db.toDouble());
                canvas
                  ..moveTo(_leftPad, y)
                  ..lineTo(width, y);
              }
              canvas.strokePath();

              for (final e in night.events) {
                final x0 = xOf(e.startedAt);
                final w = math.max(1.2, xOf(e.endedAt) - x0);
                final top = yOf(e.peakDb.clamp(_minDb.toDouble(), 0));
                canvas
                  ..setFillColor(_pdf((e.analysis?.category).color))
                  ..drawRect(x0, _axis, w, top - _axis)
                  ..fillPath();
              }

              final thrY = yOf(ampToDb(data.threshold));
              canvas
                ..setStrokeColor(_pdf(SoundFinderColors.sleepThreshold))
                ..setLineWidth(.8)
                ..setLineDashPattern([4, 3])
                ..moveTo(_leftPad, thrY)
                ..lineTo(width, thrY)
                ..strokePath()
                ..setLineDashPattern();

              for (var i = 0; i < lanes.length; i++) {
                final y = laneY(i);
                canvas
                  ..setFillColor(_grid)
                  ..drawRRect(_leftPad, y, plotW, _lane, 2, 2)
                  ..fillPath()
                  ..setFillColor(_pdf(lanes[i].color));
                for (final b in night.stages) {
                  if (b.kind != lanes[i]) continue;
                  canvas.drawRect(
                    xOf(b.start),
                    y,
                    math.max(.6, xOf(b.end) - xOf(b.start)),
                    _lane,
                  );
                }
                canvas.fillPath();
              }

              canvas
                ..setStrokeColor(_muted)
                ..setLineWidth(.6)
                ..moveTo(_leftPad, _axis)
                ..lineTo(width, _axis);
              for (final t in ticks) {
                final x = xOf(t);
                canvas
                  ..moveTo(x, _axis)
                  ..lineTo(x, _axis - 3);
              }
              canvas.strokePath();
            },
          ),
          ...labels,
        ],
      ),
    );
  }

  /// Clock-aligned ticks, as many as fit a landscape page comfortably.
  static List<DateTime> _ticks(DateTime start, DateTime end) {
    final minutes = end.difference(start).inMinutes;
    final step = switch (minutes) {
      <= 20 => 2,
      <= 60 => 10,
      <= 180 => 15,
      <= 420 => 30,
      _ => 60,
    };
    final first = DateTime(
      start.year,
      start.month,
      start.day,
      start.hour,
    ).add(Duration(minutes: (start.minute ~/ step + 1) * step));
    return [
      for (var t = first; t.isBefore(end); t = t.add(Duration(minutes: step)))
        t,
    ];
  }
}

pw.Widget _dot(PdfColor color) => pw.Container(
  width: 7,
  height: 7,
  margin: const pw.EdgeInsets.only(right: 4),
  decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
);

pw.Widget _legend(_Night night, AppLocalizations l10n) => pw.Wrap(
  spacing: 12,
  runSpacing: 3,
  children: [
    for (final c in [...SleepSoundCategory.values, null])
      if (night.categoryCounts.containsKey(c))
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            _dot(_pdf(c.color)),
            pw.Text(c.label(l10n), style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
  ],
);

pw.Widget _summary(_Night night, AppLocalizations l10n) {
  final data = night.data;
  final lines = <String>[];
  if (night.events.isEmpty) {
    lines.add(l10n.sfSleepPdfNoEvents);
  } else {
    lines.add(
      l10n.sfSleepPdfSummaryEvents(
        night.events.length,
        sleepDuration(data.duration),
        sleepDuration(data.recordedDuration),
      ),
    );
    final top = night.categoryCounts.entries.reduce(
      (a, b) => b.value > a.value ? b : a,
    );
    lines.add(
      l10n.sfSleepPdfSummaryTop(
        top.key.label(l10n),
        top.value,
        (top.value * 100 / night.events.length).round(),
      ),
    );
    final loudest = night.events.reduce((a, b) => b.peakDb > a.peakDb ? b : a);
    lines.add(
      l10n.sfSleepPdfSummaryLoudest(
        _clock(loudest.startedAt),
        loudest.peakDb.toStringAsFixed(1),
        (loudest.analysis?.category).label(l10n),
      ),
    );
  }
  if (night.stages.isEmpty) {
    lines.add(l10n.sfSleepPdfNoStages);
  } else if (night.stageEvents.isNotEmpty) {
    final top = night.stageEvents.entries.reduce(
      (a, b) => b.value > a.value ? b : a,
    );
    lines.add(
      l10n.sfSleepPdfSummaryStages(
        sleepDuration(night.stagedTime),
        top.key.label(l10n),
        top.value,
      ),
    );
  }
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle(l10n.sfSleepPdfSummary),
      pw.SizedBox(height: 5),
      for (final line in lines)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(line, style: const pw.TextStyle(fontSize: 9)),
        ),
    ],
  );
}

pw.Widget _table({
  required List<String> headers,
  required List<List<pw.Widget>> rows,
  required Map<int, pw.TableColumnWidth> widths,
}) {
  pw.Widget head(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        color: _muted,
      ),
    ),
  );
  pw.Widget cell(pw.Widget child) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
    child: child,
  );
  return pw.Table(
    columnWidths: widths,
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _grid, width: .5),
      bottom: pw.BorderSide(color: _hairline, width: .6),
    ),
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _hairline)),
        ),
        children: [for (final h in headers) head(h)],
      ),
      for (final row in rows)
        pw.TableRow(children: [for (final c in row) cell(c)]),
    ],
  );
}

pw.Widget _text(String s, {bool right = false}) => pw.Text(
  s,
  textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
  style: const pw.TextStyle(fontSize: 8),
);

pw.Widget _labelled(PdfColor color, String label) => pw.Row(
  children: [
    _dot(color),
    pw.Flexible(child: _text(label)),
  ],
);

pw.Widget _categoryTable(_Night night, AppLocalizations l10n) {
  final total = night.events.length;
  final entries = night.categoryCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _sectionTitle(l10n.sfSleepPdfCategories),
      pw.SizedBox(height: 4),
      _table(
        headers: [
          l10n.sfSleepPdfColCategory,
          l10n.sfSleepPdfColCount,
          l10n.sfSleepPdfColShare,
        ],
        widths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(1.2),
          2: pw.FlexColumnWidth(1.2),
        },
        rows: [
          for (final e in entries)
            [
              _labelled(_pdf(e.key.color), e.key.label(l10n)),
              _text('${e.value}', right: true),
              _text('${(e.value * 100 / total).round()} %', right: true),
            ],
        ],
      ),
    ],
  );
}

pw.Widget _stageTable(_Night night, AppLocalizations l10n) {
  final staged = night.stagedTime.inSeconds;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _sectionTitle(l10n.sfSleepPdfStages),
      pw.SizedBox(height: 4),
      if (night.stages.isEmpty)
        _text(l10n.sfSleepPdfNoStages)
      else
        _table(
          headers: [
            l10n.sfSleepPdfColStage,
            l10n.sfSleepPdfColDuration,
            l10n.sfSleepPdfColShare,
            l10n.sfSleepPdfColCount,
          ],
          widths: const {
            0: pw.FlexColumnWidth(2.4),
            1: pw.FlexColumnWidth(1.6),
            2: pw.FlexColumnWidth(1.1),
            3: pw.FlexColumnWidth(1.2),
          },
          rows: [
            for (final k in SleepStageKind.values)
              if (night.stageTime[k] case final time?)
                [
                  _labelled(_pdf(k.color), k.label(l10n)),
                  _text(sleepDuration(time), right: true),
                  _text(
                    '${staged == 0 ? 0 : (time.inSeconds * 100 / staged).round()} %',
                    right: true,
                  ),
                  _text('${night.stageEvents[k] ?? 0}', right: true),
                ],
          ],
        ),
    ],
  );
}

pw.Widget _eventTable(_Night night, AppLocalizations l10n) => _table(
  headers: [
    l10n.sfSleepPdfColTime,
    l10n.sfSleepPdfColCategory,
    l10n.sfSleepPdfColConfidence,
    l10n.sfSleepPdfColPeak,
    l10n.sfSleepPdfColStage,
    l10n.sfSleepPdfColNote,
  ],
  widths: const {
    0: pw.FixedColumnWidth(58),
    1: pw.FixedColumnWidth(130),
    2: pw.FixedColumnWidth(62),
    3: pw.FixedColumnWidth(58),
    4: pw.FixedColumnWidth(80),
    5: pw.FlexColumnWidth(),
  },
  rows: [
    for (final e in night.events)
      [
        _text(sleepClock(e.startedAt)),
        _labelled(
          _pdf((e.analysis?.category).color),
          (e.analysis?.category).label(l10n),
        ),
        _text(
          e.analysis == null
              ? '–'
              : '${(e.analysis!.confidence * 100).round()} %',
          right: true,
        ),
        _text('${e.peakDb.toStringAsFixed(1)} dB', right: true),
        _text(night.stageAt(e)?.label(l10n) ?? '–'),
        _text(e.annotation ?? ''),
      ],
  ],
);

pw.Widget _footer(pw.Context context, AppLocalizations l10n) => pw.Column(
  children: [
    pw.Container(height: .8, color: _hairline),
    pw.SizedBox(height: 4),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            l10n.sfSleepPdfDisclaimer,
            style: const pw.TextStyle(fontSize: 6.5, color: _muted),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Text(
          l10n.sfSleepPdfPage(context.pageNumber, context.pagesCount),
          style: const pw.TextStyle(fontSize: 7, color: _muted),
        ),
      ],
    ),
  ],
);
