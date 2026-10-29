import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';

import '../depot_state.dart';

class DepotTabs extends StatelessWidget {
  const DepotTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tab = context.select<DepotState, DepotTab>((s) => s.tab);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cramped = constraints.isCompact;
        ButtonSegment<DepotTab> segment(
          DepotTab value,
          IconData icon,
          String label,
        ) => ButtonSegment(
          value: value,
          label: cramped
              ? Icon(icon)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
          tooltip: label,
        );

        return SegmentedButton<DepotTab>(
          style: cramped
              ? const ButtonStyle(
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 3),
                  ),
                  minimumSize: WidgetStatePropertyAll(Size(0, 40)),
                )
              : null,
          segments: [
            segment(
              DepotTab.overview,
              Icons.pie_chart_outline,
              l10n.depotTabOverview,
            ),
            segment(
              DepotTab.allocation,
              Icons.stacked_bar_chart,
              l10n.depotTabAllocation,
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
