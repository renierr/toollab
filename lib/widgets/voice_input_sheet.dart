import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Dictation sheet; returns the (editable) transcript.
class VoiceInputSheet extends StatefulWidget {
  final String title;
  final String hint;
  final String example;

  /// Speech locale such as `de_DE`; null follows the app language.
  final String? localeId;

  /// Joins a new dictation to text already in the field.
  final String separator;

  const VoiceInputSheet({
    super.key,
    required this.title,
    required this.hint,
    required this.example,
    this.localeId,
    this.separator = ' ',
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String hint,
    required String example,
    String? localeId,
    String separator = ' ',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => VoiceInputSheet(
        title: title,
        hint: hint,
        example: example,
        localeId: localeId,
        separator: separator,
      ),
    );
  }

  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends State<VoiceInputSheet> {
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _text = TextEditingController();
  bool _available = true;
  bool _listening = false;
  String _prefix = '';
  int _session = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _speech.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final languageCode = Localizations.localeOf(context).languageCode;
    final session = ++_session;
    final ready = await _speech.initialize(
      options: [SpeechToText.androidNoBluetooth],
      onStatus: (status) {
        if (mounted) setState(() => _listening = _speech.isListening);
      },
      onError: (SpeechRecognitionError e) {
        debugLog('[VoiceInputSheet] ${e.errorMsg}');
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (!ready) {
      setState(() => _available = false);
      return;
    }
    _prefix = _text.text.trim().isEmpty
        ? ''
        : '${_text.text.trim()}${widget.separator}';
    await _speech.listen(
      onResult: (result) {
        // Late results after a stop must not overwrite typed corrections.
        if (!mounted || session != _session) return;
        _text.text = '$_prefix${result.recognizedWords}';
      },
      listenOptions: SpeechListenOptions(
        localeId: widget.localeId ?? (languageCode == 'de' ? 'de_DE' : 'en_US'),
        listenMode: ListenMode.dictation,
        partialResults: true,
        pauseFor: const Duration(seconds: 4),
        listenFor: const Duration(minutes: 1),
      ),
    );
    if (mounted) setState(() => _listening = true);
  }

  Future<void> _stop() async {
    _session++;
    await _speech.cancel();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _toggle() => _listening ? _stop() : _start();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              _available ? widget.hint : l10n.voiceInputUnavailable,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _available
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: IconButton.filled(
                iconSize: 36,
                onPressed: _available ? _toggle : null,
                icon: Icon(_listening ? Icons.stop : Icons.mic),
                tooltip: _listening
                    ? l10n.voiceInputStop
                    : l10n.voiceInputStart,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              minLines: 2,
              maxLines: 5,
              onTap: () {
                if (_listening) _stop();
              },
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: widget.example,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                ListenableBuilder(
                  listenable: _text,
                  builder: (context, _) => FilledButton(
                    onPressed: _text.text.trim().isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_text.text),
                    child: Text(l10n.commonApply),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
