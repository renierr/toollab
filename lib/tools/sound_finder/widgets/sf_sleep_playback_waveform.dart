import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/wav_decoder.dart';

import '../sleep_session_data.dart';

/// Compact envelope for the chunk currently playing in a sleep session.
class SfSleepPlaybackWaveform extends StatefulWidget {
  const SfSleepPlaybackWaveform({
    super.key,
    required this.event,
    required this.file,
    required this.playhead,
  });

  final SleepEvent event;
  final File file;
  final ValueListenable<DateTime?> playhead;

  @override
  State<SfSleepPlaybackWaveform> createState() =>
      _SfSleepPlaybackWaveformState();
}

class _SfSleepPlaybackWaveformState extends State<SfSleepPlaybackWaveform> {
  static const int _columns = 120;

  Float32List? _peaks;
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SfSleepPlaybackWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _peaks = null;
      _load();
    }
  }

  @override
  void dispose() {
    _loadId++;
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_loadId;
    final path = widget.file.path;
    try {
      final peaks = await Isolate.run(() {
        final audio = WavDecoder.decode(File(path).readAsBytesSync());
        return audio == null ? null : _envelope(audio.samples);
      });
      if (mounted && id == _loadId) setState(() => _peaks = peaks);
    } catch (_) {
      if (mounted && id == _loadId) setState(() => _peaks = null);
    }
  }

  static Float32List _envelope(Float32List samples) {
    final out = Float32List(_columns);
    var loudest = 0.0;
    for (var column = 0; column < _columns; column++) {
      final start = samples.length * column ~/ _columns;
      final end = samples.length * (column + 1) ~/ _columns;
      var peak = 0.0;
      for (var i = start; i < end; i++) {
        final value = samples[i].abs();
        if (value > peak) peak = value;
      }
      out[column] = peak;
      if (peak > loudest) loudest = peak;
    }
    if (loudest > 0) {
      for (var i = 0; i < out.length; i++) {
        out[i] = math.sqrt(out[i] / loudest);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        width: double.infinity,
        height: 32,
        child: CustomPaint(
          painter: _SleepPlaybackWaveformPainter(
            peaks: _peaks,
            playhead: widget.playhead,
            startedAt: widget.event.startedAt,
            length: widget.event.duration,
            active: scheme.primary,
            inactive: scheme.onSurfaceVariant.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }
}

class _SleepPlaybackWaveformPainter extends CustomPainter {
  const _SleepPlaybackWaveformPainter({
    required this.peaks,
    required this.playhead,
    required this.startedAt,
    required this.length,
    required this.active,
    required this.inactive,
  }) : super(repaint: playhead);

  final Float32List? peaks;
  final ValueListenable<DateTime?> playhead;
  final DateTime startedAt;
  final Duration length;
  final Color active;
  final Color inactive;

  @override
  void paint(Canvas canvas, Size size) {
    final data = peaks;
    final head = playhead.value;
    final progress = head == null || length.inMicroseconds <= 0
        ? 0.0
        : (head.difference(startedAt).inMicroseconds / length.inMicroseconds)
              .clamp(0.0, 1.0);
    final mid = size.height / 2;
    if (data == null || data.isEmpty) {
      canvas.drawLine(
        Offset.zero.translate(0, mid),
        Offset(size.width, mid),
        Paint()..color = inactive,
      );
      return;
    }
    final step = size.width / data.length;
    final stroke = (step * 0.55).clamp(1.0, 2.5);
    final paint = Paint()
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < data.length; i++) {
      final x = i * step + step / 2;
      final height = (data[i] * mid).clamp(1.0, mid);
      paint.color = x / size.width <= progress ? active : inactive;
      canvas.drawLine(Offset(x, mid - height), Offset(x, mid + height), paint);
    }
    if (progress > 0) {
      final x = progress * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = active
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SleepPlaybackWaveformPainter old) =>
      old.peaks != peaks ||
      old.playhead != playhead ||
      old.startedAt != startedAt ||
      old.length != length ||
      old.active != active ||
      old.inactive != inactive;
}
