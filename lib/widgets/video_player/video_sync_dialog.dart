import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

/// Shifts subtitles and audio against the picture; changes apply at once.
class VideoSyncDialog extends StatefulWidget {
  static const Duration step = Duration(milliseconds: 100);
  static const Duration limit = Duration(seconds: 30);

  final Duration subtitleDelay;
  final Duration audioDelay;

  /// Null hides the audio row.
  final ValueChanged<Duration>? onAudioDelay;
  final ValueChanged<Duration> onSubtitleDelay;

  const VideoSyncDialog({
    super.key,
    required this.subtitleDelay,
    required this.audioDelay,
    required this.onSubtitleDelay,
    required this.onAudioDelay,
  });

  static Future<void> show(
    BuildContext context, {
    required Duration subtitleDelay,
    required Duration audioDelay,
    required ValueChanged<Duration> onSubtitleDelay,
    required ValueChanged<Duration>? onAudioDelay,
  }) => showDialog<void>(
    context: context,
    builder: (_) => VideoSyncDialog(
      subtitleDelay: subtitleDelay,
      audioDelay: audioDelay,
      onSubtitleDelay: onSubtitleDelay,
      onAudioDelay: onAudioDelay,
    ),
  );

  @override
  State<VideoSyncDialog> createState() => _VideoSyncDialogState();
}

class _VideoSyncDialogState extends State<VideoSyncDialog> {
  late Duration _subtitle = widget.subtitleDelay;
  late Duration _audio = widget.audioDelay;

  static Duration _clamp(Duration value) => Duration(
    milliseconds: value.inMilliseconds.clamp(
      -VideoSyncDialog.limit.inMilliseconds,
      VideoSyncDialog.limit.inMilliseconds,
    ),
  );

  void _setSubtitle(Duration value) {
    setState(() => _subtitle = _clamp(value));
    widget.onSubtitleDelay(_subtitle);
  }

  void _setAudio(Duration value) {
    setState(() => _audio = _clamp(value));
    widget.onAudioDelay?.call(_audio);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      title: Text(l10n.videoPlayerSyncTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DelayRow(
            label: l10n.videoPlayerSubtitleDelay,
            delay: _subtitle,
            onChanged: _setSubtitle,
          ),
          if (widget.onAudioDelay != null) ...[
            const SizedBox(height: 16),
            _DelayRow(
              label: l10n.videoPlayerAudioDelay,
              delay: _audio,
              onChanged: _setAudio,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _subtitle == Duration.zero && _audio == Duration.zero
              ? null
              : () {
                  _setSubtitle(Duration.zero);
                  _setAudio(Duration.zero);
                },
          child: Text(l10n.commonReset),
        ),
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}

class _DelayRow extends StatelessWidget {
  final String label;
  final Duration delay;
  final ValueChanged<Duration> onChanged;

  const _DelayRow({
    required this.label,
    required this.delay,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final seconds = NumberFormat(
      '+0.0;-0.0',
      Localizations.localeOf(context).toString(),
    ).format(delay.inMilliseconds / 1000);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton.outlined(
              icon: const Icon(Icons.remove),
              tooltip: l10n.videoPlayerDelayEarlier,
              onPressed: () => onChanged(delay - VideoSyncDialog.step),
            ),
            Expanded(
              child: Text(
                '$seconds s',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            IconButton.outlined(
              icon: const Icon(Icons.add),
              tooltip: l10n.videoPlayerDelayLater,
              onPressed: () => onChanged(delay + VideoSyncDialog.step),
            ),
          ],
        ),
      ],
    );
  }
}
