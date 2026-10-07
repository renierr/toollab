import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/format_helper.dart';

import '../models/paperless_document.dart';
import '../paperless_state.dart';
import 'paperless_tag_chip.dart';
import 'paperless_thumbnail.dart';

class PaperlessDocumentTile extends StatelessWidget {
  final PaperlessDocument document;
  final VoidCallback onTap;

  const PaperlessDocumentTile({
    super.key,
    required this.document,
    required this.onTap,
  });

  static const _maxTags = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.read<PaperlessState>();
    final created = document.created;
    final subtitle = [
      if (created != null)
        FormatHelper.dateTime(created, style: DateStyle.dateOnly),
      ?state.correspondent(document.correspondentId)?.name,
      ?state.documentType(document.documentTypeId)?.name,
    ].join(' · ');
    final tags = document.tagIds.map(state.tag).nonNulls.take(_maxTags);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PaperlessThumbnail(documentId: document.id),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final tag in tags) PaperlessTagChip(tag: tag),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
