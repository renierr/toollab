import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_logo_state.dart';
import '../depot_portfolio_state.dart';
import '../depot_report_pdf.dart';
import '../depot_year_review_pdf.dart';
import 'depot_year_review_button.dart';

/// Saves the overview's current selection, or the running year in review,
/// as a PDF; older years are in the Activities yearly report.
class DepotReportButton extends StatefulWidget {
  const DepotReportButton({super.key});

  @override
  State<DepotReportButton> createState() => _DepotReportButtonState();
}

enum _Choice { overview, yearReview }

class _DepotReportButtonState extends State<DepotReportButton> {
  bool _busy = false;

  Future<void> _create(_Choice choice) async {
    setState(() => _busy = true);
    switch (choice) {
      case _Choice.overview:
        await _overview();
      case _Choice.yearReview:
        await DepotYearReviewButton.save(context, DateTime.now().year);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _overview() async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final messenger = ScaffoldMessenger.of(context);
    final logos = context.read<DepotLogoState>();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<DepotPortfolioState>();
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final year = DateTime.now().year;
    return PopupMenuButton<_Choice>(
      icon: const Icon(Icons.picture_as_pdf_outlined),
      tooltip: l10n.depotReportPdf,
      enabled: state.hasData,
      onSelected: _create,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _Choice.overview,
          child: Text(l10n.depotReportOverview),
        ),
        if (DepotYearReviewPdf.yearsOf(state).contains(year))
          PopupMenuItem(
            value: _Choice.yearReview,
            child: Text(l10n.depotYearReviewTitle('$year')),
          ),
      ],
    );
  }
}
