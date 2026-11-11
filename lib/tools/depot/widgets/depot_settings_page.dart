import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/background_task_service.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/background_task_tile.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';
import 'package:tool_lab/widgets/web_login/web_login.dart';
import 'package:url_launcher/url_launcher.dart';

import '../depot_background_sync.dart';
import '../depot_portfolio_state.dart';
import '../parqet/parqet_auth.dart';
import '../parqet/parqet_pairing.dart';
import 'depot_allocation_settings.dart';
import 'depot_clear_data_tile.dart';
import 'depot_data_export_tile.dart';
import 'depot_details_link_settings.dart';
import 'depot_dividend_settings.dart';
import 'depot_logo_settings.dart';
import 'depot_pair_client_id_dialog.dart';
import 'depot_sync_error_card.dart';
import 'depot_tax_settings.dart';
import 'pair_receive_dialog.dart';
import 'pair_send_page.dart';

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
      inApp: WebLogin.isSupported
          ? (authorize) => WebLogin.captureRedirect(
              context,
              url: authorize,
              callbackPrefix: ParqetAuth.redirectUri,
              title: l10n.depotLoginInAppTitle,
            )
          : null,
      // A TV has no browser to hand the login to.
      preferInApp: context.read<AppState>().tvMode,
    );
    if (!mounted) return;
    await _loadScopes();
    if (connected && mounted) Navigator.of(context).pop();
  }

  /// A TV cannot log in itself, so it can show a code a phone scans instead.
  Future<void> _connectFromPhone() async {
    final l10n = AppLocalizations.of(context);
    final request = ParqetAuth.beginLogin(clientId: '');
    final result =
        await PairReceiveDialog.show<({String clientId, ParqetTokens tokens})>(
          context,
          protocol: ParqetPairing.protocol,
          fields: ParqetPairing.fields(request),
          title: l10n.depotParqetPairReceive,
          hint: l10n.depotParqetPairReceiveHint,
          noNetwork: l10n.depotParqetPairNoNetwork,
          failed: l10n.depotParqetPairFailed,
          onReceived: (data) => ParqetPairing.complete(request, data),
        );
    if (result == null || !mounted) return;
    final connected = await context
        .read<DepotPortfolioState>()
        .connectWithTokens(clientId: result.clientId, tokens: result.tokens);
    if (!mounted) return;
    await _loadScopes();
    if (connected && mounted) Navigator.of(context).pop();
  }

  /// The phone half: scan a TV's code, finish Parqet's login here and send
  /// the redirect back.
  Future<void> _sendToTv() async {
    final l10n = AppLocalizations.of(context);
    await PairSendPage.open(
      context,
      protocol: ParqetPairing.protocol,
      title: l10n.depotParqetPairSendTitle,
      hint: l10n.depotParqetPairSendHint,
      invalidCode: l10n.depotParqetPairInvalidCode,
      sent: l10n.depotParqetPairSent,
      failed: l10n.depotParqetPairSendFailed,
      accentColor: AppTheme.accentGreen,
      onScan: (pageContext, code) async {
        final fields = ParqetPairing.read(code);
        final clientId = await DepotPairClientIdDialog.show(
          pageContext,
          _clientId.text.trim(),
        );
        if (clientId == null || !pageContext.mounted) {
          return PairSendOutcome.cancelled;
        }
        final callback = await WebLogin.captureRedirect(
          pageContext,
          url: ParqetAuth.authorizeUri(
            clientId: clientId,
            state: fields.state,
            challenge: fields.challenge,
          ),
          callbackPrefix: ParqetAuth.redirectUri,
          title: l10n.depotLoginInAppTitle,
        );
        if (callback == null) return PairSendOutcome.cancelled;
        return await ParqetPairing.send(code, callback, clientId)
            ? PairSendOutcome.sent
            : PairSendOutcome.failed;
      },
    );
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
    final tvMode = context.watch<AppState>().tvMode;
    final error = state.error;

    // A TV has no browser and remote typing is painful, so pairing leads there.
    final Widget? pairButton = Platform.isAndroid
        ? (tvMode
              ? FilledButton.icon(
                  onPressed: state.isConnecting ? null : _connectFromPhone,
                  icon: const Icon(Icons.qr_code_2),
                  label: Text(l10n.depotParqetPairReceive),
                )
              : OutlinedButton.icon(
                  onPressed: state.isConnecting ? null : _connectFromPhone,
                  icon: const Icon(Icons.qr_code_2),
                  label: Text(l10n.depotParqetPairReceive),
                ))
        : null;
    final webButton = tvMode
        ? OutlinedButton.icon(
            onPressed: state.isConnecting ? null : _connect,
            icon: const Icon(Icons.login_outlined),
            label: Text(
              state.isConnecting
                  ? l10n.depotSettingsConnecting
                  : state.isConnected
                  ? l10n.depotSettingsReconnect
                  : l10n.depotSettingsConnect,
            ),
          )
        : FilledButton.icon(
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
          );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.depotSettingsTitle)),
      body: ReadableScrollPadding(
        maxWidth: 640,
        padding: const EdgeInsets.only(bottom: 24),
        builder: (context, padding) => ListView(
          padding: padding,
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
                child: DepotSyncErrorCard(
                  error: error,
                  onRetry: state.isConnected ? state.sync : null,
                  onReconnect: error.needsLogin
                      ? (tvMode && Platform.isAndroid
                            ? _connectFromPhone
                            : _connect)
                      : null,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final button
                      in tvMode
                          ? [pairButton, webButton]
                          : [webButton, pairButton])
                    ?button,
                  if (state.isConnected)
                    OutlinedButton.icon(
                      onPressed: state.isConnecting ? null : _disconnect,
                      icon: const Icon(Icons.link_off_outlined),
                      label: Text(l10n.depotSettingsDisconnect),
                    ),
                ],
              ),
            ),
            if (Platform.isAndroid && !tvMode)
              ListTile(
                leading: const Icon(Icons.tv),
                title: Text(l10n.depotParqetPairSendTitle),
                subtitle: Text(l10n.depotParqetPairSendSubtitle),
                onTap: _sendToTv,
              ),
            const DepotLogoSettings(),
            const DepotDetailsLinkSettings(),
            const DepotAllocationSettings(),
            const DepotDividendSettings(),
            const DepotTaxSettings(),
            const DepotDataExportTile(),
            const DepotClearDataTile(),
            if (state.isConnected) ...[
              SettingsSectionLabel(title: l10n.depotSettingsSectionSync),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: Text(l10n.depotSyncAllTitle),
                subtitle: Text(l10n.depotSyncAllSubtitle),
                trailing: state.isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: state.isSyncing
                    ? null
                    : () =>
                          context.read<DepotPortfolioState>().sync(full: true),
              ),
              if (BackgroundTaskService.isSupported)
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
