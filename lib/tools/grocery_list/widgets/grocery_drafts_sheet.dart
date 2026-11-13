import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../grocery_text_parser.dart';

/// Lets the user pick which recognized items go onto the list.
class GroceryDraftsSheet extends StatefulWidget {
  final List<GroceryDraft> drafts;

  const GroceryDraftsSheet({super.key, required this.drafts});

  static Future<List<GroceryDraft>?> show(
    BuildContext context,
    List<GroceryDraft> drafts,
  ) {
    return showModalBottomSheet<List<GroceryDraft>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => GroceryDraftsSheet(drafts: drafts),
    );
  }

  @override
  State<GroceryDraftsSheet> createState() => _GroceryDraftsSheetState();
}

class _GroceryDraftsSheetState extends State<GroceryDraftsSheet> {
  late final Set<int> _selected = {
    for (var i = 0; i < widget.drafts.length; i++) i,
  };

  static String _amount(GroceryDraft d) {
    final value = d.amount == d.amount.roundToDouble()
        ? d.amount.round().toString()
        : d.amount.toString();
    return '$value ${d.unit}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final drafts = widget.drafts;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.groceryDraftsTitle(drafts.length),
                style: theme.textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: drafts.length,
                itemBuilder: (context, i) => CheckboxListTile(
                  value: _selected.contains(i),
                  title: Text(drafts[i].name),
                  subtitle: Text(_amount(drafts[i])),
                  onChanged: (on) => setState(
                    () => on == true ? _selected.add(i) : _selected.remove(i),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  FilledButton.icon(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(context).pop([
                            for (var i = 0; i < drafts.length; i++)
                              if (_selected.contains(i)) drafts[i],
                          ]),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: Text(l10n.groceryDraftsAdd(_selected.length)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
