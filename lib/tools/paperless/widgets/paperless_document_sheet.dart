import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/data_row.dart';

import '../models/paperless_document.dart';
import '../paperless_state.dart';
import 'paperless_tag_chip.dart';
import 'paperless_thumbnail.dart';

class PaperlessDocumentSheet extends StatelessWidget {
  final PaperlessDocument document;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onOpenInBrowser;

  const PaperlessDocumentSheet({
    super.key,
    required this.document,
    required this.onOpen,
    required this.onShare,
    required this.onOpenInBrowser,
  });

  static Future<void> show(
    BuildContext context, {
    required PaperlessDocument document,
    required VoidCallback onOpen,
    required VoidCallback onShare,
    required VoidCallback onOpenInBrowser,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PaperlessDocumentSheet(
        document: document,
        onOpen: onOpen,
        onShare: onShare,
        onOpenInBrowser: onOpenInBrowser,
      ),
    );
  }

  String _date(DateTime? date) => date == null
      ? ''
      : FormatHelper.dateTime(date, style: DateStyle.dateOnly);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.read<PaperlessState>();
    final tags = document.tagIds.map(state.tag).nonNulls.toList();

    void run(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PaperlessThumbnail(
                  documentId: document.id,
                  width: 72,
                  height: 96,
                  tapToPreview: true,
                  label: document.title,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    document.title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InfoRow(
              label: l10n.paperlessCreated,
              value: _date(document.created),
            ),
            const SizedBox(height: 6),
            InfoRow(label: l10n.paperlessAdded, value: _date(document.added)),
            const SizedBox(height: 6),
            InfoRow(
              label: l10n.paperlessCorrespondent,
              value: state.correspondent(document.correspondentId)?.name ?? '',
            ),
            const SizedBox(height: 6),
            InfoRow(
              label: l10n.paperlessDocumentType,
              value: state.documentType(document.documentTypeId)?.name ?? '',
            ),
            const SizedBox(height: 6),
            InfoRow(
              label: l10n.paperlessArchiveNumber,
              value: document.archiveSerialNumber?.toString() ?? '',
            ),
            const SizedBox(height: 6),
            InfoRow(
              label: l10n.paperlessOriginalFile,
              value: document.originalFileName ?? '',
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [for (final tag in tags) PaperlessTagChip(tag: tag)],
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => run(onOpenInBrowser),
                  icon: const Icon(Icons.open_in_browser),
                  label: Text(l10n.paperlessOpenInBrowser),
                ),
                OutlinedButton.icon(
                  onPressed: () => run(onShare),
                  icon: const Icon(Icons.share_outlined),
                  label: Text(l10n.commonShare),
                ),
                FilledButton.icon(
                  onPressed: () => run(onOpen),
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(l10n.commonOpen),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
