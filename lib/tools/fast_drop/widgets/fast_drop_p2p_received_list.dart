import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../p2p/p2p_models.dart';

/// Files received via the Nearby (BLE/LAN) transfer, with save/open
/// actions delegated to the page.
class FastDropP2pReceivedList extends StatelessWidget {
  final List<P2pReceivedFile> files;
  final void Function(P2pReceivedFile file) onOpen;
  final void Function(P2pReceivedFile file) onSave;
  final void Function(P2pReceivedFile file)? onDismiss;

  const FastDropP2pReceivedList({
    super.key,
    required this.files,
    required this.onOpen,
    required this.onSave,
    this.onDismiss,
  });

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (files.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const Icon(
              Icons.check_circle_outline,
              color: AppTheme.statusGreen,
            ),
            title: Text(file.filename),
            subtitle: Text(_formatBytes(file.size)),
            trailing: Wrap(
              spacing: 4,
              children: [
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.fastDropP2pDismissFile,
                    onPressed: () => onDismiss!(file),
                  ),
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  tooltip: l10n.fastDropOpenFile,
                  onPressed: () => onOpen(file),
                ),
                IconButton(
                  icon: const Icon(Icons.save_alt),
                  tooltip: l10n.fastDropDownloadFile,
                  onPressed: () => onSave(file),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
