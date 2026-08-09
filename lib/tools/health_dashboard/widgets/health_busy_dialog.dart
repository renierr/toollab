import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

/// Shown when an action is triggered while a Health Connect import or backend
/// sync still holds the tool. Those actions return early on their own, which
/// otherwise looks like the button did nothing.
class HealthBusyDialog {
  HealthBusyDialog._();

  static Future<void> show(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (context) => ResponsiveAlertDialog(
        title: Text(l10n.healthDashboardSyncInProgress),
        content: Text(l10n.healthDashboardSyncInProgressBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }
}
