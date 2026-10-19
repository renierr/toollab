import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sleep_labels.dart';
import '../sleep_session_store.dart';

class SfSleepReport extends StatelessWidget {
  const SfSleepReport({super.key, required this.session});

  final SleepSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = session.data;
    final events = data.events;
    final items = <(String, String)>[
      (l10n.sfSleepDuration, sleepDuration(data.duration)),
      (l10n.sfSleepRecorded, sleepDuration(data.recordedDuration)),
      (l10n.sfSleepChunks, '${events.length}'),
      if (events.isNotEmpty) ...[
        (l10n.sfSleepLoudest, '${data.loudestDb.toStringAsFixed(1)} dB'),
        (l10n.sfSleepAverage, '${data.avgPeakDb.toStringAsFixed(1)} dB'),
        (l10n.sfSleepFirstEvent, sleepClock(events.first.startedAt)),
        (l10n.sfSleepLastEvent, sleepClock(events.last.startedAt)),
      ],
      (l10n.sfSleepAudioData, FormatHelper.fileSize(session.wavBytes)),
      (l10n.sfSleepJsonData, FormatHelper.fileSize(session.jsonBytes)),
      (l10n.sfSleepTotalData, FormatHelper.fileSize(session.totalBytes)),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final (label, value) in items) _Stat(label, value)],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
