import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../p2p/p2p_models.dart';

/// List of nearby peers discovered while advertising the Fast Drop BLE
/// service, tap to send the pending file to that device.
class FastDropPeerList extends StatelessWidget {
  final List<P2pPeer> peers;
  final bool isScanning;
  final ValueChanged<P2pPeer> onSelect;

  const FastDropPeerList({
    super.key,
    required this.peers,
    required this.isScanning,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (peers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            if (isScanning)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Text(
              isScanning
                  ? l10n.fastDropP2pScanningForPeers
                  : l10n.fastDropP2pNoPeersFound,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: peers.length,
      itemBuilder: (context, index) {
        final peer = peers[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const Icon(
              Icons.smartphone_outlined,
              color: AppTheme.accentTeal,
            ),
            title: Text(peer.name),
            subtitle: Text(l10n.fastDropP2pSignalStrength(peer.rssi)),
            trailing: FilledButton.tonal(
              onPressed: () => onSelect(peer),
              child: Text(l10n.fastDropP2pSend),
            ),
          ),
        );
      },
    );
  }
}
