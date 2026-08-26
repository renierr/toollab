import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/pdf_export_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/notes/note_thread.dart';
import 'package:tool_lab/tools/notes/note_thread_markdown.dart';
import 'package:tool_lab/tools/notes/note_title.dart';

/// Exports a note and all of its follow-ups as a single PDF.
Future<void> exportThreadPdf(BuildContext context, NoteThreadNode root) async {
  final l10n = AppLocalizations.of(context);
  final title = noteTitle(
    root.note['content'] as String? ?? '',
    fallback: l10n.notesUntitledNote,
  );
  final markdown = buildThreadMarkdown(
    root,
    untitledFallback: l10n.notesUntitledNote,
    tocTitle: l10n.notesThreadTitle,
  );
  await PdfExportHelper.exportMarkdown(
    context: context,
    markdown: markdown,
    suggestedName: 'note-thread-${root.shortId}.pdf',
    title: title,
  );
}
