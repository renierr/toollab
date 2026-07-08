import 'package:flutter/material.dart';

import '../chiptune_colors.dart';
import '../engine/chiptune_player.dart';

/// A seek bar with a large gradient progress track, glowing thumb, and
/// time tooltip on drag — click anywhere to seek.
class ChiptuneSeekBar extends StatefulWidget {
  /// Tracker position shown as the "Pos/Row" label. Null for native audio,
  /// where only the time read-out is shown.
  final SongPosition? position;
  final Duration elapsed;
  final Duration total;
  final ValueChanged<double> onSeekFraction;

  const ChiptuneSeekBar({
    super.key,
    this.position,
    required this.elapsed,
    required this.total,
    required this.onSeekFraction,
  });

  @override
  State<ChiptuneSeekBar> createState() => _ChiptuneSeekBarState();
}

class _ChiptuneSeekBarState extends State<ChiptuneSeekBar> {
  double _dragFraction = -1.0;
  bool _isDragging = false;

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _durationAtFraction(double f) {
    return _fmt(
      Duration(
        milliseconds: (widget.total.inMilliseconds * f.clamp(0.0, 1.0)).round(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = widget.total > Duration.zero
        ? (widget.elapsed.inMicroseconds / widget.total.inMicroseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final displayFraction = _isDragging
        ? _dragFraction.clamp(0.0, 1.0)
        : fraction;
    final style = theme.textTheme.labelSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final f = (details.localPosition.dx / w).clamp(0.0, 1.0);
                  widget.onSeekFraction(f);
                },
                onHorizontalDragStart: (details) {
                  setState(() {
                    _isDragging = true;
                    _dragFraction = (details.localPosition.dx / w).clamp(
                      0.0,
                      1.0,
                    );
                  });
                },
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _dragFraction = (details.localPosition.dx / w).clamp(
                      0.0,
                      1.0,
                    );
                  });
                },
                onHorizontalDragEnd: (details) {
                  widget.onSeekFraction(_dragFraction.clamp(0.0, 1.0));
                  setState(() => _isDragging = false);
                },
                child: _SeekBarPaint(
                  fraction: displayFraction,
                  accent: ChiptuneColors.accent,
                  accentBright: ChiptuneColors.accentBright,
                  surfaceContainer: theme.colorScheme.surfaceContainerHighest,
                  timeText: _isDragging
                      ? _durationAtFraction(_dragFraction)
                      : null,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: widget.position != null
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.end,
            children: [
              if (widget.position != null)
                Text(
                  'Pos ${widget.position!.order.toString().padLeft(2, '0')} · '
                  'Row ${widget.position!.row.toString().padLeft(2, '0')}',
                  style: style,
                ),
              Text(
                _isDragging
                    ? _durationAtFraction(_dragFraction)
                    : widget.total > Duration.zero
                    ? '${_fmt(widget.elapsed)} / ${_fmt(widget.total)}'
                    : _fmt(widget.elapsed),
                style: style,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeekBarPaint extends StatelessWidget {
  final double fraction;
  final Color accent;
  final Color accentBright;
  final Color surfaceContainer;
  final String? timeText;

  const _SeekBarPaint({
    required this.fraction,
    required this.accent,
    required this.accentBright,
    required this.surfaceContainer,
    this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SeekBarPainter(
        fraction: fraction,
        accent: accent,
        accentBright: accentBright,
        surfaceContainer: surfaceContainer,
        timeText: timeText,
      ),
    );
  }
}

class _SeekBarPainter extends CustomPainter {
  final double fraction;
  final Color accent;
  final Color accentBright;
  final Color surfaceContainer;
  final String? timeText;

  _SeekBarPainter({
    required this.fraction,
    required this.accent,
    required this.accentBright,
    required this.surfaceContainer,
    this.timeText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barHeight = 8.0;
    const inset = 12.0;
    final barY = (size.height - barHeight) / 2;
    final barLeft = inset;
    final barRight = size.width - inset;
    final barWidth = barRight - barLeft;
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(barLeft, barY, barWidth, barHeight),
      const Radius.circular(4),
    );

    if (barWidth <= 0) return;

    // Background track
    final bgPaint = Paint()
      ..color = surfaceContainer
      ..style = PaintingStyle.fill;
    canvas.drawRRect(barRect, bgPaint);

    // Played portion with gradient fill
    if (fraction > 0) {
      final playedWidth = barWidth * fraction;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(barLeft, 0, playedWidth, size.height));
      final gradient = LinearGradient(colors: [accent, accentBright]);
      final fillPaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(barLeft, 0, barWidth, size.height),
        )
        ..style = PaintingStyle.fill;
      canvas.drawRRect(barRect, fillPaint);
      canvas.restore();
    }

    // Thumb
    final thumbX = barLeft + barWidth * fraction;
    final thumbCenter = Offset(
      thumbX.clamp(barLeft, barRight),
      size.height / 2,
    );

    // Glow behind thumb
    final glowPaint = Paint()
      ..color = accentBright.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(thumbCenter, 14, glowPaint);

    // Outer ring
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(thumbCenter, 9, ringPaint);

    // Inner dot
    final thumbPaint = Paint()
      ..color = accentBright
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, 6, thumbPaint);

    // Time tooltip above thumb during drag
    if (timeText != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: timeText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      const padH = 8.0;
      const padV = 4.0;
      final tw = tp.width + padH * 2;
      final th = tp.height + padV * 2;
      final tx = (thumbCenter.dx - tw / 2)
          .clamp(2.0, size.width - tw - 2)
          .toDouble();
      final ty = thumbCenter.dy - 22 - th;
      final tooltipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tx, ty, tw, th),
        const Radius.circular(4),
      );

      final tooltipBg = Paint()
        ..color = accent.withValues(alpha: 0.92)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(tooltipRect, tooltipBg);

      final arrowPath = Path()
        ..moveTo(thumbCenter.dx - 4, ty + th)
        ..lineTo(thumbCenter.dx, ty + th + 5)
        ..lineTo(thumbCenter.dx + 4, ty + th)
        ..close();
      canvas.drawPath(arrowPath, tooltipBg);

      tp.paint(
        canvas,
        Offset(tx + (tw - tp.width) / 2, ty + (th - tp.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_SeekBarPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.timeText != timeText;
}
