import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../health_dashboard_state.dart';

class HealthExportProgressDialog extends StatelessWidget {
  const HealthExportProgressDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const HealthExportProgressDialog(),
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HealthDashboardState>();
    final l10n = AppLocalizations.of(context);
    if (!state.isExportingBackup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
    final status = switch (state.backupExportPhase) {
      HealthExportPhase.measuring =>
        l10n.healthDashboardExportBackupProgressStatus,
      HealthExportPhase.writing =>
        l10n.healthDashboardExportBackupStatusWriting,
      HealthExportPhase.saving => l10n.healthDashboardExportBackupStatusSaving,
    };
    return PopScope(
      canPop: false,
      child: ResponsiveAlertDialog(
        title: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(l10n.healthDashboardExportBackupProgressTitle),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status),
            const SizedBox(height: 14),
            if (state.backupExportPhase != HealthExportPhase.saving)
              Text(
                l10n.healthDashboardExportBackupProgressCount(
                  state.backupExportProcessedCount,
                  state.backupExportTotalCount,
                ),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            const SizedBox(height: 12),
            Text(
              l10n.healthDashboardExportBackupProgressHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
