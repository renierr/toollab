import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../memo/memo_recorder.dart';
import '../memo/memo_settings.dart';
import '../memo/memo_transcriber.dart';
import '../sf_format.dart';
import 'sf_memo_model_dialog.dart';
import 'sf_mic_selector.dart';

/// Capture options of the memo recorder. Changes apply to the next memo.
class SfMemoSettingsDialog extends StatelessWidget {
  const SfMemoSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final memo = context.watch<MemoRecorder>();
    final s = memo.settings;
    void update(MemoSettings next) =>
        context.read<MemoRecorder>().updateSettings(next);

    return ResponsiveAlertDialog(
      title: Text(l10n.sfMemoSettingsTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (memo.isActive) ...[
              Text(
                l10n.sfMemoSettingsNextRecording,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            SfMicSelector(
              devices: memo.devices,
              selectedId: s.deviceId,
              onChanged: (d) => update(s.copyWith(deviceId: (value: d?.id))),
              onRefresh: () => context.read<MemoRecorder>().refreshDevices(),
            ),
            const SizedBox(height: 16),
            Text(l10n.sfMemoFormat, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<MemoFormat>(
              segments: [
                for (final f in MemoFormat.values)
                  ButtonSegment(
                    value: f,
                    label: Text(f.label),
                    enabled: memo.supportedFormats.contains(f),
                  ),
              ],
              selected: {s.format},
              showSelectedIcon: false,
              onSelectionChanged: (v) => update(s.copyWith(format: v.first)),
            ),
            const SizedBox(height: 4),
            Text(
              s.format == MemoFormat.wav
                  ? l10n.sfMemoFormatWavHint
                  : l10n.sfMemoFormatFlacHint,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _DropdownRow<int>(
              icon: Icons.speed,
              label: l10n.sfSampleRate,
              value: s.sampleRate,
              items: {
                for (final r in MemoSettings.sampleRates) r: formatRate(r),
              },
              onChanged: (v) => update(s.copyWith(sampleRate: v)),
            ),
            _DropdownRow<int>(
              icon: Icons.surround_sound_outlined,
              label: l10n.sfMemoChannels,
              value: s.channels,
              items: {1: l10n.sfMemoMono, 2: l10n.sfMemoStereo},
              onChanged: (v) => update(s.copyWith(channels: v)),
            ),
            if (Platform.isAndroid)
              _DropdownRow<MemoMicSource>(
                icon: Icons.settings_voice_outlined,
                label: l10n.sfMemoSource,
                value: s.source,
                items: {
                  MemoMicSource.standard: l10n.sfMemoSourceStandard,
                  MemoMicSource.camcorder: l10n.sfMemoSourceCamcorder,
                  MemoMicSource.voice: l10n.sfMemoSourceVoice,
                  MemoMicSource.raw: l10n.sfMemoSourceRaw,
                },
                onChanged: (v) => update(s.copyWith(source: v)),
              ),
            _DropdownRow<int>(
              icon: Icons.timer_outlined,
              label: l10n.sfMaxRecordLength,
              value: s.maxSeconds,
              items: {
                for (final m in MemoSettings.maxLengths)
                  m: m == 0
                      ? l10n.sfMemoUnlimited
                      : l10n.sfMemoMinutes(m ~/ 60),
              },
              onChanged: (v) => update(s.copyWith(maxSeconds: v)),
            ),
            const SizedBox(height: 8),
            Text(l10n.sfMemoProcessing, style: theme.textTheme.titleSmall),
            Text(l10n.sfMemoProcessingHint, style: theme.textTheme.bodySmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.sfNoiseSuppress),
              value: s.noiseSuppress,
              onChanged: (v) => update(s.copyWith(noiseSuppress: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.sfEchoCancel),
              value: s.echoCancel,
              onChanged: (v) => update(s.copyWith(echoCancel: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.sfAutoGain),
              value: s.autoGain,
              onChanged: (v) => update(s.copyWith(autoGain: v)),
            ),
            const SizedBox(height: 8),
            const _TranscriptionSection(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  const _DropdownRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Flexible(
            child: DropdownButton<T>(
              isExpanded: true,
              value: items.containsKey(value) ? value : null,
              items: [
                for (final e in items.entries)
                  DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptionSection extends StatelessWidget {
  const _TranscriptionSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final transcriber = context.watch<MemoTranscriber>();
    final model = transcriber.model;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.sfTranscriptSection, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          model == null
              ? l10n.sfTranscriptNoModel
              : l10n.sfTranscriptModelInstalled(
                  model.modelName,
                  MemoTranscriber.sizeMb(model),
                ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        const SfTranscriptLanguageField(),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => SfMemoModelDialog.show(context),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(
                model == null
                    ? l10n.sfTranscriptChooseModel
                    : l10n.sfTranscriptChangeModel,
              ),
            ),
            if (model != null)
              TextButton.icon(
                onPressed: transcriber.removeModel,
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                label: Text(
                  l10n.sfTranscriptRemoveModel,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
