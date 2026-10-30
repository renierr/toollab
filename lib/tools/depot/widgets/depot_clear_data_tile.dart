import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';

import '../depot_allocation_state.dart';
import '../depot_dividend_state.dart';
import '../depot_logo_state.dart';
import '../depot_portfolio_state.dart';

class DepotClearDataTile extends StatefulWidget {
  const DepotClearDataTile({super.key});

  @override
  State<DepotClearDataTile> createState() => _DepotClearDataTileState();
}

class _DepotClearDataTileState extends State<DepotClearDataTile> {
  bool _clearing = false;

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.depotClearDataTitle,
      message: l10n.depotClearDataConfirm,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.depotClearDataAction,
    );
    if (confirmed != true || !mounted) return;
    final portfolio = context.read<DepotPortfolioState>();
    final logos = context.read<DepotLogoState>();
    final allocation = context.read<DepotAllocationState>();
    final dividends = context.read<DepotDividendState>();
    setState(() => _clearing = true);
    try {
      await portfolio.clearLocalData();
      logos.reset();
      allocation.reset();
      dividends.reset();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.depotClearDataDone)));
      }
    } catch (e) {
      errorLog('[DepotClearDataTile] Clearing failed: $e');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    return ListTile(
      leading: Icon(Icons.delete_forever_outlined, color: error),
      title: Text(l10n.depotClearDataTitle, style: TextStyle(color: error)),
      subtitle: Text(l10n.depotClearDataSubtitle),
      trailing: _clearing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _clearing ? null : _clear,
    );
  }
}
