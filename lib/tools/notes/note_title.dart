/// First heading or first non-empty line of a note's markdown.
String noteTitle(String content, {required String fallback}) {
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('#')) {
      final stripped = trimmed.replaceAll(RegExp(r'^#+\s*'), '').trim();
      if (stripped.isNotEmpty) return stripped;
      continue;
    }
    return trimmed;
  }
  return fallback;
}
