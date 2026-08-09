import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../health_dashboard_state.dart';

class HealthImportProgressDialog extends StatefulWidget {
  final HealthImportOperation operation;

  const HealthImportProgressDialog({super.key, required this.operation});

  static Future<void> show(
    BuildContext context, {
    required HealthImportOperation operation,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HealthImportProgressDialog(operation: operation),
    );
  }

  @override
  State<HealthImportProgressDialog> createState() =>
      _HealthImportProgressDialogState();
}

class _HealthImportProgressDialogState
    extends State<HealthImportProgressDialog> {
  Timer? _cancelButtonTimer;
  bool _showCancelButton = false;

  @override
  void initState() {
    super.initState();
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
    _cancelButtonTimer?.cancel();
    super.dispose();
  }

  void _autoDismissIfCompleted(bool isInProgress) {
    if (!isInProgress) {
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
    final isBackup = widget.operation == HealthImportOperation.backup;
    final isAnalysis = widget.operation == HealthImportOperation.analysis;
    final isComparison = widget.operation == HealthImportOperation.comparison;
    final isInProgress = isBackup
        ? state.isImportingBackup
        : state.isCollecting;
    final title = isComparison
        ? l10n.healthDashboardHealthConnectComparisonProgressTitle
        : isAnalysis
        ? l10n.healthDashboardHealthConnectAnalysisProgressTitle
        : isBackup
        ? l10n.healthDashboardImportBackupProgressTitle
        : l10n.healthDashboardImportHealthConnectProgressTitle;
    final status = isComparison
        ? state.collectionStatus ??
              l10n.healthDashboardHealthConnectComparisonProgressStatus
        : isAnalysis
        ? state.collectionStatus ??
              l10n.healthDashboardHealthConnectAnalysisProgressStatus
        : isBackup
        ? l10n.healthDashboardImportBackupProgressStatus(
            state.backupImportProcessedCount,
            state.backupImportTotalCount,
          )
        : state.collectionStatus ??
              l10n.healthDashboardImportHealthConnectProgressStatus;

    _autoDismissIfCompleted(isInProgress);

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
                title,
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
            Text(status, style: theme.textTheme.bodyMedium),
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
                    isComparison
                        ? l10n.healthDashboardHealthConnectComparisonProgressCount(
                            state.collectedRecordCount,
                          )
                        : isAnalysis
                        ? l10n.healthDashboardHealthConnectAnalysisProgressCount(
                            state.collectedRecordCount,
                          )
                        : isBackup
                        ? l10n.healthDashboardImportBackupProgressCount(
                            state.backupImportProcessedCount,
                            state.backupImportTotalCount,
                          )
                        : l10n.healthDashboardImportHealthConnectProgressCount(
                            state.collectedRecordCount,
                          ),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isComparison
                  ? l10n.healthDashboardHealthConnectComparisonProgressHint
                  : isAnalysis
                  ? l10n.healthDashboardHealthConnectAnalysisProgressHint
                  : isBackup
                  ? l10n.healthDashboardImportBackupProgressHint
                  : l10n.healthDashboardImportHealthConnectProgressHint,
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

enum HealthImportOperation { healthConnect, backup, analysis, comparison }
