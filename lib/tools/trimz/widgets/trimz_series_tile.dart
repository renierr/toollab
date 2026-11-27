import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/trimz_series.dart';
import '../trimz_format.dart';
import 'trimz_series_card.dart';
import 'trimz_series_page.dart';

class TrimzSeriesTile extends StatelessWidget {
  final TrimzSeries series;
  final double width;
  final int? rank;

  const TrimzSeriesTile({
    super.key,
    required this.series,
    required this.width,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TrimzSeriesCard(
      title: series.title,
      posterUrl: series.posterUrl,
      width: width,
      rank: rank,
      badge: series.badge,
      subtitle: trimzSeriesStats(
        l10n,
        episodes: series.episodeCount,
        views: series.views,
        locale: Localizations.localeOf(context).toString(),
      ),
      onTap: () => TrimzSeriesPage.open(context, series),
    );
  }
}
