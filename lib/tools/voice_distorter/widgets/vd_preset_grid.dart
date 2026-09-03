import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/responsive_alert_dialog.dart';
import '../engine/voice_effect.dart';
import '../preset_l10n.dart';
import '../voice_distorter_state.dart';

const Map<String, IconData> _builtInIcons = {
  'chipmunk': Icons.fast_forward_rounded,
  'helium': Icons.arrow_circle_up_rounded,
  'deep_voice': Icons.arrow_circle_down_rounded,
  'giant': Icons.height,
  'robot': Icons.smart_toy_outlined,
  'cyborg': Icons.precision_manufacturing_outlined,
  'alien': Icons.rocket_launch_outlined,
  'telephone': Icons.phone_outlined,
  'radio': Icons.radio_outlined,
  'ghost': Icons.blur_on,
  'monster': Icons.warning_amber_rounded,
  'dark_lord': Icons.dark_mode_outlined,
};

class VdPresetGrid extends StatelessWidget {
  const VdPresetGrid({super.key});

  Future<void> _confirmDelete(BuildContext context, VoicePreset preset) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ResponsiveAlertDialog(
        title: Text(l10n.voiceDistorterDeletePresetTitle),
        content: Text(l10n.voiceDistorterDeletePresetMessage(preset.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<VoiceDistorterState>().deleteCustomPreset(preset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<VoiceDistorterState>();
    final List<VoicePreset> presets = [
      ...VoicePresets.all,
      ...state.customPresets,
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final preset in presets)
          _PresetCard(
            preset: preset,
            selected: state.selectedPresetId == preset.id,
            onTap: () =>
                context.read<VoiceDistorterState>().selectPreset(preset),
            onDelete: preset.isCustom
                ? () => _confirmDelete(context, preset)
                : null,
          ),
      ],
    );
  }
}

class _PresetCard extends StatelessWidget {
  final VoicePreset preset;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final IconData icon = _builtInIcons[preset.id] ?? Icons.tune_outlined;

    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                localizedPresetName(l10n, preset),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? theme.colorScheme.onPrimaryContainer : null,
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(12),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
