import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/markdown_to_pdf_helper.dart';

class PdfExportHelper {
  static Future<void> exportMarkdown({
    required BuildContext context,
    required String markdown,
    required String suggestedName,
    String? title,
  }) async {
    try {
      title ??= _extractTitle(markdown);
      final bytes = await MarkdownToPdfConverter.convert(
        markdown: markdown,
        title: title.isNotEmpty ? title : null,
      );
      if (!context.mounted) return;
      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: suggestedName,
        bytes: bytes,
      );
    } catch (e) {
      if (context.mounted) {
        FileSaveHelper.showErrorNotification(
          context: context,
          errorMessage: 'Failed to generate PDF: $e',
        );
      }
    }
  }

  static String _extractTitle(String markdown) {
    final lines = markdown.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('# ')) {
        return trimmed.substring(2).trim();
      }
    }
    return '';
  }
}
