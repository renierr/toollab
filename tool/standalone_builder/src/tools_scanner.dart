import 'dart:io';
import 'package:path/path.dart' as p;

class ToolInfo {
  final String id;
  final String folderName;
  final String className;
  final String displayName;

  /// MIME patterns the tool declares via `shareTarget.accept` in config.dart.
  /// Empty when the tool has no `shareTarget` (it is not a share/open target).
  final List<String> shareAcceptMimes;

  /// File extensions the tool declares via `fileExtensions` (literal list only;
  /// computed lists such as `DocFormat.allExtensions` cannot be resolved here).
  final List<String> fileExtensions;

  /// True when `androidProcessIsolated: true` — the tool runs in its own
  /// Android process (:isolated), so the standalone activity mirrors that.
  final bool androidProcessIsolated;

  ToolInfo({
    required this.id,
    required this.folderName,
    required this.className,
    required this.displayName,
    this.shareAcceptMimes = const [],
    this.fileExtensions = const [],
    this.androidProcessIsolated = false,
  });
}

class ToolsScanner {
  static Future<List<ToolInfo>> scan() async {
    final toolsDir = Directory('lib/tools');
    if (!await toolsDir.exists()) {
      return [];
    }

    final tools = <ToolInfo>[];
    await for (final entity in toolsDir.list()) {
      if (entity is Directory) {
        final configFile = File(p.join(entity.path, 'config.dart'));
        if (await configFile.exists()) {
          final folderName = p.basename(entity.path);
          final toolId = folderName.replaceAll('_', '-');
          final pascalName = folderName
              .split('_')
              .map(
                (part) => part.isEmpty
                    ? ''
                    : part[0].toUpperCase() + part.substring(1),
              )
              .join('');
          final className = '${pascalName}Tool';

          String displayName = pascalName;
          List<String> shareAcceptMimes = const [];
          List<String> fileExtensions = const [];
          bool androidProcessIsolated = false;
          try {
            final content = await configFile.readAsString();
            final match =
                RegExp(r"name:\s*'([^']*)'").firstMatch(content) ??
                RegExp(r'name:\s*"([^"]*)"').firstMatch(content);
            if (match != null && match.groupCount >= 1) {
              displayName = match.group(1)!;
            }
            shareAcceptMimes = _extractStringList(content, 'accept');
            fileExtensions = _extractStringList(content, 'fileExtensions');
            androidProcessIsolated = RegExp(
              r'androidProcessIsolated:\s*true',
            ).hasMatch(content);
          } catch (_) {}

          tools.add(
            ToolInfo(
              id: toolId,
              folderName: folderName,
              className: className,
              displayName: displayName,
              shareAcceptMimes: shareAcceptMimes,
              fileExtensions: fileExtensions,
              androidProcessIsolated: androidProcessIsolated,
            ),
          );
        }
      }
    }
    // Sort tools alphabetically by display name
    tools.sort((a, b) => a.displayName.compareTo(b.displayName));
    return tools;
  }

  /// Extracts the quoted string literals from a `<key>: [ ... ]` list in the
  /// config source. Returns an empty list for computed values (no bracket
  /// literal) or when the key is absent.
  static List<String> _extractStringList(String content, String key) {
    final listMatch = RegExp(
      '$key:\\s*(?:const\\s*)?\\[([^\\]]*)\\]',
      dotAll: true,
    ).firstMatch(content);
    if (listMatch == null) return const [];
    final body = listMatch.group(1)!;
    return RegExp(
      r"""['"]([^'"]+)['"]""",
    ).allMatches(body).map((m) => m.group(1)!).toList();
  }
}
