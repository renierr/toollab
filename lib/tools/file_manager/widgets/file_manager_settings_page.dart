import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/tools/file_manager/file_manager_state.dart';

class FileManagerSettingsPage extends StatelessWidget {
  const FileManagerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<FileManagerState>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fileManagerSettings)),
      body: SafeArea(
        child: ListView(
          children: [
            _SettingsSection(title: l10n.fileManagerStartupFolder),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(l10n.fileManagerAppFiles),
              subtitle: Text(state.appFilesPath),
              trailing: _StartupFolderIndicator(
                selected: state.startupPath == null,
              ),
              onTap: () => state.updateStartupPath(null),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(l10n.fileManagerDownloads),
              subtitle: Text(state.downloadsPath),
              trailing: _StartupFolderIndicator(
                selected: state.startupPath == state.downloadsPath,
              ),
              onTap: () => state.updateStartupPath(state.downloadsPath),
            ),
            if (!state.isRemote)
              ListTile(
                leading: const Icon(Icons.my_location_outlined),
                title: Text(l10n.fileManagerCurrentFolder),
                subtitle: Text(state.path),
                trailing: _StartupFolderIndicator(
                  selected: state.startupPath == state.path,
                ),
                onTap: () => state.updateStartupPath(state.path),
              ),
            const Divider(height: 1),
            _SettingsSection(title: l10n.fileManagerSorting),
            ListTile(
              title: Text(l10n.fileManagerSortBy),
              trailing: DropdownButton<FileManagerSortField>(
                value: state.sortField,
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
                onChanged: (field) {
                  if (field != null) {
                    state.updateSort(field, state.sortAscending);
                  }
                },
              ),
            ),
            SwitchListTile.adaptive(
              title: Text(l10n.fileManagerSortAscending),
              value: state.sortAscending,
              onChanged: (ascending) =>
                  state.updateSort(state.sortField, ascending),
            ),
            const Divider(height: 1),
            _SettingsSection(title: l10n.fileManagerOpenWith),
            ...FileManagerOpenCategory.values.map(
              (category) => ListTile(
                title: Text(_categoryLabel(l10n, category)),
                trailing: DropdownButton<String?>(
                  value: state.openToolId(category),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.fileManagerOpenChooser),
                    ),
                    ...SharingService.instance
                        .getMatchingTools(_exampleFile(category))
                        .map(
                          (tool) => DropdownMenuItem(
                            value: tool.id,
                            child: Text(tool.localizedName(l10n)),
                          ),
                        ),
                  ],
                  onChanged: (toolId) => state.updateOpenTool(category, toolId),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SharedFile _exampleFile(FileManagerOpenCategory category) => SharedFile(
    path: '',
    name: switch (category) {
      FileManagerOpenCategory.images => 'image.png',
      FileManagerOpenCategory.pdf => 'document.pdf',
      FileManagerOpenCategory.audio => 'audio.mp3',
      FileManagerOpenCategory.markdown => 'document.md',
    },
    mimeType: switch (category) {
      FileManagerOpenCategory.images => 'image/png',
      FileManagerOpenCategory.pdf => 'application/pdf',
      FileManagerOpenCategory.audio => 'audio/mpeg',
      FileManagerOpenCategory.markdown => 'text/markdown',
    },
  );

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

class _SettingsSection extends StatelessWidget {
  final String title;

  const _SettingsSection({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _StartupFolderIndicator extends StatelessWidget {
  final bool selected;

  const _StartupFolderIndicator({required this.selected});

  @override
  Widget build(BuildContext context) =>
      Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off);
}
