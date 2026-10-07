import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../paperless_api.dart';
import '../paperless_error_text.dart';
import '../paperless_state.dart';
import 'paperless_connection_card.dart';

enum _AuthMode { token, password }

/// Pushed with a `MaterialPageRoute`, so a plain `Scaffold` instead of
/// `ToolLayout`, whose back button needs a GoRouter state.
class PaperlessSettingsPage extends StatefulWidget {
  const PaperlessSettingsPage({super.key});

  @override
  State<PaperlessSettingsPage> createState() => _PaperlessSettingsPageState();
}

class _PaperlessSettingsPageState extends State<PaperlessSettingsPage>
    with DisposeCleanup {
  late final TextEditingController _url;
  late final TextEditingController _token;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late _AuthMode _mode;
  bool _busy = false;
  bool _obscureToken = true;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<PaperlessState>();
    _url = TextEditingController(text: state.serverUrl);
    _token = TextEditingController();
    _username = TextEditingController(text: state.username ?? '');
    _password = TextEditingController();
    _mode = state.username != null ? _AuthMode.password : _AuthMode.token;
    onDispose(() {
      _url.dispose();
      _token.dispose();
      _username.dispose();
      _password.dispose();
    });
  }

  void _setMessage(String? message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<PaperlessState>();
    final baseUri = PaperlessApi.parseBaseUri(_url.text);
    if (baseUri == null) {
      _setMessage(l10n.paperlessInvalidUrl, isError: true);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_mode == _AuthMode.password) {
        if (_username.text.trim().isEmpty || _password.text.isEmpty) {
          _setMessage(l10n.paperlessCredentialsRequired, isError: true);
          return;
        }
        await state.signIn(
          baseUri: baseUri,
          username: _username.text.trim(),
          password: _password.text,
        );
        _password.clear();
      } else {
        final token = _token.text.trim();
        if (token.isEmpty && !state.isConfigured) {
          _setMessage(l10n.paperlessTokenRequired, isError: true);
          return;
        }
        await state.saveConnection(
          baseUri: baseUri,
          token: token.isEmpty ? null : token,
        );
        _token.clear();
      }
      _url.text = state.serverUrl;
      state.refreshAll();
      await _test(afterSave: true);
    } catch (e) {
      _setMessage(describePaperlessError(l10n, e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test({bool afterSave = false}) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<PaperlessState>();
    try {
      final info = await state.testConnection();
      _setMessage(
        info.version == null
            ? l10n.paperlessConnectionOk(info.documentCount)
            : l10n.paperlessConnectionOkVersion(
                info.documentCount,
                info.version!,
              ),
      );
    } catch (e) {
      final error = describePaperlessError(l10n, e);
      // A saved connection stays: the server may just be out of reach now.
      _setMessage(
        afterSave
            ? l10n.paperlessSavedButUnreachable(error)
            : l10n.paperlessConnectionFailed(error),
        isError: true,
      );
    }
  }

  Future<void> _runTest() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    await _test();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _disconnect() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.paperlessDisconnect,
      message: l10n.paperlessDisconnectConfirm,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.paperlessDisconnect,
    );
    if (confirmed != true || !mounted) return;
    await context.read<PaperlessState>().disconnect();
    _setMessage(null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<PaperlessState>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paperlessSettingsTitle)),
      body: ReadableWidth(
        maxWidth: 640,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (state.isConfigured)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: PaperlessConnectionCard(
                  serverUrl: state.serverUrl,
                  username: state.username,
                  busy: _busy,
                  onTest: _runTest,
                  onDisconnect: _disconnect,
                ),
              ),
            SettingsSectionLabel(
              title: l10n.paperlessServerSection,
              description: l10n.paperlessServerSectionHint,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.paperlessServerUrl,
                  hintText: 'https://paperless.example.com',
                  prefixIcon: const Icon(Icons.dns_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            SettingsSectionLabel(title: l10n.paperlessAuthSection),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<_AuthMode>(
                    segments: [
                      ButtonSegment(
                        value: _AuthMode.token,
                        icon: const Icon(Icons.key_outlined),
                        label: Text(l10n.paperlessAuthToken),
                      ),
                      ButtonSegment(
                        value: _AuthMode.password,
                        icon: const Icon(Icons.person_outline),
                        label: Text(l10n.paperlessAuthPassword),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (selection) =>
                        setState(() => _mode = selection.first),
                  ),
                  const SizedBox(height: 16),
                  if (_mode == _AuthMode.token)
                    TextField(
                      controller: _token,
                      obscureText: _obscureToken,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: l10n.paperlessApiToken,
                        helperText: state.isConfigured
                            ? l10n.paperlessTokenKeepHint
                            : l10n.paperlessTokenHint,
                        helperMaxLines: 3,
                        prefixIcon: const Icon(Icons.key_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureToken
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _obscureToken = !_obscureToken),
                        ),
                      ),
                    )
                  else ...[
                    TextField(
                      controller: _username,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.paperlessUsername,
                        prefixIcon: const Icon(Icons.person_outline),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (_) => _busy ? null : _save(),
                      decoration: InputDecoration(
                        labelText: l10n.paperlessPassword,
                        helperText: l10n.paperlessPasswordHint,
                        helperMaxLines: 3,
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _mode == _AuthMode.password
                          ? l10n.paperlessSignIn
                          : l10n.commonSave,
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _messageIsError
                            ? AppTheme.statusRed
                            : AppTheme.statusGreen,
                      ),
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
