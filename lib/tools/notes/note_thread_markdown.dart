import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/helpers/markdown_to_pdf_helper.dart';
import 'package:tool_lab/tools/notes/note_thread.dart';
import 'package:tool_lab/tools/notes/note_title.dart';

/// Flattens a whole thread into one markdown document: a table of contents
/// first, then every note on its own page with headings shifted by depth.
String buildThreadMarkdown(
  NoteThreadNode root, {
  required String untitledFallback,
  required String tocTitle,
}) {
  final nodes = root.flatten();
  final buffer = StringBuffer();

  buffer.writeln('# $tocTitle');
  buffer.writeln();
  for (final node in nodes) {
    final indent = '  ' * node.depth;
    final title = noteTitle(node.note.content, fallback: untitledFallback);
    final date = FormatHelper.epoch(
      node.note.createdAt,
      style: DateStyle.dateOnly,
    );
    buffer.writeln('$indent- $title — $date');
  }

  for (final node in nodes) {
    buffer.writeln();
    buffer.writeln(MarkdownToPdfConverter.pageBreakMarker);
    buffer.writeln();
    buffer.write(_sectionFor(node, untitledFallback: untitledFallback));
    buffer.writeln();
  }

  return buffer.toString();
}

String _sectionFor(NoteThreadNode node, {required String untitledFallback}) {
  final content = node.note.content.trim();
  final shifted = _shiftHeadings(content, node.depth);
  final hasHeading = RegExp(r'^#{1,6}\s', multiLine: true).hasMatch(shifted);
  final title = noteTitle(content, fallback: untitledFallback);
  final header = '${'#' * (node.depth + 1).clamp(1, 6)} $title';
  return hasHeading ? shifted : '$header\n\n$shifted';
}

/// Pushes every heading down [depth] levels so a follow-up never competes
/// with its parent's title. Fenced code blocks are left untouched.
String _shiftHeadings(String markdown, int depth) {
  if (depth <= 0) return markdown;
  var inFence = false;
  return markdown
      .split('\n')
      .map((line) {
        if (line.trimLeft().startsWith('```')) {
          inFence = !inFence;
          return line;
        }
        if (inFence) return line;
        final match = RegExp(r'^(#{1,6})(\s)').firstMatch(line);
        if (match == null) return line;
        final level = (match.group(1)!.length + depth).clamp(1, 6);
        return '${'#' * level}${match.group(2)}${line.substring(match.end)}';
      })
      .join('\n');
}
