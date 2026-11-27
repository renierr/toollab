import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/pages/video_settings_page.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../trimz_links.dart';
import '../trimz_state.dart';

class TrimzSettingsPage extends StatelessWidget {
  const TrimzSettingsPage({super.key});

  Future<void> _clear(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() clear,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: title,
      message: message,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true) return;
    await clear();
    messenger.showSnackBar(SnackBar(content: Text(l10n.trimzCleared)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<TrimzState>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.commonSettings)),
      body: ReadableScrollPadding(
        maxWidth: 680,
        padding: const EdgeInsets.only(bottom: 32),
        builder: (context, padding) => ListView(
          padding: padding,
          children: [
            SettingsSectionLabel(title: l10n.trimzSettingsPlayback),
            SwitchListTile(
              secondary: const Icon(Icons.network_check),
              title: Text(l10n.trimzAdaptiveStream),
              subtitle: Text(l10n.trimzAdaptiveStreamSubtitle),
              value: state.adaptiveStream,
              onChanged: (v) => unawaited(state.setAdaptiveStream(v)),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.skip_next_outlined),
              title: Text(l10n.trimzAutoplayNext),
              subtitle: Text(l10n.trimzAutoplayNextSubtitle),
              value: state.autoplayNext,
              onChanged: (v) => unawaited(state.setAutoplayNext(v)),
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(l10n.trimzPlayerSettings),
              subtitle: Text(l10n.trimzPlayerSettingsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const VideoSettingsPage(),
                ),
              ),
            ),
            SettingsSectionLabel(title: l10n.trimzSettingsCatalog),
            SwitchListTile(
              secondary: const Icon(Icons.translate),
              title: Text(l10n.trimzTranslatedTitles),
              subtitle: Text(l10n.trimzTranslatedTitlesSubtitle),
              value: state.translatedTitles,
              onChanged: (v) => unawaited(state.setTranslatedTitles(v)),
            ),
            SettingsSectionLabel(title: l10n.trimzSettingsData),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(l10n.trimzClearHistory),
              subtitle: Text(l10n.trimzClearHistorySubtitle),
              enabled: state.continueWatching.isNotEmpty,
              onTap: () => unawaited(
                _clear(
                  context,
                  title: l10n.trimzClearHistory,
                  message: l10n.trimzClearHistoryBody,
                  clear: state.clearHistory,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_remove_outlined),
              title: Text(l10n.trimzClearList),
              enabled: state.myList.isNotEmpty,
              onTap: () => unawaited(
                _clear(
                  context,
                  title: l10n.trimzClearList,
                  message: l10n.trimzClearListBody,
                  clear: state.clearList,
                ),
              ),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(l10n.trimzOpenOnWeb),
              subtitle: Text(l10n.trimzAbout, style: theme.textTheme.bodySmall),
              onTap: () =>
                  unawaited(openTrimzUrl(context, Uri.https('trimz.tv', '/'))),
            ),
          ],
        ),
      ),
    );
  }
}
