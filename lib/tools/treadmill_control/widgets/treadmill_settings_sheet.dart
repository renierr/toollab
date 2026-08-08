import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../treadmill_control_state.dart';

class TreadmillSettingsSheet extends StatelessWidget {
  const TreadmillSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TreadmillControlState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.healthDashboardSettings,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (Platform.isAndroid)
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.health_and_safety_outlined),
              title: Text(l10n.treadmillSyncToHealthConnect),
              subtitle: Text(l10n.treadmillSyncToHealthConnectSubtitle),
              value: state.syncToHealthConnect,
              onChanged: state.setSyncToHealthConnect,
            ),
        ],
      ),
    );
  }
}
