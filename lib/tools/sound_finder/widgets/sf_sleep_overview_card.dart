import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sleep_session_store.dart';
import '../sleep_sessions_state.dart';
import '../sound_finder_colors.dart';

class SfSleepOverviewCard extends StatelessWidget {
  const SfSleepOverviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sessions = context
        .select<SleepSessionsState, List<SleepSession>>((s) => s.sessions)
        .reversed
        .toList();
    final wav = sessions.fold(0, (a, s) => a + s.wavBytes);
    final json = sessions.fold(0, (a, s) => a + s.jsonBytes);
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sfSleepOverviewTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '${l10n.sfSleepOverviewSessions(sessions.length)} · '
              '${l10n.sfSleepStorage}: ${FormatHelper.fileSize(wav + json)}',
            ),
            Text(
              l10n.sfSleepStorageDetail(
                FormatHelper.fileSize(wav),
                FormatHelper.fileSize(json),
              ),
              style: theme.textTheme.bodySmall,
            ),
            if (sessions.length >= 2) ...[
              const SizedBox(height: 12),
              Text(l10n.sfSleepTrendTitle, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              SizedBox(
                height: 110,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TrendPainter(
                    values: [for (final s in sessions) s.data.events.length],
                    labels: [
                      for (final s in sessions)
                        '${s.startedAt.day}.${s.startedAt.month}.',
                    ],
                    labelColor: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.labels,
    required this.labelColor,
  });

  final List<int> values;
  final List<String> labels;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = math.max(1, values.reduce(math.max));
    final barW = size.width / values.length;
    final paint = Paint()..color = SoundFinderColors.indigo;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    // Skip labels when bars get narrower than a label.
    final labelEvery = math.max(1, (32 / barW).ceil());
    for (var i = 0; i < values.length; i++) {
      final h = values[i] / maxV * (size.height - 28);
      canvas.drawRect(
        Rect.fromLTWH(i * barW + 2, size.height - 14 - h, barW - 4, h),
        paint,
      );
      if (barW >= 18) {
        tp.text = TextSpan(
          text: '${values[i]}',
          style: TextStyle(fontSize: 9, color: labelColor),
        );
        tp.layout();
        tp.paint(
          canvas,
          Offset(i * barW + (barW - tp.width) / 2, size.height - 26 - h),
        );
      }
      if (i % labelEvery == 0) {
        tp.text = TextSpan(
          text: labels[i],
          style: TextStyle(fontSize: 9, color: labelColor),
        );
        tp.layout();
        tp.paint(canvas, Offset(i * barW + 2, size.height - 12));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values || old.labelColor != labelColor;
}
