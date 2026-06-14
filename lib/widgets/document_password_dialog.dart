import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class DocumentPasswordDialog extends StatefulWidget {
  final String title;
  final String message;
  final String submitLabel;

  const DocumentPasswordDialog({
    super.key,
    required this.title,
    required this.message,
    this.submitLabel = 'Open',
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String message,
    String submitLabel = 'Open',
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => DocumentPasswordDialog(
        title: title,
        message: message,
        submitLabel: submitLabel,
      ),
    );
  }

  @override
  State<DocumentPasswordDialog> createState() => _DocumentPasswordDialogState();
}

class _DocumentPasswordDialogState extends State<DocumentPasswordDialog> {
  late final TextEditingController _passwordController;
  late final FocusNode _focusNode;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveAlertDialog(
      icon: const Icon(Icons.lock_outline),
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              focusNode: _focusNode,
              autofocus: true,
              obscureText: _obscureText,
              onSubmitted: (value) {
                Navigator.of(context).pop(value);
              },
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscureText ? 'Show password' : 'Hide password',
                  onPressed: () {
                    setState(() => _obscureText = !_obscureText);
                  },
                  icon: Icon(
                    _obscureText
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_passwordController.text);
          },
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}
