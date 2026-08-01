import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/tools/file_manager/file_manager_state.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class FileManagerSettingsDialog extends StatefulWidget {
  final FileManagerSortField initialField;
  final bool initialAscending;
  final Map<FileManagerOpenCategory, String?> initialOpenToolIds;
  final List<ToolModel> Function(FileManagerOpenCategory) matchingTools;

  const FileManagerSettingsDialog({
    super.key,
    required this.initialField,
    required this.initialAscending,
    required this.initialOpenToolIds,
    required this.matchingTools,
  });

  @override
  State<FileManagerSettingsDialog> createState() =>
      _FileManagerSettingsDialogState();
}

class _FileManagerSettingsDialogState extends State<FileManagerSettingsDialog> {
  late FileManagerSortField _field = widget.initialField;
  late bool _ascending = widget.initialAscending;
  late final Map<FileManagerOpenCategory, String?> _openToolIds = Map.of(
    widget.initialOpenToolIds,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      title: Text(l10n.fileManagerSettings),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<FileManagerSortField>(
            initialValue: _field,
            decoration: InputDecoration(labelText: l10n.fileManagerSortBy),
            items: [
              DropdownMenuItem(
                value: FileManagerSortField.name,
                child: Text(l10n.fileManagerSortName),
              ),
              DropdownMenuItem(
                value: FileManagerSortField.modified,
                child: Text(l10n.fileManagerSortDate),
              ),
              DropdownMenuItem(
                value: FileManagerSortField.size,
                child: Text(l10n.fileManagerSortSize),
              ),
            ],
            onChanged: (field) => setState(() => _field = field!),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.fileManagerSortAscending),
            value: _ascending,
            onChanged: (value) => setState(() => _ascending = value),
          ),
          const Divider(),
          ...FileManagerOpenCategory.values.map(
            (category) => DropdownButtonFormField<String>(
              initialValue: _openToolIds[category],
              decoration: InputDecoration(
                labelText: _categoryLabel(l10n, category),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.fileManagerOpenChooser),
                ),
                ...widget
                    .matchingTools(category)
                    .map(
                      (tool) => DropdownMenuItem(
                        value: tool.id,
                        child: Text(tool.localizedName(l10n)),
                      ),
                    ),
              ],
              onChanged: (value) =>
                  setState(() => _openToolIds[category] = value),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, (_field, _ascending, _openToolIds)),
          child: Text(l10n.commonApply),
        ),
      ],
    );
  }

  String _categoryLabel(
    AppLocalizations l10n,
    FileManagerOpenCategory category,
  ) => switch (category) {
    FileManagerOpenCategory.images => l10n.fileManagerOpenImages,
    FileManagerOpenCategory.pdf => l10n.fileManagerOpenPdf,
    FileManagerOpenCategory.audio => l10n.fileManagerOpenAudio,
    FileManagerOpenCategory.markdown => l10n.fileManagerOpenMarkdown,
  };
}
