import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class PdfRedactFindDialog extends StatefulWidget {
  const PdfRedactFindDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => const PdfRedactFindDialog(),
    );
  }

  @override
  State<PdfRedactFindDialog> createState() => _PdfRedactFindDialogState();
}

class _PdfRedactFindDialogState extends State<PdfRedactFindDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      icon: const Icon(Icons.search),
      title: Text(l10n.pdfEditRedactFindTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.pdfEditRedactFindFieldLabel,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => _submit(_controller.text),
          child: Text(l10n.pdfEditRedactFindMarkAll),
        ),
      ],
    );
  }
}
