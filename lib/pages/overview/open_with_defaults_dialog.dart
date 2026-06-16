import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/theme/theme.dart';

class OpenWithDefaultsDialog extends StatefulWidget {
  const OpenWithDefaultsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const OpenWithDefaultsDialog(),
    );
  }

  @override
  State<OpenWithDefaultsDialog> createState() => _OpenWithDefaultsDialogState();
}

class _OpenWithDefaultsDialogState extends State<OpenWithDefaultsDialog> {
  Map<String, String> _defaults = {};
  bool _loading = true;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await SharingService.instance.getAllDefaultTools();
    if (mounted) {
      setState(() {
        _defaults = data;
        _loading = false;
      });
    }
  }

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctxL10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(ctxL10n.coreOpenWithResetTitle),
          content: Text(ctxL10n.coreOpenWithResetContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctxL10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(ctxL10n.commonReset),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _resetting = true);
    await SharingService.instance.clearAllDefaultTools();
    await _load();
    setState(() => _resetting = false);

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.coreOpenWithCleared)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.coreOpenWithDefaultsTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : _defaults.isEmpty
            ? Text(
                l10n.coreOpenWithNoDefaults,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.coreOpenWithAssociationsLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._defaults.entries.map((e) {
                    final tool = ToolRegistry.all.where((t) => t.id == e.value);
                    final toolName = tool.isNotEmpty
                        ? tool.first.name
                        : e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.insert_drive_file_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${e.key} → $toolName',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.statusAmber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _resetting ? null : _reset,
                      icon: _resetting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(
                        _resetting
                            ? l10n.coreOpenWithResetting
                            : l10n.coreOpenWithResetButton,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
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
