import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_source_apps.dart';

class HealthSourceBadge extends StatelessWidget {
  final String? packageName;

  const HealthSourceBadge({super.key, required this.packageName});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          healthAppIcon(packageName),
          size: 16,
          color: Theme.of(context).hintColor,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            healthAppLabel(packageName, l10n),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
