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

    return SegmentedButton<DepotTab>(
      segments: [
        ButtonSegment(
          value: DepotTab.overview,
          icon: const Icon(Icons.pie_chart_outline),
          label: Text(l10n.depotTabOverview),
        ),
        ButtonSegment(
          value: DepotTab.pdfImport,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(l10n.depotTabImport),
        ),
      ],
      selected: {tab},
      showSelectedIcon: false,
      onSelectionChanged: (selection) =>
          context.read<DepotState>().setTab(selection.first),
    );
  }
}
