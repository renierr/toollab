import 'package:flutter/material.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'notes_db_helper.dart';
import 'notes_sync_delegate.dart';

class NotesState extends ChangeNotifier {
  List<Map<String, dynamic>> _notes = [];
  bool _isLoadingNotes = false;

  List<Map<String, dynamic>> get notes => _notes;
  bool get isLoadingNotes => _isLoadingNotes;

  Future<void> loadNotes({String query = ''}) async {
    _isLoadingNotes = true;
    notifyListeners();
    try {
      _notes = await NotesDbHelper.instance.getActiveNotesWithTags(
        query: query,
      );
    } catch (e) {
      debugPrint('[NotesState] Failed to load notes with tags: $e');
      try {
        _notes = await NotesDbHelper.instance.getActiveNotes(query: query);
      } catch (e2) {
        debugPrint('[NotesState] Failed to load notes (fallback): $e2');
      }
    } finally {
      _isLoadingNotes = false;
      notifyListeners();
    }
  }

  Future<void> saveNote(
    String content, {
    int? id,
    String? shortId,
    List<String>? tags,
  }) async {
    await NotesDbHelper.instance.saveNote(
      content,
      id: id,
      shortId: shortId,
      tags: tags,
    );
    await loadNotes();
    _backgroundSync();
  }

  Future<void> deleteNote(int id) async {
    await NotesDbHelper.instance.softDeleteNote(id);
    await loadNotes();
    _backgroundSync();
  }

  Future<void> importNotesFromJson(List<Map<String, dynamic>> notesList) async {
    for (final note in notesList) {
      final content = note['content'] as String? ?? '';
      if (content.trim().isEmpty) continue;
      final shortId = note['shortId'] as String?;
      final createdAt = note['createdAt'] as int?;
      final updatedAt = note['updatedAt'] as int?;
      final tags = (note['tags'] as List<dynamic>?)?.cast<String>();

      final existing = shortId != null
          ? await NotesDbHelper.instance.getNoteByShortId(shortId)
          : null;
      if (existing == null) {
        await NotesDbHelper.instance.savePulledNote(
          shortId: shortId ?? NotesDbHelper.instance.generateShortId(),
          content: content,
          createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch,
          updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
          deleted: false,
          tags: tags,
        );
      }
    }
    await loadNotes();
    _backgroundSync();
  }

  void _backgroundSync() {
    _doBackgroundSync().catchError((e) {
      debugPrint('[NotesState] Background sync failed: $e');
    });
  }

  Future<void> _doBackgroundSync() async {
    final syncEnabled = await DatabaseService.instance.getSetting(
      '_app',
      'sync_enabled',
    );
    if (syncEnabled != 'true') return;
    final serverUrl = await DatabaseService.instance.getSetting(
      '_app',
      'sync_server_url',
    );
    if (serverUrl == null || serverUrl.isEmpty) return;
    final userId =
        await DatabaseService.instance.getSetting('_app', 'sync_user_id') ?? '';

    await SyncService.sync(
      baseUrl: serverUrl,
      userId: userId,
      delegate: NotesSyncDelegate(),
    );
  }
}
