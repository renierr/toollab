import 'trimz_series.dart';

class TrimzGenre {
  final String id;
  final String label;

  const TrimzGenre({required this.id, required this.label});

  static TrimzGenre? tryParse(Map<String, dynamic> json) {
    final id = json['genre'];
    if (id is! String || id.isEmpty) return null;
    return TrimzGenre(id: id, label: json['label'] as String? ?? id);
  }
}

/// A row of the explore feed: a rail when it scrolls sideways, else a grid.
class TrimzSection {
  static const Set<String> _railTypes = {'carousel', 'ranked_carousel'};

  final String id;
  final String title;
  final bool rail;
  final bool ranked;
  final List<TrimzSeries> items;
  final int? nextOffset;

  const TrimzSection({
    required this.id,
    required this.title,
    required this.items,
    this.rail = false,
    this.ranked = false,
    this.nextOffset,
  });

  factory TrimzSection.fromJson(Map<String, dynamic> json) {
    final type = json['sectionType'] as String? ?? '';
    final items = json['items'];
    return TrimzSection(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      rail: _railTypes.contains(type),
      ranked: type == 'ranked_carousel',
      items: [
        if (items is List)
          for (final item in items.whereType<Map<String, dynamic>>())
            if (item['project_id'] is String) TrimzSeries.fromJson(item),
      ],
      nextOffset: json['hasMore'] == true
          ? (json['nextOffset'] as num?)?.toInt()
          : null,
    );
  }

  bool get hasMore => nextOffset != null;

  TrimzSection appended(List<TrimzSeries> more, int? next) => TrimzSection(
    id: id,
    title: title,
    rail: rail,
    ranked: ranked,
    items: [...items, ...more.where((m) => !items.any((i) => i.id == m.id))],
    nextOffset: next,
  );
}

class TrimzPage {
  final List<TrimzSeries> items;
  final int? nextOffset;

  const TrimzPage(this.items, this.nextOffset);
}
