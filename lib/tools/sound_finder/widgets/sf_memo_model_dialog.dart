import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import '../memo/memo_transcriber.dart';

/// Picks and downloads the Whisper model. Returns true once one is installed.
class SfMemoModelDialog extends StatefulWidget {
  const SfMemoModelDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SfMemoModelDialog(),
    );
    return ok ?? false;
  }

  @override
  State<SfMemoModelDialog> createState() => _SfMemoModelDialogState();
}

class _SfMemoModelDialogState extends State<SfMemoModelDialog> {
  late WhisperModel _choice =
      context.read<MemoTranscriber>().model ?? MemoTranscriber.recommendedModel;
  bool _failed = false;
  bool _cancelled = false;

  Future<void> _download() async {
    final transcriber = context.read<MemoTranscriber>();
    if (transcriber.model == _choice) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failed = false;
      _cancelled = false;
    });
    final ok = await transcriber.download(_choice);
    if (!mounted) return;
    if (ok || _cancelled) {
      Navigator.of(context).pop(transcriber.model != null);
    } else {
      setState(() => _failed = true);
    }
  }

  void _cancel() {
    final transcriber = context.read<MemoTranscriber>();
    if (transcriber.downloading != null) {
      _cancelled = true;
      transcriber.cancelDownload();
    } else {
      Navigator.of(context).pop(transcriber.model != null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final transcriber = context.watch<MemoTranscriber>();
    final busy = transcriber.downloading != null;
    final progress = transcriber.downloadProgress;

    return ResponsiveAlertDialog(
      title: Text(l10n.sfTranscriptModelTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.sfTranscriptModelHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            RadioGroup<WhisperModel>(
              groupValue: _choice,
              onChanged: (m) {
                if (!busy && m != null) setState(() => _choice = m);
              },
              child: Column(
                children: [
                  for (final model in MemoTranscriber.models)
                    RadioListTile<WhisperModel>(
                      value: model,
                      enabled: !busy,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        model == WhisperModel.small
                            ? l10n.sfTranscriptModelSmall
                            : l10n.sfTranscriptModelBase,
                      ),
                      subtitle: Text(
                        model == WhisperModel.small
                            ? l10n.sfTranscriptModelSmallHint(
                                MemoTranscriber.sizeMb(model),
                              )
                            : l10n.sfTranscriptModelBaseHint(
                                MemoTranscriber.sizeMb(model),
                              ),
                      ),
                      secondary: transcriber.model == model
                          ? const Icon(Icons.check_circle_outline)
                          : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SfTranscriptLanguageField(enabled: !busy),
            if (busy) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 6),
              Text(
                progress == null
                    ? l10n.sfTranscriptDownloading
                    : l10n.sfTranscriptDownloadingPercent(
                        (progress * 100).round(),
                      ),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (_failed) ...[
              const SizedBox(height: 12),
              Text(
                l10n.sfTranscriptDownloadFailed,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: Text(l10n.commonCancel)),
        FilledButton(
          onPressed: busy ? null : _download,
          child: Text(
            transcriber.model == _choice
                ? l10n.commonApply
                : l10n.sfTranscriptDownload,
          ),
        ),
      ],
    );
  }
}

/// Transcription language dropdown, shared by the model dialog and settings.
class SfTranscriptLanguageField extends StatelessWidget {
  final bool enabled;

  const SfTranscriptLanguageField({super.key, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final transcriber = context.watch<MemoTranscriber>();
    return DropdownButtonFormField<String>(
      initialValue: transcriber.language,
      decoration: InputDecoration(
        labelText: l10n.sfTranscriptLanguage,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final code in MemoTranscriber.languages)
          DropdownMenuItem(
            value: code,
            child: Text(switch (code) {
              'de' => l10n.sfTranscriptLanguageDe,
              'en' => l10n.sfTranscriptLanguageEn,
              _ => l10n.sfTranscriptLanguageAuto,
            }),
          ),
      ],
      onChanged: enabled
          ? (code) {
              if (code != null) transcriber.setLanguage(code);
            }
          : null,
    );
  }
}
