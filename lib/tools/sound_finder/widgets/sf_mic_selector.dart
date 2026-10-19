import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Compact input-device picker. Lets the user route capture through an
/// external mic (wired, USB, or Bluetooth) instead of the built-in one, with a
/// refresh to re-scan after (un)plugging a device.
class SfMicSelector extends StatelessWidget {
  final List<InputDevice> devices;
  final String? selectedId;
  final ValueChanged<InputDevice?>? onChanged;
  final VoidCallback onRefresh;

  const SfMicSelector({
    super.key,
    required this.devices,
    required this.selectedId,
    required this.onChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final Set<String> ids = devices.map((d) => d.id).toSet();
    final String? currentId = ids.contains(selectedId) ? selectedId : null;

    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mic_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: currentId,
                hint: Text(l10n.sfMicDefault),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      l10n.sfMicDefault,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...devices.map(
                    (d) => DropdownMenuItem<String?>(
                      value: d.id,
                      child: Text(d.label, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: onChanged == null
                    ? null
                    : (String? id) => onChanged!(
                        id == null
                            ? null
                            : devices.firstWhere((d) => d.id == id),
                      ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: l10n.sfRefreshMics,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}
