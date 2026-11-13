import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/text_to_speech_service.dart';
import 'package:tool_lab/services/translation/translation_service.dart';

import '../translator_state.dart';

class TranslatorOutputCard extends StatelessWidget {
  const TranslatorOutputCard({super.key});

  Future<void> _speak(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<TranslatorState>();
    final messenger = ScaffoldMessenger.of(context);
    final target = state.target;
    final error = await state.toggleSpeech();
    if (error == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error == TextToSpeechError.languageUnavailable
              ? l10n.translatorSpeechLanguageMissing(
                  TranslationService.displayName(target),
                )
              : l10n.translatorSpeechUnavailable,
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ClipboardHelper.setText(text);
    messenger.showSnackBar(SnackBar(content: Text(l10n.translatorCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<TranslatorState>();
    final output = state.output;
    final hasOutput = output.trim().isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StatusLine(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: hasOutput
                    ? SelectableText(output, style: theme.textTheme.bodyLarge)
                    : Text(
                        l10n.translatorOutputHint,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (TextToSpeechService.isSupported)
                  IconButton(
                    tooltip: state.speaking
                        ? l10n.translatorStopSpeaking
                        : l10n.translatorSpeak,
                    onPressed: hasOutput || state.speaking
                        ? () => _speak(context)
                        : null,
                    icon: Icon(
                      state.speaking ? Icons.stop : Icons.volume_up_outlined,
                    ),
                  ),
                IconButton(
                  tooltip: l10n.commonCopy,
                  onPressed: hasOutput ? () => _copy(context, output) : null,
                  icon: const Icon(Icons.copy),
                ),
                IconButton(
                  tooltip: l10n.commonShare,
                  onPressed: hasOutput
                      ? () =>
                            SharePlus.instance.share(ShareParams(text: output))
                      : null,
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<TranslatorState>();
    final downloading = state.downloading;
    final text = switch (state.status) {
      TranslatorStatus.idle => null,
      TranslatorStatus.detecting => l10n.translatorDetecting,
      TranslatorStatus.downloading => l10n.translatorDownloadingModel(
        downloading == null ? '' : TranslationService.displayName(downloading),
      ),
      TranslatorStatus.translating => l10n.translatorTranslating,
      TranslatorStatus.undetermined => l10n.translatorUndetermined,
      TranslatorStatus.failed => l10n.translatorFailed(state.error ?? ''),
    };
    if (text == null) return const SizedBox.shrink();
    final problem =
        state.status == TranslatorStatus.failed ||
        state.status == TranslatorStatus.undetermined;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (state.busy) ...[
            const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: problem
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
