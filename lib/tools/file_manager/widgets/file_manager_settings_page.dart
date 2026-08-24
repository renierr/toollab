import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/helpers/native_media_player.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/tools/file_manager/file_manager_connection.dart';
import 'package:tool_lab/tools/file_manager/file_manager_state.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_connection_dialog.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

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
              title: Text(l10n.fileManagerDocuments),
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
            SwitchListTile.adaptive(
              title: Text(l10n.fileManagerFoldersFirst),
              value: state.foldersFirst,
              onChanged: state.updateFoldersFirst,
            ),
            const Divider(height: 1),
            _SettingsSection(title: l10n.fileManagerImagePreviews),
            SwitchListTile.adaptive(
              title: Text(l10n.fileManagerCropPreviews),
              subtitle: Text(l10n.fileManagerCropPreviewsHint),
              value: state.cropImagePreviews,
              onChanged: state.updateCropImagePreviews,
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
                    if (NativeMediaPlayer.isSupported &&
                        (category == FileManagerOpenCategory.audio ||
                            category == FileManagerOpenCategory.video))
                      DropdownMenuItem(
                        value: NativeMediaPlayer.preferenceId,
                        child: Text(l10n.fileManagerOpenInternalPlayer),
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
            const Divider(height: 1),
            _SettingsSection(title: l10n.fileManagerConnections),
            ListTile(
              leading: const Icon(Icons.add_link_outlined),
              title: Text(l10n.fileManagerAddConnection),
              onTap: () => _addConnection(context),
            ),
            ...state.connections.map(
              (profile) => ListTile(
                leading: Icon(
                  profile.protocol == FileManagerProtocol.ftp
                      ? Icons.cloud_outlined
                      : Icons.folder_shared_outlined,
                ),
                title: Text(profile.label),
                subtitle: Text(
                  profile.host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  onPressed: () => _removeConnection(context, profile),
                  icon: const Icon(Icons.delete_outline),
                ),
                onTap: () =>
                    context.read<FileManagerState>().openConnection(profile),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addConnection(BuildContext context) async {
    final state = context.read<FileManagerState>();
    final result = await showDialog<(FileManagerConnection, String)>(
      context: context,
      builder: (_) => FileManagerConnectionDialog(
        onDiscoverSmbShares: state.discoverSmbShares,
      ),
    );
    if (result != null && context.mounted) {
      await context.read<FileManagerState>().saveConnection(
        result.$1,
        result.$2,
      );
    }
  }

  Future<void> _removeConnection(
    BuildContext context,
    FileManagerConnection profile,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ResponsiveAlertDialog(
        title: Text(l10n.fileManagerRemoveConnectionTitle),
        content: Text(l10n.fileManagerRemoveConnectionMessage(profile.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.commonRemove),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<FileManagerState>().removeConnection(profile);
    }
  }

  SharedFile _exampleFile(FileManagerOpenCategory category) => SharedFile(
    path: '',
    name: switch (category) {
      FileManagerOpenCategory.images => 'image.png',
      FileManagerOpenCategory.pdf => 'document.pdf',
      FileManagerOpenCategory.audio => 'audio.mp3',
      FileManagerOpenCategory.video => 'video.mp4',
      FileManagerOpenCategory.markdown => 'document.md',
      FileManagerOpenCategory.text => 'document.txt',
      FileManagerOpenCategory.sqlite => 'database.db',
    },
    mimeType: switch (category) {
      FileManagerOpenCategory.images => 'image/png',
      FileManagerOpenCategory.pdf => 'application/pdf',
      FileManagerOpenCategory.audio => 'audio/mpeg',
      FileManagerOpenCategory.video => 'video/mp4',
      FileManagerOpenCategory.markdown => 'text/markdown',
      FileManagerOpenCategory.text => 'text/plain',
      FileManagerOpenCategory.sqlite => 'application/vnd.sqlite3',
    },
  );

  String _categoryLabel(
    AppLocalizations l10n,
    FileManagerOpenCategory category,
  ) => switch (category) {
    FileManagerOpenCategory.images => l10n.fileManagerOpenImages,
    FileManagerOpenCategory.pdf => l10n.fileManagerOpenPdf,
    FileManagerOpenCategory.audio => l10n.fileManagerOpenAudio,
    FileManagerOpenCategory.video => l10n.fileManagerOpenVideo,
    FileManagerOpenCategory.markdown => l10n.fileManagerOpenMarkdown,
    FileManagerOpenCategory.text => l10n.fileManagerOpenText,
    FileManagerOpenCategory.sqlite => l10n.fileManagerOpenSqlite,
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
