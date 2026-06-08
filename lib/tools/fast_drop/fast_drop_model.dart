class FastDropItem {
  final String id;
  final String filename;
  final int size;
  final String type;
  final String source;
  final int uploadedAt;
  final int? expiresAt;

  FastDropItem({
    required this.id,
    required this.filename,
    required this.size,
    required this.type,
    required this.source,
    required this.uploadedAt,
    this.expiresAt,
  });

  factory FastDropItem.fromJson(Map<String, dynamic> json) {
    return FastDropItem(
      id: json['id'] as String,
      filename: json['filename'] as String,
      size: json['size'] as int,
      type: json['type'] as String,
      source: json['source'] as String,
      uploadedAt:
          json['uploaded_at'] as int? ?? json['uploadedAt'] as int? ?? 0,
      expiresAt: json['expires_at'] as int? ?? json['expiresAt'] as int?,
    );
  }
}
