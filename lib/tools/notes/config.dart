import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'notes_sync_delegate.dart';
import 'notes_page.dart';
import 'notes_state.dart';

class NotesTool {
  NotesTool._();

  static ToolModel get config => ToolModel(
    id: 'notes',
    name: 'Notes',
    description:
        'Simple note taking tool with Markdown support and backend sync',
    icon: Icons.note_alt_outlined,
    route: '/notes',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameNotes,
    descriptionL10n: (l10n) => l10n.toolDescNotes,
    shareTarget: ShareTargetConfig(accept: ['text/markdown', 'text/plain']),
    fileExtensions: ['md', 'txt', 'markdown'],
    createPage: (sd) => NotesPage(sharedFile: sd?.firstFile),
    syncDelegateFactory: NotesSyncDelegate.new,
    stateProviders: () => [
      ChangeNotifierProvider<NotesState>(create: (_) => NotesState()),
    ],
  );
}
