import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_state.dart';

class FileManagerBreadcrumbs extends StatelessWidget {
  final FileManagerState state;
  final ValueChanged<String> onOpenPath;

  const FileManagerBreadcrumbs({
    super.key,
    required this.state,
    required this.onOpenPath,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final separator = state.path.contains('\\') ? '\\' : '/';
    var path = state.path;
    final root = state.sharedStoragePath;
    final usesSharedStorage =
        state.usesSharedStorage && (path == root || p.isWithin(root, path));
    if (usesSharedStorage) path = p.relative(path, from: root);
    final parts = path
        .split(RegExp(r'[\\/]'))
        .where((part) => part.isNotEmpty)
        .toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              parts.length + (usesSharedStorage ? 1 : 0),
              (index) {
                final isRoot = usesSharedStorage && index == 0;
                final partIndex = usesSharedStorage ? index - 1 : index;
                final target = isRoot
                    ? root
                    : usesSharedStorage
                    ? p.joinAll([root, ...parts.take(partIndex + 1)])
                    : separator == '\\'
                    ? '${parts.take(partIndex + 1).join('\\')}\\'
                    : '/${parts.take(partIndex + 1).join('/')}';
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index > 0) const Icon(Icons.chevron_right, size: 16),
                    TextButton(
                      onPressed: () => onOpenPath(target),
                      child: Text(
                        isRoot ? l10n.fileManagerStorage : parts[partIndex],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
