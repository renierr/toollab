import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

/// Which copies of a writer's data the delete is meant to reach.
enum HealthDeleteScope { here, everywhere }

/// Confirms dropping a writer's stored rows.
///
/// The scope choice only appears while this tool actually syncs. Without a
/// backend there is one copy and nothing to decide, and a radio group that
/// cannot change the outcome is worse than no radio group.
class HealthDeleteAppDialog extends StatefulWidget {
  final String label;
  final bool canChooseScope;

  const HealthDeleteAppDialog({
    super.key,
    required this.label,
    required this.canChooseScope,
  });

  static Future<HealthDeleteScope?> show(
    BuildContext context, {
    required String label,
    required bool canChooseScope,
  }) => showDialog<HealthDeleteScope>(
    context: context,
    builder: (context) =>
        HealthDeleteAppDialog(label: label, canChooseScope: canChooseScope),
  );

  @override
  State<HealthDeleteAppDialog> createState() => _HealthDeleteAppDialogState();
}

class _HealthDeleteAppDialogState extends State<HealthDeleteAppDialog> {
  // Defaults to the reversible one: freeing space here costs nothing if it turns
  // out to be wrong, and removing everywhere cannot be taken back.
  HealthDeleteScope _scope = HealthDeleteScope.here;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ResponsiveAlertDialog(
      scrollable: true,
      title: Text(widget.label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.healthDashboardAppDeleteDataConfirm),
          if (widget.canChooseScope) ...[
            const SizedBox(height: 16),
            RadioGroup<HealthDeleteScope>(
              groupValue: _scope,
              onChanged: (value) =>
                  setState(() => _scope = value ?? HealthDeleteScope.here),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ScopeOption(
                    scope: HealthDeleteScope.here,
                    title: l10n.healthDashboardAppDeleteHere,
                    subtitle: l10n.healthDashboardAppDeleteHereHint,
                  ),
                  _ScopeOption(
                    scope: HealthDeleteScope.everywhere,
                    title: l10n.healthDashboardAppDeleteEverywhere,
                    subtitle: l10n.healthDashboardAppDeleteEverywhereHint,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentRed,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(_scope),
          child: Text(l10n.commonDelete),
        ),
      ],
    );
  }
}

class _ScopeOption extends StatelessWidget {
  final HealthDeleteScope scope;
  final String title;
  final String subtitle;

  const _ScopeOption({
    required this.scope,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RadioListTile<HealthDeleteScope>(
      value: scope,
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
