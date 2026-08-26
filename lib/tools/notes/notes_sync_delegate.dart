import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/notes/config.dart';
import 'package:tool_lab/tools/notes/notes_db_helper.dart';

class NotesSyncDelegate with DefaultSyncDelegate implements SyncDelegate {
  @override
  String get toolId => NotesTool.config.id;

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final records = await NotesDbHelper.instance.getSyncRecords();
    return [
      for (final r in records)
        {'id': r.shortId, 'updatedAt': r.updatedAt, 'deleted': r.deleted},
    ];
  }

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    final note = await NotesDbHelper.instance.getNoteByShortId(id);
    if (note == null || note.deleted) return null;
    return note.toBackupJson();
  }

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    final tags = (data['tags'] as List<dynamic>?)?.cast<String>();
    await NotesDbHelper.instance.savePulledNote(
      shortId: id,
      content: data['content'] as String? ?? '',
      createdAt: data['createdAt'] as int? ?? updatedAt,
      updatedAt: updatedAt,
      deleted: deleted,
      tags: tags,
      parentShortId: data['parentShortId'] as String?,
    );
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) async {
    if (wasDeleted) {
      await NotesDbHelper.instance.hardDeleteNote(id);
    } else {
      await NotesDbHelper.instance.markSynced(id);
    }
  }
}
