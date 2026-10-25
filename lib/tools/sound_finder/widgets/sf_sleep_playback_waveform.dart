import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/wav_decoder.dart';

import '../sleep_player.dart';
import '../sleep_session_store.dart';

/// Compact envelope for the chunk currently playing in a sleep session.
class SfSleepPlaybackWaveform extends StatefulWidget {
  const SfSleepPlaybackWaveform({super.key, required this.session});

  final SleepSession session;

  @override
  State<SfSleepPlaybackWaveform> createState() =>
      _SfSleepPlaybackWaveformState();
}

class _SfSleepPlaybackWaveformState extends State<SfSleepPlaybackWaveform> {
  static const int _columns = 120;

  Float32List? _peaks;
  String? _fileName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = context.read<SleepPlayer>();
    player.addListener(_loadPlayingChunk);
    _loadPlayingChunk();
  }

  @override
  void dispose() {
    context.read<SleepPlayer>().removeListener(_loadPlayingChunk);
    super.dispose();
  }

  void _loadPlayingChunk() {
    final player = context.read<SleepPlayer>();
    final index = player.playingIndex(widget.session.id);
    if (index == null || index >= widget.session.data.events.length) return;
    final event = widget.session.data.events[index];
    if (_fileName == event.fileName) return;
    _fileName = event.fileName;
    _load(widget.session.data.fileFor(event), event.fileName);
  }

  Future<void> _load(File file, String fileName) async {
    try {
      final bytes = await file.readAsBytes();
      final audio = WavDecoder.decode(bytes);
      final peaks = audio == null ? null : _envelope(audio.samples);
      if (mounted && _fileName == fileName) setState(() => _peaks = peaks);
    } catch (_) {
      if (mounted && _fileName == fileName) setState(() => _peaks = null);
    }
  }

  Float32List _envelope(Float32List samples) {
    final out = Float32List(_columns);
    for (var column = 0; column < _columns; column++) {
      final start = samples.length * column ~/ _columns;
      final end = samples.length * (column + 1) ~/ _columns;
      var peak = 0.0;
      for (var i = start; i < end; i++) {
        final value = samples[i].abs();
        if (value > peak) peak = value;
      }
      out[column] = peak;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<SleepPlayer>();
    final index = player.playingIndex(widget.session.id);
    if (index == null) return const SizedBox.shrink();
    final event = widget.session.data.events[index];
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        height: 32,
        child: CustomPaint(
          painter: _SleepPlaybackWaveformPainter(
            peaks: _peaks,
            playhead: player.playhead,
            startedAt: event.startedAt,
            length: event.duration,
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
