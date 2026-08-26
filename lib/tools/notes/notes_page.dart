import 'dart:io';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/tools/notes/note.dart';
import 'package:tool_lab/tools/notes/notes_state.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/tools/notes/config.dart';
import 'package:tool_lab/tools/notes/widgets/markdown_drop_zone.dart';
import 'package:tool_lab/tools/notes/widgets/notes_list.dart';
import 'package:tool_lab/tools/notes/widgets/notes_toolbar.dart';
import 'package:tool_lab/tools/notes/widgets/note_editor.dart';
import 'package:tool_lab/tools/notes/note_title.dart';
import 'package:tool_lab/tools/notes/widgets/note_delete_dialog.dart';
import 'package:tool_lab/tools/notes/widgets/note_followups_section.dart';
import 'package:tool_lab/tools/notes/widgets/note_parent_picker_dialog.dart';
import 'package:tool_lab/tools/notes/widgets/note_thread_outline.dart';
import 'package:tool_lab/widgets/markdown_viewer_page.dart';
import 'package:tool_lab/tools/notes/notes_sync_delegate.dart';

class NotesPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const NotesPage({super.key, this.sharedFile});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with DisposeCleanup {
  bool _isEditing = false;
  int? _editingId;
  String _editingContent = '';
  List<String> _editingTags = [];
  String? _editingParentShortId;
  String? _editingParentTitle;
  String? _viewingShortId;

  /// Note to return to when the editor was opened from the viewer.
  String? _returnToShortId;
  String _searchQuery = '';
  List<String> _selectedFilterTags = [];

  @override
  void initState() {
    super.initState();

    final appState = context.read<AppState>();
    final notesState = context.read<NotesState>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notesState.loadSort();
      notesState.loadNotes();

      if (appState.syncEnabled &&
          appState.syncServerUrl.isNotEmpty &&
          appState.isToolSyncEnabled(NotesTool.config.id)) {
        appState
            .syncWithBackend([NotesSyncDelegate()])
            .then((_) {
              if (mounted) {
                notesState.loadNotes();
              }
            })
            .catchError((e) {
              errorLog('[NotesPage] Auto-sync on open failed: $e');
            });
      }

      if (widget.sharedFile != null) {
        _loadSharedFile(widget.sharedFile!);
      }
    });

    final sharingSub = SharingService.instance.onSharedFile.listen((file) {
      final mime = file.mimeType.toLowerCase();
      if (mime == 'text/markdown' ||
          mime == 'text/plain' ||
          file.name.endsWith('.md') ||
          file.name.endsWith('.txt')) {
        _loadSharedFile(file);
      }
    });
    onDispose(sharingSub.cancel);
  }

  Future<void> _loadSharedFile(SharedFile file) async {
    try {
      final diskFile = File(file.path);
      if (await diskFile.exists()) {
        final text = await diskFile.readAsString();
        final fileName = file.name;

        setState(() {
          _isEditing = true;
          _editingId = null;
          _editingContent = text.trim().startsWith('# ')
              ? text
              : '# $fileName\n\n$text';
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.notesFailedToLoadSharedFile(e.toString())),
          ),
        );
      }
    }
  }

  void _openEditor({
    int? id,
    String content = '',
    List<String> tags = const [],
    String? parentShortId,
    String? parentTitle,
  }) {
    setState(() {
      _isEditing = true;
      _editingId = id;
      _editingContent = content;
      _editingTags = tags;
      _editingParentShortId = parentShortId;
      _editingParentTitle = parentTitle;
      _returnToShortId = _viewingShortId;
      _viewingShortId = null;
    });
  }

  void _closeEditor() {
    setState(() {
      _isEditing = false;
      _editingId = null;
      _editingContent = '';
      _editingTags = [];
      _editingParentShortId = null;
      _editingParentTitle = null;
      _viewingShortId = _returnToShortId;
      _returnToShortId = null;
    });
  }

  void _openViewer(Note note) {
    setState(() {
      _viewingShortId = note.shortId;
    });
  }

  void _closeViewer() {
    setState(() {
      _viewingShortId = null;
    });
  }

  void _addFollowUp(Note note) {
    final l10n = AppLocalizations.of(context);
    _openEditor(
      parentShortId: note.shortId,
      parentTitle: noteTitle(note.content, fallback: l10n.notesUntitledNote),
      tags: note.tags,
    );
  }

  Future<void> _attachNote(Note note) async {
    final notesState = context.read<NotesState>();
    final l10n = AppLocalizations.of(context);
    final parentShortId = await NoteParentPickerDialog.show(
      context: context,
      thread: notesState.thread,
      shortId: note.shortId,
    );
    if (parentShortId == null || !mounted) return;
    final moved = await notesState.setParent(note.id, parentShortId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(moved ? l10n.notesAttached : l10n.notesAttachFailed),
        backgroundColor: moved ? AppTheme.accentGreen : AppTheme.accentRed,
      ),
    );
  }

  Future<void> _detachNote(Note note) async {
    final notesState = context.read<NotesState>();
    final l10n = AppLocalizations.of(context);
    await notesState.setParent(note.id, null);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.notesDetached)));
  }

  Future<void> _saveNote(String content, List<String> tags) async {
    final notesState = context.read<NotesState>();
    try {
      await notesState.saveNote(
        content,
        id: _editingId,
        tags: tags,
        parentShortId: _editingParentShortId,
      );
      _closeEditor();
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.notesNoteSaved),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.notesFailedToSaveNote(e.toString())),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  /// Persists (and syncs) without leaving the editor; a new note becomes the
  /// editor's current note so the next save updates instead of inserting.
  Future<bool> _saveNoteKeepEditing(String content, List<String> tags) async {
    final notesState = context.read<NotesState>();
    final l10n = AppLocalizations.of(context);
    try {
      final savedId = await notesState.saveNote(
        content,
        id: _editingId,
        tags: tags,
        parentShortId: _editingParentShortId,
      );
      if (!mounted) return true;
      setState(() {
        _editingId = savedId;
        _editingTags = tags;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.notesNoteSaved),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.notesFailedToSaveNote(e.toString())),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _deleteNote(int id) async {
    final l10n = AppLocalizations.of(context);
    final notesState = context.read<NotesState>();
    final followUps = notesState.thread.nodeForId(id)?.descendantCount ?? 0;

    bool cascade = true;
    if (followUps > 0) {
      final choice = await NoteDeleteDialog.show(
        context: context,
        followUpCount: followUps,
      );
      if (choice == null || !mounted) return;
      cascade = choice == NoteDeleteChoice.cascade;
    } else {
      final confirmed = await ConfirmActionDialog.show(
        context: context,
        title: l10n.notesDeleteNoteTitle,
        message: l10n.notesDeleteNoteMessage,
        confirmLabel: l10n.commonDelete,
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      await notesState.deleteNote(id, cascade: cascade);
      setState(() {
        _viewingShortId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.notesNoteDeleted)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.notesFailedToDeleteNote(e.toString()))),
        );
      }
    }
  }

  Future<void> _importDroppedFile(File file, String name) async {
    final notesState = context.read<NotesState>();
    try {
      final text = await file.readAsString();
      final content = text.trim().startsWith('# ') ? text : '# $name\n\n$text';
      await notesState.saveNote(content);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.notesImportedNoteFrom(name)),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.notesFailedToImportDroppedFile(e.toString())),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notesState = context.watch<NotesState>();
    final notes = notesState.notes;

    final allTags = <String>{
      for (final note in notesState.allNotes) ...note.tags,
    };
    final sortedAllTags = allTags.toList()..sort();

    bool matchesTags(Note note) {
      if (_selectedFilterTags.isEmpty) return true;
      return _selectedFilterTags.every((t) => note.tags.contains(t));
    }

    final filteredNotes = notes.where(matchesTags).toList();
    // A thread stays visible as long as any note inside it matches.
    final visibleRoots = notesState.thread.roots
        .where((root) => root.flatten().any((n) => matchesTags(n.note)))
        .toList();
    final searchMode = _searchQuery.trim().isNotEmpty;

    if (_isEditing) {
      return NoteEditor(
        id: _editingId,
        initialContent: _editingContent,
        initialTags: _editingTags,
        allTags: sortedAllTags,
        parentTitle: _editingParentTitle,
        onSave: _saveNote,
        onSaveKeepEditing: _saveNoteKeepEditing,
        onCancel: _closeEditor,
      );
    }

    final viewingNode = notesState.thread.nodeForShortId(_viewingShortId);
    if (viewingNode != null) {
      final currentNote = viewingNode.note;
      final content = currentNote.content;
      final shortId = currentNote.shortId;
      return MarkdownViewerPage(
        content: content,
        config: MarkdownViewerConfig(
          accentColor: AppTheme.accentTeal,
          title: l10n.notesViewNoteTitle,
          showEdit: true,
          showDelete: true,
          headerSection: NoteThreadOutline(
            thread: notesState.thread,
            currentShortId: shortId,
            accentColor: AppTheme.accentTeal,
            onOpenNote: (node) =>
                setState(() => _viewingShortId = node.note.shortId),
          ),
          footerSection: NoteFollowUpsSection(
            node: viewingNode,
            accentColor: AppTheme.accentTeal,
            onOpenNote: (node) =>
                setState(() => _viewingShortId = node.note.shortId),
            onAddFollowUp: () => _addFollowUp(currentNote),
          ),
          extraActions: [
            IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: l10n.notesAddFollowUp,
              onPressed: () => _addFollowUp(currentNote),
            ),
            if (currentNote.parentShortId == null)
              IconButton(
                icon: const Icon(Icons.account_tree_outlined),
                tooltip: l10n.notesAttachToNote,
                onPressed: () => _attachNote(currentNote),
              )
            else
              IconButton(
                icon: const Icon(Icons.link_off),
                tooltip: l10n.notesDetachFromParent,
                onPressed: () => _detachNote(currentNote),
              ),
          ],
          onEdit: () {
            _openEditor(
              id: currentNote.id,
              content: content,
              tags: currentNote.tags,
            );
          },
          onDelete: () {
            _deleteNote(currentNote.id);
          },
          onClose: _closeViewer,
          exportSuggestedName: 'note-$shortId.md',
          updatedAt: currentNote.updatedAt,
        ),
      );
    }

    return ToolLayout(
      title: NotesTool.config.localizedName(l10n),
      fullscreen: true,
      showFloatingBackButton: false,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: AppTheme.accentTeal,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add),
      ),
      child: MarkdownDropZone(
        onFileDropped: _importDroppedFile,
        child: Column(
          children: [
            NotesToolbar(
              onSearchChanged: (query) {
                setState(() {
                  _searchQuery = query;
                });
                notesState.loadNotes(query: query);
              },
              onImportMarkdown: (content) {
                _openEditor(content: content);
              },
              onRefresh: () {
                notesState.loadNotes(query: _searchQuery);
              },
              allTags: sortedAllTags,
              selectedFilterTags: _selectedFilterTags,
              onFilterTagsChanged: (tags) {
                setState(() => _selectedFilterTags = tags);
              },
              threadSort: notesState.sort,
              onThreadSortChanged: notesState.setSort,
            ),
            Expanded(
              child: notesState.isLoadingNotes
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.accentTeal,
                        ),
                      ),
                    )
                  : NotesList(
                      notes: filteredNotes,
                      roots: visibleRoots,
                      thread: notesState.thread,
                      searchMode: searchMode,
                      onTap: _openViewer,
                      onAddFollowUp: _addFollowUp,
                      onAttach: _attachNote,
                      onDetach: _detachNote,
                      onEdit: (note) {
                        _openEditor(
                          id: note.id,
                          content: note.content,
                          tags: note.tags,
                        );
                      },
                      onDelete: (note) {
                        _deleteNote(note.id);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
