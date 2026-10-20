import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../sleep_labels.dart';
import '../sleep_recorder.dart';

/// Returns the chosen recording length in minutes, or null when cancelled.
class SfSleepDurationDialog extends StatefulWidget {
  const SfSleepDurationDialog({super.key, required this.initialMinutes});

  final int initialMinutes;

  static Future<int?> show(BuildContext context, {required int initial}) =>
      showDialog<int>(
        context: context,
        builder: (_) => SfSleepDurationDialog(initialMinutes: initial),
      );

  @override
  State<SfSleepDurationDialog> createState() => _SfSleepDurationDialogState();
}

class _SfSleepDurationDialogState extends State<SfSleepDurationDialog> {
  static const _minuteStep = 5;

  late int _hours = widget.initialMinutes ~/ 60;
  late int _minutes = (widget.initialMinutes % 60) ~/ _minuteStep * _minuteStep;

  int get _total => (_hours * 60 + _minutes).clamp(
    SleepRecorder.minDurationMinutes,
    SleepRecorder.maxDurationMinutes,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ResponsiveAlertDialog(
      title: Text(l10n.sfSleepTimerCustomTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Field(
                label: l10n.sfSleepTimerHoursLabel,
                value: _hours,
                values: [
                  for (
                    var h = 0;
                    h <= SleepRecorder.maxDurationMinutes ~/ 60;
                    h++
                  )
                    h,
                ],
                onChanged: (v) => setState(() => _hours = v),
              ),
              _Field(
                label: l10n.sfSleepTimerMinutesLabel,
                value: _minutes,
                values: [for (var m = 0; m < 60; m += _minuteStep) m],
                onChanged: (v) => setState(() => _minutes = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sleepTimerLabel(l10n, _total),
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _total),
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        DropdownButton<int>(
          value: value,
          items: [
            for (final v in values)
              DropdownMenuItem(value: v, child: Text('$v')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
