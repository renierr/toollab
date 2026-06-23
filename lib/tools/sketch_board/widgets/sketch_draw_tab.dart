import 'package:flutter/material.dart';

import 'sketch_canvas.dart';
import 'sketch_properties_bar.dart';
import 'sketch_selection_actions.dart';
import 'sketch_toolbar.dart';

class SketchDrawTab extends StatelessWidget {
  const SketchDrawTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: SketchCanvas()),
        const Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Align(
            alignment: Alignment.topCenter,
            child: SketchPropertiesBar(),
          ),
        ),
        const Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(child: SketchToolbar()),
        ),
        const Positioned(
          right: 12,
          bottom: 12,
          child: SketchSelectionActions(),
        ),
      ],
    );
  }
}
