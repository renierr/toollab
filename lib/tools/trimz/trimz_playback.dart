import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/video_player/video_player_page.dart';
import 'package:tool_lab/widgets/video_player/video_playlist.dart';
import 'package:tool_lab/widgets/video_player/video_resume_store.dart';

import 'models/trimz_series.dart';
import 'models/trimz_series_detail.dart';
import 'trimz_links.dart';
import 'trimz_state.dart';

/// Plays a series as one playlist and keeps the series' place in [TrimzState].
class TrimzPlayback implements VideoResumeStore {
  final TrimzState _state;
  final TrimzSeries _series;
  final TrimzSeriesDetail _detail;
  final Map<Uri, int> _indexOf;

  TrimzPlayback._(this._state, this._series, this._detail, List<Uri> sources)
    : _indexOf = {for (var i = 0; i < sources.length; i++) sources[i]: i};

  static Future<void> play(
    BuildContext context, {
    required TrimzSeries series,
    required TrimzSeriesDetail detail,
    required int index,
  }) async {
    if (detail.episodes.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final state = context.read<TrimzState>();
    final adaptive = state.adaptiveStream;
    final count = detail.episodes.length;
    final playlist = [
      for (var i = 0; i < count; i++)
        VideoPlaylistItem(
          source: detail.episodes[i].source(adaptive: adaptive),
          title: l10n.trimzEpisodeTitle(detail.title, i + 1, count),
        ),
    ];
    final start = playlist[index.clamp(0, count - 1)];
    final session = TrimzPlayback._(state, series, detail, [
      for (final item in playlist) item.source,
    ]);
    await VideoPlayerPage.open(
      context,
      source: start.source,
      title: start.title,
      playlist: playlist,
      autoAdvance: state.autoplayNext,
      resumeStore: session,
      actions: [
        VideoPlayerAction(
          icon: Icons.open_in_new,
          label: l10n.trimzOpenOnWeb,
          onPressed: (c) => openTrimzUrl(c, series.webUrl),
        ),
      ],
    );
  }

  @override
  Future<Duration?> resumePosition(Uri source) async {
    final index = _indexOf[source];
    if (index == null) return null;
    return _state.savedFor(_series.id)?.resumeAt(index);
  }

  @override
  Future<void> savePosition({
    required Uri source,
    required String title,
    required Duration position,
    required Duration duration,
  }) async {
    final index = _indexOf[source];
    if (index == null) return;
    await _state.recordProgress(
      _series,
      episodeIndex: index,
      episodeCount: _detail.episodes.length,
      position: position,
      duration: duration,
    );
  }

  // Every episode has a poster; frames of our own are not needed.
  @override
  Future<void> saveThumbnail(Uri source, Uint8List jpeg) async {}
}
