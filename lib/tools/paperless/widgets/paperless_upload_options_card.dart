import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/info_card.dart';

import '../models/paperless_upload.dart';
import '../paperless_state.dart';
import 'paperless_label_dropdown.dart';
import 'paperless_tag_selector.dart';

class PaperlessUploadOptionsCard extends StatelessWidget {
  final PaperlessUploadOptions options;
  final ValueChanged<PaperlessUploadOptions> onChanged;

  const PaperlessUploadOptionsCard({
    super.key,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<PaperlessState>();

    return InfoCard(
      icon: Icons.label_outline,
      title: l10n.paperlessUploadOptionsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.paperlessUploadOptionsHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 12),
          PaperlessLabelDropdown(
            label: l10n.paperlessCorrespondent,
            noneLabel: l10n.paperlessAutomatic,
            icon: Icons.person_outline,
            options: state.correspondents,
            value: options.correspondentId,
            onChanged: (id) =>
                onChanged(options.copyWith(correspondentId: () => id)),
          ),
          const SizedBox(height: 12),
          PaperlessLabelDropdown(
            label: l10n.paperlessDocumentType,
            noneLabel: l10n.paperlessAutomatic,
            icon: Icons.category_outlined,
            options: state.documentTypes,
            value: options.documentTypeId,
            onChanged: (id) =>
                onChanged(options.copyWith(documentTypeId: () => id)),
          ),
          const SizedBox(height: 12),
          Text(l10n.paperlessTags, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          PaperlessTagSelector(
            tags: state.tags,
            selected: options.tagIds,
            onChanged: (ids) => onChanged(options.copyWith(tagIds: ids)),
          ),
        ],
      ),
    );
  }
}
