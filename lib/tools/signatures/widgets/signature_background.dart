import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/checkerboard_background.dart';

import '../signature_models.dart';

/// Renders the chosen [CanvasBackground] behind a signature, shared by the
/// drawing canvas and the saved-signatures gallery so both honor the toggle.
class SignatureBackground extends StatelessWidget {
  final CanvasBackground background;
  final Widget? child;

  const SignatureBackground({super.key, required this.background, this.child});

  @override
  Widget build(BuildContext context) {
    return switch (background) {
      CanvasBackground.checkerboard => CheckerboardBackground(child: child),
      CanvasBackground.black => ColoredBox(color: Colors.black, child: child),
      CanvasBackground.white => ColoredBox(color: Colors.white, child: child),
    };
  }
}
