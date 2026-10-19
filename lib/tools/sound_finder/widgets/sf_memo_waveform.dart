import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../memo/memo_clip.dart';
import '../memo/memo_store.dart';

/// Envelope of a stored memo. With [position] it shows the playhead; taps and
/// drags report the touched fraction through [onSeek].
class SfMemoWaveform extends StatefulWidget {
  final MemoClip clip;
  final ValueListenable<Duration>? position;
  final Duration length;
  final ValueChanged<double>? onSeek;
  final double height;

  /// Shades everything outside this fraction range, for the trim dialog.
  final (double, double)? selection;

  const SfMemoWaveform({
    super.key,
    required this.clip,
    this.position,
    this.length = Duration.zero,
    this.onSeek,
    this.height = 44,
    this.selection,
  });

  @override
  State<SfMemoWaveform> createState() => _SfMemoWaveformState();
}

class _SfMemoWaveformState extends State<SfMemoWaveform> {
  Float32List? _peaks;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SfMemoWaveform old) {
    super.didUpdateWidget(old);
    if (old.clip.path != widget.clip.path ||
        old.clip.modified != widget.clip.modified) {
      _load();
    }
  }

  Future<void> _load() async {
    final peaks = await MemoStore.peaks(widget.clip);
    if (mounted) setState(() => _peaks = peaks);
  }

  void _seekAt(double dx, double width) {
    if (width <= 0) return;
    widget.onSeek?.call((dx / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final listenable = widget.position ?? const _ZeroListenable();

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.onSeek == null
                ? null
                : (d) => _seekAt(d.localPosition.dx, width),
            onHorizontalDragUpdate: widget.onSeek == null
                ? null
                : (d) => _seekAt(d.localPosition.dx, width),
            child: CustomPaint(
              size: Size(width, widget.height),
              painter: _PeaksPainter(
                peaks: _peaks,
                position: listenable,
                length: widget.length,
                played: scheme.primary,
                unplayed: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                shade: scheme.surface.withValues(alpha: 0.7),
                selection: widget.selection,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ZeroListenable implements ValueListenable<Duration> {
  const _ZeroListenable();

  @override
  Duration get value => Duration.zero;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _PeaksPainter extends CustomPainter {
  final Float32List? peaks;
  final ValueListenable<Duration> position;
  final Duration length;
  final Color played;
  final Color unplayed;
  final Color shade;
  final (double, double)? selection;

  _PeaksPainter({
    required this.peaks,
    required this.position,
    required this.length,
    required this.played,
    required this.unplayed,
    required this.shade,
    required this.selection,
  }) : super(repaint: position);

  @override
  void paint(Canvas canvas, Size size) {
    final data = peaks;
    final mid = size.height / 2;
    final progress = length.inMicroseconds <= 0
        ? 0.0
        : (position.value.inMicroseconds / length.inMicroseconds).clamp(
            0.0,
            1.0,
          );

    if (data == null || data.isEmpty) {
      canvas.drawLine(
        Offset(0, mid),
        Offset(size.width, mid),
        Paint()
          ..color = unplayed
          ..strokeWidth = 1,
      );
    } else {
      final step = size.width / data.length;
      final stroke = (step * 0.6).clamp(1.0, 3.0);
      final playedPaint = Paint()
        ..color = played
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      final restPaint = Paint()
        ..color = unplayed
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < data.length; i++) {
        final x = i * step + step / 2;
        final h = (data[i] * mid).clamp(1.0, mid);
        canvas.drawLine(
          Offset(x, mid - h),
          Offset(x, mid + h),
          x / size.width <= progress ? playedPaint : restPaint,
        );
      }
    }

    final sel = selection;
    if (sel != null) {
      final shadePaint = Paint()..color = shade;
      canvas.drawRect(
        Rect.fromLTRB(0, 0, sel.$1 * size.width, size.height),
        shadePaint,
      );
      canvas.drawRect(
        Rect.fromLTRB(sel.$2 * size.width, 0, size.width, size.height),
        shadePaint,
      );
    }

    if (progress > 0) {
      final x = progress * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = played
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PeaksPainter old) =>
      old.peaks != peaks ||
      old.position != position ||
      old.length != length ||
      old.played != played ||
      old.unplayed != unplayed ||
      old.selection != selection;
}
