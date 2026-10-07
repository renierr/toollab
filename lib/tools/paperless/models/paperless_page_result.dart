/// One page of a Django REST Framework list endpoint.
class PaperlessPageResult<T> {
  final int count;
  final List<T> items;
  final bool hasNext;

  const PaperlessPageResult({
    required this.count,
    required this.items,
    required this.hasNext,
  });

  factory PaperlessPageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final results = json['results'] as List<dynamic>? ?? const [];
    return PaperlessPageResult(
      count: json['count'] as int? ?? results.length,
      items: [
        for (final item in results)
          if (item is Map<String, dynamic>) parse(item),
      ],
      hasNext: json['next'] != null,
    );
  }
}
