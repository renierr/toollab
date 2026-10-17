import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../recording_clip.dart';
import '../sf_recording_format.dart';
import 'sf_permission_notice.dart';
import '../sound_finder_state.dart';
import 'sf_mic_selector.dart';
import 'sf_gain_control.dart';

class SfRecordingsView extends StatefulWidget {
  const SfRecordingsView({super.key});

  @override
  State<SfRecordingsView> createState() => _SfRecordingsViewState();
}

class _SfRecordingsViewState extends State<SfRecordingsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SoundFinderState>().refreshRecordings();
    });
  }

  String _mmss(double seconds) {
    final int total = seconds.floor();
    final int m = total ~/ 60;
    final int s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleRecording() async {
    final state = context.read<SoundFinderState>();
    if (state.isRecording) {
      await state.stopNormalRecordingAndStore();
    } else {
      state.startNormalRecording();
    }
  }

  Future<void> _export(BuildContext context, String path) async {
    final l10n = AppLocalizations.of(context);
    final format = await showDialog<SfRecordingFormat>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.voiceDistorterExportFormatTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final format in SfRecordingFormat.values)
              ListTile(
                title: Text(format.label),
                trailing: Text('.${format.extension}'),
                onTap: () => Navigator.of(dialogContext).pop(format),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
    if (format == null || !context.mounted) return;
    final bytes = await context.read<SoundFinderState>().exportRecording(
      path,
      format,
    );
    if (!context.mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.sfClipSaveError)));
      return;
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: 'recording-$stamp.${format.extension}',
      bytes: bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SoundFinderState>();

    if (state.micStatus != MicStatus.running) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SfPermissionNotice(status: state.micStatus),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Recording controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        state.isRecording
                            ? Icons.fiber_manual_record
                            : Icons.mic_outlined,
                        color: state.isRecording
                            ? AppTheme.statusRed
                            : theme.colorScheme.onSurface,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        state.isRecording
                            ? l10n.sfRecordingLabel
                            : l10n.sfRecordClip,
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      if (state.isRecording)
                        Text(
                          '${_mmss(state.recordedSeconds)} / ${state.maxRecordSeconds > 0 ? _mmss(state.maxRecordSeconds.toDouble()) : '∞'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                  if (state.isRecording) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: CustomPaint(
                        painter: _WaveformPainter(state.diskWaveform),
                        size: Size.infinite,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _toggleRecording,
                    icon: Icon(
                      state.isRecording ? Icons.stop : Icons.fiber_manual_record,
                    ),
                    label: Text(
                      state.isRecording
                          ? l10n.sfStopRecording
                          : l10n.sfRecordClip,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Mic settings
          ExpansionTile(
            title: Text(l10n.sfInputSettings),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SfMicSelector(),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SfGainControl(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l10n.sfMaxRecordLength),
                    ),
                    DropdownButton<int>(
                      value: state.maxRecordSeconds,
                      items: const [
                        DropdownMenuItem(value: 60, child: Text('1 min')),
                        DropdownMenuItem(value: 300, child: Text('5 min')),
                        DropdownMenuItem(value: 600, child: Text('10 min')),
                        DropdownMenuItem(value: 1800, child: Text('30 min')),
                        DropdownMenuItem(value: 0, child: Text('Unlimited')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          context.read<SoundFinderState>().setMaxRecordSeconds(v);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stored clips
          Text(l10n.sfSaveClipButton, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (state.recordings.isEmpty)
            Text(
              l10n.sfDopplerStatusNoData,
              style: theme.textTheme.bodySmall,
            )
          else
            for (final clip in state.recordings)
              _RecordingTile(
                clip: clip,
                exporting: state.recordingsExporting,
                isPlaying: state.playingRecordingPath == clip.path,
                onPlay: () => state.playingRecordingPath == clip.path
                    ? state.stopRecordingPlayback()
                    : state.playRecording(clip.path),
                onExport: () => _export(context, clip.path),
                onShare: () => FileSaveHelper.shareFile(
                  clip.path,
                  'audio/wav',
                ),
                onDelete: () => state.deleteRecording(clip.path),
              ),
        ],
      ),
    );
  }
}

class _RecordingTile extends StatelessWidget {
  final RecordingClip clip;
  final bool exporting;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _RecordingTile({
    required this.clip,
    required this.exporting,
    required this.isPlaying,
    required this.onPlay,
    required this.onExport,
    required this.onShare,
    required this.onDelete,
  });

  String _mmss(double seconds) {
    final int total = seconds.floor();
    final int m = total ~/ 60;
    final int s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isPlaying ? Icons.graphic_eq : Icons.audio_file_outlined,
                  color: isPlaying ? AppTheme.statusGreen : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clip.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        '${_mmss(clip.durationSeconds)} · ${(clip.sizeBytes / 1024).toStringAsFixed(1)} KB',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                IconButton(
                  icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                  tooltip: isPlaying ? l10n.sfStop : l10n.sfPlayClip,
                  onPressed: onPlay,
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: l10n.commonExport,
                  onPressed: exporting ? null : onExport,
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: l10n.commonShare,
                  onPressed: onShare,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.commonDelete,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> samples;
  _WaveformPainter(this.samples);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final mid = size.height / 2;
    final step = size.width / (samples.length - 1);
    final path = Path();
    for (int i = 0; i < samples.length; i++) {
      final x = i * step;
      final y = mid - (samples[i] * mid * 0.9);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = Colors.grey.withValues(alpha: 0.3)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => true;
}
