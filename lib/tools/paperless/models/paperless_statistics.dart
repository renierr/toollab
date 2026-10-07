class PaperlessFileTypeCount {
  final String mimeType;
  final int count;

  const PaperlessFileTypeCount({required this.mimeType, required this.count});
}

/// `/api/statistics/`. paperless-ng only sends the two document totals; the
/// rest is paperless-ngx and stays null against an older server.
class PaperlessStatistics {
  final int documentsTotal;
  final int? documentsInbox;
  final int? characterCount;
  final int? tagCount;
  final int? correspondentCount;
  final int? documentTypeCount;
  final int? storagePathCount;
  final List<PaperlessFileTypeCount> fileTypes;

  const PaperlessStatistics({
    required this.documentsTotal,
    this.documentsInbox,
    this.characterCount,
    this.tagCount,
    this.correspondentCount,
    this.documentTypeCount,
    this.storagePathCount,
    this.fileTypes = const [],
  });

  factory PaperlessStatistics.fromJson(Map<String, dynamic> json) {
    final fileTypes = <PaperlessFileTypeCount>[
      for (final entry
          in json['document_file_type_counts'] as List<dynamic>? ?? const [])
        if (entry is Map<String, dynamic>)
          PaperlessFileTypeCount(
            mimeType: entry['mime_type'] as String? ?? '',
            count: entry['mime_type_count'] as int? ?? 0,
          ),
    ]..sort((a, b) => b.count.compareTo(a.count));

    return PaperlessStatistics(
      documentsTotal: json['documents_total'] as int? ?? 0,
      documentsInbox: json['documents_inbox'] as int?,
      characterCount: json['character_count'] as int?,
      tagCount: json['tag_count'] as int?,
      correspondentCount: json['correspondent_count'] as int?,
      documentTypeCount: json['document_type_count'] as int?,
      storagePathCount: json['storage_path_count'] as int?,
      fileTypes: fileTypes,
    );
  }
}
