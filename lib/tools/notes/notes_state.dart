import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/notes/config.dart';
import 'note_thread.dart';
import 'notes_db_helper.dart';
import 'notes_sync_delegate.dart';

class NotesState extends ChangeNotifier {
  static const String _sortSettingKey = 'thread_sort';

  List<Map<String, dynamic>> _allNotes = [];
  List<Map<String, dynamic>> _notes = [];
  NoteThread _thread = NoteThread.empty;
  NoteThreadSort _sort = NoteThreadSort.created;
  String _query = '';
  bool _isLoadingNotes = false;

  /// Notes matching the active search query.
  List<Map<String, dynamic>> get notes => _notes;

  /// Every active note, regardless of the search query. The thread is built
  /// from this so parents of a search hit stay resolvable.
  List<Map<String, dynamic>> get allNotes => _allNotes;
  NoteThread get thread => _thread;
  NoteThreadSort get sort => _sort;
  String get query => _query;
  bool get isLoadingNotes => _isLoadingNotes;

  Future<void> loadSort() async {
    final stored = await DatabaseService.instance.getSetting(
      NotesTool.config.id,
      _sortSettingKey,
    );
    if (stored == NoteThreadSort.updated.name) {
      _sort = NoteThreadSort.updated;
      _rebuildThread();
      notifyListeners();
    }
  }

  Future<void> setSort(NoteThreadSort sort) async {
    if (_sort == sort) return;
    _sort = sort;
    _rebuildThread();
    notifyListeners();
    await DatabaseService.instance.setSetting(
      NotesTool.config.id,
      _sortSettingKey,
      sort.name,
    );
  }

  Future<void> loadNotes({String? query}) async {
    if (query != null) _query = query;
    _isLoadingNotes = true;
    notifyListeners();
    try {
      _allNotes = await NotesDbHelper.instance.getActiveNotesWithTags();
    } catch (e) {
      errorLog('[NotesState] Failed to load notes with tags: $e');
      try {
        _allNotes = await NotesDbHelper.instance.getActiveNotes();
      } catch (e2) {
        errorLog('[NotesState] Failed to load notes (fallback): $e2');
      }
    } finally {
      _applyQuery();
      _isLoadingNotes = false;
      notifyListeners();
    }
  }

  void _applyQuery() {
    final needle = _query.trim().toLowerCase();
    _notes = needle.isEmpty
        ? _allNotes
        : _allNotes
              .where(
                (n) => (n['content'] as String? ?? '').toLowerCase().contains(
                  needle,
                ),
              )
              .toList();
    _rebuildThread();
  }

  void _rebuildThread() {
    _thread = NoteThread.build(_allNotes, sort: _sort);
  }

  Future<int> saveNote(
    String content, {
    int? id,
    String? shortId,
    List<String>? tags,
    String? parentShortId,
  }) async {
    final savedId = await NotesDbHelper.instance.saveNote(
      content,
      id: id,
      shortId: shortId,
      tags: tags,
      parentShortId: parentShortId,
    );
    await loadNotes();
    _backgroundSync();
    return savedId;
  }

  /// Attaches a note to [parentShortId], or detaches it when null.
  /// Returns false when the move would create a cycle.
  Future<bool> setParent(int id, String? parentShortId) async {
    final moved = await NotesDbHelper.instance.setParent(id, parentShortId);
    if (moved) {
      await loadNotes();
      _backgroundSync();
    }
    return moved;
  }

  /// Deletes a note. With [cascade] the whole subtree goes, otherwise the
  /// direct children are lifted to the deleted note's parent.
  Future<void> deleteNote(int id, {bool cascade = true}) async {
    if (cascade) {
      await NotesDbHelper.instance.softDeleteSubtree(id);
    } else {
      await NotesDbHelper.instance.softDeleteAndPromoteChildren(id);
    }
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
          parentShortId: note['parentShortId'] as String?,
        );
      }
    }
    await loadNotes();
    _backgroundSync();
  }

  void _backgroundSync() {
    _doBackgroundSync().catchError((e) {
      errorLog('[NotesState] Background sync failed: $e');
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
