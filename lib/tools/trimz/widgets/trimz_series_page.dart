import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../models/trimz_series.dart';
import '../models/trimz_series_detail.dart';
import '../trimz_links.dart';
import '../trimz_playback.dart';
import '../trimz_state.dart';
import 'trimz_episode_tile.dart';
import 'trimz_message_view.dart';
import 'trimz_series_header.dart';

/// A series with its episodes; the series' card shows until they load.
class TrimzSeriesPage extends StatefulWidget {
  final TrimzSeries series;

  const TrimzSeriesPage({super.key, required this.series});

  static Future<void> open(BuildContext context, TrimzSeries series) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TrimzSeriesPage(series: series),
        ),
      );

  @override
  State<TrimzSeriesPage> createState() => _TrimzSeriesPageState();
}

class _TrimzSeriesPageState extends State<TrimzSeriesPage> {
  late Future<TrimzSeriesDetail> _detail = _load();

  Future<TrimzSeriesDetail> _load() =>
      context.read<TrimzState>().loadSeries(widget.series.slug);

  void _retry() => setState(() => _detail = _load());

  void _play(TrimzSeriesDetail detail, int index) => unawaited(
    TrimzPlayback.play(
      context,
      series: widget.series,
      detail: detail,
      index: index,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final series = widget.series;
    final state = context.watch<TrimzState>();
    final saved = state.savedFor(series.id);
    final onList = saved?.onList ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(series.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            onPressed: () => unawaited(state.toggleList(series)),
            tooltip: onList ? l10n.trimzOnList : l10n.trimzAddToList,
            icon: Icon(onList ? Icons.bookmark : Icons.bookmark_border),
          ),
          IconButton(
            onPressed: () => unawaited(openTrimzUrl(context, series.webUrl)),
            tooltip: l10n.trimzOpenOnWeb,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: FutureBuilder<TrimzSeriesDetail>(
        future: _detail,
        builder: (context, snapshot) {
          final detail = snapshot.data;
          final failed = snapshot.hasError;
          final episodes = detail?.episodes ?? const [];
          final watched = saved != null && saved.watched;
          return ReadableScrollPadding(
            padding: const EdgeInsets.only(bottom: 32),
            builder: (context, padding) => CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: padding.copyWith(bottom: 0),
                  sliver: SliverToBoxAdapter(
                    child: TrimzSeriesHeader(
                      series: series,
                      detail: detail,
                      saved: saved,
                      onPlay: detail == null || episodes.isEmpty
                          ? null
                          : (index) => _play(detail, index),
                      onToggleList: () => unawaited(state.toggleList(series)),
                    ),
                  ),
                ),
                if (detail == null && !failed)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (failed)
                  SliverToBoxAdapter(
                    child: TrimzMessageView(
                      icon: Icons.cloud_off_outlined,
                      message: l10n.trimzLoadFailed,
                      onRetry: _retry,
                    ),
                  )
                else if (episodes.isEmpty)
                  SliverToBoxAdapter(
                    child: TrimzMessageView(
                      icon: Icons.videocam_off_outlined,
                      message: l10n.trimzNoEpisodes,
                    ),
                  )
                else
                  SliverPadding(
                    padding: padding.copyWith(top: 8),
                    sliver: SliverList.builder(
                      itemCount: episodes.length,
                      itemBuilder: (context, index) => TrimzEpisodeTile(
                        episode: episodes[index],
                        number: index + 1,
                        watched: watched && index < saved.episodeIndex,
                        progress: watched && index == saved.episodeIndex
                            ? saved
                            : null,
                        onTap: () => _play(detail!, index),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
