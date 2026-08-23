import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/text_editor/text_editor_state.dart';

class TextEditorSettingsPage extends StatelessWidget {
  const TextEditorSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<TextEditorState>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.textEditorSettings)),
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                l10n.textEditorDefaultsSubtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.format_size_outlined),
              title: Text(l10n.textEditorFontSize),
              subtitle: Slider(
                value: state.fontSize,
                min: 10,
                max: 28,
                divisions: 18,
                label: state.fontSize.toStringAsFixed(0),
                onChanged: state.setFontSize,
              ),
              trailing: Text(state.fontSize.toStringAsFixed(0)),
            ),
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.wrap_text_outlined),
              title: Text(l10n.textEditorWordWrap),
              value: state.wordWrap,
              onChanged: state.setWordWrap,
            ),
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.code_outlined),
              title: Text(l10n.textEditorSyntaxHighlight),
              value: state.highlightEnabled,
              onChanged: state.setHighlightEnabled,
            ),
          ],
        ),
      ),
    );
  }
}
