import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/trimz_catalog.dart';
import '../models/trimz_saved_series.dart';
import '../trimz_state.dart';
import 'trimz_genre_bar.dart';
import 'trimz_message_view.dart';
import 'trimz_rail.dart';
import 'trimz_saved_tile.dart';
import 'trimz_section_title.dart';
import 'trimz_series_grid.dart';
import 'trimz_series_tile.dart';

/// The catalog: the viewer's own rows first, then the explore feed.
class TrimzBrowseView extends StatelessWidget {
  static const double _loadMoreExtent = 800;

  const TrimzBrowseView({super.key});

  bool _onScroll(BuildContext context, ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter < _loadMoreExtent) {
      unawaited(context.read<TrimzState>().loadMore());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<TrimzState>();
    final sections = state.sections;
    final own = state.genre == null;
    final continueWatching = own
        ? state.continueWatching
        : const <TrimzSavedSeries>[];
    final myList = own ? state.myList : const <TrimzSavedSeries>[];

    return RefreshIndicator(
      onRefresh: state.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onScroll(context, n),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: TrimzGenreBar()),
            if (continueWatching.isNotEmpty)
              SliverToBoxAdapter(
                child: TrimzRail(
                  title: l10n.trimzContinueWatching,
                  itemCount: continueWatching.length,
                  itemBuilder: (context, i, width) => TrimzSavedTile(
                    saved: continueWatching[i],
                    width: width,
                    resume: true,
                  ),
                ),
              ),
            if (myList.isNotEmpty)
              SliverToBoxAdapter(
                child: TrimzRail(
                  title: l10n.trimzMyList,
                  itemCount: myList.length,
                  itemBuilder: (context, i, width) => TrimzSavedTile(
                    saved: myList[i],
                    width: width,
                    resume: false,
                  ),
                ),
              ),
            if (sections.isEmpty && state.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (sections.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: state.failed
                    ? TrimzMessageView(
                        icon: Icons.cloud_off_outlined,
                        message: l10n.trimzLoadFailed,
                        onRetry: () => unawaited(state.refresh()),
                      )
                    : TrimzMessageView(
                        icon: Icons.movie_outlined,
                        message: l10n.trimzEmpty,
                      ),
              ),
            for (final section in sections) ..._sectionSlivers(section),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: state.loadingMore
                    ? const Center(child: CircularProgressIndicator())
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sectionSlivers(TrimzSection section) => section.rail
      ? [
          SliverToBoxAdapter(
            child: TrimzRail(
              title: section.title,
              itemCount: section.items.length,
              itemBuilder: (context, i, width) => TrimzSeriesTile(
                series: section.items[i],
                width: width,
                rank: section.ranked ? i + 1 : null,
              ),
            ),
          ),
        ]
      : [
          SliverToBoxAdapter(child: TrimzSectionTitle(title: section.title)),
          TrimzSeriesGrid(items: section.items),
        ];
}
