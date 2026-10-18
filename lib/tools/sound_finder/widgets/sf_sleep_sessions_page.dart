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
    if (!Platform.isAndroid) return;
    setState(() => _healthLoading.add(session.path));
    try {
      final connector = await hc.HealthConnector.create();
      await connector.requestPermissions([
        hc.HealthDataType.sleepSession.readPermission,
      ]);
      final start = session.createdAt;
      final end = session.data?.endedAt ?? start.add(const Duration(hours: 12));
      final req = hc.HealthDataType.sleepSession.readInTimeRange(
        startTime: start,
        endTime: end,
      );
      final resp = await connector.readRecords(req);
      final bands = <_StageBand>[];
      for (final r in (resp.records as List).cast<hc.HealthRecord>()) {
        // Best-effort: treat record interval as a band.
        final s = r is hc.IntervalHealthRecord ? r.startTime : start;
        final e = r is hc.IntervalHealthRecord ? r.endTime : end;
        bands.add(_StageBand(start: s, end: e, label: 'sleep'));
      }
      if (mounted) {
        setState(() {
          _healthStages[session.path] = bands;
          _healthLoading.remove(session.path);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _healthLoading.remove(session.path));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Health Connect unavailable: $e')));
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
        peakAmplitude: 0,
      ));
    }
    return SleepSessionData(
      path: session.path,
      startedAt: session.createdAt,
      endedAt: session.createdAt.add(session.totalDuration),
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
              SizedBox(
                height: 140,
                child: CustomPaint(
                  painter: _TimelinePainter(
                    session: session,
                    data: data,
                    health: _healthStages[session.path] ?? const [],
                  ),
                  size: Size.infinite,
                ),
              ),
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

class _StageBand {
  _StageBand({required this.start, required this.end, required this.label});
  final DateTime start;
  final DateTime end;
  final String label;
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.session, required this.data, required this.health});
  final SleepSession session;
  final SleepSessionData data;
  final List<_StageBand> health;

  @override
  void paint(Canvas canvas, Size size) {
    final start = data.startedAt;
    final total = data.endedAt.difference(start).inSeconds.toDouble().clamp(1, double.infinity);
    // Health bands.
    for (final b in health) {
      final x0 = (b.start.difference(start).inSeconds / total).clamp(0.0, 1.0) * size.width;
      final x1 = (b.end.difference(start).inSeconds / total).clamp(0.0, 1.0) * size.width;
      final paint = Paint()..color = Colors.blue.withValues(alpha: 0.15);
      canvas.drawRect(Rect.fromLTRB(x0, 0, x1, size.height), paint);
    }
    // Baseline.
    final basePaint = Paint()..color = Colors.grey.withValues(alpha: 0.3);
    canvas.drawLine(Offset(0, size.height - 1), Offset(size.width, size.height - 1), basePaint);
    // Events.
    for (final e in data.events) {
      final x = (e.startedAt.difference(start).inSeconds / total).clamp(0.0, 1.0) * size.width;
      final db = e.peakDb.clamp(-60.0, 0.0);
      final h = (1 - (db + 60) / 60) * (size.height - 4);
      final color = e.classification == 'loud'
          ? Colors.red
          : e.classification == 'sound'
              ? Colors.orange
              : Colors.grey;
      final paint = Paint()..color = color;
      canvas.drawRect(Rect.fromLTWH(x - 2, size.height - h, 4, h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) => true;
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.values, required this.labels});
  final List<double> values;
  final List<String> labels;

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
        text: TextSpan(text: labels[i], style: const TextStyle(fontSize: 9, color: Colors.black54)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(i * barW + 2, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => true;
}
