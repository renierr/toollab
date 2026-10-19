import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../memo/memo_recorder.dart';
import '../sf_format.dart';

/// Elapsed time, scrolling input envelope and a dBFS meter of a running memo.
/// Repaints from [MemoLevels] alone, so the page does not rebuild per tick.
class SfMemoLevelView extends StatelessWidget {
  final MemoLevels levels;
  final bool paused;

  const SfMemoLevelView({
    super.key,
    required this.levels,
    required this.paused,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final Color active = paused ? AppTheme.statusAmber : AppTheme.statusRed;

    return ListenableBuilder(
      listenable: levels,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            formatClock(levels.elapsed),
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: paused ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: CustomPaint(
              painter: _EnvelopePainter(
                levels: levels,
                color: active,
                baseline: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 8,
            child: CustomPaint(
              painter: _MeterPainter(
                level: MemoLevels.norm(levels.db),
                peak: MemoLevels.norm(levels.peakDb),
                track: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                l10n.sfMemoPeak(levels.peakDb.toStringAsFixed(1)),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              if (levels.clipped)
                InkWell(
                  onTap: levels.resetPeak,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: AppTheme.statusRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.sfMemoClipping,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.statusRed,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnvelopePainter extends CustomPainter {
  final MemoLevels levels;
  final Color color;
  final Color baseline;

  _EnvelopePainter({
    required this.levels,
    required this.color,
    required this.baseline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );
    const n = MemoLevels.historyLength;
    final step = size.width / n;
    final bar = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (step * 0.6).clamp(1.0, 4.0);
    for (int i = 0; i < n; i++) {
      final v = levels.bar(i);
      if (v <= 0) continue;
      final x = i * step + step / 2;
      final h = (v * mid).clamp(1.0, mid);
      canvas.drawLine(Offset(x, mid - h), Offset(x, mid + h), bar);
    }
  }

  @override
  bool shouldRepaint(covariant _EnvelopePainter old) => true;
}

class _MeterPainter extends CustomPainter {
  final double level;
  final double peak;
  final Color track;

  _MeterPainter({required this.level, required this.peak, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = track,
    );
    final w = level * size.width;
    if (w > 0) {
      final color = level > 0.95
          ? AppTheme.statusRed
          : level > 0.8
          ? AppTheme.statusAmber
          : AppTheme.statusGreen;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, size.height), radius),
        Paint()..color = color,
      );
    }
    final px = (peak * size.width).clamp(1.0, size.width - 1);
    canvas.drawLine(
      Offset(px, 0),
      Offset(px, size.height),
      Paint()
        ..color = peak > 0.95 ? AppTheme.statusRed : AppTheme.statusAmber
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _MeterPainter old) =>
      old.level != level || old.peak != peak || old.track != track;
}
