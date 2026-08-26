/// A note row. Built from a `notes` table row via [Note.fromMap]; nothing
/// outside [NotesDbHelper] should touch the raw map.
class Note {
  final int id;
  final String shortId;
  final String content;
  final String? parentShortId;
  final int createdAt;
  final int updatedAt;
  final bool deleted;
  final bool synced;

  /// Empty when the note was loaded without the tag join.
  final List<String> tags;

  const Note({
    required this.id,
    required this.shortId,
    required this.content,
    this.parentShortId,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    this.synced = false,
    this.tags = const [],
  });

  factory Note.fromMap(
    Map<String, dynamic> map, {
    List<String> tags = const [],
  }) {
    return Note(
      id: map['id'] as int? ?? 0,
      shortId: map['short_id'] as String? ?? '',
      content: map['content'] as String? ?? '',
      parentShortId: map['parent_short_id'] as String?,
      createdAt: map['created_at'] as int? ?? 0,
      updatedAt: map['updated_at'] as int? ?? 0,
      deleted: (map['deleted'] as int? ?? 0) == 1,
      synced: (map['synced'] as int? ?? 0) == 1,
      tags: tags,
    );
  }

  Note copyWith({List<String>? tags}) => Note(
    id: id,
    shortId: shortId,
    content: content,
    parentShortId: parentShortId,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
    synced: synced,
    tags: tags ?? this.tags,
  );

  /// Wire format shared by the sync push and the JSON backup export.
  Map<String, dynamic> toBackupJson() => {
    'shortId': shortId,
    'content': content,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    if (tags.isNotEmpty) 'tags': tags,
    if (parentShortId != null) 'parentShortId': parentShortId,
  };
}

/// Manifest entry from the sync record query — no content, no tags.
class NoteSyncRecord {
  final String shortId;
  final int updatedAt;
  final bool deleted;

  const NoteSyncRecord({
    required this.shortId,
    required this.updatedAt,
    required this.deleted,
  });

  factory NoteSyncRecord.fromMap(Map<String, dynamic> map) => NoteSyncRecord(
    shortId: map['short_id'] as String? ?? '',
    updatedAt: map['updated_at'] as int? ?? 0,
    deleted: (map['deleted'] as int? ?? 0) == 1,
  );
}
