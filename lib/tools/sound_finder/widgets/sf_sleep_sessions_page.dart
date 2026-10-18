import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:health_connector/health_connector.dart' as hc;
import 'package:tool_lab/helpers/file_save_helper.dart';

import '../sleep_session_data.dart';
import '../sound_finder_state.dart';
import '../../health_dashboard/store/health_store.dart';
import '../../health_dashboard/store/health_schema.dart';

class SfSleepSessionsPage extends StatefulWidget {
  const SfSleepSessionsPage({super.key});

  @override
  State<SfSleepSessionsPage> createState() => _SfSleepSessionsPageState();
}

class _SfSleepSessionsPageState extends State<SfSleepSessionsPage> {
  List<SleepSession> _sessions = const [];
  bool _loading = true;
  String? _playingPath;
  SoundHandle? _handle;
  AudioSource? _source;

  // Health Connect overlay state per session path.
  final Map<String, List<_StageBand>> _healthStages = {};
  final Set<String> _healthLoading = {};
  final Map<String, int> _selectedEvent = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await SoundFinderState.listSleepSessions();
    if (!mounted) return;
    setState(() {
      _sessions = s;
      _loading = false;
    });
  }

  Future<void> _play(String path) async {
    if (_playingPath == path) {
      await _stop();
      return;
    }
    await _stop();
    if (!SoLoud.instance.isInitialized) {
      await SoLoud.instance.init();
    }
    try {
      final source = await SoLoud.instance.loadFile(path);
      final handle = SoLoud.instance.play(source);
      _source = source;
      _handle = handle;
      _playingPath = path;
      setState(() {});
      source.soundEvents.listen((e) {
        if (e.handle == handle && e.event == SoundEventType.handleIsNoMoreValid) {
          _stop();
        }
      });
    } catch (_) {}
  }

  Future<void> _stop() async {
    final h = _handle;
    final s = _source;
    _handle = null;
    _source = null;
    _playingPath = null;
    if (h != null) await SoLoud.instance.stop(h);
    if (s != null) SoLoud.instance.disposeSource(s);
    if (mounted) setState(() {});
  }

  Future<void> _deleteSession(SleepSession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text('Delete ${session.chunks.length} chunks?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await SoundFinderState.deleteSleepSession(session.path);
    await _load();
  }

  Future<void> _editAnnotation(SleepSession session, SleepEvent event) async {
    final controller = TextEditingController(text: event.annotation ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annotation'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    event.annotation = result.isEmpty ? null : result;
    if (session.data != null) {
      await session.data!.save();
    }
    if (mounted) setState(() {});
  }

  Future<void> _exportReport(SleepSession session) async {
    final data = session.data;
    final report = <String, dynamic>{
      'session': session.name,
      'createdAt': session.createdAt.toIso8601String(),
      'chunks': session.chunks.length,
      'events': data?.events.map((e) => e.toJson()).toList() ?? [],
      'summary': {
        'totalDurationSeconds': session.totalDuration.inSeconds,
        'chunkCount': session.chunks.length,
        'avgPeakDb': data?.avgPeakDb,
        'loudestDb': data?.loudestDb,
      },
    };
    final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(report)));
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: '${session.name}_report.json',
      bytes: bytes,
    );
  }

  Future<void> _loadHealthStages(SleepSession session) async {
    setState(() => _healthLoading.add(session.path));
    final start = session.createdAt;
    final end = session.data?.endedAt ?? start.add(const Duration(hours: 12));
    final bands = <_StageBand>[];
    // Prefer the already-synced Health Dashboard store (no extra permissions).
    try {
      final sessions = await HealthStore.instance.sessions(
        kind: HealthSchema.sessionKindSleep,
        from: start.millisecondsSinceEpoch,
        to: end.millisecondsSinceEpoch,
      );
      for (final s in sessions) {
        bands.add(_StageBand(
          start: DateTime.fromMillisecondsSinceEpoch(s.t0),
          end: DateTime.fromMillisecondsSinceEpoch(s.t1),
          label: 'sleep',
        ));
      }
    } catch (_) {}
    // Fallback to Health Connect if the local store is empty.
    if (bands.isEmpty && Platform.isAndroid) {
      try {
        final connector = await hc.HealthConnector.create();
        await connector.requestPermissions([hc.HealthDataType.sleepSession.readPermission]);
        final req = hc.HealthDataType.sleepSession.readInTimeRange(startTime: start, endTime: end);
        final resp = await connector.readRecords(req);
        for (final r in (resp.records as List).cast<hc.HealthRecord>()) {
          final s = r is hc.IntervalHealthRecord ? r.startTime : start;
          final e = r is hc.IntervalHealthRecord ? r.endTime : end;
          bands.add(_StageBand(start: s, end: e, label: 'sleep'));
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _healthStages[session.path] = bands;
        _healthLoading.remove(session.path);
      });
      if (bands.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No sleep stages found.')));
      }
    }
  }

  SleepSessionData _effectiveData(SleepSession session) {
    if (session.data != null) return session.data!;
    // Fallback: build from chunks.
    final events = <SleepEvent>[];
    for (final f in session.chunks) {
      final name = f.path.split(Platform.pathSeparator).last;
      // chunk-YYYYMMDD-HHMMSS.wav
      DateTime start = session.createdAt;
      final m = RegExp(r'chunk-(\d{8})-(\d{6})').firstMatch(name);
      if (m != null) {
        final d = m.group(1)!;
        final t = m.group(2)!;
        start = DateTime(
          int.parse(d.substring(0, 4)),
          int.parse(d.substring(4, 6)),
          int.parse(d.substring(6, 8)),
          int.parse(t.substring(0, 2)),
          int.parse(t.substring(2, 4)),
          int.parse(t.substring(4, 6)),
        );
      }
      events.add(SleepEvent(
        file: f.path,
        startedAt: start,
        endedAt: start.add(const Duration(seconds: 15)),
        peakAmplitude: 0.03,
        classification: 'unknown',
      ));
    }
    final start = events.isEmpty ? session.createdAt : events.first.startedAt;
    final end = events.isEmpty
        ? start.add(session.totalDuration)
        : events.last.endedAt;
    return SleepSessionData(
      path: session.path,
      startedAt: start,
      endedAt: end.isAfter(start) ? end : start.add(const Duration(minutes: 1)),
      targetMinutes: 0,
      threshold: 0.005,
      adaptiveThreshold: false,
      events: events,
    );
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep Sessions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('No sessions yet.'))
              : ListView(
                  children: [
                    _buildTrendChart(context),
                    ..._sessions.map(_buildSessionTile),
                  ],
                ),
    );
  }

  Widget _buildTrendChart(BuildContext context) {
    if (_sessions.length < 2) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trend (chunks per night)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _BarChartPainter(
                  values: _sessions.reversed.map((s) => s.chunks.length.toDouble()).toList(),
                  labels: _sessions.reversed.map((s) => '${s.createdAt.month}/${s.createdAt.day}').toList(),
                  labelColor: Theme.of(context).colorScheme.onSurface,
                ),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(SleepSession session) {
    final data = _effectiveData(session);
    return ExpansionTile(
      title: Text(session.name),
      subtitle: Text('${session.chunks.length} chunks • ${session.totalDuration.inMinutes} min • avg ${data.avgPeakDb.toStringAsFixed(1)} dB'),
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReport(session, data),
              const SizedBox(height: 8),
              _buildInteractiveTimeline(session, data),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Load sleep stages'),
                    onPressed: _healthLoading.contains(session.path)
                        ? null
                        : () => _loadHealthStages(session),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.save_alt_outlined),
                    label: const Text('Export report'),
                    onPressed: () => _exportReport(session),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    onPressed: () => _deleteSession(session),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...session.chunks.asMap().entries.map((entry) {
                final idx = entry.key;
                final f = entry.value;
                final ev = idx < data.events.length ? data.events[idx] : null;
                final name = f.path.split(Platform.pathSeparator).last;
                return ListTile(
                  dense: true,
                  title: Text(name),
                  subtitle: Text(ev == null
                      ? ''
                      : '${ev.classification} • ${ev.peakDb.toStringAsFixed(1)} dB • ${ev.startedAt.hour.toString().padLeft(2, '0')}:${ev.startedAt.minute.toString().padLeft(2, '0')} ${ev.annotation ?? ''}'),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        icon: Icon(_playingPath == f.path ? Icons.stop_outlined : Icons.play_arrow_outlined),
                        onPressed: () => _play(f.path),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: ev == null ? null : () => _editAnnotation(session, ev),
                      ),
                      IconButton(
                        icon: const Icon(Icons.save_alt_outlined),
                        onPressed: () => FileSaveHelper.saveFileFromPath(
                          context: context,
                          suggestedName: name,
                          sourcePath: f.path,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveTimeline(SleepSession session, SleepSessionData data) {
    final total = data.endedAt.difference(data.startedAt).inSeconds.toDouble().clamp(1, double.infinity);
    final sel = _selectedEvent[session.path];
    final SleepEvent? selected = (sel != null && sel >= 0 && sel < data.events.length)
        ? data.events[sel]
        : null;

    void pick(double dx, double width) {
      if (data.events.isEmpty) return;
      final t = (dx / width * total).clamp(0.0, total);
      int best = -1;
      double bestDist = double.infinity;
      for (int i = 0; i < data.events.length; i++) {
        final ex = data.events[i].startedAt.difference(data.startedAt).inSeconds.toDouble();
        final d = (ex - t).abs();
        if (d < bestDist) {
          bestDist = d;
          best = i;
        }
      }
      if (best >= 0 && bestDist <= 30) {
        setState(() => _selectedEvent[session.path] = best);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 160,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return MouseRegion(
                onHover: (e) => pick(e.localPosition.dx, constraints.maxWidth),
                child: GestureDetector(
                  onTapDown: (d) => pick(d.localPosition.dx, constraints.maxWidth),
                  child: CustomPaint(
                    painter: _TimelinePainter(
                      session: session,
                      data: data,
                      health: _healthStages[session.path] ?? const [],
                      selectedIndex: sel,
                      labelColor: Theme.of(context).colorScheme.onSurface,
                    ),
                    size: Size(constraints.maxWidth, 160),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Wrap(
            spacing: 12,
            children: const [
              _LegendDot(color: Colors.red, label: 'loud'),
              _LegendDot(color: Colors.orange, label: 'sound'),
              _LegendDot(color: Colors.grey, label: 'faint'),
              _LegendDot(color: Colors.blue, label: 'health stage'),
              _LegendDot(color: Colors.grey, label: 'silence'),
            ],
          ),
        ),
        if (selected != null)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${selected.classification.toUpperCase()} • ${selected.peakDb.toStringAsFixed(1)} dB • '
                      '${selected.startedAt.hour.toString().padLeft(2, '0')}:${selected.startedAt.minute.toString().padLeft(2, '0')}:${selected.startedAt.second.toString().padLeft(2, '0')} • '
                      '${selected.endedAt.difference(selected.startedAt).inSeconds}s'
                      '${selected.annotation == null ? '' : ' • ${selected.annotation}'}',
                    ),
                  ),
                  IconButton(
                    icon: Icon(_playingPath == selected.file ? Icons.stop_outlined : Icons.play_arrow_outlined),
                    onPressed: () => _play(selected.file),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReport(SleepSession session, SleepSessionData data) {
    final duration = session.totalDuration;
    final counts = <String, int>{};
    for (final e in data.events) {
      counts[e.classification] = (counts[e.classification] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Report', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('Duration: ${duration.inHours}h ${duration.inMinutes.remainder(60)}m'),
        Text('Chunks: ${data.events.length} • Loudest: ${data.loudestDb.toStringAsFixed(1)} dB • Avg: ${data.avgPeakDb.toStringAsFixed(1)} dB'),
        Text('Events: ${counts.entries.map((e) => '${e.key} ${e.value}').join(', ')}'),
        if (data.events.isNotEmpty)
          Text('First event: ${data.events.first.startedAt} • Last: ${data.events.last.startedAt}'),
      ],
    );
  }
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
        Container(width: 10, height: 10, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

class _StageBand {
  _StageBand({required this.start, required this.end, required this.label});
  final DateTime start;
  final DateTime end;
  final String label;
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.session, required this.data, required this.health, this.selectedIndex, this.labelColor = Colors.black87});
  final SleepSession session;
  final SleepSessionData data;
  final List<_StageBand> health;
  final int? selectedIndex;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final start = data.startedAt;
    final total = data.endedAt.difference(start).inSeconds.toDouble().clamp(1, double.infinity);
    final leftPad = 34.0;
    final bottomPad = 26.0;
    final plotW = size.width - leftPad;
    final plotH = size.height - bottomPad;

    // dB grid + labels.
    final gridPaint = Paint()..color = Colors.grey.withValues(alpha: 0.18);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int db = -60; db <= 0; db += 15) {
      final y = plotH - ((db + 60) / 60) * (plotH - 4);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      tp.text = TextSpan(text: '$db', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: labelColor));
      tp.layout();
      tp.paint(canvas, Offset(2, y - 6));
    }
    // Threshold line.
    final thrDb = 20 * math.log(data.threshold.clamp(1e-9, 1)) / math.ln10;
    final thrY = plotH - ((thrDb + 60) / 60) * (plotH - 4);
    final thrPaint = Paint()
      ..color = Colors.purple.withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    // dashed
    double dx = leftPad;
    while (dx < size.width) {
      canvas.drawLine(Offset(dx, thrY), Offset(math.min(dx + 6, size.width), thrY), thrPaint);
      dx += 10;
    }
    tp.text = TextSpan(text: 'thr', style: const TextStyle(fontSize: 9, color: Colors.purple));
    tp.layout();
    tp.paint(canvas, Offset(leftPad + 2, thrY - 12));

    // Health bands.
    for (final b in health) {
      final x0 = leftPad + (b.start.difference(start).inSeconds / total).clamp(0.0, 1.0) * plotW;
      final x1 = leftPad + (b.end.difference(start).inSeconds / total).clamp(0.0, 1.0) * plotW;
      final paint = Paint()..color = Colors.blue.withValues(alpha: 0.10);
      canvas.drawRect(Rect.fromLTRB(x0, 0, x1, plotH), paint);
    }

    // Silence gaps (periods between events longer than 30s).
    final gapPaint = Paint()..color = Colors.grey.withValues(alpha: 0.08);
    if (data.events.isNotEmpty) {
      DateTime cursor = start;
      for (final e in data.events) {
        if (e.startedAt.difference(cursor).inSeconds > 30) {
          final x0 = leftPad + (cursor.difference(start).inSeconds / total).clamp(0.0, 1.0) * plotW;
          final x1 = leftPad + (e.startedAt.difference(start).inSeconds / total).clamp(0.0, 1.0) * plotW;
          canvas.drawRect(Rect.fromLTRB(x0, 0, x1, plotH), gapPaint);
        }
        cursor = e.endedAt;
      }
      if (data.endedAt.difference(cursor).inSeconds > 30) {
        final x0 = leftPad + (cursor.difference(start).inSeconds / total).clamp(0.0, 1.0) * plotW;
        final x1 = leftPad + (data.endedAt.difference(start).inSeconds / total).clamp(0.0, 1.0) * plotW;
        canvas.drawRect(Rect.fromLTRB(x0, 0, x1, plotH), gapPaint);
      }
    }

    // Baseline.
    final basePaint = Paint()..color = Colors.grey.withValues(alpha: 0.4);
    canvas.drawLine(Offset(leftPad, plotH), Offset(size.width, plotH), basePaint);

    // Axis titles.
    tp.text = TextSpan(text: 'dB', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: labelColor));
    tp.layout();
    tp.paint(canvas, Offset(2, 0));
    tp.text = TextSpan(text: 'time', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: labelColor));
    tp.layout();
    tp.paint(canvas, Offset(size.width - 34, plotH + 2));

    // Selected cursor.
    if (selectedIndex != null && selectedIndex! >= 0 && selectedIndex! < data.events.length) {
      final e = data.events[selectedIndex!];
      final x = leftPad + (e.startedAt.difference(start).inSeconds / total).clamp(0.0, 1.0) * plotW;
      final cursorPaint = Paint()
        ..color = labelColor.withValues(alpha: 0.6)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, 0), Offset(x, plotH), cursorPaint);
    }

    // Dynamic time ticks based on total duration.
    int stepSec;
    if (total <= 600) {
      stepSec = 60;
    } else if (total <= 3600) {
      stepSec = 300;
    } else if (total <= 4 * 3600) {
      stepSec = 900;
    } else if (total <= 12 * 3600) {
      stepSec = 1800;
    } else {
      stepSec = 3600;
    }
    for (int s = 0; s <= total; s += stepSec) {
      final x = leftPad + (s / total).clamp(0.0, 1.0) * plotW;
      canvas.drawLine(Offset(x, plotH - 6), Offset(x, plotH), basePaint);
      final hh = s ~/ 3600;
      final mm = (s % 3600) ~/ 60;
      tp.text = TextSpan(
        text: '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: labelColor),
      );
      tp.layout();
      tp.paint(canvas, Offset(x + 1, plotH + 2));
    }
    // Start/end clock labels.
    tp.text = TextSpan(
      text: '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: labelColor),
    );
    tp.layout();
    tp.paint(canvas, Offset(leftPad, plotH + 12));
    final end = data.endedAt;
    tp.text = TextSpan(
      text: '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: labelColor),
    );
    tp.layout();
    tp.paint(canvas, Offset(size.width - tp.width - 2, plotH + 12));
    // Minor ticks at each chunk boundary.
    final minorPaint = Paint()..color = Colors.grey.withValues(alpha: 0.25);
    for (final e in data.events) {
      final x = leftPad + (e.startedAt.difference(start).inSeconds / total).clamp(0.0, 1.0) * plotW;
      canvas.drawLine(Offset(x, plotH - 3), Offset(x, plotH), minorPaint);
    }

    // Events as bars spanning chunk duration.
    for (int i = 0; i < data.events.length; i++) {
      final e = data.events[i];
      final x0 = leftPad + (e.startedAt.difference(start).inSeconds / total).clamp(0.0, 1.0) * plotW;
      final x1 = leftPad + (e.endedAt.difference(start).inSeconds / total).clamp(0.0, 1.0) * plotW;
      final barW = math.max(2.0, x1 - x0);
      final db = e.peakDb.clamp(-60.0, 0.0);
      final h = (1 - (db + 60) / 60) * (plotH - 4);
      final color = e.classification == 'loud'
          ? Colors.red
          : e.classification == 'sound'
              ? Colors.orange
              : Colors.grey;
      final paint = Paint()..color = i == selectedIndex ? color : color.withValues(alpha: 0.8);
      canvas.drawRect(Rect.fromLTWH(x0, plotH - h, barW, h), paint);
      // chunk boundary dotted lines
      final dotPaint = Paint()
        ..color = labelColor.withValues(alpha: 0.3)
        ..strokeWidth = 0.8;
      double yy = 0;
      while (yy < plotH) {
        canvas.drawLine(Offset(x0, yy), Offset(x0, math.min(yy + 3, plotH)), dotPaint);
        yy += 6;
      }
      if (i == selectedIndex) {
        final selPaint = Paint()
          ..color = labelColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRect(Rect.fromLTWH(x0 - 1, plotH - h - 1, barW + 2, h + 2), selPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) => true;
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.values, required this.labels, this.labelColor = Colors.black87});
  final List<double> values;
  final List<String> labels;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce(math.max).clamp(1, double.infinity);
    final barW = size.width / values.length;
    for (int i = 0; i < values.length; i++) {
      final h = (values[i] / maxV) * (size.height - 16);
      final paint = Paint()..color = Colors.indigo;
      canvas.drawRect(Rect.fromLTWH(i * barW + 2, size.height - h, barW - 4, h), paint);
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: TextStyle(fontSize: 9, color: labelColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(i * barW + 2, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => true;
}
