class PaperlessDocument {
  final int id;
  final String title;
  final DateTime? created;
  final DateTime? added;
  final int? correspondentId;
  final int? documentTypeId;
  final List<int> tagIds;
  final int? archiveSerialNumber;
  final String? originalFileName;

  const PaperlessDocument({
    required this.id,
    required this.title,
    this.created,
    this.added,
    this.correspondentId,
    this.documentTypeId,
    this.tagIds = const [],
    this.archiveSerialNumber,
    this.originalFileName,
  });

  factory PaperlessDocument.fromJson(Map<String, dynamic> json) {
    return PaperlessDocument(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      created: _parseDate(json['created']),
      added: _parseDate(json['added']),
      correspondentId: json['correspondent'] as int?,
      documentTypeId: json['document_type'] as int?,
      tagIds: (json['tags'] as List<dynamic>? ?? const [])
          .whereType<int>()
          .toList(growable: false),
      archiveSerialNumber: json['archive_serial_number'] as int?,
      originalFileName: json['original_file_name'] as String?,
    );
  }

  // Older APIs send a full timestamp, newer ones a bare date for `created`.
  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}
