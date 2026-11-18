import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/core/tool_page_state.dart';

import 'video_format.dart';

/// Seeks once on release; while dragging it only moves the thumb and the time.
class VideoSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;

  /// Drawn as the secondary track.
  final Duration buffered;
  final VoidCallback onSeekStart;
  final ValueChanged<Duration> onSeek;

  const VideoSeekBar({
    super.key,
    required this.position,
    required this.duration,
    this.buffered = Duration.zero,
    required this.onSeekStart,
    required this.onSeek,
  });

  @override
  State<VideoSeekBar> createState() => _VideoSeekBarState();
}

class _VideoSeekBarState extends State<VideoSeekBar> with DisposeCleanup {
  static const int _arrivedMs = 1000;
  static const Duration _settleLimit = Duration(seconds: 1);

  /// The track is inset by the overlay radius, pinned so hover can map
  /// the mouse to a time; it covers the thumb in every Material design.
  static const double _trackInset = 20;

  /// The dragged or just released position, until playback catches up.
  double? _targetMs;
  bool _dragging = false;
  Timer? _settleTimer;

  /// Mouse position over the track, 0–1; null without a hovering mouse.
  double? _hover;

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

  void _onHover(PointerHoverEvent event, double width) {
    final track = width - 2 * _trackInset;
    if (track <= 0) return;
    final fraction = ((event.localPosition.dx - _trackInset) / track).clamp(
      0.0,
      1.0,
    );
    setState(() => _hover = fraction);
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = widget.duration.inMilliseconds.toDouble();
    final seekable = durationMs > 0;
    final max = seekable ? durationMs : 1.0;
    final positionMs = (_targetMs ?? widget.position.inMilliseconds.toDouble())
        .clamp(0.0, seekable ? durationMs : 0.0);
    final bufferedMs = widget.buffered.inMilliseconds.toDouble().clamp(
      0.0,
      max,
    );
    final hover = _dragging || !seekable ? null : _hover;
    return Row(
      children: [
        Text(formatVideoTime(Duration(milliseconds: positionMs.round()))),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => MouseRegion(
              onHover: seekable
                  ? (event) => _onHover(event, constraints.maxWidth)
                  : null,
              onExit: (_) => setState(() => _hover = null),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: _trackInset,
                      ),
                    ),
                    child: Slider(
                      value: positionMs,
                      secondaryTrackValue: bufferedMs > positionMs
                          ? bufferedMs
                          : null,
                      max: max,
                      onChangeStart: seekable ? _onStart : null,
                      onChanged: seekable
                          ? (value) => setState(() => _targetMs = value)
                          : null,
                      onChangeEnd: seekable ? _onEnd : null,
                    ),
                  ),
                  if (hover != null)
                    _HoverTime(
                      time: Duration(
                        milliseconds: (hover * durationMs).round(),
                      ),
                      x:
                          _trackInset +
                          hover * (constraints.maxWidth - 2 * _trackInset),
                      width: constraints.maxWidth,
                    ),
                ],
              ),
            ),
          ),
        ),
        Text(formatVideoTime(widget.duration)),
      ],
    );
  }
}

/// The time under the mouse, above the track.
class _HoverTime extends StatelessWidget {
  static const double _width = 64;

  final Duration time;
  final double x;
  final double width;

  const _HoverTime({required this.time, required this.x, required this.width});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      left: (x - _width / 2).clamp(0.0, (width - _width).clamp(0.0, width)),
      top: -24,
      width: _width,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              formatVideoTime(time),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onInverseSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
