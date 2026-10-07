import 'package:flutter/foundation.dart';

enum PaperlessSort {
  addedNewest('-added'),
  addedOldest('added'),
  createdNewest('-created'),
  createdOldest('created'),
  modifiedNewest('-modified'),
  titleAz('title');

  final String ordering;

  const PaperlessSort(this.ordering);
}

@immutable
class PaperlessFilter {
  final String text;
  final int? correspondentId;
  final int? documentTypeId;
  final Set<int> tagIds;
  final bool inboxOnly;
  final PaperlessSort sort;

  const PaperlessFilter({
    this.text = '',
    this.correspondentId,
    this.documentTypeId,
    this.tagIds = const {},
    this.inboxOnly = false,
    this.sort = PaperlessSort.addedNewest,
  });

  /// Filters set in the filter sheet; search text and sort are shown elsewhere.
  int get activeCount =>
      (correspondentId != null ? 1 : 0) +
      (documentTypeId != null ? 1 : 0) +
      (tagIds.isNotEmpty ? 1 : 0) +
      (inboxOnly ? 1 : 0);

  PaperlessFilter copyWith({
    String? text,
    ValueGetter<int?>? correspondentId,
    ValueGetter<int?>? documentTypeId,
    Set<int>? tagIds,
    bool? inboxOnly,
    PaperlessSort? sort,
  }) {
    return PaperlessFilter(
      text: text ?? this.text,
      correspondentId: correspondentId != null
          ? correspondentId()
          : this.correspondentId,
      documentTypeId: documentTypeId != null
          ? documentTypeId()
          : this.documentTypeId,
      tagIds: tagIds ?? this.tagIds,
      inboxOnly: inboxOnly ?? this.inboxOnly,
      sort: sort ?? this.sort,
    );
  }

  PaperlessFilter clearSheetFilters() =>
      PaperlessFilter(text: text, sort: sort);

  Map<String, String> toQuery() {
    final query = text.trim();
    return {
      'ordering': sort.ordering,
      if (query.isNotEmpty) 'title_content': query,
      if (correspondentId != null) 'correspondent__id': '$correspondentId',
      if (documentTypeId != null) 'document_type__id': '$documentTypeId',
      if (tagIds.isNotEmpty) 'tags__id__all': tagIds.join(','),
      if (inboxOnly) 'is_in_inbox': 'true',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is PaperlessFilter &&
      other.text == text &&
      other.correspondentId == correspondentId &&
      other.documentTypeId == documentTypeId &&
      setEquals(other.tagIds, tagIds) &&
      other.inboxOnly == inboxOnly &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(
    text,
    correspondentId,
    documentTypeId,
    Object.hashAllUnordered(tagIds),
    inboxOnly,
    sort,
  );
}
