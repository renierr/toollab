import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/sync_error_message.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'totp_account.dart';
import 'totp_auth_state.dart';
import 'totp_backup.dart';
import 'totp_import.dart';
import 'totp_sync_delegate.dart';
import 'widgets/totp_account_form_dialog.dart';
import 'widgets/totp_account_grid.dart';
import 'widgets/totp_add_sheet.dart';
import 'widgets/totp_empty_state.dart';
import 'widgets/totp_export_dialog.dart';
import 'widgets/totp_import_dialog.dart';
import 'widgets/totp_scan_dialog.dart';
import 'widgets/totp_search_field.dart';
import 'widgets/totp_sync_password_dialog.dart';

enum _MenuAction { import, export, syncPassword }

class TotpAuthPage extends StatefulWidget {
  const TotpAuthPage({super.key});

  @override
  State<TotpAuthPage> createState() => _TotpAuthPageState();
}

class _TotpAuthPageState extends State<TotpAuthPage> {
  String _query = '';
  bool _syncing = false;

  @override
  void initState() {
    super.initState();

    final appState = context.read<AppState>();
    final totpState = context.read<TotpAuthState>();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await totpState.ready;
      if (!mounted) return;
      await totpState.reload();
      if (!mounted) return;

      if (appState.syncEnabled &&
          appState.syncServerUrl.isNotEmpty &&
          totpState.hasSyncPassword &&
          appState.isToolSyncEnabled(TotpAuthTool.config.id)) {
        appState
            .syncWithBackend([TotpSyncDelegate()])
            .then((_) {
              if (mounted) totpState.reload();
            })
            .catchError((e) {
              errorLog('[TotpAuthPage] Auto-sync on open failed: $e');
              if (mounted) {
                final l10n = AppLocalizations.of(context);
                _snack(
                  l10n.totpSyncFailed(syncErrorMessage(e, l10n)),
                  error: true,
                );
              }
            });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TotpAuthState>();
    final l10n = AppLocalizations.of(context);
    final filtered = state.search(_query);
    final empty = !state.hasAccounts;

    return ToolLayout(
      title: TotpAuthTool.config.localizedName(l10n),
      actions: [
        if (state.hasSyncPassword)
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: l10n.totpSyncNow,
            onPressed: _syncing ? null : _syncNow,
          ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.totpAddAccount,
          onPressed: _showAddOptions,
        ),
        PopupMenuButton<_MenuAction>(
          tooltip: l10n.totpMoreActions,
          onSelected: (action) {
            switch (action) {
              case _MenuAction.import:
                _openImport();
              case _MenuAction.export:
                _openExport();
              case _MenuAction.syncPassword:
                _openSyncPassword();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _MenuAction.import,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.file_upload_outlined),
                title: Text(l10n.totpImportAccounts),
              ),
            ),
            PopupMenuItem(
              value: _MenuAction.export,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.file_download_outlined),
                title: Text(l10n.totpExportBackup),
              ),
            ),
            PopupMenuItem(
              value: _MenuAction.syncPassword,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.key_outlined),
                title: Text(l10n.totpSyncPassword),
              ),
            ),
          ],
        ),
      ],
      child: Column(
        children: [
          if (!empty)
            TotpSearchField(
              onChanged: (query) => setState(() => _query = query),
            ),
          Expanded(
            child: empty
                ? TotpEmptyState(
                    onScan: _openScan,
                    onManual: _addManually,
                    onImport: _openImport,
                  )
                : filtered.isEmpty
                ? _NoResults(query: _query)
                : TotpAccountGrid(
                    accounts: filtered,
                    state: state,
                    onCopy: _copyCode,
                    onEdit: _edit,
                    onCopyUri: _copyUri,
                    onDelete: _delete,
                    onAdvance: _advance,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddOptions() {
    return TotpAddSheet.show(
      context,
      onScan: _openScan,
      onManual: _addManually,
      onImport: _openImport,
    );
  }

  Future<void> _addManually() async {
    final account = await TotpAccountFormDialog.show(context);
    if (account == null || !mounted) return;
    await context.read<TotpAuthState>().addAccount(account);
    if (!mounted) return;
    _snack(AppLocalizations.of(context).totpAccountAdded(account.title));
  }

  Future<void> _openScan() async {
    final payload = await TotpScanDialog.show(context);
    if (payload == null || !mounted) return;
    try {
      final result = await TotpImporter.parseText(payload);
      if (!mounted) return;
      final added = await context.read<TotpAuthState>().importAccounts(
        result.accounts,
      );
      if (!mounted) return;
      _reportImport(added, result.accounts.length - added);
    } on TotpImportException catch (e) {
      errorLog('[TotpAuthPage] Scanned payload rejected: ${e.code}');
      if (mounted) {
        _snack(AppLocalizations.of(context).totpNotOtpQr, error: true);
      }
    }
  }

  Future<void> _openImport() async {
    final result = await TotpImportDialog.show(context);
    if (result == null || !mounted) return;
    final added = await context.read<TotpAuthState>().importAccounts(
      result.accounts,
    );
    if (!mounted) return;
    _reportImport(added, result.accounts.length - added);
  }

  void _reportImport(int added, int skipped) {
    final l10n = AppLocalizations.of(context);
    if (added == 0) {
      _snack(l10n.totpImportNothing, error: true);
    } else {
      _snack(l10n.totpImportSummary(added, skipped));
    }
  }

  Future<void> _openExport() async {
    final state = context.read<TotpAuthState>();
    final l10n = AppLocalizations.of(context);
    final selection = await TotpExportDialog.show(
      context,
      accountCount: state.accounts.length,
    );
    if (selection == null || !mounted) return;

    try {
      final content = await state.buildExport(
        selection.format,
        password: selection.password,
      );
      if (!mounted) return;
      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: TotpBackup.suggestedFileName(selection.format),
        bytes: Uint8List.fromList(utf8.encode(content)),
        acceptedTypeGroups: [
          XTypeGroup(
            label: 'TOTP backup',
            extensions: [selection.format.fileExtension],
            mimeTypes: [selection.format.mimeType],
          ),
        ],
        successMessageAndroid: l10n.totpBackupSaved,
        successMessageGeneralBuilder: (_) => l10n.totpBackupSaved,
      );
    } catch (e) {
      errorLog('[TotpAuthPage] Export failed: $e');
      if (mounted) {
        _snack(l10n.totpExportFailed(e.toString()), error: true);
      }
    }
  }

  Future<void> _openSyncPassword() async {
    final state = context.read<TotpAuthState>();
    final l10n = AppLocalizations.of(context);
    final result = await TotpSyncPasswordDialog.show(
      context,
      current: state.syncPassword,
    );
    if (result == null || !mounted) return;
    await state.setSyncPassword(result.password);
    if (!mounted) return;
    _snack(
      result.password == null
          ? l10n.totpSyncPasswordRemoved
          : l10n.totpSyncPasswordSaved,
    );
  }

  Future<void> _syncNow() async {
    final appState = context.read<AppState>();
    final totpState = context.read<TotpAuthState>();
    final l10n = AppLocalizations.of(context);
    if (_syncing || appState.isSyncing) return;
    setState(() => _syncing = true);
    try {
      final results = await appState.syncWithBackend([TotpSyncDelegate()]);
      if (results == null) {
        if (mounted) _snack(l10n.totpSyncNotConfigured, error: true);
        return;
      }
      await totpState.reload();
      if (!mounted) return;
      _snack(
        l10n.totpSyncFinished(
          results['pulled'] ?? 0,
          results['pushed'] ?? 0,
          results['deleted'] ?? 0,
        ),
      );
    } catch (e) {
      errorLog('[TotpAuthPage] Manual sync failed: $e');
      if (mounted) {
        _snack(l10n.totpSyncFailed(syncErrorMessage(e, l10n)), error: true);
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _copyCode(TotpAccount account) {
    final state = context.read<TotpAuthState>();
    final l10n = AppLocalizations.of(context);
    final code = state.codeFor(account);
    Clipboard.setData(ClipboardData(text: code));
    _snack(l10n.totpCodeCopied(account.title));
  }

  void _copyUri(TotpAccount account) {
    final l10n = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: account.otpAuthUri));
    _snack(l10n.totpUriCopied);
  }

  Future<void> _edit(TotpAccount account) async {
    final updated = await TotpAccountFormDialog.show(context, initial: account);
    if (updated == null || !mounted) return;
    await context.read<TotpAuthState>().updateAccount(updated);
  }

  Future<void> _advance(TotpAccount account) async {
    await context.read<TotpAuthState>().advanceCounter(account);
  }

  Future<void> _delete(TotpAccount account) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.totpDeleteTitle,
      message: l10n.totpDeleteMessage(
        account.title.isEmpty ? l10n.totpUnnamedAccount : account.title,
      ),
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonDelete,
      confirmColor: AppTheme.accentRed,
    );
    if (confirmed == true && mounted) {
      await context.read<TotpAuthState>().deleteAccount(account.id);
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppTheme.accentRed : null,
        ),
      );
  }
}

class _NoResults extends StatelessWidget {
  final String query;

  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).totpNoResults(query.trim()),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
