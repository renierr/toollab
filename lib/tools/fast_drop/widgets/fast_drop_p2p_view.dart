import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';

import '../config.dart';
import '../fast_drop_p2p_state.dart';
import '../p2p/p2p_models.dart';
import 'fast_drop_p2p_received_list.dart';
import 'fast_drop_p2p_send_intent_card.dart';
import 'fast_drop_p2p_speed_banner.dart';
import 'fast_drop_peer_list.dart';
import 'fast_drop_progress_indicator.dart';

/// Composes the Nearby (BLE discovery/handshake + LAN-or-BLE transfer) tab
/// of Fast Drop: pick-a-file-to-send / start-receiving toggle, peer list,
/// live transfer progress and the list of files received so far.
class FastDropP2pView extends StatelessWidget {
  final FastDropP2pState p2pState;
  final ValueChanged<List<XFile>> onFilesPickedToSend;
  final VoidCallback onPasteClipboardToSend;
  final ValueChanged<P2pPeer> onSelectPeer;
  final VoidCallback onCancelSendSelection;
  final VoidCallback onToggleReceiving;
  final ValueChanged<P2pReceivedFile> onOpenReceived;
  final ValueChanged<P2pReceivedFile> onSaveReceived;
  final ValueChanged<P2pReceivedFile>? onDismissReceived;
  final VoidCallback onCancelTransfer;
  final TempFileScope tempScope;

  const FastDropP2pView({
    super.key,
    required this.p2pState,
    required this.tempScope,
    required this.onFilesPickedToSend,
    required this.onPasteClipboardToSend,
    required this.onSelectPeer,
    required this.onCancelSendSelection,
    required this.onToggleReceiving,
    required this.onOpenReceived,
    required this.onSaveReceived,
    this.onDismissReceived,
    required this.onCancelTransfer,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isReceiving = p2pState.role == P2pRole.receiving;
    final isSending = p2pState.role == P2pRole.sending;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p2pState.progress != null) ...[
            if (p2pState.activeTransport == P2pTransportKind.ble)
              const FastDropP2pSpeedBanner(),
            FastDropProgressIndicator(
              label: p2pState.activeTransport == P2pTransportKind.lan
                  ? l10n.fastDropP2pTransferringLan
                  : l10n.fastDropP2pTransferringBle,
              sent: p2pState.progress!.$1,
              total: p2pState.progress!.$2,
              onCancel: onCancelTransfer,
            ),
            const SizedBox(height: 8),
          ],
          if (p2pState.errorCode != null || p2pState.error != null) ...[
            Text(
              switch (p2pState.errorCode) {
                P2pErrorCode.bleConnectFailed =>
                  l10n.fastDropP2pErrorBleConnect,
                P2pErrorCode.peerDeclined => l10n.fastDropP2pErrorDeclined,
                P2pErrorCode.transferStalled => l10n.fastDropP2pErrorStalled,
                null => p2pState.error!,
              },
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.statusRed,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: p2pState.isTransferActive
                      ? null
                      : onToggleReceiving,
                  icon: Icon(
                    isReceiving
                        ? Icons.bluetooth_disabled
                        : Icons.bluetooth_audio,
                  ),
                  label: Text(
                    isReceiving
                        ? l10n.fastDropP2pStopReceiving
                        : l10n.fastDropP2pStartReceiving,
                  ),
                ),
              ),
            ],
          ),
          if (isReceiving && p2pState.progress == null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.fastDropP2pWaitingForSender,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          if (!isReceiving) ...[
            Text(
              l10n.fastDropP2pSendSectionTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            if (!p2pState.hasPendingSendFile) ...[
              FileDropZone(
                onFileSelected: (file) => onFilesPickedToSend([file]),
                onFilesSelected: onFilesPickedToSend,
                allowedExtensions: FastDropTool.config.fileExtensions,
                typeLabel: l10n.fastDropAllFiles,
                accentColor: FastDropTool.config.accentColor,
                icon: Icons.send_outlined,
                title: l10n.fastDropP2pPickFileToSend,
                subtitle: l10n.fastDropOrClickToBrowse,
                compact: true,
                multiple: false,
                useAndroidStreamingPicker: true,
                tempScope: tempScope,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: onPasteClipboardToSend,
                    icon: const Icon(Icons.paste_outlined),
                    label: Text(l10n.fastDropPasteClipboard),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentTeal,
                      side: const BorderSide(color: AppTheme.accentTeal),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              FastDropP2pSendIntentCard(
                fileName: p2pState.pendingSendFileName ?? '',
                fileSize: p2pState.pendingSendFileSize ?? 0,
                hasPeers: p2pState.peers.isNotEmpty,
                onAbort: onCancelSendSelection,
              ),
            if (p2pState.hasPendingSendFile && p2pState.peers.isNotEmpty) ...[
              const SizedBox(height: 12),
              FastDropPeerList(
                peers: p2pState.peers,
                isScanning: isSending,
                onSelect: onSelectPeer,
              ),
            ],
          ],
          if (p2pState.receivedFiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l10n.fastDropP2pReceivedSectionTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            FastDropP2pReceivedList(
              files: p2pState.receivedFiles,
              onOpen: onOpenReceived,
              onSave: onSaveReceived,
              onDismiss: onDismissReceived,
            ),
          ],
        ],
      ),
    );
  }
}
