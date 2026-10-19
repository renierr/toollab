import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

/// Returns the edited text (empty clears it), or null when cancelled.
class SfSleepAnnotationDialog extends StatefulWidget {
  const SfSleepAnnotationDialog({super.key, this.initial});

  final String? initial;

  static Future<String?> show(BuildContext context, {String? initial}) =>
      showDialog<String>(
        context: context,
        builder: (_) => SfSleepAnnotationDialog(initial: initial),
      );

  @override
  State<SfSleepAnnotationDialog> createState() =>
      _SfSleepAnnotationDialogState();
}

class _SfSleepAnnotationDialogState extends State<SfSleepAnnotationDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      title: Text(l10n.sfSleepAnnotate),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
