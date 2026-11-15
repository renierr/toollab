import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/value_listenable_selector.dart';

import 'video_backend.dart';
import 'video_control_menus.dart';
import 'video_player_types.dart';
import 'video_seek_bar.dart';

class VideoControls extends StatelessWidget {
  /// Without position and buffer; the seek bar follows [playback] itself.
  final VideoPlaybackState state;
  final ValueListenable<VideoPlaybackState> playback;

  /// False while hidden, so the seek bar stops following playback.
  final bool tracking;
  final String? title;
  final FocusNode playFocusNode;
  final List<VideoPlayerAction> actions;
  final VoidCallback onTogglePlay;
  final VoidCallback onSeekStart;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration> onSeekBy;
  final VoidCallback onToggleMute;
  final VoidCallback onClose;
  final Duration seekStep;

  /// Copies the bare video frame.
  final VoidCallback? onCopyFrame;
  final VoidCallback? onPictureInPicture;
  final bool live;
  final List<VideoQuality> qualities;
  final Uri source;
  final ValueChanged<VideoQuality> onQuality;
  final List<double> speeds;
  final ValueChanged<double> onSpeed;
  final ValueChanged<String> onAudioTrack;

  /// Null turns subtitles off.
  final ValueChanged<String?> onSubtitleTrack;
  final VoidCallback onLoadSubtitles;
  final VoidCallback onSync;
  final VoidCallback onInfo;
  final VoidCallback onSettings;

  /// Shown with the playlist buttons, like `3 / 12`; null without a playlist.
  final String? playlistLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const VideoControls({
    super.key,
    required this.state,
    required this.playback,
    required this.tracking,
    required this.title,
    required this.playFocusNode,
    required this.actions,
    required this.onTogglePlay,
    required this.onSeekStart,
    required this.onSeek,
    required this.onSeekBy,
    required this.onToggleMute,
    required this.onClose,
    required this.seekStep,
    this.onCopyFrame,
    this.onPictureInPicture,
    required this.live,
    required this.qualities,
    required this.source,
    required this.onQuality,
    required this.speeds,
    required this.onSpeed,
    required this.onAudioTrack,
    required this.onSubtitleTrack,
    required this.onLoadSubtitles,
    required this.onSync,
    required this.onInfo,
    required this.onSettings,
    this.playlistLabel,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        _Scrim(
          alignment: Alignment.topCenter,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
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
                  if (playlistLabel != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        playlistLabel!,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  if (onCopyFrame != null)
                    IconButton(
                      icon: const Icon(Icons.photo_camera_outlined),
                      tooltip: l10n.videoPlayerCopyFrame,
                      onPressed: onCopyFrame,
                    ),
                  if (onPictureInPicture != null)
                    IconButton(
                      icon: const Icon(Icons.picture_in_picture_alt_outlined),
                      tooltip: l10n.videoPlayerPictureInPicture,
                      onPressed: onPictureInPicture,
                    ),
                  for (final action in actions)
                    IconButton(
                      icon: Icon(action.icon),
                      tooltip: action.label,
                      onPressed: () => action.onPressed(context),
                    ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        _Scrim(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (live)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _LiveBadge(),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _TrackedSeekBar(
                        playback: playback,
                        tracking: tracking,
                        onSeekStart: onSeekStart,
                        onSeek: onSeek,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ControlBar(
                      transport: [
                        if (playlistLabel != null)
                          IconButton(
                            iconSize: 32,
                            icon: const Icon(Icons.skip_previous),
                            tooltip: l10n.videoPlayerPrevious,
                            onPressed: onPrevious,
                          ),
                        if (!live)
                          IconButton(
                            iconSize: 32,
                            icon: Icon(_rewindIcon(seekStep)),
                            tooltip: l10n.videoPlayerBack(seekStep.inSeconds),
                            onPressed: () => onSeekBy(-seekStep),
                          ),
                        IconButton.filled(
                          focusNode: playFocusNode,
                          autofocus: true,
                          iconSize: 40,
                          icon: Icon(
                            state.playing ? Icons.pause : Icons.play_arrow,
                          ),
                          tooltip: state.playing
                              ? l10n.videoPlayerPause
                              : l10n.videoPlayerPlay,
                          onPressed: onTogglePlay,
                        ),
                        if (!live)
                          IconButton(
                            iconSize: 32,
                            icon: Icon(_forwardIcon(seekStep)),
                            tooltip: l10n.videoPlayerForward(
                              seekStep.inSeconds,
                            ),
                            onPressed: () => onSeekBy(seekStep),
                          ),
                        if (playlistLabel != null)
                          IconButton(
                            iconSize: 32,
                            icon: const Icon(Icons.skip_next),
                            tooltip: l10n.videoPlayerNext,
                            onPressed: onNext,
                          ),
                      ],
                      start: [
                        IconButton(
                          iconSize: 28,
                          icon: Icon(
                            state.volume > 0
                                ? Icons.volume_up
                                : Icons.volume_off,
                          ),
                          tooltip: state.volume > 0
                              ? l10n.videoPlayerMute
                              : l10n.videoPlayerUnmute,
                          onPressed: onToggleMute,
                        ),
                        if (!live)
                          VideoSpeedButton(
                            speeds: speeds,
                            speed: state.speed,
                            onSelected: onSpeed,
                          ),
                      ],
                      end: [
                        VideoTracksButton(
                          audioTracks: state.audioTracks,
                          subtitleTracks: state.subtitleTracks,
                          onAudioTrack: onAudioTrack,
                          onSubtitleTrack: onSubtitleTrack,
                          onLoadSubtitles: onLoadSubtitles,
                          onSync: onSync,
                        ),
                        if (qualities.length > 1)
                          VideoQualityButton(
                            qualities: qualities,
                            source: source,
                            onSelected: onQuality,
                          ),
                        IconButton(
                          iconSize: 28,
                          icon: const Icon(Icons.info_outline),
                          tooltip: l10n.videoPlayerInfo,
                          onPressed: onInfo,
                        ),
                        IconButton(
                          iconSize: 28,
                          icon: const Icon(Icons.settings_outlined),
                          tooltip: l10n.videoSettingsTitle,
                          onPressed: onSettings,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static IconData _rewindIcon(Duration step) => switch (step.inSeconds) {
    5 => Icons.replay_5,
    10 => Icons.replay_10,
    30 => Icons.replay_30,
    _ => Icons.fast_rewind,
  };

  static IconData _forwardIcon(Duration step) => switch (step.inSeconds) {
    5 => Icons.forward_5,
    10 => Icons.forward_10,
    30 => Icons.forward_30,
    _ => Icons.fast_forward,
  };
}

class _TrackedSeekBar extends StatelessWidget {
  final ValueListenable<VideoPlaybackState> playback;
  final bool tracking;
  final VoidCallback onSeekStart;
  final ValueChanged<Duration> onSeek;

  const _TrackedSeekBar({
    required this.playback,
    required this.tracking,
    required this.onSeekStart,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableSelector<VideoPlaybackState, VideoPlaybackState?>(
      valueListenable: playback,
      // A constant selection keeps the hidden bar from rebuilding.
      selector: (s) => tracking ? s : null,
      builder: (context, _, _) {
        final s = playback.value;
        return VideoSeekBar(
          position: s.position,
          duration: s.duration,
          buffered: s.buffered,
          onSeekStart: onSeekStart,
          onSeek: onSeek,
        );
      },
    );
  }
}

/// A shade behind one control bar, dark at the screen edge and clear toward the
/// video, so its height follows the controls rather than the window.
class _Scrim extends StatelessWidget {
  final Alignment alignment;
  final Widget child;

  const _Scrim({required this.alignment, required this.child});

  @override
  Widget build(BuildContext context) {
    final top = alignment == Alignment.topCenter;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: alignment,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [top ? Colors.black54 : Colors.black87, Colors.transparent],
        ),
      ),
      child: child,
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.statusRed,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          AppLocalizations.of(context).videoPlayerLive,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// Play/pause and the skips sit in the exact center; the other buttons go to
/// the edges, or into a row of their own when they would crowd the center.
class _ControlBar extends StatelessWidget {
  final List<Widget> transport;
  final List<Widget> start;
  final List<Widget> end;

  const _ControlBar({
    required this.transport,
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    final center = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: transport,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final cramped = constraints.maxWidth < 520;
        if (cramped) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              center,
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [...start, ...end],
              ),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.start,
                  spacing: 8,
                  children: start,
                ),
              ),
              center,
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: end,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
