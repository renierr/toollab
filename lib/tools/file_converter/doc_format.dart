import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Document formats supported by the file converter.
enum DocFormat {
  docx,
  pdf,
  html,
  md,
  txt;

  /// File extensions mapped to this format. The first entry is the canonical
  /// extension used when naming converted output.
  List<String> get extensions {
    switch (this) {
      case DocFormat.docx:
        return const ['docx'];
      case DocFormat.pdf:
        return const ['pdf'];
      case DocFormat.html:
        return const ['html', 'htm'];
      case DocFormat.md:
        return const ['md', 'markdown'];
      case DocFormat.txt:
        return const ['txt'];
    }
  }

  String get canonicalExtension => extensions.first;

  IconData get icon {
    switch (this) {
      case DocFormat.docx:
        return Icons.description_outlined;
      case DocFormat.pdf:
        return Icons.picture_as_pdf_outlined;
      case DocFormat.html:
        return Icons.code_outlined;
      case DocFormat.md:
        return Icons.notes_outlined;
      case DocFormat.txt:
        return Icons.text_snippet_outlined;
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case DocFormat.docx:
        return l10n.fileConverterFormatDocx;
      case DocFormat.pdf:
        return l10n.fileConverterFormatPdf;
      case DocFormat.html:
        return l10n.fileConverterFormatHtml;
      case DocFormat.md:
        return l10n.fileConverterFormatMd;
      case DocFormat.txt:
        return l10n.fileConverterFormatTxt;
    }
  }

  /// All file extensions across every format, for the file picker filter.
  static List<String> get allExtensions =>
      DocFormat.values.expand((f) => f.extensions).toList();

  /// Resolves a format from a file name or path by extension.
  static DocFormat? fromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return null;
    final ext = path.substring(dot + 1).toLowerCase();
    for (final format in DocFormat.values) {
      if (format.extensions.contains(ext)) return format;
    }
    return null;
  }
}
