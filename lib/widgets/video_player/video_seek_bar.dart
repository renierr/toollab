import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';

import 'video_format.dart';

/// Seeks once on release; while dragging it only moves the thumb and the time.
class VideoSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final VoidCallback onSeekStart;
  final ValueChanged<Duration> onSeek;

  const VideoSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeekStart,
    required this.onSeek,
  });

  @override
  State<VideoSeekBar> createState() => _VideoSeekBarState();
}

class _VideoSeekBarState extends State<VideoSeekBar> with DisposeCleanup {
  static const int _arrivedMs = 1000;
  static const Duration _settleLimit = Duration(seconds: 1);

  /// The dragged or just released position, until playback catches up.
  double? _targetMs;
  bool _dragging = false;
  Timer? _settleTimer;

  @override
  void initState() {
    super.initState();
    onDispose(() => _settleTimer?.cancel());
  }

  @override
  void didUpdateWidget(covariant VideoSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _targetMs;
    if (_dragging || target == null) return;
    if ((widget.position.inMilliseconds - target).abs() < _arrivedMs) {
      _settle();
    }
  }

  void _settle() {
    _settleTimer?.cancel();
    _targetMs = null;
  }

  void _onStart(double value) {
    _settleTimer?.cancel();
    widget.onSeekStart();
    setState(() {
      _dragging = true;
      _targetMs = value;
    });
  }

  void _onEnd(double value) {
    setState(() {
      _dragging = false;
      _targetMs = value;
    });
    widget.onSeek(Duration(milliseconds: value.round()));
    // A seek that lands elsewhere must not pin the thumb.
    _settleTimer = Timer(_settleLimit, () {
      if (mounted) setState(_settle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = widget.duration.inMilliseconds.toDouble();
    final seekable = durationMs > 0;
    final positionMs = (_targetMs ?? widget.position.inMilliseconds.toDouble())
        .clamp(0.0, seekable ? durationMs : 0.0);
    return Row(
      children: [
        Text(formatVideoTime(Duration(milliseconds: positionMs.round()))),
        Expanded(
          child: Slider(
            value: positionMs,
            max: seekable ? durationMs : 1,
            onChangeStart: seekable ? _onStart : null,
            onChanged: seekable
                ? (value) => setState(() => _targetMs = value)
                : null,
            onChangeEnd: seekable ? _onEnd : null,
          ),
        ),
        Text(formatVideoTime(widget.duration)),
      ],
    );
  }
}
