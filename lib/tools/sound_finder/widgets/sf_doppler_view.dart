import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:file_selector/file_selector.dart' show XTypeGroup, openFile;
import 'package:tool_lab/widgets/collapsible_section.dart';

import '../audio/doppler_analyzer.dart';
import '../sound_finder_state.dart';
import 'sf_doppler_controls.dart';
import 'sf_doppler_graph.dart';
import 'sf_doppler_results.dart';
import 'sf_permission_notice.dart';

class SfDopplerView extends StatefulWidget {
  const SfDopplerView({super.key});

  @override
  State<SfDopplerView> createState() => _SfDopplerViewState();
}

class _SfDopplerViewState extends State<SfDopplerView> {
  DopplerResult? _lastResult;

  double _fApproach = 440.0;
  double _fRecede = 400.0;
  double _t0 = 2.5;
  double _distance = 5.0;
  double _temperature = 20.0;

  Future<void> _loadWavFile(BuildContext context) async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'WAV Audio',
      extensions: ['wav'],
      mimeTypes: ['audio/wav', 'audio/x-wav'],
    );
    try {
      final file = await openFile(acceptedTypeGroups: const [typeGroup]);
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (context.mounted) {
          context.read<SoundFinderState>().loadWavClip(bytes);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SoundFinderState>();
    final result = state.dopplerResult;
    final samples = state.dopplerSamples;

    // Detect new analysis results and update local state
    if (result != _lastResult) {
      _lastResult = result;
      if (result != null) {
        _fApproach = result.defaultFApproach;
        _fRecede = result.defaultFRecede;
        _t0 = result.defaultT0;
        _distance = result.defaultDistance;
      }
    }

    if (samples == null || result == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.15),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CollapsibleSection(
                icon: Icons.analytics_outlined,
                iconColor: Theme.of(context).colorScheme.primary,
                title: l10n.sfDopplerTitle,
                initiallyExpanded: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.sfDopplerExplanation,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.sfDopplerStatusNoData,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _loadWavFile(context),
                            icon: const Icon(Icons.audio_file_outlined),
                            label: Text(l10n.sfDopplerLoadClip),
                          ),
                          if (state.micStatus != MicStatus.running)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  context.read<SoundFinderState>().ensureMic(),
                              icon: const Icon(Icons.mic_outlined),
                              label: Text(l10n.sfGrantPermission),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (state.micStatus != MicStatus.running) ...[
            const SizedBox(height: 16),
            SfPermissionNotice(status: state.micStatus),
          ],
        ],
      );
    }

    final double duration = samples.length / 44100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.15),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: CollapsibleSection(
              icon: Icons.analytics_outlined,
              iconColor: Theme.of(context).colorScheme.primary,
              title: l10n.sfDopplerTitle,
              initiallyExpanded: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.sfDopplerStatusSuccess,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.read<SoundFinderState>().clearDopplerData(),
                      icon: const Icon(Icons.clear_all_outlined),
                      label: Text(l10n.commonClear),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SfDopplerGraph(
          points: result.points,
          duration: duration,
          fApproach: _fApproach,
          fRecede: _fRecede,
          t0: _t0,
          distance: _distance,
          temperature: _temperature,
        ),
        const SizedBox(height: 12),
        SfDopplerResults(
          fApproach: _fApproach,
          fRecede: _fRecede,
          distance: _distance,
          temperature: _temperature,
        ),
        const SizedBox(height: 12),
        SfDopplerControls(
          fApproach: _fApproach,
          fRecede: _fRecede,
          t0: _t0,
          distance: _distance,
          temperature: _temperature,
          duration: duration,
          onFApproachChanged: (val) => setState(() => _fApproach = val),
          onFRecedeChanged: (val) => setState(() => _fRecede = val),
          onT0Changed: (val) => setState(() => _t0 = val),
          onDistanceChanged: (val) => setState(() => _distance = val),
          onTemperatureChanged: (val) => setState(() => _temperature = val),
        ),
      ],
    );
  }
}
