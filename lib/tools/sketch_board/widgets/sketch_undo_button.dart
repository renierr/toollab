import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sketch_board_state.dart';

class SketchUndoButton extends StatelessWidget {
  const SketchUndoButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<SketchBoardState, bool>(
      selector: (_, s) => s.canUndo,
      builder: (context, canUndo, _) => IconButton(
        tooltip: AppLocalizations.of(context).sketchUndo,
        icon: const Icon(Icons.undo),
        onPressed: canUndo ? context.read<SketchBoardState>().undo : null,
      ),
    );
  }
}
