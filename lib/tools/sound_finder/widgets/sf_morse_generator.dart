import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../sound_finder_colors.dart';
import '../sound_finder_state.dart';
import '../morse/morse_converter.dart';
import '../morse/morse_audio_renderer.dart';
import 'sf_labeled_slider.dart';

class SfMorseGenerator extends StatefulWidget {
  const SfMorseGenerator({super.key});

  @override
  State<SfMorseGenerator> createState() => _SfMorseGeneratorState();
}

class _SfMorseGeneratorState extends State<SfMorseGenerator> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    final state = context.read<SoundFinderState>();
    _textController = TextEditingController(text: state.morseInputText);
    _textController.addListener(() {
      state.setMorseInputText(_textController.text);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _exportWav(SoundFinderState state, AppLocalizations l10n) async {
    try {
      final tokens = MorseConverter.tokenize(state.morseInputText);
      if (tokens.isEmpty) return;

      final wavBytes = await MorseAudioRenderer.render(
        tokens: tokens,
        wpm: state.morseWpm,
        frequency: state.morseFreq,
      );

      if (!mounted) return;

      final DateTime now = DateTime.now();
      final String stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}-'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}';

      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: 'morse-code-$stamp.wav',
        bytes: wavBytes,
        successMessageAndroid: l10n.sfMorseExportSuccess,
        successMessageGeneralBuilder: (path) =>
            '${l10n.sfMorseExportSuccess}: $path',
        errorMessageBuilder: (_) => l10n.sfClipSaveError,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SoundFinderState>();
    final tokens = MorseConverter.tokenize(state.morseInputText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Signal Lamp Visualizer
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
                    Icons.lightbulb_outline,
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
                l10n.sfMorsePlayMode,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Text input card
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
                TextField(
                  controller: _textController,
                  enabled: !state.morsePlaying,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.sfMorsePlaceholder,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Controls row
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Playback actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.morsePlaying)
                          FilledButton.icon(
                            onPressed: () => state.stopMorsePlayback(),
                            icon: const Icon(Icons.stop),
                            label: Text(l10n.sfStop),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.statusRed,
                            ),
                          )
                        else
                          FilledButton.icon(
                            onPressed: () => state.startMorsePlayback(),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(l10n.sfPlayTone),
                          ),
                        const SizedBox(width: 8),
                        if (!state.morsePlaying && tokens.isNotEmpty)
                          IconButton.outlined(
                            onPressed: () => _exportWav(state, l10n),
                            icon: const Icon(Icons.download),
                            tooltip: l10n.commonExport,
                          ),
                      ],
                    ),

                    // Play Mode Dropdown / Segmented
                    DropdownButton<String>(
                      value: state.morsePlayMode,
                      onChanged: state.morsePlaying
                          ? null
                          : (val) {
                              if (val != null) state.setMorsePlayMode(val);
                            },
                      items: [
                        DropdownMenuItem(
                          value: 'both',
                          child: Text(l10n.sfMorsePlayBoth),
                        ),
                        DropdownMenuItem(
                          value: 'sound',
                          child: Text(l10n.sfMorsePlaySound),
                        ),
                        DropdownMenuItem(
                          value: 'flash',
                          child: Text(l10n.sfMorsePlayFlash),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Sliders card
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
              children: [
                SfLabeledSlider(
                  icon: Icons.speed,
                  label: l10n.sfMorseWpm,
                  valueText: '${state.morseWpm.round()} WPM',
                  value: state.morseWpm,
                  min: 10,
                  max: 45,
                  divisions: 35,
                  onChanged: state.morsePlaying
                      ? (val) {}
                      : (val) => state.setMorseWpm(val),
                ),
                const SizedBox(height: 16),
                SfLabeledSlider(
                  icon: Icons.music_note,
                  label: l10n.sfTargetFrequency,
                  valueText: '${state.morseFreq.round()} Hz',
                  value: state.morseFreq,
                  min: 400,
                  max: 1000,
                  divisions: 60,
                  onChanged: state.morsePlaying
                      ? (val) {}
                      : (val) => state.setMorseFreq(val),
                ),
                const SizedBox(height: 16),
                SfLabeledSlider(
                  icon: Icons.volume_up,
                  label: l10n.sfVolume,
                  valueText: '${(state.morseVolume * 100).round()}%',
                  value: state.morseVolume,
                  onChanged: (val) => state.setMorseVolume(val),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Timeline visualization card
        if (tokens.isNotEmpty) ...[
          Text(
            l10n.sfSpectrum, // Using "Spectrum" key as section title or similar, or just a custom label
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(tokens.length, (index) {
                final token = tokens[index];
                final bool isHighlighted =
                    state.morsePlaying && state.morsePlayingTokenIndex == index;

                if (token.isWordGap) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    child: Text(
                      '⫽',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }

                if (token.isCharGap) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Text(
                      '|',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                  );
                }

                // Render dot/dash representation
                final String morseFancy = token.morse
                    .replaceAll('.', '•')
                    .replaceAll('-', '—');

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? SoundFinderColors.violet
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isHighlighted
                          ? SoundFinderColors.violet
                          : theme.colorScheme.outline.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (isHighlighted)
                        BoxShadow(
                          color: SoundFinderColors.violet.withValues(
                            alpha: 0.4,
                          ),
                          blurRadius: 8,
                        ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        token.char,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isHighlighted
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        morseFancy,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: isHighlighted
                              ? Colors.white.withValues(alpha: 0.9)
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}
