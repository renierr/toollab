import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'video_backend.dart';
import 'video_player_page.dart';

class VideoControls extends StatelessWidget {
  final VideoPlaybackState state;
  final String? title;
  final FocusNode playFocusNode;
  final List<VideoPlayerAction> actions;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration> onSeekBy;
  final VoidCallback onToggleMute;
  final VoidCallback onClose;
  final Duration seekStep;

  const VideoControls({
    super.key,
    required this.state,
    required this.title,
    required this.playFocusNode,
    required this.actions,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onSeekBy,
    required this.onToggleMute,
    required this.onClose,
    required this.seekStep,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final durationMs = state.duration.inMilliseconds;
    final positionMs = state.position.inMilliseconds.clamp(0, durationMs);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent, Colors.black87],
          stops: [0, 0.35, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.commonClose,
                  onPressed: onClose,
                ),
                Expanded(
                  child: Text(
                    title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final action in actions)
                  IconButton(
                    icon: Icon(action.icon),
                    tooltip: action.label,
                    onPressed: () => action.onPressed(context),
                  ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(_format(state.position)),
                  Expanded(
                    child: Slider(
                      value: durationMs > 0 ? positionMs.toDouble() : 0,
                      max: durationMs > 0 ? durationMs.toDouble() : 1,
                      onChanged: durationMs > 0
                          ? (v) => onSeek(Duration(milliseconds: v.round()))
                          : null,
                    ),
                  ),
                  Text(_format(state.duration)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.replay_10),
                    tooltip: l10n.videoPlayerBack(seekStep.inSeconds),
                    onPressed: () => onSeekBy(-seekStep),
                  ),
                  IconButton.filled(
                    focusNode: playFocusNode,
                    autofocus: true,
                    iconSize: 40,
                    icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
                    tooltip: state.playing
                        ? l10n.videoPlayerPause
                        : l10n.videoPlayerPlay,
                    onPressed: onTogglePlay,
                  ),
                  IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.forward_10),
                    tooltip: l10n.videoPlayerForward(seekStep.inSeconds),
                    onPressed: () => onSeekBy(seekStep),
                  ),
                  IconButton(
                    iconSize: 28,
                    icon: Icon(
                      state.volume > 0 ? Icons.volume_up : Icons.volume_off,
                    ),
                    tooltip: state.volume > 0
                        ? l10n.videoPlayerMute
                        : l10n.videoPlayerUnmute,
                    onPressed: onToggleMute,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (minutes < 60) return '$minutes:$seconds';
    final mm = (minutes % 60).toString().padLeft(2, '0');
    return '${d.inHours}:$mm:$seconds';
  }
}
