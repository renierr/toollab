import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/notes/notes_db_helper.dart';

class NotesSyncDelegate implements SyncDelegate {
  @override
  String get toolId => 'notes';

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final records = await NotesDbHelper.instance.getSyncRecords();
    return records
        .map(
          (r) => {
            'id': r['short_id'] as String,
            'updatedAt': r['updated_at'] as int,
            'deleted': (r['deleted'] as int) == 1,
          },
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    final note = await NotesDbHelper.instance.getNoteByShortId(id);
    if (note == null || (note['deleted'] as int) == 1) return null;
    return {
      'shortId': note['short_id'] as String,
      'content': note['content'] as String,
      'createdAt': note['created_at'] as int,
      'updatedAt': note['updated_at'] as int,
    };
  }

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    await NotesDbHelper.instance.savePulledNote(
      shortId: id,
      content: data['content'] as String? ?? '',
      createdAt: data['createdAt'] as int? ?? updatedAt,
      updatedAt: updatedAt,
      deleted: deleted,
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
