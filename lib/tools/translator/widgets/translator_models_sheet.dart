import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/translation/translation_service.dart';

import '../translator_state.dart';

/// Lists the offline language models; downloaded ones first.
class TranslatorModelsSheet extends StatefulWidget {
  const TranslatorModelsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const TranslatorModelsSheet(),
    );
  }

  @override
  State<TranslatorModelsSheet> createState() => _TranslatorModelsSheetState();
}

class _TranslatorModelsSheetState extends State<TranslatorModelsSheet> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<TranslatorState>().refreshModels());
  }

  Future<void> _change(TranslateLanguage language, bool download) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<TranslatorState>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = download
        ? await state.downloadModel(language)
        : await state.deleteModel(language);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.translatorModelChangeFailed(
              TranslationService.displayName(language),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<TranslatorState>();
    final models = state.models;
    final languages = [...TranslationService.languages];
    if (models != null) {
      languages.sort((a, b) {
        final byState =
            (models[b] == true ? 1 : 0) - (models[a] == true ? 1 : 0);
        return byState != 0 ? byState : a.name.compareTo(b.name);
      });
    }

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translatorModelsTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.translatorModelsHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: models == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: languages.length,
                      itemBuilder: (context, i) {
                        final language = languages[i];
                        return _ModelTile(
                          language: language,
                          downloaded: models[language] == true,
                          busy: state.isModelBusy(language),
                          onChange: (download) => _change(language, download),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  final TranslateLanguage language;
  final bool downloaded;
  final bool busy;
  final ValueChanged<bool> onChange;

  const _ModelTile({
    required this.language,
    required this.downloaded,
    required this.busy,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final removable = TranslationService.isRemovable(language);
    return ListTile(
      leading: Icon(
        downloaded ? Icons.offline_pin : Icons.cloud_outlined,
        color: downloaded ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(TranslationService.displayName(language)),
      subtitle: Text(
        !removable
            ? l10n.translatorModelBuiltIn
            : downloaded
            ? l10n.translatorModelDownloaded
            : l10n.translatorModelNotDownloaded,
      ),
      trailing: busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : !removable
          ? null
          : downloaded
          ? IconButton(
              tooltip: l10n.commonDelete,
              onPressed: () => onChange(false),
              icon: const Icon(Icons.delete_outline),
            )
          : IconButton(
              tooltip: l10n.translatorModelDownload,
              onPressed: () => onChange(true),
              icon: const Icon(Icons.download_outlined),
            ),
    );
  }
}
