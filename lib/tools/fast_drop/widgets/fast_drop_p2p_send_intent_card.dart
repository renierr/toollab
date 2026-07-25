import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

/// Shown once the user has picked a file to send but no peer has been
/// selected yet: file details, an estimated transfer time for both the
/// fast (LAN) and fallback (BLE) paths, a "waiting for a nearby device"
/// indicator, and an abort action.
class FastDropP2pSendIntentCard extends StatelessWidget {
  final String fileName;
  final int fileSize;
  final bool hasPeers;
  final VoidCallback onAbort;

  const FastDropP2pSendIntentCard({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.hasPeers,
    required this.onAbort,
  });

  // Conservative real-world throughput assumptions used only to give the
  // user a rough expectation, not a precise measurement.
  static const int _lanBytesPerSecond = 8 * 1024 * 1024; // ~8 MB/s Wi-Fi
  static const int _bleBytesPerSecond = 15 * 1024; // ~15 KB/s BLE GATT

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String _formatDuration(double seconds) {
    if (seconds < 1) return '<1s';
    if (seconds < 60) return '~${seconds.round()}s';
    if (seconds < 3600) {
      final minutes = (seconds / 60).round();
      return '~${minutes}m';
    }
    final hours = (seconds / 3600).round();
    return '~${hours}h';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lanEstimate = _formatDuration(fileSize / _lanBytesPerSecond);
    final bleEstimate = _formatDuration(fileSize / _bleBytesPerSecond);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.insert_drive_file_outlined,
                  color: AppTheme.accentTeal,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatBytes(fileSize),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.fastDropP2pAbortSend,
                  onPressed: onAbort,
                  style: IconButton.styleFrom(
                    foregroundColor: AppTheme.statusRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _EstimateChip(
                  icon: Icons.wifi,
                  label: l10n.fastDropP2pEstimateWifi(lanEstimate),
                ),
                _EstimateChip(
                  icon: Icons.bluetooth,
                  label: l10n.fastDropP2pEstimateBluetooth(bleEstimate),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    hasPeers
                        ? l10n.fastDropP2pPeersFoundPickOne
                        : l10n.fastDropP2pWaitingForReceiver,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimateChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EstimateChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
