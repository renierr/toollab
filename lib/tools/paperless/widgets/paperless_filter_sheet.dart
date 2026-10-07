import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/paperless_filter.dart';
import '../paperless_state.dart';
import 'paperless_label_dropdown.dart';
import 'paperless_tag_selector.dart';

class PaperlessFilterSheet extends StatefulWidget {
  final PaperlessFilter initial;

  const PaperlessFilterSheet({super.key, required this.initial});

  static Future<PaperlessFilter?> show(
    BuildContext context,
    PaperlessFilter initial,
  ) {
    return showModalBottomSheet<PaperlessFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PaperlessFilterSheet(initial: initial),
    );
  }

  @override
  State<PaperlessFilterSheet> createState() => _PaperlessFilterSheetState();
}

class _PaperlessFilterSheetState extends State<PaperlessFilterSheet> {
  late PaperlessFilter _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<PaperlessState>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.paperlessFilters, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            PaperlessLabelDropdown(
              label: l10n.paperlessCorrespondent,
              noneLabel: l10n.paperlessAny,
              icon: Icons.person_outline,
              options: state.correspondents,
              value: _draft.correspondentId,
              onChanged: (id) => setState(
                () => _draft = _draft.copyWith(correspondentId: () => id),
              ),
            ),
            const SizedBox(height: 12),
            PaperlessLabelDropdown(
              label: l10n.paperlessDocumentType,
              noneLabel: l10n.paperlessAny,
              icon: Icons.category_outlined,
              options: state.documentTypes,
              value: _draft.documentTypeId,
              onChanged: (id) => setState(
                () => _draft = _draft.copyWith(documentTypeId: () => id),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.paperlessInboxOnly),
              value: _draft.inboxOnly,
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(inboxOnly: value)),
            ),
            Text(l10n.paperlessTags, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            PaperlessTagSelector(
              tags: state.tags,
              selected: _draft.tagIds,
              onChanged: (ids) =>
                  setState(() => _draft = _draft.copyWith(tagIds: ids)),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () =>
                      setState(() => _draft = _draft.clearSheetFilters()),
                  child: Text(l10n.commonReset),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_draft),
                  child: Text(l10n.commonApply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
