import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'video_backend.dart';
import 'video_format.dart';
import 'video_player_types.dart';

class VideoQualityButton extends StatelessWidget {
  final List<VideoQuality> qualities;
  final Uri source;
  final ValueChanged<VideoQuality> onSelected;

  const VideoQualityButton({
    super.key,
    required this.qualities,
    required this.source,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final current = qualities.where((q) => q.source == source).firstOrNull;
    return PopupMenuButton<VideoQuality>(
      tooltip: AppLocalizations.of(context).videoPlayerQuality,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final q in qualities)
          CheckedPopupMenuItem(
            value: q,
            checked: q == current,
            child: Text(q.label),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.high_quality_outlined, size: 28),
            if (current != null) ...[
              const SizedBox(width: 4),
              Text(current.label),
            ],
          ],
        ),
      ),
    );
  }
}

class VideoSpeedButton extends StatelessWidget {
  final List<double> speeds;
  final double speed;
  final ValueChanged<double> onSelected;

  const VideoSpeedButton({
    super.key,
    required this.speeds,
    required this.speed,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    String label(double value, {bool normal = true}) =>
        formatVideoSpeed(value, l10n: l10n, locale: locale, normal: normal);
    return PopupMenuButton<double>(
      tooltip: l10n.videoPlayerSpeed,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final value in speeds)
          CheckedPopupMenuItem(
            value: value,
            checked: value == speed,
            child: Text(label(value)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed, size: 28),
            if (speed != 1) ...[
              const SizedBox(width: 4),
              Text(label(speed, normal: false)),
            ],
          ],
        ),
      ),
    );
  }
}

class VideoTracksButton extends StatelessWidget {
  static const _off = 'off';
  static const _load = 'load';
  static const _audioPrefix = 'a:';
  static const _subtitlePrefix = 's:';

  final List<VideoTrackOption> audioTracks;
  final List<VideoTrackOption> subtitleTracks;
  final ValueChanged<String> onAudioTrack;
  final ValueChanged<String?> onSubtitleTrack;
  final VoidCallback onLoadSubtitles;

  const VideoTracksButton({
    super.key,
    required this.audioTracks,
    required this.subtitleTracks,
    required this.onAudioTrack,
    required this.onSubtitleTrack,
    required this.onLoadSubtitles,
  });

  void _onSelected(String value) {
    if (value == _load) {
      onLoadSubtitles();
    } else if (value == _off) {
      onSubtitleTrack(null);
    } else if (value.startsWith(_audioPrefix)) {
      onAudioTrack(value.substring(_audioPrefix.length));
    } else if (value.startsWith(_subtitlePrefix)) {
      onSubtitleTrack(value.substring(_subtitlePrefix.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final headerStyle = Theme.of(context).textTheme.labelMedium;
    String label(VideoTrackOption track, int index) {
      final parts = [
        track.title,
        track.language,
      ].whereType<String>().where((part) => part.isNotEmpty).toSet();
      return parts.isEmpty
          ? l10n.videoPlayerTrack(index + 1)
          : parts.join(' · ');
    }

    return PopupMenuButton<String>(
      tooltip: l10n.videoPlayerTracks,
      icon: const Icon(Icons.subtitles_outlined, size: 28),
      onSelected: _onSelected,
      itemBuilder: (_) => [
        if (audioTracks.length > 1) ...[
          PopupMenuItem(
            enabled: false,
            height: 32,
            child: Text(l10n.videoPlayerAudio, style: headerStyle),
          ),
          for (final (index, track) in audioTracks.indexed)
            CheckedPopupMenuItem(
              value: '$_audioPrefix${track.id}',
              checked: track.selected,
              child: Text(label(track, index)),
            ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem(
          enabled: false,
          height: 32,
          child: Text(l10n.videoPlayerSubtitles, style: headerStyle),
        ),
        CheckedPopupMenuItem(
          value: _off,
          checked: !subtitleTracks.any((t) => t.selected),
          child: Text(l10n.videoPlayerSubtitlesOff),
        ),
        for (final (index, track) in subtitleTracks.indexed)
          CheckedPopupMenuItem(
            value: '$_subtitlePrefix${track.id}',
            checked: track.selected,
            child: Text(label(track, index)),
          ),
        PopupMenuItem(
          value: _load,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.file_open_outlined),
            title: Text(l10n.videoPlayerLoadSubtitles),
          ),
        ),
      ],
    );
  }
}
