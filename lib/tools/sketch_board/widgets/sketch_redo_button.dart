import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sketch_board_state.dart';

class SketchRedoButton extends StatelessWidget {
  const SketchRedoButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<SketchBoardState, bool>(
      selector: (_, s) => s.canRedo,
      builder: (context, canRedo, _) => IconButton(
        tooltip: AppLocalizations.of(context).sketchRedo,
        icon: const Icon(Icons.redo),
        onPressed: canRedo ? context.read<SketchBoardState>().redo : null,
      ),
    );
  }
}
