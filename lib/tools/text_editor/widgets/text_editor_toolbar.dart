import 'package:flutter/material.dart';

import 'package:tool_lab/tools/text_editor/text_editor_state.dart';
import 'package:tool_lab/tools/text_editor/widgets/text_editor_toolbar_controls.dart';

/// Collapsible control row above the editor; the collapse toggle lives in
/// the app bar, so this only fades the controls themselves.
class TextEditorToolbar extends StatelessWidget {
  final TextEditorState state;
  final bool expanded;

  const TextEditorToolbar({
    super.key,
    required this.state,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: TextEditorToolbarControls(state: state),
      ),
      secondChild: const SizedBox(width: double.infinity),
      crossFadeState: expanded
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      duration: const Duration(milliseconds: 200),
    );
  }
}
