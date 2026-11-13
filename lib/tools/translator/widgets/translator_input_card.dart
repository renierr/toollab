import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/voice_input_sheet.dart';

import '../translator_ocr.dart';
import '../translator_state.dart';

class TranslatorInputCard extends StatefulWidget {
  const TranslatorInputCard({super.key});

  @override
  State<TranslatorInputCard> createState() => _TranslatorInputCardState();
}

class _TranslatorInputCardState extends State<TranslatorInputCard> {
  late final TextEditingController _controller;
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<TranslatorState>().input,
    )..addListener(_onTyped);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final input = context.watch<TranslatorState>().input;
    if (_controller.text != input) {
      _controller.value = TextEditingValue(
        text: input,
        selection: TextSelection.collapsed(offset: input.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTyped() => context.read<TranslatorState>().setInput(_controller.text);

  Future<void> _readImage(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<TranslatorState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (image == null || !mounted) return;
      setState(() => _reading = true);
      final text = await TranslatorOcr.readImage(image.path);
      if (text.trim().isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.translatorNoTextFound)),
        );
        return;
      }
      state.setInput(text, immediate: true);
    } catch (e) {
      errorLog('[Translator] Reading image failed: $e');
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.translatorImageFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _dictate() async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<TranslatorState>();
    final text = await VoiceInputSheet.show(
      context,
      title: l10n.translatorVoiceTitle,
      hint: l10n.translatorVoiceHint,
      example: l10n.translatorInputHint,
      localeId: state.source?.bcpCode,
    );
    if (text != null && text.trim().isNotEmpty) {
      state.setInput(text.trim(), immediate: true);
    }
  }

  Future<void> _paste() async {
    final text = await ClipboardHelper.getText();
    if (text == null || text.isEmpty || !mounted) return;
    context.read<TranslatorState>().setInput(text, immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasInput = context.select<TranslatorState, bool>(
      (s) => s.input.isNotEmpty,
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: l10n.translatorInputHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            if (_reading) const LinearProgressIndicator(),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                IconButton(
                  tooltip: l10n.translatorFromCamera,
                  onPressed: _reading
                      ? null
                      : () => _readImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
                IconButton(
                  tooltip: l10n.translatorFromImage,
                  onPressed: _reading
                      ? null
                      : () => _readImage(ImageSource.gallery),
                  icon: const Icon(Icons.image_outlined),
                ),
                IconButton(
                  tooltip: l10n.translatorVoiceTitle,
                  onPressed: _dictate,
                  icon: const Icon(Icons.mic_none),
                ),
                IconButton(
                  tooltip: l10n.commonPaste,
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste),
                ),
                IconButton(
                  tooltip: l10n.commonClear,
                  onPressed: hasInput
                      ? context.read<TranslatorState>().clear
                      : null,
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
