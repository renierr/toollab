import 'package:material_ui/material_ui.dart';

import '../models/trimz_series.dart';
import 'trimz_series_card.dart';
import 'trimz_series_tile.dart';

/// Cards in as many columns as fit; extra width becomes more columns.
class TrimzSeriesGrid extends StatelessWidget {
  static const double _maxTileWidth = 280;
  static const double _spacing = 12;

  final List<TrimzSeries> items;

  const TrimzSeriesGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.crossAxisExtent;
          final columns = ((available + _spacing) / (_maxTileWidth + _spacing))
              .ceil()
              .clamp(1, 12);
          final width = (available - _spacing * (columns - 1)) / columns;
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: _spacing,
              mainAxisSpacing: _spacing,
              mainAxisExtent: TrimzSeriesCard.heightFor(context, width),
            ),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                TrimzSeriesTile(series: items[index], width: width),
          );
        },
      ),
    );
  }
}
