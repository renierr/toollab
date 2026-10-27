import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_state.dart';

class DepotTabs extends StatelessWidget {
  const DepotTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tab = context.select<DepotState, DepotTab>((s) => s.tab);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Segments share the width equally, so below this even one label
        // wraps; the app bar title already names the tab.
        final cramped = constraints.maxWidth < 620;
        ButtonSegment<DepotTab> segment(
          DepotTab value,
          IconData icon,
          String label,
        ) => ButtonSegment(
          value: value,
          icon: Icon(icon),
          label: cramped ? null : Text(label),
          tooltip: label,
        );

        return SegmentedButton<DepotTab>(
          segments: [
            segment(
              DepotTab.overview,
              Icons.pie_chart_outline,
              l10n.depotTabOverview,
            ),
            segment(
              DepotTab.dividends,
              Icons.payments_outlined,
              l10n.depotTabDividends,
            ),
            segment(
              DepotTab.activities,
              Icons.receipt_long_outlined,
              l10n.depotTabActivities,
            ),
            segment(
              DepotTab.wishlist,
              Icons.star_outline,
              l10n.depotTabWishlist,
            ),
            segment(
              DepotTab.pdfImport,
              Icons.picture_as_pdf_outlined,
              l10n.depotTabImport,
            ),
          ],
          selected: {tab},
          showSelectedIcon: false,
          onSelectionChanged: (selection) =>
              context.read<DepotState>().setTab(selection.first),
        );
      },
    );
  }
}
