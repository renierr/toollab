import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';

import '../depot_state.dart';
import 'depot_section_nav.dart';

class DepotTabs extends StatefulWidget {
  const DepotTabs({super.key});

  @override
  State<DepotTabs> createState() => _DepotTabsState();
}

class _DepotTabsState extends State<DepotTabs> with DisposeCleanup {
  final FocusNode _node = FocusNode(
    debugLabel: 'DepotTabs',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    onDispose(_node.dispose);
    // Without it the remote's first Down lands in the app bar.
    if (context.read<AppState?>()?.tvMode ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusSelected());
    }
  }

  void _focusSelected() {
    if (!mounted) return;
    final segments = [
      for (final node in _node.traversalDescendants)
        if (node.canRequestFocus) node,
    ];
    final index = context.read<DepotState>().tab.index;
    if (index < segments.length) segments[index].requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }
    return DepotSectionNav.focusActive(context)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

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

        return Focus(
          focusNode: _node,
          onKeyEvent: _onKey,
          child: SegmentedButton<DepotTab>(
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
          ),
        );
      },
    );
  }
}
