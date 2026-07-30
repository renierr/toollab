/// Single source of truth for the TextMate grammars shipped in
/// `assets/grammars/` and the aliases that resolve to them.
class LanguageRegistry {
  LanguageRegistry._();

  /// Grammar names available as `assets/grammars/<name>.json`.
  static const List<String> supportedLanguages = [
    'dart',
    'javascript',
    'typescript',
    'python',
    'json',
    'yaml',
    'sql',
    'html',
    'css',
    'rust',
    'go',
    'java',
    'kotlin',
    'bash',
    'markdown',
  ];

  /// Resolves a markdown fence info string (or any language alias) to a
  /// supported grammar name. Returns `null` when nothing matches.
  static String? resolveAlias(String? info) {
    if (info == null) return null;
    final normalized = info.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (supportedLanguages.contains(normalized)) return normalized;
    return switch (normalized) {
      'js' || 'mjs' || 'cjs' || 'jsx' || 'node' => 'javascript',
      'ts' || 'mts' || 'cts' || 'tsx' => 'typescript',
      'py' || 'pyw' || 'python3' => 'python',
      'sh' || 'shell' || 'zsh' || 'console' => 'bash',
      'yml' => 'yaml',
      'kt' || 'kts' => 'kotlin',
      'rs' => 'rust',
      'htm' || 'xhtml' => 'html',
      'md' || 'mdown' => 'markdown',
      'golang' => 'go',
      'jsonc' || 'json5' => 'json',
      'postgres' || 'postgresql' || 'mysql' || 'sqlite' => 'sql',
      _ => null,
    };
  }

  /// Resolves a file name or bare extension to a grammar name,
  /// falling back to `'plain'`.
  static String fromFileName(String fileNameOrExtension) {
    final parts = fileNameOrExtension.split('.');
    if (parts.length < 2) return 'plain';
    return resolveAlias(parts.last) ?? 'plain';
  }
}
