import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_dividend_state.dart';
import '../depot_logo_state.dart';
import '../depot_portfolio_state.dart';
import '../depot_report_pdf.dart';
import '../depot_year_review_pdf.dart';

/// Saves the overview's current selection, or a year in review, as a PDF.
class DepotReportButton extends StatefulWidget {
  const DepotReportButton({super.key});

  @override
  State<DepotReportButton> createState() => _DepotReportButtonState();
}

/// What the menu creates; a null year is the overview report.
typedef _Choice = ({int? year});

class _DepotReportButtonState extends State<DepotReportButton> {
  bool _busy = false;

  Future<void> _create(_Choice choice) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<DepotPortfolioState>();
    final logos = context.read<DepotLogoState>();
    final dividends = context.read<DepotDividendState>();
    final year = choice.year;
    setState(() => _busy = true);
    try {
      final Uint8List bytes;
      final String name;
      if (year == null) {
        bytes = await DepotReportPdf.build(
          state: state,
          logoOf: logos.bytesFor,
          l10n: l10n,
          locale: locale,
        );
        final now = DateTime.now();
        name =
            'depot-report-${now.year}-${'${now.month}'.padLeft(2, '0')}-'
            '${'${now.day}'.padLeft(2, '0')}.pdf';
      } else {
        await dividends.ensureLoaded();
        bytes = await DepotYearReviewPdf.build(
          state: state,
          dividendAssets: dividends.assets,
          year: year,
          l10n: l10n,
          locale: locale,
        );
        name = 'depot-year-$year.pdf';
      }
      if (!mounted) return;
      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: name,
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
    return PopupMenuButton<_Choice>(
      icon: const Icon(Icons.picture_as_pdf_outlined),
      tooltip: l10n.depotReportPdf,
      enabled: state.hasData,
      onSelected: _create,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: (year: null),
          child: Text(l10n.depotReportOverview),
        ),
        for (final year in DepotYearReviewPdf.yearsOf(state))
          PopupMenuItem(
            value: (year: year),
            child: Text(l10n.depotYearReviewTitle('$year')),
          ),
      ],
    );
  }
}
