import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_connection.dart';
import 'package:tool_lab/tools/file_manager/file_manager_state.dart';

class FileManagerLocations extends StatelessWidget {
  final FileManagerState state;
  final ValueChanged<String> onOpenLocal;
  final ValueChanged<String> onOpenPath;
  final ValueChanged<FileManagerConnection> onOpenConnection;
  final VoidCallback onAddConnection;
  final ValueChanged<FileManagerConnection> onRemoveConnection;
  final VoidCallback onRequestStorageAccess;

  const FileManagerLocations({
    super.key,
    required this.state,
    required this.onOpenLocal,
    required this.onOpenPath,
    required this.onOpenConnection,
    required this.onAddConnection,
    required this.onRemoveConnection,
    required this.onRequestStorageAccess,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width < 720;
    final recentPaths = [
      state.appFilesPath,
      state.downloadsPath,
      ...state.recentPaths.where(
        (path) => path != state.appFilesPath && path != state.downloadsPath,
      ),
    ];
    return Material(
      child: isNarrow
          ? SizedBox(
              height: 76,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                scrollDirection: Axis.horizontal,
                children: _narrowItems(context, l10n, recentPaths),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _wideItems(context, l10n, recentPaths),
            ),
    );
  }

  List<Widget> _wideItems(
    BuildContext context,
    AppLocalizations l10n,
    List<String> recentPaths,
  ) => [
    if (state.requiresStorageAccess)
      _LocationTile(
        icon: Icons.folder_open_outlined,
        label: l10n.fileManagerGrantFileAccess,
        onTap: onRequestStorageAccess,
      ),
    _LocationTile(
      icon: Icons.folder_outlined,
      label: l10n.fileManagerAppFiles,
      onTap: () => onOpenLocal(state.defaultFolderPath),
    ),
    if (recentPaths.isNotEmpty) ...[
      const Divider(),
      _RecentLocationsTile(
        label: l10n.fileManagerRecentLocations,
        paths: recentPaths,
        pathLabel: _favoriteLabel,
        onOpenPath: onOpenPath,
      ),
    ],
    ...state.favoritePaths.map(
      (path) => _LocationTile(
        icon: Icons.star_outline,
        label: _favoriteLabel(path),
        onTap: () => onOpenLocal(path),
      ),
    ),
    const Divider(),
    ListTile(
      dense: true,
      leading: const Icon(Icons.dns_outlined),
      title: Text(l10n.fileManagerConnections),
      trailing: IconButton(
        tooltip: l10n.commonAdd,
        onPressed: onAddConnection,
        icon: const Icon(Icons.add),
      ),
    ),
    ...state.connections.map(
      (profile) => _ConnectionTile(
        profile: profile,
        onOpen: onOpenConnection,
        onRemove: onRemoveConnection,
      ),
    ),
  ];

  List<Widget> _narrowItems(
    BuildContext context,
    AppLocalizations l10n,
    List<String> recentPaths,
  ) => [
    if (state.requiresStorageAccess)
      _LocationChip(
        icon: Icons.folder_open_outlined,
        label: l10n.fileManagerGrantFileAccess,
        onTap: onRequestStorageAccess,
      ),
    _LocationChip(
      icon: Icons.folder_outlined,
      label: l10n.fileManagerAppFiles,
      onTap: () => onOpenLocal(state.defaultFolderPath),
    ),
    if (recentPaths.isNotEmpty)
      _RecentLocationsChip(
        label: l10n.fileManagerRecentLocations,
        paths: recentPaths,
        pathLabel: _favoriteLabel,
        onOpenPath: onOpenPath,
      ),
    ...state.favoritePaths.map(
      (path) => _LocationChip(
        icon: Icons.star_outline,
        label: _favoriteLabel(path),
        onTap: () => onOpenLocal(path),
      ),
    ),
    _LocationChip(
      icon: Icons.add_link_outlined,
      label: l10n.fileManagerAddConnection,
      onTap: onAddConnection,
    ),
    ...state.connections.map(
      (profile) => _LocationChip(
        icon: profile.protocol == FileManagerProtocol.ftp
            ? Icons.cloud_outlined
            : Icons.folder_shared_outlined,
        label: profile.label,
        onTap: () => onOpenConnection(profile),
      ),
    ),
  ];

  String _favoriteLabel(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = p.basename(normalized);
    const commonFolders = {
      'downloads',
      'documents',
      'images',
      'pictures',
      'music',
      'videos',
      'movies',
      'dcim',
    };
    if (commonFolders.contains(name.toLowerCase())) return name;
    final parent = p.basename(p.dirname(normalized));
    return parent.isEmpty || parent == '.' ? name : '$parent/$name';
  }
}

class _LocationChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LocationChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
    child: ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    ),
  );
}

class _RecentLocationsChip extends StatelessWidget {
  final String label;
  final List<String> paths;
  final String Function(String) pathLabel;
  final ValueChanged<String> onOpenPath;

  const _RecentLocationsChip({
    required this.label,
    required this.paths,
    required this.pathLabel,
    required this.onOpenPath,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
    child: PopupMenuButton<String>(
      onSelected: onOpenPath,
      itemBuilder: (context) => paths
          .map(
            (path) => PopupMenuItem(value: path, child: Text(pathLabel(path))),
          )
          .toList(),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          showMenu<String>(
            context: context,
            position: const RelativeRect.fromLTRB(16, 80, 16, 0),
            items: paths
                .map(
                  (path) =>
                      PopupMenuItem(value: path, child: Text(pathLabel(path))),
                )
                .toList(),
          ).then((path) {
            if (path != null) onOpenPath(path);
          });
        },
        child: Chip(
          avatar: const Icon(Icons.history_outlined, size: 18),
          label: Text(label),
        ),
      ),
    ),
  );
}

class _LocationTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LocationTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(icon),
    title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    onTap: onTap,
  );
}

class _RecentLocationsTile extends StatelessWidget {
  final String label;
  final List<String> paths;
  final String Function(String) pathLabel;
  final ValueChanged<String> onOpenPath;

  const _RecentLocationsTile({
    required this.label,
    required this.paths,
    required this.pathLabel,
    required this.onOpenPath,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: const Icon(Icons.history_outlined),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {
      showMenu<String>(
        context: context,
        position: const RelativeRect.fromLTRB(16, 80, 16, 0),
        items: paths
            .map(
              (path) =>
                  PopupMenuItem(value: path, child: Text(pathLabel(path))),
            )
            .toList(),
      ).then((path) {
        if (path != null) onOpenPath(path);
      });
    },
  );
}

class _ConnectionTile extends StatelessWidget {
  final FileManagerConnection profile;
  final ValueChanged<FileManagerConnection> onOpen;
  final ValueChanged<FileManagerConnection> onRemove;
  const _ConnectionTile({
    required this.profile,
    required this.onOpen,
    required this.onRemove,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(
      profile.protocol == FileManagerProtocol.ftp
          ? Icons.cloud_outlined
          : Icons.folder_shared_outlined,
    ),
    title: Text(profile.label),
    subtitle: Text(profile.host, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: IconButton(
      onPressed: () => onRemove(profile),
      icon: const Icon(Icons.delete_outline),
    ),
    onTap: () => onOpen(profile),
  );
}
