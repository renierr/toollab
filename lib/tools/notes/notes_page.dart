import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/tools/notes/config.dart';
import 'package:tool_lab/tools/notes/widgets/notes_list.dart';
import 'package:tool_lab/tools/notes/widgets/notes_toolbar.dart';
import 'package:tool_lab/tools/notes/widgets/note_editor.dart';

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
  String _searchQuery = '';
  bool _dragging = false;

  @override
  void initState() {
    super.initState();

    final appState = context.read<AppState>();

    // Load initial notes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appState.loadNotes();

      // Handle initial shared file if any
      if (widget.sharedFile != null) {
        _loadSharedFile(widget.sharedFile!);
      }
    });

    // Listen to shared files stream
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

        // Open editor populated with the file contents
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
    });
  }

  void _closeEditor() {
    setState(() {
      _isEditing = false;
      _editingId = null;
      _editingContent = '';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final appState = context.read<AppState>();
      try {
        await appState.deleteNote(id);
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
    final theme = Theme.of(context);

    if (_isEditing) {
      return NoteEditor(
        id: _editingId,
        initialContent: _editingContent,
        onSave: _saveNote,
        onCancel: _closeEditor,
      );
    }

    return ToolLayout(
      title: NotesTool.config.name,
      fullscreen: NotesTool.config.fullscreen,
      child: DropTarget(
        onDragDone: (details) async {
          if (details.files.isNotEmpty) {
            for (final file in details.files) {
              final name = file.name.toLowerCase();
              if (name.endsWith('.md') || name.endsWith('.txt')) {
                final diskFile = File(file.path);
                await _importDroppedFile(diskFile, file.name);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Only Markdown (.md) or Text (.txt) files are supported',
                    ),
                  ),
                );
              }
            }
          }
        },
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        child: Stack(
          children: [
            Column(
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
            if (_dragging)
              Container(
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                child: Center(
                  child: Container(
                    width: 320,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppTheme.accentTeal,
                        width: 3,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      color: AppTheme.accentTeal.withValues(alpha: 0.1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_upload_outlined,
                          size: 64,
                          color: AppTheme.accentTeal,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Drop Markdown file here',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () => _openEditor(),
                backgroundColor: AppTheme.accentTeal,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
