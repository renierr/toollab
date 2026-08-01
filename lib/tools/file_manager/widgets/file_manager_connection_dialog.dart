import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_connection.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class FileManagerConnectionDialog extends StatefulWidget {
  final Future<List<String>> Function({
    required String host,
    required String username,
    required String password,
  })
  onDiscoverSmbShares;

  const FileManagerConnectionDialog({
    super.key,
    required this.onDiscoverSmbShares,
  });

  @override
  State<FileManagerConnectionDialog> createState() =>
      _FileManagerConnectionDialogState();
}

class _FileManagerConnectionDialogState
    extends State<FileManagerConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '21');
  final _share = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _path = TextEditingController();
  FileManagerProtocol _protocol = FileManagerProtocol.ftp;
  List<String> _shares = [];
  bool _isDiscoveringShares = false;

  @override
  void dispose() {
    _label.dispose();
    _host.dispose();
    _port.dispose();
    _share.dispose();
    _username.dispose();
    _password.dispose();
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      title: Text(l10n.fileManagerAddConnection),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<FileManagerProtocol>(
              initialValue: _protocol,
              items: [
                DropdownMenuItem(
                  value: FileManagerProtocol.ftp,
                  child: Text(l10n.fileManagerFtp),
                ),
                DropdownMenuItem(
                  value: FileManagerProtocol.smb,
                  child: Text(l10n.fileManagerSmb),
                ),
              ],
              onChanged: (value) => setState(() {
                _protocol = value!;
                _port.text = value == FileManagerProtocol.ftp ? '21' : '445';
              }),
            ),
            TextFormField(
              controller: _label,
              decoration: InputDecoration(
                labelText: l10n.fileManagerConnectionName,
              ),
              validator: _required,
            ),
            TextFormField(
              controller: _host,
              decoration: InputDecoration(labelText: l10n.fileManagerHost),
              validator: _required,
            ),
            TextFormField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.fileManagerPort),
              validator: _required,
            ),
            if (_protocol == FileManagerProtocol.smb) ...[
              if (_shares.isEmpty)
                TextFormField(
                  controller: _share,
                  decoration: InputDecoration(labelText: l10n.fileManagerShare),
                  validator: _required,
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _shares.contains(_share.text)
                      ? _share.text
                      : null,
                  decoration: InputDecoration(labelText: l10n.fileManagerShare),
                  items: _shares
                      .map(
                        (share) =>
                            DropdownMenuItem(value: share, child: Text(share)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _share.text = value ?? ''),
                  validator: _required,
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isDiscoveringShares ? null : _discoverShares,
                  icon: _isDiscoveringShares
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.travel_explore_outlined),
                  label: Text(l10n.fileManagerDiscoverShares),
                ),
              ),
            ],
            TextFormField(
              controller: _username,
              decoration: InputDecoration(labelText: l10n.fileManagerUsername),
            ),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.fileManagerPassword),
            ),
            TextFormField(
              controller: _path,
              decoration: InputDecoration(
                labelText: l10n.fileManagerInitialPath,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.commonSave)),
      ],
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? '' : null;

  Future<void> _discoverShares() async {
    setState(() => _isDiscoveringShares = true);
    try {
      final shares = await widget.onDiscoverSmbShares(
        host: _host.text,
        username: _username.text,
        password: _password.text,
      );
      if (!mounted) return;
      setState(() {
        _shares = shares;
        if (shares.length == 1) _share.text = shares.first;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDiscoveringShares = false);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final id = '${_protocol.name}-${_host.text.trim()}-${_share.text.trim()}';
    Navigator.pop(context, (
      FileManagerConnection(
        id: id,
        label: _label.text.trim(),
        protocol: _protocol,
        host: _host.text.trim(),
        port: int.parse(_port.text),
        share: _share.text.trim(),
        username: _username.text.trim(),
        initialPath: _path.text.trim(),
      ),
      _password.text,
    ));
  }
}
