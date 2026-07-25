import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

/// Warns the user that the transfer fell back to slow BLE data transfer
/// because no shared network could be found between the two devices.
class FastDropP2pSpeedBanner extends StatelessWidget {
  const FastDropP2pSpeedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.statusAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.statusAmber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bluetooth, color: AppTheme.statusAmber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.fastDropP2pBleFallbackWarning,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
