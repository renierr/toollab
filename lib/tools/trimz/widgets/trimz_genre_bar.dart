import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../trimz_state.dart';

class TrimzGenreBar extends StatelessWidget {
  const TrimzGenreBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<TrimzState>();
    final genres = state.genres;
    if (genres.isEmpty) return const SizedBox.shrink();
    final selected = state.genre;
    void select(String? id) => unawaited(state.selectGenre(id));
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: [
          ChoiceChip(
            label: Text(l10n.trimzAllGenres),
            selected: selected == null,
            onSelected: (_) => select(null),
          ),
          for (final genre in genres)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text(genre.label),
                selected: selected == genre.id,
                onSelected: (on) => select(on ? genre.id : null),
              ),
            ),
        ],
      ),
    );
  }
}
