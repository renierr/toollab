import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_dividend_state.dart';
import '../depot_portfolio_state.dart';
import '../depot_year_review_pdf.dart';

/// Saves the year in review of [year] as a PDF.
class DepotYearReviewButton extends StatefulWidget {
  final int year;

  const DepotYearReviewButton({super.key, required this.year});

  /// Builds and saves the PDF; shared with the overview's report menu.
  static Future<void> save(BuildContext context, int year) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<DepotPortfolioState>();
    final dividends = context.read<DepotDividendState>();
    try {
      await dividends.ensureLoaded();
      final bytes = await DepotYearReviewPdf.build(
        state: state,
        dividendAssets: dividends.assets,
        year: year,
        l10n: l10n,
        locale: locale,
      );
      if (!context.mounted) return;
      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: 'depot-year-$year.pdf',
        bytes: bytes,
      );
    } catch (e) {
      errorLog('[DepotYearReviewButton] Year in review failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.depotReportFailed)));
    }
  }

  @override
  State<DepotYearReviewButton> createState() => _DepotYearReviewButtonState();
}

class _DepotYearReviewButtonState extends State<DepotYearReviewButton> {
  bool _busy = false;

  Future<void> _create() async {
    setState(() => _busy = true);
    await DepotYearReviewButton.save(context, widget.year);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextButton.icon(
      onPressed: _busy ? null : _create,
      icon: _busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined),
      label: Text(l10n.depotYearReviewPdf),
    );
  }
}
