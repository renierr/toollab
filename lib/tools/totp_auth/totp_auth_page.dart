import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'totp.dart';
import 'totp_account.dart';
import 'totp_auth_state.dart';
import 'widgets/totp_account_card.dart';

class TotpAuthPage extends StatefulWidget {
  const TotpAuthPage({super.key});

  @override
  State<TotpAuthPage> createState() => _TotpAuthPageState();
}

class _TotpAuthPageState extends State<TotpAuthPage> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<TotpAuthState>();
    final l10n = AppLocalizations.of(context);

    return ToolLayout(
      title: TotpAuthTool.config.localizedName(l10n),
      fullscreen: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: 'Export',
          onPressed: () => _export(context, state),
        ),
        IconButton(
          icon: const Icon(Icons.file_upload_outlined),
          tooltip: 'Import',
          onPressed: () => _import(context, state),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Sync password',
          onPressed: () => _passwordDialog(context, state),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add',
          onPressed: () => _addDialog(context, state),
        ),
      ],
      child: state.accounts.where((a) => !a.deleted).isEmpty
          ? const Center(child: Text('No accounts yet. Tap + to add.'))
          : ListView.builder(
              itemCount: state.accounts.where((a) => !a.deleted).length,
              itemBuilder: (context, i) {
                final acc = state.accounts.where((a) => !a.deleted).toList()[i];
                return TotpAccountCard(account: acc, state: state);
              },
            ),
    );
  }

  Future<void> _addDialog(BuildContext context, TotpAuthState state) async {
    final result = await showDialog<TotpAccount>(
      context: context,
      builder: (_) => _AddAccountDialog(),
    );
    if (result != null) await state.addAccount(result);
  }

  Future<void> _export(BuildContext context, TotpAuthState state) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export encrypted'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Export')),
        ],
      ),
    );
    if (ok != true || ctrl.text.isEmpty) return;
    final payload = await state.exportEncrypted(ctrl.text);
    // Save to file via share
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Encrypted export'),
          content: SelectableText(payload),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    }
  }

  Future<void> _import(BuildContext context, TotpAuthState state) async {
    final payloadCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import encrypted'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: payloadCtrl,
              decoration: const InputDecoration(labelText: 'Payload'),
              maxLines: 4,
            ),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await state.importEncrypted(payloadCtrl.text.trim(), passCtrl.text);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  Future<void> _passwordDialog(BuildContext context, TotpAuthState state) async {
    final ctrl = TextEditingController(text: state.syncPassword ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sync password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password (for sync encryption)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await state.setSyncPassword(ctrl.text.isEmpty ? null : ctrl.text);
    }
  }
}

class _AddAccountDialog extends StatefulWidget {
  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  final _issuerCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _uriCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _uriCtrl, decoration: const InputDecoration(labelText: 'otpauth:// URI (optional)')),
            const Divider(),
            TextField(controller: _issuerCtrl, decoration: const InputDecoration(labelText: 'Issuer')),
            TextField(controller: _accountCtrl, decoration: const InputDecoration(labelText: 'Account')),
            TextField(controller: _secretCtrl, decoration: const InputDecoration(labelText: 'Secret (base32)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            TotpAccount? acc;
            if (_uriCtrl.text.trim().isNotEmpty) {
              final parsed = Totp.parseOtpAuthUri(_uriCtrl.text.trim());
              if (parsed != null) {
                acc = TotpAccount(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  issuer: parsed['issuer'] ?? '',
                  accountName: parsed['account'] ?? '',
                  secret: parsed['secret']!,
                  algorithm: _algoFrom(parsed['algorithm'] ?? 'SHA1'),
                  digits: int.tryParse(parsed['digits'] ?? '6') ?? 6,
                  period: int.tryParse(parsed['period'] ?? '30') ?? 30,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
              }
            } else if (_secretCtrl.text.trim().isNotEmpty) {
              acc = TotpAccount(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                issuer: _issuerCtrl.text.trim(),
                accountName: _accountCtrl.text.trim(),
                secret: _secretCtrl.text.trim(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
            }
            if (acc != null) Navigator.pop(context, acc);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  TotpAlgorithm _algoFrom(String s) {
    switch (s.toUpperCase()) {
      case 'SHA256':
        return TotpAlgorithm.sha256;
      case 'SHA512':
        return TotpAlgorithm.sha512;
      default:
        return TotpAlgorithm.sha1;
    }
  }
}
