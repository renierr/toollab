import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/info_card.dart';

import '../focus_noise_sound.dart';

class FocusNoiseSoundSelector extends StatelessWidget {
  final List<FocusNoiseSound> sounds;
  final String selectedSoundId;
  final ValueChanged<FocusNoiseSound> onSelected;

  const FocusNoiseSoundSelector({
    super.key,
    required this.sounds,
    required this.selectedSoundId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return InfoCard(
      icon: Icons.library_music_outlined,
      title: l10n.focusSoundLibrary,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: sounds.map((sound) {
          final bool selected = sound.id == selectedSoundId;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onSelected(sound),
            avatar: Icon(sound.icon, size: 18),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sound.name),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: sound.isAsset
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    sound.isAsset ? 'REC' : 'GEN',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: sound.isAsset
                          ? Colors.green.shade700
                          : Colors.amber.shade800,
                    ),
                  ),
                ),
              ],
            ),
            labelStyle: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          );
        }).toList(),
      ),
    );
  }
}
