import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import '../fast_drop_model.dart';
import 'retention_selector.dart';

class FastDropEditRetentionDialog extends StatefulWidget {
  final FastDropItem item;

  const FastDropEditRetentionDialog({super.key, required this.item});

  @override
  State<FastDropEditRetentionDialog> createState() =>
      _FastDropEditRetentionDialogState();
}

class _FastDropEditRetentionDialogState
    extends State<FastDropEditRetentionDialog> {
  late String _retention;

  @override
  void initState() {
    super.initState();
    _retention = _getRetentionValue(widget.item);
  }

  String _getRetentionValue(FastDropItem item) {
    if (item.expiresAt == null) return 'indefinite';
    final diffMs = item.expiresAt! - item.uploadedAt;
    final diffHours = (diffMs / (3600 * 1000)).round();

    const validOptions = {'1', '8', '24', '168'};
    final hoursStr = diffHours.toString();
    if (validOptions.contains(hoursStr)) {
      return hoursStr;
    }
    return '24'; // fallback
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      title: Text(l10n.fastDropEditRetentionTitle),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RetentionSelector(
                selectedValue: _retention,
                onChanged: (val) {
                  setState(() {
                    _retention = val;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(_retention);
          },
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text(l10n.commonSave),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.accentTeal,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
