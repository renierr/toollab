import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../news_source.dart';
import '../news_state.dart';
import '../news_sync_helper.dart';
import 'news_source_edit_dialog.dart';
import 'news_source_picker_page.dart';
import 'news_source_tile.dart';

class NewsSettingsPage extends StatelessWidget {
  const NewsSettingsPage({super.key});

  Future<void> _openPicker(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NewsSourcePickerPage()),
    );
  }

  Future<void> _edit(BuildContext context, NewsSource source) async {
    final saved = await NewsSourceEditDialog.show(context, source);
    if (saved == true && context.mounted) {
      unawaited(syncNewsSources(context.read<AppState>()));
    }
  }

  Future<void> _delete(BuildContext context, NewsSource source) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.newsDeleteSourceTitle,
      message: l10n.newsDeleteSourceBody(source.title),
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true || !context.mounted) return;
    final state = context.read<NewsState>();
    final appState = context.read<AppState>();
    await state.deleteSource(source);
    unawaited(syncNewsSources(appState));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.newsSourceDeleted)));
  }

  Future<void> _toggle(
    BuildContext context,
    NewsSource source,
    bool enabled,
  ) async {
    final state = context.read<NewsState>();
    final appState = context.read<AppState>();
    await state.setSourceEnabled(source, enabled);
    unawaited(syncNewsSources(appState));
  }

  Future<void> _markAllRead(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await context.read<NewsState>().markAllRead();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.newsMarkAllReadDone)));
  }

  Future<void> _clearCache(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.newsClearCacheTitle,
      message: l10n.newsClearCacheBody,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<NewsState>().clearCachedArticles();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.newsClearCacheDone)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<NewsState>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newsSettingsTitle)),
      body: ReadableScrollPadding(
        maxWidth: 680,
        padding: const EdgeInsets.only(bottom: 32),
        builder: (context, padding) => ListView(
          padding: padding,
          children: [
            SettingsSectionLabel(title: l10n.newsReadingSection),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_outlined),
              title: Text(l10n.newsMarkReadOnScroll),
              subtitle: Text(l10n.newsMarkReadOnScrollSubtitle),
              value: state.markReadOnScroll,
              onChanged: state.setMarkReadOnScroll,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.filter_alt_outlined),
              title: Text(l10n.newsHideRead),
              subtitle: Text(l10n.newsHideReadSubtitle),
              value: state.hideRead,
              onChanged: state.setHideRead,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.autorenew),
              title: Text(l10n.newsRefreshOnOpen),
              subtitle: Text(l10n.newsRefreshOnOpenSubtitle),
              value: state.refreshOnOpen,
              onChanged: state.setRefreshOnOpen,
            ),
            SettingsSectionLabel(
              title: l10n.newsSourcesSection,
              description: l10n.newsSourcesSectionHint,
            ),
            if (state.sources.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.newsEmptyNoSourcesBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final source in state.sources)
                NewsSourceTile(
                  source: source,
                  unreadCount: state.unreadCounts[source.shortId] ?? 0,
                  onEnabledChanged: (value) => _toggle(context, source, value),
                  onEdit: () => _edit(context, source),
                  onDelete: () => _delete(context, source),
                ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: OutlinedButton.icon(
                onPressed: () => _openPicker(context),
                icon: const Icon(Icons.add),
                label: Text(l10n.newsAddSource),
              ),
            ),
            SettingsSectionLabel(title: l10n.newsDataSection),
            ListTile(
              leading: const Icon(Icons.done_all),
              title: Text(l10n.newsMarkAllRead),
              onTap: () => _markAllRead(context),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_sweep_outlined,
                color: theme.colorScheme.error,
              ),
              title: Text(
                l10n.newsClearCache,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: Text(l10n.newsClearCacheSubtitle),
              onTap: () => _clearCache(context),
            ),
          ],
        ),
      ),
    );
  }
}
