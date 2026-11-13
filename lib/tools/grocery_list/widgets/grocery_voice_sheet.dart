import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Dictate grocery items; returns the (editable) transcript.
class GroceryVoiceSheet extends StatefulWidget {
  const GroceryVoiceSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const GroceryVoiceSheet(),
    );
  }

  @override
  State<GroceryVoiceSheet> createState() => _GroceryVoiceSheetState();
}

class _GroceryVoiceSheetState extends State<GroceryVoiceSheet> {
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
        debugLog('[GroceryVoiceSheet] ${e.errorMsg}');
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (!ready) {
      setState(() => _available = false);
      return;
    }
    _prefix = _text.text.trim().isEmpty ? '' : '${_text.text.trim()}, ';
    await _speech.listen(
      onResult: (result) {
        // Late results after a stop must not overwrite typed corrections.
        if (!mounted || session != _session) return;
        _text.text = '$_prefix${result.recognizedWords}';
      },
      listenOptions: SpeechListenOptions(
        localeId: languageCode == 'de' ? 'de_DE' : 'en_US',
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
            Text(l10n.groceryVoiceTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              _available ? l10n.groceryVoiceHint : l10n.groceryVoiceUnavailable,
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
                    ? l10n.groceryVoiceStop
                    : l10n.groceryVoiceStart,
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
                hintText: l10n.groceryVoiceExample,
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
