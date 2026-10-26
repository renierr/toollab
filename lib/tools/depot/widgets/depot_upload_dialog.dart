import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../depot_store.dart';
import '../models/depot_activity.dart';
import '../models/depot_portfolio.dart';
import '../parqet/parqet_activity_upload.dart';

typedef DepotUploadTarget = ({String portfolioId, Set<String> existing});

/// Picks the target portfolio and shows what an upload will do there.
class DepotUploadDialog extends StatefulWidget {
  final List<DepotPortfolio> portfolios;
  final String initialPortfolioId;
  final List<ParsedStatement> statements;

  const DepotUploadDialog({
    super.key,
    required this.portfolios,
    required this.initialPortfolioId,
    required this.statements,
  });

  static Future<DepotUploadTarget?> show(
    BuildContext context, {
    required List<DepotPortfolio> portfolios,
    required String initialPortfolioId,
    required List<ParsedStatement> statements,
  }) => showDialog<DepotUploadTarget>(
    context: context,
    builder: (_) => DepotUploadDialog(
      portfolios: portfolios,
      initialPortfolioId: initialPortfolioId,
      statements: statements,
    ),
  );

  @override
  State<DepotUploadDialog> createState() => _DepotUploadDialogState();
}

class _DepotUploadDialogState extends State<DepotUploadDialog> {
  late String _portfolioId = widget.initialPortfolioId;

  /// Null while the synced bookings of the portfolio are being compared.
  Set<String>? _existing;
  int _check = 0;

  @override
  void initState() {
    super.initState();
    _compare();
  }

  Future<void> _compare() async {
    final check = ++_check;
    setState(() => _existing = null);
    var existing = <String>{};
    try {
      final store = DepotStore.instance;
      existing = ParqetActivityUpload.alreadyInParqet(
        widget.statements,
        await store.holdings(portfolioId: _portfolioId),
        await store.transactions(portfolioId: _portfolioId),
      );
    } catch (e) {
      errorLog('[DepotUploadDialog] Comparing bookings failed: $e');
    }
    if (!mounted || check != _check) return;
    setState(() => _existing = existing);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final existing = _existing;
    final total = widget.statements.length;
    final withIssues = widget.statements
        .where((s) => s.issues.isNotEmpty)
        .length;
    final toSend = existing == null ? null : total - existing.length;

    return ResponsiveAlertDialog(
      title: Text(l10n.depotUploadTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.portfolios.length > 1)
            DropdownButtonFormField<String>(
              initialValue: _portfolioId,
              decoration: InputDecoration(labelText: l10n.depotUploadPortfolio),
              items: [
                for (final p in widget.portfolios)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (id) {
                if (id == null || id == _portfolioId) return;
                _portfolioId = id;
                _compare();
              },
            )
          else
            Text(
              l10n.depotUploadSinglePortfolio(widget.portfolios.first.name),
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: 16),
          if (existing == null)
            const LinearProgressIndicator()
          else ...[
            Text(
              l10n.depotUploadCount(toSend!),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (existing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.depotUploadExisting(existing.length),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
          if (withIssues > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.depotImportExportIssuesBody(withIssues),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.statusAmber,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            l10n.depotUploadHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.cloud_upload_outlined),
          label: Text(l10n.depotUploadConfirm),
          onPressed: existing == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop((portfolioId: _portfolioId, existing: existing)),
        ),
      ],
    );
  }
}
