class TrimzSyncRecord {
  final String id;
  final int updatedAt;
  final bool deleted;

  const TrimzSyncRecord({
    required this.id,
    required this.updatedAt,
    required this.deleted,
  });

  factory TrimzSyncRecord.fromMap(Map<String, Object?> map) => TrimzSyncRecord(
    id: map['id']! as String,
    updatedAt: map['updated_at'] as int? ?? 0,
    deleted: map['deleted'] == 1,
  );
}
