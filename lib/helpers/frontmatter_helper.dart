import 'package:yaml/yaml.dart';

/// Result of splitting a markdown document into YAML frontmatter + body.
class FrontmatterResult {
  /// Parsed top-level YAML keys in document order. Empty when absent/invalid.
  final Map<String, dynamic> fields;

  /// Raw YAML text between the delimiters (without the `---` lines).
  final String rawYaml;

  /// Markdown content after the closing delimiter.
  final String body;

  /// True when a delimited block was found, even if the YAML failed to parse.
  final bool hasFrontmatter;

  /// Set when a block was found but its YAML could not be parsed.
  final String? error;

  const FrontmatterResult({
    required this.fields,
    required this.rawYaml,
    required this.body,
    required this.hasFrontmatter,
    this.error,
  });

  bool get isValid => hasFrontmatter && error == null && fields.isNotEmpty;
}

/// Parser for the YAML frontmatter convention used by Jekyll, Hugo, Astro and
/// Obsidian. Not part of CommonMark/GFM, hence the strict positioning rules:
/// the opening `---` must be the very first line of the file, and a closing
/// `---` (or the YAML document terminator `...`) must follow.
class FrontmatterHelper {
  FrontmatterHelper._();

  static final RegExp _openDelimiter = RegExp(r'^---[ \t]*$');
  static final RegExp _closeDelimiter = RegExp(r'^(---|\.\.\.)[ \t]*$');

  static FrontmatterResult parse(String content) {
    // A BOM would otherwise shift the opening delimiter off column 0.
    final text = content.startsWith('﻿') ? content.substring(1) : content;
    final lines = text.split('\n');

    if (lines.isEmpty ||
        !_openDelimiter.hasMatch(lines.first.replaceAll('\r', ''))) {
      return FrontmatterResult(
        fields: const {},
        rawYaml: '',
        body: content,
        hasFrontmatter: false,
      );
    }

    int closeIdx = -1;
    for (int i = 1; i < lines.length; i++) {
      if (_closeDelimiter.hasMatch(lines[i].replaceAll('\r', ''))) {
        closeIdx = i;
        break;
      }
    }

    // No closing delimiter — the leading `---` is a plain horizontal rule.
    if (closeIdx == -1) {
      return FrontmatterResult(
        fields: const {},
        rawYaml: '',
        body: content,
        hasFrontmatter: false,
      );
    }

    final rawYaml = lines.sublist(1, closeIdx).join('\n');
    final body = lines.sublist(closeIdx + 1).join('\n');

    if (rawYaml.trim().isEmpty) {
      return FrontmatterResult(
        fields: const {},
        rawYaml: rawYaml,
        body: body,
        hasFrontmatter: true,
      );
    }

    try {
      final doc = loadYaml(rawYaml);
      if (doc is Map) {
        return FrontmatterResult(
          fields: _normalizeMap(doc),
          rawYaml: rawYaml,
          body: body,
          hasFrontmatter: true,
        );
      }
      return FrontmatterResult(
        fields: const {},
        rawYaml: rawYaml,
        body: body,
        hasFrontmatter: true,
        error: 'Frontmatter is not a key/value mapping',
      );
    } catch (e) {
      return FrontmatterResult(
        fields: const {},
        rawYaml: rawYaml,
        body: body,
        hasFrontmatter: true,
        error: e.toString().split('\n').first,
      );
    }
  }

  /// Strips a valid frontmatter block, leaving the markdown body untouched.
  static String stripFrontmatter(String content) => parse(content).body;

  static Map<String, dynamic> _normalizeMap(Map source) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      result[entry.key.toString()] = _normalizeValue(entry.value);
    }
    return result;
  }

  static dynamic _normalizeValue(dynamic value) {
    if (value is Map) return _normalizeMap(value);
    if (value is Iterable) return value.map(_normalizeValue).toList();
    return value;
  }

  /// Flattens a value into a single display string. Nested maps become
  /// `key: value` pairs, lists are comma separated.
  static String formatValue(dynamic value) {
    if (value == null) return '';
    if (value is List) return value.map(formatValue).join(', ');
    if (value is Map) {
      return value.entries
          .map((e) => '${e.key}: ${formatValue(e.value)}')
          .join(', ');
    }
    if (value is DateTime) {
      final date = value.toIso8601String();
      return value.hour == 0 && value.minute == 0 && value.second == 0
          ? date.split('T').first
          : date;
    }
    return value.toString();
  }
}
