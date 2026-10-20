import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../audio/db_scale.dart';
import '../sleep_recorder.dart';
import '../sound_finder_state.dart';
import 'sf_sleep_duration_picker.dart';

class SfSleepSetupPanel extends StatelessWidget {
  const SfSleepSetupPanel({super.key});

  static const double _minDb = -60;
  static const double _maxDb = -10;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sleep = context.watch<SoundFinderState>().sleep;
    final thrDb = ampToDb(sleep.threshold).clamp(_minDb, _maxDb);
    final peak = sleep.lastMaxAbs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SfSleepDurationPicker(),
        const SizedBox(height: 8),
        Text(
          l10n.sfSleepThresholdLabel(
            thrDb.toStringAsFixed(1),
            sleep.threshold.toStringAsFixed(4),
          ),
        ),
        Slider(
          value: thrDb,
          min: _minDb,
          max: _maxDb,
          divisions: 50,
          label: '${thrDb.toStringAsFixed(1)} dB',
          onChanged: (v) => sleep.setThreshold(
            dbToAmp(
              v,
            ).clamp(SleepRecorder.minThreshold, SleepRecorder.maxThreshold),
          ),
        ),
        Text(
          l10n.sfSleepLastPeak(
            ampToDb(peak, floor: _minDb).toStringAsFixed(1),
            peak.toStringAsFixed(4),
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.auto_fix_high_outlined),
          label: Text(l10n.sfSleepCalibrate),
          onPressed: sleep.calibrate,
        ),
        SwitchListTile(
          title: Text(l10n.sfSleepAdaptive),
          value: sleep.adaptive,
          onChanged: sleep.setAdaptive,
        ),
        Text(
          l10n.sfSleepCaptureNote,
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.bedtime_outlined),
          label: Text(l10n.sfSleepStart),
          onPressed: sleep.start,
        ),
      ],
    );
  }
}
