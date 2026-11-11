import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class DepotPairClientIdDialog extends StatefulWidget {
  final String initialClientId;

  const DepotPairClientIdDialog({super.key, required this.initialClientId});

  static Future<String?> show(BuildContext context, String initialClientId) =>
      showDialog<String>(
        context: context,
        builder: (_) =>
            DepotPairClientIdDialog(initialClientId: initialClientId),
      );

  @override
  State<DepotPairClientIdDialog> createState() =>
      _DepotPairClientIdDialogState();
}

class _DepotPairClientIdDialogState extends State<DepotPairClientIdDialog>
    with DisposeCleanup {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialClientId);
    onDispose(_controller.dispose);
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      scrollable: true,
      title: Text(l10n.depotParqetPairClientTitle),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.depotSettingsClientId),
          validator: (value) => value == null || value.trim().isEmpty
              ? l10n.depotSettingsClientIdRequired
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.depotSettingsConnect),
        ),
      ],
    );
  }
}
