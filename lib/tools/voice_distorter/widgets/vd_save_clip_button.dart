import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../helpers/file_save_helper.dart';
import '../../../l10n/app_localizations.dart';
import '../voice_distorter_state.dart';

/// Renders the clip with the active effect and hands it to the platform save
/// dialog. Rendering is real time and audible — the button shows a spinner and
/// stays disabled while it runs.
class VdSaveClipButton extends StatelessWidget {
  const VdSaveClipButton({super.key});

  Future<void> _save(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final Uint8List? bytes = await context
        .read<VoiceDistorterState>()
        .renderCurrentClip();
    if (!context.mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.voiceDistorterExportFailed)));
      return;
    }
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: 'voice_clip.wav',
      bytes: bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<VoiceDistorterState>();

    if (state.isExporting) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(l10n.voiceDistorterExporting),
      );
    }

    return OutlinedButton.icon(
      onPressed: state.isPlaying ? null : () => _save(context),
      icon: const Icon(Icons.download_outlined),
      label: Text(l10n.voiceDistorterSaveClip),
    );
  }
}
