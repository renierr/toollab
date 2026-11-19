import 'dart:convert';
import 'dart:typed_data';

import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/todo/config.dart';
import 'package:tool_lab/tools/todo/models/todo_folder.dart';
import 'package:tool_lab/tools/todo/models/todo_list.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_db_helper.dart';

/// Record ids carry a kind prefix (`f_`, `l_`, `t_`, `a_`) so folders, lists,
/// tasks and attachment blobs share one sync namespace.
class TodoSyncDelegate with DefaultSyncDelegate implements SyncDelegate {
  static const Map<TodoRecordKind, String> _prefixes = {
    TodoRecordKind.folder: 'f_',
    TodoRecordKind.list: 'l_',
    TodoRecordKind.task: 't_',
    TodoRecordKind.attachment: 'a_',
  };

  final TodoDbHelper _db = TodoDbHelper.instance;

  @override
  String get toolId => TodoTool.config.id;

  @override
  int get syncPullBatchSize => 10;

  @override
  Duration get syncRequestTimeout => const Duration(seconds: 90);

  static String recordId(TodoRecordKind kind, String shortId) =>
      '${_prefixes[kind]}$shortId';

  static (TodoRecordKind, String)? parseId(String id) {
    for (final entry in _prefixes.entries) {
      if (id.startsWith(entry.value)) {
        return (entry.key, id.substring(entry.value.length));
      }
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async => [
    for (final r in await _db.getSyncRecords())
      {
        'id': recordId(r.kind, r.shortId),
        'updatedAt': r.updatedAt,
        'deleted': r.deleted,
      },
  ];

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    final parsed = parseId(id);
    if (parsed == null) return null;
    final (kind, shortId) = parsed;
    switch (kind) {
      case TodoRecordKind.folder:
        final folder = await _db.getFolder(shortId);
        return folder == null || folder.deleted ? null : folder.toJson();
      case TodoRecordKind.list:
        final list = await _db.getList(shortId);
        return list == null || list.deleted ? null : list.toJson();
      case TodoRecordKind.task:
        final task = await _db.getTask(shortId);
        return task == null || task.deleted ? null : task.toJson();
      case TodoRecordKind.attachment:
        final meta = await _db.getAttachment(shortId);
        final data = await _db.getAttachmentData(shortId);
        if (meta == null || data == null) return null;
        return {
          'taskId': meta.taskId,
          'name': meta.name,
          'mimeType': meta.mimeType,
          'createdAt': meta.createdAt,
          'data': {
            '__type': 'blob',
            'mimeType': meta.mimeType,
            'data': base64Encode(data),
          },
          if (meta.thumbnail != null)
            'thumbnail': {
              '__type': 'blob',
              'mimeType': 'image/jpeg',
              'data': base64Encode(meta.thumbnail!),
            },
        };
    }
  }

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    final parsed = parseId(id);
    if (parsed == null) return;
    final (kind, shortId) = parsed;
    if (deleted) {
      await _db.markPulledDeleted(kind, shortId, updatedAt);
      return;
    }
    switch (kind) {
      case TodoRecordKind.folder:
        await _db.upsertFolder(
          TodoFolder.fromJson(shortId, data, updatedAt: updatedAt),
          synced: true,
        );
      case TodoRecordKind.list:
        await _db.upsertList(
          TodoList.fromJson(shortId, data, updatedAt: updatedAt),
          synced: true,
        );
      case TodoRecordKind.task:
        await _db.upsertTask(
          TodoTask.fromJson(shortId, data, updatedAt: updatedAt),
          synced: true,
        );
      case TodoRecordKind.attachment:
        final bytes = _decodeBlob(data['data']);
        if (bytes == null) return;
        await _db.insertAttachment(
          shortId: shortId,
          taskId: data['taskId'] as String? ?? '',
          name: data['name'] as String? ?? 'file',
          mimeType: data['mimeType'] as String? ?? 'application/octet-stream',
          data: bytes,
          thumbnail: _decodeBlob(data['thumbnail']),
          createdAt: data['createdAt'] as int? ?? updatedAt,
          updatedAt: updatedAt,
          synced: true,
        );
    }
  }

  static Uint8List? _decodeBlob(Object? value) {
    if (value is String && value.isNotEmpty) {
      try {
        return base64Decode(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) async {
    final parsed = parseId(id);
    if (parsed == null) return;
    await _db.finalizeSync(parsed.$1, parsed.$2, wasDeleted);
  }
}
