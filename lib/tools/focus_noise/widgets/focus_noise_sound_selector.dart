import 'package:flutter/material.dart';
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
    return InfoCard(
      icon: Icons.library_music_outlined,
      title: 'Sound Library',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: sounds.map((sound) {
          final bool selected = sound.id == selectedSoundId;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onSelected(sound),
            avatar: Icon(sound.icon, size: 18),
            label: Text(sound.name),
            labelStyle: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          );
        }).toList(),
      ),
    );
  }
}
