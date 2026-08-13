import 'dart:io';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
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
  bool _isViewing = false;
  Map<String, dynamic>? _viewingNote;
  String _searchQuery = '';
  List<String> _selectedFilterTags = [];

  @override
  void initState() {
    super.initState();

    final appState = context.read<AppState>();
    final notesState = context.read<NotesState>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
  }) {
    setState(() {
      _isEditing = true;
      _editingId = id;
      _editingContent = content;
      _editingTags = tags;
      _isViewing = false;
      _viewingNote = null;
    });
  }

  void _closeEditor() {
    setState(() {
      _isEditing = false;
      _editingId = null;
      _editingContent = '';
      _editingTags = [];
    });
  }

  void _openViewer(Map<String, dynamic> note) {
    setState(() {
      _isViewing = true;
      _viewingNote = note;
    });
  }

  void _closeViewer() {
    setState(() {
      _isViewing = false;
      _viewingNote = null;
    });
  }

  Future<void> _saveNote(String content, List<String> tags) async {
    final notesState = context.read<NotesState>();
    try {
      await notesState.saveNote(content, id: _editingId, tags: tags);
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

  Future<void> _deleteNote(int id) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.notesDeleteNoteTitle,
      message: l10n.notesDeleteNoteMessage,
      confirmLabel: l10n.commonDelete,
    );

    if (confirmed == true && mounted) {
      final notesState = context.read<NotesState>();
      try {
        await notesState.deleteNote(id);
        setState(() {
          _isViewing = false;
          _viewingNote = null;
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

    final allTags = <String>{};
    for (final note in notes) {
      final noteTags = note['tags'] as List<dynamic>? ?? [];
      allTags.addAll(noteTags.cast<String>());
    }
    final sortedAllTags = allTags.toList()..sort();

    final filteredNotes = _selectedFilterTags.isEmpty
        ? notes
        : notes.where((n) {
            final noteTags =
                (n['tags'] as List<dynamic>?)?.cast<String>() ?? [];
            return _selectedFilterTags.every((t) => noteTags.contains(t));
          }).toList();

    if (_isEditing) {
      return NoteEditor(
        id: _editingId,
        initialContent: _editingContent,
        initialTags: _editingTags,
        allTags: sortedAllTags,
        onSave: _saveNote,
        onCancel: _closeEditor,
      );
    }

    if (_isViewing && _viewingNote != null) {
      final currentNote = _viewingNote!;
      final content = currentNote['content'] as String? ?? '';
      final updatedAt = currentNote['updated_at'] as int? ?? 0;
      final shortId = currentNote['short_id'] as String? ?? 'note';
      return MarkdownViewerPage(
        content: content,
        config: MarkdownViewerConfig(
          accentColor: AppTheme.accentTeal,
          title: l10n.notesViewNoteTitle,
          showEdit: true,
          showDelete: true,
          onEdit: () {
            _openEditor(
              id: currentNote['id'] as int,
              content: content,
              tags:
                  (currentNote['tags'] as List<dynamic>?)?.cast<String>() ?? [],
            );
          },
          onDelete: () {
            _deleteNote(currentNote['id'] as int);
          },
          onClose: _closeViewer,
          exportSuggestedName: 'note-$shortId.md',
          updatedAt: updatedAt,
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
                      onTap: _openViewer,
                      onEdit: (note) {
                        _openEditor(
                          id: note['id'] as int,
                          content: note['content'] as String,
                          tags:
                              (note['tags'] as List<dynamic>?)
                                  ?.cast<String>() ??
                              [],
                        );
                      },
                      onDelete: (note) {
                        _deleteNote(note['id'] as int);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
