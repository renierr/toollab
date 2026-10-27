import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_logo_state.dart';
import '../depot_portfolio_state.dart';
import '../depot_report_pdf.dart';

/// Saves the overview's current selection as a PDF report.
class DepotReportButton extends StatefulWidget {
  const DepotReportButton({super.key});

  @override
  State<DepotReportButton> createState() => _DepotReportButtonState();
}

class _DepotReportButtonState extends State<DepotReportButton> {
  bool _busy = false;

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final messenger = ScaffoldMessenger.of(context);
    final logos = context.read<DepotLogoState>();
    setState(() => _busy = true);
    try {
      final bytes = await DepotReportPdf.build(
        state: context.read<DepotPortfolioState>(),
        logoOf: logos.bytesFor,
        l10n: l10n,
        locale: locale,
      );
      if (!mounted) return;
      final now = DateTime.now();
      await FileSaveHelper.saveFile(
        context: context,
        suggestedName:
            'depot-report-${now.year}-${'${now.month}'.padLeft(2, '0')}-'
            '${'${now.day}'.padLeft(2, '0')}.pdf',
        bytes: bytes,
      );
    } catch (e) {
      errorLog('[DepotReportButton] PDF report failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.depotReportFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasData = context.select<DepotPortfolioState, bool>((s) => s.hasData);
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.picture_as_pdf_outlined),
      tooltip: l10n.depotReportPdf,
      onPressed: hasData ? _create : null,
    );
  }
}
