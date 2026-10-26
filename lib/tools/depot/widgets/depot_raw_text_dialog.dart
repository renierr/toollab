import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/widgets/selectable_text_view.dart';

class DepotRawTextDialog extends StatelessWidget {
  final String fileName;
  final String text;

  const DepotRawTextDialog({
    super.key,
    required this.fileName,
    required this.text,
  });

  static Future<void> show(
    BuildContext context, {
    required String fileName,
    required String text,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => DepotRawTextDialog(fileName: fileName, text: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;

    return ResponsiveAlertDialog(
      title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 560,
        child: SelectableTextView(
          text: text,
          emptyMessage: l10n.depotImportRawTextEmpty,
          maxHeight: maxHeight,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
