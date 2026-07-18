import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart' show XTypeGroup, openFile;
import 'package:tool_lab/helpers/wav_decoder.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sound_finder_colors.dart';
import '../sound_finder_state.dart';
import '../morse/morse_decoder.dart';
import 'sf_permission_notice.dart';

class SfMorseAnalyser extends StatefulWidget {
  const SfMorseAnalyser({super.key});

  @override
  State<SfMorseAnalyser> createState() => _SfMorseAnalyserState();
}

class _SfMorseAnalyserState extends State<SfMorseAnalyser> {
  bool _isDecodingFile = false;
  String _fileDecodeResult = '';
  String? _loadedFileName;

  Future<void> _loadAndDecodeWav(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'WAV Audio',
      extensions: ['wav'],
      mimeTypes: ['audio/wav', 'audio/x-wav'],
    );

    try {
      final file = await openFile(acceptedTypeGroups: const [typeGroup]);
      if (file == null) return;

      setState(() {
        _isDecodingFile = true;
        _loadedFileName = file.name;
        _fileDecodeResult = '';
      });

      final bytes = await file.readAsBytes();
      final decoded = WavDecoder.decode(bytes);

      if (decoded == null) {
        throw Exception(
          'Failed to parse WAV audio format. Make sure it is PCM 16-bit.',
        );
      }

      final text = await MorseDecoder.decode(
        samples: decoded.samples,
        sampleRate: decoded.sampleRate,
      );

      setState(() {
        _fileDecodeResult = text.isNotEmpty
            ? text
            : '(No Morse signals detected in audio)';
        _isDecodingFile = false;
      });
    } catch (e) {
      setState(() {
        _fileDecodeResult = 'Error: ${e.toString()}';
        _isDecodingFile = false;
      });
    }
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SoundFinderState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Signal indicator
        Center(
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state.morseFlashActive
                      ? SoundFinderColors.violet
                      : theme.colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: state.morseFlashActive
                        ? SoundFinderColors.violet.withValues(alpha: 0.8)
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                    width: 4,
                  ),
                  boxShadow: [
                    if (state.morseFlashActive)
                      BoxShadow(
                        color: SoundFinderColors.violet.withValues(alpha: 0.6),
                        blurRadius: 24,
                        spreadRadius: 8,
                      ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.wifi_tethering,
                    size: 36,
                    color: state.morseFlashActive
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.morseListening
                    ? l10n.sfMorseLiveListening
                    : 'Signal Detector',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: state.morseListening
                      ? SoundFinderColors.violet
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: state.morseListening
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Live Listening Controls
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.15),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (state.morseListening)
                      FilledButton.icon(
                        onPressed: () => state.stopMorseListening(),
                        icon: const Icon(Icons.stop),
                        label: Text(l10n.sfStop),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                        ),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () => state.startMorseListening(),
                        icon: const Icon(Icons.mic),
                        label: const Text('Live Translate'),
                      ),

                    if (state.morseDecodedText.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.outlined(
                            onPressed: () => _copyToClipboard(
                              context,
                              state.morseDecodedText,
                              'Decoded text copied to clipboard',
                            ),
                            icon: const Icon(Icons.copy),
                            tooltip: l10n.commonCopy,
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            onPressed: () => state.clearMorseDecodedText(),
                            icon: const Icon(Icons.clear_all),
                            tooltip: l10n.commonClear,
                            style: IconButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                if (state.morseIsDecodingLive) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],

                const SizedBox(height: 16),
                Text(
                  l10n.sfMorseDecodedOutput,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(minHeight: 100),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    state.morseDecodedText.isNotEmpty
                        ? state.morseDecodedText
                        : (state.morseListening
                              ? 'Listening... Tap or play Morse signals near the microphone.'
                              : 'Awaiting Morse audio input...'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontStyle: state.morseDecodedText.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color: state.morseDecodedText.isEmpty
                          ? theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            )
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Static File Decoder Card
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.15),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Translate Audio File',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a recorded or downloaded WAV clip to decode its Morse signal to plain text.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: state.morseListening || _isDecodingFile
                          ? null
                          : () => _loadAndDecodeWav(context, l10n),
                      icon: const Icon(Icons.audio_file_outlined),
                      label: Text(l10n.sfDopplerLoadClip),
                    ),
                  ],
                ),
                if (_isDecodingFile) ...[
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(width: 12),
                      Text('Decoding audio file...'),
                    ],
                  ),
                ],
                if (_fileDecodeResult.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _loadedFileName ?? 'Audio Clip',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () => _copyToClipboard(
                          context,
                          _fileDecodeResult,
                          'Translation copied to clipboard',
                        ),
                        tooltip: l10n.commonCopy,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      _fileDecodeResult,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        if (state.micStatus != MicStatus.running && state.morseListening) ...[
          const SizedBox(height: 16),
          SfPermissionNotice(status: state.micStatus),
        ],
      ],
    );
  }
}
