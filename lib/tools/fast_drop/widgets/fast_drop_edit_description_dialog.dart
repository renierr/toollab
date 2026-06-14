import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class FastDropEditDescriptionDialog extends StatefulWidget {
  final String currentDescription;

  const FastDropEditDescriptionDialog({
    super.key,
    this.currentDescription = '',
  });

  @override
  State<FastDropEditDescriptionDialog> createState() =>
      _FastDropEditDescriptionDialogState();
}

class _FastDropEditDescriptionDialogState
    extends State<FastDropEditDescriptionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentDescription);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveAlertDialog(
      title: const Text('Edit Description'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 4,
          minLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Add a description...',
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(_controller.text.trim());
          },
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Save'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.accentTeal,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
