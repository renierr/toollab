import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
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

class _ToolChooserDialogState extends State<ToolChooserDialog> {
  bool _rememberChoice = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ResponsiveAlertDialog(
      title: Text(
        'Open File',
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
            Text('Choose a tool to open:', style: theme.textTheme.bodyMedium),
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
                  children: widget.tools.map((tool) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pop((tool, _rememberChoice));
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: tool.accentColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  tool.icon,
                                  color: tool.accentColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tool.name,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tool.description,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.7),
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (widget.showRememberChoice) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _rememberChoice,
                    onChanged: (val) {
                      setState(() {
                        _rememberChoice = val ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      'Always use this tool for this file type',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
