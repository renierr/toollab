import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_back_button.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/tools/notes/note_thread.dart';
import 'package:tool_lab/tools/notes/notes_state.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/tools/notes/config.dart';
import 'package:tool_lab/tools/notes/notes_sync_delegate.dart';
import 'package:tool_lab/tools/notes/notes_db_helper.dart';

class NotesToolbar extends StatefulWidget {
  final Function(String query) onSearchChanged;
  final Function(String content) onImportMarkdown;
  final VoidCallback onRefresh;
  final List<String> allTags;
  final List<String> selectedFilterTags;
  final ValueChanged<List<String>> onFilterTagsChanged;
  final NoteThreadSort threadSort;
  final ValueChanged<NoteThreadSort> onThreadSortChanged;

  const NotesToolbar({
    super.key,
    required this.onSearchChanged,
    required this.onImportMarkdown,
    required this.onRefresh,
    this.allTags = const [],
    this.selectedFilterTags = const [],
    required this.onFilterTagsChanged,
    required this.threadSort,
    required this.onThreadSortChanged,
  });

  @override
  State<NotesToolbar> createState() => _NotesToolbarState();
}

class _NotesToolbarState extends State<NotesToolbar> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.isEmpty) {
      widget.onSearchChanged(value);
    } else {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        widget.onSearchChanged(value);
      });
    }
  }

  Future<void> _importMarkdown() async {
    const typeGroup = XTypeGroup(
      label: 'Markdown / Text',
      extensions: ['md', 'txt'],
      mimeTypes: ['text/markdown', 'text/plain'],
    );
    try {
      final XFile? file = await openFile(acceptedTypeGroups: const [typeGroup]);
      if (file != null) {
        final content = await file.readAsString();
        widget.onImportMarkdown(content);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.notesFailedToReadFile(e.toString()))),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    const typeGroup = XTypeGroup(
      label: 'JSON Backups',
      extensions: ['json'],
      mimeTypes: ['application/json'],
    );
    try {
      final XFile? file = await openFile(acceptedTypeGroups: const [typeGroup]);
      if (file != null) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);

        if (data['generator'] != 'browser-toolkit-notes') {
          throw Exception('Invalid backup file signature');
        }

        final List<dynamic>? notesList = data['notes'] as List<dynamic>?;
        if (notesList == null) {
          throw Exception('Notes list missing in backup');
        }

        if (!mounted) return;
        final notesState = context.read<NotesState>();
        final castedList = notesList
            .map((n) => Map<String, dynamic>.from(n as Map))
            .toList();

        await notesState.importNotesFromJson(castedList);

        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.notesBackupImportedSuccessfully),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.notesImportFailed(e.toString())),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _exportBackup() async {
    try {
      final dbNotes = await NotesDbHelper.instance.getActiveNotesWithTags();
      final notesList = [for (final n in dbNotes) n.toBackupJson()];

      final backupData = {
        'generator': 'browser-toolkit-notes',
        'version': 1,
        'exportedAt': DateTime.now().millisecondsSinceEpoch,
        'notes': notesList,
      };

      final jsonString = jsonEncode(backupData);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      final date = FormatHelper.dateTime(
        DateTime.now(),
        style: DateStyle.dateOnly,
      );
      if (!mounted) return;
      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: 'notes-backup-$date.json',
        bytes: bytes,
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'JSON Backups',
            extensions: ['json'],
            mimeTypes: ['application/json'],
          ),
        ],
      );
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.notesFailedToExportNotes(e.toString()))),
        );
      }
    }
  }

  Future<void> _triggerSync() async {
    final l10n = AppLocalizations.of(context);
    final appState = context.read<AppState>();
    if (appState.syncServerUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.notesSyncConfigureServerUrl)));
      return;
    }
    if (!appState.isToolSyncEnabled(NotesTool.config.id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.coreSyncToolDisabled)));
      return;
    }

    try {
      final results = await appState.syncWithBackend([NotesSyncDelegate()]);
      if (results != null) {
        widget.onRefresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.notesSyncFinished(
                  results['pulled'] ?? 0,
                  results['pushed'] ?? 0,
                  results['deleted'] ?? 0,
                ),
              ),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.notesSyncFailedEmpty)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.notesSyncFailed(e.toString())),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final isSyncing = appState.isSyncing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const ToolBackButton(),
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: l10n.notesSearchHint,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: l10n.notesSyncWithCloud,
                child: isSyncing
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.accentTeal,
                            ),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.sync),
                        color: AppTheme.accentTeal,
                        onPressed: _triggerSync,
                      ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'import_md') {
                    _importMarkdown();
                  } else if (value == 'import_backup') {
                    _importBackup();
                  } else if (value == 'export_backup') {
                    _exportBackup();
                  } else if (value == 'sort_created') {
                    widget.onThreadSortChanged(NoteThreadSort.created);
                  } else if (value == 'sort_updated') {
                    widget.onThreadSortChanged(NoteThreadSort.updated);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'import_md',
                    child: Row(
                      children: [
                        const Icon(Icons.file_open_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.notesImportMarkdownFile),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'import_backup',
                    child: Row(
                      children: [
                        const Icon(Icons.restore, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.notesImportJsonBackup),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export_backup',
                    child: Row(
                      children: [
                        const Icon(Icons.backup_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.notesExportJsonBackup),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    enabled: false,
                    height: 32,
                    child: Text(
                      l10n.notesThreadSortTooltip,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  CheckedPopupMenuItem(
                    value: 'sort_created',
                    checked: widget.threadSort == NoteThreadSort.created,
                    child: Text(l10n.notesThreadSortCreated),
                  ),
                  CheckedPopupMenuItem(
                    value: 'sort_updated',
                    checked: widget.threadSort == NoteThreadSort.updated,
                    child: Text(l10n.notesThreadSortUpdated),
                  ),
                ],
              ),
            ],
          ),
          if (widget.allTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.allTags.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final tag = widget.allTags[index];
                    final isSelected = widget.selectedFilterTags.contains(tag);
                    return FilterChip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (selected) {
                        final updated = List<String>.from(
                          widget.selectedFilterTags,
                        );
                        if (selected) {
                          updated.add(tag);
                        } else {
                          updated.remove(tag);
                        }
                        widget.onFilterTagsChanged(updated);
                      },
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      selectedColor: AppTheme.accentTeal.withValues(alpha: 0.2),
                      checkmarkColor: AppTheme.accentTeal,
                      side: BorderSide.none,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppTheme.accentTeal
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
