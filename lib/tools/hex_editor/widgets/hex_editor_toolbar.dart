import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import '../hex_editor_state.dart';
import 'strings_scan_dialog.dart';

class HexEditorToolbar extends StatefulWidget {
  final VoidCallback onReset;
  final void Function(int offset) onNavigateToOffset;

  const HexEditorToolbar({
    super.key,
    required this.onReset,
    required this.onNavigateToOffset,
  });

  @override
  State<HexEditorToolbar> createState() => _HexEditorToolbarState();
}

class _HexEditorToolbarState extends State<HexEditorToolbar> {
  final TextEditingController _searchController = TextEditingController();
  String _searchType = 'hex';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(HexEditorState state, {bool next = false}) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final l10n = AppLocalizations.of(context);
    if (_searchType == 'hex') {
      final hex = query.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
      if (hex.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.hexEditorInvalidHex)));
        return;
      }
      if (hex.length % 2 != 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.hexEditorHexLengthEven)));
        return;
      }
    }

    final success = await state.search(query, _searchType, next: next);
    if (!success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.hexEditorPatternNotFound)));
    } else if (success && state.searchMatchOffset != null) {
      widget.onNavigateToOffset(state.searchMatchOffset!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<HexEditorState>();
    final isWide = MediaQuery.of(context).size.width > 720;

    final infoPanel = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.fileName ?? '',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${state.fileMimeType} • ${l10n.hexEditorSize(state.totalSize.toString())}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final actionsWrap = Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: state.showAscii,
              onChanged: (val) => state.toggleAscii(val),
              activeThumbColor: AppTheme.accentPurple,
            ),
            const SizedBox(width: 4),
            Text(l10n.hexEditorShowAscii, style: theme.textTheme.bodyMedium),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () =>
              StringsScanDialog.show(context, widget.onNavigateToOffset),
          icon: const Icon(Icons.abc),
          label: Text(l10n.hexEditorStringsTooltip),
        ),
        OutlinedButton.icon(
          onPressed: widget.onReset,
          icon: const Icon(Icons.close),
          label: Text(l10n.hexEditorReset),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.statusRed,
            side: const BorderSide(color: AppTheme.statusRed),
          ),
        ),
      ],
    );

    final searchPanel = Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          children: [
            DropdownButton<String>(
              value: _searchType,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: 'hex',
                  child: Text(l10n.hexEditorSearchHex),
                ),
                DropdownMenuItem(
                  value: 'text',
                  child: Text(l10n.hexEditorSearchText),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _searchType = val;
                  });
                }
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.hexEditorSearchPlaceholder,
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
                onSubmitted: (_) => _onSearch(state),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  state.clearSearch();
                  setState(() {});
                },
              ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.commonSearch,
              onPressed: () => _onSearch(state),
            ),
            IconButton(
              icon: const Icon(Icons.navigate_next),
              tooltip: l10n.hexEditorSearchNext,
              onPressed: () => _onSearch(state, next: true),
            ),
          ],
        ),
      ),
    );

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(flex: 3, child: infoPanel),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: searchPanel),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: actionsWrap),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            infoPanel,
            const SizedBox(height: 8),
            searchPanel,
            const SizedBox(height: 8),
            actionsWrap,
          ],
        ),
      );
    }
  }
}
