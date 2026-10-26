import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/background_task_service.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/background_task_tile.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';
import 'package:url_launcher/url_launcher.dart';

import '../depot_background_sync.dart';
import '../depot_portfolio_labels.dart';
import '../depot_portfolio_state.dart';
import '../parqet/parqet_auth.dart';

/// Pushed with a `MaterialPageRoute`, so a plain `Scaffold` instead of
/// `ToolLayout`, whose back button needs a GoRouter state.
class DepotSettingsPage extends StatefulWidget {
  const DepotSettingsPage({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const DepotSettingsPage()));

  @override
  State<DepotSettingsPage> createState() => _DepotSettingsPageState();
}

class _DepotSettingsPageState extends State<DepotSettingsPage>
    with DisposeCleanup {
  static final Uri _consoleUri = Uri.parse(
    'https://developer.parqet.com/console/integrations',
  );

  late final TextEditingController _clientId;
  Set<String> _scopes = const {};

  @override
  void initState() {
    super.initState();
    _clientId = TextEditingController(
      text: context.read<DepotPortfolioState>().clientId,
    );
    onDispose(_clientId.dispose);
    _loadScopes();
  }

  Future<void> _loadScopes() async {
    final scopes = await ParqetAuth.grantedScopes();
    if (!mounted) return;
    setState(() => _scopes = scopes);
  }

  Future<void> _connect() async {
    final l10n = AppLocalizations.of(context);
    final html =
        '<!doctype html><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width">'
        '<body style="font-family:sans-serif;padding:2em;text-align:center">'
        '<h2>${const HtmlEscape().convert(l10n.depotLoginBrowserTitle)}</h2>'
        '<p>${const HtmlEscape().convert(l10n.depotLoginBrowserBody)}</p>';
    final connected = await context.read<DepotPortfolioState>().connect(
      clientId: _clientId.text,
      responseHtml: html,
    );
    if (!mounted) return;
    await _loadScopes();
    if (connected && mounted) Navigator.of(context).pop();
  }

  Future<void> _disconnect() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.depotSettingsDisconnect,
      message: l10n.depotSettingsDisconnectConfirm,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.depotSettingsDisconnect,
    );
    if (confirmed == true && mounted) {
      await context.read<DepotPortfolioState>().disconnect();
    }
  }

  void _copyRedirect() {
    Clipboard.setData(const ClipboardData(text: ParqetAuth.redirectUri));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).depotSettingsCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<DepotPortfolioState>();
    final error = state.error;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.depotSettingsTitle)),
      body: ReadableWidth(
        maxWidth: 640,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ListTile(
              leading: Icon(
                state.isConnected
                    ? Icons.check_circle_outline
                    : Icons.link_off_outlined,
                color: state.isConnected
                    ? AppTheme.statusGreen
                    : theme.hintColor,
              ),
              title: Text(
                state.isConnected
                    ? l10n.depotSettingsConnected
                    : l10n.depotSettingsNotConnected,
              ),
              subtitle: Text(
                state.lastSyncAt == null
                    ? l10n.depotNeverSynced
                    : l10n.depotLastSync(
                        FormatHelper.dateTime(state.lastSyncAt!),
                      ),
              ),
            ),
            if (state.isConnected && _scopes.isNotEmpty)
              ListTile(
                leading: Icon(
                  _scopes.contains(ParqetAuth.writeScope)
                      ? Icons.edit_outlined
                      : Icons.visibility_outlined,
                ),
                title: Text(l10n.depotSettingsGrantedAccess),
                subtitle: Text(
                  _scopes.contains(ParqetAuth.writeScope)
                      ? l10n.depotSettingsAccessReadWrite
                      : l10n.depotSettingsAccessReadOnly,
                ),
              ),
            SettingsSectionLabel(
              title: l10n.depotSettingsSectionParqet,
              description: l10n.depotSettingsIntro,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _clientId,
                enabled: !state.isConnecting,
                decoration: InputDecoration(
                  labelText: l10n.depotSettingsClientId,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.call_received_outlined),
              title: Text(l10n.depotSettingsRedirectUri),
              subtitle: const SelectableText(ParqetAuth.redirectUri),
              trailing: IconButton(
                icon: const Icon(Icons.copy_outlined),
                tooltip: l10n.commonCopy,
                onPressed: _copyRedirect,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_outlined),
              title: Text(l10n.depotSettingsOpenConsole),
              onTap: () =>
                  launchUrl(_consoleUri, mode: LaunchMode.externalApplication),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  DepotPortfolioLabels.error(l10n, error),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: state.isConnecting ? null : _connect,
                    icon: state.isConnecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_outlined),
                    label: Text(
                      state.isConnecting
                          ? l10n.depotSettingsConnecting
                          : state.isConnected
                          ? l10n.depotSettingsReconnect
                          : l10n.depotSettingsConnect,
                    ),
                  ),
                  if (state.isConnected)
                    OutlinedButton.icon(
                      onPressed: state.isConnecting ? null : _disconnect,
                      icon: const Icon(Icons.link_off_outlined),
                      label: Text(l10n.depotSettingsDisconnect),
                    ),
                ],
              ),
            ),
            if (BackgroundTaskService.isSupported && state.isConnected) ...[
              SettingsSectionLabel(title: l10n.depotSettingsSectionSync),
              BackgroundTaskTile(
                task: DepotBackgroundSync.task,
                icon: Icons.sync_outlined,
                title: l10n.depotSettingsBackgroundTitle,
                description: l10n.depotSettingsBackgroundSubtitle,
                onRunFinished: state.syncIfStale,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
