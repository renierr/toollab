import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'responsive_alert_dialog.dart';

class ToolChooserDialog extends StatefulWidget {
  final List<ToolModel> tools;
  final String fileName;
  final bool showRememberChoice;

  const ToolChooserDialog({
    super.key,
    required this.tools,
    required this.fileName,
    this.showRememberChoice = true,
  });

  @override
  State<ToolChooserDialog> createState() => _ToolChooserDialogState();
}

class _RememberChoiceCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String labelText;

  const _RememberChoiceCheckbox({
    required this.value,
    required this.onChanged,
    required this.labelText,
  });

  @override
  State<_RememberChoiceCheckbox> createState() =>
      _RememberChoiceCheckboxState();
}

class _RememberChoiceCheckboxState extends State<_RememberChoiceCheckbox> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(value: widget.value, onChanged: widget.onChanged),
        Expanded(
          child: Text(
            widget.labelText,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ToolChooserDialogState extends State<ToolChooserDialog> {
  bool _rememberChoice = false;

  void _choose(ToolModel tool) {
    context.read<AppState>().recordToolUsage(tool.id);
    Navigator.of(context).pop((tool, _rememberChoice));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final appState = context.read<AppState>();
    final internalTools =
        widget.tools.where((t) => !SystemToolIds.isSystem(t.id)).toList()..sort(
          (a, b) =>
              appState.getLastUsed(b.id).compareTo(appState.getLastUsed(a.id)),
        );
    final systemTools = widget.tools
        .where((t) => SystemToolIds.isSystem(t.id))
        .toList();

    return ResponsiveAlertDialog(
      title: Text(
        l10n.widgetToolChooserOpenFile,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.widgetToolChooserChooseTool,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              widget.fileName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final tool in internalTools)
                      _ToolChooserItem(tool: tool, onTap: () => _choose(tool)),
                  ],
                ),
              ),
            ),
            if (systemTools.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final tool in systemTools)
                _ToolChooserItem(tool: tool, onTap: () => _choose(tool)),
            ],
            if (widget.showRememberChoice) ...[
              const SizedBox(height: 12),
              _RememberChoiceCheckbox(
                value: _rememberChoice,
                onChanged: (val) {
                  setState(() {
                    _rememberChoice = val ?? false;
                  });
                },
                labelText: l10n.widgetToolChooserAlwaysUseTool,
              ),
            ],
          ],
        ),
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

class _ToolChooserItem extends StatelessWidget {
  final ToolModel tool;
  final VoidCallback onTap;

  const _ToolChooserItem({required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tool.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(tool.icon, color: tool.accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.localizedName(l10n),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tool.localizedDescription(l10n),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
