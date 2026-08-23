import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_installed_apps.dart';

class FileManagerAppsView extends StatelessWidget {
  final List<FileManagerAppInfo> apps;
  final FileManagerStorageInfo? storageInfo;

  const FileManagerAppsView({
    super.key,
    required this.apps,
    required this.storageInfo,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (apps.isEmpty) {
      return Center(child: Text(l10n.fileManagerNoApps));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: apps.length + 1,
      itemBuilder: (context, index) => index == 0
          ? _StorageHeader(storageInfo: storageInfo, appCount: apps.length)
          : _AppTile(app: apps[index - 1]),
    );
  }
}

class _StorageHeader extends StatelessWidget {
  final FileManagerStorageInfo? storageInfo;
  final int appCount;

  const _StorageHeader({required this.storageInfo, required this.appCount});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final info = storageInfo;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apps_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.fileManagerAppCount(appCount),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          if (info != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: info.usedFraction),
            ),
            const SizedBox(height: 6),
            Text(
              '${l10n.fileManagerStorageUsed(FormatHelper.fileSize(info.totalBytes - info.freeBytes), FormatHelper.fileSize(info.totalBytes))}  -  ${l10n.fileManagerStorageFree(FormatHelper.fileSize(info.freeBytes))}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final FileManagerAppInfo app;

  const _AppTile({required this.app});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: app.icon == null
              ? const Icon(Icons.android_outlined)
              : Image.memory(app.icon!, width: 36, height: 36),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (app.isSystem)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.fileManagerCategorySystem,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
      subtitle: Text(
        app.sizeBytes > 0
            ? '${app.packageName}  -  ${FormatHelper.fileSize(app.sizeBytes)}'
            : app.packageName,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: l10n.fileManagerOpenAppInfo,
        icon: const Icon(Icons.info_outline),
        onPressed: () =>
            FileManagerInstalledApps.openAppSettings(app.packageName),
      ),
    );
  }
}
