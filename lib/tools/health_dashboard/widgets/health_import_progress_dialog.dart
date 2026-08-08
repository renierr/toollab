import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../health_dashboard_state.dart';

class HealthImportProgressDialog extends StatefulWidget {
  const HealthImportProgressDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const HealthImportProgressDialog(),
    );
  }

  @override
  State<HealthImportProgressDialog> createState() =>
      _HealthImportProgressDialogState();
}

class _HealthImportProgressDialogState
    extends State<HealthImportProgressDialog> {
  Timer? _safetyTimeoutTimer;
  Timer? _cancelButtonTimer;
  bool _showCancelButton = false;

  @override
  void initState() {
    super.initState();
    // Safety timeout: auto-close dialog if sync stalls for 3 minutes.
    _safetyTimeoutTimer = Timer(const Duration(minutes: 3), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });

    // Escape hatch: show emergency cancel button after 30 seconds.
    _cancelButtonTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          _showCancelButton = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _safetyTimeoutTimer?.cancel();
    _cancelButtonTimer?.cancel();
    super.dispose();
  }

  void _autoDismissIfCompleted(bool isCollecting) {
    if (!isCollecting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = context.watch<HealthDashboardState>();

    _autoDismissIfCompleted(state.isCollecting);

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
              child: Text(
                'Importing Health Data',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.collectionStatus ??
                  'Fetching records from Health Connect...',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sync, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Fetched ${state.collectedRecordCount} records so far',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please keep the screen open while Health Connect records are being imported.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            if (_showCancelButton) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    if (mounted) Navigator.of(context).pop();
                  },
                  child: Text(l10n.commonCancel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
