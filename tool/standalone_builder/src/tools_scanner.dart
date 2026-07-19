import 'dart:io';
import 'package:path/path.dart' as p;

class ToolInfo {
  final String id;
  final String folderName;
  final String className;
  final String displayName;

  ToolInfo({
    required this.id,
    required this.folderName,
    required this.className,
    required this.displayName,
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
              .map((part) => part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1))
              .join('');
          final className = '${pascalName}Tool';

          // Extract human-readable name from config.dart
          String displayName = pascalName;
          try {
            final content = await configFile.readAsString();
            final match = RegExp(r"name:\s*'([^']*)'").firstMatch(content) ??
                          RegExp(r'name:\s*"([^"]*)"').firstMatch(content);
            if (match != null && match.groupCount >= 1) {
              displayName = match.group(1)!;
            }
          } catch (_) {}

          tools.add(ToolInfo(
            id: toolId,
            folderName: folderName,
            className: className,
            displayName: displayName,
          ));
        }
      }
    }
    // Sort tools alphabetically by display name
    tools.sort((a, b) => a.displayName.compareTo(b.displayName));
    return tools;
  }
}
