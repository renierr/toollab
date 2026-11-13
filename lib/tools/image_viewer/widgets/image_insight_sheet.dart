import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/chat_ai/chat_ai_state.dart';
import 'package:tool_lab/widgets/genai_status_banner.dart';

import '../utils/image_editor_controller.dart';

/// Image labels (all Android devices) and an alt-text description (Gemini Nano).
class ImageInsightSheet extends StatefulWidget {
  final ImageEditorController controller;

  const ImageInsightSheet({super.key, required this.controller});

  static Future<void> show(
    BuildContext context,
    ImageEditorController controller,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ImageInsightSheet(controller: controller),
    );
  }

  @override
  State<ImageInsightSheet> createState() => _ImageInsightSheetState();
}

class _ImageInsightSheetState extends State<ImageInsightSheet> {
  late final Future<List<ImageLabel>> _labels = widget.controller.labelImage();
  StreamSubscription<String>? _subscription;
  String _description = '';
  bool _describing = false;
  String? _error;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _describe() async {
    final ai = context.read<ChatAiState>();
    final language = Localizations.localeOf(context).languageCode == 'de'
        ? 'German'
        : 'English';
    await _subscription?.cancel();
    setState(() {
      _description = '';
      _error = null;
      _describing = true;
    });
    try {
      final bytes = await widget.controller.previewJpg();
      if (!mounted) return;
      _subscription = ai
          .streamImageTask(
            instruction:
                'Describe this image in two or three sentences so it can '
                'serve as alt text. Answer in $language and reply only with '
                'the description.',
            imageData: bytes,
          )
          .listen(
            (chunk) => setState(() => _description += chunk),
            onError: (Object e) => _fail(e),
            onDone: () {
              if (mounted) {
                setState(() {
                  _describing = false;
                  _description = _description.trim();
                });
              }
            },
          );
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object e) {
    errorLog('[ImageInsightSheet] Description failed: $e');
    if (!mounted) return;
    setState(() {
      _error = e.toString();
      _describing = false;
    });
  }

  Future<void> _copy(String text) async {
    final l10n = AppLocalizations.of(context);
    await ClipboardHelper.setText(text);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.textAiCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ai = context.watch<ChatAiState>();
    final error = _error;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.imgViewInsightTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            if (Platform.isAndroid) ...[
              _SectionTitle(title: l10n.imgViewLabels),
              FutureBuilder<List<ImageLabel>>(
                future: _labels,
                builder: (context, snapshot) => _LabelChips(
                  labels: snapshot.data,
                  failed: snapshot.hasError,
                  onCopy: _copy,
                ),
              ),
              const SizedBox(height: 20),
            ],
            _SectionTitle(title: l10n.imgViewDescription),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GenAiStatusBanner(
                status: ai.featureStatus,
                downloadProgress: ai.downloadProgress,
                onDownload: ai.downloadModel,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: ai.isGenerativeAvailable && !_describing
                      ? _describe
                      : null,
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: Text(l10n.imgViewDescribe),
                ),
                if (_description.isNotEmpty && !_describing)
                  TextButton.icon(
                    onPressed: () => _copy(_description),
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(l10n.commonCopy),
                  ),
              ],
            ),
            if (_describing && _description.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              )
            else if (_description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SelectableText(
                  _description,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _LabelChips extends StatelessWidget {
  final List<ImageLabel>? labels;
  final bool failed;
  final ValueChanged<String> onCopy;

  const _LabelChips({
    required this.labels,
    required this.failed,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final labels = this.labels;
    if (failed) {
      return Text(
        l10n.imgViewLabelsFailed,
        style: TextStyle(color: theme.colorScheme.error),
      );
    }
    if (labels == null) return const LinearProgressIndicator();
    if (labels.isEmpty) {
      return Text(l10n.imgViewNoLabels, style: theme.textTheme.bodyMedium);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final label in labels)
          Chip(
            label: Text('${label.label} ${(label.confidence * 100).round()}%'),
            visualDensity: VisualDensity.compact,
          ),
        IconButton(
          tooltip: l10n.commonCopy,
          onPressed: () => onCopy(labels.map((l) => l.label).join(', ')),
          icon: const Icon(Icons.copy, size: 18),
        ),
      ],
    );
  }
}
