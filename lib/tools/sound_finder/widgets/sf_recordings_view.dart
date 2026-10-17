import 'dart:async';
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
    if (state.isRecording || state.isPaused) {
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

  Future<void> _trimClip(BuildContext context, RecordingClip clip) async {
    final state = context.read<SoundFinderState>();
    final duration = clip.durationSeconds;
    double start = 0;
    double end = duration;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context).sfTrimClip),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Start: ${start.toStringAsFixed(1)}s'),
              Slider(
                value: start.clamp(0, duration),
                min: 0,
                max: duration,
                onChanged: (v) => setState(() => start = v.clamp(0, end)),
              ),
              Text('End: ${end.toStringAsFixed(1)}s'),
              Slider(
                value: end.clamp(0, duration),
                min: 0,
                max: duration,
                onChanged: (v) => setState(() => end = v.clamp(start, duration)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(state.trimRecording(clip.path, start, end));
              },
              child: Text(AppLocalizations.of(context).commonOk),
            ),
          ],
        ),
      ),
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
                  if (state.isRecording)
                    OutlinedButton.icon(
                      onPressed: () => state.isPaused
                          ? state.resumeNormalRecording()
                          : state.pauseNormalRecording(),
                      icon: Icon(
                        state.isPaused ? Icons.play_arrow : Icons.pause,
                      ),
                      label: Text(
                        state.isPaused ? l10n.sfResumeRecording : l10n.sfPauseRecording,
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
                    const Icon(Icons.speed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l10n.sfSampleRate)),
                    DropdownButton<int>(
                      value: state.sampleRate,
                      items: const [
                        DropdownMenuItem(value: 16000, child: Text('16 kHz')),
                        DropdownMenuItem(value: 22050, child: Text('22.05 kHz')),
                        DropdownMenuItem(value: 44100, child: Text('44.1 kHz')),
                        DropdownMenuItem(value: 48000, child: Text('48 kHz')),
                      ],
                      onChanged: (v) {
                        if (v != null) state.setSampleRate(v);
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: SwitchListTile(
                  title: Text(l10n.sfNoiseSuppress),
                  value: state.noiseSuppress,
                  onChanged: state.setNoiseSuppress,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: SwitchListTile(
                  title: Text(l10n.sfEchoCancel),
                  value: state.echoCancel,
                  onChanged: state.setEchoCancel,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SwitchListTile(
                  title: Text(l10n.sfAutoGain),
                  value: state.autoGain,
                  onChanged: state.setAutoGain,
                ),
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
          // Playback speed
          Row(
            children: [
              const Icon(Icons.speed, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.sfPlaybackSpeed)),
              DropdownButton<double>(
                value: state.playbackSpeed,
                items: const [
                  DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                  DropdownMenuItem(value: 0.75, child: Text('0.75x')),
                  DropdownMenuItem(value: 1.0, child: Text('1x')),
                  DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                  DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                  DropdownMenuItem(value: 2.0, child: Text('2x')),
                ],
                onChanged: (v) {
                  if (v != null) state.setPlaybackSpeed(v);
                },
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
                onShare: () => FileSaveHelper.showShareChooser(
                  context: context,
                  path: clip.path,
                  mimeType: 'audio/wav',
                ),
                onTrim: () => _trimClip(context, clip),
                onNormalize: () => state.normalizeRecording(clip.path),
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
  final VoidCallback onTrim;
  final VoidCallback onNormalize;
  final VoidCallback onDelete;

  const _RecordingTile({
    required this.clip,
    required this.exporting,
    required this.isPlaying,
    required this.onPlay,
    required this.onExport,
    required this.onShare,
    required this.onTrim,
    required this.onNormalize,
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
    final state = context.watch<SoundFinderState>();
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
            if (isPlaying) ...[
              const SizedBox(height: 8),
              Slider(
                value: state.playbackPosition.inMilliseconds
                    .clamp(0, (clip.durationSeconds * 1000).round())
                    .toDouble(),
                min: 0,
                max: (clip.durationSeconds * 1000).clamp(1, double.infinity),
                onChanged: (v) =>
                    state.seekPlayback(Duration(milliseconds: v.round())),
              ),
              Row(
                children: [
                  const Icon(Icons.volume_up, size: 18),
                  Expanded(
                    child: Slider(
                      value: state.playbackVolume,
                      min: 0,
                      max: 1,
                      onChanged: state.setPlaybackVolume,
                    ),
                  ),
                ],
              ),
            ],
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
                  icon: const Icon(Icons.content_cut),
                  tooltip: l10n.sfTrimClip,
                  onPressed: onTrim,
                ),
                IconButton(
                  icon: const Icon(Icons.auto_fix_high),
                  tooltip: l10n.sfNormalizeClip,
                  onPressed: onNormalize,
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
