import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../sound_finder_state.dart';

/// Captures a raw (gained) mic clip and exports it as a WAV via the shared file
/// save flow. Shown alongside the live-analysis modes.
class SfClipRecorder extends StatelessWidget {
  const SfClipRecorder({super.key});

  static String _mmss(double seconds) {
    final int total = seconds.floor();
    final int m = total ~/ 60;
    final int s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _stopAndSave(BuildContext context, AppLocalizations l10n) async {
    final bytes = context.read<SoundFinderState>().stopRecordingToWav();
    if (bytes == null || !context.mounted) return;

    final DateTime now = DateTime.now();
    final String stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: 'sound-clip-$stamp.wav',
      bytes: bytes,
      successMessageAndroid: l10n.sfClipSavedAndroid,
      successMessageGeneralBuilder: (path) => l10n.sfClipSaved(path),
      errorMessageBuilder: (_) => l10n.sfClipSaveError,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SoundFinderState>();

    if (state.micStatus != MicStatus.running) return const SizedBox.shrink();

    final bool recording = state.isRecording;

    if (!recording) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => context.read<SoundFinderState>().startRecording(),
          icon: const Icon(
            Icons.fiber_manual_record,
            color: AppTheme.statusRed,
          ),
          label: Text(l10n.sfRecordClip),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: () => _stopAndSave(context, l10n),
          icon: const Icon(Icons.stop),
          label: Text(l10n.sfStopAndSave),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.fiber_manual_record,
              size: 14,
              color: AppTheme.statusRed,
            ),
            const SizedBox(width: 6),
            Text(
              '${_mmss(state.recordedSeconds)} / '
              '${_mmss(SoundFinderState.maxRecordSeconds.toDouble())}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
