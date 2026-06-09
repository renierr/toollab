import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/providers/app_state.dart';
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
  bool _isViewing = false;
  Map<String, dynamic>? _viewingNote;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    final appState = context.read<AppState>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      appState.loadNotes();

      if (appState.syncEnabled && appState.syncServerUrl.isNotEmpty) {
        appState
            .syncWithBackend([NotesSyncDelegate()])
            .then((_) {
              if (mounted) {
                appState.loadNotes();
              }
            })
            .catchError((e) {
              debugPrint('[NotesPage] Auto-sync on open failed: $e');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load shared file: $e')),
        );
      }
    }
  }

  void _openEditor({int? id, String content = ''}) {
    setState(() {
      _isEditing = true;
      _editingId = id;
      _editingContent = content;
      _isViewing = false;
      _viewingNote = null;
    });
  }

  void _closeEditor() {
    setState(() {
      _isEditing = false;
      _editingId = null;
      _editingContent = '';
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

  Future<void> _saveNote(String content) async {
    final appState = context.read<AppState>();
    try {
      await appState.saveNote(content, id: _editingId);
      _closeEditor();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note saved'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save note: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _deleteNote(int id) async {
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: 'Delete Note',
      message: 'Are you sure you want to delete this note?',
      confirmLabel: 'Delete',
    );

    if (confirmed == true && mounted) {
      final appState = context.read<AppState>();
      try {
        await appState.deleteNote(id);
        setState(() {
          _isViewing = false;
          _viewingNote = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Note deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete note: $e')));
        }
      }
    }
  }

  Future<void> _importDroppedFile(File file, String name) async {
    final appState = context.read<AppState>();
    try {
      final text = await file.readAsString();
      final content = text.trim().startsWith('# ') ? text : '# $name\n\n$text';
      await appState.saveNote(content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported note from "$name"'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import dropped file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final notes = appState.notes;

    if (_isEditing) {
      return NoteEditor(
        id: _editingId,
        initialContent: _editingContent,
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
          title: 'View Note',
          showEdit: true,
          showDelete: true,
          onEdit: () {
            _openEditor(id: currentNote['id'] as int, content: content);
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
      title: NotesTool.config.name,
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
                appState.loadNotes(query: query);
              },
              onImportMarkdown: (content) {
                _openEditor(content: content);
              },
              onRefresh: () {
                appState.loadNotes(query: _searchQuery);
              },
            ),
            Expanded(
              child: appState.isLoadingNotes
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.accentTeal,
                        ),
                      ),
                    )
                  : NotesList(
                      notes: notes,
                      onTap: _openViewer,
                      onEdit: (note) {
                        _openEditor(
                          id: note['id'] as int,
                          content: note['content'] as String,
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
