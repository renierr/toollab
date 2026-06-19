import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../location_capture_service.dart';
import '../location_format.dart';
import '../location_source.dart';
import 'accuracy_badge.dart';

/// Dialog for entering/editing a location description. When [fix] is provided
/// it also previews the captured coordinates and accuracy.
class LocationDescriptionDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String initialDescription;
  final LocationFix? fix;

  const LocationDescriptionDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.initialDescription = '',
    this.fix,
  });

  static Future<String?> show({
    required BuildContext context,
    required String title,
    required String confirmLabel,
    String initialDescription = '',
    LocationFix? fix,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => LocationDescriptionDialog(
        title: title,
        confirmLabel: confirmLabel,
        initialDescription: initialDescription,
        fix: fix,
      ),
    );
  }

  @override
  State<LocationDescriptionDialog> createState() =>
      _LocationDescriptionDialogState();
}

class _LocationDescriptionDialogState extends State<LocationDescriptionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final fix = widget.fix;

    return ResponsiveAlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fix != null) ...[
            SelectableText(
              formatCoordinates(fix.latitude, fix.longitude),
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: AccuracyBadge(source: fix.source, accuracy: fix.accuracy),
            ),
            if (fix.source == LocationSource.ip) ...[
              const SizedBox(height: 8),
              Text(
                l10n.gpsStoreIpFallbackNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.accentAmberLight,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.gpsStoreDescriptionLabel,
              hintText: l10n.gpsStoreDescriptionHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
