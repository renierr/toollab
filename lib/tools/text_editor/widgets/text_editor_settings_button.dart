import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/text_editor/config.dart';

class TextEditorSettingsButton extends StatelessWidget {
  const TextEditorSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context).textEditorSettings,
      onPressed: () => context.push('${TextEditorTool.config.route}/settings'),
      icon: const Icon(Icons.settings_outlined),
    );
  }
}
