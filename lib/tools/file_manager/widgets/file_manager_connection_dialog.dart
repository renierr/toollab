import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_connection.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class FileManagerConnectionDialog extends StatefulWidget {
  const FileManagerConnectionDialog({super.key});

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
            if (_protocol == FileManagerProtocol.smb)
              TextFormField(
                controller: _share,
                decoration: InputDecoration(labelText: l10n.fileManagerShare),
                validator: _required,
              ),
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
