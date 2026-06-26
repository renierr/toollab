import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import '../code_highlight_state.dart';
import 'code_highlight_image_export_dialog.dart';

class CodeHighlightExportDialog extends StatelessWidget {
  final String code;
  final String? fileName;

  const CodeHighlightExportDialog({
    super.key,
    required this.code,
    this.fileName,
  });

  Future<void> _exportFile(
    BuildContext context,
    String text,
    String? fileName,
  ) async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: fileName ?? 'code.txt',
      bytes: bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.read<CodeHighlightState>();

    return ResponsiveAlertDialog(
      title: Text(l10n.codeHighlightExportTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.text_snippet_outlined),
            title: Text(l10n.codeHighlightExportText),
            subtitle: Text(fileName ?? 'code.txt'),
            onTap: () {
              Navigator.of(context).pop();
              _exportFile(context, code, fileName);
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(l10n.codeHighlightExportImage),
            subtitle: Text(
              fileName != null
                  ? '${fileName!.split('.').first}.png'
                  : 'code.png',
            ),
            onTap: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (dialogCtx) => CodeHighlightImageExportDialog(
                  code: code,
                  fileName: fileName,
                  tokens: state.cachedTokens,
                  scopes: state.cachedScopes,
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}
