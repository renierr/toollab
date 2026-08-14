import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

import '../sqlite_viewer_state.dart';

class SqliteDataToolbar extends StatefulWidget {
  final VoidCallback? onAddRow;

  const SqliteDataToolbar({super.key, this.onAddRow});

  @override
  State<SqliteDataToolbar> createState() => _SqliteDataToolbarState();
}

class _SqliteDataToolbarState extends State<SqliteDataToolbar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SqliteViewerState>();
    final page = state.page;

    final from = page.totalRows == 0 ? 0 : page.offset + 1;
    final to = page.offset + page.rows.length;

    if (_searchController.text != state.search) {
      _searchController.value = TextEditingValue(
        text: state.search,
        selection: TextSelection.collapsed(offset: state.search.length),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: context.read<SqliteViewerState>().setSearch,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: l10n.sqliteViewerSearchHint,
              border: const OutlineInputBorder(),
              suffixIcon: state.search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () =>
                          context.read<SqliteViewerState>().setSearch(''),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.sqliteViewerRowRange('$from', '$to', '${page.totalRows}'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: l10n.sqliteViewerPreviousPage,
                visualDensity: VisualDensity.compact,
                onPressed: page.offset <= 0 || state.isBusy
                    ? null
                    : context.read<SqliteViewerState>().previousPage,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: l10n.sqliteViewerNextPage,
                visualDensity: VisualDensity.compact,
                onPressed: to >= page.totalRows || state.isBusy
                    ? null
                    : context.read<SqliteViewerState>().nextPage,
              ),
              for (final size in kSqliteViewerPageSizes)
                ToolChip(
                  label: '$size',
                  selected: state.pageSize == size,
                  onTap: () =>
                      context.read<SqliteViewerState>().setPageSize(size),
                ),
              if (widget.onAddRow != null)
                ToolChip(
                  icon: Icons.add,
                  label: l10n.sqliteViewerAddRow,
                  onTap: widget.onAddRow!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
