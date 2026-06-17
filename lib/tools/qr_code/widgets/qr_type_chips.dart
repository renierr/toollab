import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_chip.dart';
import 'package:tool_lab/tools/qr_code/qr_content_type.dart';

/// Horizontal selector for the QR payload type.
class QrTypeChips extends StatelessWidget {
  final QrContentType selected;
  final ValueChanged<QrContentType> onSelected;

  const QrTypeChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final type in QrContentType.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ToolChip(
                icon: type.icon,
                label: type.label(l10n),
                selected: type == selected,
                onTap: () => onSelected(type),
              ),
            ),
        ],
      ),
    );
  }
}
