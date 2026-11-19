import 'dart:typed_data';

/// Metadata only; the bytes are read on demand via the DB helper.
class TodoAttachment {
  final String shortId;
  final String taskId;
  final String name;
  final String mimeType;
  final int size;
  final Uint8List? thumbnail;
  final int createdAt;
  final int updatedAt;

  const TodoAttachment({
    required this.shortId,
    required this.taskId,
    required this.name,
    required this.mimeType,
    required this.size,
    this.thumbnail,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isImage => mimeType.startsWith('image/');

  factory TodoAttachment.fromMap(Map<String, Object?> map) => TodoAttachment(
    shortId: map['short_id'] as String? ?? '',
    taskId: map['task_id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    mimeType: map['mime_type'] as String? ?? 'application/octet-stream',
    size: map['size'] as int? ?? 0,
    thumbnail: map['thumbnail'] as Uint8List?,
    createdAt: map['created_at'] as int? ?? 0,
    updatedAt: map['updated_at'] as int? ?? 0,
  );
}
