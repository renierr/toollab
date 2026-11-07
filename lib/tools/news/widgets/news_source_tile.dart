import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../news_l10n.dart';
import '../news_source.dart';
import '../news_time.dart';

class NewsSourceTile extends StatelessWidget {
  final NewsSource source;
  final int unreadCount;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const NewsSourceTile({
    super.key,
    required this.source,
    required this.unreadCount,
    required this.onEnabledChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final updated = source.lastFetchedAt == 0
        ? l10n.newsSourceNeverUpdated
        : l10n.newsSourceUpdated(
            newsRelativeTimeFor(l10n, locale, source.lastFetchedAt),
          );

    return Opacity(
      opacity: source.enabled ? 1 : 0.55,
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(
            Icons.rss_feed,
            size: 19,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                source.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${newsCategoryLabel(l10n, source.category)} · $updated',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            if (source.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  source.lastError!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: source.enabled, onChanged: onEnabledChanged),
            PopupMenuButton<String>(
              tooltip: l10n.commonEdit,
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(l10n.commonEdit),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      l10n.commonDelete,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
