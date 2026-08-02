import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/archives/archive_handler.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class FileManagerArchiveConflictDialog extends StatefulWidget {
  final List<String> conflictPaths;
  final bool initialApplyToAll;

  const FileManagerArchiveConflictDialog({
    super.key,
    required this.conflictPaths,
    this.initialApplyToAll = true,
  });

  @override
  State<FileManagerArchiveConflictDialog> createState() =>
      _FileManagerArchiveConflictDialogState();
}

class _FileManagerArchiveConflictDialogState
    extends State<FileManagerArchiveConflictDialog> {
  late bool _applyToAll = widget.initialApplyToAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      title: Text(l10n.fileManagerArchiveConflictTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.fileManagerArchiveConflictMessage(widget.conflictPaths.length),
          ),
          const SizedBox(height: 8),
          ...widget.conflictPaths.take(3).map((path) => Text(p.basename(path))),
          if (widget.conflictPaths.length > 3)
            Text(
              l10n.fileManagerArchiveConflictMore(
                widget.conflictPaths.length - 3,
              ),
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.fileManagerApplyToAll),
            value: _applyToAll,
            onChanged: (value) => setState(() => _applyToAll = value ?? false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, (
            _applyToAll,
            ArchiveConflictResolution.skip,
          )),
          child: Text(l10n.fileManagerSkip),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, (
            _applyToAll,
            ArchiveConflictResolution.keepBoth,
          )),
          child: Text(l10n.fileManagerKeepBoth),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            _applyToAll,
            ArchiveConflictResolution.overwrite,
          )),
          child: Text(l10n.fileManagerOverwrite),
        ),
      ],
    );
  }
}
